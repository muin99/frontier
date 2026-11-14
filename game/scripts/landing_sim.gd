extends Node3D
## Terminal-descent flying: the trainer in the Earth lab and the real arrival at Mars.
## Mars gravity is 3.71 m/s²; engine thrust, fuel and scoring are game models.
signal finished(result: Dictionary)
const Gfx = preload("res://scripts/gfx.gd")
const GRAVITY := 3.71
const THRUST := 9.6
const STEER := 5.2
const BURN := 6.2
const STEER_BURN := 1.3
const LEG := 2.1
const RATINGS := ["HARD IMPACT", "ROUGH LANDING", "GOOD LANDING", "PERFECT LANDING"]
var active := false
var training := false
var autopilot_on := false
var place := Vector3.ZERO
var velocity := Vector3.ZERO
var fuel := 100.0
var throttle := 0.0
var elapsed := 0.0
var seed_value := 1
var result: Dictionary = {}
var lander: Node3D
var camera: Camera3D
var plume: MeshInstance3D
var dust: CPUParticles3D
var engine_light: OmniLight3D
var layer: CanvasLayer
var readout: Label
var coach: Label
var fuel_bar: ProgressBar
var speed_bar: ProgressBar
var pad_hint: Label
var card: Control
var shake := 0.0
var rumble: AudioStreamPlayer
var steer_input := Vector2.ZERO
var paused := false
var briefing_card: Control

func ground(x: float, z: float) -> float:
	var distance := Vector2(x, z).length()
	var hills := sin(x * 0.021 + seed_value * 0.37) * cos(z * 0.017 - seed_value * 0.21) * 9.0 + sin(x * 0.07 + z * 0.05 + seed_value) * 2.2
	return hills * smoothstep(18.0, 75.0, distance)

