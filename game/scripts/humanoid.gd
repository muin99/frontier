extends Node3D
## Lightweight articulated human assembled from shared primitive meshes.
var limbs: Dictionary = {}
var phase: float = 0.0
var moving: bool = false
var suit_color := Color("dbe6e8")
var accent := Color("52dfd6")
var skeleton: Skeleton3D
var imported_model: Node3D
var scientist := false
var animation_player: AnimationPlayer
var locomotion_animation := ""
var animation_position := 0.0
var rest_bone_rotations: Dictionary = {}
var detailed_suit := false
var airborne := false
const WALK_REFERENCE_SPEED := 1.024
const RUN_REFERENCE_SPEED := 2.828

func _ready() -> void:
	# Run posture correction after the AnimationPlayer has written its pose.
	process_priority = 100

func _process(_delta: float) -> void:
	if moving and is_instance_valid(animation_player): correct_locomotion_posture()

func build(color := Color("dbe6e8"), trim := Color("52dfd6"), helmet: bool = false, variant: int = 0, lab_coat: bool = false) -> void:
	suit_color = color
	accent = trim
	if helmet and ResourceLoader.exists("res://assets/characters/explorer_z2.glb"):
		detailed_suit = true
		imported_model = load("res://assets/characters/explorer_z2.glb").instantiate()
		imported_model.rotation.y = PI
		add_child(imported_model)
		animation_player = imported_model.find_children("*","AnimationPlayer",true,false)[0]
		for animation_name: String in ["idle","walk","run"]:
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		animation_player.play("idle")
		return
	if ResourceLoader.exists("res://assets/characters/mh_3427.glb"):
		build_imported_human(helmet, variant, lab_coat)
		return
	part("torso", Vector3(0, 1.32, 0), Vector3(0.56, 0.72, 0.30), suit_color)
	part("chest", Vector3(0, 1.40, -0.17), Vector3(0.35, 0.25, 0.08), accent)
	part("hips", Vector3(0, 0.92, 0), Vector3(0.46, 0.23, 0.28), Color("253543"))
	limbs.left_arm = limb(Vector3(-0.39, 1.36, 0), Vector3(0.18, 0.68, 0.18), suit_color)
	limbs.right_arm = limb(Vector3(0.39, 1.36, 0), Vector3(0.18, 0.68, 0.18), suit_color)
	limbs.left_leg = limb(Vector3(-0.17, 0.48, 0), Vector3(0.21, 0.85, 0.24), Color("d2dde0"))
	limbs.right_leg = limb(Vector3(0.17, 0.48, 0), Vector3(0.21, 0.85, 0.24), Color("d2dde0"))
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.46
	head_mesh.radial_segments = 16
	head_mesh.rings = 8
	head.mesh = head_mesh
	head.position = Vector3(0, 1.88, 0)
	head.material_override = make_mat(Color("1a2d3b") if helmet else Color("b97859"), 0.45 if helmet else 0.8, helmet)
	add_child(head)
	if helmet:
		part("helmet_ring", Vector3(0, 1.69, 0), Vector3(0.39, 0.10, 0.34), accent)
		part("backpack", Vector3(0, 1.32, 0.24), Vector3(0.45, 0.62, 0.22), Color("8799a1"))

