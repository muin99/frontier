extends Node3D
const Cargo = preload("res://scripts/outpost_cargo.gd")
const Art = preload("res://scripts/field_hardware.gd")
var expedition: Node
var cargo := Cargo.new()
var installations: Array[Dictionary] = []
var actors: Dictionary = {}
var harvested: Dictionary = {}
var surveyed: Dictionary = {}
var explored: Dictionary = {}
var contracts: Dictionary = {}
var emergencies: Dictionary = {}
var markers: Dictionary = {}
var next_id := 1
var tier := 1
var research := 0
var water_made := 0
var food := 100.0
var hydration := 100.0
var clock := 0.0
var timer := 0.0
var network_timer := 0.0
var assembling := -1
var assembly_time := 0.0
var build_kind := ""
var build_yaw := 0.0
var ghost: Node3D
var ghost_position := Vector3.ZERO
var placement_reason := ""
var cable_visual: MeshInstance3D
var cable_signature := ""
var total_power := 0.0
var total_draw := 0.0
var nearest_id := -1
var nodes_revealed: Dictionary = {}
var last_local_gather := -10.0
var background_timer := 0.0
var background_sync := 0.0

func _physics_process(delta: float) -> void:
	# A listen-server operator can use a console while the crew keeps working.
	if not is_instance_valid(expedition) or not expedition.lan_active() or not authority() or expedition.model.phase!="SURFACE" or not is_instance_valid(expedition.overlay): return
	background_timer += delta; background_sync += delta
	if background_timer<1: return
	var dt := minf(background_timer,2); background_timer = 0; clock += dt
	simulate(dt)
	for peer: Dictionary in expedition.lan.peers.values(): award_exploration(peer.p)
	check_contracts(); refresh_actors()
	if background_sync>=4: background_sync = 0; sync(false)

func setup(game: Node) -> void:
	expedition = game; name = "OutpostNetwork"
	if not game.testing and game.capture_mode == "": cargo.read_draft()
	cable_visual = MeshInstance3D.new(); add_child(cable_visual)
	for chunk: Node3D in game.stream.chunks.values(): decorate_resources(chunk,chunk.get_meta("site").cell)

func authority() -> bool:
	return not expedition.lan_active() or expedition.lan.is_host

func catalog() -> Dictionary:
	return Cargo.catalog()

func stock_family(family: String) -> String:
	for id: String in cargo.kits:
		if int(cargo.kits[id])>0 and catalog().has(id) and str(catalog()[id].get("family",id))==family: return id
	return ""

func spec(unit: Dictionary) -> Dictionary:
	return catalog().get(str(unit.get("sku",unit.kind)),catalog()[unit.kind])

func capacity() -> float:
	var value := 260.0
	for unit: Dictionary in installations:
		if unit.kind=="cargo" and unit.stage==3: value += 100*float(spec(unit).get("capacityFactor",1))
	return value

func reset_for_launch() -> void:
	for actor: Node in actors.values(): actor.free()
	actors.clear(); installations.clear(); harvested.clear(); surveyed.clear(); explored.clear(); contracts.clear(); emergencies.clear(); markers.clear(); nodes_revealed.clear()
	next_id = 1; tier = 1; research = 0; water_made = 0; food = 100; hydration = 100; clock = 0; assembling = -1; cancel_build()
	cargo = Cargo.new()
	if not expedition.testing and expedition.capture_mode=="": cargo.read_draft()
	cable_signature = ""; cable_visual.mesh = null

func position_of(unit: Dictionary) -> Vector3:
	return Vector3(float(unit.p[0]),float(unit.p[1]),float(unit.p[2]))

func unit_by_id(id: int) -> Dictionary:
	for unit: Dictionary in installations:
		if int(unit.id)==id: return unit
	return {}

func player_position() -> Vector3:
	return expedition.stream.logical(expedition.player.position)

func build_menu(category := "Power") -> void:
	var v: VBoxContainer = expedition.menu(1000)
	v.add_child(expedition.text("DEPLOY / OUTPOST ASSEMBLY",30,expedition.MINT))
	v.add_child(expedition.paragraph("Cargo %.1f / %.0f kg • Tier %d • B opens kits, C opens fabrication. Choose a packed kit, position its hologram, then hold E at the frame for three assembly steps." % [cargo.mass(),capacity(),tier],17))
	var tabs := HBoxContainer.new(); v.add_child(tabs)
	for name: String in ["Power","Survival","Industry","Science","Exploration","Construction"]: tabs.add_child(expedition.action(name,func() -> void: build_menu(name)))
	for id: String in catalog():
		var item: Dictionary = catalog()[id]
		if item.category != category or item.get("portable",false) or item.get("rocket",false): continue
		v.add_child(expedition.action("%s  /  PACKED %d" % [item.name,cargo.kits.get(id,0)],func() -> void:
			if int(cargo.kits.get(id,0))<1: expedition.toast("No packed kit. Buy before departure or fabricate one at an online FORGE."); return
			begin_build(id)))
	v.add_child(expedition.action("CARGO / FABRICATE",cargo_menu)); v.add_child(expedition.action("BACK TO FIELD",expedition.resume_surface)); expedition.focus_first(v)

func begin_build(id: String) -> void:
	if expedition.driving: expedition.set_driving(false)
	cancel_build(); build_kind = id; build_yaw = expedition.player.camera_yaw
	ghost = Art.new().make(id); add_child(ghost)
	var material := StandardMaterial3D.new(); material.albedo_color = Color(.3,.95,.83,.45); material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.get_node("Shell").material_override = material
	expedition.resume_surface(); update_ghost()
	expedition.toast("PLACEMENT / Q rotate • left click or ENTER place • right click / ESC cancel\nGreen: valid footprint. Red: blocked, steep or too close.")

func cancel_build() -> void:
	build_kind = ""
	if is_instance_valid(ghost): ghost.queue_free()
	ghost = null

