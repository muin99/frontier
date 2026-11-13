extends CharacterBody3D
const Humanoid = preload("res://scripts/humanoid.gd")
var route: Array[Vector3] = []
var route_index := 0
var role := "TECHNICIAN"
var display_name := "CREW"
var speed := 1.25
var worker: Node3D
var paused := 0.0

func setup(person_name: String, job: String, points: Array, color: Color) -> void:
	display_name = person_name
	role = job
	for point: Vector3 in points: route.append(point)
	position = route[0]
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)
	worker = Humanoid.new()
	add_child(worker)
	worker.build(color, Color("f4bb64"), job.begins_with("EVA"), abs(person_name.hash()) % 4, false)

func _physics_process(delta: float) -> void:
	if route.is_empty(): return
	if paused > 0:
		paused -= delta
		velocity.x = move_toward(velocity.x, 0, delta * 6.0)
		velocity.z = move_toward(velocity.z, 0, delta * 6.0)
		worker.animate_motion(delta, Vector2(velocity.x, velocity.z).length())
		move_and_slide()
		return
	var target := route[route_index]
	var flat := target - position
	flat.y = 0
	if flat.length() < 0.45:
		route_index = (route_index + 1) % route.size()
		paused = 1.0 + fmod(float(route_index) * 0.7, 2.5)
		return
	var direction := flat.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 4.5)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 4.5)
	velocity.y = -0.2 if is_on_floor() else velocity.y - 9.81 * delta
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 7.0)
	move_and_slide()
	worker.animate_motion(delta, speed)
