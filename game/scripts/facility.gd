extends Node3D
## Metre-scale, data-driven architecture. Repeated boxes become material batches.
const CYAN := Color("60e5e0")
const GOLD := Color("f4bb64")
var mats: Dictionary = {}
var batches: Dictionary = {}
var collision: StaticBody3D
var stations: Array[Dictionary] = []
var installed_module: Node3D
var nasa: Dictionary = {}
var launch_vehicle: Node3D
var engine_flames: Array[Node3D] = []
var launch_velocity := 0.0
var liftoff_active := false

func build() -> void:
	nasa = JSON.parse_string(FileAccess.get_file_as_string("res://assets/NASA_REFERENCES.json"))
	collision = StaticBody3D.new()
	add_child(collision)
	palette()
	lighting()
	grounds()
	hall()
	shop()
	control_room()
	launch_complex()
	flush_batches()

func material(key: String, color: Color, metallic: float = 0.0, rough: float = 0.5, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	mats[key] = m
	return m

func palette() -> void:
	material("shell", Color("233344"), 0.4)
	material("dark", Color("0b1520"), 0.3)
	material("panel", Color("a5b6bd"), 0.35, 0.38)
	material("white", Color("d9e2e3"), 0.2, 0.32)
	material("steel", Color("526574"), 0.65, 0.34)
	material("black", Color("101a23"), 0.15, 0.62)
	material("gold", GOLD, 0.45, 0.38)
	material("cyan", CYAN, 0.1, 0.4, 1.8)
	material("amber", GOLD, 0.1, 0.4, 1.5)
	material("light", Color("d1f4ff"), 0.0, 0.4, 2.5)
	material("screen", Color("102c40"), 0.1, 0.4, 0.5)
	var glass := material("sign_glass", Color(0.08, 0.62, 0.68, 0.42), 0.25, 0.22, 1.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material("ground", Color("303f44"), 0.0, 0.95)
	material("red", Color("de6e4e"), 0.25)
	var floor_mat := material("floor", Color("566672"), 0.2, 0.78)
	apply_texture(floor_mat, "Concrete034", 0.25)
	var metal := material("metal", Color("5c707e"), 0.6, 0.42)
	apply_texture(metal, "MetalPlates006", 0.4)

func apply_texture(mat: StandardMaterial3D, asset: String, scale_uv: float) -> void:
	var base := "res://assets/%s/%s_1K-JPG_" % [asset, asset]
	if ResourceLoader.exists(base + "Color.jpg"):
		mat.albedo_texture = load(base + "Color.jpg")
		mat.normal_enabled = true
		mat.normal_texture = load(base + "NormalGL.jpg")
		mat.normal_scale = 0.22
		mat.roughness_texture = load(base + "Roughness.jpg")
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * scale_uv
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

func box(pos: Vector3, size: Vector3, key: String, solid: bool = false, angle: float = 0.0) -> void:
	var basis := Basis(Vector3.UP, angle)
	var t := Transform3D(basis.scaled(size), pos)
	if not batches.has(key):
		batches[key] = []
	batches[key].append(t)
	if solid:
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		shape.transform = Transform3D(basis, pos)
		collision.add_child(shape)

func flush_batches() -> void:
	for key: String in batches:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = mats[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = batches[key].size()
		for i: int in range(mm.instance_count):
			mm.set_instance_transform(i, batches[key][i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.name = "Architecture_" + key
		add_child(instance)
	batches.clear()

func cylinder(pos: Vector3, radius: float, height: float, key: String, top: float = -1.0, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 32
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mats[key]
	(parent if parent != null else self).add_child(node)
	node.position = pos
	return node

func sign_text(text: String, pos: Vector3, size: int = 60, color: Color = Color.WHITE, yaw: float = 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.rotation.y = yaw
	add_child(label)
	label.position = pos
	return label

func doorway_sign(text: String, pos: Vector3, panel_size: Vector3, yaw: float) -> void:
	# One physical cyan display with independently oriented text on each face.
	box(pos, panel_size, "sign_glass")
	var normal := Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.06)
	for face: float in [0.0, PI]:
		var caption := sign_text(text, pos + normal.rotated(Vector3.UP, face), 43, Color("d9ffff"), yaw + face)
		caption.double_sided = false
		caption.outline_size = 7
		caption.outline_modulate = Color(0.01, 0.08, 0.11, 0.95)
		caption.render_priority = 2

func point_light(pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	add_child(light)

func lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("19334f")
	sky_mat.sky_horizon_color = Color("b8bcba")
	sky_mat.ground_horizon_color = Color("7b8a8d")
	sky_mat.ground_bottom_color = Color("283542")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8da9c4")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -35, 0)
	sun.light_color = Color("ffddad")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95
	add_child(sun)
	for p: Vector3 in [Vector3(-9, 7, 19), Vector3(9, 7, 19), Vector3(-9, 10, -4), Vector3(9, 10, -4), Vector3(-24, 6, 6), Vector3(24, 6, 6)]:
		point_light(p, Color("b8e5ff"), 2.2, 21)

func grounds() -> void:
	box(Vector3(0, -0.5, 0), Vector3(250, 0.5, 250), "ground", true)
	# Common walkable floor. Rooms have no load screens or raised thresholds.
	box(Vector3(0, -0.15, 5), Vector3(32, 0.3, 48), "floor", true)
	box(Vector3(-24, -0.15, 6), Vector3(16, 0.3, 24), "floor", true)
	box(Vector3(24, -0.15, 6), Vector3(16, 0.3, 24), "floor", true)
	for x: float in [-14.6, 14.6]:
		box(Vector3(x, 0.012, 5), Vector3(0.08, 0.024, 46), "cyan")
	for z: int in range(-18, 29, 3):
		box(Vector3(0, 0.006, z), Vector3(30, 0.012, 0.025), "dark")
	for x: int in range(-15, 16, 3):
		box(Vector3(x, 0.006, 5), Vector3(0.025, 0.012, 47), "dark")
	# Distant support structures: intentionally sparse geometry.
	for i: int in range(10):
		var x: float = -100.0 + i * 22.0
		box(Vector3(x, 3, -105), Vector3(15, 6, 8), "shell")
		cylinder(Vector3(x, 8, -107), 1.4, 8, "steel")

func hall() -> void:
	# Arrival concourse, rear boundary, and ceiling.
	box(Vector3(0, 4.5, 29), Vector3(32, 9, 0.6), "shell", true)
	box(Vector3(0, 9.2, 21), Vector3(32, 0.4, 16), "dark", true)
	for x: float in [-16, 16]:
		box(Vector3(x, 4.5, 23.5), Vector3(0.5, 9, 11), "shell", true)
		# Wall opening to side rooms spans z = 1..11.
		box(Vector3(x, 8, 5), Vector3(0.5, 5, 26), "shell", true)
		box(Vector3(x, 2.8, -10), Vector3(0.5, 5.6, 18), "shell", true)
		box(Vector3(x, 2.8, 15), Vector3(0.5, 5.6, 8), "shell", true)
		for z: float in [0, 12]:
			box(Vector3(x, 3, z), Vector3(0.9, 6, 0.65), "white", true)
			box(Vector3(x - signf(x) * 0.48, 3, z), Vector3(0.06, 5.5, 0.12), "cyan")
	# Main high bay and skylight opening.
	for x: float in [-12, 12]:
		box(Vector3(x, 17, -3), Vector3(8, 0.5, 32), "shell", true)
	for z: int in range(-18, 14, 6):
		box(Vector3(0, 16.7, z), Vector3(32, 0.65, 0.6), "steel")
		for x: float in [-15, 15]:
			if z != 6:
				box(Vector3(x, 8.5, z), Vector3(0.75, 17, 0.9), "steel", true)
				box(Vector3(x - signf(x) * 0.42, 3, z), Vector3(0.06, 5, 0.2), "light")
	# Rear exit: 8m opening connects to launch corridor.
	for x: float in [-10, 10]:
		box(Vector3(x, 8.5, -19), Vector3(12, 17, 0.6), "shell", true)
		box(Vector3(x, 4.2, -18.62), Vector3(9.5, 5.5, 0.15), "panel")
		box(Vector3(x, 7.1, -18.50), Vector3(9.5, 0.09, 0.08), "cyan")
		for vent: int in range(7):
			box(Vector3(x - 3 + vent, 2.2, -18.5), Vector3(0.45, 0.8, 0.08), "dark")
		monitor(Vector3(x, 4.8, -18.4), "GROUND SUPPORT / BAY 01", "ENVIRONMENT  /  ACCESS  /  SERVICES\nFACILITY EXPLORATION BUILD", 6)
	box(Vector3(0, 12, -19), Vector3(8, 10, 0.6), "shell", true)
	box(Vector3(0, 6.9, -18.6), Vector3(8.5, 0.15, 0.15), "cyan")
	# Hero arch at the entrance to engineering.
	for x: float in [-12, 12]:
		box(Vector3(x, 5, 13), Vector3(0.7, 10, 0.7), "white", true)
	box(Vector3(0, 9.7, 13), Vector3(24, 0.7, 0.8), "white")
	box(Vector3(0, 9.28, 13.45), Vector3(22, 0.08, 0.06), "cyan")
	sign_text("M O H A S H U N N Y O", Vector3(0, 8.5, 13.5), 83)
	sign_text("F R O N T I E R   /   E A R T H   O P E R A T I O N S", Vector3(0, 7.7, 13.5), 27, CYAN)
	# Reception and wayfinding.
	box(Vector3(-7.8, 0.65, 20), Vector3(4.5, 1.3, 1.8), "panel", true)
	box(Vector3(-7.8, 1.34, 20), Vector3(4.7, 0.1, 2), "dark")
	box(Vector3(-7.8, 0.7, 21), Vector3(3.6, 0.09, 0.03), "cyan")
	sign_text("FLIGHT OPERATIONS", Vector3(-7.8, 0.95, 21.02), 28)
	monitor(Vector3(-7.8, 1.8, 19.9), "WELCOME, EXPLORER", "01  SHOP     /     02  ENGINEERING\n03  LAUNCH     /     04  MISSION CONTROL", 2.8)
	for x: float in [-7, 7]:
		box(Vector3(x, 9, 21), Vector3(0.6, 0.05, 12), "light")
	# Direction lines guide players around the integration plinth.
	for x: float in [-6.3, 6.3]:
		box(Vector3(x, 0.014, -1), Vector3(0.07, 0.028, 30), "gold")
		for z: int in range(-14, 15, 4):
			box(Vector3(x, 0.018, z), Vector3(0.7, 0.035, 0.12), "gold")
	# Door-mounted wayfinding: cyan glass panels, readable left-to-right from either side.
	doorway_sign("01  /  SUPPLY & OUTFITTING", Vector3(-15.68, 6.25, 6), Vector3(0.10, 1.15, 7.2), -PI / 2)
	doorway_sign("04  /  MISSION CONTROL", Vector3(15.68, 6.25, 6), Vector3(0.10, 1.15, 7.2), PI / 2)
	doorway_sign("02  /  VEHICLE INTEGRATION", Vector3(0, 10.45, 13), Vector3(10.5, 1.05, 0.10), 0)
	doorway_sign("03  /  LAUNCH COMPLEX", Vector3(0, 7.5, -18.55), Vector3(8.0, 1.05, 0.10), 0)
	# Assembly plinth is floor-level; barriers guide the route around it.
	box(Vector3(0, 0.08, -3), Vector3(9, 0.16, 15), "dark", true)
	for x: float in [-4.6, 4.6]:
		box(Vector3(x, 0.025, -3), Vector3(0.12, 0.05, 15.5), "amber")
		for z: int in range(-10, 5, 2):
			box(Vector3(x + signf(x) * 0.25, 0.018, z), Vector3(0.45, 0.03, 0.35), "gold", false, -0.4)
	# Horizontal spacecraft on integration cradles.
	var ship := Node3D.new()
	ship.name = "AssemblySpacecraft"
	add_child(ship)
	ship.position = Vector3(0, 3.6, -2)
	ship.rotation.x = PI / 2
	rocket(ship, 0.68)
	for z: float in [-6, 1]:
		box(Vector3(0, 1.0, z), Vector3(4.8, 2, 1.2), "steel", true)
		box(Vector3(0, 2.05, z), Vector3(5, 0.15, 1.4), "gold")
	# Collision envelope of craft leaves walkable perimeter.
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(3.3, 4.7, 12.5)
	shape.shape = bounds
	shape.position = Vector3(0, 2.35, -3)
	collision.add_child(shape)
	# Crane rails and hanging hook.
	for x: float in [-11, 11]:
		box(Vector3(x, 12, -3), Vector3(0.5, 0.6, 29), "gold")
	box(Vector3(0, 12, -5), Vector3(22, 0.8, 1.1), "gold")
	box(Vector3(0, 10.4, -5), Vector3(0.08, 3.2, 0.08), "steel")
	cylinder(Vector3(0, 8.7, -5), 0.35, 0.35, "gold")
	for x: float in [-10, 10]:
		for z: float in [-11, -4]:
			workbench(Vector3(x, 0, z))
	station(Vector3(8, 0, 7), "engineering", "MISSION DESIGN REVIEW", "MASS / POWER / READINESS")
	sign_text("VEHICLE 01\nINTEGRATION IN PROGRESS", Vector3(-9, 4.5, -15), 35, GOLD)

func monitor(pos: Vector3, title: String, body: String, width: float = 3.8, yaw: float = 0.0) -> void:
	box(pos, Vector3(width, 1.8, 0.18), "dark", false, yaw)
	var normal := Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.105)
	box(pos + normal, Vector3(width - 0.14, 1.64, 0.025), "screen", false, yaw)
	sign_text(title, pos + normal * 1.4 + Vector3(0, 0.46, 0), 26, CYAN, yaw)
	sign_text(body, pos + normal * 1.5 + Vector3(0, -0.22, 0), 18, Color("c4dbe5"), yaw)

func workbench(pos: Vector3) -> void:
	box(pos + Vector3(0, 0.9, 0), Vector3(3.8, 0.18, 1.7), "metal", true)
	for x: float in [-1.5, 1.5]:
		box(pos + Vector3(x, 0.4, 0), Vector3(0.18, 0.8, 1.4), "steel", true)
	for i: int in range(3):
		box(pos + Vector3(-1 + i, 1.12, 0), Vector3(0.6, 0.25, 0.8), "gold" if i == 0 else "black")
	monitor(pos + Vector3(0, 2, -0.5), "SYSTEM DIAGNOSTICS", "POWER  /  STRUCTURE  /  AVIONICS\nGROUND SYSTEMS : NOMINAL", 3.0)

func station(pos: Vector3, id: String, title: String, subtitle: String) -> void:
	box(pos + Vector3(0, 0.75, 0), Vector3(2.4, 1.5, 1.2), "shell", true)
	box(pos + Vector3(0, 1.55, 0), Vector3(2.6, 0.1, 1.4), "metal")
	monitor(pos + Vector3(0, 2.25, -0.1), title, subtitle + "\nCLICK TO OPEN", 3.4)
	box(pos + Vector3(0, 0.8, 0.62), Vector3(1.8, 0.07, 0.03), "cyan")
	stations.append({"id": id, "title": title, "position": pos + Vector3(0, 2.25, 0)})

func shop() -> void:
	box(Vector3(-32, 4, 6), Vector3(0.5, 8, 24), "shell", true)
	for z: float in [-6, 18]:
		box(Vector3(-24, 4, z), Vector3(16, 8, 0.5), "shell", true)
	box(Vector3(-24, 8.1, 6), Vector3(16, 0.3, 24), "dark", true)
	for z: float in [-2, 5, 12]:
		box(Vector3(-31.65, 4.0, z), Vector3(0.12, 5.5, 5.8), "panel")
		box(Vector3(-31.5, 1.1, z), Vector3(0.12, 0.1, 5.8), "amber")
	for z: float in [-3, 3, 9, 15]:
		box(Vector3(-24, 7.8, z), Vector3(12, 0.08, 0.35), "light")
	for i: int in range(3):
		var x: float = -29.0 + i * 4.8
		box(Vector3(x, 1.7, -3.5), Vector3(3.4, 3.4, 1.2), "dark", true)
		for y: float in [0.3, 1.7, 3.1]:
			box(Vector3(x, y, -3.4), Vector3(3.5, 0.1, 1.4), "metal")
			box(Vector3(x, y + 0.1, -2.68), Vector3(3.3, 0.035, 0.03), "cyan")
		for n: int in range(3):
			box(Vector3(x - 1 + n, 0.9, -3.3), Vector3(0.65, 0.9, 0.6), "white" if i == 0 else "gold")
		cylinder(Vector3(x, 2.4, -3.3), 0.45, 1.1, "white")
		sign_text(["LIFE SUPPORT", "POWER SYSTEMS", "SCIENCE PAYLOAD"][i], Vector3(x, 3.9, -2.7), 23, GOLD)
	# Three display islands and a suit mannequin.
	for z: float in [3, 10]:
		box(Vector3(-26.5, 0.5, z), Vector3(4, 1, 2.2), "panel", true)
		box(Vector3(-26.5, 1.04, z), Vector3(4.1, 0.08, 2.3), "dark")
		for x: float in [-27.6, -25.5]:
			cylinder(Vector3(x, 1.6, z), 0.33, 1.0, "white")
			cylinder(Vector3(x, 2.13, z), 0.22, 0.12, "cyan")
	station(Vector3(-21, 0, 13), "shop", "MISSION OUTFITTER", "PROCURE / DELIVER / INTEGRATE")
	box(Vector3(-30, 0.15, 13), Vector3(2.3, 0.3, 2.3), "steel", true)
	# Stylized pressure suit display, built from purposeful hard-surface parts.
	cylinder(Vector3(-30, 1.75, 13), 0.48, 1.1, "white")
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.37
	sphere.height = 0.74
	head.mesh = sphere
	head.material_override = mats.gold
	head.position = Vector3(-30, 2.65, 13)
	add_child(head)
	for x: float in [-30.25, -29.75]:
		cylinder(Vector3(x, 0.8, 13), 0.19, 1.1, "white")
	for x: float in [-30.65, -29.35]:
		cylinder(Vector3(x, 1.7, 13), 0.17, 1.0, "white")

func control_room() -> void:
	box(Vector3(32, 4, 6), Vector3(0.5, 8, 24), "shell", true)
	for z: float in [-6, 18]:
		box(Vector3(24, 4, z), Vector3(16, 8, 0.5), "shell", true)
	box(Vector3(24, 8.1, 6), Vector3(16, 0.3, 24), "dark", true)
	material("control_graphite",Color("17212c"),0.35,0.6)
	material("control_fabric",Color("30434a"),0.05,0.9)
	material("control_blue",Color("1c536a"),0.15,0.5,0.25)
	box(Vector3(24,0.03,5),Vector3(15,0.06,21),"control_graphite")
	for x: float in [17.0,31.0]: box(Vector3(x,0.09,6),Vector3(0.06,0.04,21),"cyan")
	# Main display wall: one large flight plot, paired telemetry columns.
	box(Vector3(24,4.5,-5.6),Vector3(13.2,5.5,0.2),"black")
	box(Vector3(24,4.5,-5.45),Vector3(8,4.8,0.04),"screen")
	sign_text("F R O N T I E R   /   M I S S I O N   C O N T R O L",Vector3(24,7.2,-5.35),30,Color("d8e7e9"))
	sign_text("EARTH DEPARTURE     →     MARS ARRIVAL",Vector3(24,6.25,-5.30),22,CYAN)
	for i: int in range(34):
		var t := float(i)/33
		box(Vector3(20.8+t*6.3,3.3+sin(t*PI)*1.9,-5.27),Vector3(0.12,0.045,0.045),"cyan")
	for x: float in [20.8,27.1]:
		var planet := SphereMesh.new(); planet.radius = 0.22; planet.height = 0.44
		var node := MeshInstance3D.new(); node.mesh = planet; node.material_override = mats["control_blue"] if x < 24 else mats["red"]; node.position = Vector3(x,3.3,-5.23); add_child(node)
	sign_text("TRAJECTORY CONCEPT / NOT TO SCALE",Vector3(24,2.55,-5.25),18,Color("799eaa"))
	for x: float in [18.7,29.3]:
		for row: int in range(3):
			monitor(Vector3(x,3+row*1.4,-5.3),["VEHICLE STATUS","LIFE SUPPORT","GROUND NETWORK"][row],"NOMINAL\nREFERENCE / SIMULATION",2.15)
	# Paired operator islands preserve the central and cross-room circulation aisles.
	for x: float in [20.0,28.0]:
		for z: float in [0.0,8.0]:
			box(Vector3(x,0.56,z),Vector3(4.1,1.12,1.4),"control_graphite",true)
			box(Vector3(x,1.18,z),Vector3(4.4,0.14,1.9),"steel")
			for offset: float in [-1.05,1.05]:
				monitor(Vector3(x+offset,1.95,z-0.48),"FLIGHT" if offset < 0 else "SYSTEMS","LINK 01 / ACTIVE",1.9)
				box(Vector3(x+offset,1.29,z+0.34),Vector3(0.92,0.045,0.34),"black")
				for key: int in range(6): box(Vector3(x+offset-0.34+key*0.13,1.32,z+0.35),Vector3(0.07,0.02,0.19),"steel")
				cylinder(Vector3(x+offset,0.44,z+1.55),0.33,0.08,"black")
				cylinder(Vector3(x+offset,0.67,z+1.55),0.055,0.45,"steel")
				box(Vector3(x+offset,0.93,z+1.55),Vector3(0.64,0.12,0.6),"control_fabric")
				box(Vector3(x+offset,1.3,z+1.85),Vector3(0.64,0.7,0.12),"control_fabric")
			box(Vector3(x,1.0,z+0.75),Vector3(4.2,0.04,0.03),"cyan")
	for z: float in [-1.0,5.0,12.0]:
		box(Vector3(31.6,3.5,z),Vector3(0.12,5.4,4.2),"control_graphite")
		for j: int in range(9): box(Vector3(31.48,1.25+j*0.45,z),Vector3(0.08,0.12,3.7),"steel")
	for x: float in [20.0,28.0]:
		box(Vector3(x,7.6,6),Vector3(0.18,0.06,20),"light")
		point_light(Vector3(x,4.5,5),Color("b2d8e2"),1.3,9)
	sign_text("FLIGHT DIRECTOR / OPERATIONS",Vector3(24,3.5,17.65),28,GOLD,PI)
	station(Vector3(24, 0, 14), "science", "NASA DATA ARCHIVE", "SOURCES / MEASUREMENTS / LIMITATIONS")
	station(Vector3(29.6,0,14),"field_systems","FIELD SYSTEMS PROCUREMENT","DEPLOY / ASSEMBLE / EXPAND")

func rocket(parent: Node3D, scale_factor: float = 1.0) -> void:
	parent.scale = Vector3.ONE * scale_factor
	cylinder(Vector3(0, 0, 0), 1.6, 11, "white", -1, parent)
	for y: float in [-4.8, -1.8, 2, 4.8]:
		cylinder(Vector3(0, y, 0), 1.625, 0.18, "steel", -1, parent)
	cylinder(Vector3(0, 6.8, 0), 1.6, 2.6, "white", 0.15, parent)
	cylinder(Vector3(0, -5.8, 0), 1.4, 0.65, "steel", 1.1, parent)
	for x: float in [-0.65, 0.65]:
		for z: float in [-0.65, 0.65]:
			cylinder(Vector3(x, -6.5, z), 0.48, 0.9, "black", 0.25, parent)
	for x: float in [-2.1, 2.1]:
		cylinder(Vector3(x, -1.4, 0), 0.58, 7.5, "panel", -1, parent)
		cylinder(Vector3(x, 2.8, 0), 0.58, 0.9, "white", 0, parent)
		cylinder(Vector3(x, -5.5, 0), 0.65, 0.7, "black", 0.35, parent)
	var text := Label3D.new()
	text.text = "FRONTIER\n01"
	text.font_size = 70
	text.pixel_size = 0.007
	text.outline_size = 0
	text.modulate = Color("16354d")
	text.position = Vector3(0, 1.5, 1.62)
	parent.add_child(text)

func launch_complex() -> void:
	box(Vector3(0, -0.15, -27), Vector3(8, 0.3, 16), "metal", true)
	for x: float in [-4, 4]:
		box(Vector3(x, 1.1, -27), Vector3(0.2, 0.15, 16), "steel", true)
		for z: int in range(-34, -18, 3):
			box(Vector3(x, 0.55, z), Vector3(0.15, 1.1, 0.15), "steel", true)
		box(Vector3(x * 0.9, 0.03, -27), Vector3(0.07, 0.06, 16), "cyan")
	box(Vector3(0, -0.15, -49), Vector3(40, 0.3, 28), "floor", true)
	for x: float in [-19, 19]:
		box(Vector3(x, 1.1, -49), Vector3(0.2, 0.15, 28), "steel", true)
		for z: int in range(-62, -35, 3):
			box(Vector3(x, 0.55, z), Vector3(0.15, 1.1, 0.15), "steel", true)
	# End safety barriers, with a central view of the launch stack.
	for z: float in [-63, -35]:
		for x: float in [-12, 12]:
			box(Vector3(x, 1.1, z), Vector3(16, 0.15, 0.2), "steel", true)
			for i: int in range(6):
				box(Vector3(x - 7.5 + i * 3, 0.55, z), Vector3(0.15, 1.1, 0.15), "steel", true)
	box(Vector3(0, 1.1, -63), Vector3(8, 0.15, 0.2), "steel", true)
	cylinder(Vector3(0, 0.35, -50), 7, 0.7, "dark")
	# Pad collision keeps player safely outside vehicle base.
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 6.8
	shape.height = 1.0
	col.shape = shape
	col.position = Vector3(0, 0.5, -50)
	collision.add_child(col)
	var ship := Node3D.new()
	ship.name = "LaunchVehicle"
	add_child(ship)
	launch_vehicle = ship
	ship.position = Vector3(0, 10.5, -50)
	rocket(ship, 1.4)
	for x: float in [7, 11]:
		for z: float in [-53, -49]:
			box(Vector3(x, 12, z), Vector3(0.65, 24, 0.65), "steel", true)
	for y: int in range(3, 25, 3):
		box(Vector3(9, y, -51), Vector3(4.5, 0.2, 5), "metal")
		box(Vector3(9, y + 1, -48.4), Vector3(4, 0.1, 0.1), "gold")
	box(Vector3(5, 17, -50), Vector3(7, 0.7, 1.4), "gold")
	for x: float in [-16, 16]:
		box(Vector3(x, 9, -59), Vector3(0.45, 18, 0.45), "steel", true)
		box(Vector3(x, 18, -59), Vector3(2.4, 0.35, 1), "light")
		point_light(Vector3(x, 15, -57), Color("fff0ce"), 3, 25)
	station(Vector3(-10, 0, -39), "launch", "LAUNCH OPERATIONS", "READINESS GATE / TERMINAL COUNT")
	# Storage tanks and service infrastructure.
	for i: int in range(3):
		cylinder(Vector3(-31 - i * 7, 4, -52), 2.7, 8, "panel")
		cylinder(Vector3(-31 - i * 7, 8.3, -52), 2.7, 0.6, "steel", 2.2)
		box(Vector3(-31 - i * 7, 1, -52), Vector3(6, 2, 6), "dark")

func start_liftoff() -> void:
	if liftoff_active or not is_instance_valid(launch_vehicle): return
	liftoff_active = true
	launch_velocity = 0.8
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = Color("ffb43b")
	flame_material.emission_enabled = true
	flame_material.emission = Color("ff6a24")
	flame_material.emission_energy_multiplier = 7.0
	for x: float in [-0.65, 0.65]:
		for z: float in [-0.65, 0.65]:
			var flame := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.36; cone.bottom_radius = 0.05; cone.height = 4.5; cone.radial_segments = 12
			flame.mesh = cone; flame.material_override = flame_material
			flame.position = Vector3(x, -9.0, z)
			launch_vehicle.add_child(flame)
			engine_flames.append(flame)
	var light := OmniLight3D.new()
	light.light_color = Color("ff9b43"); light.light_energy = 14.0; light.omni_range = 24.0
	light.position = Vector3(0, -7.5, 0)
	launch_vehicle.add_child(light)

func update_liftoff(delta: float) -> void:
	if not liftoff_active or not is_instance_valid(launch_vehicle): return
	launch_velocity = minf(28.0, launch_velocity + 2.2 * delta)
	launch_vehicle.position.y += launch_velocity * delta
	var pulse := 0.88 + sin(Time.get_ticks_msec() * 0.025) * 0.12
	for flame: Node3D in engine_flames: flame.scale.y = pulse
