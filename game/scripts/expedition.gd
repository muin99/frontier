extends Node3D
const World = preload("res://scripts/mars_world.gd")
const Explorer = preload("res://scripts/player.gd")
const Model = preload("res://scripts/expedition_model.gd")
const MapView = preload("res://scripts/expedition_map.gd")
const Gfx = preload("res://scripts/gfx.gd")
const LandingSim = preload("res://scripts/landing_sim.gd")
const MINT := Color("8de0d4")
const GOLD := Color("eec393")
const SAVE := "user://expedition_v8.json"
const LEGACY_SAVE := "user://expedition_v7.json"
var world: World
var player: Explorer
var model := Model.new()
var canvas: CanvasLayer
var ui: Control
var overlay: Control
var hud: Control
var prompt: Label
var resources: Label
var objective: Label
var status: Label
var notice: Label
var scan_bar: ProgressBar
var map_view: Control
var cine: Camera3D
var selected_loadout := 1
var selected_site := 0
var target := -1
var launch_time := -1.0
var storm_announced := false
var capture_mode := ""
var capture_frame := 0
var fps_samples: Array[float] = []
var testing := false
var scan_held := false
var save_timer := 0.0
var toast_timer := 0.0
var quality := 1
var sfx: AudioStreamPlayer
var source_return := "pause"
var orbital_stage: Node3D
var transfer_ship: Node3D
var selected_seed := 42601
var weather := preload("res://scripts/mars_weather.gd").new()
var last_weather := ""
var visited_regions: Array[int] = []
var dust_particles: CPUParticles3D
var dust_devil: MultiMeshInstance3D
var rover: Node3D
var driving := false
var clouds: Node3D
var stream: Node3D
var lan: Node
var puzzle_stage := 0
var goal_marker: Node3D
var outpost: Node3D
var field: Node3D
var traversal: Node3D
var music: Node
var campaign := preload("res://scripts/campaign.gd").new()
var flight := preload("res://scripts/flight_director.gd").new()
var receiving_campaign_end := false
var guided := false
var control_hint: Label
var destination_hint: Label
var descent: Node3D
var landing_fuel_bonus := 0.0
var hazards: Node3D
var reserve_bars: Dictionary = {}
var isolated_demo := false
var guided_film := false

func film_event(value: String) -> void:
	if guided_film or "--film-adventure" in OS.get_cmdline_user_args(): print("FILM_EVENT ",JSON.stringify({"time":Engine.get_process_frames()/30.0,"event":value}))

func film_pause(seconds: float) -> void:
	if guided_film:
		for frame: int in range(int(seconds*60)): await get_tree().physics_frame

func first_mission() -> void:
	if lan_active(): lan.close()
	var v := menu(860)
	v.add_child(text("FIRST MISSION / ABOUT 5 MINUTES",15,MINT))
	v.add_child(text("Two discoveries. One safe return.",34))
	v.add_child(paragraph("You are the mission commander. Learn to move, collect two rock observations, and bring the crew home. Your rocket and supplies are provided. This practice mission never spends campaign money or replaces a saved expedition.",21))
	v.add_child(action("START PRACTICE / NO SPACE KNOWLEDGE NEEDED",start_first_mission,true))
	v.add_child(text("1  WALK TO THE CYAN MARKER",21,MINT))
	v.add_child(paragraph("WASD moves. Mouse looks. Follow the destination and distance at the top of the screen. Hold E near a marked target for three seconds to scan it.",19))
	v.add_child(text("2  WATCH YOUR OXYGEN",21,MINT))
	v.add_child(paragraph("The habitat refills oxygen and battery while you stand nearby. Return early if reserves are low. Escape pauses and explains your next step.",19))
	v.add_child(paragraph("Oxygen is your breathing air. Battery is electricity for your tools. The habitat is the white crew shelter. Scanning means using a tool to record an observation; you do not need to identify the rock yourself.",19,MINT))
	v.add_child(text("3  RETURN WITH TWO OBSERVATIONS",21,MINT))
	v.add_child(paragraph("After both scans, follow the marker home. Press E at the habitat and choose Return to Earth. Building, crafting and advanced equipment can wait.",19))
	v.add_child(action("BACK",title_screen)); focus_first(v)

func start_first_mission() -> void:
	guided = true; selected_seed = 42601; selected_loadout = 1; selected_site = 0
	field.restore({}); traversal.restore({}); regenerate_world(selected_seed)
	outpost.reset_for_launch(); outpost.cargo = preload("res://scripts/outpost_cargo.gd").new()
	outpost.cargo.starter()
	model.configure(1,0); visited_regions.clear(); set_driving(false)
	world.ascent.position = world.point(17,27); launch_time = -1
	land(true); map_view.hide()
	toast("WELCOME TO MARS\nFollow the cyan marker. WASD to move; hold E beside the target to scan.")

func guided_destination() -> Vector3:
	if model.samples.size() >= 2 or model.oxygen < 45 or model.battery < 20:
		return world.to_global(world.habitat)
	for i: int in range(mini(4,world.beacons.size())):
		if model.can_sample(i) == "": return world.beacons[i].global_position
	return world.to_global(world.habitat)

func guided_instruction() -> String:
	if model.oxygen < 45 or model.battery < 20:
		return "REFILL / Head back to the habitat"
	if model.samples.size() >= 2:
		return "3 / Return home / E at habitat"
	return "%d / Scan the %s target" % [model.samples.size()+1,"first" if model.samples.is_empty() else "second"]

func mission_help() -> void:
	var v := menu(800)
	v.add_child(text("YOUR NEXT MOVE",15,MINT))
	v.add_child(text(guided_instruction() if guided else "Collect evidence. Protect the crew.",28))
	v.add_child(paragraph("WASD: walk. Mouse: look. Hold E at a cyan survey target until its scan bar fills. Two distinct observations are needed. Return to the main habitat to command ascent; standing nearby restores oxygen and battery.",21))
	v.add_child(paragraph("V: switch first/third person. Tab: map. Escape: pause. In campaign mode, survey two districts and meet the science quota too. Building and crafting are optional ways to extend your range.",18))
	v.add_child(text("SPACE WORDS / PLAIN MEANINGS",16,MINT))
	v.add_child(paragraph(preload("res://scripts/beginner_lessons.gd").GLOSSARY,18))
	if not guided: v.add_child(paragraph("Ctrl + Space while airborne: use a short thruster burst. Fuel is limited and recharges on the ground. Red impact rings warn of fictional meteor hazards: move away or shelter. Thrusters and hazard rates are game mechanics, not certified equipment or NASA forecasts.",18,GOLD))
	v.add_child(action("BACK TO FIELD",resume_surface,true)); focus_first(v)

func guided_playtest() -> void:
	var errors: Array[String] = []
	var campaign_before: Dictionary = campaign.snapshot().duplicate(true)
	var save_before := FileAccess.get_file_as_string(SAVE) if FileAccess.file_exists(SAVE) else ""
	start_first_mission()
	film_event("touchdown"); await film_pause(4)
	if not guided or model.phase!="SURFACE" or model.samples.size()!=0: errors.append("Practice start")
	# Exercise real controller movement with live suit, weather and field updates.
	for i: int in range(2):
		film_event("walk_"+str(i+1))
		var destination: Vector3 = world.beacons[i].global_position
		var arrived := false
		player.set_test_move_input(Vector2(0,-1))
		for frame: int in range(12000):
			var offset: Vector3 = destination-player.global_position
			if Vector2(offset.x,offset.z).length()<3: arrived = true; break
			player.camera_yaw = atan2(-offset.x,-offset.z)
			await get_tree().physics_frame
		player.clear_test_move_input()
		if not arrived: errors.append("Blocked guided target "+str(i)); break
		scan_held = true
		film_event("scan_"+str(i+1))
		for frame: int in range(220):
			await get_tree().physics_frame
			if is_instance_valid(overlay): break
		if not model.samples.has(i): errors.append("Guided scan failed "+str(i)); break
		evidence_screen(i)
		film_event("lesson_"+str(i+1)); await film_pause(5)
		var lesson_buttons := overlay.find_children("*","Button",true,false)
		lesson_buttons[0 if i==0 else 1].pressed.emit()
		if not model.interpreted.has(i): errors.append("Beginner evidence lesson did not record answer")
		await film_pause(4)
		resume_surface()
	if model.samples.size()!=2: errors.append("Missing guided evidence")
	var home := false
	film_event("return_home")
	player.set_test_move_input(Vector2(0,-1))
	for frame: int in range(16000):
		var offset: Vector3 = world.to_global(world.habitat)-player.global_position
		if Vector2(offset.x,offset.z).length()<8: home = true; break
		player.camera_yaw = atan2(-offset.x,-offset.z)
		await get_tree().physics_frame
	player.clear_test_move_input()
	if not home or model.integrity<=0 or expedition_return_gaps()!="": errors.append("Guided return not viable")
	habitat_console(); film_event("habitat"); await film_pause(5); begin_return(); film_event("ascent")
	for frame: int in range(300): await get_tree().physics_frame
	if model.phase!="RETURNED": errors.append("Guided ascent/debrief")
	film_event("debrief"); await film_pause(6)
	if campaign.snapshot()!=campaign_before: errors.append("Practice mutated campaign")
	var save_after := FileAccess.get_file_as_string(SAVE) if FileAccess.file_exists(SAVE) else ""
	if save_after!=save_before: errors.append("Practice replaced campaign save")
	for error: String in errors: push_error(error)
	print("GUIDED PLAYTHROUGH: ","PASS" if errors.is_empty() else "FAIL"," / live movement, two held scans, return route, ascent, debrief, campaign/save isolation; oxygen ",model.oxygen," integrity ",model.integrity," elapsed ",model.elapsed)
	get_tree().call_deferred("quit",0 if errors.is_empty() else 1)

func learning_playtest() -> void:
	testing = true; campaign.persistent = false
	var errors: Array[String] = []
	var lessons = preload("res://scripts/beginner_lessons.gd")
	for event: Array in flight.EVENTS:
		if lessons.flight_help(str(event[0])).begins_with("Protect people first."): errors.append("Missing lesson: "+str(event[0]))
	model.configure(1,0); flight.reset(42601)
	for stage: int in range(6):
		flight_screen()
		var correct := int(flight.current()[3])
		var buttons := overlay.find_children("*","Button",true,false)
		buttons[correct].pressed.emit()
		if flight.stage!=stage+1: errors.append("Flight answer did not advance once")
		var feedback := overlay.find_children("*","Button",true,false)
		if feedback.size()!=1: errors.append("Flight feedback missing"); break
		feedback[0].pressed.emit()
	if model.phase!="SURFACE": errors.append("Coached flight did not reach Mars")
	model.configure(1,0); flight.reset(42601); flight_screen()
	var wrong := (int(flight.current()[3])+1)%3
	var buttons := overlay.find_children("*","Button",true,false); buttons[wrong].pressed.emit()
	if flight.mistakes!=1 or model.integrity>=100 or overlay.find_children("*","Button",true,false).size()!=1: errors.append("Wrong-answer feedback missing")
	for error: String in errors: push_error(error)
	print("BEGINNER LEARNING: ","PASS" if errors.is_empty() else "FAIL"," / all 10 flight explanations, six coached decisions, feedback pause, wrong-answer consequence, landing")
	get_tree().quit(0 if errors.is_empty() else 1)

func matching_checkpoint() -> bool:
	for path: String in [SAVE,SAVE+".bak"]:
		if not FileAccess.file_exists(path): continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and str(d.get("campaign_id",""))==campaign.id and int(d.get("expedition_number",0))==campaign.expedition_number and str(d.get("phase",""))=="SURFACE": return true
	return false

func resume_active_flight() -> void:
	guided = false
	if campaign.status!="ACTIVE": return
	selected_seed = campaign.seed_value; regenerate_world(selected_seed); outpost.reset_for_launch(); field.restore({}); traversal.restore({})
	model.configure(1,0); flight.reset(selected_seed); flight_screen()

func rocket_integration() -> void:
	var stock := preload("res://scripts/outpost_cargo.gd").new(); stock.read_draft()
	var v := menu(1000)
	v.add_child(text("VEHICLE INTEGRATION / EXPEDITION %d" % campaign.expedition_number,29,MINT))
	v.add_child(paragraph("One campaign budget covers rocket components, crew architecture and field equipment. Current procurement balance: %d credits. Field payload %.1f / 260kg." % [stock.credits,stock.mass()],18,GOLD))
	var gaps := campaign.missing(stock)
	v.add_child(paragraph("Rocket components complete." if gaps.is_empty() else "REQUIRED: "+", ".join(gaps),18))
	v.add_child(action("ROCKET / FIELD PROCUREMENT",func() -> void: preload("res://scripts/outpost_shop.gd").new().show_shop(self,"Launch","launch_core")))
	if campaign.integrated: v.add_child(paragraph("INTEGRATION VERIFIED / flight clearance granted",21,MINT))
	elif gaps.is_empty():
		var prompts := ["Isolate the propulsion and electrical buses before integration.","Verify independent guidance, pressure and descent sensors.","Clear the range and verify the crew before arming the vehicle."]
		var choices := [["Arm while the crew works","ISOLATE AND SECURE","Bypass the interlocks"],["Use only one display","Ignore the pressure trend","CROSS-CHECK AND VERIFY"],["CLEAR RANGE / CREW GO","Launch without checks","Disable guidance"]]
		v.add_child(paragraph("STEP %d / 3 • %s" % [campaign.integration_step+1,prompts[campaign.integration_step]],20,GOLD))
		for i: int in range(3):
			var choice := i
			v.add_child(action(choices[campaign.integration_step][i],func() -> void:
				var reason := campaign.integrate(stock,choice)
				if reason!="": toast(reason)
				rocket_integration()))
	v.add_child(paragraph("Return quota: %d points. Safe return adds 2,200 credits plus 1.25 × mission points to unspent funds. Vehicle dimensions, grants and procedures are game assumptions." % campaign.quota(),17,GOLD))
	v.add_child(action("BACK TO PLANNING",planning,true)); focus_first(v)

func flight_screen() -> void:
	launch_time = -1
	var event := flight.current(); var v := menu(900)
	v.add_child(text("FLIGHT DIRECTOR / %d OF 6" % [flight.stage+1],16,MINT)); v.add_child(text(event[0],30))
	v.add_child(paragraph(event[1],22)); v.add_child(paragraph("INTEGRITY %.0f%% • OXYGEN %.0f • BATTERY %.0f • INCIDENTS %d" % [model.integrity,model.oxygen,model.battery,flight.mistakes],17,GOLD))
	v.add_child(text("FLIGHT COACH / WHAT YOU NEED TO KNOW",15,MINT))
	v.add_child(paragraph(preload("res://scripts/beginner_lessons.gd").flight_help(str(event[0])),19))
	for i: int in range(3):
		var choice := i
		v.add_child(action(event[2][i],func() -> void:
			var correct := flight.answer(choice)
			if not correct:
				var protected := int(outpost.cargo.kits.get("rocket_radiation",0))>0 or int(outpost.cargo.kits.get("rocket_redundancy",0))>0
				model.integrity = maxf(0,model.integrity-(17 if protected else 27)); model.battery = maxf(0,model.battery-8); model.oxygen = maxf(0,model.oxygen-10)
			if model.integrity<=0: finish(false)
			else: flight_feedback(event,correct)))
	v.add_child(paragraph(event[4],15)); focus_first(v)

func flight_feedback(event: Array, correct: bool) -> void:
	var v := menu(850)
	v.add_child(text("DECISION / "+("CREW PROTECTED" if correct else "HERE IS WHAT TO CHANGE"),15,MINT))
	v.add_child(text("Why that choice matters",31))
	v.add_child(paragraph(preload("res://scripts/beginner_lessons.gd").flight_help(str(event[0])),22))
	v.add_child(paragraph("Recommended action: "+str(event[2][int(event[3])]),21,GOLD))
	if not correct: v.add_child(paragraph("This choice used extra oxygen and battery and damaged the suit. Your next decision can still protect the crew. Read the coach before choosing.",19))
	v.add_child(action("CONTINUE TO LANDING" if flight.finished() else "NEXT DECISION",func() -> void:
		if flight.finished(): land(true)
		else: flight_screen(),true)); focus_first(v)

func gear_menu() -> void:
	var v := menu(850); v.add_child(text("EVA / PERSONAL EQUIPMENT",29,MINT))
	v.add_child(paragraph("Harnesses, crampons, headlamps, filters and liners work while carried. Z routes a rope from an assembled anchor; X attaches. Consumables below are spent when used.",18))
	for id: String in ["oxygen_bottle","spare_cell","medkit","sealant"]:
		var tool := id
		v.add_child(action("USE %s / %d PACKED" % [outpost.catalog()[id].name,outpost.cargo.kits.get(id,0)],func() -> void:
			if int(outpost.cargo.kits.get(tool,0))<=0: toast("Purchase or fabricate this consumable first."); return
			outpost.request_action("gear",{"kind":tool}); gear_menu()))
	v.add_child(action("FIELD ATLAS / EQUIPMENT REQUIREMENTS",field.journal)); v.add_child(action("BACK TO FIELD",resume_surface)); focus_first(v)

