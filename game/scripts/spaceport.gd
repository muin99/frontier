extends Node3D
## Earth Operations: the lab where every expedition is prepared and launched.
const Facility = preload("res://scripts/facility.gd")
const Player = preload("res://scripts/player.gd")
const FacilityMap = preload("res://scripts/facility_map.gd")
const ModuleSlot = preload("res://scripts/module_slot.gd")
const MissionSystem = preload("res://scripts/mission_system.gd")
const Humanoid = preload("res://scripts/humanoid.gd")
const Gfx = preload("res://scripts/gfx.gd")
const Model = preload("res://scripts/expedition_model.gd")
const Cargo = preload("res://scripts/outpost_cargo.gd")
const Campaign = preload("res://scripts/campaign.gd")
const LandingSim = preload("res://scripts/landing_sim.gd")
const MINT := Color("74eee2")
const GOLD := Color("f4bb64")
const LAB_SAVE := "user://lab_progress_v12.json"
const STEPS := [["briefing", "Take the mission briefing", "MISSION CONTROL"], ["crew", "Choose your commander", "CREW LOCKER"], ["shop", "Buy the rocket and outpost", "OUTFITTER"], ["engineering", "Integrate the vehicle", "HIGH BAY"], ["launch", "Go for launch", "PAD LC-01"]]
var facility: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var screen: Control
var chrome: Control
var overlay: Control
var room_label: Label
var hint: Label
var stats: Label
var checklist: Label
var waypoint: Label
var map_panel: Control
var reticle: Label
var focused: Dictionary = {}
var talker: Node
var visits: Dictionary = {}
var clock: float = 0
var last_room: String = ""
var quality: int = 1
var settings := ConfigFile.new()
var smoke: bool = false
var capture: bool = false
var automated: bool = false
var capture_frames: int = 0
var capture_view: String = "arrival"
var frame_times: Array[float] = []
var mission: Node
var economy_label: Label
var objective_label: Label
var toast_panel: PanelContainer
var toast_time := 0.0
var countdown_hud: Label
var state_tick := -1
var music: Node
var campaign := Campaign.new()
var stock := Cargo.new()
var lab := {"briefed": false, "suited": false, "solved": {}, "sim_rating": -1}
var selected_loadout := 1
var selected_site := 0
var selected_seed := 42601
var launch_clock := -1.0
var launch_cam: Camera3D
var bars: Array[ColorRect] = []
var fade: ColorRect
var sim: Node3D
var rumble: AudioStreamPlayer
var blip: AudioStreamPlayer
var leaving := false
var bar_height := 0.0

func _ready() -> void:
	get_window().title = "Mohashunnyo — Earth Operations"
	music = preload("res://scripts/music_director.gd").new(); add_child(music)
	configure_inputs()
	smoke = "--smoke" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture"):
			capture = true
			if "=" in argument:
				capture_view = argument.get_slice("=", 1)
	automated = smoke or capture or "--ground-transfer-test" in OS.get_cmdline_user_args()
	if capture:
		get_viewport().set_disable_input(true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	facility = Facility.new()
	facility.name = "Facility"
	add_child(facility)
	facility.build()
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 0.1, 23)
	settings.load(Gfx.SETTINGS)
	player.sensitivity = settings.get_value("controls", "sensitivity", 0.0021)
	quality = Gfx.quality()
	set_quality(quality)
	launch_cam = Camera3D.new(); launch_cam.fov = 58; launch_cam.far = 900; add_child(launch_cam)
	blip = AudioStreamPlayer.new(); blip.volume_db = -14; add_child(blip)
	rumble = AudioStreamPlayer.new(); rumble.volume_db = -60; add_child(rumble)
	if DisplayServer.get_name() != "headless":
		rumble.stream = Gfx.rumble_stream(); rumble.play()
	create_hud()
	mission = MissionSystem.new()
	add_child(mission)
	mission.setup(self)
	mission.countdown_label = countdown_hud
	var rng := RandomNumberGenerator.new(); rng.randomize(); selected_seed = rng.randi_range(1, 999999999)
	if not automated: load_state()
	update_objectives()
	if smoke:
		await smoke_test()
	elif capture:
		setup_capture()
	else:
		show_welcome()

func configure_inputs() -> void:
	var bindings := {"forward": [KEY_W, KEY_UP], "backward": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "sprint": [KEY_SHIFT]}
	for action: String in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action,event): InputMap.action_add_event(action, event)

# ---------------------------------------------------------------- persistent lab state

func load_state() -> void:
	campaign.read(); stock.read_draft()
	lab = {"briefed": false, "suited": settings.has_section_key("avatar", "variant"), "solved": {}, "sim_rating": -1}
	if FileAccess.file_exists(LAB_SAVE) or FileAccess.file_exists(LAB_SAVE+".bak"):
		var d: Variant = preload("res://scripts/progress_store.gd").read(LAB_SAVE)
		if d is Dictionary and str(d.get("campaign", "")) == campaign.id and int(d.get("expedition", 0)) == campaign.expedition_number:
			lab.briefed = bool(d.get("briefed", false))
			lab.sim_rating = clampi(int(d.get("sim_rating", -1)), -1, 3)
			if d.get("solved") is Dictionary:
				for key: String in d.solved: lab.solved[key] = true
	mission.briefing_complete = lab.briefed
	for key: String in lab.solved: mission.solved_exercises[key] = true
	facility.set_integration(3 if campaign.integrated else campaign.integration_step)

func save_state() -> void:
	if automated: return
	preload("res://scripts/progress_store.gd").write(LAB_SAVE,{"campaign": campaign.id, "expedition": campaign.expedition_number, "briefed": lab.briefed, "solved": lab.solved, "sim_rating": lab.sim_rating})

func refresh_state() -> void:
	if automated: return
	stock.read_draft(); campaign.read()
	facility.set_integration(3 if campaign.integrated else campaign.integration_step)

func step_done(id: String) -> bool:
	match id:
		"briefing": return bool(lab.briefed)
		"crew": return bool(lab.suited)
		"shop": return campaign.missing(stock).is_empty()
		"engineering": return campaign.integrated and campaign.missing(stock).is_empty()
	return false

func next_step() -> String:
	for step: Array in STEPS:
		if not step_done(step[0]): return step[0]
	return "launch"

func solved_count() -> int:
	return mission.exercise_data.exercises.size() - mission.calculation_gaps().size()

func update_objectives() -> void:
	if not is_instance_valid(checklist): return
	var next := next_step()
	var lines := "LAUNCH CHECKLIST  /  EXPEDITION %d\n" % campaign.expedition_number
	for step: Array in STEPS:
		var done := step_done(step[0])
		lines += "\n%s  %s" % ["✓" if done else ("▶" if step[0] == next else "○"), step[1]]
		if step[0] == next: lines += "   ·   " + str(step[2])
	lines += "\n\nBONUS\n%s  Flight Lab  %d / %d solved" % ["✓" if solved_count() >= 3 else "○", solved_count(), mission.exercise_data.exercises.size()]
	lines += "\n%s  Descent simulator  %s" % ["✓" if int(lab.sim_rating) >= 2 else "○", "not flown" if int(lab.sim_rating) < 0 else str(LandingSim.RATINGS[int(lab.sim_rating)]).to_lower()]
	checklist.text = lines
	facility.point_guide("" if launch_clock >= 0 else next)

# ---------------------------------------------------------------- interface helpers