func handle_input(event: InputEvent) -> bool:
	if build_kind == "": return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q: build_yaw += PI/12; update_ghost(); return true
		if event.keycode == KEY_ESCAPE: cancel_build(); return true
		if event.keycode == KEY_ENTER: confirm_placement(); return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: cancel_build(); return true
		if event.button_index == MOUSE_BUTTON_LEFT: confirm_placement(); return true
	return event is InputEventKey and event.keycode in [KEY_E,KEY_F,KEY_B,KEY_C,KEY_G,KEY_R]

func update_ghost() -> void:
	var p := player_position()+Vector3(-sin(expedition.player.camera_yaw),0,-cos(expedition.player.camera_yaw))*7
	p.x = snappedf(p.x,1); p.z = snappedf(p.z,1); p.y = expedition.field.floor_for(p,player_position()) if is_instance_valid(expedition.field) else expedition.stream.surface(p.x,p.z)
	ghost_position = p
	placement_reason = validate_placement(build_kind,p,player_position(),build_yaw)
	ghost.position = expedition.stream.local(p); ghost.rotation.y = build_yaw
	var material: StandardMaterial3D = ghost.get_node("Shell").material_override
	material.albedo_color = Color(.2,.9,.7,.45) if placement_reason=="" else Color(1,.22,.2,.45)

func validate_placement(kind: String,p: Vector3,owner_position: Vector3,yaw := 0.0) -> String:
	if not catalog().has(kind) or not p.is_finite(): return "Invalid kit or coordinates"
	if owner_position.distance_to(p)>10 or owner_position.distance_to(p)<3: return "Place 3–10 metres from your astronaut"
	var r: float = catalog()[kind].radius
	var h: float = expedition.field.floor_for(p,owner_position) if is_instance_valid(expedition.field) else expedition.stream.surface(p.x,p.z)
	if absf(p.y-h)>.8: return "Footprint must meet the terrain"
	var slope := 0.0
	for offset: Vector2 in [Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]: slope = maxf(slope,absf((expedition.field.floor_for(p+Vector3(offset.x,0,offset.y),owner_position) if is_instance_valid(expedition.field) else expedition.stream.surface(p.x+offset.x,p.z+offset.y))-h)/r)
	if slope > (.65 if kind in ["bridge","ramp"] else .32): return "Slope too steep; use a valley or flatter site"
	if Vector2(p.x,p.z).distance_to(Vector2(0,28))<21: return "Keep the base habitat access clear"
	for beacon: Node3D in expedition.world.beacons:
		if p.distance_to(beacon.position)<r+4: return "Keep evidence access clear"
	var cell: Vector2i = expedition.stream.cell_at(p); var density := 0
	for dz: int in range(-1,2):
		for dx: int in range(-1,2):
			var sector := cell+Vector2i(dx,dz); var site: Dictionary = expedition.stream.site_data(sector)
			var service: Vector3 = site.position+Vector3(12,0,14); service.y = expedition.stream.surface(service.x,service.z)
			if p.distance_to(site.position)<r+3 or p.distance_to(service)<r+3: return "Keep activity and emergency-pod access clear"
			for index: int in range(3):
				if p.distance_to(resource_data(sector,index).p)<r+2: return "Keep the resource deposit accessible"
	for unit: Dictionary in installations:
		var at := position_of(unit)
		if expedition.stream.cell_at(at)==cell: density += 1
		if kind in ["bridge","ramp"] and unit.kind in ["bridge","ramp"]:
			if not Geometry2D.intersect_polygons(deck_footprint(kind,p,yaw),deck_footprint(unit.kind,at,float(unit.yaw))).is_empty(): return "Another deck occupies this footprint"
		elif p.distance_to(at)<r+float(spec(unit).radius)+.5: return "Another installation occupies this footprint"
	if density>=24: return "Sector construction limit: 24 modules; expand to a neighbouring sector"
	var shape := CylinderShape3D.new(); shape.radius = maxf(.3,r*.55); shape.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.transform = Transform3D(Basis.IDENTITY,expedition.stream.local(p)+Vector3(0,1.1,0)); query.exclude = [expedition.player.get_rid()]
	for hit: Dictionary in expedition.get_world_3d().direct_space_state.intersect_shape(query,16):
		if not hit.collider.get_meta("ground",false): return "Terrain object obstructs the installation; choose clear ground"
	return ""

func deck_footprint(kind: String,p: Vector3,yaw: float) -> PackedVector2Array:
	var length := 6.0 if kind=="bridge" else 4.0
	var forward := Vector2(sin(yaw),cos(yaw)); var right := Vector2(cos(yaw),-sin(yaw)); var centre := Vector2(p.x,p.z)
	var polygon := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]: polygon.append(centre+right*corner.x*.97+forward*corner.y*(length*.5-.03))
	return polygon

func confirm_placement() -> void:
	update_ghost()
	if placement_reason!="": expedition.toast(placement_reason); return
	if expedition.lan_active() and not authority():
		expedition.lan.request_outpost.rpc_id(1,"place",{"kind":build_kind,"p":[ghost_position.x,ghost_position.y,ghost_position.z],"yaw":build_yaw})
	else:
		var result := place(build_kind,ghost_position,build_yaw,player_position())
		expedition.toast(result if result!="" else "FRAME DEPLOYED / approach and hold E: anchor → wire → calibrate")
		sync()
	cancel_build()

func place(kind: String,p: Vector3,yaw: float,owner_position: Vector3) -> String:
	var reason := validate_placement(kind,p,owner_position,yaw)
	if reason!="": return reason
	if not is_finite(yaw) or int(cargo.kits.get(kind,0))<=0: return "Packed kit unavailable"
	cargo.kits[kind] = int(cargo.kits[kind])-1
	installations.append({"id":next_id,"kind":catalog()[kind].get("family",kind),"sku":kind,"p":[p.x,p.y,p.z],"yaw":yaw,"stage":0,"health":100.0,"energy":0.0,"oxygen":0.0,"progress":0.0,"online":false,"linked":false,"group":-1,"state":"ANCHOR FRAME"})
	next_id += 1; refresh_actors(); return ""

