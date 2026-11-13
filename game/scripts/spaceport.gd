extends Node3D
const Facility = preload("res://scripts/facility.gd")
const Player = preload("res://scripts/player.gd")
const FacilityMap = preload("res://scripts/facility_map.gd")
const ModuleCard = preload("res://scripts/module_card.gd")
const ModuleSlot = preload("res://scripts/module_slot.gd")
const MissionSystem = preload("res://scripts/mission_system.gd")
const MINT := Color("74eee2")
var facility: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var screen: Control
var overlay: Control
var room_label: Label
var hint: Label
var stats: Label
var visits_label: Label
var map_panel: Control
var reticle: Label
var focused: Dictionary = {}
var visits: Dictionary = {}
var clock: float = 0
var last_room: String = ""
var quality: int = 1
var settings := ConfigFile.new()
var smoke: bool = false
var capture: bool = false
var capture_frames: int = 0
var capture_view: String = "arrival"
var frame_times: Array[float] = []
var mission: Node
var economy_label: Label
var objective_label: Label
var toast_panel: PanelContainer
var toast_time := 0.0
var countdown_hud: Label
var test_card: Control
var test_slot: Control
var campaign_hud_tick := -1
var music: Node

func _ready() -> void:
	get_window().title = "Mohashunnyo — Mission Control 7"
	music = preload("res://scripts/music_director.gd").new(); add_child(music)
	configure_inputs()
	smoke = "--smoke" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture"):
			capture = true
			if "=" in argument:
				capture_view = argument.get_slice("=", 1)
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
	settings.load("user://settings.cfg")
	player.sensitivity = settings.get_value("controls", "sensitivity", 0.0021)
	quality = settings.get_value("video", "quality", 1)
	set_quality(quality)
	create_hud()
	mission = MissionSystem.new()
	add_child(mission)
	mission.setup(self)
	mission.countdown_label = countdown_hud
	if smoke:
		await smoke_test()
	elif capture:
		player.position = Vector3(10, 0.1, 20)
		player.rotation.y = 0.29
		player.camera.rotation.x = 0.1
		if capture_view == "shop":
			player.position = Vector3(-18, 0.1, 15)
			player.rotation.y = 0.5
			player.camera.rotation.x = 0.05
		elif capture_view == "launch":
			player.position = Vector3(-15, 0.1, -37)
			player.rotation.y = 0
			player.camera.look_at(Vector3(0, 10, -50))
		elif capture_view == "terminal":
			open_station("engineering")
		elif capture_view == "briefing":
			open_mission_briefing()
		elif capture_view == "equations":
			open_equation_lab()
		elif capture_view == "liftoff":
			player.position = Vector3(-14, 0.1, -39)
			player.camera_yaw = -0.90
			player.camera_pitch = 0.35
			if not player.first_person: player.toggle_camera_view()
			facility.start_liftoff()
		elif capture_view == "menu":
			show_menu(true)
		elif capture_view == "control":
			player.position = Vector3(24,0.1,11); player.camera_yaw = 0; player.camera_pitch = 0.09
			if not player.first_person: player.toggle_camera_view()
		elif capture_view == "crew":
			var npc: CharacterBody3D = get_children().filter(func(node: Node) -> bool: return node is CharacterBody3D and node != player)[0]
			npc.position = Vector3(24,0.1,10); npc.rotation.y = 0; npc.paused = 999
			player.position = Vector3(24,0.1,7.4); player.camera_yaw = PI; player.camera_pitch = -0.04
			if not player.first_person: player.toggle_camera_view()
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		show_menu(true)

func configure_inputs() -> void:
	var bindings := {"forward": [KEY_W, KEY_UP], "backward": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "sprint": [KEY_SHIFT]}
	for action: String in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action,event): InputMap.action_add_event(action, event)

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

