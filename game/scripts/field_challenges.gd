extends Node3D
const Atlas = preload("res://scripts/mars_atlas.gd")
var expedition: Node
var completed: Dictionary = {}
var returning: Dictionary = {}
var stamina := 100.0
var cold := 0.0
var dust := 0.0
var exposure := 0.0
var scan := 0.0
var active_key := ""
var warning := ""
var rock_timer := 0.0
var last_rock_block := -1
var light: SpotLight3D
var cave_environment: Environment
var fog_multiplier := 1.0
var return_timer := 0.0
var filter_load := 0.0
var route: Array = []

func setup(game: Node) -> void:
	expedition = game; name = "FieldChallenges"
	light = SpotLight3D.new(); expedition.player.camera.add_child(light); light.light_color = Color("d0e6ed"); light.light_energy = 2.5; light.spot_range = 25; light.spot_angle = 45; light.shadow_enabled = true; light.hide()
	cave_environment = game.world.environment_resource.duplicate(true); cave_environment.ambient_light_energy = .025; cave_environment.fog_enabled = false
	for chunk: Node3D in game.stream.chunks.values(): decorate(chunk,chunk.get_meta("site").cell)

func profile_at(p: Vector3) -> Dictionary:
	var cell: Vector2i = expedition.stream.cell_at(p)
	return Atlas.profile(expedition.world.world_seed,cell,expedition.stream.kind_at(cell))

func cave_info(p: Vector3) -> Dictionary:
	var cell: Vector2i = expedition.stream.cell_at(p)
	if expedition.stream.is_base(cell): return {}
	var profile := profile_at(p)
	if not profile.cave or not Atlas.in_cave_footprint(p,cell): return {}
	var c := Atlas.cave_centre(cell)
	var entrance: float = expedition.stream.height(c.x,c.y-24)
	var floor_y := entrance-clampf(p.z-(c.y-24),0,48)*.35
	return {"cell":cell,"floor":floor_y,"ceiling":floor_y+5.8,"centre":c}

func inside_cave(p: Vector3) -> bool:
	var info := cave_info(p)
	return not info.is_empty() and p.y>=float(info.floor)-1 and p.y<float(info.ceiling)-.2

func floor_for(p: Vector3,observer: Vector3) -> float:
	var info := cave_info(p)
	if inside_cave(observer) and not info.is_empty(): return float(info.floor)
	return expedition.stream.surface(p.x,p.z)

func allowed_height(p: Vector3) -> bool:
	var info := cave_info(p)
	return not info.is_empty() and p.y>=float(info.floor)-2 and p.y<=float(info.ceiling)

func target_for(cell: Vector2i) -> Vector3:
	var c := Atlas.cave_centre(cell); var p := Vector3(c.x,0,c.y+12)
	p.y = expedition.stream.surface(p.x,p.z)
	var info := cave_info(p)
	if not info.is_empty(): p.y = float(info.floor)
	return p

func decorate(chunk: Node3D,cell: Vector2i) -> void:
	if chunk.has_meta("atlas"): return
	var profile: Dictionary = Atlas.profile(expedition.world.world_seed,cell,expedition.stream.kind_at(cell)); chunk.set_meta("atlas",profile)
	if expedition.stream.is_base(cell): return
	if profile.cave: build_cave(chunk,cell)
	var target := target_for(cell)
	var label := Label3D.new(); chunk.add_child(label); label.position = target-Vector3(cell.x*256,0,cell.y*256)+Vector3(0,2.5,0); label.text = "%s\nT / %s" % [profile.name,Atlas.TASKS[profile.task]]; label.font_size = 23; label.pixel_size = .007; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.modulate = Color("dac5a2"); label.visibility_range_end = 60
	var flag: MeshInstance3D = expedition.world.cylinder(target-Vector3(cell.x*256,0,cell.y*256)+Vector3(1,.8,0),.025,1.6,expedition.world.mat(Color("d0ad72")),chunk)
	flag.set_meta("field_goal",true)

