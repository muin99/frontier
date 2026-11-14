extends CharacterBody3D
const Humanoid = preload("res://scripts/humanoid.gd")
const Gfx = preload("res://scripts/gfx.gd")
const MARS_GRAVITY := 3.71
const SUIT_JUMP_HEIGHT := 0.75
const JET_LIFT := 5.4
const JET_BURN := 24.0
const JET_REFILL := 16.0
var sensitivity := 0.0021
var enabled := true
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := -0.22
var camera_distance := 4.4
var camera_pivot: Node3D
var camera_boom: SpringArm3D
var avatar: Node3D
var move_input_override := Vector2(INF, INF)
var first_person := false
var suited := false
var gravity := 9.81
var rope_control := false
var rope_velocity := Vector3.ZERO
var speed_multiplier := 1.0
var gait_time := 0.0
var jump_buffer := 0.0
var coyote_time := 0.0
var jump_height := 0.8
var peak_fall_speed := 0.0
var terrain_ready: Callable
var avatar_variant := 2
var suit_index := 0
var trauma := 0.0
var jet_enabled := false
var jet_fuel := 100.0
var jetting := false
var jet_hold := false
var air_time := 0.0
var jet_flames: Array[CPUParticles3D] = []
var jet_light: OmniLight3D
var step_dust: CPUParticles3D
signal hard_landing(speed: float)
const WALK_SPEED := 1.8
const RUN_SPEED := 4.5
const ACCELERATION := 10.0
const DECELERATION := 14.0

func _ready() -> void:
	name = "Commander"
	var shape := CapsuleShape3D.new(); shape.radius = 0.32; shape.height = 1.8
	var collision := CollisionShape3D.new(); collision.shape = shape; collision.position.y = 0.9; add_child(collision)
	var settings := ConfigFile.new(); settings.load(Gfx.SETTINGS)
	avatar_variant = posmod(int(settings.get_value("avatar", "variant", 2)), Humanoid.CREW.size())
	suit_index = posmod(int(settings.get_value("avatar", "suit", 0)), Humanoid.SUITS.size())
	build_avatar()
	camera_pivot = Node3D.new(); camera_pivot.name = "CameraRig"; add_child(camera_pivot)
	# The camera must not inherit the character's turning. Otherwise every body turn
	# also rotates the view and makes camera-relative WASD feel unstable.
	camera_pivot.top_level = true
	camera_boom = SpringArm3D.new(); camera_boom.spring_length = camera_distance; camera_boom.margin = 0.15; camera_pivot.add_child(camera_boom)
	camera_boom.add_excluded_object(get_rid())
	camera = Camera3D.new(); camera.name = "ThirdPersonCamera"; camera.fov = 72; camera.near = 0.08; camera.far = 350.0; camera_boom.add_child(camera); camera.current = true
	# Restrained suited hop; retain actual Mars acceleration.
	if suited: jump_height = SUIT_JUMP_HEIGHT
	floor_snap_length = 0.4 if suited else 0.25
	var is_capture := false
	for argument: String in OS.get_cmdline_user_args(): is_capture = is_capture or argument.begins_with("--capture")
	if not is_capture: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if suited: build_suit_effects()
	update_camera_rig()

func suit_color() -> Color:
	return Color(str(Humanoid.SUITS[suit_index].color))

func build_avatar() -> void:
	if is_instance_valid(avatar): avatar.free()
	avatar = Humanoid.new(); add_child(avatar)
	# On Mars the pressure suit keeps its white shell; the chosen colour drives its running lights.
	var accent := suit_color().lightened(0.25) if suited else Color("55e7dd")
	avatar.build(suit_color(), accent, suited, avatar_variant, false, "COMMANDER")
	avatar.visible = not first_person

func choose_avatar(variant: int, suit: int, save := true) -> void:
	avatar_variant = posmod(variant, Humanoid.CREW.size()); suit_index = posmod(suit, Humanoid.SUITS.size())
	build_avatar()
	if save:
		var settings := ConfigFile.new(); settings.load(Gfx.SETTINGS)
		settings.set_value("avatar", "variant", avatar_variant); settings.set_value("avatar", "suit", suit_index)
		settings.save(Gfx.SETTINGS)

func build_suit_effects() -> void:
	for side: float in [-1.0, 1.0]:
		var flame: CPUParticles3D = Gfx.emitter({"amount": 28, "life": 0.35, "speed": Vector2(4, 7), "size": Vector2(0.12, 0.24), "dir": Vector3(0, -1, 0.15), "spread": 9.0, "colors": [Color(0.75, 0.95, 1.0, 0.95), Color(0.35, 0.7, 1.0, 0.6), Color(0.2, 0.4, 1.0, 0.0)], "additive": true, "grow": Vector2(1.0, 0.35), "local": false, "emitting": false})
		flame.position = Vector3(side * 0.16, 1.05, 0.34); add_child(flame); jet_flames.append(flame)
	jet_light = OmniLight3D.new(); jet_light.light_color = Color("7cc8ff"); jet_light.omni_range = 5.0; jet_light.light_energy = 0.0; jet_light.shadow_enabled = false
	jet_light.position = Vector3(0, 0.9, 0.4); add_child(jet_light)
	step_dust = Gfx.emitter({"amount": 14, "life": 1.1, "speed": Vector2(0.3, 0.9), "size": Vector2(0.25, 0.55), "dir": Vector3(0, 1, 0), "spread": 60.0, "gravity": Vector3(0, -0.4, 0), "colors": [Color(0.78, 0.55, 0.4, 0.0), Color(0.78, 0.55, 0.4, 0.34), Color(0.78, 0.55, 0.4, 0.0)], "grow": Vector2(0.5, 1.8), "emitting": false})
	step_dust.position = Vector3(0, 0.08, 0.1); add_child(step_dust)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled:
		apply_look(event.screen_relative)
	if event is InputEventMouseButton and enabled:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera_distance = maxf(2.6, camera_distance - 0.35)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera_distance = minf(7.0, camera_distance + 0.35)