func button(text: String, callable: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 49
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_stylebox_override("normal", style(Color("15313b"), Color("3b777a"), 7))
	b.add_theme_stylebox_override("hover", style(Color("25515a"), MINT, 7))
	b.add_theme_stylebox_override("focus", style(Color("25515a"), MINT, 7))
	b.pressed.connect(callable)
	return b

func create_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(screen)
	var header := VBoxContainer.new()
	header.position = Vector2(40, 30)
	header.add_theme_constant_override("separation", 5)
	screen.add_child(header)
	header.add_child(label("M O H A S H U N N Y O", 27))
	header.add_child(label("FRONTIER  /  EARTH OPERATIONS", 13, MINT))
	var status_box := VBoxContainer.new()
	status_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_box.position = Vector2(-310, 32)
	status_box.size.x = 270
	screen.add_child(status_box)
	status_box.add_child(label("●  FACILITY SYSTEMS ONLINE", 14, MINT))
	stats = label("", 13, Color("a1b6c4"))
	status_box.add_child(stats)
	visits_label = label("", 13, Color("a1b6c4"))
	status_box.add_child(visits_label)
	economy_label = label("", 14, Color("f4bb64"))
	status_box.add_child(economy_label)
	objective_label = label("", 13, MINT)
	status_box.add_child(objective_label)
	var footer := VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(40, -121)
	screen.add_child(footer)
	footer.add_child(label("CURRENT SECTOR", 12, MINT))
	room_label = label("ARRIVAL CONCOURSE", 26)
	footer.add_child(room_label)
	footer.add_child(label("WASD  Walk    SHIFT  Sprint    MOUSE  Orbit    WHEEL  Zoom    TAB  Map    ESC  Menu", 14, Color("a1b6c4")))
	reticle = label("·", 30, Color("d0e5e8"))
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-5, -22)
	screen.add_child(reticle)
	hint = label("", 17, MINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-350, -150)
	hint.size = Vector2(700, 60)
	screen.add_child(hint)
	map_panel = PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", style(Color(0.025, 0.06, 0.09, 0.95)))
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	map_panel.position = Vector2(-310, -365)
	map_panel.size = Vector2(270, 320)
	screen.add_child(map_panel)
	var map_vbox := VBoxContainer.new()
	map_panel.add_child(map_vbox)
	map_vbox.add_child(label("FACILITY PLAN / NORTH ↑", 13, MINT))
	var minimap := FacilityMap.new()
	minimap.explorer = player
	minimap.custom_minimum_size = Vector2(220, 260)
	map_vbox.add_child(minimap)
	map_panel.hide()
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", style(Color(0.035,0.12,0.15,0.96), MINT, 8))
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_panel.position = Vector2(-240, 28)
	toast_panel.size = Vector2(480, 78)
	toast_panel.hide()
	screen.add_child(toast_panel)
	toast_panel.add_child(label("", 16, Color.WHITE))
	countdown_hud = label("", 76, Color("f4bb64"))
	countdown_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	countdown_hud.position = Vector2(-160, 110)
	countdown_hud.size = Vector2(320, 100)
	countdown_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(countdown_hud)

func clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	player.enabled = true
	if not capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func new_overlay() -> VBoxContainer:
	clear_overlay()
	player.enabled = false
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay = ColorRect.new()
	overlay.color = Color(0.01, 0.025, 0.04, 0.76)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", style(Color("0e1c29"), Color("395467"), 16))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	return content