func campaign_integration_test() -> void:
	testing = true; campaign.persistent = false
	var errors: Array[String] = []
	var stock := preload("res://scripts/outpost_cargo.gd").new()
	if stock.catalog().size()!=236: errors.append("Catalog count")
	if campaign.commit(stock,88)=="": errors.append("Incomplete rocket accepted")
	if stock.rocket_pack()!="" or stock.starter()!="": errors.append("Campaign packs exceed budget")
	for answer: int in [1,2,0]: campaign.integrate(stock,answer)
	if campaign.commit(stock,88)!="": errors.append("Completed rocket rejected")
	var bank_before: int = campaign.bank
	var grant: int = campaign.settle(true,400)
	if grant!=2700 or campaign.bank!=bank_before+2700 or campaign.total_score!=400 or campaign.expedition_number!=2: errors.append("Success grant/continuation failed")
	var no_duplicate: int = campaign.bank; campaign.settle(true,400)
	if campaign.bank!=no_duplicate: errors.append("Double settlement")
	campaign.status = "ACTIVE"; campaign.settle(false,900)
	if campaign.bank!=0 or campaign.total_score!=0 or campaign.status!="FAILED": errors.append("Permadeath failed")
	if campaign.commit(stock,88)=="": errors.append("Failed campaign revived")
	campaign.restart()
	if campaign.bank!=3200 or campaign.expedition_number!=1: errors.append("Restart failed")
	var ids: Dictionary = {}
	for x: int in range(-32,32):
		for z: int in range(-32,32):
			var cell := Vector2i(x,z); var profile: Dictionary = field.Atlas.profile(42601,cell,stream.kind_at(cell)); ids[profile.id] = true
	if ids.size()<280: errors.append("Atlas sampled diversity: "+str(ids.size()))
	for seed_number: int in [1,42601,20261105]:
		var director := preload("res://scripts/flight_director.gd").new(); director.reset(seed_number)
		for stage: int in range(6): director.answer(int(director.current()[3]))
		if not director.finished() or director.mistakes!=0: errors.append("Flight procedure")
	model.configure(1,0); model.transit(true); resume_surface(); player.enabled = false
	outpost.cargo.kits.anchor = 2; outpost.cargo.kits.rope30 = 1; outpost.cargo.kits.ropebridge = 1; outpost.cargo.kits.harness = 1
	var anchor_ids: Array[int] = []
	for x: float in [-108.,-90.]:
		var at: Vector3 = world.point(x,42)
		var reason: String = outpost.place("anchor",at,0,at+Vector3(0,0,7))
		if reason!="": errors.append("Anchor placement: "+reason); continue
		anchor_ids.append(outpost.next_id-1)
		for stage: int in range(3): outpost.assembly_step(outpost.next_id-1,at+Vector3(0,0,3))
	if anchor_ids.size()==2:
		var reply: String = traversal.create_link(anchor_ids[0],anchor_ids[1],Vector3.ZERO,world.point(-90,45))
		if not reply.begins_with("SUSPENSION") or traversal.links.size()!=1: errors.append("Rope bridge assembly")
		await get_tree().physics_frame; await get_tree().physics_frame
		var midpoint: Vector3 = traversal.point(traversal.links[0].a).lerp(traversal.point(traversal.links[0].b),.35)-Vector3.UP*1.2
		var bridge_ray := PhysicsRayQueryParameters3D.create(midpoint+Vector3.UP*3,midpoint-Vector3.UP*3,4)
		if get_world_3d().direct_space_state.intersect_ray(bridge_ray).is_empty(): errors.append("Suspension deck collision")
		player.position = midpoint; outpost.cargo.kits.harness = 0; traversal.toggle_attach()
		if traversal.attached(): errors.append("Harness requirement bypassed")
		outpost.cargo.kits.harness = 1; traversal.toggle_attach()
		if not traversal.attached(): errors.append("Harness did not attach")
		traversal.toggle_attach()
	var cave_cell := Vector2i.ZERO; var found := false
	for x: int in range(4,14):
		for z: int in range(4,14):
			var candidate := Vector2i(x,z); var profile: Dictionary = field.Atlas.profile(world.world_seed,candidate,stream.kind_at(candidate))
			if profile.cave: cave_cell = candidate; found = true; break
		if found: break
	if not found: errors.append("No cave profile")
	else:
		var target: Vector3 = field.target_for(cave_cell); player.position = target; stream.ensure_near(player.position,true); stream.rebase()
		await get_tree().physics_frame; await get_tree().physics_frame
		if not field.inside_cave(stream.logical(player.position)): errors.append("Cave interior classification")
		var query := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*2,player.position-Vector3.UP*3); query.exclude = [player.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			errors.append("Cave floor collision")
			print("CAVE DEBUG ",cave_cell," player ",player.position," logical ",stream.logical(player.position)," info ",field.cave_info(stream.logical(player.position))," chunk ",stream.chunks[cave_cell].position)
			for node: Node in stream.chunks[cave_cell].get_children():
				if node is MeshInstance3D: print(node.mesh.get_aabb()," at ",node.global_position)
		player.enabled = true; player.floor_max_angle = deg_to_rad(28); player.camera_yaw = 0; player.set_test_move_input(Vector2(0,-1))
		var portal_z: float = field.Atlas.cave_centre(cave_cell).y-25
		for frame: int in range(1800):
			await get_tree().physics_frame
			if stream.logical(player.position).z<portal_z: break
		player.clear_test_move_input()
		if stream.logical(player.position).z>=portal_z: errors.append("Cave egress controller blocked")
	player.position = stream.local(world.point(0,42,.2)); player.velocity = Vector3.ZERO; player.jump_height = Explorer.SUIT_JUMP_HEIGHT; player.enabled = true
	for frame: int in range(45): await get_tree().physics_frame
	var jump_start: float = player.position.y; var apex := jump_start; var air_frames := 0; var launched := false
	player.request_jump()
	for frame: int in range(180):
		await get_tree().physics_frame; apex = maxf(apex,player.position.y)
		if not player.is_on_floor(): launched = true; air_frames += 1
		elif launched: break
	print("MARS MOVEMENT / apex ",apex-jump_start," m / airtime ",air_frames/60.," s / gravity ",player.gravity)
	if apex-jump_start<.65 or apex-jump_start>.9 or air_frames/60.<1.15 or air_frames/60.>1.45: errors.append("Mars jump apex / airtime")
	if absf(player.gravity-3.71)>.001: errors.append("Mars gravity")
	if not ResourceLoader.exists("res://assets/audio/frontier_ambient.wav"): errors.append("Music asset")
	for error: String in errors: push_error(error)
	print("CAMPAIGN INTEGRATION: ","PASS" if errors.is_empty() else "FAIL"," / 236 SKUs, rocket gates, grants, permadeath, restart, sampled atlas diversity, flight, cave collision, rope bridge collision, harness gate, gravity, music")
	await get_tree().process_frame; get_tree().quit(0 if errors.is_empty() else 1)

func make_outpost_capture() -> void:
	model.configure(1,0); model.transit(true)
	outpost.cargo.restore(preload("res://scripts/outpost_cargo.gd").new().snapshot())
	var centre := Vector2(-67,66)
	var arrangement := [["solar",Vector2(-13,-7)],["solar",Vector2(-6,-7)],["battery",Vector2(-10,0)],["oxygen",Vector2(-5,4)],["habitat",Vector2(3,5)],["fabricator",Vector2(-5,12)],["relay",Vector2(2,-8)],["weather",Vector2(11,-6)],["greenhouse",Vector2(11,5)],["spectrometer",Vector2(12,13)]]
	for entry: Array in arrangement:
		outpost.cargo.kits[entry[0]] = 1
		var p: Vector3 = world.point(centre.x+entry[1].x,centre.y+entry[1].y)
		var reason: String = outpost.place(entry[0],p,0,p+Vector3(0,0,7))
		if reason!="": push_warning("Capture placement: "+reason); continue
		var id: int = outpost.next_id-1
		for stage: int in range(3): outpost.assembly_step(id,p+Vector3(0,0,2.8))
	outpost.simulate(1); outpost.refresh_actors()
	player.position = world.point(centre.x+17,centre.y+24,.2); player.camera_yaw = .6; player.camera_pitch = -.16; player.camera_distance = 5.2
	await get_tree().physics_frame

func outpost_integration_test() -> void:
	testing = true; model.configure(1,0); model.transit(true); resume_surface(); player.enabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	var errors: Array[String] = []
	var stock := preload("res://scripts/outpost_cargo.gd").new(); stock.credits = 600
	if stock.starter()!="" or stock.credits!=20 or stock.mass()>260: errors.append("Starter procurement budget/mass")
	var snapshot: Dictionary = stock.snapshot()
	var draft_test := "user://outpost_cargo_verification.json"
	stock.write_draft(draft_test)
	stock.write_draft(draft_test)
	stock.write_draft(draft_test)
	var reloaded_stock := preload("res://scripts/outpost_cargo.gd").new(); reloaded_stock.read_draft(draft_test)
	if reloaded_stock.snapshot()!=snapshot: errors.append("Procurement ledger disk roundtrip failed")
	DirAccess.remove_absolute(draft_test)
	DirAccess.remove_absolute(draft_test+".bak")
	if stock.buy("reactor")=="" or stock.snapshot()!=snapshot: errors.append("Failed purchase consumed resources")
	for id: String in outpost.catalog():
		var asset: Node3D = preload("res://scripts/field_hardware.gd").new().make(id)
		if asset.get_node("Shell").mesh.get_surface_count()<1: errors.append("Missing authored asset: "+id)
		asset.free()
	outpost.cargo = stock
	var positions := {"solar":Vector2(-80,57),"battery":Vector2(-73,59),"oxygen":Vector2(-68,65),"habitat":Vector2(-60,65),"fabricator":Vector2(-69,74),"relay":Vector2(-60,55),"weather":Vector2(-51,55)}
	for id: String in positions:
		var at: Vector2 = positions[id]; var p: Vector3 = world.point(at.x,at.y)
		var reason: String = outpost.place(id,p,0,p+Vector3(0,0,7))
		if reason!="": errors.append("Placement "+id+": "+reason); continue
		var unit_id: int = outpost.next_id-1
		for stage: int in range(3):
			if outpost.assembly_step(unit_id,p+Vector3(0,0,2.8))!="": errors.append("Assembly failed: "+id)
	var second_solar: Vector3 = world.point(-87,57)
	if outpost.place("solar",second_solar,0,second_solar+Vector3(0,0,7))!="": errors.append("Second power wing placement failed")
	else:
		for stage: int in range(3): outpost.assembly_step(outpost.next_id-1,second_solar+Vector3(0,0,3))
	# Overlap and forged remote placement must not consume kits.
	var kit_count: int = int(outpost.cargo.kits.solar)
	var invalid: String = outpost.place("solar",world.point(-80,57),0,world.point(-80,64))
	if invalid=="" or int(outpost.cargo.kits.solar)!=kit_count: errors.append("Overlap validation failed")
	invalid = outpost.place("solar",world.point(200,0),0,world.point(0,0))
	if invalid=="": errors.append("Distant placement accepted")
	var deck_a: Vector3 = world.point(-105,42); var deck_b: Vector3 = world.point(-105,48)
	outpost.cargo.kits.bridge = 3
	var first_deck: String = outpost.place("bridge",deck_a,0,deck_a+Vector3(0,0,7))
	var second_deck: String = outpost.place("bridge",deck_b,0,deck_b+Vector3(0,0,7))
	if first_deck!="" or second_deck!="": errors.append("End-to-end walkway joining failed: "+first_deck+" / "+second_deck)
	if outpost.place("bridge",world.point(-105,45),0,world.point(-98,45))=="": errors.append("Overlapping walkway accepted")
	weather.update(0,"basin",world.world_seed)
	for second: int in range(25): outpost.simulate(1)
	if outpost.tier<2 or outpost.total_power<=0 or not outpost.service_available(world.point(-60,68)): errors.append("Power grid or fabrication commissioning failed")
	var supplied: float = outpost.draw_oxygen(world.point(-60,68),3)
	if supplied<=0: errors.append("Connected oxygen reservoir did not supply shelter")
	var habitat: Dictionary = outpost.installations.filter(func(u: Dictionary) -> bool: return u.kind=="habitat")[0]
	var original_habitat: Array = habitat.p.duplicate()
	habitat.p[0] += 100; outpost.simulate(1)
	if habitat.online or outpost.draw_oxygen(outpost.position_of(habitat),3)>0: errors.append("Disconnected shelter received power/oxygen")
	habitat.p = original_habitat; outpost.simulate(1)
	var buffer_group: Array[Dictionary] = [{"kind":"battery","energy":2.,"online":false,"state":""},{"kind":"habitat","online":false,"state":""}]
	var test_battery: Dictionary = buffer_group[0]; var test_habitat: Dictionary = buffer_group[1]
	outpost.power_group(buffer_group,1)
	if test_battery.energy>0 or not test_habitat.online: errors.append("Battery did not discharge under load")
	for unit: Dictionary in buffer_group: unit.online = false
	outpost.power_group(buffer_group,1)
	if test_habitat.online: errors.append("Depleted battery supplied infinite energy")
	var before: Dictionary = outpost.cargo.snapshot()
	var reason: String = outpost.fabricate("reactor",world.point(-69,74))
	if reason=="" or before!=outpost.cargo.snapshot(): errors.append("Locked crafting was not atomic")
	outpost.cargo.materials.alloy = 30; outpost.cargo.materials.circuits = 30; outpost.cargo.materials.polymer = 30
	if not outpost.fabricate("coupler",world.point(-69,74)).begins_with("KIT FABRICATED"): errors.append("Powered crafting failed")
	# Instrument reward can occur only once for a type and sector.
	for second: int in range(80): outpost.simulate(1)
	var score: int = model.science; var research: int = outpost.research
	for second: int in range(80): outpost.simulate(1)
	if research<1 or outpost.research!=research or model.science!=score: errors.append("Research duplication or no research")
	var recovered: Dictionary = outpost.resource_data(Vector2i.ZERO,1)
	for attempt: int in range(5): outpost.gather(recovered.p)
	if int(outpost.harvested.get(recovered.id,0))!=12: errors.append("Resource recovery exceeded deposit size")
	# Terrain-specific resource locations and depletion.
	var ice_node: Dictionary = {}
	for x: int in range(-10,11):
		for z: int in range(-10,11):
			var node: Dictionary = outpost.resource_data(Vector2i(x,z),2)
			if node.resource=="ice": ice_node = node; break
		if not ice_node.is_empty(): break
	if ice_node.is_empty(): errors.append("No deterministic ice deposit")
	else:
		outpost.installations.append({"id":999,"kind":"ice","p":[ice_node.p.x+3,ice_node.p.y,ice_node.p.z],"stage":3,"health":100.,"energy":0.,"oxygen":0.,"progress":0.,"online":true,"linked":false,"group":999,"state":"ONLINE","yaw":0.})
		var extractor: Dictionary = outpost.unit_by_id(999)
		var before_water: int = outpost.cargo.materials.water
		for second: int in range(6): outpost.operate(extractor,1,[])
		if outpost.cargo.materials.water<=before_water: errors.append("Ice-site extraction failed")
		extractor.p = [0.,0.,0.]; extractor.progress = 0
		before_water = outpost.cargo.materials.water
		for second: int in range(6): outpost.operate(extractor,1,[])
		if outpost.cargo.materials.water!=before_water: errors.append("Off-site extractor created water without ice")
		outpost.cargo.materials.ice = 1
		for second: int in range(6): outpost.operate(extractor,1,[])
		if outpost.cargo.materials.water!=before_water+1 or outpost.cargo.materials.ice!=0: errors.append("Recovered ice processing failed")
		outpost.installations.erase(extractor)
	var record: Dictionary = JSON.parse_string(JSON.stringify(outpost.snapshot()))
	var total: int = outpost.installations.size(); outpost.restore(record)
	if outpost.installations.size()!=total or outpost.research!=research: errors.append("Outpost save restore failed")
	var backup_record := record.duplicate(true); backup_record.installations.append({"kind":"solar","p":[0,0,0]})
	outpost.restore(backup_record)
	if outpost.installations.size()!=total: errors.append("Malformed installation accepted")
	var before_score: int = model.science
	outpost.award_exploration(Vector3(5000,0,5000)); outpost.award_exploration(Vector3(5000,0,5000))
	if model.science!=before_score+8: errors.append("Exploration reward duplicated")
	model.science = 1200
	if model.score()<1200: errors.append("Exploration score still capped")
	# Real previews and menus must instantiate without input or rendering errors.
	preload("res://scripts/outpost_shop.gd").new().show_shop(self)
	outpost.build_menu(); outpost.cargo_menu(); outpost.contract_menu(); clear_menu()
	for error: String in errors: push_error(error)
	print("OUTPOST INTEGRATION: ","PASS" if errors.is_empty() else "FAIL"," / 20 authored models, procurement, capacity, atomic recipes, placement, assembly, power, oxygen, fabrication tiers, research, ice extraction, persistence, UI")
	sfx.stop(); sfx.stream = null; await get_tree().process_frame; get_tree().quit(0 if errors.is_empty() else 1)

func create_stream() -> void:
	stream = preload("res://scripts/frontier_stream.gd").new(); stream.name = "Frontier"; add_child(stream); stream.setup(self)
	player.terrain_ready = func(p: Vector3) -> bool:
		var cell: Vector2i = stream.cell_at(stream.logical(p))
		return stream.is_base(cell) or stream.chunks.has(cell)

func setup_frontier() -> void:
	create_stream()
	lan = preload("res://scripts/lan_session.gd").new(); add_child(lan); lan.setup(self)
	outpost = preload("res://scripts/outpost_system.gd").new(); add_child(outpost); outpost.setup(self)
	traversal = preload("res://scripts/rope_system.gd").new(); add_child(traversal); traversal.setup(self)
	field = preload("res://scripts/field_challenges.gd").new(); add_child(field); field.setup(self)
	music = preload("res://scripts/music_director.gd").new(); add_child(music)
	hazards = preload("res://scripts/hazards.gd").new(); add_child(hazards); hazards.setup(self); hazards.reset(selected_seed)
	goal_marker = Node3D.new(); add_child(goal_marker)
	var ring := TorusMesh.new(); ring.inner_radius = .75; ring.outer_radius = .85
	var material := world.mat(MINT); material.emission_enabled = true; material.emission = MINT
	world.mesh_at(ring,Vector3(0,.1,0),material,goal_marker)
	var l := Label3D.new(); goal_marker.add_child(l); l.text = "NEXT STATION"; l.position.y = 1.7; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = .012; l.font_size = 25
	goal_marker.hide()

func lan_active() -> bool:
	return is_instance_valid(lan) and lan.active and lan.session_ready

func campaign_destination() -> Dictionary:
	var home := world.to_global(world.habitat)
	if model.oxygen<45 or model.battery<20: return {"p":home,"label":"REFILL AT HABITAT"}
	if model.samples.size()>=2 and visited_regions.size()>=2 and model.science>=campaign.quota(): return {"p":home,"label":"RETURN HOME / E AT HABITAT"}
	if model.samples.size()>=2 and visited_regions.size()<2:
		var best := INF; var destination := home
		for i: int in range(world.generator.regions.size()):
			if visited_regions.has(i): continue
			var centre: Vector2 = world.generator.regions[i].centre
			var at: Vector3 = world.to_global(world.point(centre.x,centre.y))
			if at.distance_to(player.global_position)<best: best = at.distance_to(player.global_position); destination = at
		return {"p":destination,"label":"SURVEY ANOTHER DISTRICT"}
	var best := INF; var destination := home
	for i: int in range(world.beacons.size()):
		if model.can_sample(i)!="": continue
		var at: Vector3 = world.beacons[i].global_position
		if at.distance_to(player.global_position)<best: best = at.distance_to(player.global_position); destination = at
	return {"p":destination,"label":"HOLD E / COLLECT EVIDENCE"}

func update_goal_marker() -> void:
	goal_marker.hide()
	if guided:
		goal_marker.global_position = guided_destination(); goal_marker.show()
		var destination: Vector3 = guided_destination()+Vector3.UP*2
		destination_hint.show()
		if player.camera.is_position_behind(destination):
			destination_hint.text = "TURN AROUND / destination behind you"
			destination_hint.position = Vector2(600,190)
		else:
			var projected: Vector2 = player.camera.unproject_position(destination)
			var viewport_size := get_viewport().get_visible_rect().size
			destination_hint.position = Vector2(clampf(projected.x-80,80,viewport_size.x-260),clampf(projected.y-40,185,viewport_size.y-180))
			destination_hint.text = "◆ %s / %d m" % ["HOME" if model.samples.size()>=2 or model.oxygen<45 or model.battery<20 else "SCAN",player.global_position.distance_to(guided_destination())]
		for child: Node in goal_marker.get_children():
			if child is Label3D: child.text = "HOME" if model.samples.size() >= 2 or model.oxygen < 45 or model.battery < 20 else "HOLD E / SCAN"
		return
	destination_hint.hide()
	if stream.active.is_empty():
		var goal := campaign_destination(); var at: Vector3 = goal.p
		goal_marker.global_position = at; goal_marker.show()
		for child: Node in goal_marker.get_children():
			if child is Label3D: child.text = str(goal.label)
		destination_hint.show()
		var offset := at-player.global_position
		var angle := wrapf(atan2(-offset.x,-offset.z)-player.camera_yaw,-PI,PI)
		var bearing := "AHEAD" if absf(angle)<.4 else ("TURN LEFT" if angle>0 else "TURN RIGHT")
		destination_hint.text = "%s / %dm / %s" % [goal.label,Vector2(offset.x,offset.z).length(),bearing]
		destination_hint.position = Vector2(36,155)
		return
	var site: Dictionary = stream.active; var p: Vector3 = site.position
	if site.type == "parkour": p = stream.course_point(site,stream.active_step)
	elif site.type in ["seismic","survey","navigation"]:
		var angle: float = stream.active_step*TAU/3; p += Vector3(cos(angle)*22,0,sin(angle)*22); p.y = stream.surface(p.x,p.z)
	elif site.type in ["sample","rescue"]:
		var cell: Vector2i = stream.cell_at(stream.logical(player.position))
		if site.type == "rescue" and stream.logical(player.position).distance_to(site.position)<35: cell += Vector2i.RIGHT
		p = stream.site_data(cell).position+Vector3(12,0,14); p.y = stream.surface(p.x,p.z)
	goal_marker.position = stream.local(p); goal_marker.show()

func journal() -> void:
	var v := menu(840)
	v.add_child(text("FIELD JOURNAL / ENDLESS HORIZONS",29,MINT))
	v.add_child(action("ENGINEERING CONTRACTS / EXPANSION",outpost.contract_menu))
	v.add_child(action("TERRAIN ATLAS / DISCOVERY HOOKS",field.journal))
	v.add_child(paragraph("Seed %d • Sector %s • %d surveyed • %d activities complete • %d spares" % [world.world_seed,stream.key(stream.cell_at(stream.logical(player.position))),stream.visited.size(),stream.completed_count,stream.salvage],18,GOLD))
	if not stream.active.is_empty():
		v.add_child(paragraph(stream.activity_prompt(),20,MINT))
		v.add_child(action("ABANDON CURRENT ACTIVITY",func() -> void: stream.cancel("Activity abandoned. Restart at its original beacon."); journal()))
	v.add_child(paragraph("Every 256 m sector has a generated activity and a service pod. Gold beacons reveal nearby work. New terrain loads beyond the original survey area; return visits reproduce the same seed and completed work stays completed.",17))
	var choices: Array[Dictionary] = []
	for chunk: Node3D in stream.chunks.values():
		var site: Dictionary = chunk.get_meta("site",{})
		if not site.is_empty() and not stream.completed.has(site.id): choices.append(site)
	choices.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.position.distance_to(stream.logical(player.position))<b.position.distance_to(stream.logical(player.position)))
	for i: int in range(mini(6,choices.size())):
		var site: Dictionary = choices[i]; var d: Vector3 = site.position-stream.logical(player.position)
		v.add_child(paragraph("%s • %dm • ΔX %+.0f / ΔZ %+.0f" % [site.name,d.length(),d.x,d.z],16))
	v.add_child(paragraph("B build • C fabricate/cargo • G recover materials • hold E assemble/use • F activity • R rover • SPACE jump • L LAN crew. Outer pods contain one emergency reserve. Build a powered shelter and oxygen processor for sustained support. N spends spares on an emergency kit.",16))
	v.add_child(action("RETURN TO THE FIELD",resume_surface,true)); focus_first(v)