func assembly_step(id: int,p: Vector3) -> String:
	var unit := unit_by_id(id)
	if unit.is_empty() or p.distance_to(position_of(unit))>float(spec(unit).radius)+4: return "Approach the installation"
	if unit.stage>=3: return "Already commissioned"
	unit.stage += 1
	unit.state = ["ANCHOR FRAME","CONNECT HARNESS","CALIBRATE SYSTEM","COMMISSIONED"][unit.stage]
	if unit.stage==3:
		var commission_key: String = "assembly:"+str(unit.kind)+":"+expedition.stream.key(expedition.stream.cell_at(position_of(unit)))
		if not surveyed.has(commission_key): surveyed[commission_key] = true; expedition.model.science += 4
		simulate(.01)
	refresh_actors(); return ""

func tick(delta: float) -> void:
	if build_kind!="": update_ghost()
	for id: int in actors:
		var drone: Node3D = actors[id].get_node_or_null("SurveyDrone")
		if drone:
			var unit := unit_by_id(id); var t: float = float(unit.progress)+timer
			drone.position = Vector3(sin(t*.22)*9,4+sin(t*.3),cos(t*.22)*9) if unit.online else Vector3(0,1.15,0)
			drone.rotation.y = -t*.22
	nearest_id = nearest_unit(player_position())
	if assembling>=0:
		var unit := unit_by_id(assembling)
		if unit.is_empty() or nearest_id!=assembling or not Input.is_physical_key_pressed(KEY_E): assembling = -1; assembly_time = 0
		else:
			assembly_time += delta
			if assembly_time>=2:
				if expedition.lan_active() and not authority(): expedition.lan.request_outpost.rpc_id(1,"assemble",{"id":assembling})
				else: assembly_step(assembling,player_position()); sync()
				assembly_time = 0; assembling = -1
	timer += delta; network_timer += delta
	if timer<1: return
	var dt := minf(timer,2.0); timer = 0
	food = maxf(0,food-dt*.035); hydration = maxf(0,hydration-dt*.065)
	if hydration<1 or food<1: expedition.model.integrity = maxf(0,expedition.model.integrity-dt*.3)
	if authority():
		clock += dt; simulate(dt); award_exploration(player_position())
		if expedition.lan_active():
			for peer: Dictionary in expedition.lan.peers.values(): award_exploration(peer.p)
		check_contracts()
	service_player(dt); refresh_actors(); emergency_pod()
	if authority() and network_timer>=4: network_timer = 0; sync(false)

func award_exploration(p: Vector3) -> void:
	var key: String = expedition.stream.key(expedition.stream.cell_at(p))
	if explored.has(key): return
	explored[key] = true; expedition.model.science += 8

func nearest_unit(p: Vector3) -> int:
	var chosen := -1; var best := INF
	for unit: Dictionary in installations:
		var d := p.distance_to(position_of(unit)); var range_limit: float = float(spec(unit).radius)+3.3
		if d<range_limit and d<best: best = d; chosen = int(unit.id)
	return chosen

func prompt_text() -> String:
	if build_kind!="": return "PLACE / Q rotate • ENTER confirm • ESC cancel / "+("VALID FOOTPRINT" if placement_reason=="" else placement_reason)
	if nearest_id<0: return ""
	var unit := unit_by_id(nearest_id)
	if unit.stage<3: return "HOLD E / %s • %s %d%%" % [spec(unit).name,unit.state,int(assembly_time/2*100)]
	return "E / %s • %s • C fabrication" % [spec(unit).name,unit.state]

func interact() -> bool:
	if nearest_id<0: return false
	if expedition.driving: expedition.toast("Exit the rover with R to work on field hardware"); return true
	var unit := unit_by_id(nearest_id)
	if unit.stage<3:
		assembling = nearest_id; assembly_time = 0
		if expedition.lan_active() and not authority(): expedition.lan.begin_outpost_assembly.rpc_id(1,nearest_id)
	else: unit_console(nearest_id)
	return true

func simulate(dt: float) -> void:
	var active_units: Array[Dictionary] = []
	var buckets: Dictionary = {}
	for unit: Dictionary in installations:
		unit.online = false; unit.linked = false; unit.group = -1
		if unit.stage<3: continue
		if unit.health<=0: unit.state = "DAMAGED / REPAIR"; continue
		var p := position_of(unit); var cell := Vector2i(floori(p.x/40),floori(p.z/40))
		if not buckets.has(cell): buckets[cell] = []
		buckets[cell].append(unit); active_units.append(unit)
	var group_id := 0; var edges: Array[Array] = []
	total_power = 0; total_draw = 0
	for start: Dictionary in active_units:
		if start.group>=0: continue
		var group: Array[Dictionary] = []; var queue: Array[Dictionary] = [start]; start.group = group_id
		while not queue.is_empty():
			var u: Dictionary = queue.pop_front(); group.append(u)
			var p := position_of(u); var cell := Vector2i(floori(p.x/40),floori(p.z/40))
			for dz: int in range(-1,2):
				for dx: int in range(-1,2):
					for other: Dictionary in buckets.get(cell+Vector2i(dx,dz),[]):
						if other.group>=0: continue
						var reach := (38.0 if u.kind=="coupler" or other.kind=="coupler" else 20.0)*maxf(float(spec(u).get("reachFactor",1)),float(spec(other).get("reachFactor",1)))
						if p.distance_to(position_of(other))<=reach:
							other.group = group_id; queue.append(other); edges.append([int(u.id),int(other.id)])
		power_group(group,dt); group_id += 1
	# Communications are separate from the short-range power grid.
	var relays: Array[Dictionary] = []
	for u: Dictionary in active_units:
		if u.kind=="relay" and u.online:
			u.linked = Vector2(position_of(u).x,position_of(u).z).distance_to(Vector2(0,28))<=260
			relays.append(u)
	for pass_index: int in range(relays.size()):
		var changed := false
		for a: Dictionary in relays:
			if a.linked: continue
			for b: Dictionary in relays:
				if b.linked and position_of(a).distance_to(position_of(b))<=360: a.linked = true; changed = true; break
		if not changed: break
	for u: Dictionary in active_units:
		var p := position_of(u)
		if Vector2(p.x,p.z).distance_to(Vector2(0,28))<180: u.linked = true
		for relay: Dictionary in relays:
			if relay.linked and p.distance_to(position_of(relay))<180: u.linked = true; break
	for u: Dictionary in active_units:
		if u.online: operate(u,dt,active_units)
		if expedition.weather.severity>.7 and u.kind not in ["habitat","cargo","battery"]: u.health = maxf(0,u.health-dt*.025/float(spec(u).get("durability",1)))
	draw_cables(edges)