## Deterministic start state shared by play and by the automated landing check.
func reset(options: Dictionary = {}) -> void:
	training = bool(options.get("training", false))
	seed_value = int(options.get("seed", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var bearing := rng.randf() * TAU
	var range_m := rng.randf_range(70.0, 105.0)
	place = Vector3(cos(bearing) * range_m, 250.0, sin(bearing) * range_m)
	velocity = Vector3(-cos(bearing) * 9.0 + rng.randf_range(-3, 3), -30.0, -sin(bearing) * 9.0 + rng.randf_range(-3, 3))
	fuel = minf(130.0, 100.0 + float(options.get("fuel_bonus", 0.0)))
	throttle = 0.0
	elapsed = 0.0
	result = {}
	autopilot_on = false
	active = true

## One step of the flight model. Returns true on touchdown.
func step(delta: float, steer: Vector2, thrust: bool) -> bool:
	if not active: return true
	elapsed += delta
	var burning := thrust and fuel > 0.0
	throttle = move_toward(throttle, 1.0 if burning else 0.0, delta * 3.5)
	var lateral := steer.limit_length(1.0) if fuel > 0.0 else Vector2.ZERO
	velocity.y += (THRUST * throttle - GRAVITY) * delta
	velocity.x += lateral.x * STEER * delta
	velocity.z += lateral.y * STEER * delta
	velocity -= velocity * 0.015 * delta
	fuel = maxf(0.0, fuel - (BURN * throttle + STEER_BURN * lateral.length()) * delta)
	place += velocity * delta
	place.x = clampf(place.x, -290, 290)
	place.z = clampf(place.z, -290, 290)
	var floor_y := ground(place.x, place.z) + LEG
	if place.y <= floor_y:
		place.y = floor_y
		touchdown()
		return true
	return false

func touchdown() -> void:
	active = false
	var sink := maxf(0.0, -velocity.y)
	var slide := Vector2(velocity.x, velocity.z).length()
	var miss := Vector2(place.x, place.z).length()
	var rating := 0
	if sink < 2.6 and slide < 2.2 and miss < 12.0: rating = 3
	elif sink < 4.6 and slide < 3.6 and miss < 45.0: rating = 2
	elif sink < 8.0 and slide < 6.5: rating = 1
	if autopilot_on: rating = mini(rating, 2)
	result = {"rating": rating, "label": RATINGS[rating], "sink": sink, "slide": slide, "miss": miss, "fuel": fuel, "time": elapsed, "autopilot": autopilot_on,
		"damage": [25.0, 8.0, 0.0, 0.0][rating], "science": [0, 0, 8, 15][rating]}
	velocity = Vector3.ZERO

## Simple guidance law. It is the autopilot option and the proof that every start is landable.
func guidance() -> Array:
	var altitude := place.y - ground(place.x, place.z) - LEG
	var offset := Vector2(place.x, place.z)
	var wanted := (-offset * 0.22).limit_length(9.0 if altitude > 30 else 3.0)
	var steer := ((wanted - Vector2(velocity.x, velocity.z)) * 0.9).limit_length(1.0)
	var settled := offset.length() < 9.0 and Vector2(velocity.x, velocity.z).length() < 2.0
	var target_sink := clampf(altitude * 0.21 + 1.3, 1.3, 30.0)
	if altitude < 22 and not settled: target_sink = clampf((altitude - 14.0) * 0.4, -0.5, 3.0)
	return [steer, -velocity.y > target_sink]

func start(options: Dictionary = {}) -> void:
	reset(options)
	build_stage()
	build_hud()
	paused = bool(options.get("briefing",true)); briefing_card.visible = paused
	camera.current = true
	set_physics_process(true)
	if DisplayServer.get_name() != "headless":
		rumble = AudioStreamPlayer.new()
		add_child(rumble)
		var wave := AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = 11025
		var bytes := PackedByteArray()
		bytes.resize(11025 * 2)
		var level := 0.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i: int in range(11025):
			level = clampf(level * 0.96 + rng.randf_range(-1, 1) * 0.16, -1, 1)
			bytes.encode_s16(i * 2, int(level * 15000))
		wave.data = bytes
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_end = 11025
		rumble.stream = wave
		rumble.volume_db = -60
		rumble.play()

func _ready() -> void:
	set_physics_process(false)

func build_stage() -> void:
	position = Vector3(0, 6000, 0)
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3b3340")
	sky_mat.sky_horizon_color = Color("d59a6f")
	sky_mat.ground_horizon_color = Color("b77c53")
	sky_mat.ground_bottom_color = Color("563a2b")
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9a79e")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("c58f68")
	env.fog_density = 0.0028
	Gfx.grade(env, Gfx.quality())
	camera = Camera3D.new()
	camera.fov = 62
	camera.far = 2500
	camera.environment = env
	add_child(camera)
	# The host scene's sun lights this stage; only local lamps are added here.
	# Terrain: vertex-coloured relief that flattens into the landing zone.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 96
	var span := 1700.0
	for z: int in range(cells):
		for x: int in range(cells):
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var px := (float(x + corner.x) / cells - 0.5) * span
				var pz := (float(z + corner.y) / cells - 0.5) * span
				var height := ground(px, pz)
				st.set_color(Color("9a6240").lerp(Color("c98a5c"), clampf(height / 12.0 + 0.5, 0, 1)))
				st.add_vertex(Vector3(px, height, pz))
	st.generate_normals()
	var land := MeshInstance3D.new()
	land.mesh = st.commit()
	var soil := ShaderMaterial.new()
	soil.shader = Gfx.shader("descent_soil", """shader_type spatial;
varying vec3 wp;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=VERTEX;}
void fragment(){
	float patches=noise(wp.xz*0.05)*0.5+noise(wp.xz*0.4)*0.3+noise(wp.xz*3.0)*0.2;
	ALBEDO=COLOR.rgb*(0.55+patches*0.75);
	ROUGHNESS=0.95;
}""")
	land.material_override = soil
	land.layers = 2
	add_child(land)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stone := SphereMesh.new()
	stone.radius = 1.0
	stone.height = 2.0
	stone.radial_segments = 8
	stone.rings = 4
	var rocks := MultiMesh.new()
	rocks.transform_format = MultiMesh.TRANSFORM_3D
	rocks.mesh = stone
	rocks.instance_count = 420
	for i: int in range(420):
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(16, 300)
		var at := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		at.y = ground(at.x, at.z)
		var size := rng.randf_range(0.3, 2.6)
		rocks.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(rng.randf(), rng.randf() * TAU, rng.randf())).scaled(Vector3(size, size * 0.6, size * 0.85)), at))
	var field := MultiMeshInstance3D.new()
	field.multimesh = rocks
	field.material_override = Gfx.surface(Color("6a4532"), 0.0, 0.9)
	field.layers = 2
	add_child(field)
	# Landing zone: rings, corner strobes and a tall beacon that reads from altitude.
	for data: Array in [[12.0, Color("5fe9e0")], [45.0, Color("f4bb64")]]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = float(data[0]) - 0.35
		torus.outer_radius = float(data[0]) + 0.35
		torus.rings = 96
		ring.mesh = torus
		ring.material_override = Gfx.emissive(data[1], 1.4)
		ring.position.y = 0.12
		ring.layers = 2
		add_child(ring)
	var beacon := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 0.6
	column.bottom_radius = 0.6
	column.height = 120
	beacon.mesh = column
	beacon.material_override = Gfx.hologram(Color("5fe9e0"), 0.22)
	beacon.position = Vector3(0, 60, 0)
	beacon.layers = 2
	add_child(beacon)
	for i: int in range(3):
		var hull := MeshInstance3D.new()
		var tank := CylinderMesh.new()
		tank.top_radius = 2.4
		tank.bottom_radius = 2.4
		tank.height = 9
		hull.mesh = tank
		hull.material_override = Gfx.surface(Color("d3d9da"), 0.2, 0.4)
		hull.rotation.z = PI / 2
		hull.rotation.y = 0.4 + i
		hull.position = Vector3(-34 + i * 9.0, 2.6, -30 - i * 7.0)
		hull.layers = 2
		add_child(hull)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("7fe7ff")
		lamp.omni_range = 14
		lamp.light_energy = 2.5
		lamp.light_cull_mask = 2
		lamp.position = hull.position + Vector3(0, 4, 3)
		add_child(lamp)
	build_lander()

