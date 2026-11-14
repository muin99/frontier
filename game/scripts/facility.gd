extends Node3D
## Earth Operations: metre-scale lab and launch site. Walls and furniture are batched
## boxes; hero pieces (vehicle, robot arms, holograms, simulator) are authored in code.
const Gfx = preload("res://scripts/gfx.gd")
const CYAN := Color("5fe9e0")
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
var ignited := false
var environment: Environment
var sun: DirectionalLight3D
var spinners: Array[Dictionary] = []
var arms: Array[Dictionary] = []
var blinkers: Array[Dictionary] = []
var status_lamps: Array[MeshInstance3D] = []
var integration_level := 0
var clock := 0.0
var guide: Node3D
var pad_smoke: CPUParticles3D
var pad_sparks: CPUParticles3D
var pad_light: OmniLight3D
var service_arm: Node3D
var screen_seed := 0.0

func build() -> void:
	nasa = JSON.parse_string(FileAccess.get_file_as_string("res://assets/NASA_REFERENCES.json"))
	collision = StaticBody3D.new()
	add_child(collision)
	palette()
	lighting()
	grounds()
	concourse()
	high_bay()
	outfitting()
	control_room()
	launch_complex()
	make_guide()
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
	apply_texture(material("shell", Color("b9c4ca"), 0.15, 0.6), "MetalPlates006", 0.14, 0.7, false)
	material("trim", Color("1e2a35"), 0.45, 0.42)
	material("dark", Color("0d141b"), 0.3, 0.5)
	material("panel", Color("c9d1d4"), 0.15, 0.4)
	material("white", Color("d5dadc"), 0.1, 0.3)
	material("steel", Color("70828f"), 0.85, 0.3)
	material("nozzle", Color("4c5660"), 0.9, 0.35).cull_mode = BaseMaterial3D.CULL_DISABLED
	material("black", Color("11181f"), 0.2, 0.5)
	material("gold", Color("e9b13c"), 0.35, 0.42)
	material("orange", Color("e2672f"), 0.2, 0.45)
	material("leaf", Color("3f8a52"), 0.0, 0.8)
	material("cyan", CYAN, 0.1, 0.4, 1.7)
	material("amber", GOLD, 0.1, 0.4, 1.6)
	material("light", Color("eaf6ff"), 0.0, 0.4, 1.9)
	material("warm", Color("ffd9a8"), 0.0, 0.4, 1.7)
	material("red", Color("ff4a3a"), 0.1, 0.4, 2.0)
	material("green", Color("58f08c"), 0.1, 0.4, 1.8)
	material("lamp_off", Color("26323a"), 0.3, 0.4)
	material("screen", Color("0a2030"), 0.1, 0.3, 0.4)
	material("ground", Color("2b3136"), 0.0, 0.92)
	material("tarmac", Color("3a4046"), 0.0, 0.85)
	material("control_graphite", Color("17212c"), 0.35, 0.5)
	material("control_fabric", Color("30434a"), 0.05, 0.9)
	material("control_blue", Color("1c536a"), 0.15, 0.5, 0.25)
	var glass := material("sign_glass", Color(0.08, 0.62, 0.68, 0.42), 0.25, 0.22, 1.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats["glass"] = Gfx.glass()
	apply_texture(material("floor", Color("59646c"), 0.1, 0.3), "Concrete034", 0.16, 0.25)
	material("floor_dark", Color("1a232b"), 0.35, 0.14)
	apply_texture(material("metal", Color("7a8b96"), 0.7, 0.4), "MetalPlates006", 0.3, 0.6)

func apply_texture(mat: StandardMaterial3D, asset: String, scale_uv: float, normal_strength := 0.3, albedo := true) -> void:
	var base := "res://assets/%s/%s_1K-JPG_" % [asset, asset]
	if ResourceLoader.exists(base + "Color.jpg"):
		if albedo: mat.albedo_texture = load(base + "Color.jpg")
		mat.normal_enabled = true
		mat.normal_texture = load(base + "NormalGL.jpg")
		mat.normal_scale = normal_strength
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * scale_uv
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

func box(pos: Vector3, size: Vector3, key: String, solid: bool = false, angle: float = 0.0) -> void:
	var basis := Basis(Vector3.UP, angle)
	var t := Transform3D(basis.scaled(size), pos)
	if not batches.has(key):
		batches[key] = []
	batches[key].append(t)
	if solid:
		blocker(pos, size, angle)

func blocker(pos: Vector3, size: Vector3, angle: float = 0.0) -> void:
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	shape.transform = Transform3D(Basis(Vector3.UP, angle), pos)
	collision.add_child(shape)

func round_blocker(pos: Vector3, radius: float, height: float) -> void:
	var shape := CollisionShape3D.new()
	var bounds := CylinderShape3D.new()
	bounds.radius = radius
	bounds.height = height
	shape.shape = bounds
	shape.position = pos + Vector3(0, height * 0.5, 0)
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
		if key in ["glass", "sign_glass", "light", "cyan", "amber", "warm", "red", "green"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

func ball(pos: Vector3, radius: float, material_value: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 48
	mesh.rings = 24
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material_value
	(parent if parent != null else self).add_child(node)
	node.position = pos
	return node

func part(pos: Vector3, size: Vector3, key: String, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mats[key]
	parent.add_child(node)
	node.position = pos
	return node

func turned(profile: Array, key: String, pos: Vector3, parent: Node3D = null, segments: int = 40) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = Gfx.lathe(profile, segments)
	node.material_override = mats[key]
	(parent if parent != null else self).add_child(node)
	node.position = pos
	return node

func sign_text(text: String, pos: Vector3, size: int = 60, color: Color = Color.WHITE, yaw: float = 0.0, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.rotation.y = yaw
	(parent if parent != null else self).add_child(label)
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

func point_light(pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0
	add_child(light)
	return light

func spot_light(pos: Vector3, target: Vector3, color: Color, energy: float, reach: float, angle: float, shadows := false) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = angle
	light.spot_attenuation = 0.8
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 0.6
	add_child(light)
	light.look_at_from_position(pos, target, Vector3.FORWARD if absf(pos.x - target.x) + absf(pos.z - target.z) < 0.01 else Vector3.UP)
	return light

func lighting() -> void:
	var level: int = Gfx.quality()
	var world := WorldEnvironment.new()
	environment = Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1d4a8a")
	sky_mat.sky_horizon_color = Color("f3c59c")
	sky_mat.sky_curve = 0.11
	sky_mat.ground_horizon_color = Color("caa58a")
	sky_mat.ground_bottom_color = Color("2a3038")
	sky_mat.sun_angle_max = 24.0
	sky_mat.sun_curve = 0.07
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a6bfd8")
	environment.ambient_light_energy = 0.5
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	Gfx.grade(environment, level, true)
	environment.volumetric_fog_enabled = level > 0
	environment.volumetric_fog_density = 0.011
	environment.volumetric_fog_albedo = Color("d6e4f2")
	environment.volumetric_fog_anisotropy = 0.72
	environment.volumetric_fog_length = 110.0
	environment.volumetric_fog_ambient_inject = 0.15
	environment.volumetric_fog_sky_affect = 0.25
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color("ffd3a2")
	sun.light_energy = 2.0
	sun.shadow_enabled = level > 0
	sun.directional_shadow_max_distance = 130
	sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 2.2
	add_child(sun)
	# Soft interior fill. Clustered lighting keeps unshadowed omnis inexpensive.
	for p: Vector3 in [Vector3(-9, 7.5, 21), Vector3(9, 7.5, 21), Vector3(-9, 11, -4), Vector3(9, 11, -4), Vector3(-9, 11, -13), Vector3(9, 11, -13), Vector3(0, 11, 6)]:
		point_light(p, Color("cfe6ff"), 2.4, 22)
	for z: float in [-1.0, 6.0, 13.0]:
		point_light(Vector3(-24, 6.4, z), Color("ffe6c8"), 2.2, 13)
	# Each occupied volume gets one box-projected probe so glossy floors mirror the room, not the sky.
	for data: Array in [[Vector3(0, 6, 21), Vector3(32, 12, 16)], [Vector3(0, 9, -3), Vector3(32, 18, 32)], [Vector3(-24, 4, 6), Vector3(16, 8, 24)], [Vector3(24, 4, 6), Vector3(16, 8, 24)]]:
		var probe := ReflectionProbe.new()
		probe.position = data[0]
		probe.size = data[1]
		probe.box_projection = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.enable_shadows = false
		probe.intensity = 0.8
		probe.max_distance = 60.0
		add_child(probe)

func grounds() -> void:
	box(Vector3(0, -0.5, 0), Vector3(900, 0.5, 900), "ground", true)
	box(Vector3(0, -0.2, -20), Vector3(180, 0.1, 180), "tarmac")
	# Common walkable floor. Rooms have no load screens or raised thresholds.
	box(Vector3(0, -0.15, 5), Vector3(32, 0.3, 48), "floor", true)
	box(Vector3(-24, -0.15, 6), Vector3(16, 0.3, 24), "floor", true)
	box(Vector3(24, -0.15, 6), Vector3(16, 0.3, 24), "floor", true)
	for x: float in [-14.6, 14.6]:
		box(Vector3(x, 0.012, 5), Vector3(0.08, 0.024, 46), "cyan")
	# Distant support structures and a ring of hills close the horizon.
	for i: int in range(10):
		var x: float = -100.0 + i * 22.0
		box(Vector3(x, 3, -125), Vector3(15, 6, 8), "trim")
		cylinder(Vector3(x, 8, -127), 1.4, 8, "steel")
	for i: int in range(6):
		box(Vector3(70 + i * 3.0, 4 + i * 0.6, 40 - i * 21.0), Vector3(14, 8 + i * 1.2, 18), "trim")
		box(Vector3(-78 - i * 2.0, 5, 44 - i * 24.0), Vector3(16, 10, 20), "trim")
	var hills := SurfaceTool.new()
	hills.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var previous := Vector3.ZERO
	var first_height := 22 + rng.randf() * 46
	for i: int in range(49):
		var angle := TAU * float(i) / 48.0
		var peak := Vector3(cos(angle) * 430, first_height if i in [0, 48] else 22 + rng.randf() * 46, sin(angle) * 430)
		if i > 0:
			var a := Vector3(cos(angle - TAU / 48.0) * 430, -1, sin(angle - TAU / 48.0) * 430)
			var b := Vector3(cos(angle) * 430, -1, sin(angle) * 430)
			var last_peak := Vector3(a.x, previous.y, a.z)
			for p: Vector3 in [a, last_peak, b, b, last_peak, peak]: hills.add_vertex(p)
		previous = peak
	var ridge := MeshInstance3D.new()
	ridge.mesh = hills.commit()
	var ridge_mat := Gfx.surface(Color("3a4a5c"), 0.0, 1.0)
	ridge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ridge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ridge.material_override = ridge_mat
	add_child(ridge)

func planter(pos: Vector3) -> void:
	box(pos + Vector3(0, 0.4, 0), Vector3(1.5, 0.8, 1.5), "panel", true)
	box(pos + Vector3(0, 0.82, 0), Vector3(1.38, 0.06, 1.38), "dark")
	for offset: Vector3 in [Vector3(0, 1.45, 0), Vector3(0.32, 1.15, 0.2), Vector3(-0.3, 1.2, -0.22), Vector3(0.1, 1.85, -0.1)]:
		var leaf := ball(pos + offset, 0.42 if offset.y < 1.8 else 0.3, mats.leaf)
		leaf.scale = Vector3(1, 1.25, 1)
	cylinder(pos + Vector3(0, 1.1, 0), 0.05, 0.7, "black")

func concourse() -> void:
	# Glazed south front: sun rakes across the arrival floor through the mullions.
	box(Vector3(0, 0.45, 29), Vector3(32, 0.9, 0.6), "trim")
	box(Vector3(0, 8.6, 29), Vector3(32, 1.2, 0.6), "shell")
	box(Vector3(0, 4.45, 29), Vector3(32, 7.1, 0.06), "glass")
	for i: int in range(9):
		box(Vector3(-16 + i * 4.0, 4.45, 29), Vector3(0.22, 7.1, 0.36), "steel")
	box(Vector3(0, 4.45, 29), Vector3(32, 0.16, 0.3), "steel")
	blocker(Vector3(0, 4.5, 29), Vector3(32, 9, 0.6))
	box(Vector3(0, 9.2, 21), Vector3(32, 0.4, 16), "dark", true)
	for x: float in [-16, 16]:
		box(Vector3(x, 4.5, 23.5), Vector3(0.5, 9, 11), "shell", true)
		box(Vector3(x - signf(x) * 0.3, 1.0, 23.5), Vector3(0.12, 2.0, 10.6), "trim")
		box(Vector3(x - signf(x) * 0.37, 2.05, 23.5), Vector3(0.05, 0.06, 10.6), "cyan")
	for x: float in [-10.5, -3.5, 3.5, 10.5]:
		box(Vector3(x, 8.96, 21), Vector3(0.5, 0.06, 13), "light")
	for z: float in [16.0, 21.0, 26.0]:
		box(Vector3(0, 8.9, z), Vector3(30, 0.25, 0.3), "trim")
	# Reception and wayfinding.
	box(Vector3(-7.8, 0.65, 20), Vector3(4.5, 1.3, 1.8), "panel", true)
	box(Vector3(-7.8, 1.34, 20), Vector3(4.7, 0.1, 2), "trim")
	box(Vector3(-7.8, 0.7, 20.92), Vector3(3.6, 0.09, 0.03), "cyan")
	sign_text("FLIGHT OPERATIONS", Vector3(-7.8, 0.98, 20.93), 28)
	monitor(Vector3(-7.8, 2.0, 19.9), "WELCOME, COMMANDER", "FOLLOW THE CYAN BEAM\nTO YOUR NEXT STATION", 2.8, 0.0, 4, 0.35)
	for p: Vector3 in [Vector3(-14.2, 0, 27.4), Vector3(14.2, 0, 27.4), Vector3(-14.2, 0, 14.6), Vector3(14.2, 0, 19.5)]:
		planter(p)
	for x: float in [-11.5, -8.5]:
		box(Vector3(x, 0.42, 26.6), Vector3(2.4, 0.12, 0.8), "trim", true)
		for leg: float in [-1.0, 1.0]: box(Vector3(x + leg, 0.2, 26.6), Vector3(0.1, 0.4, 0.7), "steel")
	# Mission banners.
	for i: int in range(4):
		var x: float = [-12.5, -5.5, 5.5, 12.5][i]
		box(Vector3(x, 6.6, 14.2), Vector3(2.2, 3.6, 0.05), ["orange", "trim", "trim", "orange"][i])
		box(Vector3(x, 8.45, 14.2), Vector3(2.4, 0.1, 0.1), "steel")
		sign_text(["MARS\n2026", "FRONTIER\n01", "ISIDIS\nBASIN", "A LONG\nWAY HOME"][i], Vector3(x, 6.6, 14.24), 46, Color("f6efe2"))
	mars_centrepiece(Vector3(0, 0, 17.5))
	simulator_pod(Vector3(11.2, 0, 25.2))

func mars_centrepiece(pos: Vector3) -> void:
	cylinder(pos + Vector3(0, 0.3, 0), 1.7, 0.6, "black")
	cylinder(pos + Vector3(0, 0.5, 0), 1.74, 0.05, "cyan")
	cylinder(pos + Vector3(0, 0.61, 0), 0.5, 0.03, "cyan")
	cylinder(pos + Vector3(0, 0.02, 0), 2.6, 0.03, "cyan")
	cylinder(pos + Vector3(0, 0.03, 0), 2.5, 0.035, "black")
	round_blocker(pos, 1.75, 1.2)
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = pos + Vector3(0, 3.1, 0)
	pivot.rotation.z = deg_to_rad(25.2)
	var globe := ball(Vector3.ZERO, 1.35, Gfx.mars(0.55), pivot)
	spinners.append({"node": globe, "axis": Vector3.UP, "speed": 0.22})
	var site := ball(Vector3(0, 0.42, 1.31).normalized() * 1.37, 0.045, Gfx.emissive(CYAN, 4.0), globe)
	var tag := sign_text("ISIDIS  /  LANDING REGION", Vector3(0, 0.25, 0), 22, Color("d9ffff"), 0.0, site)
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 6
	tag.outline_modulate = Color(0.02, 0.08, 0.1)
	ball(Vector3.ZERO, 1.5, Gfx.hologram(Color("ff9a5c"), 0.35), pivot).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i: int in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.9 + i * 0.35
		torus.outer_radius = 1.93 + i * 0.35
		torus.rings = 96
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = Gfx.emissive(CYAN if i == 0 else GOLD, 2.6)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(ring)
		ring.rotation = Vector3(0.35 + i * 0.5, 0, 0.2 - i * 0.6)
		spinners.append({"node": ring, "axis": Vector3.UP, "speed": 0.5 - i * 0.85})
		var moon := ball(Vector3(1.915 + i * 0.35, 0, 0), 0.07, Gfx.emissive(Color("fff4dd"), 3.0), ring)
		moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Light cone from the plinth sells the projection.
	var cone := turned([Vector2(0.25, 0.0), Vector2(1.45, 1.6)], "cyan", pos + Vector3(0, 0.66, 0))
	cone.material_override = Gfx.hologram(CYAN, 0.16)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	point_light(pos + Vector3(0, 3.1, 0), Color("ff9d66"), 3.0, 9)
	var caption := "MARS   /   gravity %.2f m/s²   /   mean radius %.1f km" % [float(nasa.equatorialGravity.value), float(nasa.meanRadius.value)]
	for face: float in [0.0, PI]:
		sign_text(caption, pos + Vector3(0, 0.34, 1.72).rotated(Vector3.UP, face), 20, Color("d9ffff"), face)

func simulator_pod(pos: Vector3) -> void:
	# Motion-base descent trainer: a capsule cockpit on three hydraulic legs.
	cylinder(pos + Vector3(0, 0.1, 0), 2.3, 0.2, "trim")
	cylinder(pos + Vector3(0, 0.1, 0), 2.34, 0.03, "amber")
	round_blocker(pos, 2.0, 3.2)
	var pod := Node3D.new()
	add_child(pod)
	pod.position = pos + Vector3(0, 1.25, 0)
	turned([Vector2(0.0, 0.0), Vector2(0.9, 0.08), Vector2(1.45, 0.5), Vector2(1.5, 0.85), Vector2(1.1, 1.75), Vector2(0.55, 2.2), Vector2(0.0, 2.3)], "white", Vector3.ZERO, pod)
	turned([Vector2(1.47, 0.5), Vector2(1.53, 0.68), Vector2(1.47, 0.86)], "trim", Vector3.ZERO, pod)
	for i: int in range(3):
		var angle := TAU * i / 3.0 + 0.5
		var pane := part(Vector3(sin(angle) * 1.22, 1.3, cos(angle) * 1.22), Vector3(0.7, 0.42, 0.06), "cyan", pod)
		pane.rotation = Vector3(-0.55, angle, 0)
	for i: int in range(3):
		var angle := TAU * i / 3.0
		var leg := cylinder(pos + Vector3(sin(angle) * 1.25, 0.72, cos(angle) * 1.25), 0.09, 1.3, "steel")
		leg.rotation = Vector3(cos(angle) * 0.35, 0, -sin(angle) * 0.35)
		cylinder(pos + Vector3(sin(angle) * 1.5, 0.3, cos(angle) * 1.5), 0.16, 0.5, "orange")
	spinners.append({"node": pod, "axis": Vector3.UP, "speed": 0.0, "sway": 0.05})
	box(pos + Vector3(-1.9, 0.3, 0), Vector3(0.9, 0.2, 1.1), "steel")
	box(pos + Vector3(-1.5, 0.6, 0), Vector3(0.6, 0.2, 1.1), "steel")
	sign_text("DESCENT SIMULATOR", pos + Vector3(-1.7, 3.3, 0), 30, GOLD, -PI / 2)
	station(pos + Vector3(-3.9, 0, 0.2), "simulator", "DESCENT SIMULATOR", "FLY A MARS LANDING", -PI / 2)
	point_light(pos + Vector3(-1, 3.6, 0), Color("ffe1b0"), 2.0, 8)

func high_bay() -> void:
	for x: float in [-16, 16]:
		# Wall opening to side rooms spans z = 1..11.
		box(Vector3(x, 8, 5), Vector3(0.5, 5, 26), "shell", true)
		box(Vector3(x, 2.8, -10), Vector3(0.5, 5.6, 18), "shell", true)
		box(Vector3(x, 2.8, 15), Vector3(0.5, 5.6, 8), "shell", true)
		box(Vector3(x - signf(x) * 0.3, 0.9, -10), Vector3(0.12, 1.8, 17.6), "trim")
		box(Vector3(x - signf(x) * 0.37, 1.85, -10), Vector3(0.05, 0.06, 17.6), "amber")
		for z: float in [0, 12]:
			box(Vector3(x, 3, z), Vector3(0.9, 6, 0.65), "white", true)
			box(Vector3(x - signf(x) * 0.48, 3, z), Vector3(0.06, 5.5, 0.12), "cyan")
		box(Vector3(x, 11.5, -3), Vector3(0.5, 11, 32), "shell")
	# Roof with a glazed central skylight.
	for x: float in [-12, 12]:
		box(Vector3(x, 17, -3), Vector3(8, 0.5, 32), "shell", true)
	box(Vector3(0, 17.15, -3), Vector3(16, 0.06, 32), "glass")
	for z: int in range(-18, 14, 6):
		box(Vector3(0, 16.7, z), Vector3(32, 0.65, 0.6), "steel")
		for x: float in [-15, 15]:
			if z != 6:
				box(Vector3(x, 8.5, z), Vector3(0.75, 17, 0.9), "steel", true)
				box(Vector3(x - signf(x) * 0.42, 3, z), Vector3(0.06, 5, 0.2), "light")
	for x: float in [-8.0, 0.0, 8.0]:
		box(Vector3(x, 16.9, -3), Vector3(0.3, 0.5, 32), "steel")
	# Rear exit: 8m opening connects to launch corridor.
	for x: float in [-10, 10]:
		box(Vector3(x, 8.5, -19), Vector3(12, 17, 0.6), "shell", true)
		box(Vector3(x, 4.2, -18.62), Vector3(9.5, 5.5, 0.15), "panel")
		box(Vector3(x, 7.1, -18.50), Vector3(9.5, 0.09, 0.08), "cyan")
		for vent: int in range(7):
			box(Vector3(x - 3 + vent, 1.6, -18.5), Vector3(0.45, 0.8, 0.08), "dark")
		monitor(Vector3(x, 4.6, -18.4), "VEHICLE 01  /  " + ("PROPULSION" if x < 0 else "AVIONICS"), "", 6.0, 0.0, 0 if x < 0 else 1, 1.4, 2.6)
	box(Vector3(0, 12, -19), Vector3(8, 10, 0.6), "shell", true)
	box(Vector3(0, 6.9, -18.6), Vector3(8.5, 0.15, 0.15), "cyan")
	for x: float in [-4.2, 4.2]:
		for i: int in range(6):
			box(Vector3(x, 0.5 + i, -18.62), Vector3(0.4, 0.5, 0.1), "gold" if i % 2 == 0 else "black")
	# Hero arch at the entrance to engineering.
	for x: float in [-12, 12]:
		box(Vector3(x, 5, 13), Vector3(0.7, 10, 0.7), "white", true)
		box(Vector3(x, 5, 13.37), Vector3(0.1, 9.4, 0.04), "cyan")
	box(Vector3(0, 9.7, 13), Vector3(24, 0.7, 0.8), "white")
	box(Vector3(0, 9.28, 13.45), Vector3(22, 0.08, 0.06), "cyan")
	sign_text("M O H A S H U N N Y O", Vector3(0, 8.5, 13.5), 83)
	sign_text("F R O N T I E R   /   E A R T H   O P E R A T I O N S", Vector3(0, 7.7, 13.5), 27, CYAN)
	# Direction lines guide players around the integration plinth.
	for x: float in [-6.3, 6.3]:
		box(Vector3(x, 0.014, -1), Vector3(0.07, 0.028, 30), "gold")
		for z: int in range(-14, 15, 4):
			box(Vector3(x, 0.018, z), Vector3(0.7, 0.035, 0.12), "gold")
	# Door-mounted wayfinding: cyan glass panels, readable left-to-right from either side.
	doorway_sign("01  /  OUTFITTING & CREW SYSTEMS", Vector3(-15.68, 6.25, 6), Vector3(0.10, 1.15, 7.2), -PI / 2)
	doorway_sign("04  /  MISSION CONTROL", Vector3(15.68, 6.25, 6), Vector3(0.10, 1.15, 7.2), PI / 2)
	doorway_sign("02  /  VEHICLE INTEGRATION", Vector3(0, 10.45, 13), Vector3(10.5, 1.05, 0.10), 0)
	doorway_sign("03  /  LAUNCH COMPLEX", Vector3(0, 7.5, -18.55), Vector3(8.0, 1.05, 0.10), 0)
	# Assembly plinth is floor-level; barriers guide the route around it.
	box(Vector3(0, 0.08, -3), Vector3(9, 0.16, 15), "floor_dark", true)
	for x: float in [-4.6, 4.6]:
		box(Vector3(x, 0.025, -3), Vector3(0.12, 0.05, 15.5), "amber")
		for z: int in range(-10, 5, 2):
			box(Vector3(x + signf(x) * 0.25, 0.018, z), Vector3(0.45, 0.03, 0.35), "gold", false, -0.4)
	# Horizontal flight vehicle on integration cradles.
	var ship := Node3D.new()
	ship.name = "AssemblySpacecraft"
	add_child(ship)
	ship.position = Vector3(0, 3.6, -3.4)
	ship.rotation.x = PI / 2
	rocket(ship, 0.68, false)
	for z: float in [-6, 1]:
		box(Vector3(0, 0.95, z), Vector3(4.8, 1.9, 1.2), "steel", true)
		box(Vector3(0, 1.95, z), Vector3(5, 0.15, 1.4), "gold")
		for x: float in [-1.5, 1.5]:
			box(Vector3(x, 2.3, z), Vector3(0.5, 0.7, 1.0), "trim", false, 0.0)
	blocker(Vector3(0, 2.35, -3), Vector3(3.6, 4.7, 12.5))
	for data: Array in [[Vector3(-4.0, 0.16, -6.4), 0.0, 0.0], [Vector3(4.0, 0.16, -6.4), PI, 1.7], [Vector3(-4.0, 0.16, 0.6), 0.0, 3.1], [Vector3(4.0, 0.16, 0.6), PI, 4.4]]:
		robot_arm(data[0], data[1], data[2])
	spot_light(Vector3(-7, 15.5, 4), Vector3(0, 3.5, -3), Color("fff1dc"), 5.0, 26, 34, true)
	spot_light(Vector3(7, 15.5, -10), Vector3(0, 3.5, -3), Color("dcefff"), 4.0, 26, 34, false)
	# Crane rails, trolley and hook block.
	for x: float in [-11, 11]:
		box(Vector3(x, 12, -3), Vector3(0.5, 0.6, 29), "gold")
	box(Vector3(0, 12, -5), Vector3(22, 0.8, 1.1), "gold")
	box(Vector3(0, 11.4, -5), Vector3(1.6, 0.5, 1.5), "trim")
	for x: float in [-0.3, 0.3]: box(Vector3(x, 9.7, -5), Vector3(0.05, 3.0, 0.05), "steel")
	box(Vector3(0, 8.1, -5), Vector3(0.9, 0.5, 0.4), "gold")
	cylinder(Vector3(0, 7.7, -5), 0.22, 0.3, "steel")
	blinkers.append({"node": point_light(Vector3(0, 11.0, -5), Color("ffb347"), 1.5, 6), "rate": 2.0, "base": 1.5})
	for x: float in [-10, 10]:
		for z: float in [-11, -4]:
			workbench(Vector3(x, 0, z))
	# Staged cargo and tool carts.
	for data: Array in [[Vector3(12.6, 0, 9.4), "orange"], [Vector3(13.4, 0, -15.5), "steel"], [Vector3(-13.2, 0, -16.2), "orange"], [Vector3(-12.8, 0, 9.2), "steel"]]:
		var at: Vector3 = data[0]
		box(at + Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 1.3), data[1], true)
		box(at + Vector3(0, 0.45, 0.66), Vector3(1.0, 0.5, 0.03), "black")
		box(at + Vector3(0.1, 1.2, -0.1), Vector3(0.9, 0.6, 0.9), "trim" if data[1] == "orange" else "orange")
	# Integration stack light beside the review console: one lamp per cleared procedure.
	box(Vector3(5.4, 1.2, 7), Vector3(0.3, 2.4, 0.3), "trim", true)
	for i: int in range(3):
		var lamp := part(Vector3(5.4, 1.5 + i * 0.5, 7.17), Vector3(0.36, 0.32, 0.06), "lamp_off", self)
		status_lamps.append(lamp)
	sign_text("INTEGRATION\nSTATUS", Vector3(5.4, 3.0, 7.17), 16, Color("c4dbe5"))
	station(Vector3(8, 0, 7), "engineering", "VEHICLE INTEGRATION", "ISOLATE / VERIFY / CLEAR")
	sign_text("VEHICLE 01\nINTEGRATION IN PROGRESS", Vector3(-9, 5.2, -18.2), 35, GOLD)

func robot_arm(pos: Vector3, yaw: float, phase: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation.y = yaw
	cylinder(Vector3(0, 0.2, 0), 0.5, 0.4, "trim", -1, root)
	cylinder(Vector3(0, 0.3, 0), 0.52, 0.05, "amber", -1, root)
	round_blocker(pos, 0.5, 1.0)
	var turret := Node3D.new()
	root.add_child(turret)
	turret.position.y = 0.45
	cylinder(Vector3(0, 0.25, 0), 0.34, 0.5, "orange", -1, turret)
	var shoulder := Node3D.new()
	turret.add_child(shoulder)
	shoulder.position.y = 0.55
	ball(Vector3.ZERO, 0.3, mats.trim, shoulder)
	part(Vector3(0, 1.2, 0), Vector3(0.3, 2.4, 0.3), "orange", shoulder)
	part(Vector3(0, 1.2, 0.16), Vector3(0.1, 2.0, 0.04), "black", shoulder)
	var elbow := Node3D.new()
	shoulder.add_child(elbow)
	elbow.position.y = 2.4
	ball(Vector3.ZERO, 0.24, mats.trim, elbow)
	part(Vector3(0, 1.0, 0), Vector3(0.22, 2.0, 0.22), "white", elbow)
	var tool := Node3D.new()
	elbow.add_child(tool)
	tool.position.y = 2.0
	cylinder(Vector3(0, 0.15, 0), 0.1, 0.3, "steel", -1, tool)
	ball(Vector3(0, 0.34, 0), 0.06, mats.cyan, tool)
	var sparks: CPUParticles3D = Gfx.emitter({"amount": 26, "life": 0.5, "speed": Vector2(2, 5), "size": Vector2(0.03, 0.07), "spread": 70.0, "gravity": Vector3(0, -9, 0), "colors": [Color(1, 0.95, 0.7, 1), Color(1, 0.55, 0.15, 0.9), Color(1, 0.3, 0.05, 0)], "additive": true, "grow": Vector2(1, 0.3), "emitting": false})
	tool.add_child(sparks)
	sparks.position.y = 0.38
	var flash := OmniLight3D.new()
	flash.light_color = Color("9fd8ff")
	flash.omni_range = 5.0
	flash.light_energy = 0.0
	flash.shadow_enabled = false
	tool.add_child(flash)
	flash.position.y = 0.4
	arms.append({"turret": turret, "shoulder": shoulder, "elbow": elbow, "phase": phase, "sparks": sparks, "flash": flash})

func monitor(pos: Vector3, title: String, body: String, width: float = 3.8, yaw: float = 0.0, mode: int = -1, gain: float = 0.9, height: float = 1.8) -> void:
	box(pos, Vector3(width, height, 0.14), "black", false, yaw)
	var basis := Basis(Vector3.UP, yaw)
	var normal := basis * Vector3(0, 0, 0.08)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width - 0.14, height - 0.16)
	face.mesh = quad
	screen_seed += 1.37
	var chosen := mode if mode >= 0 else int(screen_seed) % 5
	var display: ShaderMaterial = Gfx.screen(CYAN if int(screen_seed * 3.0) % 4 != 0 else GOLD, chosen, screen_seed)
	display.set_shader_parameter("gain", gain)
	face.material_override = display
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(face)
	face.position = pos + normal
	face.rotation.y = yaw
	if title != "":
		var heading := sign_text(title, pos + normal * 1.3 + Vector3(0, height * 0.5 - 0.42, 0), 26, Color("e6fbff"), yaw)
		heading.outline_size = 8
		heading.outline_modulate = Color(0.01, 0.06, 0.09, 0.9)
	if body != "":
		var caption := sign_text(body, pos + normal * 1.3 + Vector3(0, -0.24, 0), 18, Color("c4dbe5"), yaw)
		caption.outline_size = 8
		caption.outline_modulate = Color(0.01, 0.06, 0.09, 0.9)

func workbench(pos: Vector3) -> void:
	box(pos + Vector3(0, 0.9, 0), Vector3(3.8, 0.18, 1.7), "metal", true)
	for x: float in [-1.5, 1.5]:
		box(pos + Vector3(x, 0.4, 0), Vector3(0.18, 0.8, 1.4), "steel", true)
	for i: int in range(3):
		box(pos + Vector3(-1 + i, 1.12, 0), Vector3(0.6, 0.25, 0.8), "orange" if i == 0 else "black")
	box(pos + Vector3(0, 0.99, 0.84), Vector3(3.6, 0.03, 0.03), "cyan")
	monitor(pos + Vector3(0, 2, -0.5), "SYSTEM DIAGNOSTICS", "", 3.0, 0.0, -1, 1.3)

func station(pos: Vector3, id: String, title: String, subtitle: String, yaw: float = 0.0) -> void:
	var basis := Basis(Vector3.UP, yaw)
	box(pos + Vector3(0, 0.6, 0), Vector3(2.4, 1.2, 1.1), "trim", true, yaw)
	box(pos + Vector3(0, 1.24, 0), Vector3(2.6, 0.08, 1.3), "steel", false, yaw)
	box(pos + basis * Vector3(0, 0.7, 0.56), Vector3(1.9, 0.07, 0.03), "cyan", false, yaw)
	box(pos + basis * Vector3(0, 1.3, 0.25), Vector3(1.3, 0.04, 0.42), "black", false, yaw)
	box(pos + basis * Vector3(0, 0.03, 1.5), Vector3(2.2, 0.03, 1.4), "cyan", false, yaw)
	box(pos + basis * Vector3(0, 0.035, 1.5), Vector3(2.0, 0.035, 1.2), "floor_dark", false, yaw)
	monitor(pos + basis * Vector3(0, 2.25, -0.1), title, subtitle + "\n[ E ]  OPEN", 3.4, yaw, 4, 0.3)
	stations.append({"id": id, "title": title, "position": pos + Vector3(0, 2.25, 0), "stand": pos + basis * Vector3(0, 0, 1.5)})

func outfitting() -> void:
	# West wall is glazed above a sill: afternoon light crosses the display floor.
	box(Vector3(-32, 0.6, 6), Vector3(0.5, 1.2, 24), "trim")
	box(Vector3(-32, 6.9, 6), Vector3(0.5, 2.2, 24), "shell")
	box(Vector3(-32, 3.5, 6), Vector3(0.06, 4.6, 24), "glass")
	for i: int in range(7):
		box(Vector3(-32, 3.5, -6 + i * 4.0), Vector3(0.3, 4.6, 0.2), "steel")
	blocker(Vector3(-32, 4, 6), Vector3(0.5, 8, 24))
	for z: float in [-6, 18]:
		box(Vector3(-24, 4, z), Vector3(16, 8, 0.5), "shell", true)
	box(Vector3(-24, 8.1, 6), Vector3(16, 0.3, 24), "dark", true)
	box(Vector3(-24, 0.02, 6), Vector3(15.4, 0.04, 23.4), "floor_dark")
	for z: float in [-3, 3, 9, 15]:
		box(Vector3(-24, 7.8, z), Vector3(12, 0.08, 0.35), "warm")
	# Storage racks along the north wall.
	for i: int in range(3):
		var x: float = -29.0 + i * 4.8
		box(Vector3(x, 1.7, -4.3), Vector3(3.4, 3.4, 1.2), "trim", true)
		for y: float in [0.3, 1.7, 3.1]:
			box(Vector3(x, y, -4.2), Vector3(3.5, 0.1, 1.4), "metal")
			box(Vector3(x, y + 0.1, -3.48), Vector3(3.3, 0.035, 0.03), "cyan")
		for n: int in range(3):
			box(Vector3(x - 1 + n, 0.9, -4.1), Vector3(0.65, 0.9, 0.6), "white" if (i + n) % 2 == 0 else "orange")
			box(Vector3(x - 1 + n, 2.2, -4.1), Vector3(0.7, 0.7, 0.7), "steel" if (i + n) % 2 == 0 else "gold")
		sign_text(["LIFE SUPPORT", "POWER SYSTEMS", "SCIENCE PAYLOAD"][i], Vector3(x, 3.9, -3.5), 23, GOLD)
	# Field hardware on lit plinths: the same authored models the crew deploys on Mars.
	var art := preload("res://scripts/field_hardware.gd").new()
	var shown := ["solar", "oxygen", "habitat"]
	for i: int in range(3):
		var at := Vector3(-29.4 + i * 3.1, 0, 0.2)
		cylinder(at + Vector3(0, 0.2, 0), 1.15, 0.4, "black")
		cylinder(at + Vector3(0, 0.3, 0), 1.18, 0.03, "cyan")
		round_blocker(at, 1.15, 1.6)
		var model: Node3D = art.make(shown[i])
		add_child(model)
		model.position = at + Vector3(0, 0.42, 0)
		model.scale = Vector3.ONE * [0.42, 0.62, 0.36][i]
		spinners.append({"node": model, "axis": Vector3.UP, "speed": 0.25})
		sign_text(["HELIOS ARRAY", "AERIS OXYGEN", "HAVEN SHELTER"][i], at + Vector3(0, 0.22, 1.17), 15, Color("d9ffff"))
		spot_light(at + Vector3(0, 7.4, 0.6), at + Vector3(0, 1, 0), Color("fff2dc"), 5.0, 9, 24)
	# Pressurised rover on a turntable.
	var turntable := Node3D.new()
	add_child(turntable)
	turntable.position = Vector3(-25, 0, 9.5)
	cylinder(Vector3(0, 0.12, 0), 2.9, 0.24, "black", -1, turntable)
	cylinder(Vector3(0, 0.14, 0), 2.95, 0.03, "amber", -1, turntable)
	round_blocker(Vector3(-25, 0, 9.5), 2.9, 2.6)
	if ResourceLoader.exists("res://assets/vehicles/sev.glb"):
		var vehicle: Node3D = load("res://assets/vehicles/sev.glb").instantiate()
		turntable.add_child(vehicle)
		var bounds := AABB()
		var first := true
		for node: Node in vehicle.find_children("*", "MeshInstance3D", true, false):
			var relative: Transform3D = turntable.global_transform.affine_inverse() * node.global_transform
			var aabb: AABB = relative * node.mesh.get_aabb()
			bounds = aabb if first else bounds.merge(aabb)
			first = false
		var factor := 4.4 / maxf(bounds.size.x, bounds.size.z)
		vehicle.scale *= factor
		vehicle.position = Vector3(-bounds.get_center().x * factor, 0.26 - bounds.position.y * factor, -bounds.get_center().z * factor)
	spinners.append({"node": turntable, "axis": Vector3.UP, "speed": 0.12})
	spot_light(Vector3(-25, 7.6, 12), Vector3(-25, 1, 9.5), Color("fff0d8"), 8.0, 12, 30, true)
	sign_text("SURFACE ROVER  /  NASA SEV CONCEPT MODEL", Vector3(-25, 5.6, 17.7), 26, GOLD, PI)
	# Suit lockers along the glazed wall, each a lit glass tube.
	for i: int in range(3):
		var at := Vector3(-30.3, 0, 3.4 + i * 2.6)
		cylinder(at + Vector3(0, 0.15, 0), 0.8, 0.3, "trim")
		cylinder(at + Vector3(0, 2.75, 0), 0.8, 0.14, "trim")
		cylinder(at + Vector3(0, 0.31, 0), 0.74, 0.03, "cyan")
		var tube := cylinder(at + Vector3(0, 1.5, 0), 0.76, 2.4, "glass")
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		round_blocker(at, 0.8, 2.8)
		if ResourceLoader.exists("res://assets/characters/explorer_z2.glb"):
			var suit: Node3D = load("res://assets/characters/explorer_z2.glb").instantiate()
			add_child(suit)
			suit.position = at + Vector3(0, 0.32, 0)
			suit.rotation.y = PI / 2
			suit.scale = Vector3.ONE * 0.98
			var players := suit.find_children("*", "AnimationPlayer", true, false)
			if not players.is_empty(): players[0].play("idle")
		point_light(at + Vector3(0.3, 2.5, 0), Color("bfe9ff"), 1.4, 3.5)
	sign_text("EVA SUIT LOCKERS", Vector3(-31.6, 4.3, 6), 30, CYAN, PI / 2)
	station(Vector3(-29.6, 0, 12.4), "crew", "CREW LOCKER", "CHOOSE YOUR COMMANDER", PI / 2)
	station(Vector3(-21, 0, 13), "shop", "MISSION OUTFITTER", "ROCKET / OUTPOST / FIELD KITS")

func control_room() -> void:
	box(Vector3(32, 4, 6), Vector3(0.5, 8, 24), "shell", true)
	for z: float in [-6, 18]:
		box(Vector3(24, 4, z), Vector3(16, 8, 0.5), "shell", true)
	box(Vector3(24, 8.1, 6), Vector3(16, 0.3, 24), "dark", true)
	box(Vector3(24, 0.03, 6), Vector3(15.4, 0.06, 23.4), "floor_dark")
	for x: float in [17.0, 31.0]: box(Vector3(x, 0.09, 6), Vector3(0.06, 0.04, 21), "cyan")
	# Main display wall: one large flight plot, paired telemetry columns.
	box(Vector3(24, 4.5, -5.6), Vector3(14.6, 6.2, 0.2), "black")
	monitor(Vector3(24, 4.4, -5.45), "", "", 8.4, 0.0, 3, 1.7, 4.6)
	sign_text("F R O N T I E R   /   M I S S I O N   C O N T R O L", Vector3(24, 7.25, -5.35), 30, Color("d8e7e9"))
	sign_text("EARTH DEPARTURE     →     MARS ARRIVAL", Vector3(24, 6.2, -5.25), 22, CYAN)
	sign_text("TRANSFER CONCEPT / NOT TO SCALE", Vector3(24, 2.5, -5.25), 18, Color("799eaa"))
	for x: float in [18.3, 29.7]:
		for row: int in range(3):
			monitor(Vector3(x, 2.9 + row * 1.5, -5.3), ["VEHICLE STATUS", "LIFE SUPPORT", "GROUND NETWORK"][row], "", 2.6, 0.0, [0, 1, 2][row], 1.3, 1.36)
	# Paired operator islands preserve the central and cross-room circulation aisles.
	for x: float in [20.0, 28.0]:
		for z: float in [0.0, 8.0]:
			box(Vector3(x, 0.56, z), Vector3(4.1, 1.12, 1.4), "control_graphite", true)
			box(Vector3(x, 1.18, z), Vector3(4.4, 0.14, 1.9), "steel")
			for offset: float in [-1.05, 1.05]:
				monitor(Vector3(x + offset, 1.95, z - 0.48), "", "", 1.9, 0.0, -1, 1.2, 1.2)
				box(Vector3(x + offset, 1.29, z + 0.34), Vector3(0.92, 0.045, 0.34), "black")
				for key: int in range(6): box(Vector3(x + offset - 0.34 + key * 0.13, 1.32, z + 0.35), Vector3(0.07, 0.02, 0.19), "steel")
				cylinder(Vector3(x + offset, 0.44, z + 1.55), 0.33, 0.08, "black")
				cylinder(Vector3(x + offset, 0.67, z + 1.55), 0.055, 0.45, "steel")
				box(Vector3(x + offset, 0.93, z + 1.55), Vector3(0.64, 0.12, 0.6), "control_fabric")
				box(Vector3(x + offset, 1.3, z + 1.85), Vector3(0.64, 0.7, 0.12), "control_fabric")
			box(Vector3(x, 1.0, z + 0.75), Vector3(4.2, 0.04, 0.03), "cyan")
	for z: float in [-1.0, 5.0, 12.0]:
		box(Vector3(31.6, 3.5, z), Vector3(0.12, 5.4, 4.2), "control_graphite")
		for j: int in range(9): box(Vector3(31.48, 1.25 + j * 0.45, z), Vector3(0.08, 0.12, 3.7), "steel")
		box(Vector3(31.42, 6.3, z), Vector3(0.05, 0.08, 3.9), "cyan")
	for x: float in [20.0, 28.0]:
		box(Vector3(x, 7.6, 6), Vector3(0.18, 0.06, 20), "light")
		point_light(Vector3(x, 4.5, 5), Color("b2d8e2"), 1.6, 10)
	point_light(Vector3(24, 4, -3), Color("7fd9e6"), 2.4, 12)
	sign_text("FLIGHT DIRECTOR / OPERATIONS", Vector3(24, 5.2, 17.65), 28, GOLD, PI)
	terrain_table(Vector3(24, 0, 10.9))
	station(Vector3(18.6, 0, 15.2), "briefing", "FLIGHT DIRECTOR", "MISSION BRIEFING", PI)
	station(Vector3(24, 0, 15.2), "science", "NASA FLIGHT LAB", "THREE FLIGHT CALCULATIONS", PI)
	station(Vector3(29.4, 0, 15.2), "field_systems", "FIELD SYSTEMS", "DEPLOY / ASSEMBLE / EXPAND", PI)

func terrain_table(pos: Vector3) -> void:
	# Holographic relief built from the same NASA MOLA crop that shapes the Mars terrain.
	cylinder(pos + Vector3(0, 0.45, 0), 1.45, 0.9, "black")
	cylinder(pos + Vector3(0, 0.8, 0), 1.5, 0.04, "cyan")
	round_blocker(pos, 1.5, 1.4)
	var path := "res://assets/mola/isidis.json"
	if not FileAccess.file_exists(path): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var heights: Array = data.heights
	var low := INF
	var high := -INF
	for row: Array in heights:
		for value: Variant in row:
			low = minf(low, float(value)); high = maxf(high, float(value))
	var count: int = mini(heights.size(), 65)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := 2.3
	var relief := 0.42
	for z: int in range(count - 1):
		for x: int in range(count - 1):
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var cx: int = x + corner.x
				var cz: int = z + corner.y
				var h: float = (float(heights[cz][cx]) - low) / maxf(1.0, high - low)
				st.add_vertex(Vector3((float(cx) / (count - 1) - 0.5) * span, h * relief, (float(cz) / (count - 1) - 0.5) * span))
	var relief_mesh := MeshInstance3D.new()
	relief_mesh.mesh = st.commit()
	var holo := ShaderMaterial.new()
	holo.shader = Gfx.shader("relief", """shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float relief = 0.42;
varying float hh;
void vertex(){hh=VERTEX.y/relief;}
void fragment(){
	float lines=smoothstep(0.38,0.5,abs(fract(hh*14.0+TIME*0.05)-0.5));
	vec3 c=mix(vec3(0.05,0.5,0.7),vec3(1.0,0.55,0.2),clamp(hh*1.15,0.0,1.0));
	ALBEDO=c*(0.4+lines*1.9);
}""")
	relief_mesh.material_override = holo
	relief_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(relief_mesh)
	relief_mesh.position = pos + Vector3(0, 1.05, 0)
	spinners.append({"node": relief_mesh, "axis": Vector3.UP, "speed": 0.1})
	for i: int in range(2):
		var marker := turned([Vector2(0.0, 0.0), Vector2(0.05, 0.16)], "amber" if i == 0 else "cyan", Vector3([0.0, -0.15][i], 0.5, [0.06, 0.15][i]), relief_mesh, 12)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var caption := sign_text("ISIDIS REGION  /  NASA MGS MOLA TOPOGRAPHY", pos + Vector3(0, 2.0, 0), 20, Color("d9ffff"))
	caption.pixel_size = 0.0035
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.outline_size = 6
	caption.outline_modulate = Color(0.02, 0.08, 0.1)
	point_light(pos + Vector3(0, 1.8, 0), Color("69e4ff"), 1.8, 6)

func rocket(parent: Node3D, scale_factor: float = 1.0, flight_ready: bool = true) -> void:
	parent.scale = Vector3.ONE * scale_factor
	# Core: first stage, interstage, upper stage and an ogive fairing.
	turned([Vector2(1.72, -5.9), Vector2(1.6, -5.2), Vector2(1.6, 1.2)], "white", Vector3.ZERO, parent)
	turned([Vector2(1.6, 1.2), Vector2(1.47, 1.5), Vector2(1.47, 1.9)], "black", Vector3.ZERO, parent)
	turned([Vector2(1.47, 1.9), Vector2(1.47, 4.4)], "white", Vector3.ZERO, parent)
	turned([Vector2(1.47, 4.4), Vector2(1.74, 4.9), Vector2(1.74, 5.9), Vector2(1.55, 6.9), Vector2(1.12, 7.8), Vector2(0.55, 8.45), Vector2(0.0, 8.7)], "panel", Vector3.ZERO, parent)
	for y: float in [-4.6, -2.6, -0.4, 2.6, 3.6]:
		turned([Vector2(1.615 if y < 1.5 else 1.485, y), Vector2(1.615 if y < 1.5 else 1.485, y + 0.14)], "steel", Vector3.ZERO, parent)
	turned([Vector2(1.62, -1.9), Vector2(1.62, -0.9)], "black", Vector3.ZERO, parent)
	turned([Vector2(1.75, 5.2), Vector2(1.75, 5.32)], "orange", Vector3.ZERO, parent)
	# Engine cluster.
	turned([Vector2(0.0, -5.9), Vector2(1.72, -5.9)], "black", Vector3.ZERO, parent)
	var bell := [Vector2(0.22, 0.0), Vector2(0.26, -0.25), Vector2(0.4, -0.6), Vector2(0.52, -1.0)]
	for p: Vector2 in [Vector2(0, 0), Vector2(0.95, 0), Vector2(-0.95, 0), Vector2(0, 0.95), Vector2(0, -0.95)]:
		turned(bell, "nozzle", Vector3(p.x, -5.9, p.y), parent, 20)
	# Strap-on boosters with their own nozzles.
	for x: float in [-2.25, 2.25]:
		turned([Vector2(0.66, -5.7), Vector2(0.62, -5.3), Vector2(0.62, 2.2), Vector2(0.4, 3.2), Vector2(0.0, 3.75)], "panel", Vector3(x, 0, 0), parent, 24)
		turned([Vector2(0.63, -3.2), Vector2(0.63, -2.6)], "black", Vector3(x, 0, 0), parent, 24)
		turned([Vector2(0.63, 1.4), Vector2(0.63, 1.55)], "orange", Vector3(x, 0, 0), parent, 24)
		turned([Vector2(0.2, 0.0), Vector2(0.3, -0.4), Vector2(0.46, -0.9)], "nozzle", Vector3(x, -5.7, 0), parent, 20)
		for y: float in [-3.8, 1.0]:
			part(Vector3(x * 0.84, y, 0), Vector3(0.5, 0.16, 0.3), "steel", parent)
	# Fins, cable raceway and livery.
	for i: int in range(4):
		var angle := PI / 4 + i * PI / 2
		var fin := part(Vector3(sin(angle) * 1.95, -5.0, cos(angle) * 1.95), Vector3(0.08, 1.5, 0.9), "trim", parent)
		fin.rotation.y = angle
	part(Vector3(0, -1.6, -1.62), Vector3(0.22, 6.6, 0.1), "trim", parent)
	for face: float in [0.0, PI]:
		var text := Label3D.new()
		text.text = "FRONTIER\n01"
		text.font_size = 70
		text.pixel_size = 0.007
		text.outline_size = 0
		text.modulate = Color("16354d")
		text.position = Vector3(0, 0.3, 1.62).rotated(Vector3.UP, face + 0.5)
		text.rotation.y = face + 0.5
		parent.add_child(text)
	if flight_ready:
		var tip := OmniLight3D.new()
		tip.light_color = Color("ff5a48")
		tip.omni_range = 4.0
		tip.light_energy = 2.0
		tip.position = Vector3(0, 8.9, 0)
		parent.add_child(tip)
		blinkers.append({"node": tip, "rate": 1.2, "base": 2.5})

func launch_complex() -> void:
	box(Vector3(0, -0.15, -27), Vector3(8, 0.3, 16), "metal", true)
	for x: float in [-4, 4]:
		box(Vector3(x, 1.1, -27), Vector3(0.2, 0.15, 16), "steel", true)
		for z: int in range(-34, -18, 3):
			box(Vector3(x, 0.55, z), Vector3(0.15, 1.1, 0.15), "steel", true)
		box(Vector3(x * 0.9, 0.03, -27), Vector3(0.07, 0.06, 16), "cyan")
		for z: int in range(-33, -19, 4):
			box(Vector3(x, 1.3, z), Vector3(0.14, 0.14, 0.14), "amber")
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
	# Pad deck, hazard ring and flame trench.
	cylinder(Vector3(0, 0.35, -50), 7, 0.7, "dark")
	cylinder(Vector3(0, 0.71, -50), 6.6, 0.03, "gold")
	cylinder(Vector3(0, 0.72, -50), 6.0, 0.035, "dark")
	cylinder(Vector3(0, 0.73, -50), 2.6, 0.04, "black")
	round_blocker(Vector3(0, 0, -50), 6.8, 1.0)
	for i: int in range(12):
		var angle := TAU * i / 12.0
		var lamp := ball(Vector3(sin(angle) * 6.8, 0.75, -50 + cos(angle) * 6.8), 0.1, mats.red if i % 2 == 0 else mats.amber)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ship := Node3D.new()
	ship.name = "LaunchVehicle"
	add_child(ship)
	launch_vehicle = ship
	ship.position = Vector3(0, 10.5, -50)
	rocket(ship, 1.4)
	# Service tower: braced lattice with decks and a swinging crew access arm.
	for x: float in [7, 11]:
		for z: float in [-53, -49]:
			box(Vector3(x, 13.5, z), Vector3(0.5, 27, 0.5), "steel", true)
	for y: int in range(3, 28, 3):
		box(Vector3(9, y, -51), Vector3(4.5, 0.2, 4.5), "metal")
		box(Vector3(9, y + 1, -48.7), Vector3(4, 0.1, 0.1), "gold")
		box(Vector3(9, y + 1, -53.3), Vector3(4, 0.1, 0.1), "gold")
		for side: float in [-48.75, -53.25]:
			var brace := part(Vector3(9, y - 1.5, side), Vector3(5.0, 0.12, 0.12), "steel", self)
			brace.rotation.z = 0.59 if (y / 3) % 2 == 0 else -0.59
	box(Vector3(9, 27.6, -51), Vector3(5, 0.4, 5), "trim")
	cylinder(Vector3(9, 31, -51), 0.08, 6.5, "steel")
	blinkers.append({"node": point_light(Vector3(9, 34.4, -51), Color("ff4433"), 3.0, 9), "rate": 0.8, "base": 3.0})
	ball(Vector3(9, 34.3, -51), 0.18, mats.red)
	service_arm = Node3D.new()
	add_child(service_arm)
	service_arm.position = Vector3(7, 20.4, -51)
	part(Vector3(-2.3, 0, 0), Vector3(4.6, 0.5, 1.3), "gold", service_arm)
	part(Vector3(-2.3, 0.9, 0.62), Vector3(4.6, 0.08, 0.06), "steel", service_arm)
	part(Vector3(-2.3, 0.9, -0.62), Vector3(4.6, 0.08, 0.06), "steel", service_arm)
	part(Vector3(-4.4, 0.6, 0), Vector3(0.5, 1.6, 1.5), "white", service_arm)
	# Flood towers and lightning masts.
	for x: float in [-16, 16]:
		box(Vector3(x, 9, -59), Vector3(0.45, 18, 0.45), "steel", true)
		box(Vector3(x, 18, -59), Vector3(2.4, 0.5, 1), "light")
		spot_light(Vector3(x, 18, -58.4), Vector3(0, 12, -50), Color("fff0ce"), 4.5, 40, 30, x < 0)
	for x: float in [-17.5, 17.5]:
		box(Vector3(x, 15, -40), Vector3(0.3, 30, 0.3), "steel")
		ball(Vector3(x, 30.2, -40), 0.15, mats.red)
		blinkers.append({"node": point_light(Vector3(x, 30.2, -40), Color("ff4433"), 2.0, 7), "rate": 1.0 + absf(x) * 0.01, "base": 2.0})
	station(Vector3(-10, 0, -41), "launch", "LAUNCH CONTROL", "GO / NO-GO  /  TERMINAL COUNT")
	# Propellant farm with frost-white spheres and feed lines.
	for i: int in range(3):
		var tank_x: float = -31.0 - i * 7.0
		ball(Vector3(tank_x, 4.6, -52), 2.9, mats.panel)
		for leg: Vector2 in [Vector2(-1.6, -1.6), Vector2(1.6, -1.6), Vector2(-1.6, 1.6), Vector2(1.6, 1.6)]:
			cylinder(Vector3(tank_x + leg.x, 1.2, -52 + leg.y), 0.14, 2.6, "steel")
		box(Vector3(tank_x, 0.1, -52), Vector3(6.4, 0.2, 6.4), "dark")
		cylinder(Vector3(tank_x, 7.7, -52), 0.25, 0.5, "steel")
	var feed := cylinder(Vector3(-14.5, 0.45, -52), 0.16, 27, "steel")
	feed.rotation.z = PI / 2
	sign_text("LC-01", Vector3(9, 25.6, -48.6), 150, Color("f4f7f8"))
	# Launch effects are created once and switched on at ignition.
	pad_smoke = Gfx.emitter({"amount": 800, "life": 6.0, "speed": Vector2(6, 21), "size": Vector2(4.0, 9.0), "dir": Vector3(1, 0.12, 0), "spread": 180.0, "gravity": Vector3(0, 1.6, 0), "damping": 2.2, "colors": [Color(1.0, 0.8, 0.55, 0.0), Color(1.0, 0.86, 0.7, 0.5), Color(0.86, 0.86, 0.88, 0.4), Color(0.6, 0.62, 0.66, 0.0)], "grow": Vector2(0.5, 2.6), "radius": 2.5, "emitting": false})
	pad_smoke.flatness = 0.86
	add_child(pad_smoke)
	pad_smoke.position = Vector3(0, 1.6, -50)
	pad_sparks = Gfx.emitter({"amount": 90, "life": 1.3, "speed": Vector2(9, 24), "size": Vector2(0.12, 0.3), "dir": Vector3(0, 0.3, 0), "spread": 180.0, "gravity": Vector3(0, -9, 0), "colors": [Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.1, 0.9), Color(1, 0.2, 0.0, 0)], "additive": true, "grow": Vector2(1, 0.2), "radius": 1.5, "emitting": false})
	add_child(pad_sparks)
	pad_sparks.position = Vector3(0, 1.4, -50)

func make_guide() -> void:
	guide = Node3D.new()
	guide.name = "ObjectiveGuide"
	add_child(guide)
	var beam := cylinder(Vector3(0, 7, 0), 0.5, 14, "cyan", -1, guide)
	beam.material_override = Gfx.hologram(CYAN, 0.2)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.05
	ring.mesh = torus
	ring.material_override = Gfx.emissive(CYAN, 3.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.08
	guide.add_child(ring)
	guide.hide()

func station_by_id(id: String) -> Dictionary:
	for entry: Dictionary in stations:
		if str(entry.id) == id: return entry
	return {}

func point_guide(id: String) -> void:
	var entry := station_by_id(id)
	guide.visible = not entry.is_empty()
	if not entry.is_empty(): guide.position = entry.stand

func set_integration(level: int) -> void:
	integration_level = clampi(level, 0, 3)
	for i: int in range(status_lamps.size()):
		status_lamps[i].material_override = mats.green if i < integration_level else mats.lamp_off

func _process(delta: float) -> void:
	clock += delta
	for entry: Dictionary in spinners:
		var node: Node3D = entry.node
		if not is_instance_valid(node): continue
		if entry.has("sway"):
			node.rotation.x = sin(clock * 0.9) * float(entry.sway)
			node.rotation.z = cos(clock * 0.7) * float(entry.sway)
		else:
			node.rotate_object_local(entry.axis, float(entry.speed) * delta)
	for entry: Dictionary in blinkers:
		var light: Light3D = entry.node
		light.light_energy = float(entry.base) if fmod(clock * float(entry.rate), 1.0) < 0.45 else 0.0
	if is_instance_valid(guide) and guide.visible:
		guide.rotation.y += delta * 0.8
		guide.scale = Vector3(1.0 + sin(clock * 3.0) * 0.08, 1, 1.0 + sin(clock * 3.0) * 0.08)
	# Arms solve a two-link reach toward a point sweeping over the hull.
	var busy := integration_level < 3
	for arm: Dictionary in arms:
		var phase: float = arm.phase
		var t := clock * (0.55 if busy else 0.12) + phase
		var turret: Node3D = arm.turret
		turret.rotation.y = sin(t * 0.7) * 0.42
		var reach_x := 2.75 + sin(t * 1.3) * 0.25 if busy else 1.6
		var reach_y := 2.5 + sin(t) * 0.9 if busy else 3.4
		var distance := clampf(Vector2(reach_x, reach_y).length(), 0.6, 4.35)
		var to_target := atan2(reach_x, reach_y)
		var inner := acos(clampf((2.4 * 2.4 + distance * distance - 2.0 * 2.0) / (2.0 * 2.4 * distance), -1, 1))
		var bend := acos(clampf((2.4 * 2.4 + 2.0 * 2.0 - distance * distance) / (2.0 * 2.4 * 2.0), -1, 1))
		var shoulder: Node3D = arm.shoulder
		var elbow: Node3D = arm.elbow
		shoulder.rotation.z = -(to_target - inner)
		elbow.rotation.z = -(PI - bend)
		var welding := busy and fmod(t, 5.0) < 1.6
		var sparks: CPUParticles3D = arm.sparks
		sparks.emitting = welding
		var flash: OmniLight3D = arm.flash
		flash.light_energy = (2.5 + sin(clock * 55.0) * 1.5) if welding else 0.0

func ignite() -> void:
	if ignited or not is_instance_valid(launch_vehicle): return
	ignited = true
	var plume: ShaderMaterial = Gfx.plume(Color("fff3d2"), Color("ff6a1e"))
	plume.set_shader_parameter("reach", 6.5)
	for p: Vector2 in [Vector2(0, 0), Vector2(0.95, 0), Vector2(-0.95, 0), Vector2(0, 0.95), Vector2(0, -0.95), Vector2(2.25, 0), Vector2(-2.25, 0)]:
		var flame := MeshInstance3D.new()
		flame.mesh = Gfx.plume_mesh(0.5, 6.5)
		flame.material_override = plume
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = Vector3(p.x, -6.7, p.y)
		launch_vehicle.add_child(flame)
		engine_flames.append(flame)
	pad_light = OmniLight3D.new()
	pad_light.light_color = Color("ff9b43")
	pad_light.light_energy = 16.0
	pad_light.omni_range = 48.0
	pad_light.light_volumetric_fog_energy = 2.0
	pad_light.position = Vector3(0, -8.5, 0)
	launch_vehicle.add_child(pad_light)
	pad_smoke.emitting = true
	pad_sparks.emitting = true

func start_liftoff() -> void:
	if liftoff_active or not is_instance_valid(launch_vehicle): return
	ignite()
	liftoff_active = true
	launch_velocity = 0.8

func update_liftoff(delta: float) -> void:
	if ignited and is_instance_valid(service_arm):
		service_arm.rotation.y = lerp_angle(service_arm.rotation.y, -1.35, 1 - exp(-delta * 1.4))
	if ignited and is_instance_valid(pad_light):
		pad_light.light_energy = 14.0 + sin(Time.get_ticks_msec() * 0.03) * 3.0
	if not liftoff_active or not is_instance_valid(launch_vehicle): return
	launch_velocity = minf(46.0, launch_velocity + 3.4 * delta)
	launch_vehicle.position.y += launch_velocity * delta
	var pulse := 0.9 + sin(Time.get_ticks_msec() * 0.025) * 0.1
	for flame: Node3D in engine_flames: flame.scale = Vector3(1.0 + (1 - pulse), pulse * (1.0 + minf(1.2, launch_velocity * 0.04)), 1.0 + (1 - pulse))
	if launch_vehicle.position.y > 75: pad_smoke.emitting = false; pad_sparks.emitting = false
