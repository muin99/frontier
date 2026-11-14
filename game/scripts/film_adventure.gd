extends RefCounted
## Records real game components in controlled demonstration scenarios.
## It never changes campaign saves. Cuts and staged sections are disclosed.
func wait(game: Node, seconds: float) -> void:
	for frame: int in range(int(seconds*60)): await game.get_tree().physics_frame

func run(game: Node) -> void:
	game.model.configure(1,0); game.selected_seed = 42601
	game.begin_descent(true); game.film_event("landing_briefing")
	await wait(game,3)
	var sim: Node = game.descent
	sim.begin_flight(true); game.film_event("assisted_descent")
	for frame: int in range(6000):
		await game.get_tree().physics_frame
		if not sim.active: break
	game.film_event("landing_result"); await wait(game,4)
	for button: Node in sim.card.find_children("*","Button",true,false):
		if button.text=="STEP ONTO MARS": button.pressed.emit(); break
	game.film_event("surface_dashboard"); await wait(game,5)
	# Cut to open terrain to demonstrate the optional suit mechanics.
	game.player.position = game.world.point(-35,-25,.2); game.player.velocity = Vector3.ZERO; game.player.reset_physics_interpolation()
	game.player.camera_yaw = -.2; game.player.camera_pitch = -.15
	await wait(game,1)
	game.player.request_jump(); game.player.jet_hold = true; game.film_event("thruster")
	await wait(game,2); game.player.jet_hold = false; await wait(game,3)
	game.player.camera_yaw = 0; game.player.camera_pitch = -.16
	game.hazards.schedule(game.player.position+Vector3(0,0,-13),4)
	game.hazards.schedule(game.player.position+Vector3(-12,0,-17),5.5)
	game.film_event("controlled_impacts"); await wait(game,8)
	game.hazards.start_quake(); game.film_event("controlled_quake"); await wait(game,7)
	await game.make_outpost_capture(); game.resume_surface(); game.film_event("staged_outpost")
	await wait(game,8)
	print("ADVENTURE FILM: COMPLETE / actual game rendering; staged demonstration sections; no campaign saves")
	game.get_tree().call_deferred("quit")