func lan_menu() -> void:
	if guided: toast("Practice is solo. Choose a campaign mission from the title screen for LAN play."); return
	var v := menu(760)
	v.add_child(text("LOCAL NETWORK CREW",32,MINT))
	v.add_child(paragraph("Up to four players. One PC hosts the expedition; others join its local IP. All players need this same build. No account or external server is used.",18))
	if lan.active:
		v.add_child(paragraph(lan.status_text,20,GOLD))
		if lan.is_host:
			var ips: Array[String] = []
			for address: String in IP.get_local_addresses():
				if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."): ips.append(address)
			v.add_child(paragraph("Host IP candidates: "+", ".join(ips)+"\nPort: UDP 24642. Share the address on your router's network.",17))
		v.add_child(action("LEAVE LOCAL NETWORK",func() -> void: lan.close(); lan_menu()))
	else:
		v.add_child(action("HOST THIS EXPEDITION",func() -> void:
			if model.phase != "SURFACE":
				regenerate_world(selected_seed)
				outpost.reset_for_launch()
				toast("Launch and land the expedition first, then host your crew with L."); rocket_integration(); return
				model.configure(selected_loadout,0); model.transit(true); player.position = world.point(0,42,.2)
			var result: Error = lan.host()
			if result != OK: toast("Could not host: "+error_string(result))
			lan_menu(),true))
		var ip := LineEdit.new(); ip.placeholder_text = "Host IPv4 address, e.g. 192.168.1.20"; ip.custom_minimum_size.y = 44; v.add_child(ip)
		v.add_child(action("JOIN HOST",func() -> void:
			var result: Error = lan.join(ip.text.strip_edges())
			if result != OK: toast("Enter a valid local IP address. "+error_string(result))
			else: lan_menu()))
	v.add_child(paragraph("Allow the game on PRIVATE networks if Windows asks. Guest Wi-Fi/AP isolation may prevent peer connections. The host must keep the game open. Evidence and completed activities are shared; life support stays personal. Menus pause only your astronaut. Host migration is unavailable.",16,GOLD))
	v.add_child(action("BACK TO FIELD" if model.phase == "SURFACE" else "BACK",resume_surface if model.phase == "SURFACE" else title_screen)); focus_first(v)

func activity_expected(site: Dictionary,stage: int) -> int:
	# Choices test a short procedure; each task family has a different sequence.
	var sequences := {"relay":[1,0,2],"solar":[0,2,1],"rescue":[2,0,1],"drill":[0,1,2],"ice":[0,1,2],"meteorite":[1,2,0],"cache":[2,1,0]}
	return int(sequences.get(str(site.type),[0,1,2])[clampi(stage,0,2)])

func activity_console(site: Dictionary,new_task := true) -> void:
	if new_task: puzzle_stage = 0
	var v := menu(790)
	v.add_child(text(site.name,29,MINT))
	v.add_child(paragraph("PROCEDURE %d / 3 • +%d science • +2 spares" % [puzzle_stage+1,site.reward],18,GOLD))
	var procedures := {
		"relay":[["A short in the field relay is tripping its bus. First make the unit safe.",["Bridge the fuse","Isolate the power bus","Increase the current limit"]],["The breaker is isolated. Restore the protected connection.",["Replace the damaged fuse","Bypass protection","Reconnect bare conductors"]],["Confirm that the repair is effective before returning to service.",["Transmit continuously","Seal without testing","Run a low-power handshake"]]],
		"solar":[["Fine dust blankets the array. Start maintenance safely.",["Isolate and secure the array","Spray water over live contacts","Short the terminals"]],["Remove dust while preserving the panel coating.",["Sandblast the surface","Chip it with the drill","Use the soft dry brush"]],["Check output before reconnecting the habitat.",["Assume rated power","Measure open-circuit output","Override the bus controller"]]],
		"rescue":[["An autonomous rover is stranded with a damaged drive.",["Run all wheels at maximum","Tow against the brake","Isolate the drive power"]],["Free the wheel and preserve its bearings.",["Clear the jam and inspect the wheel","Strike the motor casing","Lubricate with loose regolith"]],["Start its recovery return.",["Send it down the steepest slope","Select low-speed recovery mode","Disable all hazard checks"]]],
		"drill":[["Select a core without contaminating its context.",["Record the outcrop and clean the tool","Drill without recording","Mix surface dust into the core"]],["The drill is approaching its torque limit.",["Increase torque indefinitely","Reduce feed rate and clear cuttings","Force the stuck bit"]],["Preserve the sample for later interpretation.",["Call it a biosignature","Leave the sample exposed","Seal and label its provenance"]]],
		"meteorite":[["A dark rock may be a meteorite. Choose the next observation.",["Declare it extraterrestrial","Record context and inspect its texture","Assume black colour proves origin"]],["Compare composition using the instrument.",["Use colour as chemistry","Infer its age from shape","Acquire a calibrated spectrum"]],["State a defensible result.",["Candidate pending further analysis","Confirmed life-bearing fragment","Precisely dated from one spectrum"]]],
		"cache":[["A supply cache seal appears damaged.",["Open the oxygen cylinder immediately","Ignore the seal","Inspect pressure and contamination indicators"]],["Choose what is safe to recover.",["All contents regardless of condition","Only sealed verified supplies","Unknown loose chemicals"]],["Preserve useful logistics information.",["Log contents, condition and location","Erase the manifest","Assume unlimited supplies"]]]}
	var family := "drill" if site.type == "ice" else str(site.type)
	var steps: Array = procedures.get(family,procedures.meteorite)
	var step: Array = steps[puzzle_stage]
	v.add_child(paragraph(step[0],21))
	for i: int in range(3):
		var choice := i
		v.add_child(action(step[1][i],func() -> void:
			if lan_active() and not lan.is_host: lan.activity_answer.rpc_id(1,choice)
			if choice != activity_expected(site,puzzle_stage):
				puzzle_stage = 0; toast("Procedure rejected / review the safe order."); activity_console(site,false); return
			puzzle_stage += 1
			if puzzle_stage < 3: activity_console(site,false)
			else:
				if site.type == "rescue": stream.active_step = 1; resume_surface(); toast("Recovery initiated. Reach a different field pod >35m away.")
				else:
					model.battery = maxf(0,model.battery-(10 if site.type in ["drill","ice"] else 3))
					stream.finish_activity(); resume_surface()))
	v.add_child(action("CANCEL PROCEDURE",func() -> void: stream.cancel("Procedure cancelled"); resume_surface())); focus_first(v)

func deploy_waypoint() -> void:
	if lan_active() and not lan.is_host: toast("Only the host can deploy shared supply waypoints."); return
	if stream.salvage < 2 or model.battery < 12: toast("Supply waypoint needs 2 spares and 12 battery."); return
	stream.salvage -= 2; model.battery -= 12
	model.oxygen = minf(float(Model.LOADOUTS[model.loadout].oxygen),model.oxygen+35)
	model.integrity = minf(100,model.integrity+15)
	toast("EMERGENCY WAYPOINT / +35 oxygen, +15 integrity • 2 spares consumed")
	var p: Vector3 = player.position+Vector3(2,0,0)
	world.cylinder(p+Vector3(0,.5,0),.25,1,world.mat(GOLD),stream)
	checkpoint()