func style(bg: Color, border: Color = Color("314958"), radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	return s

func label(text: String, font_size: int = 20, color: Color = Color("e4edf2")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func para(text: String, font_size: int = 18, color: Color = Color("b1c4d0"), width: float = 760) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l

func outlined(text: String, font_size: int, color: Color) -> Label:
	var l := label(text, font_size, color)
	l.add_theme_color_override("font_outline_color", Color("06121a"))
	l.add_theme_constant_override("outline_size", 7)
	return l

func button(text: String, callable: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 49
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_stylebox_override("normal", style(Color("15313b"), Color("3b777a"), 7))
	b.add_theme_stylebox_override("hover", style(Color("25515a"), MINT, 7))
	b.add_theme_stylebox_override("focus", style(Color("25515a"), MINT, 7))
	b.add_theme_stylebox_override("disabled", style(Color("14202a"), Color("2a3a44"), 7))
	b.pressed.connect(func() -> void: beep(620, 0.05); callable.call())
	return b

func primary(text: String, callable: Callable) -> Button:
	var b := button(text, callable)
	b.add_theme_color_override("font_color", Color("0b2227"))
	b.add_theme_color_override("font_hover_color", Color("0b2227"))
	b.add_theme_color_override("font_focus_color", Color("0b2227"))
	b.add_theme_stylebox_override("normal", style(MINT, MINT, 7))
	b.add_theme_stylebox_override("hover", style(Color("a8fff5"), Color.WHITE, 7))
	b.add_theme_stylebox_override("focus", style(Color("a8fff5"), Color.WHITE, 7))
	return b

func beep(frequency: float, duration: float) -> void:
	if DisplayServer.get_name() == "headless" or smoke: return
	blip.stream = Gfx.tone_stream(frequency, duration); blip.play()

func card(parent: Control, heading: String, value: String, width: float = 190) -> void:
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(width, 92); panel.add_theme_stylebox_override("panel", style(Color("142b38"), Color("3d6270"), 7)); parent.add_child(panel)
	var box := VBoxContainer.new(); panel.add_child(box); box.add_child(label(heading, 11, MINT)); box.add_child(label(value, 20))

func create_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(screen)
	chrome = Control.new()
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(chrome)
	var header := VBoxContainer.new()
	header.position = Vector2(40, 30)
	header.add_theme_constant_override("separation", 5)
	chrome.add_child(header)
	header.add_child(outlined("M O H A S H U N N Y O", 27, Color("eef4f6")))
	header.add_child(outlined("FRONTIER  /  EARTH OPERATIONS", 13, MINT))
	var list_panel := PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", style(Color(0.02, 0.06, 0.09, 0.78), Color("2f5560"), 10))
	list_panel.position = Vector2(40, 108)
	chrome.add_child(list_panel)
	checklist = label("", 16, Color("d9e8ed"))
	checklist.add_theme_constant_override("line_spacing", 5)
	list_panel.add_child(checklist)
	var status_box := VBoxContainer.new()
	status_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_box.position = Vector2(-330, 32)
	status_box.size.x = 290
	chrome.add_child(status_box)
	status_box.add_child(outlined("●  FACILITY SYSTEMS ONLINE", 14, MINT))
	economy_label = outlined("", 16, GOLD)
	status_box.add_child(economy_label)
	objective_label = outlined("", 13, MINT)
	status_box.add_child(objective_label)
	stats = outlined("", 12, Color("a1b6c4"))
	status_box.add_child(stats)
	var footer := VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(40, -121)
	chrome.add_child(footer)
	footer.add_child(outlined("CURRENT SECTOR", 12, MINT))
	room_label = outlined("ARRIVAL CONCOURSE", 26, Color("eef4f6"))
	footer.add_child(room_label)
	footer.add_child(outlined("WASD  Walk    SHIFT  Run    SPACE  Jump    E  Use    V  Camera    TAB  Map    ESC  Menu", 14, Color("c2d3dc")))
	reticle = label("·", 30, Color("d0e5e8"))
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-5, -22)
	chrome.add_child(reticle)
	hint = outlined("", 22, MINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-450, -190)
	hint.size = Vector2(900, 60)
	chrome.add_child(hint)
	waypoint = outlined("", 20, MINT)
	chrome.add_child(waypoint)
	map_panel = PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", style(Color(0.025, 0.06, 0.09, 0.95)))
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	map_panel.position = Vector2(-310, -365)
	map_panel.size = Vector2(270, 320)
	chrome.add_child(map_panel)
	var map_vbox := VBoxContainer.new()
	map_panel.add_child(map_vbox)
	map_vbox.add_child(label("FACILITY PLAN / NORTH ↑", 13, MINT))
	var minimap := FacilityMap.new()
	minimap.explorer = player
	minimap.custom_minimum_size = Vector2(220, 260)
	map_vbox.add_child(minimap)
	map_panel.hide()
	for top: bool in [true, false]:
		var bar := ColorRect.new(); bar.color = Color.BLACK
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(bar); bars.append(bar)
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", style(Color(0.035,0.12,0.15,0.96), MINT, 8))
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_panel.position = Vector2(-330, 28)
	toast_panel.size = Vector2(660, 78)
	toast_panel.hide()
	screen.add_child(toast_panel)
	var toast_text := label("", 17, Color.WHITE)
	toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_text.custom_minimum_size.x = 610
	toast_panel.add_child(toast_text)
	countdown_hud = outlined("", 86, GOLD)
	countdown_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	countdown_hud.position = Vector2(-250, 120)
	countdown_hud.size = Vector2(500, 110)
	countdown_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(countdown_hud)
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 0); fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)

func clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	if launch_clock >= 0 or is_instance_valid(sim): return
	player.enabled = true
	refresh_state(); update_objectives()
	if not capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func new_overlay() -> VBoxContainer:
	clear_overlay()
	player.enabled = false
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay = ColorRect.new()
	overlay.color = Color(0.01, 0.025, 0.04, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", style(Color(0.05, 0.1, 0.15, 0.97), Color("395467"), 16))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	return content

func show_toast(message: String) -> void:
	if not is_instance_valid(toast_panel): return
	var toast_label: Label = toast_panel.get_child(0)
	toast_label.text = message
	toast_panel.size = Vector2(660, 0)
	toast_panel.show()
	toast_time = 5.5

func go_to(scene: String, note: String) -> void:
	if leaving: return
	leaving = true
	var content := new_overlay()
	content.add_child(label(note, 30, MINT))
	content.add_child(label("Preparing the next scene…", 18, Color("b1c4d0")))
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(scene)

# ---------------------------------------------------------------- menus

func show_welcome() -> void:
	var content := new_overlay()
	content.add_child(label("EARTH OPERATIONS   /   EXPEDITION %d" % campaign.expedition_number, 14, MINT))
	if campaign.status == "ACTIVE":
		content.add_child(label("Your crew is in flight.", 44))
		content.add_child(para("An expedition is already under way. Rejoin it from the title screen, or walk the lab while the vehicle is away. Procurement reopens when the crew returns."))
		content.add_child(primary("REJOIN THE EXPEDITION  →", func() -> void: go_to("res://scenes/expedition.tscn", "RETURNING TO THE EXPEDITION")))
		content.add_child(button("WALK THE LAB", clear_overlay))
		return
	if campaign.status == "FAILED":
		content.add_child(label("The last crew did not come home.", 40))
		content.add_child(para("That campaign's funds and points are forfeited. Start a new campaign with a fresh budget and prepare the next vehicle."))
		content.add_child(primary("START A NEW CAMPAIGN  →", func() -> void:
			campaign.restart(); lab = {"briefed": false, "suited": lab.suited, "solved": {}, "sim_rating": -1}; mission.solved_exercises.clear(); mission.briefing_complete = false
			save_state(); refresh_state(); show_welcome()))
		content.add_child(button("TITLE SCREEN", func() -> void: go_to("res://scenes/expedition.tscn", "RETURNING TO THE TITLE SCREEN")))
		return
	content.add_child(label("A long way home.", 44))
	content.add_child(label("It starts in this building." if campaign.expedition_number == 1 else "Welcome back, Commander.", 23))
	if campaign.last_grant > 0:
		content.add_child(para("Your last expedition returned %d points and earned a %d-credit grant. %d credits are ready for the next vehicle." % [campaign.last_score, campaign.last_grant, stock.credits], 18, GOLD))
	content.add_child(para("Walk the lab and get your Mars mission ready: take the briefing, pick your commander, buy and integrate the rocket, then launch from Pad LC-01. A cyan beam marks your next stop.\n\nWASD move · Shift run · Mouse look · E use consoles and talk to the crew."))
	content.add_child(primary("ENTER THE LAB  →", func() -> void:
		clear_overlay(); show_toast("Follow the cyan beam. Next: %s." % str(STEPS[step_index(next_step())][2]))))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); content.add_child(row)
	row.add_child(button("SETTINGS", show_menu))
	row.add_child(button("TITLE SCREEN", func() -> void: go_to("res://scenes/expedition.tscn", "RETURNING TO THE TITLE SCREEN")))
	content.add_child(label("FICTIONAL EARTH SPACEPORT · NASA EQUATIONS, TERRAIN AND RESEARCH ARE CITED IN-GAME", 12, Color("8fa6b5")))

func step_index(id: String) -> int:
	for i: int in range(STEPS.size()):
		if STEPS[i][0] == id: return i
	return STEPS.size() - 1