func power_group(group: Array[Dictionary],dt: float) -> void:
	var supply := 0.0; var batteries: Array[Dictionary] = []
	for u: Dictionary in group:
		var unit_spec: Dictionary = spec(u)
		supply += float(unit_spec.output)*(expedition.weather.solar_fraction if u.kind=="solar" else 1.0)
		if u.kind=="battery": batteries.append(u)
	var production := supply; var buffer_power := 0.0
	for b: Dictionary in batteries: buffer_power += minf(5*float(spec(b).get("capacityFactor",1)),float(b.energy)/dt)
	var used := 0.0
	group.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var priority := {"oxygen":0,"habitat":1,"ice":2,"relay":3,"battery":4}
		return int(priority.get(a.kind,5))<int(priority.get(b.kind,5)))
	for u: Dictionary in group:
		var draw: float = spec(u).draw
		if draw<=supply+buffer_power-used+.001: u.online = true; u.state = "ONLINE"; used += draw
		else: u.state = "NO POWER / add source or battery"
	var deficit := maxf(0,used-production)
	for b: Dictionary in batteries:
		var amount := minf(minf(5*float(spec(b).get("capacityFactor",1))*dt,float(b.energy)),deficit*dt); b.energy -= amount; deficit -= amount/dt
	var surplus := maxf(0,production-used)
	for b: Dictionary in batteries:
		var amount := minf(100*float(spec(b).get("capacityFactor",1))-float(b.energy),surplus*dt); b.energy += amount; surplus -= amount/dt
	total_power += production; total_draw += used

func operate(u: Dictionary,dt: float,all_units: Array) -> void:
	var p := position_of(u)
	if u.kind in ["ice","greenhouse"] and cargo.mass()+.5>capacity(): u.state = "CARGO FULL / add ATLAS storage"; return
	match str(u.kind):
		"oxygen":
			if int(cargo.materials.water)>0 and float(u.oxygen)<150:
				u.oxygen = minf(150,u.oxygen+dt*.9*float(spec(u).get("capacityFactor",1))); u.progress += dt
				if u.progress>=12: cargo.materials.water -= 1; u.progress = 0
			else: u.state = "O₂ FULL" if u.oxygen>=150 else "NEEDS WATER"
		"ice":
			var deposit := nearby_deposit(p,"ice",22)
			var recovered_ice := int(cargo.materials.ice)>0
			if deposit.is_empty() and not recovered_ice: u.state = "NEEDS ICE DEPOSIT OR RECOVERED ICE"; return
			if not recovered_ice and int(harvested.get(deposit.id,0))>=90: u.state = "ICE RESERVE DEPLETED / relocate"; return
			u.progress += dt
			if u.progress>=5:
				u.progress = 0; cargo.materials.water += 1; water_made += 1
				if recovered_ice: cargo.materials.ice -= 1
				else: harvested[deposit.id] = int(harvested.get(deposit.id,0))+1
		"greenhouse":
			if int(cargo.materials.water)<=0: u.state = "NEEDS WATER"; return
			u.progress += dt
			if u.progress>=30: u.progress = 0; cargo.materials.water -= 1; cargo.materials.rations += 2
		"refinery":
			if int(cargo.materials.regolith)<2: u.state = "NEEDS 2 REGOLITH"; return
			u.progress += dt
			if u.progress>=8: u.progress = 0; cargo.materials.regolith -= 2; cargo.materials.alloy += 1
		"scrubber":
			if position_of(u).distance_to(player_position())<8: expedition.field.dust = maxf(0,expedition.field.dust-dt*2)
		"heater":
			if position_of(u).distance_to(player_position())<9: expedition.field.cold = maxf(0,expedition.field.cold-dt*2)
		"shelter","radiometer":
			if position_of(u).distance_to(player_position())<8: expedition.field.exposure = maxf(0,expedition.field.exposure-dt*.4)
		"repair_station":
			if position_of(u).distance_to(player_position())<7 and expedition.model.integrity<95 and int(cargo.materials.alloy)>0:
				u.progress += dt
				if u.progress>=8: u.progress = 0; cargo.materials.alloy -= 1; expedition.model.integrity = minf(100,expedition.model.integrity+12)
		"oxygen_cache":
			if position_of(u).distance_to(player_position())<5 and u.progress<45:
				var amount := minf(dt*2,45-float(u.progress)); u.progress += amount; expedition.model.oxygen = minf(float(expedition.Model.LOADOUTS[expedition.model.loadout].oxygen),expedition.model.oxygen+amount)
		"fabricator": tier = maxi(tier,2)
		"weather","spectrometer","observatory","seismic","survey_lidar","sample_vault":
			if not u.linked: u.state = "NO DOWNLINK / build relay chain"; return
			if u.kind=="observatory" and expedition.weather.state not in ["CLEAR","HIGH CLOUD"]: u.state = "WAITING FOR CLEAR SKY"; return
			if u.kind=="seismic":
				var count := 1
				for other: Dictionary in all_units:
					if other.id!=u.id and other.kind=="seismic" and other.online and other.linked and position_of(other).distance_to(p)>=20 and position_of(other).distance_to(p)<=150: count += 1
				if count<3: u.state = "ARRAY NEEDS 3 ANCHORS / 20–150m spacing"; return
			var evidence_key: String = str(u.kind)+":"+expedition.stream.key(expedition.stream.cell_at(p))
			if surveyed.has(evidence_key): u.state = "RESEARCH SECURED / new sector needed"; return
			u.progress += dt*float(spec(u).get("researchRate",1)); u.state = "RECORDING %d / 45s" % int(u.progress)
			if u.progress>=45:
				surveyed[evidence_key] = true; research += 1; expedition.model.science += 36
				cargo.materials.circuits += 2; cargo.materials.polymer += 1; u.progress = 0
				if u.kind=="spectrometer" and explored.size()>=3: tier = 3
				expedition.toast("RESEARCH PACKAGE / "+str(catalog()[u.kind].name)+"\n+36 science • recovered electronics • original simulated deployment")
		"dronepad":
			u.progress += dt; u.state = "SURVEY SORTIE %d / 45s" % int(u.progress)
			if u.progress>=45:
				u.progress = 0
				var cell: Vector2i = expedition.stream.cell_at(p)
				for dz: int in range(-1,2):
					for dx: int in range(-1,2): nodes_revealed[expedition.stream.key(cell+Vector2i(dx,dz))] = true
				u.state = "LOCAL RESOURCES MAPPED"

