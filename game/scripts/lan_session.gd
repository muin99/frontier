extends Node
## Listen-server LAN co-op. No relay, account service, UPnP or external server.
const PORT := 24642
const PROTOCOL := 8
const MAX_CREW := 4
var expedition: Node
var is_host := false
var active := false
var session_ready := false
var peers: Dictionary = {}
var remotes: Dictionary = {}
var missions: Dictionary = {}
var timer := 0.0
var clock := 0.0
var status_text := "OFFLINE"
var last_progress := ""
var session_port := PORT
var assembly_requests: Dictionary = {}
var outpost_limits: Dictionary = {}

func setup(owner_node: Node) -> void:
	expedition = owner_node; name = "LAN"
	if "--lan-host-test" in OS.get_cmdline_user_args() or "--lan-client-test" in OS.get_cmdline_user_args(): session_port = PORT+1
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(func() -> void: hello.rpc_id(1,PROTOCOL))
	multiplayer.connection_failed.connect(func() -> void: close(); expedition.toast("LAN connection failed. Check the host IP, UDP 24642 and private-network firewall access."))
	multiplayer.server_disconnected.connect(func() -> void: close(); expedition.pause_screen(); expedition.toast("HOST DISCONNECTED / local progress retained; host migration is unavailable."))

func host() -> Error:
	close()
	var peer := ENetMultiplayerPeer.new(); var error := peer.create_server(session_port,MAX_CREW-1)
	if error != OK: return error
	multiplayer.multiplayer_peer = peer; is_host = true; active = true; session_ready = true
	status_text = "HOST • UDP %d • 1/%d" % [PORT,MAX_CREW]
	return OK

func join(address: String) -> Error:
	if not address.is_valid_ip_address(): return ERR_INVALID_PARAMETER
	close()
	var peer := ENetMultiplayerPeer.new(); var error := peer.create_client(address,session_port)
	if error != OK: return error
	multiplayer.multiplayer_peer = peer; active = true; session_ready = false; status_text = "CONNECTING " + address
	return OK

func close() -> void:
	active = false; session_ready = false; is_host = false
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for avatar: Node3D in remotes.values(): avatar.queue_free()
	remotes.clear(); peers.clear(); missions.clear(); status_text = "OFFLINE"

func peer_connected(_id: int) -> void:
	if is_host: status_text = "HOST • UDP %d • %d/%d" % [PORT,multiplayer.get_peers().size()+1,MAX_CREW]

func peer_left(id: int) -> void:
	peers.erase(id); missions.erase(id)
	if remotes.has(id): remotes[id].queue_free(); remotes.erase(id)
	expedition.toast("A crew member left the expedition.")

@rpc("any_peer","call_remote","reliable")
func hello(version: int) -> void:
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	if version != PROTOCOL: multiplayer.multiplayer_peer.disconnect_peer(id); return
	peers[id] = {"p":expedition.stream.logical(expedition.player.position)+Vector3(3,0,0),"yaw":0.0,"speed":0.0,"drive":false,"seen":clock,"session_ready":false}
	welcome.rpc_id(id,PROTOCOL,expedition.world.world_seed,expedition.model.loadout,expedition.stream.logical(expedition.player.position),progress_data())

@rpc("authority","call_remote","reliable")
func welcome(version: int,seed_value: int,loadout: int,spawn: Vector3,progress: Dictionary) -> void:
	if is_host or version != PROTOCOL: return
	expedition.regenerate_world(seed_value)
	expedition.selected_seed = seed_value
	expedition.model.configure(loadout,0); expedition.model.transit(true)
	expedition.stream.origin = Vector2(floorf(spawn.x/256)*256,floorf(spawn.z/256)*256)
	expedition.world.position = Vector3(-expedition.stream.origin.x,0,-expedition.stream.origin.y)
	for chunk: Node3D in expedition.stream.chunks.values(): chunk.free()
	expedition.stream.chunks.clear(); expedition.stream.pending.clear()
	expedition.player.position = expedition.stream.local(spawn+Vector3(3,1,0))
	expedition.stream.ensure_near(expedition.player.position,true)
	apply_progress(progress); session_ready = true; status_text = "LAN CREW • HOST CONNECTED"
	expedition.resume_surface(); joined.rpc_id(1)
	expedition.toast("JOINED / shared seed, evidence and activity rewards. Resources remain personal.")

