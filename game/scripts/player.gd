extends CharacterBody3D
const Humanoid = preload("res://scripts/humanoid.gd")
const MARS_GRAVITY := 3.71
const SUIT_JUMP_HEIGHT := 0.75
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
signal hard_landing(speed: float)
const WALK_SPEED := 1.8
const RUN_SPEED := 4.5
const ACCELERATION := 10.0
const DECELERATION := 14.0

func _ready() -> void:
	name = "Commander"
	var shape := CapsuleShape3D.new(); shape.radius = 0.32; shape.height = 1.8
	var collision := CollisionShape3D.new(); collision.shape = shape; collision.position.y = 0.9; add_child(collision)
	avatar = Humanoid.new(); add_child(avatar); avatar.build(Color("e2ebed"), Color("55e7dd"), suited, 2)
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
	update_camera_rig()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled:
		apply_look(event.screen_relative)
	if event is InputEventMouseButton and enabled:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera_distance = maxf(2.6, camera_distance - 0.35)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera_distance = minf(7.0, camera_distance + 0.35)

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
		peak_fall_speed = 0
	avatar.airborne = not is_on_floor()
	avatar.animate_motion(delta, Vector2(velocity.x, velocity.z).length())
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