func service_available(p: Vector3) -> bool:
	for unit: Dictionary in installations:
		if unit.kind=="habitat" and unit.stage==3 and unit.online and p.distance_to(position_of(unit))<7: return true
	return false

func service_player(dt: float) -> void:
	var p := player_position()
	if not authority():
		for unit: Dictionary in installations:
			if not unit.online or p.distance_to(position_of(unit))>8: continue
			if unit.kind=="heater": expedition.field.cold = maxf(0,expedition.field.cold-dt*2)
			if unit.kind=="scrubber": expedition.field.dust = maxf(0,expedition.field.dust-dt*2)
			if unit.kind in ["shelter","radiometer"]: expedition.field.exposure = maxf(0,expedition.field.exposure-dt*.4)
	for habitat: Dictionary in installations:
		if habitat.kind!="habitat" or not habitat.online or p.distance_to(position_of(habitat))>=7: continue
		expedition.model.battery = minf(float(expedition.Model.LOADOUTS[expedition.model.loadout].battery),expedition.model.battery+dt*1.8)
		if authority():
			var amount := draw_oxygen(p,minf(dt*3,float(expedition.Model.LOADOUTS[expedition.model.loadout].oxygen)-expedition.model.oxygen))
			expedition.model.oxygen += amount
		elif expedition.model.oxygen<float(expedition.Model.LOADOUTS[expedition.model.loadout].oxygen)-1: expedition.lan.request_outpost.rpc_id(1,"service",{})
		if food>20 and hydration>20: expedition.model.integrity = minf(100,expedition.model.integrity+dt*.15)
		break

func draw_oxygen(p: Vector3,requested: float) -> float:
	for habitat: Dictionary in installations:
		if habitat.kind!="habitat" or not habitat.online or p.distance_to(position_of(habitat))>=7: continue
		for oxygen: Dictionary in installations:
			if oxygen.kind=="oxygen" and oxygen.online and oxygen.group==habitat.group:
				var amount := minf(float(oxygen.oxygen),requested); oxygen.oxygen -= amount; return amount
	return 0

func emergency_pod() -> void:
	if not expedition.stream.is_sheltered(): return
	var id: String = expedition.stream.key(expedition.stream.cell_at(player_position()))
	if emergencies.has(id): return
	if expedition.lan_active() and not authority():
		emergencies[id] = true; expedition.lan.request_outpost.rpc_id(1,"emergency",{}); return
	emergencies[id] = true
	expedition.model.oxygen = minf(float(expedition.Model.LOADOUTS[expedition.model.loadout].oxygen),expedition.model.oxygen+25)
	expedition.model.battery = minf(float(expedition.Model.LOADOUTS[expedition.model.loadout].battery),expedition.model.battery+15)
	expedition.toast("EMERGENCY POD / one reserve recovered. Build powered HAVEN + AERIS for sustained field support.")

func resource_data(cell: Vector2i,index: int) -> Dictionary:
	var site: Dictionary = expedition.stream.site_data(cell); var kind: int = site.kind
	if expedition.stream.is_base(cell):
		var region_index: int = expedition.world.generator.region_at(site.position.x,site.position.z)
		kind = 0 if region_index<0 else expedition.stream.KINDS.find(str(expedition.world.generator.regions[region_index].kind))
	var offsets := [Vector3(-28,0,20),Vector3(32,0,-25),Vector3(-24,0,-34)]
	var p: Vector3 = site.position+offsets[index]; p.y = expedition.stream.surface(p.x,p.z)
	var resource: String = ["alloy" if kind==1 else "regolith","circuits","ice" if kind==4 else "polymer"][index]
	return {"id":expedition.stream.key(cell)+"/"+str(index),"resource":resource,"p":p,"quantity":90 if resource=="ice" else 12}

func nearby_deposit(p: Vector3,resource := "",reach := 4.0) -> Dictionary:
	var cell: Vector2i = expedition.stream.cell_at(p); var best := reach; var chosen: Dictionary = {}
	for dz: int in range(-1,2):
		for dx: int in range(-1,2):
			for index: int in range(3):
				var node := resource_data(cell+Vector2i(dx,dz),index)
				if resource!="" and node.resource!=resource: continue
				var distance: float = p.distance_to(node.p)
				if distance<best: chosen = node; best = distance
	return chosen

func decorate_resources(chunk: Node3D,cell: Vector2i) -> void:
	if chunk.has_node("Resources"): return
	var root := Node3D.new(); root.name = "Resources"; chunk.add_child(root)
	var records: Array[Dictionary] = []
	for index: int in range(3):
		var node := resource_data(cell,index)
		records.append(node)
		var holder := Node3D.new(); root.add_child(holder); holder.position = node.p-Vector3(cell.x*256,0,cell.y*256)
		var builder := Art.new()
		var visual: Node3D = builder.make("cargo" if node.resource in ["circuits","polymer"] else ("ice_deposit" if node.resource=="ice" else "ore"))
		holder.add_child(visual); visual.scale = Vector3.ONE*.45
		visual.get_node("Shell").visibility_range_end = 150
		var l := Label3D.new(); holder.add_child(l); l.text = node.resource.to_upper()+" / G TO RECOVER"; l.position.y = 1.5; l.font_size = 24; l.pixel_size = .007; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.modulate = Color("d6bc8d"); l.visibility_range_end = 32
	chunk.set_meta("outpost_resources",records)