@rpc("any_peer","call_remote","reliable")
func joined() -> void:
	if is_host and peers.has(multiplayer.get_remote_sender_id()): peers[multiplayer.get_remote_sender_id()].session_ready = true

func _physics_process(delta: float) -> void:
	if not active or not session_ready: return
	clock += delta; timer += delta
	if is_host and expedition.model.phase=="SURFACE" and is_instance_valid(expedition.overlay): expedition.model.elapsed += delta
	for id: int in remotes:
		if not peers.has(id): continue
		var state: Dictionary = peers[id]; var avatar: Node3D = remotes[id]
		avatar.position = avatar.position.lerp(expedition.stream.local(state.p),1-exp(-delta*12))
		avatar.rotation.y = lerp_angle(avatar.rotation.y,float(state.yaw),1-exp(-delta*12))
		avatar.animate_motion(delta,float(state.speed))
		avatar.imported_model.visible = not state.get("drive",false)
		avatar.get_node("CrewRover").visible = state.get("drive",false)
	if timer < .1: return
	timer = 0
	var p: Vector3 = expedition.stream.logical(expedition.player.position)
	if is_host:
		var packet := peers.duplicate(true)
		packet[1] = {"p":p,"yaw":expedition.player.rotation.y,"speed":Vector2(expedition.player.velocity.x,expedition.player.velocity.z).length(),"drive":expedition.driving}
		snapshots.rpc(packet,expedition.model.elapsed); apply_states(packet)
		expedition.stream.remote_focus.clear()
		for id: int in peers:
			expedition.stream.remote_focus.append(peers[id].p)
			advance_mission(id,.1)
			if missions.has(id) and missions[id].get("submitted",false): complete_remote_activity(id)
	else:
		movement.rpc_id(1,p,expedition.player.rotation.y,expedition.driving)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func movement(p: Vector3,yaw: float,driving: bool) -> void:
	if not is_host or not p.is_finite() or not is_finite(yaw): return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id) or not peers[id].session_ready: return
	var prior: Dictionary = peers[id]
	var dt := clampf(clock-float(prior.seen),.05,1)
	var distance: float = p.distance_to(prior.p)
	# Host checks displacement and terrain envelope; clients predict for responsiveness.
	var maximum := (18.0 if driving else 7.0)*dt+1.2
	var h: float = expedition.stream.surface(p.x,p.z)
	var alternate: bool = expedition.field.allowed_height(p) or expedition.traversal.bridge_height_allowed(p) or (int(expedition.outpost.cargo.kits.get("harness",0))>0 and expedition.traversal.near_line(p))
	if distance > maximum or ((p.y < h-2 or p.y > h+12) and not alternate):
		correct_position.rpc_id(id,prior.p); prior.seen = clock; return
	peers[id] = {"p":p,"yaw":yaw,"speed":minf(distance/dt,18),"drive":driving,"seen":clock,"session_ready":true}

@rpc("authority","call_remote","unreliable_ordered",1)
func correct_position(p: Vector3) -> void:
	if not session_ready: return
	expedition.player.position = expedition.stream.local(p); expedition.player.velocity = Vector3.ZERO; expedition.player.reset_physics_interpolation()

@rpc("authority","call_remote","unreliable_ordered",1)
func snapshots(states: Dictionary,elapsed: float) -> void:
	if session_ready:
		expedition.model.elapsed = elapsed; apply_states(states)

func apply_states(states: Dictionary) -> void:
	for id: int in states:
		if id == multiplayer.get_unique_id(): continue
		peers[id] = states[id]
		if not remotes.has(id):
			var avatar := preload("res://scripts/humanoid.gd").new(); expedition.add_child(avatar); avatar.build(Color("dbe6e8"),Color("8de0d4"),true)
			avatar.position = expedition.stream.local(states[id].p); remotes[id] = avatar
			var vehicle: Node3D = expedition.rover.duplicate(); vehicle.name = "CrewRover"; avatar.add_child(vehicle); vehicle.position = Vector3.ZERO; vehicle.hide()
			var badge := Label3D.new(); avatar.add_child(badge); badge.text = "CREW "+str(id); badge.position.y = 2.3; badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED; badge.font_size = 25; badge.pixel_size = .01
	for id: int in remotes.keys():
		if not states.has(id): remotes[id].queue_free(); remotes.erase(id); peers.erase(id)

