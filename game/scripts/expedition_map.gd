extends Control
var expedition: Node
var revealed: Dictionary = {}
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(expedition) or not is_instance_valid(expedition.player) or not is_instance_valid(expedition.stream): return
	var centre := size/2; var scale_factor := size.x/768
	var pos: Vector3 = expedition.stream.logical(expedition.player.position)
	draw_rect(Rect2(Vector2.ZERO,size),Color(.035,.07,.09,.94))
	for i: int in range(1,8):
		var line := float(i)*size.x/8
		draw_line(Vector2(line,0),Vector2(line,size.y),Color(.15,.22,.25))
		draw_line(Vector2(0,line),Vector2(size.x,line),Color(.15,.22,.25))
	var home := centre+(Vector2(0,28)-Vector2(pos.x,pos.z))*scale_factor
	if Rect2(Vector2.ZERO,size).has_point(home): draw_rect(Rect2(home-Vector2(4,4),Vector2(8,8)),Color("f0c389"))
	for i: int in range(expedition.world.beacons.size()):
		var p: Vector3 = expedition.world.beacons[i].position
		if p.distance_to(pos)>300 or (i>=4 and p.distance_to(pos)>100 and not expedition.model.samples.has(i)): continue
		draw_circle(centre+Vector2(p.x-pos.x,p.z-pos.z)*scale_factor,2.5,Color("77908b") if expedition.model.samples.has(i) else Color("7ae2da"))
	for chunk: Node3D in expedition.stream.chunks.values():
		var site: Dictionary = chunk.get_meta("site",{})
		if site.is_empty(): continue
		var p: Vector3 = site.position
		if p.distance_to(pos)<270:
			var at := centre+Vector2(p.x-pos.x,p.z-pos.z)*scale_factor
			draw_circle(at,3,Color("77908b") if expedition.stream.completed.has(site.id) else Color("eec393"))
		var service: Vector3 = chunk.get_meta("service",Vector3.INF)
		if service.distance_to(pos)<270:
			var at := centre+Vector2(service.x-pos.x,service.z-pos.z)*scale_factor
			draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),Color("8de0d4"))
	if expedition.lan_active():
		for state: Dictionary in expedition.lan.peers.values():
			var p: Vector3 = state.p
			if p.distance_to(pos)<300: draw_circle(centre+Vector2(p.x-pos.x,p.z-pos.z)*scale_factor,4,Color("87b9f0"))
	if is_instance_valid(expedition.outpost):
		for unit: Dictionary in expedition.outpost.installations:
			var p: Vector3 = expedition.outpost.position_of(unit)
			if p.distance_to(pos)>300: continue
			var at := centre+Vector2(p.x-pos.x,p.z-pos.z)*scale_factor
			draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),Color("b3a8eb") if unit.online else Color("687d87"))
		for chunk: Node3D in expedition.stream.chunks.values():
			for deposit: Dictionary in chunk.get_meta("outpost_resources",[]):
				var p: Vector3 = deposit.p
				if p.distance_to(pos)<(180 if expedition.field.owned("lidar") else 90) or (p.distance_to(pos)<300 and expedition.outpost.nodes_revealed.has(expedition.stream.key(expedition.stream.cell_at(p)))):
					draw_circle(centre+Vector2(p.x-pos.x,p.z-pos.z)*scale_factor,1.8,Color("caa685"))
	if is_instance_valid(expedition.field) and expedition.field.owned("navigation"):
		var previous := Vector2.INF
		for at: Array in expedition.field.route:
			var p := Vector2(float(at[0])-pos.x,float(at[2])-pos.z)
			if p.length()>350: previous = Vector2.INF; continue
			var here := centre+p*scale_factor
			if previous!=Vector2.INF: draw_line(previous,here,Color("7f9db3"),1.2)
			previous = here
	draw_circle(centre,4,Color.WHITE)
	var yaw: float = expedition.player.camera_yaw
	draw_line(centre,centre+Vector2(-sin(yaw),-cos(yaw))*14,Color.WHITE,2)