func frontier_integration_test() -> void:
	testing = true; model.configure(1,0); model.transit(true); resume_surface()
	var errors: Array[String] = []
	# Shared edges, deterministic sites, negative and far coordinate generation.
	for cell: Vector2i in [Vector2i(3,0),Vector2i(-5,8),Vector2i(97,-103),Vector2i(1001,999)]:
		var a: Dictionary = stream.site_data(cell); var b: Dictionary = stream.site_data(cell)
		if a != b: errors.append("Site determinism failed")
		var x: float = (cell.x+1)*256.0; var z: float = cell.y*256.0+112
		if absf(stream.height(x-.001,z)-stream.height(x+.001,z))>.02: errors.append("Terrain seam at "+str(cell))
		player.position = stream.local(Vector3(cell.x*256+128,stream.surface(cell.x*256+128,cell.y*256+128)+1,cell.y*256+128))
		stream.ensure_near(player.position,true); stream.rebase()
		for frame: int in range(8): await get_tree().physics_frame
		var ray := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*10,player.position-Vector3.UP*20)
		ray.exclude = [player.get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty(): errors.append("Streamed terrain has no collision "+str(cell))
		if player.position.y < stream.surface(stream.logical(player.position).x,stream.logical(player.position).z)-2: errors.append("Fell through chunk")
		if stream.chunks.size()>49: errors.append("Unbounded loaded chunk count")
	var far_position: Vector3 = stream.logical(player.position)
	if far_position.length()<100000: errors.append("Far-distance rebase did not preserve logical position")
	# Complete once, unload, regenerate, and restore the modification record.
	stream.active = stream.site_data(Vector2i(1001,999)); var id: String = stream.active.id
	stream.finish_activity(); var science_before: int = model.science
	stream.active = stream.site_data(Vector2i(1001,999)); stream.finish_activity()
	if model.science != science_before or not stream.completed.has(id): errors.append("Duplicate activity reward")
	var record: Dictionary = JSON.parse_string(JSON.stringify(stream.snapshot())); stream.restore(record)
	if not stream.completed.has(id): errors.append("Frontier persistence failed")
	# Real takeoff under 3.71 m/s². No externally forced velocity.
	player.position = stream.local(Vector3(62,world.elevation(62,65)+.2,65)); stream.ensure_near(player.position,true); stream.rebase()
	for frame: int in range(50): await get_tree().physics_frame
	var start_y: float = player.position.y; var peak := start_y
	player.jump_height = Explorer.SUIT_JUMP_HEIGHT; player.request_jump()
	for frame: int in range(100):
		await get_tree().physics_frame; peak = maxf(peak,player.position.y)
	if peak-start_y<.6 or peak-start_y>1.0: errors.append("Mars jump height invalid: "+str(peak-start_y))
	# Traverse all course platforms with controller input and buffered jumps.
	var course: Dictionary = stream.site_data(Vector2i(0,-1))
	player.position = stream.local(course.position+Vector3(0,.2,8)); player.velocity = Vector3.ZERO
	stream.ensure_near(player.position,true); player.enabled = true; player.jump_height = Explorer.SUIT_JUMP_HEIGHT
	stream.active = course.duplicate(); stream.active_step = 0; stream.active_time = 0
	for stage: int in range(7):
		var goal: Vector3 = stream.local(stream.course_point(course,stage)); var reached := false
		for frame: int in range(700):
			var offset: Vector3 = goal-player.position; var horizontal := Vector2(offset.x,offset.z).length()
			player.camera_yaw = atan2(-offset.x,-offset.z)
			player.set_test_move_input(Vector2(0,-1) if horizontal > .25 else Vector2.ZERO)
			if horizontal < 3.6 and horizontal > .35 and player.is_on_floor() and frame%70 == 0: player.request_jump()
			await get_tree().physics_frame
			if player.is_on_floor() and horizontal < 1.1 and player.position.y >= goal.y-.15: reached = true; break
		player.clear_test_move_input()
		if not reached: errors.append("Parkour controller failed platform %d at %s toward %s" % [stage+1,player.position,goal]); break
		stream.active_step = stage
		stream.tick(1.0/60)
	if not stream.completed.has(course.id): errors.append("Course did not award completion")
	# Exercise the real procedure buttons, including a rejected answer.
	var relay: Dictionary = stream.site_data(Vector2i.ZERO); stream.active = relay.duplicate(); activity_console(relay)
	var buttons := overlay.find_children("*","Button",true,false)
	buttons[0].pressed.emit()
	if puzzle_stage != 0 or stream.completed.has(relay.id): errors.append("Incorrect repair answer accepted")
	for stage: int in range(3):
		buttons = overlay.find_children("*","Button",true,false)
		buttons[activity_expected(relay,stage)].pressed.emit()
	if not stream.completed.has(relay.id): errors.append("Repair procedure did not finish")
	clear_menu()
	for error: String in errors: push_error(error)
	print("FRONTIER INTEGRATION: ","PASS" if errors.is_empty() else "FAIL"," / streamed collision, seams, bounded chunks, 250km rebase, deterministic activities, persistence, duplicate rewards, Mars jump, seven-platform course, repair UI")
	sfx.stop(); sfx.stream = null; await get_tree().process_frame; get_tree().quit(0 if errors.is_empty() else 1)

func lan_integration_test() -> void:
	testing = true; model.configure(1,0); model.transit(true); resume_surface(); player.enabled = false
	var errors: Array[String] = []
	var host_test := "--lan-host-test" in OS.get_cmdline_user_args()
	if host_test:
		campaign.status = "ACTIVE"
		var relay_position: Vector3 = stream.site_data(Vector2i.ZERO).position
		player.position = relay_position-Vector3(3,0,0)
		world.beacons[0].position = relay_position
		outpost.cargo.kits.beacon = 1
		if lan.host()!=OK: errors.append("Host failed to bind")
		print("LAN TEST HOST READY")
		var saw_client := false
		for frame: int in range(1700):
			await get_tree().physics_frame
			if not lan.peers.is_empty(): saw_client = true
			if model.samples.has(0): world.beacons[0].position = world.point(-35,-30)
		if not saw_client: errors.append("No client handshake")
		if not model.samples.has(0): errors.append("Client scan did not reach host")
		if model.samples.has(1): errors.append("Out-of-range evidence request accepted")
		if not stream.completed.has("0:0"): errors.append("Client activity reward not verified")
		if outpost.installations.size()!=1 or outpost.installations[0].stage!=3: errors.append("Client construction was not commissioned")
		if campaign.status!="FAILED" or campaign.bank!=0 or campaign.total_score!=0: errors.append("Shared campaign death did not wipe funds")
		if not lan.missions.is_empty(): errors.append("Out-of-range activity request accepted")
	else:
		if lan.join("127.0.0.1")!=OK: errors.append("Client failed to initialize")
		for frame: int in range(400):
			await get_tree().physics_frame
			if lan.session_ready: break
		if not lan.session_ready: errors.append("Client never received seeded world")
		else:
			player.enabled = false
			for frame: int in range(50): await get_tree().physics_frame
			var original_position: Vector3 = player.position
			lan.movement.rpc_id(1,Vector3(9000,0,9000),0.0,false)
			for frame: int in range(25): await get_tree().physics_frame
			if player.position.distance_to(original_position)>3: errors.append("Invalid movement was not corrected")
			lan.request_sample.rpc_id(1,0); lan.request_sample.rpc_id(1,1); lan.begin_activity.rpc_id(1,Vector2i(900,900))
			lan.begin_activity.rpc_id(1,Vector2i.ZERO)
			for answer: int in [1,0,2]: lan.activity_answer.rpc_id(1,answer)
			lan.finish_activity.rpc_id(1)
			for frame: int in range(100): await get_tree().physics_frame
			if not model.samples.has(0): errors.append("Shared evidence not replicated")
			if lan.remotes.is_empty(): errors.append("Host avatar not replicated")
			if not stream.completed.has("0:0"): errors.append("Shared activity reward not replicated")
			var build_position: Vector3 = stream.logical(player.position)+Vector3(4,0,0); build_position.y = stream.surface(build_position.x,build_position.z)
			lan.request_outpost.rpc_id(1,"place",{"kind":"beacon","p":[build_position.x,build_position.y,build_position.z],"yaw":0.0})
			for frame: int in range(50): await get_tree().physics_frame
			if outpost.installations.size()!=1: errors.append("Client placement not replicated")
			else:
				var build_id: int = outpost.installations[0].id
				lan.begin_outpost_assembly.rpc_id(1,build_id); lan.request_outpost.rpc_id(1,"assemble",{"id":build_id})
				for frame: int in range(30): await get_tree().physics_frame
				if outpost.installations[0].stage!=0: errors.append("Instant assembly exploit accepted")
				for stage: int in range(3):
					lan.begin_outpost_assembly.rpc_id(1,build_id)
					for frame: int in range(135): await get_tree().physics_frame
					lan.request_outpost.rpc_id(1,"assemble",{"id":build_id})
					for frame: int in range(25): await get_tree().physics_frame
				if outpost.installations[0].stage!=3: errors.append("Timed shared assembly failed")
			var saved_seed: int = world.world_seed
			lan.close()
			for frame: int in range(30): await get_tree().physics_frame
			lan.join("127.0.0.1")
			for frame: int in range(400):
				await get_tree().physics_frame
				if lan.session_ready: break
			if not lan.session_ready or world.world_seed!=saved_seed or not model.samples.has(0) or outpost.installations.size()!=1 or outpost.installations[0].stage!=3: errors.append("Late rejoin progress failed")
			for frame: int in range(50): await get_tree().physics_frame
			lan.request_campaign_failure.rpc_id(1)
			for frame: int in range(60): await get_tree().physics_frame
			if campaign.status!="FAILED" or campaign.bank!=0: errors.append("Crew campaign failure did not replicate")
	for error: String in errors: push_error(error)
	print("LAN ","HOST" if host_test else "CLIENT"," INTEGRATION: ","PASS" if errors.is_empty() else "FAIL"," / handshake, matching seed, avatars, evidence, activities, shared construction, timed assembly, late rejoin, rejected distant requests")
	lan.close(); sfx.stop(); sfx.stream = null; await get_tree().process_frame; get_tree().quit(0 if errors.is_empty() else 1)

func _ready() -> void:
	guided_film = "--guided-film" in OS.get_cmdline_user_args()
	if guided_film or "--film-adventure" in OS.get_cmdline_user_args():
		get_viewport().set_disable_input(true); DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	isolated_demo = "--landing-demo" in OS.get_cmdline_user_args() or guided_film or "--film-adventure" in OS.get_cmdline_user_args()
	get_window().title = "Mohashunnyo — Frontier 13"
	var automated := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture=") or argument.ends_with("-test") or argument.ends_with("-demo") or argument in ["--guided-film","--film-adventure"]: automated = true
	if "--outpost-test" in OS.get_cmdline_user_args(): testing = true
	campaign.persistent = not automated
	if not automated: campaign.read()
	if not automated:
		var rng := RandomNumberGenerator.new(); rng.randomize(); selected_seed = rng.randi_range(1,999999999)
	for a: String in ["forward","backward","left","right","sprint"]:
		if not InputMap.has_action(a): InputMap.add_action(a)
	var bindings := {"forward":KEY_W,"backward":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT}
	for a: String in bindings:
		var e := InputEventKey.new(); e.physical_keycode = bindings[a]
		if not InputMap.action_has_event(a,e): InputMap.action_add_event(a,e)
	world = World.new(); world.world_seed = selected_seed; add_child(world); world.build()
	quality = Gfx.quality(); Gfx.grade(world.environment_resource,quality); Gfx.viewport_quality(get_viewport(),quality)
	install_targets()
	player = Explorer.new(); player.suited = true; player.gravity = Explorer.MARS_GRAVITY; add_child(player)
	player.hard_landing.connect(func(speed: float) -> void:
		if model.phase == "SURFACE" and not testing:
			model.integrity = maxf(0,model.integrity-maxf(0,(speed*speed/(2*3.71)-2.5)*4.5)); toast("HARD LANDING / suit integrity reduced. Use low routes or climbing gear."))
	player.position = world.point(0,42,0.2); player.camera_yaw = 0.15; player.camera_pitch = -0.16
	player.camera.far = 2200
	cine = Camera3D.new(); add_child(cine); cine.fov = 55; cine.far = 1200
	sfx = AudioStreamPlayer.new(); add_child(sfx); sfx.volume_db = -18
	build_ui()
	build_orbit()
	build_weather_visuals()
	build_rover()
	setup_frontier()
	if "--film-adventure" in OS.get_cmdline_user_args():
		await preload("res://scripts/film_adventure.gd").new().run(self); return
	if guided_film:
		await guided_playtest(); return
	if "--adventure-test" in OS.get_cmdline_user_args():
		await preload("res://scripts/test_adventure.gd").new().run(self); return
	if isolated_demo:
		model.configure(1,0); selected_seed = 42601; begin_descent(true); return
	if "--learning-test" in OS.get_cmdline_user_args():
		await learning_playtest(); return
	if "--guided-test" in OS.get_cmdline_user_args():
		await guided_playtest(); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_mode = arg.get_slice("=",1)
		if arg == "--expedition-test": testing = true
	if "--campaign-test" in OS.get_cmdline_user_args():
		await campaign_integration_test(); return
	if "--outpost-test" in OS.get_cmdline_user_args():
		await outpost_integration_test(); return
	if "--lan-host-test" in OS.get_cmdline_user_args() or "--lan-client-test" in OS.get_cmdline_user_args():
		await lan_integration_test(); return
	if "--frontier-test" in OS.get_cmdline_user_args():
		await frontier_integration_test(); return
	if testing:
		model.weather_driven = false
		await integration_test(); return
	if capture_mode != "":
		model.configure(1,0); model.transit(true)
		if capture_mode == "surface": resume_surface()
		elif capture_mode == "outpost":
			await make_outpost_capture(); resume_surface()
		elif capture_mode in ["cave","atlas-peak"]:
			var chosen := Vector2i(5,4)
			for x: int in range(3,14):
				var found := false
				for z: int in range(3,14):
					var cell := Vector2i(x,z); var profile: Dictionary = field.profile_at(Vector3(x*256+72,0,z*256+192))
					if (capture_mode=="cave" and profile.cave) or (capture_mode=="atlas-peak" and profile.mountain): chosen = cell; found = true; break
				if found: break
			outpost.cargo.kits.headlamp = 1
			var at: Vector3 = field.target_for(chosen) if capture_mode=="cave" else Vector3(chosen.x*256+128,stream.surface(chosen.x*256+128,chosen.y*256+128),chosen.y*256+128)
			player.position = at+Vector3.UP*.1; stream.ensure_near(player.position,true); stream.rebase(); resume_surface()
			if capture_mode=="cave": player.toggle_camera_view(); player.camera_yaw = 0; player.camera_pitch = -.08
			else:
				var target: Vector3 = field.target_for(chosen)-stream.logical(player.position); player.camera_yaw = atan2(-target.x,-target.z); player.camera_pitch = .05
			field.tick(.01)
		elif capture_mode == "hardware":
			preload("res://scripts/outpost_shop.gd").new().show_shop(self,"Power","solar")
		elif capture_mode.begins_with("hardware-"):
			var id := capture_mode.trim_prefix("hardware-")
			preload("res://scripts/outpost_shop.gd").new().show_shop(self,str(outpost.catalog()[id].category),id)
		elif capture_mode in ["frontier","course"]:
			var at: Vector3 = Vector3(1152,0,1152) if capture_mode == "frontier" else stream.site_data(Vector2i(0,-1)).position+Vector3(0,0,9)
			at.y = stream.surface(at.x,at.z)+.2; player.position = at; stream.ensure_near(at,true); player.camera_yaw = -.3; player.camera_pitch = -.12; resume_surface()
		elif capture_mode in ["storm","cold","devils"]:
			var requested := {"storm":"LOCAL DUST FRONT","cold":"COLD TWILIGHT","devils":"DUST DEVILS"}
			for block: int in range(1,80):
				weather.update(block*55+1,"basin",world.world_seed)
				if weather.state == requested[capture_mode]: model.elapsed = block*55+1; break
			player.position = world.point(-30,-25,0.1)
			if capture_mode == "cold":
				var p: Vector2 = world.generator.regions[4].centre; var direction := p.normalized(); var at := p-direction*120
				player.position = world.point(at.x,at.y,0.1); player.camera_yaw = atan2(-direction.x,-direction.y); player.camera_pitch = -0.12
			resume_surface()
		elif capture_mode == "debrief": model.collect(0); model.collect(1); finish(true)
		elif capture_mode == "planning": cinematic(); planning()
		elif capture_mode == "evidence": model.collect(0); evidence_screen(0)
		elif capture_mode == "beginner-lesson": guided = true; model.collect(0); evidence_screen(0)
		elif capture_mode == "flight-coach": flight.reset(selected_seed); flight_screen()
		elif capture_mode == "orbit": begin_expedition(); launch_time = -1
		elif capture_mode.begins_with("region"):
			var region_index := clampi(capture_mode.trim_prefix("region").to_int(),0,5)
			var centre: Vector2 = world.generator.regions[region_index].centre
			var direction := centre.normalized(); var at := centre-direction*120
			player.position = world.point(at.x,at.y,0.2); player.camera_pitch = -0.15; player.camera_yaw = atan2(-direction.x,-direction.y)
			resume_surface()
		elif capture_mode == "suit":
			player.camera_yaw = PI-0.3; player.camera_pitch = -0.04; player.camera_distance = 3.0; resume_surface()
		elif capture_mode == "rover":
			resume_surface(); set_driving(true); player.camera_yaw = -0.45; player.camera_pitch = -0.12
		else: title_screen()
		player.enabled = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif get_tree().has_meta("ground_manifest"):
		var manifest: Dictionary = get_tree().get_meta("ground_manifest")
		selected_loadout = clampi(int(manifest.get("loadout",1)),0,2); selected_site = clampi(int(manifest.get("site",0)),0,1)
		selected_seed = clampi(int(manifest.get("seed",selected_seed)),1,999999999); begin_expedition()
		if "--ground-transfer-test" in OS.get_cmdline_user_args():
			var valid := model.phase == "TRANSIT" and model.loadout == int(manifest.get("loadout",1)) and model.site==int(manifest.get("site",0)) and not get_tree().has_meta("ground_manifest") and model.log.size() == 3
			valid = valid and model.science == int(manifest.get("lab_science",0))+(15 if model.site==1 else 0) and landing_fuel_bonus == float(manifest.get("fuel_bonus",0))
			print("GROUND TRANSFER: ","PASS" if valid else "FAIL")
			get_tree().quit(0 if valid else 1)
	else: title_screen()

func panel_style(color := Color(0.035,0.065,0.085,0.97), border := Color("354b53")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = color; s.border_color = border
	s.set_border_width_all(1); s.set_corner_radius_all(5)
	s.content_margin_left = 24; s.content_margin_right = 24; s.content_margin_top = 20; s.content_margin_bottom = 20
	return s

func text(value: String, size := 18, color := Color("e8e7de")) -> Label:
	var l := Label.new(); l.text = value; l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func paragraph(value: String, size := 18, color := Color("a7b9bd")) -> Label:
	var l := text(value,size,color); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func action(value: String, callback: Callable, primary := false) -> Button:
	var b := Button.new(); b.text = value; b.custom_minimum_size.y = 48
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",Color("10242b") if primary else Color("e4e9df"))
	b.add_theme_stylebox_override("normal",panel_style(MINT if primary else Color("132830")))
	b.add_theme_stylebox_override("hover",panel_style(Color("8bded2") if primary else Color("294951"),MINT))
	b.add_theme_stylebox_override("focus",panel_style(Color("466a6b"),GOLD))
	b.pressed.connect(func() -> void: tone(560,0.055); callback.call())
	return b

func build_ui() -> void:
	canvas = CanvasLayer.new(); add_child(canvas)
	ui = Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; canvas.add_child(ui)
	hud = Control.new(); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(hud)
	var top := PanelContainer.new(); top.position = Vector2(32,26); top.size = Vector2(560,110); top.add_theme_stylebox_override("panel",panel_style()); hud.add_child(top)
	var v := VBoxContainer.new(); top.add_child(v)
	v.add_child(text("M O H A S H U N N Y O     /     FIELD OPERATIONS",15,MINT))
	objective = text("SECURE TWO EVIDENCE TARGETS. RETURN HOME.",21); v.add_child(objective)
	status = text("ISIDIS BASIN  /  SOL 01",13,GOLD); v.add_child(status)
	var right := PanelContainer.new(); right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-355,26); right.size = Vector2(323,140); right.add_theme_stylebox_override("panel",panel_style()); hud.add_child(right)
	resources = text("",18); right.add_child(resources)
	var reserve_column := VBoxContainer.new(); reserve_column.add_theme_constant_override("separation",7)
	right.remove_child(resources); right.add_child(reserve_column); reserve_column.add_child(resources)
	for key: String in ["AIR","TOOL BATTERY","SUIT","THRUSTER"]:
		var row := HBoxContainer.new(); reserve_column.add_child(row)
		var caption := text(key,12,MINT); caption.custom_minimum_size.x = 110; row.add_child(caption)
		var bar := ProgressBar.new(); bar.max_value = 100; bar.show_percentage = true; bar.custom_minimum_size = Vector2(160,20)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(bar); reserve_bars[key] = bar
	var bottom := PanelContainer.new(); bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(32,-106); bottom.size = Vector2(1040,74); bottom.add_theme_stylebox_override("panel",panel_style()); hud.add_child(bottom)
	var bv := VBoxContainer.new(); bottom.add_child(bv)
	prompt = text("",19,MINT); bv.add_child(prompt)
	control_hint = text("WASD Move • Mouse Look • Hold E Scan • R Rover • Tab Map • F1 Help • Esc Pause",14)
	bv.add_child(control_hint)
	map_view = MapView.new(); map_view.expedition = self; map_view.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	map_view.position = Vector2(-280,-328); map_view.size = Vector2(248,248); map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(map_view)
	var map_label := text("N ↑    ORBITAL SURVEY / TAB",12,MINT); map_label.position = Vector2(10,8); map_view.add_child(map_label)
	notice = text("",20,GOLD); notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_color_override("font_outline_color",Color("122229")); notice.add_theme_constant_override("outline_size",6)
	notice.position = Vector2(-440,180); notice.size = Vector2(880,75); notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hud.add_child(notice)
	scan_bar = ProgressBar.new(); scan_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	scan_bar.position = Vector2(-180,-155); scan_bar.size = Vector2(360,14); scan_bar.show_percentage = false; scan_bar.max_value = 3; hud.add_child(scan_bar); scan_bar.hide()
	var cross := text("·",24); cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER); cross.position = Vector2(-4,-16); hud.add_child(cross)
	destination_hint = text("",23,MINT)
	destination_hint.add_theme_color_override("font_outline_color",Color("0b1820")); destination_hint.add_theme_constant_override("outline_size",7)
	hud.add_child(destination_hint); destination_hint.hide()