func build_imported_human(helmet: bool, variant: int, lab_coat: bool) -> void:
	var paths := ["mh_3183","mh_3488","mh_3427","mh_1037"]
	var model_path := "res://assets/characters/%s.glb" % paths[posmod(variant,paths.size())]
	var packed: PackedScene = load(model_path)
	imported_model = packed.instantiate()
	imported_model.name = "RiggedHuman"
	# The source faces +Z; the controller's conventional forward is -Z.
	imported_model.rotation.y = PI
	# Normalize the shorter body to the male rig's gameplay height. Collision and
	# camera framing can then stay consistent across the player and every NPC.
	imported_model.scale = Vector3.ONE * ([1.03,1.0,0.96,0.96][posmod(variant,4)])
	add_child(imported_model)
	for node: Node in imported_model.find_children("*","MeshInstance3D",true,false):
		for surface: int in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(surface)
			if not original is StandardMaterial3D: continue
			var material: StandardMaterial3D = original.duplicate()
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			material.metallic = 0; material.roughness = 0.72; material.metallic_specular = 0.28
			if "body" in material.resource_name.to_lower(): material.roughness = 0.58; material.metallic_specular = 0.34
			if "iris" in material.resource_name.to_lower(): material.roughness = 0.16; material.metallic_specular = 0.5
			if "hair" in material.resource_name.to_lower(): material.cull_mode = BaseMaterial3D.CULL_DISABLED
			node.set_surface_override_material(surface,material)
	var skeletons := imported_model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		skeleton = skeletons[0]
		for bone_name: String in ["pelvis", "spine_01", "spine_03", "neck_01", "thigh_l", "thigh_r", "calf_l", "calf_r"]:
			var bone_index := skeleton.find_bone(bone_name)
			if bone_index >= 0: rest_bone_rotations[bone_name] = skeleton.get_bone_pose_rotation(bone_index)
	var players := imported_model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation_player = players[0]
		locomotion_animation = "idle"
		animation_player.play(locomotion_animation, 0.0)
	# Small authored additions identify role while preserving the curved rigged body.
	if helmet:
		var visor := MeshInstance3D.new()
		var sphere := SphereMesh.new(); sphere.radius = 0.31; sphere.height = 0.62; sphere.radial_segments = 24; sphere.rings = 12
		visor.mesh = sphere; visor.position = Vector3(0, 1.72, -0.015); visor.scale = Vector3(1.0, 0.95, 0.92)
		var glass := make_mat(Color(0.04, 0.16, 0.22, 0.72), 0.16, true); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		visor.material_override = glass; add_child(visor)
		part("life_support_pack", Vector3(0, 1.23, 0.18), Vector3(0.28, 0.40, 0.12), Color("788d95"))
	else:
		scientist = true
		part("id_badge", Vector3(0.18, 1.30, -0.235), Vector3(0.07, 0.10, 0.008), accent)