func build_cave(chunk: Node3D,cell: Vector2i) -> void:
	var centre := Atlas.cave_centre(cell); var entrance: float = expedition.stream.height(centre.x,centre.y-24)
	var floor_mesh := SurfaceTool.new(); floor_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shell := SurfaceTool.new(); shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := SurfaceTool.new(); top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset := Vector3(cell.x*256,0,cell.y*256)
	for step: int in range(12):
		var z0 := centre.y-24+step*4; var z1 := z0+4
		var y0 := entrance-step*4*.35; var y1 := y0-1.4
		quad(floor_mesh,Vector3(centre.x-8,y0,z0)-offset,Vector3(centre.x-8,y1,z1)-offset,Vector3(centre.x+8,y1,z1)-offset,Vector3(centre.x+8,y0,z0)-offset)
		for side: float in [-1.,1.]: quad(shell,Vector3(centre.x+side*8,y0,z0)-offset,Vector3(centre.x+side*8,y0+2,z0)-offset,Vector3(centre.x+side*8,y1+2,z1)-offset,Vector3(centre.x+side*8,y1,z1)-offset)
		for segment: int in range(12):
			var a := segment*PI/12; var b := (segment+1)*PI/12
			quad(shell,Vector3(centre.x+cos(a)*8,y0+2+sin(a)*3.8,z0)-offset,Vector3(centre.x+cos(b)*8,y0+2+sin(b)*3.8,z0)-offset,Vector3(centre.x+cos(b)*8,y1+2+sin(b)*3.8,z1)-offset,Vector3(centre.x+cos(a)*8,y1+2+sin(a)*3.8,z1)-offset)
		if step>=3:
			for x_step: int in range(2):
				var x0 := centre.x-8+x_step*8; var x1 := x0+8
				quad(top,Vector3(x0,expedition.stream.height(x0,z0),z0)-offset,Vector3(x0,expedition.stream.height(x0,z1),z1)-offset,Vector3(x1,expedition.stream.height(x1,z1),z1)-offset,Vector3(x1,expedition.stream.height(x1,z0),z0)-offset)
	quad(shell,Vector3(centre.x-8,entrance-16.8,centre.y+24)-offset,Vector3(centre.x-8,entrance-11,centre.y+24)-offset,Vector3(centre.x+8,entrance-11,centre.y+24)-offset,Vector3(centre.x+8,entrance-16.8,centre.y+24)-offset)
	var material: StandardMaterial3D = expedition.world.geological_material(Color("574e49")); material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for pair: Array in [[floor_mesh,true],[shell,false],[top,true]]:
		var st: SurfaceTool = pair[0]; st.generate_normals(); st.set_material(material)
		var mesh := MeshInstance3D.new(); mesh.mesh = st.commit(); chunk.add_child(mesh); mesh.create_trimesh_collision()
		for child: Node in mesh.get_children():
			if child is StaticBody3D:
				child.set_meta("ground",pair[1])
				for collision: Node in child.get_children():
					if collision is CollisionShape3D and collision.shape is ConcavePolygonShape3D: collision.shape.backface_collision = true

func quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	for p: Vector3 in [a,c,b,a,d,c]: st.add_vertex(p)

func owned(id: String) -> bool:
	return int(expedition.outpost.cargo.kits.get(id,0))>0