func update_reserve_bars() -> void:
	var layout: Dictionary = Model.LOADOUTS[model.loadout]
	var values := {"AIR":model.oxygen/float(layout.oxygen)*100,"TOOL BATTERY":model.battery/float(layout.battery)*100,"SUIT":model.integrity,"THRUSTER":player.jet_fuel}
	for key: String in reserve_bars:
		var bar: ProgressBar = reserve_bars[key]; bar.value = float(values[key])
		bar.get_parent().visible = key!="THRUSTER" or not guided
		var color := MINT if bar.value>=35 else (GOLD if bar.value>=15 else Color("ff6655"))
		if bar.get_meta("reserve_color",Color.TRANSPARENT)!=color:
			var fill := StyleBoxFlat.new(); fill.bg_color = color; fill.set_corner_radius_all(4)
			bar.add_theme_stylebox_override("fill",fill); bar.set_meta("reserve_color",color)
	resources.text = "EVIDENCE %d / 2\n%s" % [model.samples.size(),"PRACTICE / SAVE SAFE" if guided else "SCIENCE %d / %d" % [model.science,campaign.quota()]]

func clear_menu() -> void:
	if is_instance_valid(overlay): overlay.queue_free(); overlay = null

func menu(width := 660, left := false) -> VBoxContainer:
	clear_menu(); player.enabled = false; player.velocity = Vector3.ZERO; scan_held = false
	if is_instance_valid(destination_hint): destination_hint.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay = Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(overlay)
	var shade := ColorRect.new(); shade.color = Color(0.015,0.025,0.035,0.45); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade)
	var centre := CenterContainer.new(); centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(centre)
	if left: centre.offset_right = -700; centre.offset_left = 32
	var p := PanelContainer.new(); p.custom_minimum_size.x = width; p.add_theme_stylebox_override("panel",panel_style()); centre.add_child(p)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(width-48,minf(680,get_viewport().get_visible_rect().size.y-100)); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; p.add_child(scroll)
	var v := VBoxContainer.new(); v.custom_minimum_size.x = width-56; v.add_theme_constant_override("separation",14); scroll.add_child(v)
	return v

func focus_first(v: Control) -> void:
	for b: Node in v.find_children("*","Button",true,false):
		b.grab_focus(); break

func cinematic() -> void:
	if is_instance_valid(outpost): outpost.hide()
	world.show()
	if is_instance_valid(stream): stream.hide()
	if is_instance_valid(goal_marker): goal_marker.hide()
	if is_instance_valid(orbital_stage): orbital_stage.hide()
	cine.environment = null
	cine.position = world.to_global(world.point(45,86,16)); cine.look_at(world.to_global(world.habitat)+Vector3(0,2,0)); cine.current = true
	player.visible = false; hud.hide()

func title_screen() -> void:
	launch_time = -1
	if lan_active(): lan.close()
	cinematic()
	var v := menu(650,true)
	v.add_child(text("F R O N T I E R    0 1     /     A MARS EXPEDITION",14,MINT))
	v.add_child(text("A long way\nhome.",68))
	v.add_child(paragraph("Design the mission. Read the planet.\nBring them home.",24,GOLD))
	v.add_child(paragraph("Lead a crew into the Isidis region. Choose what to carry, weather a power crisis, and bring back evidence worth the journey.",18))
	v.add_child(paragraph("New here? Fly the guided first mission, then prepare your own expedition in the Earth lab.",18,MINT))
	v.add_child(action("START AT THE EARTH LAB / CAMPAIGN",enter_lab,true))
	v.add_child(action("PLAY FIRST MISSION / GUIDED PRACTICE ON MARS",first_mission))
	v.add_child(action("QUICK PLAN / SKIP THE LAB",func() -> void: guided = false; planning()))
	if campaign.status=="ACTIVE" and not matching_checkpoint(): v.add_child(action("RESUME ACTIVE FLIGHT",resume_active_flight))
	if campaign.status=="FAILED": v.add_child(action("START A NEW CAMPAIGN / RESET BUDGET",func() -> void: campaign.restart(); title_screen()))
	v.add_child(action("CO-OP, WORKSHOP & NASA SOURCES",extras_menu))
	if matching_checkpoint(): v.add_child(action("CONTINUE SAVED EXPEDITION",load_checkpoint))

	focus_first(v)

func extras_menu() -> void:
	guided = false
	var v := menu(800)
	v.add_child(text("EXPLORE MORE",30,MINT))
	v.add_child(action("LOCAL NETWORK CO-OP",lan_menu))
	v.add_child(action("EQUIPMENT WORKSHOP",func() -> void: preload("res://scripts/outpost_shop.gd").new().show_shop(self)))
	v.add_child(action("NASA DATA & SCIENCE NOTES",func() -> void: source_return = "title"; sources()))
	v.add_child(action("EARTH LAB / PREPARE AND LAUNCH",enter_lab))
	v.add_child(action("BACK",title_screen,true)); focus_first(v)

func enter_lab() -> void:
	if lan_active(): lan.close()
	var v := menu(650,true)
	v.add_child(text("EARTH OPERATIONS",14,MINT)); v.add_child(text("Opening the lab…",44))
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/spaceport.tscn")

func planning() -> void:
	var procurement := preload("res://scripts/outpost_cargo.gd").new(); procurement.read_draft()
	var v := menu(1050)
	v.add_child(text("CAMPAIGN / EXPEDITION %d" % campaign.expedition_number,14,MINT)); v.add_child(text("Build a mission. Bring them home.",34))
	v.add_child(paragraph("Goal: collect two observations, explore two districts and earn %d science. Return to the habitat to launch home. Campaign failure forfeits funds; practice mode is available from the title screen." % campaign.quota(),18))
	var gaps := campaign.missing(procurement)
	v.add_child(text("1  PACK EQUIPMENT   /   2  CLEAR ROCKET   /   3  CHOOSE CREW & LAUNCH",17,MINT))
	v.add_child(paragraph("%d credits available / %.1f of 260 kg cargo. Recommended equipment includes the required rocket and a complete starter outpost. Existing items are kept." % [procurement.credits,procurement.mass()],17))
	if campaign.status=="ACTIVE":
		v.add_child(action("CONTINUE ACTIVE EXPEDITION",load_checkpoint if matching_checkpoint() else resume_active_flight,true))
	elif campaign.status=="FAILED":
		v.add_child(action("START A NEW CAMPAIGN",func() -> void: campaign.restart(); planning(),true))
	elif not gaps.is_empty():
		v.add_child(action("1 / PACK RECOMMENDED ROCKET & OUTPOST",func() -> void:
			var reason := procurement.recommended_pack()
			if reason=="" and not procurement.write_draft(): reason = "Equipment could not be saved. Try again."
			planning(); toast("Equipment packed. Next: clear the rocket." if reason=="" else reason),true))
	elif not campaign.integrated:
		v.add_child(action("2 / CLEAR ROCKET FOR FLIGHT",rocket_integration,true))
	else: v.add_child(paragraph("Equipment packed. Rocket cleared. Choose your crew architecture below, then launch.",19,MINT))
	v.add_child(text("CREW ARCHITECTURE / RESILIENT EXPLORER RECOMMENDED",16,GOLD))
	var crew_row := HBoxContainer.new(); crew_row.add_theme_constant_override("separation",10); v.add_child(crew_row)
	for i: int in range(Model.LOADOUTS.size()):
		var item: Dictionary = Model.LOADOUTS[i]
		crew_row.add_child(action(("SELECTED / " if selected_loadout==i else "")+str(item.name)+"\n%d credits / %d t" % [item.cost,item.mass],func() -> void: selected_loadout=i; planning(),selected_loadout==i))
	v.add_child(paragraph(str(Model.LOADOUTS[selected_loadout].detail),18))
	var launch := action("3 / LAUNCH THIS MISSION",begin_expedition,true)
	launch.disabled = campaign.status!="PLANNING" or not campaign.integrated or not gaps.is_empty() or procurement.credits<int(Model.LOADOUTS[selected_loadout].cost)
	v.add_child(launch)
	v.add_child(text("OPTIONAL / TUNE YOUR MISSION",15,MINT))
	var seed_row := HBoxContainer.new(); seed_row.add_theme_constant_override("separation",12); v.add_child(seed_row)
	seed_row.add_child(text("WORLD SEED",14,MINT))
	var seed_input := LineEdit.new(); seed_input.text = str(selected_seed); seed_input.custom_minimum_size.x = 180; seed_row.add_child(seed_input)
	seed_input.text_changed.connect(func(value: String) -> void:
		if value.is_valid_int(): selected_seed = clampi(value.to_int(),1,999999999))
	seed_row.add_child(action("NEW SEED",func() -> void:
		var rng := RandomNumberGenerator.new(); rng.randomize(); selected_seed = rng.randi_range(1,999999999); planning()))
	v.add_child(action("CUSTOMIZE EQUIPMENT / ADVANCED WORKSHOP",func() -> void: preload("res://scripts/outpost_shop.gd").new().show_shop(self)))
	v.add_child(action("REVIEW ROCKET CLEARANCE",rocket_integration))
	v.add_child(action("REHEARSE / NASA WEATHER & SURVIVAL TRADE-OFFS",rehearsal_screen))
	var cards := HBoxContainer.new(); cards.add_theme_constant_override("separation",12); v.add_child(cards)
	for i: int in range(Model.LOADOUTS.size()):
		var item: Dictionary = Model.LOADOUTS[i]
		var p := PanelContainer.new(); p.custom_minimum_size.x = 320
		p.add_theme_stylebox_override("panel",panel_style(Color("173b41") if selected_loadout == i else Color("101f28"),MINT if selected_loadout == i else Color("354b53"))); cards.add_child(p)
		var c := VBoxContainer.new(); c.add_theme_constant_override("separation",12); p.add_child(c)
		c.add_child(text(str(item.name),17,GOLD)); c.add_child(paragraph(str(item.detail),16))
		c.add_child(text("%d credits  /  %d t\n%d kW  /  %.0f battery\n%.0f oxygen reserve" % [item.cost,item.mass,item.power,item.battery,item.oxygen],17))
		c.add_child(action("SELECTED" if selected_loadout == i else "SELECT",func() -> void: selected_loadout = i; planning(),selected_loadout == i))
	v.add_child(text("LANDING APPROACH",14,MINT))
	var sites := HBoxContainer.new(); sites.add_theme_constant_override("separation",12); v.add_child(sites)
	for i: int in range(2):
		var title := "BASIN / %.0f m MOLA" % world.raw_height(0,42) if i == 0 else "UPLAND / %.0f m MOLA" % world.raw_height(-100,100)
		sites.add_child(action(("● " if selected_site == i else "○ ")+title,func() -> void: selected_site = i; planning()))
	v.add_child(paragraph("MOLA observes regional relief. Lower elevation provides more atmosphere for entry braking, but this is a simplified game choice, not a landing-safety assessment. Walkable routes and targets are authored.",14))
	var totals: Dictionary = Model.LOADOUTS[selected_loadout]
	v.add_child(text("AFTER CREW COST   %d credits   /   %d t launch margin   /   %d kW installed" % [procurement.credits-int(totals.cost),46-int(totals.mass),totals.power],20,MINT))
	v.add_child(paragraph("Upland approach: +15 science, −12 integrity. The MOLA elevation is observed; the scoring and integrity penalty are game design assumptions.",14,GOLD))
	v.add_child(action("BACK",title_screen)); focus_first(v)

func rehearsal_screen() -> void:
	var v := menu(980)
	v.add_child(text("FLIGHT LAB / TRY BEFORE YOU FLY",14,MINT))
	v.add_child(text("Can your crew make it back?",34))
	v.add_child(paragraph("180-second walking EVA, then compare returning to shelter after 90 seconds. No scans, sprinting, repairs, outpost support or field injuries are included. These are suit-reserve rehearsals, not a prediction of total mission safety.",17))
	v.add_child(paragraph("NASA PDS / MEDA: sol 20 sensor temperature and pressure; sol 36 wind quantiles. The seed selects fictional dust timing and illumination. Upland cooling is simulated. Change seed, architecture or landing site in planning and compare again.",16,GOLD))
	var lab = preload("res://scripts/mission_rehearsal.gd")
	for i: int in range(Model.LOADOUTS.size()):
		var exposed: Dictionary = lab.run(i,selected_site,selected_seed)
		var sheltered_run: Dictionary = lab.run(i,selected_site,selected_seed,180,90)
		var item: Dictionary = Model.LOADOUTS[i]
		v.add_child(text(("SELECTED / " if selected_loadout == i else "")+str(item.name),20,MINT))
		v.add_child(paragraph("Budget margin %d / 100 credits | launch margin %d / 46 t\nStay outside: %.0f oxygen / %.0f battery. Return at 90 s: %.0f oxygen / %.0f battery.\nScenario: %d s of dust front; minimum solar %.0f%%; coldest %.1f C; peak wind analog %.2f m/s." % [100-int(item.cost),46-int(item.mass),exposed.oxygen,exposed.battery,sheltered_run.oxygen,sheltered_run.battery,exposed.dust_seconds,exposed.solar*100,exposed.temperature,exposed.wind],16))
		v.add_child(action("USE THIS ARCHITECTURE",func() -> void: selected_loadout = i; rehearsal_screen(),selected_loadout == i))
	v.add_child(paragraph("Engineering lesson: shelter restores oxygen; fission backup retains charging in simulated dust. Carrying more instruments adds mass and cost. Wind observations from a different sol are an analog, not a forecast. Regional MOLA relief cannot resolve safe landing spots.",17,GOLD))
	v.add_child(action("BACK TO MISSION DESIGN",planning,true)); focus_first(v)

func begin_expedition() -> void:
	guided = false
	if campaign.persistent and capture_mode=="":
		var launch_stock := preload("res://scripts/outpost_cargo.gd").new(); launch_stock.read_draft()
		var reason := campaign.commit(launch_stock,int(Model.LOADOUTS[selected_loadout].cost),selected_seed)
		if reason!="": toast(reason); rocket_integration(); return
		launch_stock.write_draft()
	flight.reset(selected_seed)
	field.restore({}); traversal.restore({})
	regenerate_world(selected_seed)
	outpost.reset_for_launch()
	model.configure(selected_loadout,selected_site)
	landing_fuel_bonus = 0.0; hazards.reset(selected_seed); player.jet_fuel = 100.0
	visited_regions.clear(); model.weather_driven = true
	set_driving(false)
	if get_tree().has_meta("ground_manifest"):
		var manifest: Dictionary = get_tree().get_meta("ground_manifest")
		landing_fuel_bonus = clampf(float(manifest.get("fuel_bonus",0)),0,24)
		var lab_science := clampi(int(manifest.get("lab_science",0)),0,15)
		model.science += lab_science
		model.log.append("Earth integration cleared: %.0f kg hardware / %.1f kW; fission baseline mapped to normalized expedition reserves" % [float(manifest.mass),float(manifest.power)])
		get_tree().remove_meta("ground_manifest")
	world.ascent.position = world.point(17,27)
	clear_menu(); player.visible = false; world.visible = false; orbital_stage.show(); hud.show(); objective.text = "02 / EARTH DEPARTURE  —  FRONTIER 01"
	map_view.hide(); resources.text = "CREW SECURE\nDEPARTURE BURN\nGUIDANCE INTERNAL"; prompt.text = "TRANSFER / scenario duration compressed"
	cine.position = Vector3(10,1004,14); cine.look_at(Vector3(0,1000,-8)); cine.current = true
	cine.environment = orbital_stage.get_meta("environment")
	transfer_ship.position = Vector3.ZERO
	player.enabled = false; launch_time = 0
	toast("DEPARTURE BURN  /  GUIDANCE INTERNAL\nTime, distance and planetary scale are compressed.")

