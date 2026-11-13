extends Node3D
const Art = preload("res://scripts/field_hardware.gd")
var expedition: Node
var links: Array[Dictionary] = []
var visuals: Array[Node3D] = []
var first_anchor := -1
var active_link := -1
var progress := 0.0

func setup(game: Node) -> void:
	expedition = game; name = "TraversalLines"

func point(a: Array) -> Vector3:
	return Vector3(float(a[0]),float(a[1]),float(a[2]))

func nearest_anchor(p: Vector3) -> Dictionary:
	for unit: Dictionary in expedition.outpost.installations:
		if unit.kind in ["anchor","winch"] and unit.stage==3 and expedition.outpost.position_of(unit).distance_to(p)<4: return unit
	return {}

func deploy() -> void:
	var p: Vector3 = expedition.stream.logical(expedition.player.position)
	var anchor := nearest_anchor(p)
	if first_anchor<0:
		if anchor.is_empty(): expedition.toast("Approach an assembled climbing anchor or winch. B deploys purchased anchor kits."); return
		first_anchor = int(anchor.id); expedition.toast("ROPE START / approach a second anchor and press Z, or aim at a landing below and press Z."); return
	var start: Dictionary = expedition.outpost.unit_by_id(first_anchor)
	if start.is_empty(): first_anchor = -1; return
	var a: Vector3 = expedition.outpost.position_of(start)+Vector3.UP*1.6
	var b := Vector3.ZERO; var second_id := -1
	if not anchor.is_empty() and int(anchor.id)!=first_anchor: b = expedition.outpost.position_of(anchor)+Vector3.UP*1.6; second_id = int(anchor.id)
	else:
		var camera: Camera3D = expedition.player.camera; var middle: Vector2 = get_viewport().get_visible_rect().size*.5
		var from := camera.project_ray_origin(middle); var query := PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(middle)*60)
		query.exclude = [expedition.player.get_rid()]
		var hit: Dictionary = expedition.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): expedition.toast("Aim at solid landing ground within rope range, or use a second assembled anchor."); return
		b = expedition.stream.logical(hit.position)+Vector3.UP*1.6
	if expedition.lan_active() and not expedition.lan.is_host:
		expedition.lan.request_rope.rpc_id(1,first_anchor,second_id,[b.x,b.y,b.z]); first_anchor = -1; return
	var result := create_link(first_anchor,second_id,b,p)
	expedition.toast(result); first_anchor = -1
	if expedition.lan_active(): expedition.lan.broadcast_progress()

func create_link(first: int,second: int,end: Vector3,p: Vector3) -> String:
	var a_unit: Dictionary = expedition.outpost.unit_by_id(first)
	if a_unit.is_empty() or a_unit.stage!=3 or a_unit.kind not in ["anchor","winch"]: return "Invalid belay anchor"
	var a: Vector3 = expedition.outpost.position_of(a_unit)+Vector3.UP*1.6
	if p.distance_to(a)>65: return "Move within rope-working range of the anchor"
	var b := end
	if second>=0:
		var b_unit: Dictionary = expedition.outpost.unit_by_id(second)
		if b_unit.is_empty() or b_unit.stage!=3 or b_unit.kind not in ["anchor","winch"] or p.distance_to(expedition.outpost.position_of(b_unit))>5: return "Approach the destination anchor"
		b = expedition.outpost.position_of(b_unit)+Vector3.UP*1.6
	if not b.is_finite(): return "Invalid rope endpoint"
	var distance := a.distance_to(b)
	if distance<3 or distance>60: return "Rope routes must span 3–60m"
	if second<0:
		if p.distance_to(a)>5: return "Stand beside the start anchor for a free-hanging rope"
		var landing: float = expedition.stream.surface(b.x,b.z)+1.6
		var cave_data: Dictionary = expedition.field.cave_info(b)
		if absf(b.y-landing)>2 and (cave_data.is_empty() or absf(b.y-float(cave_data.floor)-1.6)>2): return "The rope must terminate at a verified landing surface"
	var rope := "rope30" if distance<=30 and int(expedition.outpost.cargo.kits.get("rope30",0))>0 else "rope60"
	if int(expedition.outpost.cargo.kits.get(rope,0))<1: return "Purchase a rope long enough for this route"
	for link: Dictionary in links:
		if point(link.a).distance_to(a)<1 and point(link.b).distance_to(b)<1: return "Route already installed"
	var bridge_sku: String = expedition.outpost.stock_family("ropebridge")
	var rating: float = expedition.outpost.spec(a_unit).get("capacityFactor",1)
	var bridge := second>=0 and distance<=minf(36,36*rating) and absf(a.y-b.y)<12 and bridge_sku!=""
	expedition.outpost.cargo.kits[rope] -= 1
	if bridge: expedition.outpost.cargo.kits[bridge_sku] -= 1
	links.append({"a":[a.x,a.y,a.z],"b":[b.x,b.y,b.z],"bridge":bridge,"anchor":first,"second":second})
	rebuild(); expedition.checkpoint()
	return "SUSPENSION WALKWAY INSTALLED" if bridge else "STATIC ROPE INSTALLED / approach the line and press X with a harness"