func gather(p: Vector3) -> String:
	var node := nearby_deposit(p)
	if node.is_empty(): return "Approach a labelled resource site; G recovers material"
	var used := int(harvested.get(node.id,0))
	if used>=int(node.quantity): return "Deposit depleted. Explore a new sector"
	if cargo.mass()+.75>capacity(): return "Cargo full; deploy kits or build an ATLAS cargo vault"
	var amount := mini(3,int(node.quantity)-used)
	var type: String = str(node.resource)
	if type=="alloy" and not expedition.Model.LOADOUTS[expedition.model.loadout].drill: return "Hard-rock recovery requires a drill architecture"
	cargo.materials[type] = int(cargo.materials.get(type,0))+amount; harvested[node.id] = used+amount
	return "RECOVERED / +%d %s" % [amount,type]

func can_fabricate(id: String,p: Vector3) -> String:
	if not catalog().has(id): return "Unknown recipe"
	var item: Dictionary = catalog()[id]
	if tier<int(item.tier): return "Requires fabrication tier "+str(item.tier)
	var station := Vector2(p.x,p.z).distance_to(Vector2(0,28))<20
	for unit: Dictionary in installations:
		if unit.kind=="fabricator" and unit.online and p.distance_to(position_of(unit))<7: station = true
	if not station: return "Use a powered FORGE within 7m, or the main habitat workshop"
	for material: String in item.recipe:
		if int(cargo.materials.get(material,0))<int(item.recipe[material]): return "Need "+recipe_text(item.recipe)
	var consumed := 0.0
	for material: String in item.recipe: consumed += int(item.recipe[material])*.25
	if cargo.mass()-consumed+float(item.mass)>capacity(): return "Crafted kit would exceed cargo capacity"
	return ""

func fabricate(id: String,p: Vector3) -> String:
	var reason := can_fabricate(id,p)
	if reason!="": return reason
	for material: String in catalog()[id].recipe: cargo.materials[material] -= int(catalog()[id].recipe[material])
	cargo.kits[id] = int(cargo.kits.get(id,0))+1
	return "KIT FABRICATED / "+str(catalog()[id].name)