func transit_screen() -> void:
	if not testing and capture_mode=="": flight_screen(); return
	launch_time = -1
	var v := menu(760)
	v.add_child(text("03 / TRANSIT    •    DAY 114",14,MINT)); v.add_child(text("The Sun changes the plan.",36))
	v.add_child(paragraph("A radiation alert arrives. Your habitat can shelter the crew, but the science instruments must shut down while power is rerouted. Choose a response.",20))
	v.add_child(action("SHELTER CREW / preserve integrity",func() -> void: land(true),true))
	v.add_child(action("KEEP INSTRUMENTS ONLINE / +10 science, −20 integrity",func() -> void: land(false)))
	v.add_child(paragraph("Scenario event, not a real-time solar forecast. Shielding and operational decisions reduce exposure; this game does not model a dose in sieverts.",14))
	focus_first(v)

func land(safe: bool) -> void:
	if not testing and not guided and capture_mode=="":
		begin_descent(safe); return
	touchdown_surface(safe)

func begin_descent(safe: bool) -> void:
	if is_instance_valid(descent): return
	clear_menu(); launch_time = -1; model.phase = "DESCENT"
	player.enabled = false; player.velocity = Vector3.ZERO; player.hide(); hud.hide(); world.hide(); stream.hide(); outpost.hide(); orbital_stage.hide()
	descent = LandingSim.new(); add_child(descent)
	descent.finished.connect(func(result: Dictionary) -> void:
		var completed := descent; descent = null; completed.queue_free()
		model.integrity = maxf(0,model.integrity-float(result.get("damage",0)))
		model.science += int(result.get("science",0)); model.log.append("Flown descent: "+str(result.get("label","touchdown")))
		if model.integrity<=0: finish(false)
		else: touchdown_surface(safe))
	descent.start({"training":false,"seed":selected_seed,"fuel_bonus":landing_fuel_bonus})
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func touchdown_surface(safe: bool) -> void:
	model.transit(safe); storm_announced = false
	world.show(); orbital_stage.hide(); cine.environment = null
	map_view.show()
	player.position = world.point(0,42,0.2) if model.site == 0 else world.point(-100,100,0.2)
	player.camera_yaw = 0.15; player.camera_pitch = -0.16
	resume_surface(); checkpoint(); toast("04 / TOUCHDOWN\nB deploys kits • hold E to assemble • C fabricates • G recovers materials. Build power, oxygen and shelter to push farther.")

func resume_surface() -> void:
	player.jet_enabled = not guided
	if is_instance_valid(outpost): outpost.show()
	if is_instance_valid(stream): stream.show()
	clear_menu(); player.visible = true; player.enabled = true; player.camera.current = true
	world.show(); orbital_stage.hide()
	hud.show(); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	objective.text = "SECURE TWO EVIDENCE TARGETS. RETURN HOME."

func sheltered() -> bool:
	if is_instance_valid(outpost) and outpost.service_available(outpost.player_position()): return true
	if at_main_habitat(): return true
	for refuge: Vector3 in world.refuges:
		if player.global_position.distance_to(world.to_global(refuge)) < 8: return true
	return false

func at_main_habitat() -> bool:
	return player.global_position.distance_to(world.to_global(world.habitat)) < 12

func nearest_target() -> int:
	var best := -1; var distance := 5.0
	for i: int in range(world.beacons.size()):
		var d: float = player.global_position.distance_to(world.beacons[i].global_position)
		if d < distance: distance = d; best = i
	return best

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if is_instance_valid(music): music.update_mix(delta,clampf(weather.severity*.6+(1-model.integrity/100)*.7+field.cold/180,0,1))
	if launch_time >= 0:
		launch_time += delta
		transfer_ship.position.z -= delta*1.4
		cine.position += Vector3(delta*0.4,delta*0.2,delta*0.5)
		cine.look_at(Vector3(0,1000,-8))
		if launch_time >= 4: transit_screen()
	if model.phase == "SURFACE" and not is_instance_valid(overlay) and not testing:
		stream.tick(delta)
		outpost.tick(delta)
		traversal.tick(delta)
		field.tick(delta)
		var home := sheltered()
		hazards.enabled = not guided and not lan_active()
		hazards.visible = hazards.enabled
		hazards.tick(delta,home)
		var logical_position: Vector3 = stream.logical(player.position)
		var region_index: int = world.generator.region_at(logical_position.x,logical_position.z)
		var region_kind := "basin" if region_index < 0 else str(world.generator.regions[region_index].kind)
		if maxf(absf(logical_position.x),absf(logical_position.z)) > 768: region_kind = stream.KINDS[stream.kind_at(stream.cell_at(logical_position))]
		weather.update(model.elapsed,region_kind,world.world_seed)
		model.weather_driven = true; model.storm = weather.severity > 0.5; model.solar_fraction = weather.solar_fraction
		var depot := at_main_habitat()
		for refuge: Vector3 in world.refuges:
			if player.global_position.distance_to(world.to_global(refuge)) < 8: depot = true
		model.tick(delta,depot,Input.is_action_pressed("sprint"))
		if home and not depot: model.integrity = minf(100,model.integrity+(delta*.10 if model.storm else 0.0))
		world.update_discoveries(logical_position)
		if region_index >= 0 and not visited_regions.has(region_index):
			visited_regions.append(region_index); model.science += 5
			toast("DISCOVERED / "+str(world.generator.regions[region_index].name)+"\n"+str(world.generator.regions[region_index].description)); checkpoint()
		var mobility := 1.0
		if region_kind == "dunes": mobility = 0.92 if model.pack.has("traction") else 0.48
		if region_kind == "highlands" and not model.pack.has("thermal"):
			model.oxygen = maxf(0,model.oxygen-delta*0.15)
		player.speed_multiplier = mobility*(3.2 if driving else 1.0)
		player.floor_max_angle = deg_to_rad(27 if driving else (40 if field.owned("crampons") and field.owned("harness") else 28))
		player.jump_height = Explorer.SUIT_JUMP_HEIGHT
		if driving and player.velocity.length() > 0.5: model.battery = maxf(0,model.battery-delta*0.08)
		if driving and model.battery <= 0: set_driving(false)
		update_weather_visuals(delta)
		target = nearest_target()
		var distance_home := Vector2(logical_position.x,logical_position.z).distance_to(Vector2(0,28))
		resources.text = "O₂ RESERVE     %03d\nBATTERY          %03d\nINTEGRITY       %03d%%\nEVIDENCE       %d / 2" % [model.oxygen,model.battery,model.integrity,model.samples.size()]
		status.text = ("BASE CAMP" if region_index < 0 else str(world.generator.regions[region_index].name))+" / "+weather.state
		if maxf(absf(logical_position.x),absf(logical_position.z)) > 768: status.text = str(field.profile_at(logical_position).name)+" / "+weather.state
		objective.text = "POINTS %d / QUOTA %d • %d SECTORS" % [model.science,campaign.quota(),stream.visited.size()]
		resources.text += "\nMEDA PROFILE %.0f°C / %.0f Pa\nWIND ANALOG %.1f m/s\nPACK: %s" % [weather.measured_temperature_c,weather.pressure_pa,weather.wind_mps,", ".join(model.pack)]
		if home: prompt.text = ("HABITAT" if at_main_habitat() else "REFUGE")+" / recharging    E  Console / change tools"
		elif target >= 0:
			var reason: String = model.can_sample(target)
			prompt.text = ("HOLD E / " + str(model.targets[target].name)) if reason == "" else reason
		else: prompt.text = "HABITAT %dm / B Build • C Craft • G Gather • J Journal • L LAN" % int(distance_home)
		if stream.activity_prompt() != "" and not home: prompt.text = stream.activity_prompt()
		if outpost.prompt_text()!="": prompt.text = outpost.prompt_text()
		resources.text += "\nFOOD %d%% • WATER %d%%" % [outpost.food,outpost.hydration]
		if field.warning!="": prompt.text = field.warning
		if hazards.enabled and hazards.warning!="": prompt.text = hazards.warning
		if guided:
			var destination := guided_destination()
			var offset := destination-player.global_position
			var angle := wrapf(atan2(-offset.x,-offset.z)-player.camera_yaw,-PI,PI)
			var direction := "AHEAD" if absf(angle)<.4 else ("TURN LEFT" if angle>0 else "TURN RIGHT")
			objective.text = guided_instruction()
			status.text = "%s / %d m / EVIDENCE %d OF 2" % [direction,Vector2(offset.x,offset.z).length(),model.samples.size()]
			resources.text = "OXYGEN  %d\nBATTERY  %d\nSUIT  %d%%\nPRACTICE / NO SAVE RISK" % [model.oxygen,model.battery,model.integrity]
			if field.warning == "":
				prompt.text = "Follow the cyan marker / F1 explains your next step"
				if target>=0 and model.can_sample(target)=="": prompt.text = "HOLD E for 3 seconds / "+str(model.targets[target].name)
				elif at_main_habitat(): prompt.text = "Oxygen and battery refilling / E opens habitat / follow marker when ready"
		update_goal_marker()
		update_reserve_bars()
		if scan_held and target >= 0 and model.can_sample(target) == "":
			model.scan_progress += delta; scan_bar.show(); scan_bar.value = model.scan_progress
			if model.scan_progress >= 3:
				var index := target
				if lan_active() and not lan.is_host: lan.request_sample.rpc_id(1,index)
				else:
					model.collect(index)
					if lan_active(): lan.broadcast_progress()
				model.scan_progress = 0; scan_held = false
				tone(880,0.2); checkpoint()
				if not lan_active() or lan.is_host: evidence_screen(index)
		else: model.scan_progress = 0; scan_bar.hide()
		if model.storm and not storm_announced:
			storm_announced = true; toast("DUST FRONT ARRIVING\nSolar recharge reduced. Shelter at habitat to protect your suit."); tone(220,0.4)
		var env: Environment = world.environment_resource
		env.fog_density = lerpf(env.fog_density,weather.fog,1-exp(-delta*2))
		if model.integrity <= 0: finish(false)
		save_timer += delta
		if save_timer > 20: save_timer = 0; checkpoint()
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0: notice.text = ""
	if capture_mode != "":
		capture_frame += 1
		if capture_frame > 30: fps_samples.append(delta)
		if capture_frame == 180:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://../build/expedition-"+capture_mode+".png")
			fps_samples.sort(); var sum := 0.0
			for dt: float in fps_samples: sum += dt
			print("GPU CAPTURE ",capture_mode," mean FPS ",fps_samples.size()/sum," p95 ms ",fps_samples[int(fps_samples.size()*0.95)]*1000," draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(descent): return
	if is_instance_valid(outpost) and outpost.handle_input(event): return
	if event is InputEventKey:
		if event.physical_keycode == KEY_E and not is_instance_valid(overlay) and model.phase == "SURFACE":
			if event.pressed and not event.echo and outpost.interact(): return
			scan_held = event.pressed
			if event.pressed and not event.echo and (sheltered() or stream.is_sheltered()): habitat_console()
		if not event.pressed or event.echo: return
		if event.keycode == KEY_F1 and model.phase=="SURFACE": mission_help(); return
		if event.keycode == KEY_ESCAPE:
			if model.phase == "SURFACE":
				if is_instance_valid(overlay): resume_surface()
				else: pause_screen()
		elif event.keycode == KEY_TAB: map_view.visible = not map_view.visible
		elif event.keycode == KEY_V and not is_instance_valid(overlay) and not driving: player.toggle_camera_view()
		elif event.keycode == KEY_R and not is_instance_valid(overlay) and model.phase == "SURFACE":
			set_driving(not driving)
		elif event.keycode == KEY_SPACE and not is_instance_valid(overlay) and not driving:
			player.request_jump()
		elif event.keycode == KEY_F and not is_instance_valid(overlay) and model.phase == "SURFACE": stream.interact()
		elif event.keycode == KEY_J and model.phase == "SURFACE": journal()
		elif event.keycode == KEY_H and model.phase=="SURFACE": field.journal()
		elif event.keycode == KEY_Z and model.phase=="SURFACE" and not is_instance_valid(overlay): traversal.deploy()
		elif event.keycode == KEY_X and model.phase=="SURFACE" and not is_instance_valid(overlay): traversal.toggle_attach()
		elif event.keycode == KEY_P and model.phase=="SURFACE": gear_menu()
		elif event.keycode == KEY_L: lan_menu()
		elif event.keycode == KEY_B and not is_instance_valid(overlay) and model.phase == "SURFACE": outpost.build_menu()
		elif event.keycode == KEY_C and model.phase == "SURFACE": outpost.cargo_menu()
		elif event.keycode == KEY_G and not is_instance_valid(overlay) and model.phase == "SURFACE": outpost.request_action("gather",{})
		elif event.keycode == KEY_N and not is_instance_valid(overlay) and model.phase == "SURFACE": deploy_waypoint()
		elif event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player) and model.phase == "SURFACE" and not is_instance_valid(overlay) and capture_mode == "" and not testing and not lan_active() and not guided_film and not "--film-adventure" in OS.get_cmdline_user_args(): pause_screen()

func evidence_screen(index: int) -> void:
	if guided:
		var lesson := menu(850)
		lesson.add_child(text("DISCOVERY %d OF 2 / LEARN BY DOING" % model.samples.size(),15,MINT))
		lesson.add_child(text("You recorded a rock observation.",30))
		var tool := str(model.targets[index].instrument)
		lesson.add_child(paragraph("Your light scanner compares how rock reflects light. Scientists use this to investigate what a rock may contain. It uses electricity: this scan cost 8 battery." if tool=="spectrometer" else "Your drill reaches material below the surface. Scientists compare it with exposed rock to investigate how conditions change the material. It uses electricity: this scan cost 8 battery.",21))
		lesson.add_child(text("WHAT DID WE LEARN?",16,GOLD))
		if not model.interpreted.has(index):
			lesson.add_child(action("We have a clue to investigate / more observations are needed",func() -> void: model.interpret(index,true); evidence_screen(index),true))
			lesson.add_child(action("One observation proves there is life here",func() -> void: model.interpret(index,false); evidence_screen(index)))
		else:
			lesson.add_child(paragraph("One observation is a clue, not proof of life. Comparing different observations makes a scientific explanation stronger. You can learn from either answer; practice does not punish a mistaken explanation.",21,MINT))
		lesson.add_child(paragraph("NEXT: "+("Follow HOME to the white shelter. Press E there, then choose Return to Earth." if model.samples.size()>=2 else "Follow the next cyan marker. Hold E near it until the scan bar fills."),21,GOLD))
		lesson.add_child(action("CONTINUE / FOLLOW THE MARKER",resume_surface)); focus_first(lesson)
		return
	var v := menu(850); var item: Dictionary = model.targets[index]
	v.add_child(text("EVIDENCE SECURED    /    +%d SCIENCE" % item.science,14,MINT))
	v.add_child(text(str(item.name),36)); v.add_child(paragraph(str(item.observation),21))
	v.add_child(paragraph("Instrument: "+str(item.instrument)+".  Cost: 8 battery.\nThe target placement and assay are authored game content. MOLA supplies regional terrain context only.",16))
	if str(item.get("type","")) == "weather":
		v.add_child(paragraph("MEDA calibrated sensor profile / sol 20\nLocal sensor temperature %.1f°C · Pressure %.1f Pa\nThe station location and wind scenario are simulated; the displayed profile is derived from archived MEDA observations." % [weather.measured_temperature_c,weather.pressure_pa],17,GOLD))
		v.add_child(paragraph("Wind analog %.2f m/s: a quantile of stationary-rover MEDA sol 36 wind retrievals. Sols 20 and 36 are not contemporaneous; this combination is a game scenario." % weather.wind_mps,16,MINT))
	elif str(item.get("type","")) == "cache": v.add_child(paragraph("Cache recovered: +45 oxygen and +25 battery, capped at suit capacity. Its contents and location are seeded game content.",17,MINT))
	elif not model.interpreted.has(index):
		v.add_child(text("WHAT DOES THIS EVIDENCE SUPPORT?",14,GOLD))
		v.add_child(action("A limited hypothesis; more measurements are needed",func() -> void: model.interpret(index,true); checkpoint(); evidence_screen(index)))
		v.add_child(action("Proof of life or an exact age",func() -> void: model.interpret(index,false); checkpoint(); evidence_screen(index)))
	else: v.add_child(paragraph("Evidence constrains a hypothesis. It cannot establish life or an exact age on its own.",17,MINT))
	v.add_child(action("READ NASA SCIENCE REFERENCE ↗",func() -> void: OS.shell_open(str(item.source))))
	v.add_child(action("CONTINUE EXPEDITION",resume_surface,true)); focus_first(v)