func show_menu(_first: bool = false) -> void:
	var content := new_overlay()
	content.add_child(label("EARTH OPERATIONS   /   PAUSED", 14, MINT))
	content.add_child(label("Take a breath.", 44))
	content.add_child(primary("RESUME  →", clear_overlay))
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 20)
	content.add_child(options)
	options.add_child(label("Graphics", 17))
	var quality_picker := OptionButton.new()
	quality_picker.add_item("Performance · fastest")
	quality_picker.add_item("Balanced · shadows, ambient occlusion, light shafts")
	quality_picker.add_item("High · adds 4× MSAA and bounce light")
	quality_picker.selected = quality
	quality_picker.item_selected.connect(set_quality)
	options.add_child(quality_picker)
	var sensitivity_row := HBoxContainer.new()
	content.add_child(sensitivity_row)
	sensitivity_row.add_child(label("Mouse sensitivity   ", 17))
	var slider := HSlider.new()
	slider.custom_minimum_size.x = 260
	slider.min_value = 0.0006
	slider.max_value = 0.004
	slider.step = 0.0001
	slider.value = player.sensitivity
	slider.value_changed.connect(func(value: float) -> void:
		player.sensitivity = value
		settings.load(Gfx.SETTINGS)
		settings.set_value("controls", "sensitivity", value)
		settings.save(Gfx.SETTINGS))
	sensitivity_row.add_child(slider)
	var volume_row := HBoxContainer.new()
	content.add_child(volume_row)
	volume_row.add_child(label("Music volume           ", 17))
	var volume := HSlider.new(); volume.custom_minimum_size.x = 260; volume.min_value = 0; volume.max_value = 1; volume.step = 0.05; volume.value = music.volume
	volume.value_changed.connect(music.set_volume); volume_row.add_child(volume)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	content.add_child(controls)
	controls.add_child(button("Fullscreen / F11", toggle_fullscreen))
	controls.add_child(button("Return to arrival", func() -> void:
		player.position = Vector3(0, 0.1, 23)
		player.rotation = Vector3.ZERO
		clear_overlay()))
	controls.add_child(button("Title screen", func() -> void: go_to("res://scenes/expedition.tscn", "RETURNING TO THE TITLE SCREEN")))
	controls.add_child(button("Quit", func() -> void: get_tree().quit()))

func toggle_fullscreen() -> void:
	var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_quality(index: int) -> void:
	quality = index
	Gfx.viewport_quality(get_viewport(), index)
	if is_instance_valid(facility):
		Gfx.grade(facility.environment, index, true)
		facility.environment.volumetric_fog_enabled = index > 0
		facility.sun.shadow_enabled = index > 0
	if not automated: Gfx.store_quality(index)

# ---------------------------------------------------------------- input and frame loop

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(sim): end_simulator({})
			elif launch_clock >= 0: pass
			elif is_instance_valid(overlay): clear_overlay()
			else: show_menu()
		if event.keycode == KEY_F11:
			toggle_fullscreen()
		if is_instance_valid(overlay) or launch_clock >= 0 or is_instance_valid(sim): return
		if event.keycode == KEY_TAB:
			map_panel.visible = not map_panel.visible
		if event.keycode == KEY_V:
			var first_person: bool = player.toggle_camera_view()
			show_toast("CAMERA  /  " + ("FIRST PERSON" if first_person else "THIRD PERSON"))
		if event.keycode == KEY_SPACE: player.request_jump()
		if event.physical_keycode == KEY_E: interact()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_instance_valid(overlay) and launch_clock < 0 and not is_instance_valid(sim): interact()

func interact() -> void:
	if not focused.is_empty(): open_station(str(focused.id))
	elif is_instance_valid(talker):
		talker.paused = 5.0
		var away: Vector3 = player.global_position - talker.global_position
		talker.rotation.y = atan2(-away.x, -away.z)
		show_toast("%s  /  %s\n“%s”" % [talker.display_name, talker.role, talker.line])
		beep(480, 0.08)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player) and not is_instance_valid(overlay) and not automated and launch_clock < 0 and not is_instance_valid(sim):
		show_menu()