func tick(delta: float) -> void:
	var p: Vector3 = expedition.stream.logical(expedition.player.position); var profile := profile_at(p)
	var cave := inside_cave(p); warning = ""
	fog_multiplier = [1.,1.15,.85,1.2,1.,1.5,1.,2.,1.1][int(profile.condition)]
	expedition.player.camera.environment = cave_environment if cave else null
	light.visible = owned("headlamp") and (cave or expedition.weather.state in ["COLD TWILIGHT","FROST HAZE","LOCAL DUST FRONT"])
	var safe: bool = expedition.sheltered()
	var sprint: bool = Input.is_action_pressed("sprint") and expedition.player.velocity.length()>1
	stamina = clampf(stamina+delta*(-1.8 if sprint else 1.5),0,100)
	if expedition.weather.temperature_c < -50 and not safe:
		cold += delta*(.035 if owned("thermal_liner") or expedition.model.pack.has("thermal") else .3)*(1.6 if profile.condition==3 else (1.3 if profile.condition==8 else 1.0))
	else: cold = maxf(0,cold-delta*.5)
	dust = maxf(0,dust+delta*(expedition.weather.severity+(.2 if profile.condition==5 else 0))*(.025 if owned("dust_filter") else .12)*(1.4 if profile.condition==1 else (.6 if profile.condition==2 else 1.0)))
	if owned("dust_filter"):
		filter_load += delta*expedition.weather.severity*.5
		if filter_load>=100: expedition.outpost.cargo.kits.dust_filter -= 1; filter_load = 0; expedition.toast("DUST FILTER EXHAUSTED / replace it before another exposure")
	if owned("navigation") and (route.is_empty() or Vector3(route[-1][0],route[-1][1],route[-1][2]).distance_to(p)>24):
		route.append([p.x,p.y,p.z])
		if route.size()>2048: route.pop_front()
	var exposure_rate := .018*(1+float(profile.condition==6))
	if safe or cave or owned("radiation_liner"): exposure_rate *= .15
	exposure = clampf(exposure+delta*exposure_rate,0,100)
	if safe: dust = maxf(0,dust-delta*.08)
	if cold>80: expedition.model.integrity = maxf(0,expedition.model.integrity-delta*.45); warning = "THERMAL LIMIT / seek shelter or a thermal liner"
	if dust>70: expedition.model.oxygen = maxf(0,expedition.model.oxygen-delta*.15); warning = "SEAL CONTAMINATION / use a dust-service station"
	if exposure>80: expedition.model.integrity = maxf(0,expedition.model.integrity-delta*.3); warning = "EXPOSURE LIMIT / seek a refuge or cave"
	var slope: Vector2 = Vector2(expedition.stream.surface(p.x+1,p.z)-expedition.stream.surface(p.x-1,p.z),expedition.stream.surface(p.x,p.z+1)-expedition.stream.surface(p.x,p.z-1))*.5
	if not cave and slope.length()>.55 and not expedition.traversal.attached():
		stamina = maxf(0,stamina-delta*4); warning = "STEEP / harness, anchors and ropes recommended • falls can end the campaign"
	if cave and not owned("headlamp"): warning = "CAVE DARKNESS / a headlamp and route recorder are strongly recommended"
	if stamina<10: expedition.player.speed_multiplier *= .6
	var cell: Vector2i = expedition.stream.cell_at(p); var target := target_for(cell); var key: String = expedition.stream.key(cell)+"/"+str(profile.landform)+"/"+str(profile.task)
	if p.distance_to(target)<5 and not completed.has(key):
		var requirement := requirement_for(profile)
		warning = "HOLD T / "+Atlas.TASKS[profile.task]+(" / "+requirement if requirement!="" else "")
		if Input.is_physical_key_pressed(KEY_T) and requirement=="" and expedition.model.battery>=8:
			scan += delta
			if scan>=3: submit_feature(key,profile,p); scan = 0
		else: scan = 0
	else: scan = 0
	if warning=="" and owned("lidar"): warning = "LIDAR / local slope %.0f° • %s" % [rad_to_deg(atan(slope.length())),"SUBSURFACE VOID" if cave else "SURFACE RELIEF"]
	return_timer += delta
	if (safe or expedition.at_main_habitat()) and not returning.is_empty() and return_timer>2:
		return_timer = 0
		if expedition.lan_active() and not expedition.lan.is_host: expedition.lan.request_field_return.rpc_id(1)
		else: complete_returns(1)
	var block := int(expedition.model.elapsed/70)
	if block!=last_rock_block and not expedition.stream.is_base(cell) and (profile.landform in [7,14,21,26,29] or profile.condition==4) and expedition.model.elapsed>80:
		last_rock_block = block; rock_timer = 3; expedition.toast("ROCKFALL WARNING / leave the unstable slope. Listen for the impact cue.")
	if rock_timer>0:
		rock_timer -= delta
		if rock_timer<=0: spawn_rockfall()

func requirement_for(profile: Dictionary) -> String:
	match int(profile.task):
		0: return "Requires a spectrometer architecture" if not expedition.Model.LOADOUTS[expedition.model.loadout].spectrometer else ""
		1: return "Requires a drill architecture" if not expedition.Model.LOADOUTS[expedition.model.loadout].drill else ""
		4:
			for u: Dictionary in expedition.outpost.installations:
				if u.kind=="seismic" and u.online and expedition.outpost.position_of(u).distance_to(expedition.stream.logical(expedition.player.position))<30: return ""
			return "Place a powered seismic anchor within 30m"
		6: return "Requires harness and a placed rope" if not owned("harness") or expedition.traversal.links.is_empty() else ""
		7: return "Requires a sterile sample container" if not owned("sample_container") else ""
	return ""

