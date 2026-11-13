extends Node3D
const Atlas = preload("res://scripts/mars_atlas.gd")
## Deterministic streamed extension. Only nearby chunks exist as scene nodes.
const CHUNK := 256.0
const GRID := 33
const RADIUS := 3
const KINDS := ["dunes","basalt","canyon","mesa","highlands","crater"]
const TINTS := [Color("b38b66"),Color("575456"),Color("a36750"),Color("bba98b"),Color("9cabb3"),Color("8c7769")]
var expedition: Node
var origin := Vector2.ZERO
var chunks: Dictionary = {}
var pending: Array[Vector2i] = []
var wanted: Dictionary = {}
var completed: Dictionary = {}
var visited: Dictionary = {}
var salvage := 4
var completed_count := 0
var active: Dictionary = {}
var active_step := 0
var active_time := 0.0
var hold_time := 0.0
var nearest: Dictionary = {}
var remote_focus: Array[Vector3] = []
var last_cell := Vector2i(2147483647,0)
var last_remote_cells := ""
var generation_ms := 0.0
var airlock: Vector3
var job_id := -1
var job_cell := Vector2i.ZERO
var job_mesh: ArrayMesh

func logical(local: Vector3) -> Vector3:
	return local+Vector3(origin.x,0,origin.y)

func local(logical_position: Vector3) -> Vector3:
	return logical_position-Vector3(origin.x,0,origin.y)

func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x/CHUNK),floori(p.z/CHUNK))

func key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x,cell.y]

func seed_at(cell: Vector2i, salt := 0) -> int:
	return (str(expedition.world.world_seed)+":"+key(cell)+":"+str(salt)).hash() & 0x7fffffff

func is_base(cell: Vector2i) -> bool:
	return cell.x >= -3 and cell.x <= 2 and cell.y >= -3 and cell.y <= 2

func kind_at(cell: Vector2i) -> int:
	return Atlas.code(world_seed_value(),Vector2i(floori(cell.x/2.0),floori(cell.y/2.0)),17)%6

func world_seed_value() -> int:
	return int(expedition.world.world_seed)

func corner_height(cell: Vector2i) -> float:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_at(cell,93)
	return rng.randf_range(-18,65)

func height(x: float,z: float) -> float:
	if absf(x) <= 768 and absf(z) <= 768: return expedition.world.elevation(x,z)
	var cell := cell_at(Vector3(x,0,z)); var u := (x-cell.x*CHUNK)/CHUNK; var v := (z-cell.y*CHUNK)/CHUNK
	var su := smoothstep(0,1,u); var sv := smoothstep(0,1,v)
	var low := lerpf(corner_height(cell),corner_height(cell+Vector2i.RIGHT),su)
	var high := lerpf(corner_height(cell+Vector2i.DOWN),corner_height(cell+Vector2i.ONE),su)
	var h := lerpf(low,high,sv)
	# Local detail vanishes at boundaries, guaranteeing identical shared edges.
	var envelope := sin(u*PI)*sin(v*PI)
	match kind_at(cell):
		0: h += envelope*pow((sin(u*TAU*4+sin(v*TAU))+1)*0.5,2)*13
		1: h += envelope*(sin(u*TAU*3)*cos(v*TAU*3)*6+10)
		2: h += envelope*smoothstep(.08,.22,absf(u-.5+sin(v*TAU)*.07))*38
		3: h += envelope*smoothstep(.38,.25,Vector2(u-.5,v-.5).length())*35
		4: h += envelope*(40+sin(u*TAU*2)*7)
		5: h += envelope*(exp(-pow((Vector2(u-.5,v-.5).length()-.3)/.09,2))*30-8)
	h += envelope*envelope*Atlas.relief(expedition.world.world_seed,cell,kind_at(cell),u,v)
	# Crossing lanes and activity centres are deliberately traversable.
	var lane := minf(absf(u-.5),absf(v-.5))*CHUNK
	var baseline := lerpf(lerpf(corner_height(cell),corner_height(cell+Vector2i.RIGHT),su),lerpf(corner_height(cell+Vector2i.DOWN),corner_height(cell+Vector2i.ONE),su),sv)
	h = lerpf(baseline,h,smoothstep(12,40,lane))
	# Measured regional context ends here; smoothly join the synthetic extension.
	var edge := maxf(absf(x),absf(z))-768
	if edge < 192:
		var base: float = expedition.world.elevation(clampf(x,-768,768),clampf(z,-768,768))
		h = lerpf(base,h,smoothstep(0,192,edge))
	return h