func recipe_text(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	for id: String in recipe: parts.append("%d %s" % [recipe[id],id])
	return ", ".join(parts)

func cargo_menu(category := "Power") -> void:
	var v: VBoxContainer = expedition.menu(1050)
	v.add_child(expedition.text("CARGO / FIELD FABRICATION",29,expedition.MINT))
	v.add_child(expedition.paragraph("%.1f / %.0f kg • Tier %d • Research %d • FOOD %d%% / WATER %d%%\n%s" % [cargo.mass(),capacity(),tier,research,food,hydration,recipe_text(cargo.materials)],18,expedition.GOLD))
	var buttons := HBoxContainer.new(); v.add_child(buttons)
	buttons.add_child(expedition.action("DRINK / 1 water",func() -> void: request_action("drink",{}); cargo_menu(category)))
	buttons.add_child(expedition.action("EAT / 1 ration",func() -> void: request_action("eat",{}); cargo_menu(category)))
	buttons.add_child(expedition.action("CONSTRUCTION CONTRACTS",contract_menu))
	var tabs := HBoxContainer.new(); v.add_child(tabs)
	for name: String in ["Power","Survival","Industry","Science","Exploration","Construction"]: tabs.add_child(expedition.action(name,func() -> void: cargo_menu(name)))
	for id: String in catalog():
		var spec: Dictionary = catalog()[id]
		if spec.category!=category: continue
		var reason := can_fabricate(id,player_position())
		v.add_child(expedition.action("%s • TIER %d • PACKED %d\n%s / %s" % [spec.name,spec.tier,cargo.kits.get(id,0),recipe_text(spec.recipe),"FABRICATE" if reason=="" else reason],func() -> void:
			request_action("craft",{"kind":id}); cargo_menu(category)))
	v.add_child(expedition.paragraph("Tier 2: commission a powered FORGE. Tier 3: complete a linked PRISM research package after exploring three sectors. G gathers material; the refinery converts regolith to alloy. Different installations unlock different parts of the survival network.",16))
	v.add_child(expedition.action("BUILD PACKED KITS",build_menu)); v.add_child(expedition.action("BACK TO FIELD",expedition.resume_surface)); expedition.focus_first(v)

func request_action(action: String,data: Dictionary) -> void:
	if action=="drink" and hydration>=99: expedition.toast("Suit water reserve is already full"); return
	if action=="eat" and food>=99: expedition.toast("Food reserve is already full"); return
	if expedition.lan_active() and not authority(): expedition.lan.request_outpost.rpc_id(1,action,data)
	else:
		if action=="gather":
			if clock-last_local_gather<1.5: expedition.toast("Recovery tool cycling / wait a moment"); return
			last_local_gather = clock
		expedition.toast(apply_action(action,data,player_position())); sync()

func apply_action(action: String,data: Dictionary,p: Vector3) -> String:
	match action:
		"gear":
			var kind := str(data.get("kind",""))
			if kind not in ["oxygen_bottle","spare_cell","medkit","sealant"] or int(cargo.kits.get(kind,0))<1: return "Consumable unavailable"
			cargo.kits[kind] -= 1
			if kind=="oxygen_bottle": expedition.model.oxygen = minf(float(expedition.Model.LOADOUTS[expedition.model.loadout].oxygen),expedition.model.oxygen+45)
			if kind=="spare_cell": expedition.model.battery = minf(float(expedition.Model.LOADOUTS[expedition.model.loadout].battery),expedition.model.battery+35)
			if kind in ["medkit","sealant"]: expedition.model.integrity = minf(100,expedition.model.integrity+(35 if kind=="medkit" else 20))
			if kind=="sealant": expedition.field.dust = maxf(0,expedition.field.dust-40)
			return "EVA CONSUMABLE USED"
		"gather": return gather(p)
		"craft": return fabricate(str(data.get("kind","")),p)
		"place":
			if not data.get("p") is Array or data.p.size()!=3: return "Invalid placement"
			return place(str(data.get("kind","")),Vector3(float(data.p[0]),float(data.p[1]),float(data.p[2])),float(data.get("yaw",0)),p)
		"drink":
			if int(cargo.materials.water)<=0: return "No stored water"
			cargo.materials.water -= 1; hydration = minf(100,hydration+35); return "HYDRATED / +35 water reserve"
		"eat":
			if int(cargo.materials.rations)<=0: return "No stored rations"
			cargo.materials.rations -= 1; food = minf(100,food+40); return "FED / +40 food reserve"
		"repair":
			var unit := unit_by_id(int(data.get("id",-1)))
			if unit.is_empty() or p.distance_to(position_of(unit))>7: return "Approach installation"
			if int(cargo.materials.alloy)<2: return "Need 2 alloy"
			cargo.materials.alloy -= 2; unit.health = 100; return "STRUCTURE REPAIRED"
		"pack":
			var unit := unit_by_id(int(data.get("id",-1)))
			if unit.is_empty() or p.distance_to(position_of(unit))>7: return "Approach installation"
			var remaining_capacity := capacity()-(100 if unit.kind=="cargo" and unit.stage==3 else 0)
			if cargo.mass()+float(spec(unit).mass)>remaining_capacity: return "Cargo full after repacking this module"
			var sku: String = str(unit.get("sku",unit.kind))
			cargo.kits[sku] = int(cargo.kits.get(sku,0))+1; installations.erase(unit)
			if actors.has(int(unit.id)): actors[int(unit.id)].queue_free(); actors.erase(int(unit.id))
			return "KIT REPACKED / production reservoirs discharged"
	return "Unknown operation"

func unit_console(id: int) -> void:
	var unit := unit_by_id(id)
	if unit.is_empty(): return
	var v: VBoxContainer = expedition.menu(800)
	v.add_child(expedition.text(spec(unit).name,30,expedition.MINT))
	v.add_child(expedition.paragraph(str(spec(unit).description),20))
	v.add_child(expedition.paragraph("%s\nIntegrity %.0f%% • Grid %d • Data link %s\nPower network %.1f generated / %.1f allocated\nStored energy %.1f / O₂ %.1f" % [unit.state,unit.health,unit.group,"CONNECTED" if unit.linked else "OFFLINE",total_power,total_draw,unit.energy,unit.oxygen],18,expedition.GOLD))
	if unit.kind=="weather": v.add_child(expedition.paragraph("Archived MEDA analog profile: %.1f°C / %.1f Pa / %.1f m/s. Placement and research production are simulated; this is not a measured new Mars station." % [expedition.weather.measured_temperature_c,expedition.weather.pressure_pa,expedition.weather.wind_mps],16))
	if unit.kind=="habitat": v.add_child(expedition.action("SUIT SYSTEMS / TRAVERSAL KITS",expedition.habitat_console))
	v.add_child(expedition.action("REPAIR / 2 ALLOY",func() -> void: request_action("repair",{"id":id}); unit_console(id)))
	v.add_child(expedition.action("REPACK KIT / relocate",func() -> void: request_action("pack",{"id":id}); expedition.resume_surface()))
	v.add_child(expedition.action("CARGO / FABRICATION",cargo_menu)); v.add_child(expedition.action("BACK TO FIELD",expedition.resume_surface)); expedition.focus_first(v)

func refresh_actors() -> void:
	var p := player_position(); var alive: Dictionary = {}
	for unit: Dictionary in installations:
		var id := int(unit.id)
		if p.distance_to(position_of(unit))>900: continue
		alive[id] = true
		if not actors.has(id):
			var root := Art.new().make(str(unit.get("sku",unit.kind))); add_child(root); root.rotation.y = float(unit.yaw); actors[id] = root
			var l := Label3D.new(); l.name = "Readout"; root.add_child(l); l.position.y = 3.3; l.font_size = 23; l.pixel_size = .006; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.visibility_range_end = 24
			var body := StaticBody3D.new(); root.add_child(body)
			if unit.kind=="dronepad":
				var drone := Art.new().make("survey_drone"); drone.name = "SurveyDrone"; root.add_child(drone)
			if unit.kind=="floodlight":
				var lamp := OmniLight3D.new(); lamp.name = "FieldLamp"; root.add_child(lamp); lamp.position.y = 2.2; lamp.omni_range = 22*float(spec(unit).get("reachFactor",1)); lamp.light_color = Color("bcdbe0"); lamp.light_energy = 2.3
			if unit.kind not in ["bridge","ramp"]:
				var collision := CollisionShape3D.new(); var shape := CylinderShape3D.new(); shape.radius = float(spec(unit).radius)*.55; shape.height = 1.7
				collision.shape = shape; collision.position.y = .85; body.add_child(collision)
		actors[id].position = expedition.stream.local(position_of(unit))
		if actors[id].has_node("FieldLamp"): actors[id].get_node("FieldLamp").visible = unit.online and unit.stage==3
		if unit.kind in ["bridge","ramp"] and unit.stage==3 and not actors[id].has_meta("deck_ready"):
			actors[id].get_node("Shell").create_trimesh_collision(); actors[id].set_meta("deck_ready",true)
		actors[id].get_node("Shell").transparency = .5 if unit.stage<3 else 0
		actors[id].get_node("Readout").text = str(spec(unit).name)+"\n"+str(unit.state)
		actors[id].get_node("Readout").modulate = Color("8de0d4") if unit.online else Color("eec393")
	for id: int in actors.keys():
		if not alive.has(id): actors[id].queue_free(); actors.erase(id)

func draw_cables(edges: Array[Array]) -> void:
	var signature := str(edges)+str(expedition.stream.origin)
	if signature==cable_signature: return
	cable_signature = signature
	if edges.is_empty(): cable_visual.mesh = null; return
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := StandardMaterial3D.new(); m.albedo_color = Color("3f8f91"); m.metallic = .5; st.set_material(m)
	for edge: Array in edges:
		var a: Vector3 = expedition.stream.local(position_of(unit_by_id(edge[0])))+Vector3(0,.17,0)
		var b: Vector3 = expedition.stream.local(position_of(unit_by_id(edge[1])))+Vector3(0,.17,0)
		if a.distance_to(expedition.player.position)>900: continue
		var side := (b-a).cross(Vector3.UP).normalized()*.035
		for v: Vector3 in [a-side,a+side,b+side,a-side,b+side,b-side]: st.add_vertex(v)
	st.generate_normals(); cable_visual.mesh = st.commit()

func check_contracts() -> void:
	var counts: Dictionary = {}
	for unit: Dictionary in installations:
		if unit.stage==3 and unit.online: counts[unit.kind] = int(counts.get(unit.kind,0))+1
	var weather_sectors := 0
	for key: String in surveyed:
		if key.begins_with("weather:"): weather_sectors += 1
	var requirements := {"power":int(counts.get("solar",0))+int(counts.get("reactor",0))>0 and int(counts.get("battery",0))>0,"survival":int(counts.get("habitat",0))>0 and int(counts.get("oxygen",0))>0,"industry":int(counts.get("fabricator",0))>0 and int(counts.get("refinery",0))>0,"water":water_made>=10,"weather":weather_sectors>=3,"seismic":false,"frontier":false,"observatory":false}
	for key: String in surveyed:
		if key.begins_with("seismic:"): requirements.seismic = true
		if key.begins_with("observatory:"): requirements.observatory = true
	for unit: Dictionary in installations:
		if unit.kind=="habitat" and unit.online and Vector2(position_of(unit).x,position_of(unit).z).length()>800: requirements.frontier = true
	for id: String in requirements:
		if requirements[id] and not contracts.has(id):
			contracts[id] = true; expedition.model.science += 65; cargo.materials.alloy += 4; cargo.materials.circuits += 3
			expedition.toast("CONSTRUCTION CONTRACT / "+id.to_upper()+"\n+65 science • +4 alloy • +3 circuits")

func contract_menu() -> void:
	var v: VBoxContainer = expedition.menu(920)
	v.add_child(expedition.text("FRONTIER ENGINEERING CONTRACTS",29,expedition.MINT))
	var descriptions := {"power":"Commission a power source and battery","survival":"Commission powered HAVEN and AERIS","industry":"Run FORGE and CRUCIBLE together","water":"Extract 10 units from a highland ice deposit","weather":"Return weather packages from three sectors","seismic":"Return a three-anchor seismic-array package","frontier":"Power a shelter beyond 800m from base","observatory":"Return an ORION clear-sky research package"}
	for id: String in descriptions: v.add_child(expedition.paragraph(("COMPLETE  " if contracts.has(id) else "OPEN  ")+str(descriptions[id])+"  /  65 science + fabrication materials",18,expedition.MINT if contracts.has(id) else expedition.GOLD))
	v.add_child(expedition.paragraph("Exploration: +8 science for each new sector, once. Research: +36 for each new instrument/sector package. Modules can be repacked and moved; more distant stations need independent power and a relay path back to base.",17))
	v.add_child(expedition.action("CARGO / FABRICATE",cargo_menu)); v.add_child(expedition.action("BACK TO FIELD",expedition.resume_surface)); expedition.focus_first(v)

func sync(save := true) -> void:
	if expedition.lan_active() and authority(): expedition.lan.broadcast_progress()
	if save: expedition.checkpoint()

func snapshot() -> Dictionary:
	return {"version":1,"cargo":cargo.snapshot(),"installations":installations.duplicate(true),"harvested":harvested.duplicate(),"surveyed":surveyed.duplicate(),"explored":explored.duplicate(),"contracts":contracts.duplicate(),"emergencies":emergencies.duplicate(),"next_id":next_id,"tier":tier,"research":research,"water_made":water_made,"food":food,"hydration":hydration,"clock":clock,"nodes_revealed":nodes_revealed.duplicate()}

func restore(d: Dictionary,personal := true) -> void:
	if d.is_empty(): return
	if d.get("cargo") is Dictionary: cargo.restore(d.cargo)
	installations.clear()
	if d.get("installations") is Array:
		for unit: Variant in d.installations:
			if not unit is Dictionary or not catalog().has(str(unit.get("kind",""))) or not unit.get("p") is Array or unit.p.size()!=3: continue
			var valid_unit := true
			for field: String in ["id","yaw","stage","health","energy","oxygen","progress","online","linked","group","state"]:
				if not unit.has(field): valid_unit = false
			if not valid_unit: continue
			for field: String in ["yaw","health","energy","oxygen","progress"]:
				if not (unit[field] is float or unit[field] is int) or not is_finite(float(unit[field])): valid_unit = false
			for coordinate: Variant in unit.p:
				if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)): valid_unit = false
			if not valid_unit or int(unit.stage) not in range(4): continue
			installations.append(unit.duplicate(true))
	harvested = safe_dictionary(d,"harvested"); surveyed = safe_dictionary(d,"surveyed"); explored = safe_dictionary(d,"explored"); contracts = safe_dictionary(d,"contracts"); emergencies = safe_dictionary(d,"emergencies"); nodes_revealed = safe_dictionary(d,"nodes_revealed")
	next_id = int(d.get("next_id",1)); tier = clampi(int(d.get("tier",1)),1,3); research = int(d.get("research",0)); water_made = int(d.get("water_made",0)); clock = float(d.get("clock",0))
	if personal: food = clampf(float(d.get("food",100)),0,100); hydration = clampf(float(d.get("hydration",100)),0,100)
	var valid: Dictionary = {}
	for unit: Dictionary in installations: valid[int(unit.id)] = true
	for id: int in actors.keys():
		if not valid.has(id): actors[id].queue_free(); actors.erase(id)
	cable_signature = ""; refresh_actors()

func safe_dictionary(d: Dictionary,key: String) -> Dictionary:
	return d[key] if d.get(key) is Dictionary else {}