func show_menu(first: bool = false) -> void:
	var content := new_overlay()
	content.add_child(label("EARTH OPERATIONS   /   MISSION BUILD 03", 14, MINT))
	content.add_child(label("A long way home.", 44))
	content.add_child(label("Your mission begins here.", 23))
	content.add_child(label("Take a Mars mission from briefing to liftoff. Build the architecture, solve NASA-based flight checks, clear integration, and command terminal count.\n\nWASD / arrows move · Shift runs · Mouse looks · V switches first/third person · Click terminals.", 18, Color("b1c4d0")))
	var start_action: Callable = open_mission_briefing if first and not mission.briefing_complete else clear_overlay
	content.add_child(button("BEGIN MISSION BRIEFING  →" if first and not mission.briefing_complete else "RESUME MISSION  →", start_action))
	content.add_child(button("MARS EXPEDITION / TITLE SCREEN", func() -> void: get_tree().change_scene_to_file("res://scenes/expedition.tscn")))
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 20)
	content.add_child(options)
	options.add_child(label("Graphics", 17))
	var quality_picker := OptionButton.new()
	quality_picker.add_item("Performance · 900p / no shadows")
	quality_picker.add_item("Balanced · 1080p / sun shadows")
	quality_picker.add_item("High · native / 4× MSAA")
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
		settings.set_value("controls", "sensitivity", value)
		settings.save("user://settings.cfg"))
	sensitivity_row.add_child(slider)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	content.add_child(controls)
	controls.add_child(button("Fullscreen / F11", toggle_fullscreen))
	controls.add_child(button("Return to arrival", func() -> void:
		player.position = Vector3(0, 0.1, 23)
		player.rotation = Vector3.ZERO
		player.camera.rotation = Vector3.ZERO
		clear_overlay()))
	controls.add_child(button("Quit", func() -> void: get_tree().quit()))
	content.add_child(label("FICTIONAL EARTH SPACEPORT · NASA EQUATIONS AND RESEARCH ARE CITED IN-GAME\nScenario values and gameplay estimates are explicitly labeled.", 12, Color("8fa6b5")))

func toggle_fullscreen() -> void:
	var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_quality(index: int) -> void:
	quality = index
	var viewport := get_viewport()
	viewport.msaa_3d = Viewport.MSAA_4X if index == 2 else (Viewport.MSAA_DISABLED if index == 0 else Viewport.MSAA_2X)
	# Cap render resolution without changing HUD resolution or window dimensions.
	var target: float = 900.0 if index == 0 else 1080.0
	viewport.scaling_3d_scale = 1.0 if index == 2 else minf(1.0, target / maxf(1.0, viewport.get_visible_rect().size.y))
	if is_instance_valid(facility):
		for child: Node in facility.get_children():
			if child is DirectionalLight3D:
				child.shadow_enabled = index > 0
	settings.set_value("video", "quality", index)
	settings.save("user://settings.cfg")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(overlay):
				clear_overlay()
			else:
				show_menu()
		if event.keycode == KEY_TAB and not is_instance_valid(overlay):
			map_panel.visible = not map_panel.visible
		if event.keycode == KEY_F11:
			toggle_fullscreen()
		if event.keycode == KEY_V and not is_instance_valid(overlay):
			var first_person: bool = player.toggle_camera_view()
			show_toast("CAMERA  /  " + ("FIRST PERSON" if first_person else "THIRD PERSON"))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not focused.is_empty() and not is_instance_valid(overlay):
			open_station(str(focused.id))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player) and not is_instance_valid(overlay) and not smoke and not capture:
		show_menu()