func habitat_console() -> void:
	if guided:
		var guide_menu := menu(790)
		guide_menu.add_child(text("HABITAT / YOU ARE SAFE HERE",15,MINT))
		guide_menu.add_child(text("Your way home.",36))
		guide_menu.add_child(paragraph("Evidence collected: %d of 2. Oxygen and battery refill while you stand beside the habitat with this menu closed." % model.samples.size(),21))
		if model.samples.size() >= 2:
			var return_home := action("RETURN TO EARTH / COMPLETE FIRST MISSION",begin_return,true)
			return_home.disabled = not at_main_habitat(); guide_menu.add_child(return_home)
			if not at_main_habitat(): guide_menu.add_child(paragraph("This is a refuge. Follow the HOME marker to the main habitat to launch.",19,GOLD))
		else: guide_menu.add_child(paragraph("Follow the cyan marker and hold E beside a target to scan. Bring back two different observations. You do not need to build anything for this first mission.",20,GOLD))
		guide_menu.add_child(action("CONTINUE EXPLORING",resume_surface,model.samples.size()<2))
		guide_menu.add_child(action("HOW TO PLAY",mission_help)); focus_first(guide_menu)
		return
	var v := menu(760)
	v.add_child(text("OUTPOST / SAFE HAVEN",14,MINT)); v.add_child(text("A place to breathe.",38))
	var support_note := "The base and starter refuges restore suit reserves during active play. Evidence needed for return: two different targets."
	if outpost.service_available(outpost.player_position()): support_note = "HAVEN charges your suit from its grid. Oxygen draws from a connected AERIS reservoir, which requires water. Close this console to resume local work."
	elif stream.is_sheltered() and not at_main_habitat(): support_note = "This outer pod contains one finite emergency reserve. You can change traversal kits here; sustained oxygen and power require your own outpost."
	v.add_child(paragraph(support_note,19))
	v.add_child(text("EVIDENCE %d  /  SCIENCE %d  /  INTEGRITY %d%%" % [model.samples.size(),model.science,model.integrity],20,GOLD))
	v.add_child(action("OUTPOST CARGO / FABRICATION",outpost.cargo_menu))
	v.add_child(action("CONSTRUCTION CONTRACTS",outpost.contract_menu))
	v.add_child(text("TRAVERSAL PACK / TWO SLOTS",14,MINT))
	for tool: String in ["traction","climbing","thermal"]:
		var description := {"traction":"Dune traction / cross sand faster","climbing":"Climbing support / buy harnesses, crampons and ropes for steep routes","thermal":"Thermal liner / reduces cold-region oxygen load"}
		v.add_child(action(("✓ " if model.pack.has(tool) else "+ ")+str(description[tool]),func() -> void:
			if model.pack.has(tool): model.pack.erase(tool)
			elif model.pack.size() < 2: model.pack.append(tool)
			else: model.pack.pop_front(); model.pack.append(tool)
			checkpoint(); habitat_console()))
	if not model.repaired:
		v.add_child(action("USE SPARES / −12 battery, +25 integrity (once)",func() -> void:
			if model.repair(): checkpoint(); habitat_console()
			else: toast("Need 12 battery to use spares.")))
	if not model.downlinked:
		v.add_child(action("ARCHIVE EVIDENCE TO EARTH / −15 battery, +10 science",func() -> void:
			if model.downlink(): checkpoint(); habitat_console(); toast("EARTH ARCHIVE / transmission complete\nReal Mars links have minute-scale light-time. This transfer is compressed.")
			else: toast("Collect evidence and retain at least 15 battery.")))
	var gaps: String = expedition_return_gaps()
	if gaps != "": v.add_child(paragraph(gaps,16,GOLD))
	var return_button := action("05 / LAUNCH ASCENT & RETURN TO EARTH",begin_return,true); return_button.disabled = gaps != "" or not at_main_habitat(); v.add_child(return_button)
	if not at_main_habitat(): v.add_child(paragraph("Return launch is commanded at the main habitat. This refuge supports suit recovery and tool changes.",15,GOLD))
	v.add_child(action("RETURN TO FIELD",resume_surface)); focus_first(v)

func begin_return() -> void:
	if expedition_return_gaps() != "": return
	model.phase = "RETURNING"; clear_menu(); player.enabled = false
	cine.position = world.to_global(world.point(38,55,8)); cine.look_at(world.to_global(world.point(17,27,4))); cine.current = true
	toast("05 / ASCENT COMMITTED\nRendezvous confirmed. Returning crew and evidence to Earth.")
	var ignition := world.mat(Color("ffb85c")); ignition.emission_enabled = true; ignition.emission = Color("ffa548")
	var plume := CylinderMesh.new(); plume.top_radius = 0.9; plume.bottom_radius = 0.05; plume.height = 4
	world.mesh_at(plume,Vector3(0,-1.7,0),ignition,world.ascent)
	var ascent_tween := create_tween(); ascent_tween.tween_property(world.ascent,"position",world.ascent.position+Vector3(0,90,0),3.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tween := create_tween(); tween.tween_property(cine,"position",cine.position+Vector3(0,35,25),3.5).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func() -> void: finish(true))

func expedition_return_gaps() -> String:
	if guided: return model.return_gaps()
	if campaign.status=="ACTIVE" and model.science<campaign.quota(): return "Campaign return quota: %d / %d points" % [model.science,campaign.quota()]
	var gaps: String = model.return_gaps()
	if gaps != "": return gaps
	if visited_regions.size() < 2: return "Survey two different geological districts before return. Follow the changing terrain beyond the basin."
	return ""

func finish(success: bool) -> void:
	if guided:
		model.phase = "RETURNED" if success else "FAILED"
		var guide_menu := menu(820)
		guide_menu.add_child(text("FIRST MISSION / "+("COMPLETE" if success else "TRY AGAIN"),15,MINT))
		guide_menu.add_child(text("You brought them home." if success else "The next crew has your experience.",34))
		guide_menu.add_child(paragraph("You collected %d observations and returned with %d%% suit integrity. You learned movement, scanning and recovery. NASA MOLA supplies regional terrain; the equipment and survival rates are game models." % [model.samples.size(),model.integrity] if success else "Your suit ran out of reserves. Head back to the habitat sooner to refill. Your campaign money and saves are unchanged.",21))
		guide_menu.add_child(action("PREPARE YOUR OWN MISSION / EARTH LAB",enter_lab,true))
		guide_menu.add_child(action("QUICK PLAN / SKIP THE LAB",func() -> void: guided = false; planning()))
		guide_menu.add_child(action("PLAY PRACTICE AGAIN",start_first_mission))
		guide_menu.add_child(action("TITLE SCREEN",title_screen)); focus_first(guide_menu)
		return
	if (not testing or "--lan-host-test" in OS.get_cmdline_user_args() or "--lan-client-test" in OS.get_cmdline_user_args()) and capture_mode=="":
		if lan_active() and not lan.is_host and not receiving_campaign_end:
			model.phase = "AWAITING_TEAM_RESULT"; lan.request_campaign_failure.rpc_id(1); return
		if not receiving_campaign_end: campaign.settle(success,model.science)
		if lan_active() and lan.is_host: lan.end_campaign.rpc(success,campaign.snapshot())
	model.phase = "RETURNED" if success else "FAILED"
	if not testing and capture_mode == "": checkpoint()
	var v := menu(860)
	if not success: v.add_child(action("NEW CAMPAIGN / FORFEITURE CONFIRMED",func() -> void: campaign.restart(); model.phase = "PLANNING"; title_screen()))
	else: selected_seed = posmod(selected_seed+104729*campaign.expedition_number,999999999)+1
	v.add_child(text("06 / MISSION DEBRIEF",14,MINT)); v.add_child(text("Home, with a story." if success else "A lesson for the next crew.",38))
	v.add_child(text("%d TOTAL POINTS    •    %d EVIDENCE TARGETS    •    %d%% INTEGRITY" % [model.score() if success else 0,model.samples.size(),model.integrity],24,GOLD))
	v.add_child(paragraph("Campaign %s • Total score %d • Next budget %d • Grant %d" % [campaign.status,campaign.total_score,campaign.bank,campaign.last_grant],18,MINT))
	v.add_child(text("REGIONS %d / 6   •   SEED %d" % [visited_regions.size(),world.world_seed],18,MINT))
	v.add_child(paragraph("Crew returned safely. Your evidence funds the next expedition." if success else "CAMPAIGN LOST. All campaign points and money are forfeited. Earlier checkpoints cannot revive this campaign. Start again with a new initial budget.",19))
	for entry: String in model.log: v.add_child(paragraph("• "+entry,15))
	v.add_child(paragraph("Science %d + crew integrity %d + shelter decision %d + reserves %d + budget/mass efficiency %d. Exploration and research points continue to accumulate.\nTrade-off: %s" % [model.science,int(model.integrity*0.5),20 if model.transit_safe else 0,int((model.oxygen+model.battery)*0.05),model.efficiency_score(),str(Model.LOADOUTS[model.loadout].detail)],16,MINT))
	v.add_child(action("NASA SOURCES & MODEL LIMITS",func() -> void: source_return = "debrief"; sources()))
	v.add_child(action("RETURN TO THE EARTH LAB / NEXT EXPEDITION",enter_lab,true))
	v.add_child(action("QUICK PLAN / SKIP THE LAB",planning)); v.add_child(action("TITLE SCREEN",title_screen)); focus_first(v)

func pause_screen() -> void:
	var v := menu(700); v.add_child(text("MISSION PAUSED",14,MINT)); v.add_child(text("Take a breath.",40))
	v.add_child(action("HOW TO PLAY / YOUR NEXT STEP",mission_help))
	if guided:
		v.add_child(paragraph(guided_instruction()+". Practice progress is temporary; campaign saves are safe.",20,GOLD))
		v.add_child(action("RESUME PRACTICE",resume_surface,true))
		v.add_child(action("RESTART PRACTICE",start_first_mission))
		v.add_child(action("TITLE SCREEN",title_screen)); focus_first(v)
		return
	v.add_child(text("BACKGROUND MUSIC",13,MINT)); var music_slider := HSlider.new(); music_slider.min_value = 0; music_slider.max_value = 1; music_slider.step = .05; music_slider.value = music.volume; music_slider.value_changed.connect(music.set_volume); v.add_child(music_slider)
	v.add_child(action("RESUME",resume_surface,true)); v.add_child(action("SAVE CHECKPOINT",func() -> void: checkpoint(); toast("Checkpoint saved.")))
	v.add_child(action("OUTPOST / CARGO & FABRICATION",outpost.cargo_menu)); v.add_child(action("FIELD JOURNAL",journal)); v.add_child(action("LOCAL NETWORK CO-OP",lan_menu))
	v.add_child(action("NASA DATA & MODEL LIMITS",func() -> void: source_return = "pause"; sources()))
	var q := OptionButton.new(); q.add_item("Performance / no sun shadows"); q.add_item("Balanced / 2× MSAA"); q.add_item("High / 4× MSAA"); q.selected = quality
	q.item_selected.connect(func(i: int) -> void:
		quality = i; get_viewport().msaa_3d = Viewport.MSAA_DISABLED if i == 0 else (Viewport.MSAA_2X if i == 1 else Viewport.MSAA_4X)
		Gfx.grade(world.environment_resource,i); Gfx.viewport_quality(get_viewport(),i)
		if not testing and capture_mode=="" and not isolated_demo: Gfx.store_quality(i)
		for child: Node in world.get_children():
			if child is DirectionalLight3D: child.shadow_enabled = i > 0)
	v.add_child(q)
	v.add_child(text("MOUSE SENSITIVITY",13,MINT)); var slider := HSlider.new(); slider.min_value = 0.0005; slider.max_value = 0.005; slider.step = 0.0001; slider.value = player.sensitivity
	slider.value_changed.connect(func(value: float) -> void: player.sensitivity = value); v.add_child(slider)
	v.add_child(action("TITLE SCREEN",title_screen)); v.add_child(action("SAVE & QUIT",func() -> void: checkpoint(); get_tree().quit())); focus_first(v)

func sources() -> void:
	var v := menu(900); v.add_child(text("THE EVIDENCE BEHIND THE EXPEDITION",14,MINT)); v.add_child(text("NASA data. Visible limits.",36))
	v.add_child(paragraph("OBSERVATION / NASA PDS Mars Global Surveyor MOLA\nMEGT90N000CB.IMG · 4 pixels per degree · signed 16-bit big-endian metres relative to the areoid. This build carries a 65 × 65 regional crop and the original label and SHA-256.",18))
	v.add_child(paragraph("TRANSFORMATION / Regional Isidis/Jezero relief is compressed into 1536 game metres, vertical scale 0.008, then combined with seeded local landforms. Six geological analog districts are a simulated composite, not one measured contiguous landscape. Local geometry, targets, hardware, wind and storm timing are generated scenarios.",18))
	v.add_child(paragraph("WEATHER / MEDA sol 20 calibrated ATS sensor 1 temperature and Barocap 1 pressure, binned into 15-minute medians. Wind magnitudes use sol 36 stationary-rover retrieval quantiles; missing/invalid values are excluded. Different sols are combined as a game scenario, not a forecast. Sensor temperature is not global climatology. Frost and storm timing are simulated.",16,GOLD))
	v.add_child(action("NASA PDS / MEDA PRODUCT LABEL ↗",func() -> void: OS.shell_open("https://atmos.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/data_calibrated_env/sol_0000_0089/sol_0020/WE__0020___________CAL_ATS_________________P01.xml")))
	v.add_child(action("NASA PDS / MEDA WIND LABEL ↗",func() -> void: OS.shell_open("https://atmos.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/data_derived_env/sol_0000_0089/sol_0036/WE__0036___________DER_WS__________________P02.xml")))
	v.add_child(paragraph("DECISION / Choose lower-basin or upland entry and trade mass, cost, instruments and power. NASA mission science motivates complementary sample contexts; this game cannot infer minerals, life, landing safety or radiation dose from MOLA.",18))
	v.add_child(action("NASA PDS / ORIGINAL DATA & LABEL ↗",func() -> void: OS.shell_open(str(world.data.label))))
	v.add_child(action("NASA / PERSEVERANCE SCIENCE ↗",func() -> void: OS.shell_open("https://science.nasa.gov/mission/mars-2020-perseverance/science/")))
	v.add_child(action("2026 / OFFICIAL CHALLENGE ↗",func() -> void: OS.shell_open("https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/")))
	v.add_child(paragraph("This independent project follows the supplied Space Mission Design Game brief in nasaguide.md. NASA data and fictional game assumptions are identified separately. Pre-event development must be disclosed; submission eligibility is an organizer decision. See docs/COMPETITION_2026.md.",14,GOLD))
	v.add_child(action("BACK",func() -> void:
		if source_return == "title": title_screen()
		elif source_return == "debrief": finish(model.phase == "RETURNED")
		else: pause_screen(),true)); focus_first(v)

func toast(message: String) -> void:
	notice.text = message; toast_timer = 7

func tone(frequency: float, duration: float) -> void:
	if testing or DisplayServer.get_name() == "headless": return
	var wave := AudioStreamWAV.new(); wave.format = AudioStreamWAV.FORMAT_16_BITS; wave.mix_rate = 22050
	var bytes := PackedByteArray(); var count := int(duration*22050); bytes.resize(count*2)
	for i: int in range(count):
		var sample := int(sin(float(i)*frequency*TAU/22050)*6000*sin(PI*float(i)/count))
		bytes.encode_s16(i*2,sample)
	wave.data = bytes; sfx.stream = wave; sfx.play()

func install_targets() -> void:
	model.targets.assign(Model.TARGETS.duplicate(true))
	for item: Dictionary in world.discoveries: model.targets.append(item.duplicate(true))

func set_driving(value: bool) -> void:
	if value and model.battery < 2: toast("Rover needs battery. Recharge at a refuge or habitat."); return
	driving = value; rover.visible = driving
	var collision: CollisionShape3D = player.get_children().filter(func(node: Node) -> bool: return node is CollisionShape3D)[0]
	collision.shape.radius = 0.82 if driving else 0.32
	if driving and player.first_person: player.toggle_camera_view()
	player.avatar.visible = not driving and not player.first_person
	player.camera_distance = 6.8 if driving else 4.4
	toast("ROVER / "+("DRIVE ENABLED. Steep terrain requires on-foot climbing." if driving else "ON FOOT"))

func regenerate_world(seed_number: int) -> void:
	if is_instance_valid(stream): stream.free()
	world.free()
	world = World.new(); world.world_seed = seed_number; add_child(world); world.build()
	install_targets()
	if is_instance_valid(map_view): map_view.revealed.clear()
	if is_instance_valid(player): create_stream()

func build_rover() -> void:
	rover = Node3D.new(); rover.name = "TraverseRover"; player.add_child(rover); rover.hide()
	if ResourceLoader.exists("res://assets/vehicles/sev.glb"):
		var vehicle: Node3D = load("res://assets/vehicles/sev.glb").instantiate(); rover.add_child(vehicle); vehicle.rotation.y = PI
		var bounds := AABB(); var first := true
		for node: Node in vehicle.find_children("*","MeshInstance3D",true,false):
			var relative: Transform3D = rover.global_transform.affine_inverse()*node.global_transform
			var aabb: AABB = relative*node.mesh.get_aabb()
			bounds = aabb if first else bounds.merge(aabb); first = false
		var factor := 4.6/maxf(bounds.size.x,bounds.size.z)
		vehicle.scale *= factor
		vehicle.position = Vector3(-bounds.get_center().x*factor,-bounds.position.y*factor,-bounds.get_center().z*factor)
		return
	var white := world.mat(Color("929e9d"),0.4); var black := world.mat(Color("1b232a")); var metal := world.mat(Color("77654c"),0.6)
	world.box(Vector3(0,0.73,0),Vector3(1.8,0.55,2.8),white,rover)
	world.box(Vector3(0,1.25,-0.25),Vector3(1.4,0.8,1.5),black,rover)
	world.box(Vector3(0,1.72,-0.25),Vector3(1.6,0.12,1.8),white,rover)
	world.box(Vector3(0,1.1,1),Vector3(1.4,0.3,0.7),metal,rover)
	for x: float in [-1.0,1.0]:
		for z: float in [-1.1,0.0,1.1]:
			var tire := world.cylinder(Vector3(x,0.48,z),0.48,0.34,black,rover); tire.rotation.z = PI/2
			var hub := world.cylinder(Vector3(x*1.18,0.48,z),0.2,0.05,metal,rover); hub.rotation.z = PI/2