func surface(x: float,z: float) -> float:
	if absf(x) <= 768 and absf(z) <= 768: return height(x,z)
	# Match the rendered eight-metre triangles exactly.
	var gx := floorf(x/8)*8; var gz := floorf(z/8)*8; var u := (x-gx)/8; var v := (z-gz)/8
	var a := height(gx,gz); var b := height(gx+8,gz); var c := height(gx,gz+8); var d := height(gx+8,gz+8)
	return a+(b-a)*u+(c-a)*v if u+v <= 1 else d+(c-d)*(1-u)+(b-d)*(1-v)

func site_data(cell: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_at(cell,277)
	var kind := kind_at(cell)
	var types := ["relay","seismic","rescue","sample","solar","parkour","navigation","drill","survey","cache","ice","meteorite"]
	var activity_type: String = types[rng.randi_range(0,types.size()-1)]
	# Starter activity chain is reachable from touchdown, outside the habitat console.
	if cell == Vector2i.ZERO: activity_type = "relay"
	elif cell == Vector2i(0,-1): activity_type = "parkour"
	elif cell == Vector2i(1,0): activity_type = "seismic"
	var p := Vector3(cell.x*CHUNK+128,0,cell.y*CHUNK+128)
	if cell == Vector2i.ZERO: p = Vector3(62,0,65)
	elif cell == Vector2i(0,-1): p = Vector3(60,0,-60)
	p.y = surface(p.x,p.z)
	return {"id":key(cell),"cell":cell,"kind":kind,"type":activity_type,"position":p,"name":activity_type.to_upper()+" / "+key(cell),"reward":18+rng.randi_range(0,16)}

func setup(owner_node: Node) -> void:
	expedition = owner_node
	ensure_near(expedition.player.position,true)

func ensure_near(p: Vector3, immediate := false) -> void:
	var cell := cell_at(logical(p))
	var remote_cells := ""
	for remote: Vector3 in remote_focus: remote_cells += key(cell_at(remote))+";"
	if cell == last_cell and remote_cells == last_remote_cells and not immediate: return
	last_remote_cells = remote_cells
	last_cell = cell; wanted.clear(); pending.clear()
	var focuses: Array[Vector2i] = [cell]
	for remote: Vector3 in remote_focus: focuses.append(cell_at(remote))
	for focus: Vector2i in focuses:
		var radius := RADIUS if focus == cell else 1
		for dz: int in range(-radius,radius+1):
			for dx: int in range(-radius,radius+1): wanted[focus+Vector2i(dx,dz)] = true
	for existing: Vector2i in chunks.keys():
		if not wanted.has(existing):
			chunks[existing].queue_free(); chunks.erase(existing)
	for desired: Vector2i in wanted:
		if not chunks.has(desired): pending.append(desired)
	pending.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.distance_squared_to(cell)<b.distance_squared_to(cell))
	if immediate:
		while not pending.is_empty() and pending[0].distance_to(cell) < 2: spawn_chunk(pending.pop_front())

func spawn_chunk(cell: Vector2i,supplied_mesh: ArrayMesh = null) -> void:
	if chunks.has(cell): return
	var start := Time.get_ticks_usec()
	var root := Node3D.new(); root.name = "Sector_"+key(cell).replace(":","_"); add_child(root)
	root.position = local(Vector3(cell.x*CHUNK,0,cell.y*CHUNK)); chunks[cell] = root
	if not is_base(cell):
		var terrain := MeshInstance3D.new(); terrain.mesh = supplied_mesh if supplied_mesh != null else make_mesh(cell); root.add_child(terrain); terrain.create_trimesh_collision()
		for body: Node in terrain.get_children():
			if body is StaticBody3D: body.set_meta("ground",true)
		decorate(root,cell)
	var site := site_data(cell)
	if not completed.has(site.id): build_site(root,site)
	# One service refuge per chunk keeps arbitrarily long journeys resupplied.
	var pp: Vector3 = site.position+Vector3(12,0,14); pp.y = surface(pp.x,pp.z)
	var service := Node3D.new(); root.add_child(service); service.position = pp-Vector3(cell.x*CHUNK,0,cell.y*CHUNK)
	expedition.world.cylinder(Vector3(0,1.2,0),1.2,2.4,expedition.world.mat(Color("899b9d"),.4),service)
	expedition.world.box(Vector3(0,1.2,-1.15),Vector3(1.2,.8,.12),expedition.world.mat(Color("5da79e")),service)
	label(service,"FIELD SERVICE\nO₂ • POWER • KITS",Vector3(0,3,0),Color("8de0d4"))
	root.set_meta("service",pp); root.set_meta("site",site)
	if is_instance_valid(expedition.outpost): expedition.outpost.decorate_resources(root,cell)
	if is_instance_valid(expedition.field): expedition.field.decorate(root,cell)
	generation_ms = (Time.get_ticks_usec()-start)/1000.0

