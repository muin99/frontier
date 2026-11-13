extends SceneTree
const Generator = preload("res://scripts/exploration_generator.gd")
const Weather = preload("res://scripts/mars_weather.gd")
const World = preload("res://scripts/mars_world.gd")
const Model = preload("res://scripts/expedition_model.gd")
var errors: Array[String] = []
func _initialize() -> void:
	await process_frame
	var generator := Generator.new()
	for seed_value: int in [1,2,7,42,99,42601,71523,20261104,999999999]:
		generator.generate(seed_value); var signature := generator.signature()
		if generator.regions.size() != 6 or generator.discoveries.size() != 36: errors.append("Missing region or site")
		generator.generate(seed_value)
		if generator.signature() != signature: errors.append("Seed does not reproduce")
		for item: Dictionary in generator.discoveries:
			if absf(item.position.x)>730 or absf(item.position.y)>730: errors.append("Site beyond bounds")
		generator.generate(seed_value+1)
		if generator.signature() == signature: errors.append("Different seeds did not vary")
	var weather := Weather.new(); var states := {}
	for step: int in range(160):
		weather.update(step*30,"basalt",42601); states[weather.state] = true
		if weather.pressure_pa < 700 or weather.pressure_pa > 800: errors.append("Pressure units invalid")
		if weather.temperature_c < -90 or weather.temperature_c > 0: errors.append("Temperature units invalid")
		if weather.wind_mps < 0 or weather.wind_mps > float(weather.data.windAnalog.maxMps): errors.append("Wind magnitude outside source range")
		var same := Weather.new(); same.update(step*30,"basalt",42601)
		if same.state != weather.state or not is_equal_approx(same.pressure_pa,weather.pressure_pa): errors.append("Weather not reproducible")
	if states.size() != 6: errors.append("Weather diversity missing")
	var world := World.new(); root.add_child(world); world.build()
	await physics_frame; await physics_frame
	if world.beacons.size() != 40 or world.refuges.size() != 6: errors.append("World assembly incomplete")
	var model := Model.new(); model.configure(1,0); model.transit(true)
	for site: Dictionary in world.discoveries: model.targets.append(site.duplicate(true))
	model.pack.clear()
	var advanced := -1
	for i: int in range(4,model.targets.size()):
		if model.targets[i].get("tool","") == "climbing": advanced = i; break
	if advanced < 0: errors.append("No traversal-gated science site")
	else:
		if model.can_sample(advanced) == "": errors.append("Missing traversal tool bypassed")
		model.pack.append("climbing")
		if not model.collect(advanced): errors.append("Equipped traversal tool rejected")
		var copy := Model.new(); copy.targets = model.targets.duplicate(true)
		if not copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) or not copy.samples.has(advanced) or copy.pack != model.pack: errors.append("Extended exploration save roundtrip failed")
	for i: int in range(4,world.beacons.size()):
		var p: Vector3 = world.beacons[i].position
		var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*10,p-Vector3.UP*10)
		if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): errors.append("Missing discovery ground")
		var g := Vector2((world.elevation(p.x+3,p.z)-world.elevation(p.x-3,p.z))/6,(world.elevation(p.x,p.z+3)-world.elevation(p.x,p.z-3))/6).length()
		if g > 0.55: errors.append("Unsafe discovery slope")
	world.free()
	for error: String in errors: push_error(error)
	print("EXPLORATION GENERATOR: ","PASS" if errors.is_empty() else "FAIL"," / nine seeds, 6 districts, 36 sites, repeatability, weather states, sensor units, collision, site gradients, traversal tools, extended save")
	quit(0 if errors.is_empty() else 1)