func _process(delta: float) -> void:
	if capture and "--film-shot" in OS.get_cmdline_user_args() and launch_clock<0:
		player.camera_yaw += delta*.025
	music.update_mix(delta, 0.9 if launch_clock >= 0 else 0.0)
	if not is_instance_valid(player):
		return
	clock += delta
	var zone := room_at(player.position)
	if zone != last_room:
		last_room = zone
		visits[zone] = true
		room_label.text = zone
	stats.text = "%d FPS  /  %s" % [Engine.get_frames_per_second(), ["PERFORMANCE", "BALANCED", "HIGH"][quality]]
	if int(clock) != state_tick:
		state_tick = int(clock)
		refresh_state(); update_objectives()
	if smoke:
		var total: Dictionary = mission.totals()
		economy_label.text = "$%.0fM AVAILABLE  /  %d ASSETS" % [mission.budget_m, total.count]
		objective_label.text = "MISSION PHASE  /  " + mission.stage_name()
	else:
		economy_label.text = "%d CREDITS   ·   %.0f / 260 kg CARGO" % [stock.credits, stock.mass()]
		objective_label.text = "EXPEDITION %d  /  %s  /  QUOTA %d" % [campaign.expedition_number, campaign.status, campaign.quota()]
	facility.update_liftoff(delta)
	if facility.liftoff_active and launch_clock < 0 and not smoke and is_instance_valid(facility.launch_vehicle):
		var rocket_at: Vector3 = facility.launch_vehicle.global_position
		var look: Vector3 = rocket_at - (player.global_position + Vector3(0, 1.55, 0))
		player.camera_yaw = atan2(-look.x, -look.z)
		player.camera_pitch = minf(1.15, atan2(look.y, Vector2(look.x, look.z).length()))
	update_launch(delta)
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0: toast_panel.hide()
	focused = {}
	talker = null
	var busy := is_instance_valid(overlay) or launch_clock >= 0 or is_instance_valid(sim)
	if not busy:
		var camera: Camera3D = player.camera
		for station: Dictionary in facility.stations:
			var stand: Vector3 = station.stand
			if Vector2(stand.x - player.position.x, stand.z - player.position.z).length() < 1.7 and absf(player.position.y - stand.y) < 2.0:
				focused = station
				break
			var offset: Vector3 = station.position - camera.global_position
			if offset.length() < 7.5 and offset.normalized().dot(-camera.global_basis.z) > 0.90:
				var query := PhysicsRayQueryParameters3D.create(camera.global_position, station.position)
				query.exclude = [player.get_rid()]
				var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or camera.global_position.distance_to(hit.position) > offset.length() - 0.9:
					focused = station
					break
		for node: Node in get_children():
			if node is CharacterBody3D and node != player and node.get("tag") != null and is_instance_valid(node.tag):
				var distance: float = node.global_position.distance_to(player.global_position)
				node.tag.visible = distance < 9.0
				if focused.is_empty() and distance < 2.6 and (not is_instance_valid(talker) or distance < talker.global_position.distance_to(player.global_position)): talker = node
	hint.text = ""
	if not focused.is_empty(): hint.text = "[ E ]   " + str(focused.title)
	elif is_instance_valid(talker): hint.text = "[ E ]   TALK TO " + str(talker.display_name)
	reticle.modulate = MINT if hint.text != "" else Color.WHITE
	update_waypoint(busy)
	if capture:
		capture_frames += 1
		if capture_frames > 120:
			frame_times.append(delta)
		if capture_frames == 360:
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			image.save_png("res://../build/spaceport-" + capture_view + ".png")
			frame_times.sort()
			var total: float = 0
			for frame_time: float in frame_times:
				total += frame_time
			print("RENDER CHECK ", capture_view, " | mean FPS: ", snappedf(frame_times.size() / total, 0.1), " | p95 frame ms: ", snappedf(frame_times[int(frame_times.size() * 0.95)] * 1000, 0.1), " | draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			get_tree().quit()

func update_waypoint(busy: bool) -> void:
	var entry: Dictionary = facility.station_by_id(next_step())
	if busy or entry.is_empty():
		waypoint.text = ""
		return
	var stand: Vector3 = entry.stand
	var mark: Vector3 = stand + Vector3(0, 3.2, 0)
	var distance := player.global_position.distance_to(stand)
	var view := get_viewport().get_visible_rect().size
	var camera: Camera3D = player.camera
	if distance < 3.0: waypoint.text = ""
	elif camera.is_position_behind(mark):
		waypoint.text = "◆ %s  %d m  /  behind you" % [str(STEPS[step_index(str(entry.id))][2]), distance]
		waypoint.position = Vector2(view.x * 0.5 - 150, view.y - 250)
	else:
		var at: Vector2 = camera.unproject_position(mark)
		waypoint.text = "◆ %s  %d m" % [str(STEPS[step_index(str(entry.id))][2]), distance]
		waypoint.position = Vector2(clampf(at.x - 80, 60, view.x - 330), clampf(at.y - 30, 100, view.y - 250))

func room_at(p: Vector3) -> String:
	if p.z < -19:
		return "03 / LAUNCH COMPLEX"
	if p.x < -16:
		return "01 / OUTFITTING & CREW SYSTEMS"
	if p.x > 16:
		return "04 / MISSION CONTROL"
	if p.z < 13:
		return "02 / VEHICLE INTEGRATION"
	return "00 / ARRIVAL CONCOURSE"

func open_station(id: String) -> void:
	match id:
		"briefing": open_briefing()
		"crew": open_crew_locker()
		"shop": open_outfitter()
		"engineering": open_engineering_manifest()
		"science": open_equation_lab()
		"simulator": open_simulator()
		"field_systems": open_field_systems()
		"launch": open_launch_control()

# ---------------------------------------------------------------- stations: campaign play

func open_briefing() -> void:
	if automated:
		open_mission_briefing(); return
	var content := new_overlay()
	var profile: Dictionary = mission.exercise_data.mission
	content.add_child(label("MISSION CONTROL  /  FLIGHT DIRECTOR BRIEFING  /  EXPEDITION %d" % campaign.expedition_number, 14, MINT))
	content.add_child(label(str(profile.title), 34))
	content.add_child(para(str(profile.objective), 20, Color("d9e8ed"), 820))
	var cards := HBoxContainer.new(); cards.add_theme_constant_override("separation", 12); content.add_child(cards)
	card(cards, "CREW", str(profile.crew)); card(cards, "ON MARS", "2 FINDS · 2 DISTRICTS"); card(cards, "RETURN QUOTA", "%d SCIENCE" % campaign.quota()); card(cards, "BUDGET", "%d CREDITS" % stock.credits)
	content.add_child(para("FLIGHT DIRECTOR AMINA RAHMAN\n“Every kilogram changes the mission. Outfit the vehicle, clear integration, then meet me at the pad. If the crew does not come home, the campaign ends, so bring them home.”", 18, Color("b7cad4"), 820))
	content.add_child(para("Optional before launch: solve the three Flight Lab calculations for +5 science each, and fly the descent simulator for extra landing fuel.", 16, GOLD, 820))
	if campaign.status != "PLANNING":
		content.add_child(para("Expedition status: %s. Launch preparation reopens when it is resolved." % campaign.status, 16, Color("ef8d6d"), 820))
	content.add_child(primary("ACCEPT COMMAND  →", func() -> void:
		lab.briefed = true; mission.accept_briefing(); save_state(); clear_overlay()
		show_toast("MISSION ACCEPTED\nNext: %s." % str(STEPS[step_index(next_step())][2]))))

func open_crew_locker(variant: int = -1, suit: int = -1) -> void:
	if variant < 0: variant = player.avatar_variant
	if suit < 0: suit = player.suit_index
	var content := new_overlay()
	content.add_child(label("CREW SYSTEMS  /  LOCKER 01", 14, MINT))
	content.add_child(label("Choose your commander", 34))
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation", 26); content.add_child(columns)
	var viewport := SubViewport.new(); viewport.size = Vector2i(440, 560); viewport.own_world_3d = true; viewport.msaa_3d = Viewport.MSAA_4X
	var viewer := SubViewportContainer.new(); viewer.custom_minimum_size = Vector2(360, 458); viewer.stretch = true; viewer.add_child(viewport); columns.add_child(viewer)
	var world := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("0c1a24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("b9d2e6"); env.ambient_light_energy = 0.75; env.tonemap_mode = Environment.TONE_MAPPER_ACES; world.environment = env; viewport.add_child(world)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-32, -38, 0); key.light_energy = 1.9; key.light_color = Color("fff1de"); viewport.add_child(key)
	var rim := OmniLight3D.new(); rim.position = Vector3(-1.6, 1.9, -1.4); rim.light_color = MINT; rim.omni_range = 6; rim.light_energy = 2.4; viewport.add_child(rim)
	var floor_disc := MeshInstance3D.new(); var disc := CylinderMesh.new(); disc.top_radius = 0.75; disc.bottom_radius = 0.8; disc.height = 0.06; floor_disc.mesh = disc
	floor_disc.material_override = Gfx.emissive(Color("123a44"), 0.25); floor_disc.position.y = -0.03; viewport.add_child(floor_disc)
	var preview := Humanoid.new(); viewport.add_child(preview)
	preview.build(Color(str(Humanoid.SUITS[suit].color)), Color("55e7dd"), false, variant, false, "COMMANDER")
	preview.rotation.y = PI + 0.35
	preview.create_tween().set_loops().tween_property(preview, "rotation:y", TAU, 14.0).as_relative()
	var camera := Camera3D.new(); viewport.add_child(camera); camera.fov = 34; camera.position = Vector3(0, 1.02, 3.6); camera.look_at(Vector3(0, 0.95, 0))
	var side := VBoxContainer.new(); side.custom_minimum_size.x = 420; side.add_theme_constant_override("separation", 12); columns.add_child(side)
	side.add_child(label("CALLSIGN", 12, MINT))
	var names := HBoxContainer.new(); names.add_theme_constant_override("separation", 8); side.add_child(names)
	for i: int in range(Humanoid.CREW.size()):
		var choice := i
		var pick := button(("● " if i == variant else "") + str(Humanoid.CREW[i].callsign), func() -> void: open_crew_locker(choice, suit))
		if i == variant: pick.add_theme_stylebox_override("normal", style(Color("25515a"), MINT, 7))
		names.add_child(pick)
	side.add_child(label("FLIGHT SUIT", 12, MINT))
	var suits := GridContainer.new(); suits.columns = 2; suits.add_theme_constant_override("h_separation", 8); suits.add_theme_constant_override("v_separation", 8); side.add_child(suits)
	for i: int in range(Humanoid.SUITS.size()):
		var choice := i
		var swatch := button(("● " if i == suit else "") + str(Humanoid.SUITS[i].name), func() -> void: open_crew_locker(variant, choice))
		var tint := Color(str(Humanoid.SUITS[i].color))
		swatch.add_theme_stylebox_override("normal", style(tint.darkened(0.45), MINT if i == suit else tint, 7))
		swatch.custom_minimum_size.x = 200
		suits.add_child(swatch)
	side.add_child(para("Commander %s leads the crew through launch, landing and every walk on Mars. On the surface the pressure suit carries this colour on its running lights." % str(Humanoid.CREW[variant].callsign), 16, Color("b1c4d0"), 400))
	side.add_child(primary("SUIT UP AS %s  →" % str(Humanoid.CREW[variant].callsign), func() -> void:
		player.choose_avatar(variant, suit, not automated); lab.suited = true; save_state(); clear_overlay()
		show_toast("COMMANDER %s REPORTING\nNext: %s." % [str(Humanoid.CREW[variant].callsign), str(STEPS[step_index(next_step())][2])])))
	side.add_child(button("CANCEL", clear_overlay))

func open_outfitter() -> void:
	if automated:
		open_mission_shop(); return
	refresh_state()
	var content := new_overlay()
	content.add_child(label("OUTFITTING  /  ROCKET & EXPEDITION PROCUREMENT", 14, MINT))
	content.add_child(label("Pack the mission", 34))
	var gaps := campaign.missing(stock)
	var cards := HBoxContainer.new(); cards.add_theme_constant_override("separation", 12); content.add_child(cards)
	card(cards, "CREDITS", str(stock.credits)); card(cards, "CARGO", "%.0f / 260 kg" % stock.mass()); card(cards, "ROCKET", "COMPLETE" if gaps.is_empty() else "%d PARTS MISSING" % gaps.size()); card(cards, "KITS PACKED", str(stock.kits.size()))
	if campaign.status != "PLANNING":
		content.add_child(para("Procurement is locked while the campaign is %s." % campaign.status, 17, Color("ef8d6d")))
	elif gaps.is_empty():
		content.add_child(para("Rocket components are aboard. Add field kits if you have credits to spare; keep at least 88 for the crew architecture you will choose at the pad.", 18, MINT))
	else:
		content.add_child(para("Recommended for a first flight: every required rocket component plus a starter outpost (two solar arrays, battery, oxygen plant, shelter, fabricator, relay, weather mast and ice drill).", 18))
		content.add_child(primary("PACK THE RECOMMENDED ROCKET & OUTPOST  →", func() -> void:
			var reason: String = stock.recommended_pack()
			if reason == "" and not stock.write_draft(): reason = "Equipment could not be saved. Try again."
			beep(880, 0.15); open_outfitter()
			show_toast("EQUIPMENT PACKED\nGround crew is moving it to the high bay." if reason == "" else reason)))
	content.add_child(button("OPEN THE FULL CATALOG / 3D HARDWARE VIEWER", func() -> void: preload("res://scripts/outpost_shop.gd").new().show_shop(self, "Launch", "launch_core")))
	content.add_child(button("RETURN TO THE LAB", clear_overlay))

func open_field_systems() -> void:
	preload("res://scripts/outpost_shop.gd").new().show_shop(self)

func open_campaign_board() -> void:
	refresh_state()
	var content := new_overlay()
	content.add_child(label("VEHICLE INTEGRATION  /  EXPEDITION %d" % campaign.expedition_number, 14, MINT))
	content.add_child(label("Clear the rocket for flight", 34))
	var gaps := campaign.missing(stock)
	if not gaps.is_empty():
		content.add_child(para("The vehicle is incomplete. Missing components:\n" + ", ".join(gaps), 17, Color("ef8d6d")))
		content.add_child(primary("GO TO THE OUTFITTER  →", open_outfitter))
	elif not campaign.integrated:
		var prompts := ["Technicians are about to work on the engines. What must happen first?", "Guidance, pressure and descent sensors disagree by a small amount. How do you clear them?", "The stack is ready to arm. What is the last gate?"]
		content.add_child(label("PROCEDURE %d OF 3" % (campaign.integration_step + 1), 15, GOLD))
		content.add_child(para(prompts[campaign.integration_step], 22, Color("e4edf2")))
		var answers := [["Arm the vehicle now", "ISOLATE propulsion and electrical buses", "Bypass the protections"], ["Ignore the sensors", "Trust a single display", "CROSS-CHECK independent sensors"], ["CLEAR the range and confirm the crew", "Launch without clearance", "Disable guidance"]]
		for i: int in range(3):
			var choice := i
			content.add_child(button(answers[campaign.integration_step][i], func() -> void:
				var before: int = campaign.integration_step
				var reason: String = campaign.integrate(stock, choice)
				facility.set_integration(3 if campaign.integrated else campaign.integration_step)
				if reason != "": show_toast(reason); beep(190, 0.3); player.shake(0.3)
				else: show_toast("VEHICLE CLEARED FOR FLIGHT\nReport to Launch Control at Pad LC-01." if campaign.integrated else "PROCEDURE %d VERIFIED" % (before + 1)); beep(880, 0.16)
				open_campaign_board()))
		content.add_child(para("A wrong answer resets the sequence. Watch the stack light beside this console: one lamp per verified procedure.", 15))
	else:
		content.add_child(para("All three procedures are verified and the stack light is green. Walk through the north door to Pad LC-01 and report to Launch Control.", 20, MINT))
	content.add_child(button("RETURN TO THE LAB", clear_overlay))

func open_simulator() -> void:
	var content := new_overlay()
	content.add_child(label("DESCENT SIMULATOR  /  MOTION BASE 01", 14, MINT))
	content.add_child(label("Fly the last 250 metres", 34))
	content.add_child(para("Mars has about 1% of Earth's surface air pressure, so a crew vehicle cannot land on parachutes alone. Practise the engine-powered final descent here: brake with the main engine, steer to the pad and touch down slower than 3 m/s."))
	content.add_child(para("HOLD SPACE  fire the engine      W A S D  steer      ENTER  autopilot", 18, GOLD))
	content.add_child(para("Best rating: %s. A GOOD or PERFECT rating adds landing fuel to the real descent." % ("not flown yet" if int(lab.sim_rating) < 0 else str(LandingSim.RATINGS[int(lab.sim_rating)])), 17, MINT))
	content.add_child(primary("START TRAINING RUN  →", start_simulator))
	content.add_child(button("RETURN TO THE LAB", clear_overlay))

func start_simulator() -> void:
	if is_instance_valid(overlay): overlay.queue_free(); overlay = null
	player.enabled = false; player.velocity = Vector3.ZERO
	chrome.hide(); toast_panel.hide()
	sim = LandingSim.new(); add_child(sim)
	sim.finished.connect(end_simulator)
	var rng := RandomNumberGenerator.new(); rng.randomize()
	sim.start({"training": true, "seed": rng.randi_range(1, 9999)})
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func end_simulator(result: Dictionary) -> void:
	if not is_instance_valid(sim): return
	sim.queue_free(); sim = null
	player.camera.current = true; chrome.show()
	if not result.is_empty() and int(result.rating) > int(lab.sim_rating):
		lab.sim_rating = int(result.rating); save_state()
	clear_overlay()
	if not result.is_empty(): show_toast("SIMULATOR  /  %s\nPilot rating recorded for launch day." % str(result.label))

func open_launch_director() -> void:
	refresh_state()
	var content := new_overlay()
	content.add_child(label("LAUNCH CONTROL  /  PAD LC-01  /  GO – NO-GO", 14, MINT))
	content.add_child(label("Commit the crew", 34))
	var gaps := campaign.missing(stock)
	var cost := int(Model.LOADOUTS[selected_loadout].cost)
	var checks := [["Mission briefing accepted", bool(lab.briefed)], ["Commander suited", bool(lab.suited)], ["Rocket components aboard", gaps.is_empty()], ["Vehicle integration verified", campaign.integrated and gaps.is_empty()], ["%d credits held for the crew architecture" % cost, stock.credits >= cost], ["Campaign ready for a new launch", campaign.status == "PLANNING"]]
	var ready := true
	var poll := GridContainer.new(); poll.columns = 2; poll.add_theme_constant_override("h_separation", 34); content.add_child(poll)
	for check: Array in checks:
		ready = ready and bool(check[1])
		poll.add_child(label(("GO        " if check[1] else "NO-GO  ") + str(check[0]), 17, MINT if check[1] else Color("ef8d6d")))
	content.add_child(label("CREW ARCHITECTURE", 12, MINT))
	var crew_row := HBoxContainer.new(); crew_row.add_theme_constant_override("separation", 10); content.add_child(crew_row)
	for i: int in range(Model.LOADOUTS.size()):
		var choice := i
		var item: Dictionary = Model.LOADOUTS[i]
		var pick := button("%s%s\n%d credits · %d t" % ["● " if i == selected_loadout else "", item.name, item.cost, item.mass], func() -> void: selected_loadout = choice; open_launch_director())
		if i == selected_loadout: pick.add_theme_stylebox_override("normal", style(Color("25515a"), MINT, 7))
		pick.custom_minimum_size = Vector2(250, 66); crew_row.add_child(pick)
	content.add_child(para(str(Model.LOADOUTS[selected_loadout].detail), 16))
	content.add_child(label("LANDING APPROACH", 12, MINT))
	var site_row := HBoxContainer.new(); site_row.add_theme_constant_override("separation", 10); content.add_child(site_row)
	for i: int in range(2):
		var choice := i
		var pick := button(("● " if i == selected_site else "") + ["BASIN  /  gentler entry", "UPLAND  /  +15 science, −12 integrity"][i], func() -> void: selected_site = choice; open_launch_director())
		if i == selected_site: pick.add_theme_stylebox_override("normal", style(Color("25515a"), MINT, 7))
		pick.custom_minimum_size.x = 380; site_row.add_child(pick)
	content.add_child(para("Bonuses riding with you: Flight Lab %d / 3 (+%d science)   ·   simulator %s (+%d%% landing fuel)" % [solved_count(), solved_count() * 5, "not flown" if int(lab.sim_rating) < 0 else str(LandingSim.RATINGS[int(lab.sim_rating)]).to_lower(), maxi(0, int(lab.sim_rating)) * 8], 15, GOLD))
	var go := primary("GO FOR LAUNCH  /  BOARD FRONTIER 01  →", begin_real_launch)
	go.disabled = not ready
	content.add_child(go)
	if not ready: content.add_child(para("Clear every NO-GO item first. The cyan beam marks your next station.", 15, Color("ef8d6d")))
	content.add_child(button("RETURN TO THE PAD", clear_overlay))

# ---------------------------------------------------------------- launch cinematic

func begin_real_launch() -> void:
	if launch_clock >= 0: return
	if is_instance_valid(overlay): overlay.queue_free(); overlay = null
	launch_clock = 0.0
	player.enabled = false; player.velocity = Vector3.ZERO; player.avatar.hide()
	chrome.hide(); facility.point_guide("")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if capture else Input.MOUSE_MODE_CAPTURED
	launch_cam.current = true
	launch_cam.position = Vector3(-17, 2.0, -36); launch_cam.look_at(Vector3(0, 15, -50))
	show_toast("CREW ABOARD  /  ACCESS ARM RETRACTING\nTerminal count begins.")

func update_launch(delta: float) -> void:
	bar_height = lerpf(bar_height, 84.0 if launch_clock >= 0 else 0.0, 1 - exp(-delta * 4))
	bars[0].offset_bottom = bar_height
	bars[1].offset_top = -bar_height
	if launch_clock < 0:
		rumble.volume_db = lerpf(rumble.volume_db, -60.0, 0.1)
		return
	var previous := 11.0 - launch_clock
	launch_clock += delta
	var count := 11.0 - launch_clock
	if count > 0:
		countdown_hud.show(); countdown_hud.text = "T−%02d" % ceili(count)
		for mark: int in [10, 5, 3, 2, 1]:
			if previous > mark and count <= mark: countdown_callout(mark); beep(660 if mark > 3 else 880, 0.12)
	if count <= 3.0 and not facility.ignited:
		facility.ignite()
	if count <= 0 and not facility.liftoff_active:
		facility.start_liftoff(); countdown_hud.text = "LIFTOFF"; beep(1040, 0.5)
		show_toast("LIFTOFF  /  MISSION COMMITTED\nFrontier 01 has cleared the tower.")
	if count < -3.5: countdown_hud.hide()
	var rocket_at: Vector3 = facility.launch_vehicle.global_position
	var power := 0.0
	if facility.ignited: power = clampf(1.0 - (rocket_at.y - 10.5) / 260.0, 0.25, 1.0)
	rumble.volume_db = lerpf(rumble.volume_db, linear_to_db(maxf(0.001, power * 0.9)), 0.08)
	var wanted: Vector3
	var aim: Vector3
	if count > 4.0:
		wanted = Vector3(-17 + launch_clock * 0.55, 2.0 + launch_clock * 0.12, -36.5)
		aim = Vector3(0, 14, -50)
	elif count > -1.2:
		wanted = Vector3(-10.5, 2.3, -42.5)
		aim = Vector3(0, 5.0 + maxf(0, -count) * 2.0, -50)
	else:
		wanted = Vector3(-34, 4.0, -22)
		aim = rocket_at + Vector3(0, -2, 0)
		launch_cam.fov = lerpf(launch_cam.fov, 40.0, 1 - exp(-delta * 0.8))
	launch_cam.position = launch_cam.position.lerp(wanted, 1 - exp(-delta * (5.0 if count > -1.2 else 1.3)))
	launch_cam.look_at(aim)
	launch_cam.h_offset = randf_range(-1, 1) * power * 0.09
	launch_cam.v_offset = randf_range(-1, 1) * power * 0.09
	if count < -8.0: fade.color.a = clampf((-count - 8.0) / 1.6, 0, 1)
	if count < -9.8 and not leaving:
		leaving = true
		if capture: return
		get_tree().set_meta("ground_manifest", {"mass": 0.0, "power": 0.0, "loadout": selected_loadout, "site": selected_site, "seed": selected_seed, "lab_science": solved_count() * 5, "fuel_bonus": maxi(0, int(lab.sim_rating)) * 8.0})
		if not smoke: get_tree().change_scene_to_file("res://scenes/expedition.tscn")

func begin_launch_sequence() -> void:
	if not player.first_person: player.toggle_camera_view()
	facility.start_liftoff()
	countdown_hud.text = "LIFTOFF"
	if not smoke and not capture:
		await get_tree().create_timer(7.0).timeout
		get_tree().set_meta("ground_manifest",mission.totals())
		get_tree().change_scene_to_file("res://scenes/expedition.tscn")

func countdown_callout(value: int) -> void:
	var callouts := {10:"TERMINAL COUNT", 5:"GUIDANCE INTERNAL", 3:"ENGINE START SEQUENCE", 2:"THRUST BUILDING", 1:"COMMIT"}
	show_toast("T−%02d  /  %s" % [value, callouts.get(value, "COUNTING")])

# ---------------------------------------------------------------- stations shared with the ground-systems checks

func open_mission_briefing() -> void:
	var content := new_overlay()
	var profile: Dictionary = mission.exercise_data.mission
	content.add_child(label("MISSION CONTROL  /  FLIGHT DIRECTOR BRIEFING", 14, MINT))
	content.add_child(label(str(profile.title), 34))
	content.add_child(para(str(profile.objective), 20, Color("d9e8ed"), 820))
	var cards := HBoxContainer.new(); cards.add_theme_constant_override("separation", 12); content.add_child(cards)
	card(cards, "CREW", str(profile.crew)); card(cards, "SURFACE STAY", "%d DAYS" % profile.surfaceDays); card(cards, "BUDGET", "$%.1fB" % (mission.budget_m / 1000.0)); card(cards, "DECISION GATES", "3 CALCULATIONS")
	content.add_child(para("FLIGHT DIRECTOR AMINA RAHMAN\n“Every kilogram changes the mission. Procure the survival architecture, prove the numbers, then meet me at Launch Operations.”", 18, Color("b7cad4"), 820))
	content.add_child(para(str(profile.architectureNote), 13, GOLD, 820))
	content.add_child(primary("ACCEPT COMMAND  /  BEGIN OUTFITTING  →", func() -> void:
		mission.accept_briefing(); clear_overlay(); show_toast("MISSION ACCEPTED  /  PHASE 02 OUTFITTING\nProceed to Outfitting.")))

func open_equation_lab() -> void:
	var content := new_overlay()
	content.add_child(label("MISSION CONTROL  /  NASA FLIGHT LAB", 14, MINT))
	content.add_child(label("Prove the mission before launch", 34))
	content.add_child(label("Solve each engineering check for +5 starting science. Commas are optional. A wrong answer shows a hint and costs nothing.", 14, Color("a9bfce")))
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(970, 500); content.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 10); scroll.add_child(list)
	for exercise: Dictionary in mission.exercise_data.exercises:
		var solved: bool = mission.solved_exercises.get(str(exercise.id), false)
		var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", style(Color("102c37") if solved else Color("142838"), MINT if solved else Color("355064"), 7)); list.add_child(panel)
		var box := VBoxContainer.new(); panel.add_child(box)
		box.add_child(label(("✓ VALIDATED  /  " if solved else str(exercise.station) + "  /  ") + str(exercise.title), 18, MINT if solved else GOLD))
		box.add_child(para(str(exercise.prompt), 15, Color("e4edf2"), 900))
		box.add_child(label(str(exercise.equation), 18, Color("d7f8f4")))
		box.add_child(para(str(exercise.evidence), 12, Color("91aab8"), 900))
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); box.add_child(row)
		if not solved:
			var answer := LineEdit.new(); answer.placeholder_text = "Numeric answer in " + str(exercise.unit); answer.custom_minimum_size = Vector2(300, 44); row.add_child(answer)
			answer.text_submitted.connect(func(value: String) -> void: submit_flight_answer(str(exercise.id), value))
			row.add_child(button("SUBMIT", func() -> void: submit_flight_answer(str(exercise.id), answer.text)))
		row.add_child(button("NASA SOURCE ↗", func() -> void: OS.shell_open(str(exercise.sourceUrl))))
	var footer := HBoxContainer.new(); footer.add_theme_constant_override("separation", 12); content.add_child(footer)
	footer.add_child(button("RETURN TO THE LAB", clear_overlay))