func attached() -> bool:
	return active_link>=0 and active_link<links.size()

func toggle_attach() -> void:
	if attached(): active_link = -1; expedition.player.rope_control = false; expedition.toast("BELAY RELEASED / check your footing"); return
	if int(expedition.outpost.cargo.kits.get("harness",0))<1: expedition.toast("A rated harness is required to attach"); return
	var p: Vector3 = expedition.stream.logical(expedition.player.position)+Vector3.UP*1.2
	for i: int in range(links.size()):
		var a := point(links[i].a); var b := point(links[i].b); var t := clampf((p-a).dot(b-a)/a.distance_squared_to(b),0,1)
		if p.distance_to(a.lerp(b,t))<2.3:
			active_link = i; progress = t; expedition.player.rope_control = true; expedition.toast("BELAY ATTACHED / W ascends toward the first anchor; S descends. X releases."); return
	expedition.toast("Approach a placed rope to attach")

func tick(delta: float) -> void:
	if not attached(): return
	var player: CharacterBody3D = expedition.player
	if not player.enabled: player.rope_velocity = Vector3.ZERO; return
	var a := point(links[active_link].a); var b := point(links[active_link].b)
	var axis := Input.get_axis("forward","backward")
	var speed := 1.4 if int(expedition.outpost.cargo.kits.get("ascender",0))>0 else .75
	progress = clampf(progress+axis*delta*speed/a.distance_to(b),0,1)
	var goal: Vector3 = expedition.stream.local(a.lerp(b,progress))+Vector3(.7,-1.2,0)
	player.rope_velocity = (goal-player.position).limit_length(speed*delta*1.3)/maxf(delta,.001)
	if progress>=.999 or progress<=.001: expedition.field.stamina = minf(100,expedition.field.stamina+delta)

func bridge_height_allowed(p: Vector3) -> bool:
	for link: Dictionary in links:
		if not link.bridge: continue
		var a := point(link.a); var b := point(link.b); var t := clampf((p-a).dot(b-a)/a.distance_squared_to(b),0,1)
		if p.distance_to(a.lerp(b,t)-Vector3.UP*1.2)<3: return true
	return false

func near_line(p: Vector3) -> bool:
	for link: Dictionary in links:
		var a := point(link.a); var b := point(link.b); var t := clampf((p+Vector3.UP*1.2-a).dot(b-a)/a.distance_squared_to(b),0,1)
		if (p+Vector3.UP*1.2).distance_to(a.lerp(b,t))<2.5: return true
	return false

func rebuild() -> void:
	for visual: Node3D in visuals: visual.queue_free()
	visuals.clear()
	for link: Dictionary in links:
		var a: Vector3 = expedition.stream.local(point(link.a)); var b: Vector3 = expedition.stream.local(point(link.b))
		var root := Node3D.new(); add_child(root); visuals.append(root)
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var material: StandardMaterial3D = expedition.world.mat(Color("b69b66"),.4); material.cull_mode = BaseMaterial3D.CULL_DISABLED; st.set_material(material)
		var direction := b-a; var right := direction.cross(Vector3.UP).normalized()
		if right.length()<.5: right = Vector3.RIGHT
		for i: int in range(24):
			var t0 := i/24.; var t1 := (i+1)/24.
			var sag0 := sin(t0*PI)*(minf(1.3,direction.length()*.025) if link.bridge else .08); var sag1 := sin(t1*PI)*(minf(1.3,direction.length()*.025) if link.bridge else .08)
			var p0 := a.lerp(b,t0)-Vector3.UP*sag0; var p1 := a.lerp(b,t1)-Vector3.UP*sag1
			var width := .7 if link.bridge else .035
			var floor0 := p0-Vector3.UP*1.2 if link.bridge else p0; var floor1 := p1-Vector3.UP*1.2 if link.bridge else p1
			for v: Vector3 in [floor0-right*width,floor1-right*width,floor1+right*width,floor0-right*width,floor1+right*width,floor0+right*width]: st.add_vertex(v)
			if link.bridge:
				for side: float in [-1.,1.]:
					for v: Vector3 in [p0+right*side*.7,p1+right*side*.7,p1+right*side*.7+Vector3.UP*.035,p0+right*side*.7,p1+right*side*.7+Vector3.UP*.035,p0+right*side*.7+Vector3.UP*.035]: st.add_vertex(v)
		st.generate_normals(); var mesh := MeshInstance3D.new(); mesh.mesh = st.commit(); root.add_child(mesh)
		if link.bridge:
			mesh.create_trimesh_collision()
			for child: Node in mesh.get_children():
				if child is StaticBody3D:
					child.collision_layer = 5
					for collision: Node in child.get_children():
						if collision is CollisionShape3D and collision.shape is ConcavePolygonShape3D: collision.shape.backface_collision = true

func snapshot() -> Dictionary:
	return {"links":links}

func restore(d: Dictionary) -> void:
	if d.get("links",[])==links: return
	links.clear(); active_link = -1; expedition.player.rope_control = false
	for link: Variant in d.get("links",[]):
		if link is Dictionary and link.get("a") is Array and link.get("b") is Array and link.a.size()==3 and link.b.size()==3: links.append(link)
	rebuild()