func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.4)
	if is_instance_valid(camera):
		var amount := trauma * trauma
		camera.h_offset = randf_range(-1, 1) * amount * 0.22
		camera.v_offset = randf_range(-1, 1) * amount * 0.22

## Adds camera trauma; values near 1.0 are a violent jolt.
func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func _physics_process(delta: float) -> void:
	if terrain_ready.is_valid() and not terrain_ready.call(position+velocity*delta):
		velocity = Vector3.ZERO; update_camera_rig(); return
	if rope_control:
		velocity = rope_velocity; move_and_slide(); update_camera_rig(); return
	update_camera_rig()
	camera_boom.spring_length = lerpf(camera_boom.spring_length, camera_distance, delta * 8.0)
	var axis := Vector2.ZERO
	if move_input_override.x != INF:
		axis = move_input_override
	elif enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		axis = Input.get_vector("left", "right", "forward", "backward")
	var forward := Vector3(-sin(camera_yaw), 0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0, -sin(camera_yaw))
	var direction := (right * axis.x + forward * -axis.y).normalized()
	var speed := ((3.2 if suited else RUN_SPEED) if Input.is_action_pressed("sprint") else WALK_SPEED * (1.1 if suited else 1.0)) * speed_multiplier
	var response := (6.0 if suited else ACCELERATION) if direction.length_squared() > 0.01 else (7.0 if suited else DECELERATION)
	if suited and not is_on_floor(): response = 1.6 if direction.length_squared()>.01 else .25
	# Thruster pack: hold jump while airborne. Lift is a game model, gravity is Mars'.
	var wants_jet := jet_hold or (enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_physical_key_pressed(KEY_SPACE) and Input.is_physical_key_pressed(KEY_CTRL))
	air_time = 0.0 if is_on_floor() else air_time + delta
	jetting = enabled and jet_enabled and suited and wants_jet and air_time > 0.14 and jet_fuel > 0.0
	if jetting:
		jet_fuel = maxf(0.0, jet_fuel - JET_BURN * delta)
		velocity.y = minf(velocity.y + (gravity + JET_LIFT) * delta, 4.2)
		response = 4.2; speed *= 1.5
		peak_fall_speed = minf(peak_fall_speed, maxf(0.0, -velocity.y))
	elif enabled and is_on_floor(): jet_fuel = minf(100.0, jet_fuel + JET_REFILL * delta)
	for flame: CPUParticles3D in jet_flames: flame.emitting = jetting
	if is_instance_valid(jet_light): jet_light.light_energy = lerpf(jet_light.light_energy, 3.0 if jetting else 0.0, 0.3)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * response)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * response)
	if direction.length_squared() > 0.01: rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 10.0)
	jump_buffer = maxf(0,jump_buffer-delta)
	if is_on_floor(): coyote_time = .12
	else: coyote_time = maxf(0,coyote_time-delta)
	if jump_buffer > 0 and coyote_time > 0 and enabled:
		velocity.y = sqrt(2*gravity*jump_height); jump_buffer = 0; coyote_time = 0
	elif not is_on_floor(): velocity.y -= gravity * delta
	elif velocity.y <= 0: velocity.y = -0.2
	var was_airborne := not is_on_floor()
	peak_fall_speed = maxf(peak_fall_speed,-velocity.y)
	move_and_slide()
	if is_on_floor():
		if was_airborne and peak_fall_speed > (4.2 if suited else 6): hard_landing.emit(peak_fall_speed)
		if was_airborne and peak_fall_speed > 2.0: shake(clampf(peak_fall_speed * 0.05, 0.1, 0.5))
		peak_fall_speed = 0
	avatar.airborne = not is_on_floor()
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	avatar.animate_motion(delta, ground_speed)
	if is_instance_valid(step_dust): step_dust.emitting = is_on_floor() and ground_speed > 1.2 and avatar.visible
	update_camera_rig()
	if position.y < -240: hard_landing.emit(50); velocity = Vector3.ZERO

func request_jump() -> void:
	jump_buffer = .16

func apply_look(relative: Vector2) -> void:
	camera_yaw = wrapf(camera_yaw - relative.x * sensitivity, -PI, PI)
	camera_pitch = clampf(camera_pitch - relative.y * sensitivity, -1.35, 1.1)
	update_camera_rig()

func update_camera_rig() -> void:
	if not is_instance_valid(camera_pivot): return
	camera_pivot.global_position = global_position + Vector3(0, 1.68 if first_person else 1.45, 0)
	camera_pivot.global_rotation = Vector3(camera_pitch, camera_yaw, 0)

func set_test_move_input(axis: Vector2) -> void:
	move_input_override = axis

func clear_test_move_input() -> void:
	move_input_override = Vector2(INF, INF)

func toggle_camera_view() -> bool:
	first_person = not first_person
	camera_distance = 0.12 if first_person else 4.4
	camera_boom.spring_length = camera_distance
	avatar.visible = not first_person
	update_camera_rig()
	return first_person