func submit_feature(key: String,profile: Dictionary,p: Vector3,owner := 1) -> void:
	if expedition.lan_active() and not expedition.lan.is_host:
		expedition.lan.request_field_feature.rpc_id(1,key); return
	if completed.has(key): return
	completed[key] = true; expedition.model.battery -= 8
	if profile.task==7:
		expedition.outpost.cargo.kits.sample_container -= 1; returning[key] = owner
	else: expedition.model.science += 35+int(profile.landform%5)*8
	expedition.outpost.cargo.materials.alloy += 2; expedition.outpost.cargo.materials.circuits += 1
	expedition.toast("FIELD DISCOVERY / "+profile.name+"\nNew context archived. Geological interpretation remains a hypothesis.")
	expedition.checkpoint()
	if expedition.lan_active(): expedition.lan.broadcast_progress()

func complete_returns(owner: int) -> void:
	var count := 0
	for key: String in returning.keys():
		if int(returning[key])==owner: count += 1; returning.erase(key)
	if count>0:
		expedition.model.science += count*55; expedition.toast("PROTECTED FIELD CACHE RETURNED / +%d points" % (count*55))
		if expedition.lan_active(): expedition.lan.broadcast_progress()

func spawn_rockfall() -> void:
	for i: int in range(3):
		var rock := RigidBody3D.new(); add_child(rock); rock.gravity_scale = 3.71/9.8; rock.contact_monitor = true; rock.max_contacts_reported = 3
		rock.position = expedition.player.position+Vector3(-6+i*4,7+i, -7)
		var mesh := SphereMesh.new(); mesh.radius = .38; mesh.height = .76; mesh.radial_segments = 8; mesh.rings = 5
		expedition.world.mesh_at(mesh,Vector3.ZERO,expedition.world.rock_mat,rock)
		var collision := CollisionShape3D.new(); var shape := SphereShape3D.new(); shape.radius = .38; collision.shape = shape; rock.add_child(collision)
		rock.body_entered.connect(func(body: Node) -> void:
			if body==expedition.player and rock.linear_velocity.length()>3: expedition.model.integrity = maxf(0,expedition.model.integrity-22))
		get_tree().create_timer(12).timeout.connect(rock.queue_free)

func journal() -> void:
	var v: VBoxContainer = expedition.menu(950)
	var p: Vector3 = expedition.stream.logical(expedition.player.position); var profile := profile_at(p)
	v.add_child(expedition.text("FIELD ATLAS / "+profile.name,26,expedition.MINT))
	v.add_child(expedition.paragraph("32 geological archetypes × 9 operating conditions = 288 place profiles. Eight scientific objectives create 256 landform/objective encounters. These are seeded combinations, with cave, scarp, pit and surface geometry families; they are not 288 separately mapped NASA sites.",18))
	v.add_child(expedition.paragraph("STAMINA %.0f • COLD %.0f • DUST %.0f • EXPOSURE %.0f\nZ places a rope route from an assembled anchor. X attaches/detaches. A harness is required. Two anchors plus a suspension kit make a traversable rope bridge. Headlamps support cave entry. G recovers materials; T records local discoveries.",17,expedition.GOLD))
	var cell: Vector2i = expedition.stream.cell_at(p)
	for offset: Vector2i in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
		var nearby := Atlas.profile(expedition.world.world_seed,cell+offset,expedition.stream.kind_at(cell+offset)); var at := target_for(cell+offset)
		v.add_child(expedition.paragraph("%s • %s • ΔX %+.0fm / ΔZ %+.0fm" % [nearby.name,Atlas.TASKS[nearby.task],at.x-p.x,at.z-p.z],16))
	v.add_child(expedition.action("RETURN TO FIELD",expedition.resume_surface)); expedition.focus_first(v)

func snapshot() -> Dictionary:
	return {"completed":completed,"returning":returning,"stamina":stamina,"cold":cold,"dust":dust,"exposure":exposure,"filter_load":filter_load,"route":route}

func restore(d: Dictionary) -> void:
	completed = d.get("completed",{}); returning = d.get("returning",{}); stamina = float(d.get("stamina",100)); cold = float(d.get("cold",0)); dust = float(d.get("dust",0)); exposure = float(d.get("exposure",0))
	filter_load = float(d.get("filter_load",0)); route = d.get("route",[])
