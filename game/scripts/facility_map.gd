extends Control
var explorer: CharacterBody3D

func _process(_delta: float) -> void:
	queue_redraw()

func project_point(p: Vector3) -> Vector2:
	return Vector2(size.x * 0.5 + p.x * 2.5, 180 + p.z * 2.5)

func _draw() -> void:
	var rooms: Array[Rect2] = [Rect2(-16, -19, 32, 48), Rect2(-32, -6, 16, 24), Rect2(16, -6, 16, 24), Rect2(-4, -35, 8, 16), Rect2(-20, -63, 40, 28)]
	for r: Rect2 in rooms:
		var rect := Rect2(project_point(Vector3(r.position.x, 0, r.position.y)), r.size * 2.5)
		draw_rect(rect, Color("172b3b"))
		draw_rect(rect, Color("466175"), false, 1)
	if is_instance_valid(explorer):
		var p := project_point(explorer.position)
		draw_circle(p, 4, Color("74eee2"))
		var forward := Vector2(-sin(explorer.rotation.y), -cos(explorer.rotation.y))
		draw_line(p, p + forward * 13, Color("74eee2"), 2, true)