func _process(delta: float) -> void:
	music.update_mix(delta,0)
	if not is_instance_valid(player):
		return
	clock += delta
	var zone := room_at(player.position)
	if zone != last_room:
		last_room = zone
		visits[zone] = true
		room_label.text = zone
	visits_label.text = "%d / 5 SECTORS VISITED" % visits.size()
	stats.text = "NATIVE 3D  /  %d FPS  /  %s" % [Engine.get_frames_per_second(), ["PERFORMANCE", "BALANCED", "HIGH"][quality]]
	if is_instance_valid(mission):
		var total: Dictionary = mission.totals()
		economy_label.text = "$%.0fM AVAILABLE  /  %d ASSETS" % [mission.budget_m, total.count]
		objective_label.text = "MISSION PHASE  /  " + mission.stage_name()
		if not smoke and not capture and int(clock)!=campaign_hud_tick:
			campaign_hud_tick = int(clock)
			var cargo := preload("res://scripts/outpost_cargo.gd").new(); cargo.read_draft()
			var campaign := preload("res://scripts/campaign.gd").new(); campaign.read()
			economy_label.text = "%d PROCUREMENT CREDITS / %d KITS" % [cargo.credits,cargo.kits.size()]
			objective_label.text = "EXPEDITION %d / %s / QUOTA %d" % [campaign.expedition_number,campaign.status,campaign.quota()]
		facility.update_liftoff(delta)
		if facility.liftoff_active and not smoke and is_instance_valid(facility.launch_vehicle):
			var target: Vector3 = facility.launch_vehicle.global_position
			var look: Vector3 = target - (player.global_position + Vector3(0, 1.55, 0))
			player.camera_yaw = atan2(-look.x, -look.z)
			player.camera_pitch = minf(1.15, atan2(look.y, Vector2(look.x, look.z).length()))
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0: toast_panel.hide()
	focused = {}
	if not is_instance_valid(overlay):
		var camera: Camera3D = player.camera
		for station: Dictionary in facility.stations:
			var offset: Vector3 = station.position - camera.global_position
			if offset.length() < 7.5 and offset.normalized().dot(-camera.global_basis.z) > 0.90:
				var query := PhysicsRayQueryParameters3D.create(camera.global_position, station.position)
				query.exclude = [player.get_rid()]
				var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or camera.global_position.distance_to(hit.position) > offset.length() - 0.9:
					focused = station
					break
	hint.text = "CLICK  /  " + str(focused.title) if not focused.is_empty() else ""
	reticle.modulate = MINT if not focused.is_empty() else Color.WHITE
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

func room_at(p: Vector3) -> String:
	if p.z < -19:
		return "03 / LAUNCH COMPLEX"
	if p.x < -16:
		return "01 / SUPPLY & OUTFITTING"
	if p.x > 16:
		return "04 / MISSION CONTROL"
	if p.z < 13:
		return "02 / VEHICLE INTEGRATION"
	return "00 / ARRIVAL CONCOURSE"

func open_station(id: String) -> void:
	if id == "field_systems":
		open_field_systems(); return
	if id == "shop":
		open_mission_shop()
		return
	if id == "engineering":
		open_engineering_manifest()
		return
	if id == "launch":
		open_launch_control()
		return
	if id == "science":
		open_equation_lab()
		return
	var content := new_overlay()
	content.add_child(label("FRONTIER  /  FACILITY TERMINAL", 14, MINT))
	if id == "engineering" or id == "shop":
		content.add_child(label("Module fit preview" if id == "engineering" else "Mission outfitter", 36))
		content.add_child(label("Drag a component from the catalog into the integration slot.\nVisual preview only — mass, budget and flight systems are not simulated yet.", 17, Color("a9bfce")))
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 22)
		content.add_child(columns)
		var catalog := VBoxContainer.new()
		catalog.custom_minimum_size.x = 340
		columns.add_child(catalog)
		var modules := [["power", "Solar power module", "Deployable power / engineering concept"], ["life", "Life-support module", "Consumables / engineering concept"], ["science", "Science instrument bay", "Payload / engineering concept"]]
		for data: Array in modules:
			var card := ModuleCard.new()
			card.module_id = data[0]
			card.display_name = data[1]
			card.add_theme_stylebox_override("panel", style(Color("1c3344"), Color("476276"), 8))
			card.mouse_default_cursor_shape = Control.CURSOR_DRAG
			var lines := VBoxContainer.new()
			lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(lines)
			lines.add_child(label("⠿  " + str(data[1]), 20, MINT))
			lines.add_child(label(str(data[2]), 13))
			catalog.add_child(card)
			if data[0] == "power":
				test_card = card
		var slot := ModuleSlot.new()
		slot.custom_minimum_size = Vector2(345, 250)
		slot.add_theme_stylebox_override("panel", style(Color("102d34"), MINT, 10))
		var caption := label("INTEGRATION SLOT\n\nDrop a module here\n\nNo cost / preview mode", 21, MINT)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.caption = caption
		slot.add_child(caption)
		slot.installed.connect(install_module)
		columns.add_child(slot)
		test_slot = slot
	elif id == "science":
		content.add_child(label("Real references. Visible sources.", 34))
		var facts := "NASA / JPL · Solar System Dynamics\nMars equatorial gravity: %.2f m/s²\nMars mean radius: %.1f km\n\nThese are cited planetary reference values, not live telemetry.\nThis Earth facility and its spacecraft are fictional design concepts.\nNASA terrain and environmental datasets will power later mission stages;\nthey are not implemented in this facility exploration build." % [facility.nasa.equatorialGravity.value, facility.nasa.meanRadius.value]
		content.add_child(label(facts, 19))
		content.add_child(button("Open NASA / JPL source ↗", func() -> void: OS.shell_open(str(facility.nasa.sourceUrl))))
		content.add_child(label("Material sources: ambientCG / MetalPlates006 and Concrete034 / CC0\nFull source metadata and checksums are stored beside the textures.", 14, Color("9bb3c4")))
	else:
		content.add_child(label("Launch complex 01", 36))
		content.add_child(label("VEHICLE STATUS  /  GROUND HOLD\n\nExplore the pad and service gantry from the perimeter.\nLaunch sequencing, flight physics and mission progression\nwill be developed in a later iteration.\n\nThe launch vehicle is an original concept, not a NASA flight vehicle.", 20))
	content.add_child(button("RETURN TO FACILITY  →", clear_overlay))