func submit_flight_answer(id: String, answer: String) -> void:
	var result: Dictionary = mission.submit_exercise(id, answer)
	if result.correct:
		lab.solved[id] = true; save_state(); beep(880, 0.16)
	else: beep(190, 0.25)
	show_toast(str(result.message))
	open_equation_lab()

func open_mission_shop(category := "ALL") -> void:
	var content := new_overlay()
	content.add_child(label("SUPPLY & OUTFITTING  /  NASA-INFORMED MISSION CATALOG", 14, MINT))
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 24); content.add_child(head)
	head.add_child(label("Mission hardware", 34))
	var funds := label("$%.0fM available" % mission.budget_m, 22, GOLD); funds.size_flags_horizontal = Control.SIZE_EXPAND_FILL; funds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; head.add_child(funds)
	content.add_child(label("Published NASA values, architecture targets, and gameplay estimates are labeled separately.", 14, Color("a9bfce")))
	var category_row := HBoxContainer.new(); category_row.add_theme_constant_override("separation", 7); content.add_child(category_row)
	for name: String in ["ALL", "Spacecraft", "Life Support", "Consumables", "Propulsion", "Mars ISRU", "Power", "Surface", "Safety"]:
		var cat_button := button(name, func() -> void: open_mission_shop(name)); cat_button.custom_minimum_size.y = 38; category_row.add_child(cat_button)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(970, 440); content.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 8); scroll.add_child(list)
	for item: Dictionary in mission.catalog.items:
		if category != "ALL" and str(item.category) != category: continue
		var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", style(Color("142838"), Color("355064"), 7)); list.add_child(panel)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); panel.add_child(row)
		var details := VBoxContainer.new(); details.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(details)
		details.add_child(label(str(item.name) + "  /  " + str(item.variant), 19, MINT))
		details.add_child(label("%s  •  %s" % [item.category, item.sourceClass], 12, GOLD))
		details.add_child(label("Mass %s kg   Power %+.1f kW   %s" % [format_number(float(item.massKg)), float(item.powerKw), item.note], 13, Color("b6c7d1")))
		var owned := int(mission.inventory.get(item.id, 0))
		var buy := button("BUY  $%.0fM\nOwned %d" % [float(item.costM), owned], func() -> void:
			if mission.buy(item): show_toast("PROCURED  /  " + str(item.name) + "\nDelivery assigned to the integration queue."); open_mission_shop(category)
			else: show_toast("PROCUREMENT BLOCKED  /  INSUFFICIENT BUDGET"))
		buy.custom_minimum_size = Vector2(170, 65); row.add_child(buy)
	var foot := HBoxContainer.new(); foot.add_theme_constant_override("separation", 12); content.add_child(foot)
	foot.add_child(button("PROCURE RECOMMENDED BASELINE", func() -> void:
		var count: int = mission.buy_baseline(); show_toast("BASELINE LOADOUT  /  %d ORDERS PLACED\nGround crew delivery timers started." % count); open_mission_shop(category)))
	foot.add_child(button("NASA SOURCES", open_source_ledger)); foot.add_child(button("ENGINEERING MANIFEST", open_engineering_manifest)); foot.add_child(button("RETURN TO FACILITY", clear_overlay))

