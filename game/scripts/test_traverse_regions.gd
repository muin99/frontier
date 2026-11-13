extends SceneTree
var errors: Array[String] = []
func _initialize() -> void:
	await process_frame
	var game: Node = load("res://scenes/expedition.tscn").instantiate(); root.add_child(game); current_scene = game
	var test_seed := 42601
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--route-seed="): test_seed = argument.get_slice("=",1).to_int()
	game.regenerate_world(test_seed)
	game.testing = true; game.model.configure(1,0); game.model.transit(true); game.resume_surface(); game.player.enabled = false
	for npc: Node in game.world.get_children():
		if npc is CharacterBody3D: npc.collision_layer = 0
	game.player.jump_height = 1.3; game.player.enabled = true; game.player.floor_max_angle = deg_to_rad(58); game.player.speed_multiplier = 3.2
	game.player.position = game.world.point(0,42,0.3)
	var previous_centre := Vector3.ZERO
	for region: int in range(6):
		var goal: Vector3 = game.world.beacons[4+region*6+1].position # cache, reachable without an instrument
		var centre: Vector2 = game.world.generator.regions[region].centre
		var points: Array[Vector3] = []
		# Follow the generated valley and site approach, as a player can; do not
		# assume an arbitrary straight line across a cliff should be traversable.
		var chain: Array[Vector3] = [previous_centre,game.world.point(0,0),game.world.point(centre.x,centre.y),goal]
		if region == 0: chain = [game.world.point(-15,42),game.world.point(-15,0),game.world.point(0,0),game.world.point(centre.x,centre.y),goal]
		previous_centre = game.world.point(centre.x,centre.y)
		var from: Vector3 = game.player.position
		for destination: Vector3 in chain:
			var count := ceili(Vector2(destination.x-from.x,destination.z-from.z).length()/12)
			for step: int in range(1,count+1):
				var p := from.lerp(destination,float(step)/count)
				points.append(game.world.point(p.x,p.z))
			from = destination
		var reached := true
		for point: Vector3 in points:
			var arrived := false
			game.player.set_test_move_input(Vector2(0,-1))
			for frame: int in range(700):
				var offset: Vector3 = point-game.player.position
				if Vector2(offset.x,offset.z).length() < 3: arrived = true; break
				game.player.camera_yaw = atan2(-offset.x,-offset.z)
				if frame>140 and frame%80 == 0 and game.player.is_on_floor(): game.player.request_jump()
				await physics_frame
			if not arrived: reached = false; errors.append("Controller stuck in region %d at %s toward %s" % [region,game.player.position,point]); break
		game.player.clear_test_move_input()
		print("REGION ROUTE ",region," / ","PASS" if reached else "FAIL")
	game.sfx.stop(); game.sfx.stream = null
	await process_frame
	for error: String in errors: push_error(error)
	print("REGIONAL TRAVERSAL: ","PASS" if errors.is_empty() else "FAIL"," / seed ",test_seed)
	quit(0 if errors.is_empty() else 1)