func shift_remotes(shift: Vector3) -> void:
	for avatar: Node3D in remotes.values(): avatar.position -= shift

func progress_data() -> Dictionary:
	return {"samples":expedition.model.samples,"science":expedition.model.science,"completed":expedition.stream.completed,"salvage":expedition.stream.salvage,"elapsed":expedition.model.elapsed,"outpost":expedition.outpost.snapshot(),"field_completed":expedition.field.completed,"field_returning":expedition.field.returning,"ropes":expedition.traversal.snapshot(),"campaign":expedition.campaign.snapshot()}

func broadcast_progress() -> void:
	if is_host: progress_update.rpc(progress_data())

func apply_progress(d: Dictionary) -> void:
	if d.get("field_completed") is Dictionary: expedition.field.completed = d.field_completed
	if d.get("field_returning") is Dictionary: expedition.field.returning = d.field_returning
	if d.get("ropes") is Dictionary: expedition.traversal.restore(d.ropes)
	if d.get("campaign") is Dictionary: expedition.campaign.restore(d.campaign)
	if d.get("outpost") is Dictionary: expedition.outpost.restore(d.outpost,false)
	expedition.model.samples.assign(d.get("samples",[])); expedition.model.science = int(d.get("science",0))
	expedition.model.elapsed = float(d.get("elapsed",expedition.model.elapsed))
	expedition.stream.completed = d.get("completed",{}); expedition.stream.completed_count = expedition.stream.completed.size(); expedition.stream.salvage = int(d.get("salvage",4))
	for chunk: Node3D in expedition.stream.chunks.values():
		var site: Dictionary = chunk.get_meta("site",{})
		if expedition.stream.completed.has(site.get("id","")):
			var visual := chunk.get_node_or_null("Activity")
			if visual: visual.queue_free()

@rpc("authority","call_remote","reliable")
func progress_update(d: Dictionary) -> void:
	apply_progress(d)

@rpc("any_peer","call_remote","reliable")
func request_sample(index: int) -> void:
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id) or index < 0 or index >= expedition.world.beacons.size(): return
	if peers[id].p.distance_to(expedition.world.beacons[index].position) > 6: return
	if expedition.model.collect(index): broadcast_progress()

@rpc("any_peer","call_remote","reliable")
func begin_activity(cell: Vector2i) -> void:
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id): return
	var site: Dictionary = expedition.stream.site_data(cell)
	if peers[id].p.distance_to(site.position) > 7 or expedition.stream.completed.has(site.id): return
	missions[id] = {"site":site,"step":0,"dwell":0.0,"time":clock,"answer":0}

func advance_mission(id: int,delta: float) -> void:
	if not missions.has(id): return
	var task: Dictionary = missions[id]; var site: Dictionary = task.site; var p: Vector3 = peers[id].p
	match str(site.type):
		"parkour":
			if clock-float(task.time)>150: missions.erase(id); return
			if task.step < 7 and not peers[id].drive and p.distance_to(expedition.stream.course_point(site,task.step))<2: task.step += 1
		"seismic","survey","navigation":
			if task.step >= 3: return
			var angle: float = task.step*TAU/3; var goal: Vector3 = site.position+Vector3(cos(angle)*22,0,sin(angle)*22); goal.y = expedition.stream.surface(goal.x,goal.z)
			if p.distance_to(goal)<4 and peers[id].speed<.6: task.dwell += delta
			else: task.dwell = 0.0
			if task.dwell >= 1.8: task.step += 1; task.dwell = 0.0
		"sample","rescue":
			var service_cell: Vector2i = expedition.stream.cell_at(p); var service: Vector3 = expedition.stream.site_data(service_cell).position+Vector3(12,0,14); service.y = expedition.stream.surface(service.x,service.z)
			if p.distance_to(service)<9 and (site.type=="sample" or p.distance_to(site.position)>35): task.step = 1

