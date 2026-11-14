extends SceneTree
## Real lab cinematic -> manifest -> Mars architecture and earned rewards.
func _initialize() -> void:
	await process_frame
	var port: Node = load("res://scenes/spaceport.tscn").instantiate()
	root.add_child(port); current_scene = port
	port.campaign.persistent = false; port.stock.recommended_pack()
	for answer: int in [1,2,0]: port.campaign.integrate(port.stock,answer)
	port.lab.briefed = true; port.lab.suited = true; port.lab.sim_rating = 2
	for exercise: Dictionary in port.mission.exercise_data.exercises:
		port.mission.solved_exercises[str(exercise.id)] = true
	port.selected_loadout = 2; port.selected_site = 1; port.selected_seed = 314159
	port.clear_overlay(); port.begin_real_launch()
	for frame: int in range(46):
		port.update_launch(.5)
		if port.leaving: break