func build_weather_visuals() -> void:
	dust_particles = CPUParticles3D.new(); dust_particles.amount = 650; dust_particles.lifetime = 3
	dust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; dust_particles.emission_box_extents = Vector3(35,10,35)
	dust_particles.direction = Vector3(1,-0.04,0.2); dust_particles.spread = 12; dust_particles.gravity = Vector3.ZERO
	dust_particles.initial_velocity_min = 12; dust_particles.initial_velocity_max = 22
	dust_particles.scale_amount_min = 0.03; dust_particles.scale_amount_max = 0.13
	var dust_mat := StandardMaterial3D.new(); dust_mat.albedo_color = Color(0.65,0.43,0.28,0.32)
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new(); quad.size = Vector2(1.4,0.12); quad.material = dust_mat; dust_particles.mesh = quad
	add_child(dust_particles); dust_particles.emitting = false
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	var puff := SphereMesh.new(); puff.radius = 1; puff.height = 2; puff.radial_segments = 6; puff.rings = 3; mm.mesh = puff; mm.instance_count = 150
	var rng := RandomNumberGenerator.new(); rng.seed = 771
	for i: int in range(150):
		var h := float(i)/150*38; var angle := h*1.8+rng.randf()*2; var r := 1+h*0.10
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.45+h*0.04)),Vector3(cos(angle)*r,h,sin(angle)*r)))
	dust_devil = MultiMeshInstance3D.new(); dust_devil.multimesh = mm; dust_devil.material_override = dust_mat; add_child(dust_devil); dust_devil.hide()
	clouds = Node3D.new(); add_child(clouds)
	var cloud_shader := Shader.new()
	cloud_shader.code = "shader_type spatial; render_mode unshaded,cull_disabled,depth_draw_never; float h(vec2 p){return fract(sin(dot(p,vec2(12.3,78.7)))*43758.5);}float n(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1)),f.x),f.y);}void fragment(){float a=n(UV*vec2(9.0,3.0)+vec2(TIME*0.01,0));float edge=smoothstep(0.0,0.2,UV.x)*smoothstep(0.0,0.2,UV.y)*smoothstep(0.0,0.2,1.0-UV.x)*smoothstep(0.0,0.2,1.0-UV.y);ALBEDO=vec3(0.72,0.77,0.8);ALPHA=smoothstep(0.3,0.8,a)*edge*0.22;}"
	var cloud_mat := ShaderMaterial.new(); cloud_mat.shader = cloud_shader
	for i: int in range(8):
		var plane := PlaneMesh.new(); plane.size = Vector2(400,130)
		world.mesh_at(plane,Vector3(-600+i*170,150+i%3*16,-220+i%2*320),cloud_mat,clouds)

func update_weather_visuals(delta: float) -> void:
	dust_particles.global_position = player.global_position+Vector3(0,7,0)
	dust_particles.emitting = weather.severity >= 0.25 and model.phase == "SURFACE"
	dust_particles.initial_velocity_min = weather.wind_mps*0.8; dust_particles.initial_velocity_max = weather.wind_mps*1.3
	dust_devil.visible = weather.state == "DUST DEVILS"
	dust_devil.position = world.to_global(world.point(cos(model.elapsed*0.014)*350,sin(model.elapsed*0.014)*350))
	dust_devil.rotation.y += delta*0.9
	clouds.visible = weather.state in ["HIGH CLOUD","COLD TWILIGHT","FROST HAZE"]
	var cold := weather.state in ["COLD TWILIGHT","FROST HAZE"]
	world.sunlight.light_energy = lerpf(world.sunlight.light_energy,(0.30 if cold else (0.45 if model.storm else 0.85))*weather.daylight,1-exp(-delta*0.8))
	world.environment_resource.fog_light_color = world.environment_resource.fog_light_color.lerp(Color("8395a6") if cold else Color("bd8865"),1-exp(-delta))
	world.sky_material.sky_horizon_color = world.sky_material.sky_horizon_color.lerp(Color("8093a1") if cold else Color("c89571"),1-exp(-delta*0.5))
	if weather.state != last_weather:
		last_weather = weather.state
		if model.elapsed > 45: toast("WEATHER / "+weather.state+"\nMEDA sol 20 sensor profile; local wind and event timing are simulated.")

func build_orbit() -> void:
	orbital_stage = Node3D.new(); add_child(orbital_stage); orbital_stage.position.y = 1000; orbital_stage.hide()
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("03070e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("90a4bf"); env.ambient_light_energy = 0.3
	orbital_stage.set_meta("environment",env)
	var planet := SphereMesh.new(); planet.radius = 24; planet.height = 48; planet.radial_segments = 64; planet.rings = 32
	var shader := Shader.new(); shader.code = "shader_type spatial; varying vec3 p; void vertex(){p=VERTEX;} void fragment(){float lat=abs(p.y)/24.0;float n=sin(p.x*0.21+sin(p.z*0.32)*2.0)+cos(p.y*0.42+sin(p.x*0.3));vec3 ocean=vec3(0.035,0.15,0.30);vec3 land=vec3(0.18,0.27,0.18);ALBEDO=mix(ocean,land,smoothstep(0.1,0.45,n));ALBEDO=mix(ALBEDO,vec3(0.72,0.81,0.85),smoothstep(0.72,0.9,lat));ROUGHNESS=0.9;}"
	var earth := ShaderMaterial.new(); earth.shader = shader
	world.mesh_at(planet,Vector3(-28,-10,-64),earth,orbital_stage)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-25,20,0); key.light_color = Color("c8e2ff"); key.light_energy = 1.0; orbital_stage.add_child(key)
	transfer_ship = Node3D.new(); orbital_stage.add_child(transfer_ship)
	var white := world.mat(Color("aeb9be"),0.35); var dark := world.mat(Color("263c59"),0.55); var gold := world.mat(Color("b28b51"),0.6)
	var body := world.cylinder(Vector3(0,0,-8),0.85,4,white,transfer_ship); body.rotation.x = PI/2
	for x: float in [-4.0,4.0]:
		world.box(Vector3(x,0,-8),Vector3(5.0,0.08,3),dark,transfer_ship)
		world.box(Vector3(x*0.5,0,-8),Vector3(3.5,0.12,0.12),gold,transfer_ship)
	var glow := world.mat(Color("66b9e5")); glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var engine := CylinderMesh.new(); engine.top_radius = 0.45; engine.bottom_radius = 0.02; engine.height = 3.5
	var flame := world.mesh_at(engine,Vector3(0,0,-3.8),glow,transfer_ship); flame.rotation.x = PI/2
	var stars := MultiMesh.new(); stars.transform_format = MultiMesh.TRANSFORM_3D
	var star_mesh := SphereMesh.new(); star_mesh.radius = 0.05; star_mesh.height = 0.1; star_mesh.radial_segments = 4; star_mesh.rings = 2; stars.mesh = star_mesh; stars.instance_count = 350
	var rng := RandomNumberGenerator.new(); rng.seed = 2026
	for i: int in range(350): stars.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-110,110),rng.randf_range(-60,90),rng.randf_range(-150,-95))))
	var star_field := MultiMeshInstance3D.new(); star_field.multimesh = stars; star_field.material_override = glow; orbital_stage.add_child(star_field)

func checkpoint() -> bool:
	if isolated_demo: return true
	if guided: return true
	if testing or capture_mode != "": return true
	var d: Dictionary = model.snapshot(); d.position = [player.position.x,player.position.y,player.position.z]
	d.world_seed = world.world_seed; d.generator_version = 4; d.visited_regions = visited_regions
	d.campaign_id = campaign.id; d.expedition_number = campaign.expedition_number-(1 if model.phase=="RETURNED" else 0); d.field = field.snapshot(); d.ropes = traversal.snapshot()
	d.outpost = outpost.snapshot()
	d.hazards = hazards.snapshot(); d.jet_fuel = player.jet_fuel
	d.frontier = stream.snapshot(); var logical_p: Vector3 = stream.logical(player.position); d.position = [logical_p.x,logical_p.y,logical_p.z]
	d.yaw = player.camera_yaw; d.pitch = player.camera_pitch
	var f := FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if f == null: toast("Save failed: cannot write checkpoint."); return false
	f.store_string(JSON.stringify(d)); f.close()
	if FileAccess.file_exists(SAVE):
		if DirAccess.rename_absolute(SAVE,SAVE+".bak") != OK: toast("Save failed: cannot preserve backup."); return false
	if DirAccess.rename_absolute(SAVE+".tmp",SAVE) != OK: toast("Save failed: previous checkpoint kept as backup."); return false
	return true

func load_checkpoint() -> void:
	guided = false
	if campaign.status=="FAILED": toast("Campaign lost. Old checkpoints cannot revive it. Start a new campaign."); return
	for path: String in [SAVE,SAVE+".bak",LEGACY_SAVE,LEGACY_SAVE+".bak"]:
		if not FileAccess.file_exists(path): continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK: continue
		var d: Variant = parser.data
		if not d is Dictionary or not d.has("campaign_id"): continue
		if d.has("campaign_id") and (str(d.campaign_id)!=campaign.id or int(d.get("expedition_number",1))!=campaign.expedition_number): continue
		if int(d.get("generator_version",2)) not in [4]: continue
		var saved_seed := clampi(int(d.get("world_seed",42601)),1,999999999)
		if world.world_seed != saved_seed: regenerate_world(saved_seed)
		if not model.restore(d): continue
		selected_seed = saved_seed; visited_regions.clear()
		for region: Variant in d.get("visited_regions",[]):
			if int(region) in range(6) and not visited_regions.has(int(region)): visited_regions.append(int(region))
		player.position = world.point(0,42,0.1)
		if d.get("position") is Array and d.position.size() == 3:
			var x := float(d.position[0]); var z := float(d.position[2])
			if not is_finite(x) or not is_finite(z): continue
			stream.restore(d.get("frontier",{}))
			stream.origin = Vector2(floorf(x/256)*256,floorf(z/256)*256)
			world.position = Vector3(-stream.origin.x,0,-stream.origin.y)
			for chunk: Node3D in stream.chunks.values(): chunk.free()
			stream.chunks.clear(); stream.pending.clear()
			var saved_y := float(d.position[1]); var cave_data: Dictionary = field.cave_info(Vector3(x,saved_y,z))
			var floor_y: float = float(cave_data.floor) if not cave_data.is_empty() and saved_y<float(cave_data.ceiling) else stream.surface(x,z)
			player.position = stream.local(Vector3(x,floor_y+.2,z))
			stream.ensure_near(player.position,true)
		outpost.restore(d.get("outpost",{})); field.restore(d.get("field",{})); traversal.restore(d.get("ropes",{}))
		hazards.reset(saved_seed); hazards.restore(d.get("hazards",{})); player.jet_fuel = clampf(float(d.get("jet_fuel",100)),0,100)
		player.camera_yaw = float(d.get("yaw",0)); player.camera_pitch = clampf(float(d.get("pitch",-0.2)),-0.85,0.45)
		if model.phase == "RETURNED" or model.phase == "FAILED": finish(model.phase == "RETURNED")
		else: resume_surface(); toast("CHECKPOINT RESTORED")
		return
	toast("No valid checkpoint found. Start a new expedition.")

func integration_test() -> void:
	var errors: Array[String] = []
	if not player.avatar.detailed_suit: errors.append("Detailed suit asset missing")
	if not ResourceLoader.exists("res://assets/vehicles/sev.glb"): errors.append("NASA vehicle asset missing")
	for character: String in ["mh_3183","mh_3488","mh_3427","mh_1037"]:
		if not ResourceLoader.exists("res://assets/characters/"+character+".glb"): errors.append("Crew asset missing: "+character)
	if world.beacons.size() != 40 or world.refuges.size() != 6 or model.targets.size() != 40: errors.append("Expanded world assembly incomplete")
	var generator_check := preload("res://scripts/exploration_generator.gd").new()
	for seed_value: int in [1,42601,20261104]:
		generator_check.generate(seed_value); var signature: String = generator_check.signature()
		generator_check.generate(seed_value)
		if generator_check.signature() != signature or generator_check.discoveries.size() != 36: errors.append("Packaged generator failed repeatability")
	if int(weather.data.windAnalog.acceptedStationaryRows) < 1: errors.append("Wind data missing from runtime")
	model.configure(1,0); model.transit(true); model.pack.clear()
	for index: int in range(4,model.targets.size()):
		if model.targets[index].get("tool","") != "climbing": continue
		if model.can_sample(index) == "": errors.append("Packaged traversal-tool gate bypassed")
		model.pack.append("climbing")
		if not model.collect(index): errors.append("Equipped field target failed")
		var restored := Model.new(); restored.targets = model.targets.duplicate(true)
		if not restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) or not restored.samples.has(index): errors.append("Packaged extended save failed")
		break
	model.pack.assign(["traction","climbing"])
	for architecture: int in range(3):
		model.configure(architecture,0); model.transit(true)
		if model.return_gaps() == "": errors.append("Empty science bypassed return gate")
		for i: int in range(4):
			if model.can_sample(i) == "": model.collect(i)
		if model.samples.size() < 2 or model.return_gaps() != "": errors.append("Architecture cannot complete")
		if model.collect(model.samples[0]): errors.append("Duplicate evidence rewarded")
		var copy := Model.new()
		if not copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))): errors.append("Save roundtrip failed")
		if copy.samples != model.samples or copy.science != model.science: errors.append("Save state drift")
		var evidence_before: int = model.science
		if not model.interpret(model.samples[0],true) or model.interpret(model.samples[0],true): errors.append("Interpretation duplicate gate failed")
		if model.science != evidence_before+5: errors.append("Evidence interpretation bonus failed")
		if not model.downlink() or model.downlink(): errors.append("Downlink gate failed")
	model.configure(0,0); model.transit(false)
	if model.integrity != 80 or model.science != 10: errors.append("Transit tradeoff failed")
	if model.collect(1): errors.append("Missing instrument accepted")
	model.elapsed = 70; var before: float = model.integrity; var battery_before: float = model.battery; model.tick(10,false,false)
	if not model.storm or model.battery> battery_before-1.5 or model.integrity!=before: errors.append("Dust power effect / thin-atmosphere damage model failed")
	model.oxygen = 0; model.battery = 0; model.integrity = 1; model.tick(1,false,false)
	if model.integrity > 0: errors.append("Resource failure missing")
	model.configure(1,0); model.transit(true); model.integrity = 50
	if not model.repair() or model.repair(): errors.append("Repair not one-use")
	var invalid := model.snapshot(); invalid.loadout = 99
	if model.restore(invalid): errors.append("Invalid save accepted")
	model.configure(1,0); model.transit(true); resume_surface(); player.enabled = false
	await get_tree().physics_frame; await get_tree().physics_frame
	# Cast capsule down onto actual collision at all critical destinations.
	for p: Vector3 in [world.habitat,world.beacons[0].position,world.beacons[1].position,world.beacons[2].position,world.beacons[3].position]:
		var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*30,p-Vector3.UP*30)
		query.exclude = [player.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty(): errors.append("Terrain collision missing at "+str(p))
	player.position = world.point(0,42,0.1); player.camera_yaw = 0; player.set_test_move_input(Vector2(0,-1))
	for frame: int in range(120): await get_tree().physics_frame
	player.clear_test_move_input()
	if player.position.z > 39 or player.position.y < world.elevation(player.position.x,player.position.z)-1: errors.append("Mars traversal failed")
	for i: int in range(4):
		player.position = world.beacons[i].position
		if nearest_target() != i: errors.append("Target unreachable")
	# Traverse the critical route with the real CharacterBody, not teleports.
	player.position = world.point(0,42,0.2); player.velocity = Vector3.ZERO
	for destination: Vector3 in [world.beacons[0].position,world.beacons[1].position,world.beacons[2].position,world.beacons[3].position,world.point(0,42)]:
		var arrived := false
		player.set_test_move_input(Vector2(0,-1))
		for frame: int in range(9000):
			var offset := destination-player.position
			if Vector2(offset.x,offset.z).length() < 2.5: arrived = true; break
			player.camera_yaw = atan2(-offset.x,-offset.z)
			await get_tree().physics_frame
		player.clear_test_move_input()
		if not arrived: errors.append("Controller route blocked toward "+str(destination))
	# Exercise the same hold-to-scan path used by player input.
	model.configure(1,0); model.transit(true); resume_surface(); player.enabled = false
	player.position = world.beacons[0].position; player.velocity = Vector3.ZERO
	capture_mode = "test"; testing = false; scan_held = true
	for frame: int in range(3): _process(1.05)
	testing = true; capture_mode = ""
	if not model.samples.has(0) or not is_instance_valid(overlay): errors.append("Held scan did not open evidence screen")
	model.collect(0); model.collect(1)
	evidence_screen(0); habitat_console(); pause_screen(); source_return = "pause"; sources(); finish(true)
	sfx.stop()
	sfx.stream = null
	await get_tree().process_frame
	for e: String in errors: push_error(e)
	print("EXPEDITION INTEGRATION: ","PASS" if errors.is_empty() else "FAIL"," / seeded world, 40 sites, NASA profiles, traversal tools, architectures, resources, save, collision, movement, scanning, menus, return")
	get_tree().quit(0 if errors.is_empty() else 1)

func _exit_tree() -> void:
	Gfx.release_cache()