func build_lander() -> void:
	lander = Node3D.new()
	add_child(lander)
	var white := Gfx.surface(Color("e4e9ea"), 0.15, 0.32)
	var dark := Gfx.surface(Color("1c252d"), 0.4, 0.45)
	var foil := Gfx.surface(Color("d7a046"), 0.85, 0.3)
	var metal := Gfx.surface(Color("7b8894"), 0.9, 0.3)
	metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	var parts: Array = [
		[[Vector2(0.0, 2.9), Vector2(0.7, 2.75), Vector2(1.5, 1.9), Vector2(1.85, 0.9), Vector2(1.9, 0.2)], white],
		[[Vector2(1.9, 0.2), Vector2(1.95, -0.1), Vector2(1.55, -0.55), Vector2(0.0, -0.6)], foil],
		[[Vector2(1.87, 0.75), Vector2(1.93, 0.9), Vector2(1.87, 1.05)], dark],
		[[Vector2(0.35, -0.55), Vector2(0.45, -0.95), Vector2(0.8, -1.5)], metal]]
	for entry: Array in parts:
		var mesh := MeshInstance3D.new()
		mesh.mesh = Gfx.lathe(entry[0], 28)
		mesh.material_override = entry[1]
		mesh.layers = 2
		lander.add_child(mesh)
	for i: int in range(4):
		var angle := PI / 4 + i * PI / 2
		var direction := Vector3(sin(angle), 0, cos(angle))
		var strut := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.07
		tube.bottom_radius = 0.07
		tube.height = 2.9
		strut.mesh = tube
		strut.material_override = metal
		strut.position = direction * 2.3 + Vector3(0, -0.85, 0)
		strut.rotation = Vector3(direction.z * 0.75, 0, -direction.x * 0.75)
		strut.layers = 2
		lander.add_child(strut)
		var foot := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.38
		disc.bottom_radius = 0.44
		disc.height = 0.12
		foot.mesh = disc
		foot.material_override = foil
		foot.position = direction * 3.25 + Vector3(0, -LEG + 0.06, 0)
		foot.layers = 2
		lander.add_child(foot)
		var window := MeshInstance3D.new()
		var pane := SphereMesh.new()
		pane.radius = 0.22
		pane.height = 0.3
		window.mesh = pane
		window.material_override = Gfx.emissive(Color("7fe7ff"), 2.0)
		window.position = direction * 1.52 + Vector3(0, 1.75, 0)
		window.layers = 2
		lander.add_child(window)
	plume = MeshInstance3D.new()
	plume.mesh = Gfx.plume_mesh(0.75, 7.0)
	var fire: ShaderMaterial = Gfx.plume(Color("fff0cf"), Color("ff7a2a"))
	fire.set_shader_parameter("reach", 7.0)
	plume.material_override = fire
	plume.position.y = -1.45
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.layers = 2
	lander.add_child(plume)
	engine_light = OmniLight3D.new()
	engine_light.light_color = Color("ff9a4a")
	engine_light.omni_range = 34
	engine_light.light_energy = 0
	engine_light.light_cull_mask = 2
	engine_light.position.y = -3.0
	lander.add_child(engine_light)
	dust = Gfx.emitter({"amount": 160, "life": 2.4, "speed": Vector2(8, 20), "size": Vector2(1.6, 4.0), "dir": Vector3(1, 0.1, 0), "spread": 180.0, "gravity": Vector3(0, 0.8, 0), "damping": 3.0, "colors": [Color(0.86, 0.6, 0.42, 0.0), Color(0.86, 0.62, 0.45, 0.6), Color(0.8, 0.6, 0.48, 0.0)], "grow": Vector2(0.5, 2.6), "radius": 1.5, "emitting": false})
	dust.flatness = 0.88
	dust.layers = 2
	add_child(dust)
	lander.position = place
	camera.cull_mask = 2
	camera.position = place + Vector3(0, 10, 30)