func show_toast(message: String) -> void:
	if not is_instance_valid(toast_panel): return
	var toast_label: Label = toast_panel.get_child(0)
	toast_label.text = message
	toast_panel.show()
	toast_time = 4.5

func open_field_systems() -> void:
	preload("res://scripts/outpost_shop.gd").new().show_shop(self)

func open_campaign_board() -> void:
	var campaign := preload("res://scripts/campaign.gd").new(); campaign.read()
	var stock := preload("res://scripts/outpost_cargo.gd").new(); stock.read_draft()
	var content := new_overlay()
	content.add_child(label("CAMPAIGN VEHICLE INTEGRATION",30,MINT))
	content.add_child(label("EXPEDITION %d / %d procurement credits / return quota %d" % [campaign.expedition_number,stock.credits,campaign.quota()],18))
	var gaps := campaign.missing(stock)
	if not gaps.is_empty():
		content.add_child(label("Rocket components required:\n"+"\n".join(gaps),16))
	elif not campaign.integrated:
		content.add_child(label(["ISOLATE propulsion and electrical buses","VERIFY independent flight and descent systems","CLEAR the range and confirm the crew"][campaign.integration_step],22,MINT))
		var answers := [["Arm now","ISOLATE AND SECURE","Bypass protections"],["Ignore sensors","Use one display","CROSS-CHECK AND VERIFY"],["CLEAR RANGE / CREW GO","Launch without clearance","Disable guidance"]]
		for i: int in range(3):
			var choice := i
			content.add_child(button(answers[campaign.integration_step][i],func() -> void:
				var reason := campaign.integrate(stock,choice)
				if reason!="": show_toast(reason)
				open_campaign_board()))
	else:
		content.add_child(label("VEHICLE CLEARED / launch funds and field kits share this budget",19,MINT))
		content.add_child(button("BOARD VEHICLE / LAUNCH EXPEDITION",func() -> void:
			get_tree().set_meta("ground_manifest",{"mass":0.,"power":0.}); get_tree().change_scene_to_file("res://scenes/expedition.tscn")))
	content.add_child(button("ROCKET & FIELD PROCUREMENT",func() -> void: preload("res://scripts/outpost_shop.gd").new().show_shop(self,"Launch","launch_core")))
	content.add_child(button("RETURN TO FACILITY",clear_overlay))