func format_number(value: float) -> String:
	var raw := str(int(value)); var out := ""
	for i: int in range(raw.length()):
		if i > 0 and (raw.length() - i) % 3 == 0: out += ","
		out += raw[i]
	return out

func open_source_ledger() -> void:
	var content := new_overlay(); content.add_child(label("MISSION DATA  /  SOURCE LEDGER", 14, MINT)); content.add_child(label("Trace every design input", 34))
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(900, 480); content.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(list)
	for id: String in mission.catalog.sources:
		var source: Dictionary = mission.catalog.sources[id]
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); list.add_child(row)
		var text := label(id + "  /  " + str(source.title), 16); text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(text)
		row.add_child(button("OPEN NASA SOURCE ↗", func() -> void: OS.shell_open(str(source.url))))
	content.add_child(label("Catalog costs and many concept masses are gameplay estimates, never NASA procurement data.", 14, GOLD))
	content.add_child(button("BACK TO CATALOG", open_mission_shop))

func open_engineering_manifest() -> void:
	if not automated: open_campaign_board(); return
	var content := new_overlay(); content.add_child(label("VEHICLE INTEGRATION  /  MISSION DESIGN REVIEW", 14, MINT)); content.add_child(label("Architecture manifest", 34))
	var t: Dictionary = mission.totals(); var cards := HBoxContainer.new(); cards.add_theme_constant_override("separation", 10); content.add_child(cards)
	card(cards, "PURCHASED", "%d" % t.count, 205); card(cards, "MISSION MASS", "%s kg" % format_number(t.mass), 205); card(cards, "NET POWER LOAD", "%+.1f kW" % t.power, 205); card(cards, "BUDGET", "$%.0fM" % mission.budget_m, 205)
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation", 20); content.add_child(columns)
	var manifest := VBoxContainer.new(); manifest.custom_minimum_size = Vector2(525, 390); columns.add_child(manifest); manifest.add_child(label("INSTALLED / DELIVERING HARDWARE", 14, GOLD))
	var any := false
	for item: Dictionary in mission.catalog.items:
		var count := int(mission.inventory.get(item.id, 0))
		if count > 0: any = true; manifest.add_child(label("%d × %s  /  %s" % [count, item.name, item.variant], 14))
	if not any: manifest.add_child(label("No hardware procured. Visit Outfitting.", 17, Color("a9bfce")))
	var readiness_box := VBoxContainer.new(); readiness_box.custom_minimum_size.x = 390; columns.add_child(readiness_box); readiness_box.add_child(label("FLIGHT READINESS", 14, GOLD))
	var missing: Array[String] = mission.readiness()
	if missing.is_empty(): readiness_box.add_child(label("GO  /  All mandatory capabilities installed", 18, MINT))
	else:
		readiness_box.add_child(label("HOLD  /  %d requirements open" % missing.size(), 18, Color("ef8d6d")))
		for requirement: String in missing: readiness_box.add_child(label("○  " + requirement, 13))
	readiness_box.add_child(label("\nConsumables\nO₂: %s kg\nWater: %s kg\nFood: %s crew-mission days" % [format_number(t.oxygen), format_number(t.water), format_number(t.food)], 15))
	var calculation_gaps: Array[String] = mission.calculation_gaps()
	readiness_box.add_child(label("\nFLIGHT CALCULATIONS  /  %d OF %d VALIDATED" % [mission.exercise_data.exercises.size() - calculation_gaps.size(), mission.exercise_data.exercises.size()], 14, GOLD))
	for gap: String in calculation_gaps: readiness_box.add_child(label("○  " + gap, 12))
	var pending: int = mission.pending_delivery_count()
	readiness_box.add_child(label("\nGROUND LOGISTICS  /  %s" % ("ALL DELIVERED" if pending == 0 else "%d DELIVERIES ACTIVE" % pending), 13, MINT if pending == 0 else GOLD))
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 12); content.add_child(actions)
	actions.add_child(button("OPEN CATALOG", open_mission_shop)); actions.add_child(button("FLIGHT LAB", open_equation_lab)); actions.add_child(button("PROCEED TO LAUNCH COMPLEX", func() -> void: clear_overlay(); show_toast("FINAL STEP  /  REPORT TO LAUNCH OPERATIONS")))

