extends Node3D
## Regional MOLA context; deliberate scale compression, never a local DEM claim.
var data: Dictionary
var rock_mat: StandardMaterial3D
var ground_mat: ShaderMaterial
var heights: Array
var surface_heights: Array[PackedFloat32Array] = []
const SIZE := 1536.0
const N := 193
var world_seed := 42601
var generator := preload("res://scripts/exploration_generator.gd").new()
var discoveries: Array[Dictionary] = []
var refuges: Array[Vector3] = []
var region_titles: Array[Label3D] = []
var origin_height := 0.0
var beacons: Array[Node3D] = []
var habitat := Vector3(0,0,28)
var ascent: Node3D
var environment_resource: Environment
var sunlight: DirectionalLight3D
var sky_material: ProceduralSkyMaterial

func mat(color: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color; m.roughness = 0.82; m.metallic = metal
	return m

func geological_material(color: Color) -> StandardMaterial3D:
	var material := mat(color.lightened(0.08))
	var base := "res://assets/Rock058/Rock058_1K-JPG_"
	if ResourceLoader.exists(base+"Color.jpg"):
		material.albedo_texture = load(base+"Color.jpg")
		material.normal_enabled = true; material.normal_texture = load(base+"NormalGL.jpg"); material.normal_scale = 0.65
		material.roughness_texture = load(base+"Roughness.jpg")
		material.uv1_triplanar = true; material.uv1_scale = Vector3.ONE*0.18
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func mesh_at(mesh: Mesh, p: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = material
	parent.add_child(node); node.position = p
	return node

func box(p: Vector3, dimensions: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = dimensions
	return mesh_at(b,p,material,parent)

func cylinder(p: Vector3, radius: float, height: float, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius = radius; c.bottom_radius = radius; c.height = height; c.radial_segments = 24
	return mesh_at(c,p,material,parent)

func build() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mola/isidis.json"))
	heights = data.heights
	generator.generate(world_seed)
	origin_height = raw_height(0,28)
	repair_discovery_sites()
	for z: int in range(N):
		var row := PackedFloat32Array()
		for x: int in range(N): row.append(field_height((float(x)/(N-1)-0.5)*SIZE,(float(z)/(N-1)-0.5)*SIZE))
		surface_heights.append(row)
	terrain(); environment(); props()
	exploration_props()

func raw_height(x: float, z: float) -> float:
	var u := clampf((x / SIZE + 0.5) * 64, 0, 63.999)
	var v := clampf((z / SIZE + 0.5) * 64, 0, 63.999)
	var ix := int(u); var iz := int(v)
	var a := lerpf(float(heights[iz][ix]), float(heights[iz][ix+1]), u-ix)
	var b := lerpf(float(heights[iz+1][ix]), float(heights[iz+1][ix+1]), u-ix)
	return lerpf(a,b,v-iz)

func elevation(x: float, z: float) -> float:
	if surface_heights.is_empty(): return field_height(x,z)
	var u := clampf((x/SIZE+0.5)*(N-1),0,N-1.00001); var v := clampf((z/SIZE+0.5)*(N-1),0,N-1.00001)
	var ix := int(u); var iz := int(v); var fx := u-ix; var fz := v-iz
	var a := surface_heights[iz][ix]; var b := surface_heights[iz][ix+1]; var c := surface_heights[iz+1][ix]; var d := surface_heights[iz+1][ix+1]
	if fx+fz <= 1: return a+(b-a)*fx+(c-a)*fz
	return d+(c-d)*(1-fx)+(b-d)*(1-fz)

func field_height(x: float,z: float) -> float:
	return (raw_height(x,z)-origin_height) * 0.008+generator.local_height(x,z)

func point(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x,elevation(x,z)+lift,z)

func repair_discovery_sites() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = world_seed+1009
	for item: Dictionary in generator.discoveries:
		var original: Vector2 = item.position; var chosen := original; var best := INF
		for attempt: int in range(48):
			var candidate := original if attempt == 0 else original+Vector2(rng.randf_range(-40,40),rng.randf_range(-40,40))
			var gradient := Vector2((elevation(candidate.x+3,candidate.y)-elevation(candidate.x-3,candidate.y))/6,(elevation(candidate.x,candidate.y+3)-elevation(candidate.x,candidate.y-3))/6).length()
			if gradient < best: best = gradient; chosen = candidate
			if gradient < 0.32: break
		item.position = chosen

func terrain() -> void:
	var shader := Shader.new()
	shader.code = "shader_type spatial; varying vec3 wp; float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);} float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);} void vertex(){wp=VERTEX;} void fragment(){float grain=noise(wp.xz*24.0);float patches=noise(wp.xz*0.16)*0.45+noise(wp.xz*1.4)*0.20;float bands=sin(wp.y*2.2+wp.x*0.021)*0.5+0.5;vec3 tint=COLOR.rgb;ALBEDO=tint*(0.52+patches+bands*0.1)*(0.94+grain*0.09);ROUGHNESS=0.96;}"
	ground_mat = ShaderMaterial.new(); ground_mat.shader = shader
	if ResourceLoader.exists("res://assets/Ground080/Ground080_1K-JPG_Color.jpg"):
		shader.code = shader.code.replace("varying vec3 wp;","uniform sampler2D sand_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic; uniform sampler2D rock_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic; varying vec3 wp; varying vec3 wn;")
		shader.code = shader.code.replace("wp=VERTEX;","wp=VERTEX;wn=NORMAL;")
		shader.code = shader.code.replace("vec3 tint=COLOR.rgb;","vec3 tint=COLOR.rgb; vec3 w=pow(abs(wn),vec3(6.0));w/=max(w.x+w.y+w.z,0.001);vec3 rock=texture(rock_tex,wp.yz*0.12).rgb*w.x+texture(rock_tex,wp.xz*0.12).rgb*w.y+texture(rock_tex,wp.xy*0.12).rgb*w.z;vec3 sand=texture(sand_tex,wp.xz*0.22).rgb;float grit=mix(dot(sand,vec3(0.333)),dot(rock,vec3(0.333)),smoothstep(0.15,0.55,1.0-abs(wn.y)));tint*=clamp(grit*2.2,0.3,1.3);")
		shader.code = shader.code.replace("ALBEDO=tint*","ALBEDO=mix(vec3(dot(tint,vec3(0.30,0.59,0.11))),tint,0.7)*0.8*")
		ground_mat.set_shader_parameter("sand_tex",load("res://assets/Ground080/Ground080_1K-JPG_Color.jpg"))
		ground_mat.set_shader_parameter("rock_tex",load("res://assets/Rock058/Rock058_1K-JPG_Color.jpg"))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in range(N-1):
		for x: int in range(N-1):
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var px := (float(x+corner.x)/(N-1)-0.5)*SIZE
				var pz := (float(z+corner.y)/(N-1)-0.5)*SIZE
				var region_index: int = generator.region_at(px,pz)
				var tint := Color("956543")
				if region_index >= 0:
					var r: Dictionary = generator.regions[region_index]
					var weight := 1-smoothstep(130,210,Vector2(px,pz).distance_to(r.centre))
					tint = tint.lerp(r.color,weight)
				st.set_color(tint)
				st.add_vertex(point(px,pz))
	st.generate_normals(); st.set_material(ground_mat)
	var terrain_mesh := st.commit()
	var instance := mesh_at(terrain_mesh,Vector3.ZERO,ground_mat)
	instance.create_trimesh_collision()
	for body: Node in instance.get_children():
		if body is StaticBody3D: body.set_meta("ground",true)

func environment() -> void:
	var env := Environment.new(); var sky := Sky.new(); var skymat := ProceduralSkyMaterial.new()
	sky_material = skymat
	skymat.sky_top_color = Color("252b39"); skymat.sky_horizon_color = Color("c89571")
	skymat.ground_horizon_color = Color("b77c53"); skymat.ground_bottom_color = Color("563a2b")
	sky.sky_material = skymat; env.sky = sky; env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9eafc3"); env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true; env.fog_light_color = Color("bd8865"); env.fog_density = 0.0008
	var world := WorldEnvironment.new(); world.environment = env; add_child(world)
	environment_resource = env
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-23,-38,0)
	sunlight = sun
	sun.light_color = Color("ffddba"); sun.light_energy = 0.85; sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160; add_child(sun)

func props() -> void:
	var white := mat(Color("9ca5a4"),0.15); var dark := mat(Color("252e36"),0.35)
	var gold := mat(Color("c99657"),0.65); var solar := mat(Color("253e61"),0.65)
	var teal := mat(Color("63e4df"),0.25); teal.emission_enabled = true; teal.emission = Color("63e4df")
	rock_mat = geological_material(Color("71513b"))
	var rng := RandomNumberGenerator.new(); rng.seed = world_seed
	var stone := SphereMesh.new(); stone.height = 2; stone.radius = 1; stone.radial_segments = 7; stone.rings = 4
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = stone; mm.instance_count = 4500
	for i: int in range(4500):
		var x := rng.randf_range(-745,745); var z := rng.randf_range(-745,745)
		var s := rng.randf_range(0.12,1.0)
		if absf(x) < 17 and z > 0 and z < 45: s *= 0.2
		mm.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(rng.randf(),rng.randf()*TAU,rng.randf())).scaled(Vector3(s,s*0.55,s*0.8)),point(x,z,s*0.2)))
	var rocks := MultiMeshInstance3D.new(); rocks.multimesh = mm; rocks.material_override = rock_mat; add_child(rocks)
	habitat = point(0,28)
	var base := Node3D.new(); add_child(base); base.position = habitat
	var hull_collision := StaticBody3D.new(); base.add_child(hull_collision)
	var shape := CollisionShape3D.new(); var bounds := BoxShape3D.new(); bounds.size = Vector3(10,5,4.6)
	shape.shape = bounds; shape.position.y = 2.7; hull_collision.add_child(shape)
	box(Vector3(0,0.15,0),Vector3(13,0.3,9),dark,base)
	for x: float in [-4.0,4.0]:
		for z: float in [-2.5,2.5]: cylinder(Vector3(x,0.5,z),0.25,1.0,gold,base)
	var shell := cylinder(Vector3(0,2.7,0),2.6,10,white,base); shell.rotation.z = PI/2
	for x: float in [-4.5,-2.0,2.0,4.5]:
		var band := cylinder(Vector3(x,2.7,0),2.65,0.13,dark,base); band.rotation.z = PI/2
	box(Vector3(0,2.65,2.54),Vector3(5,1.05,0.12),dark,base)
	box(Vector3(0,2.65,2.63),Vector3(4.7,0.7,0.06),teal,base)
	for x: float in [-1.6,0.0,1.6]: box(Vector3(x,2.65,2.69),Vector3(0.10,0.9,0.08),dark,base)
	for x: float in [-4.0,4.0]:
		box(Vector3(x,2.4,2.3),Vector3(0.9,1.5,0.25),gold,base)
		for line: int in range(5): box(Vector3(x,1.9+line*0.2,2.46),Vector3(0.7,0.07,0.04),dark,base)
	var title := Label3D.new(); title.text = "F R O N T I E R   /   0 1"; title.font_size = 38; title.pixel_size = 0.009; title.position = Vector3(0,4.0,2.45); title.modulate = Color("243d44"); title.outline_size = 0; base.add_child(title)
	box(Vector3(0,0.5,4),Vector3(3,0.6,2),white,base)
	for i: int in range(3): box(Vector3(0,0.12+0.12*i,5.7-i*0.4),Vector3(3,0.24,0.4),dark,base)
	cylinder(Vector3(5.5,5.5,-1),0.06,6,gold,base)
	var dish := cylinder(Vector3(5.5,8.5,-1),1.3,0.16,white,base); dish.rotation.x = 0.6
	for x: float in [-14.0,-21.0]:
		for z: float in [18.0,27.0,36.0]:
			var panel := box(point(x,z,1.2),Vector3(5.5,0.12,6.5),solar); panel.rotation.z = -0.18
			for line: int in range(6): box(point(x-2.4+line*0.95,z,1.3),Vector3(0.035,0.04,6.4),white)
	# Fictional ascent vehicle, a strong readable return landmark.
	var rocket := Node3D.new(); add_child(rocket); rocket.position = point(17,27)
	ascent = rocket
	cylinder(Vector3(0,3.0,0),1.5,5,white,rocket)
	var nose := CylinderMesh.new(); nose.bottom_radius = 1.5; nose.top_radius = 0.15; nose.height = 2.5
	mesh_at(nose,Vector3(0,6.7,0),gold,rocket)
	cylinder(Vector3(0,1.0,0),1.75,0.45,dark,rocket)
	for angle: float in [0.0,PI/2,PI,PI*1.5]:
		var foot := box(Vector3(sin(angle)*2,0.4,cos(angle)*2),Vector3(0.4,0.5,3),dark,rocket); foot.rotation.y = angle
	for index: int in range(4):
		var positions := [Vector2(-35,-30),Vector2(47,-57),Vector2(93,14),Vector2(-78,-92)]
		var p: Vector2 = positions[index]
		var marker := Node3D.new(); add_child(marker); marker.position = point(p.x,p.y)
		cylinder(Vector3(0,1.3,0),0.045,2.6,gold,marker)
		box(Vector3(0,2.6,0),Vector3(0.7,0.4,0.12),teal,marker)
		var caption := Label3D.new(); caption.text = ["01 / DELTA STRATA","02 / SUBSURFACE CORE","03 / BASALT TRANSECT","04 / RIDGE CONTEXT"][index]
		caption.font_size = 30; caption.pixel_size = 0.008; caption.position.y = 3.4; caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED; caption.modulate = Color("b4e1d5"); caption.outline_size = 5
		marker.add_child(caption)
		var sample := mesh_at(stone,Vector3(0.8,0.35,0),rock_mat,marker); sample.scale = Vector3(1.3,0.6,1)
		beacons.append(marker)