func make_mesh(cell: Vector2i) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint: Color = TINTS[kind_at(cell)]
	for z: int in range(GRID-1):
		for x: int in range(GRID-1):
			var form: int = Atlas.landform(expedition.world.world_seed,cell,kind_at(cell))
			if form in [9,10,15] and absf(float(x)*8+4-72)<8 and absf(float(z)*8+4-192)<24: continue
			for c: Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
				var px := float(x+c.x)*8; var pz := float(z+c.y)*8
				st.set_color(tint); st.add_vertex(Vector3(px,height(cell.x*CHUNK+px,cell.y*CHUNK+pz),pz))
	st.generate_normals(); st.set_material(expedition.world.ground_mat)
	return st.commit()

func label(parent: Node3D,value: String,p: Vector3,color: Color) -> Label3D:
	var l := Label3D.new(); parent.add_child(l); l.text = value; l.position = p; l.font_size = 25; l.pixel_size = .012; l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = .006; l.visibility_range_end = 75; return l

func decorate(root: Node3D,cell: Vector2i) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_at(cell,332)
	var stone := SphereMesh.new(); stone.radius = 1; stone.height = 2; stone.radial_segments = 8; stone.rings = 5
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = stone; mm.instance_count = 100
	for i: int in range(100):
		var x := rng.randf_range(0,CHUNK); var z := rng.randf_range(0,CHUNK); var s := rng.randf_range(.15,1.8)
		if minf(absf(x-128),absf(z-128)) < 18: s *= .15
		mm.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(rng.randf(),rng.randf()*TAU,0)).scaled(Vector3(s,s*.6,s*.8)),Vector3(x,surface(cell.x*CHUNK+x,cell.y*CHUNK+z)+s*.2,z)))
	var rocks := MultiMeshInstance3D.new(); root.add_child(rocks); rocks.multimesh = mm; rocks.material_override = expedition.world.rock_mat
	for i: int in range(3):
		var x := rng.randf_range(20,90); var z := rng.randf_range(20,90)
		var outcrop: MeshInstance3D = expedition.world.mesh_at(expedition.world.mesa_mesh(seed_at(cell,i)),Vector3(x,surface(cell.x*CHUNK+x,cell.y*CHUNK+z)-8,z),expedition.world.geological_material(TINTS[kind_at(cell)]),root)
		outcrop.scale = Vector3.ONE*rng.randf_range(.3,.8); outcrop.create_trimesh_collision()

func build_site(root: Node3D,site: Dictionary) -> void:
	var node := Node3D.new(); node.name = "Activity"; root.add_child(node)
	node.position = site.position-Vector3(site.cell.x*CHUNK,0,site.cell.y*CHUNK)
	var w: Node3D = expedition.world; var dark: Material = w.mat(Color("263b43"),.4); var metal: Material = w.mat(Color("b49b78"),.6)
	label(node,site.name,Vector3(0,4,0),Color("eec393"))
	match str(site.type):
		"relay", "seismic", "survey", "navigation":
			w.cylinder(Vector3(0,2,0),.08,4,metal,node)
			var dish: MeshInstance3D = w.cylinder(Vector3(0,3.8,0),1,.16,dark,node); dish.rotation.x = .6
			w.box(Vector3(0,.6,0),Vector3(1.4,1.2,1.1),metal,node)
		"rescue":
			var vehicle: Node3D = expedition.rover.get_child(0).duplicate(); node.add_child(vehicle); vehicle.rotation.z = .06
			var block := StaticBody3D.new(); node.add_child(block)
			var collision := CollisionShape3D.new(); var bounds := BoxShape3D.new(); bounds.size = Vector3(2.1,2.6,3.8); collision.shape = bounds; collision.position.y = 1.4; block.add_child(collision)
		"solar":
			for z: float in [-2.,0.,2.]:
				var panel: MeshInstance3D = w.box(Vector3(0,.9,z),Vector3(3,.12,1.7),w.mat(Color("2a4b64"),.5),node); panel.rotation.z = .15
		"parkour":
			var first: Vector3 = course_point(site,0)-site.position
			# An access ramp reaches a level course even over uneven ground.
			var ramp_start := Vector3(first.x,0,7)
			ramp_start.y = surface(site.position.x+ramp_start.x,site.position.z+ramp_start.z)-site.position.y
			var ramp_mid := (ramp_start+first)*.5
			var ramp: MeshInstance3D = w.box(ramp_mid-Vector3(0,.18,0),Vector3(2.6,.36,ramp_start.distance_to(first)+2),metal,node)
			ramp.rotation.x = atan2(first.y-ramp_start.y,ramp_start.z-first.z); ramp.create_trimesh_collision()
			for i: int in range(7):
				var p: Vector3 = course_point(site,i)-site.position
				var platform: MeshInstance3D = w.box(p-Vector3(0,.2,0),Vector3(2.2,.4,2.2),metal,node); platform.create_trimesh_collision()
				label(node,str(i+1),p+Vector3(0,1,0),Color("8de0d4"))
		_:
			var rock := SphereMesh.new(); rock.radius = 1; rock.height = 1.5; rock.radial_segments = 10
			w.mesh_at(rock,Vector3(0,.6,0),w.geological_material(TINTS[int(site.kind)]),node)
			w.box(Vector3(1.5,.4,0),Vector3(.8,.8,.8),metal,node)
	# Common field hardware: readable work lights, secured cases and telemetry.
	for side: float in [-1.,1.]:
		w.cylinder(Vector3(side*2.5,.7,1.8),.035,1.4,dark,node)
		w.box(Vector3(side*2.5,1.4,1.8),Vector3(.3,.12,.16),w.mat(Color("81b9b0")),node)
	var case_mesh: MeshInstance3D = w.box(Vector3(2.5,.25,1),Vector3(.9,.5,.6),dark,node)
	for x: float in [2.2,2.8]: w.box(Vector3(x,.27,1),Vector3(.05,.51,.62),metal,node)
	case_mesh.create_trimesh_collision()