@rpc("any_peer","call_remote","reliable")
func activity_answer(answer: int) -> void:
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	if not missions.has(id) or answer < 0 or answer > 2: return
	var task: Dictionary = missions[id]
	if peers[id].p.distance_to(task.site.position)>7: return
	var expected: int = expedition.activity_expected(task.site,task.answer)
	if answer == expected: task.answer += 1
	else: task.answer = 0

@rpc("any_peer","call_remote","reliable")
func finish_activity() -> void:
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	if not missions.has(id): return
	missions[id].submitted = true
	complete_remote_activity(id)

func complete_remote_activity(id: int) -> void:
	var task: Dictionary = missions[id]; var site: Dictionary = task.site
	var required := 7 if site.type=="parkour" else (3 if site.type in ["seismic","survey","navigation"] else 1)
	var valid: bool = task.step >= required if site.type in ["parkour","seismic","survey","navigation","sample","rescue"] else task.answer >= 3
	if site.type == "rescue": valid = valid and task.answer >= 3
	if not valid or expedition.stream.completed.has(site.id): return
	expedition.stream.completed[site.id] = true; expedition.stream.completed_count += 1; expedition.stream.salvage += 2; expedition.model.science += int(site.reward)
	missions.erase(id); broadcast_progress()

@rpc("any_peer","call_remote","reliable")
func begin_outpost_assembly(unit_id: int) -> void:
	if not is_host: return
	var sender := multiplayer.get_remote_sender_id()
	if not peers.has(sender): return
	var unit: Dictionary = expedition.outpost.unit_by_id(unit_id)
	if unit.is_empty() or peers[sender].p.distance_to(expedition.outpost.position_of(unit))>float(expedition.outpost.catalog()[unit.kind].radius)+4: return
	assembly_requests[sender] = {"id":unit_id,"began":clock}

@rpc("any_peer","call_remote","reliable")
func request_outpost(action: String,data: Dictionary) -> void:
	if not is_host or expedition.model.phase!="SURFACE": return
	var sender := multiplayer.get_remote_sender_id()
	if not peers.has(sender) or not peers[sender].session_ready: return
	var limiter_key := str(sender)+":"+action
	var interval := 1.5 if action=="gather" else (.85 if action=="service" else .2)
	if clock-float(outpost_limits.get(limiter_key,-10))<interval: return
	outpost_limits[limiter_key] = clock
	var p: Vector3 = peers[sender].p
	var outpost: Node3D = expedition.outpost
	if action=="assemble":
		var requested: Dictionary = assembly_requests.get(sender,{})
		if requested.is_empty() or requested.id!=int(data.get("id",-1)) or clock-float(requested.began)<1.85: return
		var reason: String = outpost.assembly_step(requested.id,p); assembly_requests.erase(sender)
		outpost_response.rpc_id(sender,{"message":"ASSEMBLY STEP COMPLETE" if reason=="" else reason}); broadcast_progress(); return
	if action in ["drink","eat"]:
		var material := "water" if action=="drink" else "rations"
		if int(outpost.cargo.materials[material])<=0: outpost_response.rpc_id(sender,{"message":"No stored "+material}); return
		outpost.cargo.materials[material] -= 1
		outpost_response.rpc_id(sender,{"message":"SUPPLY USED","hydration":35 if action=="drink" else 0,"food":40 if action=="eat" else 0}); broadcast_progress(); return
	if action=="service":
		var amount: float = outpost.draw_oxygen(p,2.8)
		if amount>0: outpost_response.rpc_id(sender,{"oxygen":amount})
		return
	if action=="gear":
		var kind := str(data.get("kind",""))
		if kind not in ["oxygen_bottle","spare_cell","medkit","sealant"] or int(outpost.cargo.kits.get(kind,0))<1: return
		outpost.cargo.kits[kind] -= 1
		outpost_response.rpc_id(sender,{"message":"EVA CONSUMABLE USED","oxygen":45 if kind=="oxygen_bottle" else 0,"battery":35 if kind=="spare_cell" else 0,"integrity":35 if kind=="medkit" else (20 if kind=="sealant" else 0),"dust_clean":40 if kind=="sealant" else 0}); broadcast_progress(); return
	if action=="emergency":
		var cell: Vector2i = expedition.stream.cell_at(p); var key: String = expedition.stream.key(cell)
		var service: Vector3 = expedition.stream.site_data(cell).position+Vector3(12,0,14); service.y = expedition.stream.surface(service.x,service.z)
		if p.distance_to(service)>8 or outpost.emergencies.has(key): return
		outpost.emergencies[key] = true; outpost_response.rpc_id(sender,{"message":"EMERGENCY POD / one shared reserve recovered","oxygen":25.0,"battery":15.0}); broadcast_progress(); return
	var reason: String = outpost.apply_action(action,data,p)
	outpost_response.rpc_id(sender,{"message":"KIT FRAME DEPLOYED / HOLD E TO ASSEMBLE" if reason=="" else reason}); broadcast_progress()