func label(value: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("0b1820"))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.06, 0.08, 0.86)
	s.border_color = Color("3b777a")
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(18)
	return s

func build_hud() -> void:
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var head := VBoxContainer.new()
	head.position = Vector2(36, 28)
	root.add_child(head)
	head.add_child(label("DESCENT SIMULATOR  /  TRAINING RUN" if training else "TERMINAL DESCENT  /  FRONTIER 01", 16, Color("8de0d4")))
	head.add_child(label("Land on the cyan ring. Touch down slower than 3 m/s.", 26, Color("f1f4ee")))
	coach = label("", 20, Color("eec393"))
	head.add_child(coach)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", panel_style())
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.position = Vector2(-376, 28)
	box.size = Vector2(340, 250)
	root.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	box.add_child(column)
	readout = label("", 21, Color("e8f3f1"))
	column.add_child(readout)
	column.add_child(label("FUEL", 13, Color("8de0d4")))
	fuel_bar = ProgressBar.new()
	fuel_bar.max_value = 100
	fuel_bar.show_percentage = false
	fuel_bar.custom_minimum_size = Vector2(300, 14)
	column.add_child(fuel_bar)
	column.add_child(label("DESCENT RATE  /  keep the bar short near the ground", 13, Color("8de0d4")))
	speed_bar = ProgressBar.new()
	speed_bar.max_value = 30
	speed_bar.show_percentage = false
	speed_bar.custom_minimum_size = Vector2(300, 14)
	column.add_child(speed_bar)
	var keys := label("HOLD SPACE  fire engine        W A S D  steer        ENTER  autopilot", 18, Color("d5e3e2"))
	keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	keys.position = Vector2(-330, -64)
	keys.size = Vector2(660, 30)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(keys)
	pad_hint = label("", 22, Color("8de0d4"))
	root.add_child(pad_hint)
	briefing_card = PanelContainer.new(); briefing_card.add_theme_stylebox_override("panel",panel_style())
	briefing_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER); briefing_card.position = Vector2(-360,-125); briefing_card.size = Vector2(720,250); root.add_child(briefing_card)
	var intro := VBoxContainer.new(); intro.add_theme_constant_override("separation",14); briefing_card.add_child(intro)
	intro.add_child(label("READY TO FLY? / TIME IS PAUSED",22,Color("8de0d4")))
	var explanation := label("Space fires the engine to slow your fall. WASD steers. Aim for the cyan ring. Enter switches autopilot on or off. Escape pauses. Try assisted landing first if you are learning.",19,Color("e8f3f1"))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; explanation.custom_minimum_size.x = 670; intro.add_child(explanation)
	intro.add_child(make_button("START / ASSISTED LANDING",func() -> void: begin_flight(true)))
	intro.add_child(make_button("START / MANUAL CONTROL",func() -> void: begin_flight(false)))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func begin_flight(assisted: bool) -> void:
	paused = false; autopilot_on = assisted
	if is_instance_valid(briefing_card): briefing_card.hide()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and active and DisplayServer.get_name()!="headless": paused = true