func exploration_props() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = world_seed+551
	var bronze := mat(Color("75604b"),0.5); var dark := mat(Color("27333b"),0.4)
	var ceramic := mat(Color("aeb3ab"),0.2); var blue := mat(Color("3d6976"),0.4)
	var obstacles := StaticBody3D.new(); obstacles.name = "GeologyCollision"; add_child(obstacles)
	for index: int in range(generator.regions.size()):
		var region: Dictionary = generator.regions[index]
		var geology := geological_material(region.color.darkened(0.12))
		var mesh: Mesh
		if region.kind == "basalt":
			var column := CylinderMesh.new(); column.radial_segments = 6; column.top_radius = 1; column.bottom_radius = 1.08; column.height = 1
			var arrays := column.get_mesh_arrays(); var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_smooth_group(-1)
			for vertex: int in arrays[Mesh.ARRAY_INDEX]: st.add_vertex(arrays[Mesh.ARRAY_VERTEX][vertex])
			st.generate_normals(); mesh = st.commit()
		else:
			var outcrop := SphereMesh.new(); outcrop.radius = 1; outcrop.height = 2; outcrop.radial_segments = 9; outcrop.rings = 5; mesh = outcrop
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh; mm.instance_count = 180
		for j: int in range(180):
			var angle := rng.randf()*TAU; var radius := rng.randf_range(35,165)
			var p: Vector2 = region.centre+Vector2(cos(angle),sin(angle))*radius
			var tall := rng.randf_range(2,12) if region.kind == "basalt" else rng.randf_range(2,7)
			if region.kind == "dunes": tall *= 0.16
			var width := rng.randf_range(1.0,4.5)
			if region.kind == "basalt": width = rng.randf_range(0.4,1.8)
			mm.set_instance_transform(j,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(width,tall,width*0.7)),point(p.x,p.y,tall*0.35)))
			if tall > 3 and width > 1.0 and generator.distance_to_route(p) > 20:
				var collider := CollisionShape3D.new(); var shape := BoxShape3D.new()
				shape.size = Vector3(width*1.4,tall*1.25,width)
				collider.shape = shape; collider.position = point(p.x,p.y,tall*0.35); obstacles.add_child(collider)
		var instances := MultiMeshInstance3D.new(); instances.multimesh = mm; instances.material_override = geology; add_child(instances)
		# Layered, angular horizon landmarks, never labelled as measured local features.
		if region.kind in ["mesa","canyon"]:
			for j: int in range(5):
				var p: Vector2 = region.centre+Vector2(-85+j*40,-90)
				if generator.distance_to_route(p) < 40: continue
				var material := geological_material(region.color.darkened(0.18).lightened(j*0.035))
				mesh_at(mesa_mesh(j),point(p.x,p.y),material)
				var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(24,35,24)
				collider.shape = shape; collider.position = point(p.x,p.y,8); obstacles.add_child(collider)
	for item: Dictionary in generator.discoveries:
		discoveries.append(item.duplicate(true))
		var p: Vector2 = item.position
		var node := Node3D.new(); node.name = "Discovery_%02d" % discoveries.size(); add_child(node); node.position = point(p.x,p.y)
		match str(item.type):
			"tube":
				var rock := SphereMesh.new(); rock.radial_segments = 9; rock.rings = 5; rock.radius = 1; rock.height = 2
				for row: int in range(3):
					for segment: int in range(10):
						var angle := float(segment)/9*PI
						var block := mesh_at(rock,Vector3(cos(angle)*3.7,sin(angle)*3.7,2+row*3),rock_mat,node)
						block.scale = Vector3(1.3,1.0,1.7)
			"meteorite":
				var stone := SphereMesh.new(); stone.radius = 1.2; stone.height = 1.3; stone.radial_segments = 7; stone.rings = 4
				mesh_at(stone,Vector3(0,0.45,0),geological_material(Color("3a3833")),node)
			"cache":
				box(Vector3(0,0.5,0),Vector3(1.8,1,1),bronze,node)
				for x: float in [-0.65,0.65]: box(Vector3(x,0.52,0),Vector3(0.12,1.05,1.05),dark,node)
			"weather":
				cylinder(Vector3(0,2,0),0.06,4,ceramic,node); cylinder(Vector3(0,0.35,0),0.65,0.7,dark,node)
				for yaw: float in [0.0,2.1,4.2]:
					var vane := box(Vector3(0,4,0),Vector3(2,0.1,0.3),blue,node); vane.rotation.y = yaw
				box(Vector3(0,1,-0.8),Vector3(2,0.1,1.2),blue,node)
			"refuge":
				var pod := cylinder(Vector3(0,1.4,0),1.5,3,ceramic,node); pod.rotation.z = PI/2
				box(Vector3(0,1.4,1.4),Vector3(1.3,0.8,0.15),blue,node)
				refuges.append(node.position)
			_:
				var stone := SphereMesh.new(); stone.radius = 1.8; stone.height = 2.2; stone.radial_segments = 12; stone.rings = 6
				mesh_at(stone,Vector3(0,0.65,0),geological_material(generator.regions[int(item.region)].color),node)
				cylinder(Vector3(2,0.9,0),0.035,1.8,bronze,node)
		var label := Label3D.new(); label.text = str(item.name); label.font_size = 30; label.pixel_size = 0.010; label.position.y = 4
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.modulate = Color("9bd1c1"); label.outline_size = 6; node.add_child(label)
		label.visible = false; region_titles.append(label)
		beacons.append(node)
	# Surface personnel share the articulated suit and authored locomotion.
	for i: int in range(2):
		var npc := preload("res://scripts/npc.gd").new(); add_child(npc)
		var points := [point(-6-i*3,42,0.2),point(-12-i*3,32,0.2),point(-9-i*3,21,0.2)]
		npc.setup("SURFACE ENGINEER %d" % (i+1),"EVA ENGINEER",points,Color("d7dedb"))

