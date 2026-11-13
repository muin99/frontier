extends Node
const NPC = preload("res://scripts/npc.gd")
var catalog: Dictionary
var exercise_data: Dictionary
var inventory: Dictionary = {}
var budget_m := 0.0
var parent_game: Node
var delivery_queue: Array[Dictionary] = []
var countdown := -1.0
var countdown_label: Label
var mission_state := "DESIGN"
var ground_crew: CharacterBody3D
var briefing_complete := false
var solved_exercises: Dictionary = {}
var last_count_call := -1

func setup(game: Node) -> void:
	parent_game = game
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/MISSION_CATALOG.json"))
	exercise_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/NASA_MISSION_EXERCISES.json"))
	budget_m = float(catalog.startingBudgetM)
	spawn_staff()

func spawn_staff() -> void:
	var staff := [
		["AMINA RAHMAN", "FLIGHT DIRECTOR", [Vector3(21,0.1,14), Vector3(27,0.1,14), Vector3(27,0.1,5), Vector3(21,0.1,5)], Color("4f9fb5")],
		["ELIAS PARK", "PROPULSION", [Vector3(7,0.1,-12), Vector3(11,0.1,-12), Vector3(11,0.1,1), Vector3(7,0.1,1)], Color("d8e2e4")],
		["MAYA CHEN", "LIFE SUPPORT", [Vector3(-20,0.1,13), Vector3(-28,0.1,13), Vector3(-28,0.1,3), Vector3(-20,0.1,3)], Color("80b69b")],
		["RAFI ISLAM", "GROUND CREW", [Vector3(-20,0.1,13), Vector3(-12,0.1,6), Vector3(8,0.1,7), Vector3(8,0.1,-8), Vector3(-8,0.1,-8)], Color("c59a50")],
		["SOFIA OKAFOR", "SYSTEMS ENGINEER", [Vector3(-9,0.1,-4), Vector3(-9,0.1,-12), Vector3(8,0.1,-12), Vector3(8,0.1,-4)], Color("7f8fc1")]
	]
	for data: Array in staff:
		var npc := NPC.new(); parent_game.add_child(npc); npc.setup(data[0], data[1], data[2], data[3])
		if data[1] == "GROUND CREW": ground_crew = npc

func buy(item: Dictionary) -> bool:
	var price := float(item.costM)
	if budget_m < price: return false
	budget_m -= price
	inventory[item.id] = int(inventory.get(item.id, 0)) + 1
	# Stagger a multi-item loadout so logistics reads as an active operation.
	delivery_queue.append({"item": item, "remaining": 2.5 + delivery_queue.size() * 0.55, "crate": make_delivery_crate()})
	return true

func buy_baseline() -> int:
	var required_ids := ["crew_capsule", "transit_hab", "mars_lander", "oga", "cdrs", "water_recovery", "food_500", "isru_plant", "fission_40", "surface_hab", "medical", "lox_tank", "water_1000"]
	var purchased := 0
	for required_id: String in required_ids:
		if int(inventory.get(required_id, 0)) > 0: continue
		for item: Dictionary in catalog.items:
			if str(item.id) == required_id and buy(item): purchased += 1
	return purchased

func accept_briefing() -> void:
	briefing_complete = true
	mission_state = "OUTFITTING"

func submit_exercise(id: String, answer_text: String) -> Dictionary:
	var normalized := answer_text.strip_edges().replace(",", "").replace(" ", "")
	if not normalized.is_valid_float(): return {"correct": false, "message": "Enter a numeric answer using the displayed unit."}
	var value := normalized.to_float()
	for exercise: Dictionary in exercise_data.exercises:
		if str(exercise.id) != id: continue
		var error := absf(value - float(exercise.answer))
		if error <= float(exercise.tolerance):
			solved_exercises[id] = true
			return {"correct": true, "message": "VALIDATED  /  %s" % exercise.title}
		return {"correct": false, "message": "CHECK UNITS  /  %s" % exercise.hint}
	return {"correct": false, "message": "Unknown engineering check."}

func calculation_gaps() -> Array[String]:
	var gaps: Array[String] = []
	for exercise: Dictionary in exercise_data.exercises:
		if not solved_exercises.get(str(exercise.id), false): gaps.append(str(exercise.title))
	return gaps