func bar_color(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)

func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_physics_processing(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		paused = not paused; get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if paused: begin_flight(true)
		else: autopilot_on = not autopilot_on
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if active and not paused:
		var steer := steer_input
		var thrust := Input.is_physical_key_pressed(KEY_SPACE)
		if steer == Vector2.ZERO:
			steer = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		if autopilot_on:
			var command := guidance()
			steer = command[0]
			thrust = command[1]
		if step(delta, steer, thrust): show_result()
		lander.rotation = Vector3(steer.y * 0.16, 0, -steer.x * 0.16).lerp(lander.rotation, 0.86)
	update_view(delta)

func update_view(delta: float) -> void:
	lander.position = place
	var altitude := place.y - ground(place.x, place.z) - LEG
	plume.visible = throttle > 0.03
	plume.scale = Vector3(1, throttle * (0.9 + sin(elapsed * 40.0) * 0.08), 1)
	engine_light.light_energy = throttle * 9.0
	dust.emitting = throttle > 0.2 and altitude < 28
	dust.position = Vector3(place.x, ground(place.x, place.z) + 0.6, place.z)
	shake = lerpf(shake, throttle * (0.25 + clampf(1.0 - altitude / 40.0, 0, 1) * 0.5), 1 - exp(-delta * 6))
	var back := clampf(14.0 + altitude * 0.16, 14.0, 44.0)
	var wanted := place + Vector3(0, back * 0.42, back)
	camera.position = camera.position.lerp(wanted, 1 - exp(-delta * 4.0))
	camera.look_at(to_global(place + Vector3(0, -2.0 - altitude * 0.05, -4.0)))
	camera.h_offset = randf_range(-1, 1) * shake * 0.12
	camera.v_offset = randf_range(-1, 1) * shake * 0.12
	if is_instance_valid(rumble): rumble.volume_db = lerpf(rumble.volume_db, linear_to_db(maxf(0.001, throttle * 0.5)), 0.2)
	if not is_instance_valid(readout): return
	var sink := -velocity.y
	var slide := Vector2(velocity.x, velocity.z).length()
	var miss := Vector2(place.x, place.z).length()
	readout.text = "ALTITUDE     %4d m\nDESCENT      %4.1f m/s\nDRIFT        %4.1f m/s\nPAD RANGE    %4d m" % [maxf(0, altitude), sink, slide, miss]
	fuel_bar.value = fuel
	bar_color(fuel_bar, Color("5fe9e0") if fuel > 30 else Color("ff5a48"))
	speed_bar.value = clampf(sink, 0, 30)
	bar_color(speed_bar, Color("58f08c") if sink < 3 else (Color("f4bb64") if sink < 8 else Color("ff5a48")))
	if active:
		if paused: coach.text = "PAUSED / Enter starts assisted flight / Escape resumes"
		elif autopilot_on: coach.text = "AUTOPILOT FLYING  /  press Enter to take control"
		elif fuel <= 0: coach.text = "FUEL EXHAUSTED  /  brace for impact"
		elif altitude > 120 and sink > 26: coach.text = "Start your braking burn: hold SPACE"
		elif altitude < 60 and sink > 9: coach.text = "TOO FAST  /  hold SPACE to brake"
		elif miss > 14 and altitude < 70: coach.text = "Steer toward the cyan beacon with W A S D"
		elif altitude < 30 and sink < 3: coach.text = "Good. Ease down gently; tap SPACE to hold 2 m/s"
		else: coach.text = "Brake early. Gravity here is 3.71 m/s², the air barely helps."
	var screen_size := get_viewport().get_visible_rect().size
	if camera.is_position_behind(to_global(Vector3(0, 2, 0))): pad_hint.text = ""
	else:
		var projected := camera.unproject_position(to_global(Vector3(0, 2, 0)))
		pad_hint.position = Vector2(clampf(projected.x - 70, 40, screen_size.x - 240), clampf(projected.y - 46, 150, screen_size.y - 140))
		pad_hint.text = "◆ PAD  %d m" % miss

func show_result() -> void:
	if is_instance_valid(card): return
	dust.emitting = int(result.rating) < 3
	shake = 1.2 if int(result.rating) == 0 else 0.4
	throttle = 0.0
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", panel_style())
	layer.get_child(0).add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.size = Vector2(660, 0)
	card.position = get_viewport().get_visible_rect().size*.5-Vector2(330,190)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var rating: int = result.rating
	column.add_child(label("TOUCHDOWN", 15, Color("8de0d4")))
	column.add_child(label(str(result.label), 40, [Color("ff6a58"), Color("f4bb64"), Color("8de0d4"), Color("58f08c")][rating]))
	column.add_child(label("Descent %.1f m/s   •   Drift %.1f m/s   •   %d m from pad   •   Fuel %d%%" % [result.sink, result.slide, result.miss, result.fuel], 18, Color("d5e3e2")))
	var lesson := "Mars has too little air for parachutes alone, so the last metres are flown on engines."
	if rating == 0: lesson = "Too fast at contact. Start braking higher and keep descent under 3 m/s near the ground."
	elif rating == 1: lesson = "Survivable, but hard on the landing gear. Cancel sideways drift before the final metres."
	elif bool(result.autopilot): lesson = "The autopilot lands safely. Fly it yourself to earn a higher rating."
	var note := label(lesson, 18, Color("eec393"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 600
	column.add_child(note)
	if training:
		column.add_child(label("Pilot rating carries to launch day: +%d%% landing fuel on the real descent." % (rating * 8), 17, Color("8de0d4")))
	else:
		column.add_child(label("Suit integrity %s   •   Science %s" % ["-%d%%" % int(result.damage) if float(result.damage) > 0 else "unchanged", "+%d" % int(result.science) if int(result.science) > 0 else "+0"], 17, Color("8de0d4")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	if training:
		row.add_child(make_button("FLY AGAIN", func() -> void:
			card.queue_free(); card = null
			seed_value += 1
			reset({"training": true, "seed": seed_value})
			camera.position = place + Vector3(0, 10, 30)))
	var done := make_button("RETURN TO THE LAB" if training else "STEP ONTO MARS", func() -> void: finished.emit(result))
	row.add_child(done)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	done.grab_focus()

func make_button(value: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = Vector2(250, 50)
	b.add_theme_font_size_override("font_size", 18)
	var normal := panel_style()
	normal.bg_color = Color("15313b")
	var hover := panel_style()
	hover.bg_color = Color("25515a")
	hover.border_color = Color("8de0d4")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(callback)
	return b