func open_mission_briefing() -> void:
	var content := new_overlay()
	var profile: Dictionary = mission.exercise_data.mission
	content.add_child(label("MISSION CONTROL  /  FLIGHT DIRECTOR BRIEFING", 14, MINT))
	content.add_child(label(str(profile.title), 34))
	content.add_child(label(str(profile.objective), 20, Color("d9e8ed")))
	var cards := HBoxContainer.new(); cards.add_theme_constant_override("separation", 12); content.add_child(cards)
	for datum: Array in [["CREW", str(profile.crew)], ["SURFACE STAY", "%d DAYS" % profile.surfaceDays], ["BUDGET", "$%.1fB" % (mission.budget_m / 1000.0)], ["DECISION GATES", "3 CALCULATIONS"]]:
		var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(190, 92); panel.add_theme_stylebox_override("panel", style(Color("142b38"), Color("3d6270"), 7)); cards.add_child(panel)
		var box := VBoxContainer.new(); panel.add_child(box); box.add_child(label(datum[0], 11, MINT)); box.add_child(label(datum[1], 20))
	content.add_child(label("FLIGHT DIRECTOR AMINA RAHMAN\n“Every kilogram changes the mission. Procure the survival architecture, prove the numbers, then meet me at Launch Operations.”", 18, Color("b7cad4")))
	content.add_child(label(str(profile.architectureNote), 13, Color("f4bb64")))
	content.add_child(button("ACCEPT COMMAND  /  BEGIN OUTFITTING  →", func() -> void:
		mission.accept_briefing(); clear_overlay(); show_toast("MISSION ACCEPTED  /  PHASE 02 OUTFITTING\nProceed to Supply & Outfitting.")))

func open_equation_lab() -> void:
	var content := new_overlay()
	content.add_child(label("MISSION CONTROL  /  NASA FLIGHT LAB", 14, MINT))
	content.add_child(label("Prove the mission before launch", 34))
	content.add_child(label("Solve each engineering check. Commas are optional. Incorrect answers reveal a useful diagnostic and never consume budget.", 14, Color("a9bfce")))
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(970, 500); content.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 10); scroll.add_child(list)
	for exercise: Dictionary in mission.exercise_data.exercises:
		var solved: bool = mission.solved_exercises.get(str(exercise.id), false)
		var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", style(Color("102c37") if solved else Color("142838"), MINT if solved else Color("355064"), 7)); list.add_child(card)
		var box := VBoxContainer.new(); card.add_child(box)
		box.add_child(label(("✓ VALIDATED  /  " if solved else str(exercise.station) + "  /  ") + str(exercise.title), 18, MINT if solved else Color("f4bb64")))
		box.add_child(label(str(exercise.prompt), 15))
		box.add_child(label(str(exercise.equation), 18, Color("d7f8f4")))
		box.add_child(label(str(exercise.evidence), 12, Color("91aab8")))
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); box.add_child(row)
		if not solved:
			var answer := LineEdit.new(); answer.placeholder_text = "Numeric answer in " + str(exercise.unit); answer.custom_minimum_size = Vector2(300, 44); row.add_child(answer)
			row.add_child(button("SUBMIT", func() -> void: submit_flight_answer(str(exercise.id), answer.text)))
		row.add_child(button("NASA SOURCE ↗", func() -> void: OS.shell_open(str(exercise.sourceUrl))))
	var footer := HBoxContainer.new(); footer.add_theme_constant_override("separation", 12); content.add_child(footer)
	footer.add_child(button("ENGINEERING REVIEW", open_engineering_manifest)); footer.add_child(button("RETURN TO FACILITY", clear_overlay))

func submit_flight_answer(id: String, answer: String) -> void:
	var result: Dictionary = mission.submit_exercise(id, answer)
	show_toast(str(result.message))
	open_equation_lab()

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

