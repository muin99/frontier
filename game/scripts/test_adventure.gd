extends RefCounted

func run(game: Node) -> void:
	game.testing = true; game.campaign.persistent = false
	game.model.configure(1,0); game.selected_seed = 42601
	var errors: Array[String] = []
	game.begin_descent(true)
	var sim: Node = game.descent
	var before_fuel: float = sim.fuel
	for frame: int in range(30): await game.get_tree().physics_frame
	if sim.elapsed!=0 or sim.fuel!=before_fuel: errors.append("Descent moved during briefing")
	sim.begin_flight(true)
	for frame: int in range(6000):
		await game.get_tree().physics_frame
		if not sim.active: break
	if sim.result.is_empty() or int(sim.result.get("rating",0))<2: errors.append("Assisted playable descent failed")
	var found := false
	for button: Node in sim.card.find_children("*","Button",true,false):
		if button.text=="STEP ONTO MARS": button.pressed.emit(); found = true; break
	if not found or game.model.phase!="SURFACE" or game.model.science<8: errors.append("Descent result did not reach field/reward")
	game.resume_surface(); game.player.velocity = Vector3.ZERO
	for frame: int in range(60): await game.get_tree().physics_frame
	game.player.request_jump(); game.player.jet_hold = true
	for frame: int in range(45): await game.get_tree().physics_frame
	if game.player.jet_fuel>=98 or not game.player.jetting or game.player.velocity.y<=0: errors.append("Thruster did not lift/consume fuel")
	game.pause_screen()
	var paused_fuel: float = game.player.jet_fuel
	for frame: int in range(30): await game.get_tree().physics_frame
	if game.player.jetting or game.player.jet_fuel!=paused_fuel: errors.append("Paused thruster consumed fuel")
	game.player.jet_hold = false; game.resume_surface()
	for frame: int in range(300): await game.get_tree().physics_frame
	game.player.enabled = false
	game.hazards.reset(42601); game.hazards.enabled = true
	var before_integrity: float = game.model.integrity
	game.hazards.schedule(game.player.position,.1); game.hazards.tick(.2,false)
	if game.model.integrity>=before_integrity or game.hazards.hits!=1: errors.append("Exposed impact did not damage suit")
	before_integrity = game.model.integrity
	game.hazards.schedule(game.player.position,.1); game.hazards.tick(.2,true)
	if game.model.integrity!=before_integrity: errors.append("Shelter failed to protect crew")
	game.hazards.schedule(game.player.position+Vector3(20,0,0),3)
	var at: Vector3 = game.hazards.pending[0].p
	game.hazards.shift(Vector3(-256,0,256))
	if game.hazards.pending[0].p!=at+Vector3(-256,0,256): errors.append("Hazard rebase lost target")
	var saved: Dictionary = game.hazards.snapshot()
	game.hazards.reset(42601); game.hazards.restore(saved)
	if game.hazards.events!=int(saved.events) or game.hazards.hits!=int(saved.hits): errors.append("Hazard save roundtrip")
	var science_before: int = game.model.science
	game.hazards.start_quake(); game.hazards.tick(7,true)
	if game.model.science!=science_before+4: errors.append("Quake science not once-only")
	# Let one-shot effects clean up their timers before shutdown.
	for frame: int in range(200): await game.get_tree().physics_frame
	for error: String in errors: push_error(error)
	print("ADVENTURE SYSTEMS: ","PASS" if errors.is_empty() else "FAIL"," / live assisted descent, briefing pause, field handoff, thruster fuel/lift/pause, exposed/sheltered impacts, rebasing, hazard save, quake reward")
	game.get_tree().quit(0 if errors.is_empty() else 1)