func update_discoveries(player_position: Vector3) -> void:
	for i: int in range(region_titles.size()):
		region_titles[i].visible = player_position.distance_to(beacons[i+4].position) < 65

func mesa_mesh(variation: int) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_smooth_group(-1)
	var rings: Array[PackedVector3Array] = []
	var levels := [-36.0,-4.0,7.0,14.0,21.0,26.0]; var radii := [24.0,22.0,17.0,14.0,12.0,9.0]
	for level: int in range(levels.size()):
		var ring := PackedVector3Array()
		for side: int in range(9):
			var angle := float(side)*TAU/9; var radius: float = radii[level]*(1+sin(side*2.7+variation)*0.14)
			ring.append(Vector3(cos(angle)*radius,levels[level]+sin(side*3.4+level)*0.7,sin(angle)*radius))
		rings.append(ring)
	for level: int in range(rings.size()-1):
		for side: int in range(9):
			var next := (side+1)%9
			for p: Vector3 in [rings[level][side],rings[level+1][side],rings[level][next],rings[level][next],rings[level+1][side],rings[level+1][next]]: st.add_vertex(p)
	for side: int in range(9):
		for p: Vector3 in [Vector3(0,26,0),rings[-1][side],rings[-1][(side+1)%9]]: st.add_vertex(p)
	st.generate_normals(); return st.commit()