func pending_delivery_count() -> int:
	var count := 0
	for delivery: Dictionary in delivery_queue:
		if not delivery.get("announced", false): count += 1
	return count

func authorization_gaps() -> Array[String]:
	var gaps := readiness()
	if not briefing_complete: gaps.push_front("mission briefing")
	for calculation: String in calculation_gaps(): gaps.append("calculation: " + calculation)
	var pending := pending_delivery_count()
	if pending > 0: gaps.append("%d hardware deliveries pending" % pending)
	return gaps

func stage_name() -> String:
	if mission_state == "LAUNCHED": return "LIFTOFF"
	if mission_state == "COUNTDOWN": return "TERMINAL COUNT"
	if not briefing_complete: return "01 BRIEFING"
	if not readiness().is_empty(): return "02 OUTFITTING"
	if not calculation_gaps().is_empty(): return "03 FLIGHT LAB"
	if pending_delivery_count() > 0: return "04 INTEGRATION"
	return "05 LAUNCH READY"

func make_delivery_crate() -> Node3D:
	if not is_instance_valid(ground_crew): return null
	var crate := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = Vector3(0.55, 0.38, 0.42); crate.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("d0a94d"); mat.metallic = 0.55; mat.roughness = 0.35; crate.material_override = mat
	crate.position = Vector3(0, 1.0, -0.48)
	ground_crew.add_child(crate)
	return crate

func totals() -> Dictionary:
	var result := {"mass":0.0,"power":0.0,"oxygen":0.0,"water":0.0,"food":0.0,"count":0}
	for item: Dictionary in catalog.items:
		var count := int(inventory.get(item.id, 0))
		result.mass += float(item.massKg) * count; result.power += float(item.powerKw) * count
		result.oxygen += float(item.oxygenKg) * count; result.water += float(item.waterKg) * count
		result.food += float(item.foodDays) * count; result.count += count
	return result

func readiness() -> Array[String]:
	var missing: Array[String] = []
	var required := {"crew_capsule":"crew vehicle", "transit_hab":"transit habitat", "mars_lander":"Mars lander", "oga":"oxygen generation", "cdrs":"CO₂ removal", "water_recovery":"water recovery", "food_500":"500-day food", "isru_plant":"crew-scale ISRU", "fission_40":"surface power", "surface_hab":"surface habitat", "medical":"medical system"}
	for id: String in required:
		if int(inventory.get(id, 0)) < 1: missing.append(required[id])
	var t := totals()
	if float(t.oxygen) < 25000: missing.append("25 t ascent oxygen")
	if float(t.water) < 1000: missing.append("1,000 kg water reserve")
	return missing

func begin_countdown() -> bool:
	if not authorization_gaps().is_empty(): return false
	countdown = 10.99; last_count_call = 11; mission_state = "COUNTDOWN"; return true

func _process(delta: float) -> void:
	for delivery: Dictionary in delivery_queue:
		delivery.remaining -= delta
		if delivery.remaining <= 0 and not delivery.get("announced", false):
			delivery.announced = true
			if is_instance_valid(delivery.crate): delivery.crate.queue_free()
			parent_game.show_toast("DELIVERED  /  " + str(delivery.item.name) + "\nGround crew transferred hardware to integration.")
	if countdown >= 0:
		countdown -= delta
		var count_value := maxi(0, ceili(countdown))
		if count_value != last_count_call:
			last_count_call = count_value
			if count_value in [10, 5, 3, 2, 1]: parent_game.countdown_callout(count_value)
		if countdown > 0 and is_instance_valid(countdown_label): countdown_label.show()
		if is_instance_valid(countdown_label): countdown_label.text = "T−%02d" % maxi(0, ceili(countdown))
		if countdown <= 0:
			mission_state = "LAUNCHED"
			if is_instance_valid(countdown_label): countdown_label.text = "LIFTOFF"
			parent_game.begin_launch_sequence()
			parent_game.show_toast("LIFTOFF  /  MISSION COMMITTED\nFrontier 01 has cleared the tower.")
	elif mission_state == "DESIGN" and is_instance_valid(countdown_label):
		countdown_label.hide()