func course_point(site: Dictionary,i: int) -> Vector3:
	var p: Vector3 = site.position+Vector3(sin(i*1.3)*2,0,-4-i*3.0)
	var base: float = site.position.y
	for step: int in range(7):
		base = maxf(base,surface(site.position.x+sin(step*1.3)*2,site.position.z-4-step*3))
	p.y = base+.45+(i%3)*.35
	return p

func tick(delta: float) -> void:
	ensure_near(expedition.player.position)
	pump_generation()
	rebase()
	nearest = {}; var distance := 6.0; airlock = Vector3.INF
	var p := logical(expedition.player.position)
	for root: Node3D in chunks.values():
		var service: Vector3 = root.get_meta("service",Vector3.INF)
		if p.distance_to(service) < 8: airlock = local(service)
		var site: Dictionary = root.get_meta("site",{})
		if site.is_empty() or completed.has(site.id): continue
		var d: float = p.distance_to(site.position)
		if d < distance: distance = d; nearest = site
	var cell := cell_at(p)
	visited[key(cell)] = true
	if not active.is_empty():
		active_time += delta
		if active.type == "parkour":
			if active_time > 150: cancel("COURSE EXPIRED / restart at its beacon")
			elif not expedition.driving and p.distance_to(course_point(active,active_step)) < 1.8 and expedition.player.is_on_floor():
				active_step += 1; expedition.tone(640+active_step*35,.06)
				if active_step >= 7: finish_activity()
		elif active.type in ["seismic","survey","navigation"]:
			var angle := active_step*TAU/3
			var destination: Vector3 = active.position+Vector3(cos(angle)*22,0,sin(angle)*22); destination.y = surface(destination.x,destination.z)
			if p.distance_to(destination) < 4 and Vector2(expedition.player.velocity.x,expedition.player.velocity.z).length()<.6:
				hold_time += delta
				if hold_time >= 2:
					hold_time = 0; active_step += 1; expedition.tone(760,.08)
					if active_step >= 3: finish_activity()
			else: hold_time = 0
		elif active.type == "rescue":
			if active_step == 1 and p.distance_to(active.position) > 35 and is_sheltered(): finish_activity()
		elif active.type == "sample":
			if active_step == 1 and is_sheltered(): finish_activity()

func is_sheltered() -> bool:
	return airlock != Vector3.INF

func activity_prompt() -> String:
	if not active.is_empty():
		match str(active.type):
			"parkour": return "COURSE %d/7 • %ds / land on numbered platforms on foot" % [active_step+1,150-active_time]
			"seismic","survey","navigation":
				var angle := active_step*TAU/3; var p: Vector3 = active.position+Vector3(cos(angle)*22,0,sin(angle)*22)
				var delta := p-logical(expedition.player.position)
				return "SURVEY %d/3 • station ΔX %+.0fm ΔZ %+.0fm / stand still 2s" % [active_step+1,delta.x,delta.z]
			"sample": return "SEALED SAMPLE / carry to any FIELD SERVICE pod • F to cancel"
			"rescue": return "ROVER RECOVERED / move >35m to another FIELD SERVICE pod"
		return "F / continue "+str(active.name)
	if not nearest.is_empty(): return "F / "+str(nearest.name)+" • J mission journal"
	return ""