@rpc("authority","call_remote","reliable")
func outpost_response(result: Dictionary) -> void:
	if result.has("message"): expedition.toast(str(result.message))
	if result.has("oxygen"): expedition.model.oxygen = minf(float(expedition.Model.LOADOUTS[expedition.model.loadout].oxygen),expedition.model.oxygen+float(result.oxygen))
	if result.has("battery"): expedition.model.battery = minf(float(expedition.Model.LOADOUTS[expedition.model.loadout].battery),expedition.model.battery+float(result.battery))
	if result.has("food"): expedition.outpost.food = minf(100,expedition.outpost.food+float(result.food))
	if result.has("hydration"): expedition.outpost.hydration = minf(100,expedition.outpost.hydration+float(result.hydration))
	if result.has("integrity"): expedition.model.integrity = minf(100,expedition.model.integrity+float(result.integrity))
	if result.has("dust_clean"): expedition.field.dust = maxf(0,expedition.field.dust-float(result.dust_clean))

@rpc("any_peer","call_remote","reliable")
func request_rope(first: int,second: int,end: Array) -> void:
	if not is_host or end.size()!=3: return
	var sender := multiplayer.get_remote_sender_id()
	if not peers.has(sender): return
	var reason: String = expedition.traversal.create_link(first,second,Vector3(float(end[0]),float(end[1]),float(end[2])),peers[sender].p)
	outpost_response.rpc_id(sender,{"message":reason}); broadcast_progress()

@rpc("any_peer","call_remote","reliable")
func request_field_feature(key: String) -> void:
	if not is_host or expedition.model.phase!="SURFACE": return
	var sender := multiplayer.get_remote_sender_id()
	if not peers.has(sender): return
	var p: Vector3 = peers[sender].p; var cell: Vector2i = expedition.stream.cell_at(p); var profile: Dictionary = expedition.field.profile_at(p)
	var expected: String = expedition.stream.key(cell)+"/"+str(profile.landform)+"/"+str(profile.task)
	if key!=expected or p.distance_to(expedition.field.target_for(cell))>6 or expedition.field.requirement_for(profile)!="": return
	expedition.field.submit_feature(key,profile,p,sender); broadcast_progress()

@rpc("any_peer","call_remote","reliable")
func request_field_return() -> void:
	if not is_host: return
	var sender := multiplayer.get_remote_sender_id()
	if not peers.has(sender): return
	var p: Vector3 = peers[sender].p
	var safe: bool = p.distance_to(expedition.world.habitat)<12 or expedition.outpost.service_available(p)
	if safe: expedition.field.complete_returns(sender)

@rpc("any_peer","call_remote","reliable")
func request_campaign_failure() -> void:
	if not is_host or expedition.model.phase!="SURFACE": return
	if not peers.has(multiplayer.get_remote_sender_id()): return
	expedition.finish(false)

@rpc("authority","call_remote","reliable")
func end_campaign(success: bool,state: Dictionary) -> void:
	expedition.receiving_campaign_end = true; expedition.campaign.restore(state); expedition.campaign.write(); expedition.finish(success); expedition.receiving_campaign_end = false