func open_launch_control() -> void:
	if not automated: open_launch_director(); return
	var content := new_overlay(); content.add_child(label("LAUNCH COMPLEX 01  /  TERMINAL COUNT", 14, MINT))
	var countdown := label("T−10", 78, GOLD); countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; content.add_child(countdown)
	var missing: Array[String] = mission.authorization_gaps()
	if mission.mission_state == "LAUNCHED": countdown.text = "LIFTOFF"; content.add_child(label("Frontier 01 has cleared the tower. Mission committed and ascent sequence active.", 20, MINT))
	elif missing.is_empty():
		content.add_child(label("FLIGHT DIRECTOR: GO FOR TERMINAL COUNT\nRange clear · hardware delivered · equations validated · crew systems ready", 19, MINT))
		content.add_child(button("ARM AND START T−10", func() -> void: mission.begin_countdown(); clear_overlay(); show_toast("TERMINAL COUNT STARTED  /  T−10")))
	else:
		content.add_child(label("GROUND HOLD  /  %d AUTHORIZATION ITEMS OPEN" % missing.size(), 20, Color("ef8d6d")))
		for gap: String in missing.slice(0, 7): content.add_child(label("○  " + gap, 13))
		content.add_child(label("Complete the architecture, flight calculations, and deliveries before committing the crew.", 15))
	var launch_actions := HBoxContainer.new(); launch_actions.add_theme_constant_override("separation", 12); content.add_child(launch_actions)
	launch_actions.add_child(button("ENGINEERING REVIEW", open_engineering_manifest)); launch_actions.add_child(button("FLIGHT LAB", open_equation_lab)); launch_actions.add_child(button("RETURN TO PAD", clear_overlay))

func install_module(id: String, title: String) -> void:
	if is_instance_valid(facility.installed_module):
		facility.installed_module.queue_free()
	var module := Node3D.new()
	facility.add_child(module)
	facility.installed_module = module
	module.position = Vector3(8, 2.0, 4.5)
	facility.cylinder(Vector3.ZERO, 0.5, 1.1, "gold" if id == "power" else "white", -1, module)
	facility.cylinder(Vector3(0, 0.6, 0), 0.48, 0.1, "cyan", -1, module)
	module.set_meta("module_id", id)
	module.set_meta("title", title)

# ---------------------------------------------------------------- screenshots and checks