func interact() -> void:
	if not active.is_empty():
		if active.type in ["sample","rescue"]: cancel("ACTIVITY CANCELLED / supplies retained where applicable")
		return
	if nearest.is_empty(): expedition.toast("Approach a gold activity beacon. J opens the field journal."); return
	active = nearest.duplicate(); active_step = 0; active_time = 0; hold_time = 0
	if expedition.lan_active() and not expedition.lan.is_host: expedition.lan.begin_activity.rpc_id(1,active.cell)
	match str(active.type):
		"parkour": expedition.set_driving(false); expedition.toast("LOW-G COURSE / Land on platforms 1–7 in order. 150 seconds.")
		"seismic","survey","navigation": expedition.toast("THREE-STATION TRANSECT / follow the journal compass. Dwell 2s at each station.")
		"relay","solar","rescue": expedition.activity_console(active)
		"drill","ice":
			if not expedition.model.LOADOUTS[expedition.model.loadout].drill: cancel("This activity requires a drill architecture.")
			elif expedition.model.battery < 10: cancel("Need 10 battery for coring.")
			else: expedition.activity_console(active)
		"sample": active_step = 1; expedition.toast("SAMPLE SEALED / carry to a FIELD SERVICE pod.")
		_: expedition.activity_console(active)

func finish_activity() -> void:
	if active.is_empty(): return
	if completed.has(active.id): active = {}; return
	if expedition.lan_active() and not expedition.lan.is_host:
		expedition.lan.finish_activity.rpc_id(1); active = {}; expedition.toast("Activity submitted to the host for verification."); return
	completed[active.id] = true; completed_count += 1; salvage += 2
	expedition.model.science += int(active.reward)
	expedition.model.log.append("Field activity completed: "+str(active.name))
	var cell: Vector2i = active.cell
	if chunks.has(cell):
		var visual: Node = chunks[cell].get_node_or_null("Activity")
		if visual: visual.queue_free()
	expedition.toast("ACTIVITY COMPLETE / +%d science • +2 spares" % int(active.reward))
	active = {}; expedition.checkpoint()
	if expedition.lan_active(): expedition.lan.broadcast_progress()

func cancel(message: String) -> void:
	active = {}; hold_time = 0; expedition.toast(message)

func rebase() -> void:
	var p: Vector3 = expedition.player.position
	if maxf(absf(p.x),absf(p.z)) < 1536: return
	var shift := Vector3(floorf(p.x/CHUNK)*CHUNK,0,floorf(p.z/CHUNK)*CHUNK)
	origin += Vector2(shift.x,shift.z)
	expedition.player.position -= shift; expedition.player.reset_physics_interpolation()
	expedition.world.position -= shift
	for root: Node3D in chunks.values(): root.position -= shift
	if expedition.lan_active(): expedition.lan.shift_remotes(shift)
	if is_instance_valid(expedition.traversal):
		for visual: Node3D in expedition.traversal.visuals: visual.position -= shift
	if is_instance_valid(expedition.outpost): expedition.outpost.refresh_actors()
	expedition.player.update_camera_rig()

func snapshot() -> Dictionary:
	return {"completed":completed,"visited":visited,"salvage":salvage,"count":completed_count,"origin":[origin.x,origin.y]}

func restore(d: Dictionary) -> void:
	completed = d.get("completed",{}); visited = d.get("visited",{}); salvage = maxi(0,int(d.get("salvage",4))); completed_count = completed.size()
	active = {}

func pump_generation() -> void:
	if job_id >= 0 and WorkerThreadPool.is_task_completed(job_id):
		WorkerThreadPool.wait_for_task_completion(job_id); job_id = -1
		if wanted.has(job_cell): spawn_chunk(job_cell,job_mesh)
		job_mesh = null
	if job_id < 0 and not pending.is_empty():
		var next: Vector2i = pending.pop_front()
		if chunks.has(next): return
		if is_base(next): spawn_chunk(next)
		else:
			job_cell = next
			job_id = WorkerThreadPool.add_task(func() -> void: job_mesh = make_mesh(job_cell),false,"Mars terrain "+key(next))

func _exit_tree() -> void:
	if job_id >= 0: WorkerThreadPool.wait_for_task_completion(job_id)
