extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var sim := preload("res://scripts/landing_sim.gd").new()
	var lowest_fuel := 200.0
	for seed_number: int in range(1,101):
		sim.reset({"seed":seed_number}); sim.autopilot_on = true
		for frame: int in range(12000):
			var command := sim.guidance()
			if sim.step(1.0/60,command[0],command[1]): break
		if sim.result.is_empty() or int(sim.result.get("rating",0))<2: failures.append(str(seed_number)+":"+str(sim.result))
		lowest_fuel = minf(lowest_fuel,sim.fuel)
	sim.free()
	for failure: String in failures: push_error(failure)
	print("LANDING MODEL: ","PASS" if failures.is_empty() else "FAIL"," / 100 seeds, assisted landing; lowest fuel ",lowest_fuel)
	quit(0 if failures.is_empty() else 1)