func astronaut() -> Node3D:
	var root := Node3D.new()
	var suit := mat(Color("afb5ae"),0.05); var trim := mat(Color("914a2b")); var visor := mat(Color("162b36"),0.6)
	var torso := CapsuleMesh.new(); torso.radius = 0.29; torso.height = 0.78
	var body := mesh_at(torso,Vector3(0,1.03,0),suit,root); body.scale.z = 0.7
	box(Vector3(0,1.08,0.27),Vector3(0.46,0.62,0.24),trim,root)
	for side: float in [-1.0,1.0]:
		var leg := cylinder(Vector3(side*0.17,0.4,0),0.135,0.72,suit,root); leg.name = "LegL" if side < 0 else "LegR"
		box(Vector3(side*0.17,0.09,-0.09),Vector3(0.29,0.19,0.43),visor,root)
		var arm := cylinder(Vector3(side*0.37,0.99,0),0.115,0.62,suit,root); arm.name = "ArmL" if side < 0 else "ArmR"
		box(Vector3(side*0.39,0.73,0),Vector3(0.23,0.17,0.24),trim,root)
	var helmet := SphereMesh.new(); helmet.radius = 0.31; helmet.height = 0.62
	mesh_at(helmet,Vector3(0,1.62,0),suit,root)
	var face := mesh_at(helmet,Vector3(0,1.62,-0.10),visor,root); face.scale = Vector3(0.9,0.7,0.85)
	box(Vector3(0,1.16,-0.25),Vector3(0.29,0.22,0.07),trim,root)
	return root