func make_mat(color: Color, rough: float = 0.6, metallic: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = 0.55 if metallic else 0.0
	return mat

func part(key: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = make_mat(color)
	node.name = key
	add_child(node)
	return node

func limb(pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos + Vector3(0, size.y * 0.5, 0)
	add_child(pivot)
	var node := part("limb", Vector3.ZERO, size, color)
	remove_child(node)
	pivot.add_child(node)
	node.position.y = -size.y * 0.5
	return pivot

func animate_motion(delta: float, speed: float) -> void:
	moving = speed > 0.15
	phase += delta * clampf(speed * 2.4, 2.0, 11.0)
	if is_instance_valid(animation_player):
		var desired := "idle" if airborne else ("run" if speed > 2.8 else ("walk" if moving else "idle"))
		if animation_player.current_animation != desired: animation_player.play(desired, 0.16)
		var reference_speed := RUN_REFERENCE_SPEED if desired == "run" else WALK_REFERENCE_SPEED
		animation_player.speed_scale = clampf(speed / reference_speed, 0.75, 1.75) if moving else 1.0
		if moving: correct_locomotion_posture()
		return
	if is_instance_valid(skeleton):
		var swing := sin(phase) * (0.55 if moving else 0.025)
		pose_bone("thigh_l", Vector3.RIGHT, swing)
		pose_bone("thigh_r", Vector3.RIGHT, -swing)
		pose_bone("calf_l", Vector3.RIGHT, maxf(0.0, -swing) * 0.65)
		pose_bone("calf_r", Vector3.RIGHT, maxf(0.0, swing) * 0.65)
		pose_arm("upperarm_l", 1.30, -swing * 0.75)
		pose_arm("upperarm_r", -1.30, swing * 0.75)
		pose_bone("spine_02", Vector3.UP, sin(phase) * (0.035 if moving else 0.012))
		position.y = (abs(sin(phase * 2.0)) * 0.018) if moving else sin(phase) * 0.004
		return
	var swing := sin(phase) * (0.62 if moving else 0.035)
	limbs.left_arm.rotation.x = swing
	limbs.right_arm.rotation.x = -swing
	limbs.left_leg.rotation.x = -swing
	limbs.right_leg.rotation.x = swing
	position.y = (abs(sin(phase * 2.0)) * 0.025) if moving else sin(phase) * 0.006

func pose_bone(name: String, axis: Vector3, angle: float) -> void:
	var index := skeleton.find_bone(name)
	if index >= 0: skeleton.set_bone_pose_rotation(index, Quaternion(axis, angle))

func pose_arm(name: String, down_angle: float, swing: float) -> void:
	var index := skeleton.find_bone(name)
	if index >= 0:
		skeleton.set_bone_pose_rotation(index, Quaternion(Vector3.FORWARD, down_angle) * Quaternion(Vector3.RIGHT, swing))

func correct_locomotion_posture() -> void:
	if detailed_suit: return
	# The source locomotion exaggerates a combat crouch. Blend only the posture
	# bones toward their standing rest pose; arms and feet retain the authored gait.
	var strengths := {
		"pelvis": 0.30, "spine_01": 0.28, "spine_03": 0.30,
		"neck_01": 0.35, "thigh_l": 0.68, "thigh_r": 0.68,
		"calf_l": 0.58, "calf_r": 0.58
	}
	for bone_name: String in strengths:
		var index := skeleton.find_bone(bone_name)
		if index < 0 or not rest_bone_rotations.has(bone_name): continue
		var animated := skeleton.get_bone_pose_rotation(index)
		var standing: Quaternion = rest_bone_rotations[bone_name]
		skeleton.set_bone_pose_rotation(index, standing.slerp(animated, float(strengths[bone_name])))

func build_lab_coat() -> void:
	var cloth := Color("e8f1f2")
	var shadow := Color("bccbd0")
	# Thin tailored panels preserve the source body's silhouette and avoid a rigid
	# rectangular shell. The open front and split back leave room for the gait.
	coat_panel("coat_back_l", PackedVector3Array([Vector3(-0.25,1.60,0.14), Vector3(0,1.60,0.14), Vector3(0,0.62,0.14), Vector3(-0.31,0.62,0.14)]), shadow)
	coat_panel("coat_back_r", PackedVector3Array([Vector3(0,1.60,0.14), Vector3(0.25,1.60,0.14), Vector3(0.31,0.62,0.14), Vector3(0,0.62,0.14)]), shadow)
	coat_panel("coat_front_l", PackedVector3Array([Vector3(-0.25,1.60,-0.19), Vector3(-0.04,1.60,-0.19), Vector3(-0.05,0.62,-0.19), Vector3(-0.31,0.62,-0.19)]), cloth)
	coat_panel("coat_front_r", PackedVector3Array([Vector3(0.04,1.60,-0.19), Vector3(0.25,1.60,-0.19), Vector3(0.31,0.62,-0.19), Vector3(0.05,0.62,-0.19)]), cloth)
	var lapel_l := part("coat_lapel_l", Vector3(-0.09, 1.43, -0.22), Vector3(0.13, 0.36, 0.035), shadow)
	var lapel_r := part("coat_lapel_r", Vector3(0.09, 1.43, -0.22), Vector3(0.13, 0.36, 0.035), shadow)
	lapel_l.rotation.z = -0.30
	lapel_r.rotation.z = 0.30
	part("id_badge", Vector3(0.18, 1.30, -0.235), Vector3(0.12, 0.16, 0.018), accent)

func coat_panel(panel_name: String, vertices: PackedVector3Array, color: Color) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var panel := MeshInstance3D.new()
	panel.name = panel_name
	panel.mesh = mesh
	var material := make_mat(color, 0.82, false)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel.material_override = material
	add_child(panel)
