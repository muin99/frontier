extends SceneTree
## End-to-end scene handoff test: real procurement gates, countdown, departure timer.
func _initialize() -> void:
	await process_frame
	var port: Node = load("res://scenes/spaceport.tscn").instantiate()
	root.add_child(port); current_scene = port
	port.mission.accept_briefing(); port.mission.buy_baseline()
	for exercise: Dictionary in port.mission.exercise_data.exercises:
		port.mission.submit_exercise(str(exercise.id),str(exercise.answer))
	for delivery: Dictionary in port.mission.delivery_queue:
		delivery.announced = true
		if is_instance_valid(delivery.crate): delivery.crate.queue_free()
	if not port.mission.begin_countdown():
		push_error("Ground transfer could not authorize launch"); quit(1); return
	port.clear_overlay(); port.mission.countdown = 0.01
	port.mission._process(0.02)