func open_mission_shop(category := "ALL") -> void:
	if not smoke and not capture and "--ground-transfer-test" not in OS.get_cmdline_user_args(): preload("res://scripts/outpost_shop.gd").new().show_shop(self,"Launch","launch_core"); return
	var content := new_overlay()
	content.add_child(label("SUPPLY & OUTFITTING  /  NASA-INFORMED MISSION CATALOG", 14, MINT))
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 24); content.add_child(head)
	head.add_child(label("Mission hardware", 34))
	var funds := label("$%.0fM available" % mission.budget_m, 22, Color("f4bb64")); funds.size_flags_horizontal = Control.SIZE_EXPAND_FILL; funds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; head.add_child(funds)
	content.add_child(label("Published NASA values, architecture targets, and gameplay estimates are labeled separately.", 14, Color("a9bfce")))
	var category_row := HBoxContainer.new(); category_row.add_theme_constant_override("separation", 7); content.add_child(category_row)
	for name: String in ["ALL", "Spacecraft", "Life Support", "Consumables", "Propulsion", "Mars ISRU", "Power", "Surface", "Safety"]:
		var cat_button := button(name, func() -> void: open_mission_shop(name)); cat_button.custom_minimum_size.y = 38; category_row.add_child(cat_button)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(970, 440); content.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 8); scroll.add_child(list)
	for item: Dictionary in mission.catalog.items:
		if category != "ALL" and str(item.category) != category: continue
		var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", style(Color("142838"), Color("355064"), 7)); list.add_child(card)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); card.add_child(row)
		var details := VBoxContainer.new(); details.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(details)
		details.add_child(label(str(item.name) + "  /  " + str(item.variant), 19, MINT))
		details.add_child(label("%s  •  %s" % [item.category, item.sourceClass], 12, Color("f4bb64")))
		details.add_child(label("Mass %s kg   Power %+.1f kW   %s" % [format_number(float(item.massKg)), float(item.powerKw), item.note], 13, Color("b6c7d1")))
		var owned := int(mission.inventory.get(item.id, 0))
		var buy := button("BUY  $%.0fM\nOwned %d" % [float(item.costM), owned], func() -> void:
			if mission.buy(item): show_toast("PROCURED  /  " + str(item.name) + "\nDelivery assigned to the integration queue."); open_mission_shop(category)
			else: show_toast("PROCUREMENT BLOCKED  /  INSUFFICIENT BUDGET"))
		buy.custom_minimum_size = Vector2(170, 65); row.add_child(buy)
	var foot := HBoxContainer.new(); foot.add_theme_constant_override("separation", 12); content.add_child(foot)
	foot.add_child(button("PROCURE RECOMMENDED BASELINE", func() -> void:
		var count: int = mission.buy_baseline(); show_toast("BASELINE LOADOUT  /  %d ORDERS PLACED\nGround crew delivery timers started." % count); open_mission_shop(category)))
	foot.add_child(button("FIELD SYSTEMS / MARS KITS",func() -> void: preload("res://scripts/outpost_shop.gd").new().show_shop(self))); foot.add_child(button("NASA SOURCES", open_source_ledger)); foot.add_child(button("ENGINEERING MANIFEST", open_engineering_manifest)); foot.add_child(button("RETURN TO FACILITY", clear_overlay))

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
	content.add_child(label("Catalog costs and many concept masses are gameplay estimates, never NASA procurement data.", 14, Color("f4bb64")))
	content.add_child(button("BACK TO CATALOG", open_mission_shop))