func setup_capture() -> void:
	# view: [position, camera yaw, camera pitch, first person]
	var views := {
		"arrival": [Vector3(0, 0.1, 26.2), 0.0, -0.02, false],
		"globe": [Vector3(3.4, 0.1, 22.8), 0.56, 0.22, true],
		"bay": [Vector3(-9.5, 0.1, 10.5), -0.62, 0.14, true],
		"shop": [Vector3(-17.6, 0.1, 5.4), PI / 2, 0.02, true],
		"lockers": [Vector3(-24.6, 0.1, 4.6), 1.25, 0.02, true],
		"control": [Vector3(24, 0.1, 13.4), 0.0, 0.1, true],
		"launch": [Vector3(-15, 0.1, -37), -0.857, 0.52, true],
		"liftoff": [Vector3(-15, 0.1, -37), -0.857, 0.52, true],
		"avatar": [Vector3(0, 0.1, 24.4), PI, -0.03, false],
		"crew": [Vector3(0, 0.1, 27.6), 0.0, -0.04, true],
		"simpod": [Vector3(4.4, 0.1, 22.4), -1.15, 0.12, true]}
	var view: Array = views.get(capture_view, views.arrival)
	player.position = view[0]; player.camera_yaw = view[1]; player.camera_pitch = view[2]
	if view[3] and not player.first_person: player.toggle_camera_view()
	match capture_view:
		"avatar": player.camera_distance = 3.0; player.camera_boom.spring_length = 3.0
		"crew":
			var staff: Array = get_children().filter(func(node: Node) -> bool: return node is CharacterBody3D and node != player)
			for i: int in range(staff.size()):
				staff[i].position = Vector3(-2.4 + i * 1.2, 0.1, 24.6); staff[i].rotation.y = PI; staff[i].paused = 999
		"liftoff": facility.start_liftoff()
		"countdown": launch_clock = -1.0; begin_real_launch(); launch_clock = 8.4
		"ascent": begin_real_launch(); launch_clock = 13.0; facility.start_liftoff(); facility.launch_velocity = 14.0
		"menu": show_menu(true)
		"welcome": show_welcome()
		"briefing": automated = false; open_briefing(); automated = true
		"locker": open_crew_locker()
		"outfitter": automated = false; open_outfitter(); automated = true
		"integration": automated = false; open_campaign_board(); automated = true
		"equations": open_equation_lab()
		"simui": open_simulator()
		"sim": start_simulator(); sim.autopilot_on = true
		"launchui": automated = false; open_launch_director(); automated = true
		"terminal": open_station("engineering")
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func smoke_test() -> void:
	player.enabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	var errors: Array[String] = []
	# Probe the actual capsule along each intended route, not just room centres.
	var waypoints: Array[Vector3] = [Vector3(0, 0.05, 23), Vector3(11, 0.05, 15), Vector3(11, 0.05, 4), Vector3(24, 0.05, 4), Vector3(11, 0.05, 4), Vector3(11, 0.05, 10), Vector3(0, 0.05, 10), Vector3(-12, 0.05, 4), Vector3(-24, 0.05, 4), Vector3(-7, 0.05, 4), Vector3(-7, 0.05, -14), Vector3(0, 0.05, -14), Vector3(0, 0.05, -38), Vector3(-12, 0.05, -38), Vector3(-12, 0.05, -58)]
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var dynamic_exclusions: Array[RID] = [player.get_rid()]
	for child: Node in get_children():
		if child is CharacterBody3D: dynamic_exclusions.append(child.get_rid())
	for i: int in range(waypoints.size() - 1):
		var start := waypoints[i]
		var end := waypoints[i + 1]
		var steps := ceili(start.distance_to(end) / 0.25)
		for j: int in range(steps + 1):
			var at := start.lerp(end, float(j) / maxf(steps, 1))
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.9, 0))
			query.exclude = dynamic_exclusions
			if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				errors.append("Blocked walk route at " + str(at))
				break
	# Every console must be reachable: its standing spot is free and close enough to trigger.
	for station: Dictionary in facility.stations:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, station.stand + Vector3(0, 0.95, 0))
		query.exclude = dynamic_exclusions
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): errors.append("Console standing spot blocked: " + str(station.id))
	for id: String in ["briefing", "crew", "shop", "engineering", "science", "simulator", "launch", "field_systems"]:
		if facility.station_by_id(id).is_empty(): errors.append("Missing console: " + id)
		open_station(id)
		await get_tree().process_frame
		if not is_instance_valid(overlay): errors.append("Console did not open: " + id)
		clear_overlay()
	# Campaign-facing consoles and the pause/welcome screens must build without errors.
	automated = false; campaign.persistent = false
	for screen_call: Callable in [open_briefing, open_outfitter, open_campaign_board, open_launch_director, show_welcome, show_menu]:
		screen_call.call()
		await get_tree().process_frame
		if not is_instance_valid(overlay): errors.append("Campaign screen failed to open")
		if is_instance_valid(overlay): overlay.queue_free(); overlay = null
	automated = true; player.enabled = false
	if step_done("launch") or next_step() == "": errors.append("Checklist order invalid")
	player.choose_avatar(1, 2, false)
	if player.avatar_variant != 1 or player.suit_index != 2 or not is_instance_valid(player.avatar.animation_player): errors.append("Commander selection did not rebuild the avatar")
	facility.set_integration(2)
	if facility.status_lamps[1].material_override != facility.mats.green or facility.status_lamps[2].material_override == facility.mats.green: errors.append("Integration stack light out of step")
	install_module("power", "Solar power module")
	if not is_instance_valid(facility.installed_module):
		errors.append("Module preview missing")
	if facility.stations.size() != 8:
		errors.append("Missing facility terminal")
	var slot := ModuleSlot.new()
	slot.caption = Label.new()
	slot.add_child(slot.caption)
	add_child(slot)
	if slot._can_drop_data(Vector2.ZERO, {"invalid": true}):
		errors.append("Drop slot accepted invalid data")
	var payload := {"module": "science", "title": "Science instrument bay"}
	if not slot._can_drop_data(Vector2.ZERO, payload):
		errors.append("Drop slot rejected a catalog module")
	slot.installed.connect(install_module)
	slot._drop_data(Vector2.ZERO, payload)
	if facility.installed_module.get_meta("module_id") != "science":
		errors.append("Drop did not replace installed preview")
	slot.queue_free()
	# Validate catalog economics, manifest aggregation, readiness gate and countdown.
	var starting_budget: float = mission.budget_m
	if not mission.buy(mission.catalog.items[0]): errors.append("Catalog purchase failed")
	if mission.budget_m >= starting_budget: errors.append("Purchase did not reduce budget")
	if int(mission.totals().count) != 1: errors.append("Manifest aggregation failed")
	if mission.begin_countdown(): errors.append("Incomplete mission bypassed readiness gate")
	for required_id: String in ["transit_hab", "mars_lander", "oga", "cdrs", "water_recovery", "food_500", "isru_plant", "fission_40", "surface_hab", "medical", "lox_tank", "water_1000"]:
		for item: Dictionary in mission.catalog.items:
			if str(item.id) == required_id: mission.buy(item); break
	if not mission.readiness().is_empty(): errors.append("Complete baseline mission did not pass readiness")
	if mission.begin_countdown(): errors.append("Hardware-only mission bypassed briefing/calculation gates")
	mission.accept_briefing()
	if mission.submit_exercise("mass_ratio", "1.0").correct: errors.append("Incorrect equation answer accepted")
	for answer: Array in [["mass_ratio", "2.85"], ["food_energy", "6,070,000"], ["comm_latency", "22"]]:
		if not mission.submit_exercise(answer[0], answer[1]).correct: errors.append("Valid equation answer rejected: " + answer[0])
	for delivery: Dictionary in mission.delivery_queue:
		delivery.announced = true
		if is_instance_valid(delivery.crate): delivery.crate.queue_free()
	if not mission.authorization_gaps().is_empty(): errors.append("Completed mission did not clear authorization gates")
	if not mission.begin_countdown(): errors.append("Authorized mission could not start countdown")
	mission.countdown = 0.01
	mission._process(0.02)
	await get_tree().process_frame
	if mission.mission_state != "LAUNCHED" or not facility.liftoff_active: errors.append("Countdown did not trigger physical liftoff")
	if not facility.ignited or facility.engine_flames.is_empty() or not facility.pad_smoke.emitting: errors.append("Ignition effects missing at liftoff")
	var launch_height: float = facility.launch_vehicle.position.y
	for frame: int in range(5): await get_tree().process_frame
	if facility.launch_vehicle.position.y <= launch_height: errors.append("Launch vehicle did not ascend")
	# Exercise real movement and collision against the arrival back wall.
	player.position = Vector3(0, 0.1, 27)
	player.velocity = Vector3.ZERO
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("backward")
	for frame: int in range(90):
		await get_tree().physics_frame
	Input.action_release("backward")
	if player.position.z > 28.5 or player.position.y < -0.1:
		errors.append("Player wall/floor collision failed")
	player.position = Vector3(0, 0.1, 23)
	player.velocity = Vector3.ZERO
	player.camera_yaw = 0.0
	player.set_test_move_input(Vector2(0, -1))
	for frame: int in range(24): await get_tree().physics_frame
	if player.position.z > 22.5: errors.append("W did not move toward camera forward")
	if player.avatar.animation_player.current_animation != "walk": errors.append("Casual walk animation did not engage")
	var heading := -player.global_basis.z
	var travel := Vector3(player.velocity.x, 0, player.velocity.z).normalized()
	if heading.dot(travel) < 0.9: errors.append("Body did not face travel direction")
	Input.action_press("sprint")
	for frame: int in range(20): await get_tree().physics_frame
	if player.avatar.animation_player.current_animation != "run": errors.append("Casual run animation did not engage")
	Input.action_release("sprint")
	var old_yaw: float = player.camera_yaw
	var old_pitch: float = player.camera_pitch
	player.apply_look(Vector2(100, -60))
	if is_equal_approx(player.camera_yaw, old_yaw) or is_equal_approx(player.camera_pitch, old_pitch):
		errors.append("Mouse look did not update yaw and pitch")
	player.position = Vector3(0, 0.1, 23)
	player.velocity = Vector3.ZERO
	player.camera_yaw = PI * 0.5
	for frame: int in range(24): await get_tree().physics_frame
	if player.position.x > -0.5: errors.append("W did not follow rotated camera heading")
	player.clear_test_move_input()
	if player.first_person: player.toggle_camera_view()
	if not player.toggle_camera_view() or player.avatar.visible: errors.append("First-person camera did not engage")
	if player.toggle_camera_view() or not player.avatar.visible: errors.append("Third-person camera did not restore")
	if player.avatar.find_children("*", "MeshInstance3D", true, false).is_empty():
		errors.append("Rigged character mesh missing")
	# The cinematic count must ignite, lift off and hand the manifest to the expedition.
	launch_clock = -1.0; facility.liftoff_active = false; facility.ignited = false
	begin_real_launch()
	for frame: int in range(46): update_launch(0.5)
	if not facility.liftoff_active or not leaving or not get_tree().has_meta("ground_manifest"): errors.append("Cinematic launch did not hand over to the expedition")
	elif int(get_tree().get_meta("ground_manifest").loadout) != selected_loadout: errors.append("Launch manifest lost the crew architecture")
	print("SMOKE CHECK: eight consoles, campaign screens, commander selection, checklist, briefing-to-liftoff flow, equations, ignition effects, cinematic launch handoff, first-person view, movement and collision")
	for error: String in errors:
		push_error(error)
	print("SMOKE RESULT: " + ("PASS" if errors.is_empty() else "FAIL"))
	get_tree().quit(0 if errors.is_empty() else 1)

func _exit_tree() -> void:
	Gfx.release_cache()