func open_engineering_manifest() -> void:
	if not smoke and not capture and "--ground-transfer-test" not in OS.get_cmdline_user_args(): open_campaign_board(); return
	var content := new_overlay(); content.add_child(label("VEHICLE INTEGRATION  /  MISSION DESIGN REVIEW", 14, MINT)); content.add_child(label("Architecture manifest", 34))
	var t: Dictionary = mission.totals(); var cards := HBoxContainer.new(); cards.add_theme_constant_override("separation", 10); content.add_child(cards)
	for datum: Array in [["PURCHASED", "%d" % t.count], ["MISSION MASS", "%s kg" % format_number(t.mass)], ["NET POWER LOAD", "%+.1f kW" % t.power], ["BUDGET", "$%.0fM" % mission.budget_m]]:
		var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(205, 90); panel.add_theme_stylebox_override("panel", style(Color("142b38"), Color("3d6270"), 7)); cards.add_child(panel)
		var box := VBoxContainer.new(); panel.add_child(box); box.add_child(label(datum[0], 11, MINT)); box.add_child(label(datum[1], 20))
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation", 20); content.add_child(columns)
	var manifest := VBoxContainer.new(); manifest.custom_minimum_size = Vector2(525, 390); columns.add_child(manifest); manifest.add_child(label("INSTALLED / DELIVERING HARDWARE", 14, Color("f4bb64")))
	var any := false
	for item: Dictionary in mission.catalog.items:
		var count := int(mission.inventory.get(item.id, 0))
		if count > 0: any = true; manifest.add_child(label("%d × %s  /  %s" % [count, item.name, item.variant], 14))
	if not any: manifest.add_child(label("No hardware procured. Visit Supply & Outfitting.", 17, Color("a9bfce")))
	var readiness_box := VBoxContainer.new(); readiness_box.custom_minimum_size.x = 390; columns.add_child(readiness_box); readiness_box.add_child(label("FLIGHT READINESS", 14, Color("f4bb64")))
	var missing: Array[String] = mission.readiness()
	if missing.is_empty(): readiness_box.add_child(label("GO  /  All mandatory capabilities installed", 18, MINT))
	else:
		readiness_box.add_child(label("HOLD  /  %d requirements open" % missing.size(), 18, Color("ef8d6d")))
		for requirement: String in missing: readiness_box.add_child(label("○  " + requirement, 13))
	readiness_box.add_child(label("\nConsumables\nO₂: %s kg\nWater: %s kg\nFood: %s crew-mission days" % [format_number(t.oxygen), format_number(t.water), format_number(t.food)], 15))
	var calculation_gaps: Array[String] = mission.calculation_gaps()
	readiness_box.add_child(label("\nFLIGHT CALCULATIONS  /  %d OF %d VALIDATED" % [mission.exercise_data.exercises.size() - calculation_gaps.size(), mission.exercise_data.exercises.size()], 14, Color("f4bb64")))
	for gap: String in calculation_gaps: readiness_box.add_child(label("○  " + gap, 12))
	var pending: int = mission.pending_delivery_count()
	readiness_box.add_child(label("\nGROUND LOGISTICS  /  %s" % ("ALL DELIVERED" if pending == 0 else "%d DELIVERIES ACTIVE" % pending), 13, MINT if pending == 0 else Color("f4bb64")))
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 12); content.add_child(actions)
	actions.add_child(button("OPEN CATALOG", open_mission_shop)); actions.add_child(button("FLIGHT LAB", open_equation_lab)); actions.add_child(button("PROCEED TO LAUNCH COMPLEX", func() -> void: clear_overlay(); show_toast("FINAL STEP  /  REPORT TO LAUNCH OPERATIONS")))

func open_launch_control() -> void:
	if not smoke and not capture and "--ground-transfer-test" not in OS.get_cmdline_user_args(): open_campaign_board(); return
	var content := new_overlay(); content.add_child(label("LAUNCH COMPLEX 01  /  TERMINAL COUNT", 14, MINT))
	var countdown := label("T−10", 78, Color("f4bb64")); countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; content.add_child(countdown)
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
	for id: String in ["shop", "engineering", "science", "launch", "field_systems"]:
		open_station(id)
		await get_tree().process_frame
		clear_overlay()
	install_module("power", "Solar power module")
	if not is_instance_valid(facility.installed_module):
		errors.append("Module preview missing")
	if facility.stations.size() != 5:
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
	print("SMOKE CHECK: complete briefing-to-liftoff flow, equations, first-person view, movement and collision")
	for error: String in errors:
		push_error(error)
	print("SMOKE RESULT: " + ("PASS" if errors.is_empty() else "FAIL"))
	get_tree().quit(0 if errors.is_empty() else 1)
