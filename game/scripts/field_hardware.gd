extends RefCounted
## Original authored hard-surface family. Batched meshes, no downloaded art.
static var cache: Dictionary = {}
var surfaces: Array[SurfaceTool] = []
var ceramic := 0
var graphite := 1
var titanium := 2
var teal := 3
var amber := 4
var glass := 5
var solar := 6
var crop := 7

func make(id: String) -> Node3D:
	var root := Node3D.new(); root.name = "Hardware_"+id
	var catalog: Dictionary = preload("res://scripts/outpost_cargo.gd").catalog()
	var family: String = str(catalog[id].get("family",id)) if catalog.has(id) else id
	if not cache.has(family): cache[family] = build_mesh(family)
	var visual := MeshInstance3D.new(); visual.mesh = cache[family]; visual.name = "Shell"; root.add_child(visual)
	if catalog.has(id) and str(catalog[id].get("variant","standard")) not in ["standard","flight"]:
		var badge := Label3D.new(); root.add_child(badge); badge.text = str(catalog[id].variant).to_upper(); badge.position = Vector3(0,1.2,-.55); badge.font_size = 24; badge.pixel_size = .006; badge.modulate = Color("72dfd2")
		visual.scale = Vector3.ONE*(.88 if catalog[id].variant=="compact" else (1.06 if catalog[id].variant in ["expedition","rugged"] else 1.0))
	return root

func build_mesh(id: String) -> ArrayMesh:
	surfaces.clear()
	var colors := [Color("b9c4c5"),Color("16252e"),Color("697f8c"),Color("54ddc7"),Color("dca35a"),Color("173846"),Color("143a64"),Color("5b856a")]
	for i: int in range(colors.size()):
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var m := StandardMaterial3D.new(); m.albedo_color = colors[i]; m.roughness = .39 if i in [0,2] else .7; m.metallic = .65 if i==2 else (.28 if i in [0,1,6] else .05)
		if i in [3,4]: m.emission_enabled = true; m.emission = colors[i]; m.emission_energy_multiplier = .6
		if i in [5,6]: m.roughness = .18; m.metallic = .45
		if id=="greenhouse" and i==5:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color = Color(.25,.55,.6,.28); m.metallic = .1
		st.set_material(m); surfaces.append(st)
	match id:
		"solar": solar_array()
		"battery": battery_bank()
		"reactor": reactor_core()
		"oxygen": oxygen_plant()
		"ice": ice_drill()
		"habitat": habitat_shell()
		"greenhouse": greenhouse()
		"fabricator", "refinery": factory(id=="refinery")
		"relay", "observatory": antenna(id=="observatory")
		"weather": weather_array()
		"seismic": seismic_anchor()
		"spectrometer": mineral_lab()
		"dronepad": drone_port()
		"survey_drone": survey_drone()
		"ore", "ice_deposit": resource_formation(id=="ice_deposit")
		"bridge", "ramp": walkway(id=="ramp")
		"cargo": cargo_vault()
		"anchor","winch","ropebridge": climbing_rig(id)
		"floodlight","heater","scrubber","repair_station": service_rig(id)
		"shelter","sample_vault": habitat_shell()
		"oxygen_cache","oxygen_bottle": oxygen_plant()
		"survey_lidar","radiometer","lidar","navigation": mineral_lab()
		"harness","crampons","rope30","rope60","ascender": portable_climbing(id)
		"headlamp": service_rig("floodlight")
		"radiation_liner","thermal_liner","dust_filter","medkit","sealant","spare_cell","sample_container": cargo_vault()
		_: pylon(id=="coupler")
	if id.begins_with("rocket_") or id=="launch_core": rocket_component(id)
	var mesh := ArrayMesh.new()
	for st: SurfaceTool in surfaces:
		# Some models do not use every palette material.
		var arrays := st.commit_to_arrays()
		if arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty(): continue
		st.generate_normals(); st.index(); st.commit(mesh)
	return mesh

func tri(a: Vector3,b: Vector3,c: Vector3,material: int) -> void:
	var n := (b-a).cross(c-a).normalized()
	for p: Vector3 in [a,c,b]: surfaces[material].set_normal(n); surfaces[material].add_vertex(p)

func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,material: int) -> void:
	tri(a,b,c,material); tri(a,c,d,material)

func panel(p: Vector3,size: Vector3,material: int,rotation := Vector3.ZERO) -> void:
	# Four bevel bands around an octagonal housing produce manufactured edges.
	var bevel := minf(size.x,minf(size.y,size.z))*.14
	var transform := Transform3D(Basis.from_euler(rotation),p)
	var rings: Array[PackedVector3Array] = []
	for pair: Vector2 in [Vector2(-size.y*.5,bevel),Vector2(-size.y*.5+bevel,0),Vector2(size.y*.5-bevel,0),Vector2(size.y*.5,bevel)]:
		var x := size.x*.5-pair.y; var z := size.z*.5-pair.y; var cut := minf(size.x,size.z)*.12
		var ring := PackedVector3Array()
		for v: Vector2 in [Vector2(-x+cut,-z),Vector2(x-cut,-z),Vector2(x,-z+cut),Vector2(x,z-cut),Vector2(x-cut,z),Vector2(-x+cut,z),Vector2(-x,z-cut),Vector2(-x,-z+cut)]: ring.append(transform*Vector3(v.x,pair.x,v.y))
		rings.append(ring)
	for k: int in range(3):
		for j: int in range(8): quad(rings[k][j],rings[k+1][j],rings[k+1][(j+1)%8],rings[k][(j+1)%8],material)
	for j: int in range(8):
		tri(transform*Vector3(0,-size.y*.5,0),rings[0][j],rings[0][(j+1)%8],material)
		tri(transform*Vector3(0,size.y*.5,0),rings[3][(j+1)%8],rings[3][j],material)

func lathe(p: Vector3,profile: Array[Vector2],material: int,rotation := Vector3.ZERO,segments := 32) -> void:
	var t := Transform3D(Basis.from_euler(rotation),p)
	for k: int in range(profile.size()-1):
		for j: int in range(segments):
			var a := j*TAU/segments; var b := (j+1)*TAU/segments
			quad(t*Vector3(cos(a)*profile[k].x,profile[k].y,sin(a)*profile[k].x),t*Vector3(cos(a)*profile[k+1].x,profile[k+1].y,sin(a)*profile[k+1].x),t*Vector3(cos(b)*profile[k+1].x,profile[k+1].y,sin(b)*profile[k+1].x),t*Vector3(cos(b)*profile[k].x,profile[k].y,sin(b)*profile[k].x),material)

func beam(a: Vector3,b: Vector3,width: float,material: int) -> void:
	var direction := b-a; var basis := Basis(Quaternion(Vector3.UP,direction.normalized()))
	panel((a+b)*.5,Vector3(width,direction.length(),width),material,basis.get_euler())

func feet(radius := .9,height := .55) -> void:
	for i: int in range(3):
		var a := i*TAU/3
		var p := Vector3(cos(a)*radius,0,sin(a)*radius)
		panel(p+Vector3(0,.055,0),Vector3(.55,.11,.5),graphite)
		beam(p+Vector3(0,.1,0),p*.48+Vector3(0,height,0),.13,titanium)
		lathe(p+Vector3(0,.15,0),[Vector2(.13,-.08),Vector2(.13,.08)],amber,Vector3(PI/2,0,0),16)

func core_case(p := Vector3(0,.9,0),size := Vector3(1.1,1.2,.8)) -> void:
	panel(p,size,graphite); panel(p+Vector3(0,.03,0),size*Vector3(.94,.9,1.04),ceramic)
	panel(p+Vector3(0,.12,-size.z*.53),Vector3(size.x*.7,size.y*.4,.035),glass)
	for j: int in range(5): panel(p+Vector3(-size.x*.25+j*size.x*.12,.1,-size.z*.56),Vector3(.04,.1+(j%3)*.04,.012),teal)
	for side: float in [-1.,1.]:
		for j: int in range(5): panel(p+Vector3(side*size.x*.505,-size.y*.28+j*.09,0),Vector3(.025,.04,size.z*.6),graphite)
	panel(p+Vector3(0,-size.y*.34,-size.z*.54),Vector3(size.x*.65,.035,.025),amber)

func solar_array() -> void:
	feet(1.05,.65); core_case(Vector3(0,.65,0),Vector3(.7,.6,.75))
	for side: float in [-1.,1.]:
		beam(Vector3(0,.8,0),Vector3(side*2.2,1.2,0),.11,titanium)
		for k: int in range(3):
			var p := Vector3(side*(.68+k*.68),1.16+k*.12,0)
			panel(p,Vector3(.66,.09,2.35),titanium,Vector3(0,0,side*.17))
			for row: int in range(7):
				for col: int in range(2): panel(p+Vector3(-.155+col*.31,.055,-.98+row*.32),Vector3(.285,.018,.29),solar,Vector3(0,0,side*.17))
			panel(p+Vector3(side*.32,.07,0),Vector3(.025,.025,2.3),teal)

func battery_bank() -> void:
	feet(.9,.45)
	panel(Vector3(0,.55,0),Vector3(1.75,.3,1.1),graphite)
	for x: float in [-.5,0.,.5]:
		panel(Vector3(x,1.05,0),Vector3(.43,1.1,.85),ceramic)
		panel(Vector3(x,1.12,-.44),Vector3(.28,.7,.025),graphite)
		for i: int in range(5): panel(Vector3(x,.88+i*.1,-.46),Vector3(.22,.045,.018),teal)
	panel(Vector3(0,1.66,0),Vector3(1.8,.16,1.1),titanium)
	beam(Vector3(-.83,1.7,0),Vector3(.83,1.7,0),.06,amber)

func reactor_core() -> void:
	feet(1.3,.65)
	lathe(Vector3.ZERO,[Vector2(.5,.5),Vector2(.8,.7),Vector2(.8,1.4),Vector2(.6,1.7),Vector2(.4,1.8),Vector2(0,1.8)],ceramic)
	for i: int in range(16):
		var a := i*TAU/16
		panel(Vector3(cos(a)*.85,1.15,sin(a)*.85),Vector3(.08,1.25,.55),titanium,Vector3(0,-a,0))
	lathe(Vector3.ZERO,[Vector2(.82,.68),Vector2(.83,.75)],amber)
	lathe(Vector3.ZERO,[Vector2(.64,1.6),Vector2(.65,1.67)],teal)
	core_case(Vector3(0,.8,-1),Vector3(.65,.55,.35))

func oxygen_plant() -> void:
	feet(1.1,.55); core_case(Vector3(0,.95,0),Vector3(.7,1.05,.9))
	for side: float in [-1.,1.]:
		lathe(Vector3(side*.68,.45,0),[Vector2(0,0),Vector2(.26,.1),Vector2(.32,.3),Vector2(.32,1.05),Vector2(.24,1.25),Vector2(0,1.3)],ceramic)
		for y: float in [.8,1.5]: lathe(Vector3(side*.68,0,0),[Vector2(.33,y),Vector2(.33,y+.07)],titanium)
		beam(Vector3(side*.68,1.75,0),Vector3(side*.25,1.6,0),.065,teal)
	panel(Vector3(0,1.65,-.45),Vector3(.45,.12,.05),teal)

func ice_drill() -> void:
	feet(1.35,.65); core_case(Vector3(.55,1.1,0),Vector3(.65,1,.85))
	for side: float in [-1.,1.]: beam(Vector3(side*.4,.4,0),Vector3(side*.4,2.55,0),.1,titanium)
	panel(Vector3(0,2.4,0),Vector3(1,.35,.8),ceramic)
	lathe(Vector3(0,.15,0),[Vector2(.12,0),Vector2(.12,2)],graphite)
	for i: int in range(70):
		var a := i*.36; var b := (i+1)*.36; var y := .1+i*.024
		quad(Vector3(cos(a)*.12,y,sin(a)*.12),Vector3(cos(a)*.29,y,sin(a)*.29),Vector3(cos(b)*.29,y+.024,sin(b)*.29),Vector3(cos(b)*.12,y+.024,sin(b)*.12),titanium)
	beam(Vector3(.2,.8,0),Vector3(.9,.5,.3),.09,teal)

func habitat_shell() -> void:
	panel(Vector3(0,.3,0),Vector3(4.4,.4,3.5),graphite)
	# Elliptical pressure-shell sections with inset seams.
	for k: int in range(5):
		var z := -1.5+k*.62
		for j: int in range(20):
			var a := j*PI/20; var b := (j+1)*PI/20
			quad(Vector3(cos(a)*2,.55+sin(a)*2,z),Vector3(cos(a)*2,.55+sin(a)*2,z+.57),Vector3(cos(b)*2,.55+sin(b)*2,z+.57),Vector3(cos(b)*2,.55+sin(b)*2,z),ceramic)
		beam(Vector3(-2,.57,z),Vector3(-2,.57,z+.57),.05,amber)
	for z: float in [-1.55,1.55]:
		panel(Vector3(0,1.35,z),Vector3(3.65,1.65,.13),ceramic)
		panel(Vector3(0,1.25,z*1.025),Vector3(1.1,1.6,.12),graphite)
		panel(Vector3(0,1.4,z*1.07),Vector3(.65,.45,.06),glass)
		for x: float in [-.62,.62]: panel(Vector3(x,1.2,z*1.06),Vector3(.035,1.5,.05),teal)
	panel(Vector3(0,.15,-2.1),Vector3(1.6,.18,1),titanium)
	for side: float in [-1.,1.]:
		panel(Vector3(side*1.78,1.3,0),Vector3(.12,.55,1.8),glass)
		for i: int in range(4): panel(Vector3(side*1.86,1.3,-.66+i*.44),Vector3(.045,.6,.045),titanium)
	panel(Vector3(0,2.58,0),Vector3(1.3,.15,.8),titanium)

func greenhouse() -> void:
	feet(1.2,.5); panel(Vector3(0,.6,0),Vector3(2.6,.35,2.1),ceramic)
	lathe(Vector3(0,.6,0),[Vector2(1.2,0),Vector2(1.2,.3),Vector2(1.05,1.2),Vector2(.5,1.7),Vector2(0,1.8)],glass)
	for i: int in range(8):
		var a := i*TAU/8
		beam(Vector3(cos(a)*1.2,.75,sin(a)*1.2),Vector3(cos(a)*.5,2.3,sin(a)*.5),.055,titanium)
		panel(Vector3(cos(a)*.6,1.05,sin(a)*.6),Vector3(.35,.15,.5),crop,Vector3(0,a,0))
	lathe(Vector3.ZERO,[Vector2(1.22,.8),Vector2(1.22,.86)],teal)
	core_case(Vector3(0,1,-1.2),Vector3(.65,.6,.3))

func factory(refinery: bool) -> void:
	feet(1.2,.55); panel(Vector3(0,.55,0),Vector3(2.3,.2,1.6),titanium)
	core_case(Vector3(-.65,1.1,0),Vector3(.75,1.3,1.4))
	panel(Vector3(.45,.9,0),Vector3(1.3,.13,1.25),graphite)
	for x: float in [-.1,.95]: beam(Vector3(x,.7,.5),Vector3(x,2,.5),.1,titanium)
	beam(Vector3(-.1,2,.5),Vector3(.95,2,.5),.16,ceramic)
	beam(Vector3(.2,2,.5),Vector3(.2,1.5,0),.08,amber)
	panel(Vector3(.2,1.43,0),Vector3(.25,.25,.3),teal)
	for y: float in [.7,.95,1.2,1.45,1.7]: panel(Vector3(-.98,y,0),Vector3(.04,.055,1.2),graphite)
	if refinery:
		lathe(Vector3(.4,.8,0),[Vector2(.5,0),Vector2(.5,.45),Vector2(.75,.8),Vector2(.75,.88)],titanium)
		lathe(Vector3(.4,.8,0),[Vector2(.45,0),Vector2(.44,.1)],amber)
	else: panel(Vector3(.4,1,0),Vector3(.45,.15,.45),ceramic)

func antenna(telescope: bool) -> void:
	feet(1.2,.6); core_case(Vector3(0,.9,0),Vector3(.65,.65,.65))
	beam(Vector3(0,1,0),Vector3(0,2.25,0),.2,titanium)
	if telescope:
		lathe(Vector3(0,2.1,0),[Vector2(.4,-.8),Vector2(.48,-.65),Vector2(.48,.65),Vector2(.4,.85)],ceramic,Vector3(.9,0,0))
		lathe(Vector3(0,2.1,0),[Vector2(.38,.83),Vector2(0,.84)],glass,Vector3(.9,0,0))
		for side: float in [-1.,1.]: beam(Vector3(side*.55,1.5,0),Vector3(side*.55,2.4,0),.12,titanium)
	else:
		lathe(Vector3(0,2.45,0),[Vector2(0,-.25),Vector2(.3,-.2),Vector2(.65,-.08),Vector2(1.15,.2),Vector2(1.2,.25)],ceramic,Vector3(.65,0,0),40)
		beam(Vector3(0,2.2,0),Vector3(0,3.2,-.7),.055,titanium)
		panel(Vector3(0,3.2,-.7),Vector3(.2,.16,.18),teal)

func weather_array() -> void:
	feet(1,.5); core_case(Vector3(0,.7,0),Vector3(.65,.6,.6))
	beam(Vector3(0,.8,0),Vector3(0,3.2,0),.09,titanium)
	for y: float in [1.6,1.7,1.8,1.9,2.0]: lathe(Vector3.ZERO,[Vector2(.28,y),Vector2(.28,y+.04)],ceramic)
	for i: int in range(3):
		var a := i*TAU/3
		beam(Vector3(0,3.1,0),Vector3(cos(a)*.7,3.1,sin(a)*.7),.05,graphite)
		lathe(Vector3(cos(a)*.7,3.1,sin(a)*.7),[Vector2(.18,0),Vector2(.18,.15)],amber,Vector3(0,0,PI/2),16)
	panel(Vector3(.6,1.05,0),Vector3(.85,.05,.6),solar,Vector3(0,0,-.3))

func seismic_anchor() -> void:
	feet(.9,.4)
	lathe(Vector3.ZERO,[Vector2(.75,.3),Vector2(.7,.5),Vector2(.45,.8),Vector2(.45,1),Vector2(0,1.1)],ceramic)
	for y: float in [.48,.58]: lathe(Vector3.ZERO,[Vector2(.69,y),Vector2(.69,y+.035)],teal)
	beam(Vector3(0,.4,0),Vector3(0,-.25,0),.16,titanium)
	panel(Vector3(0,.85,-.45),Vector3(.45,.25,.045),glass)

func mineral_lab() -> void:
	feet(1.1,.5); core_case(Vector3(0,1,0),Vector3(1.3,1,.85))
	panel(Vector3(0,.58,-.6),Vector3(1.1,.12,.85),titanium)
	for x: float in [-.3,0.,.3]: lathe(Vector3(x,.65,-.65),[Vector2(.1,0),Vector2(.1,.27),Vector2(0,.3)],glass,Vector3.ZERO,16)
	beam(Vector3(.7,1.5,0),Vector3(.7,1.8,-.65),.1,titanium)
	beam(Vector3(.7,1.8,-.65),Vector3(0,1.65,-.65),.08,amber)
	lathe(Vector3(0,1.48,-.65),[Vector2(.15,0),Vector2(.15,.2)],teal)

func drone_port() -> void:
	feet(1.4,.5)
	lathe(Vector3.ZERO,[Vector2(0,.4),Vector2(1.4,.4),Vector2(1.6,.55),Vector2(1.6,.7),Vector2(1.3,.78),Vector2(0,.78)],graphite)
	lathe(Vector3.ZERO,[Vector2(1.2,.8),Vector2(1.27,.8)],teal)
	panel(Vector3(0,1.05,0),Vector3(.6,.35,.8),ceramic)
	for a: float in [0.,PI/2,PI,PI*1.5]:
		var p := Vector3(cos(a)*.85,1.1,sin(a)*.85)
		beam(Vector3(0,1.1,0),p,.07,titanium)
		lathe(p,[Vector2(.3,0),Vector2(.3,.07)],titanium)
		beam(p-Vector3(.25,0,0),p+Vector3(.25,0,0),.025,graphite)
	core_case(Vector3(1.4,1.1,.7),Vector3(.6,.75,.5))

func walkway(ramp: bool) -> void:
	var length := 4.0 if ramp else 6.0
	var tilt := -.24 if ramp else 0.0
	var y := .8 if ramp else .65
	panel(Vector3(0,y,0),Vector3(2,.18,length),titanium,Vector3(tilt,0,0))
	for i: int in range(16):
		var z := -length*.46+i*length*.92/15
		panel(Vector3(0,y+z*sin(-tilt)+.11,z),Vector3(1.65,.035,.055),graphite,Vector3(tilt,0,0))
	for side: float in [-1.,1.]:
		beam(Vector3(side*.95,.23,-length*.47),Vector3(side*.95,y+.2,length*.47),.085,amber)
		for z: float in [-length*.4,0.,length*.4]:
			beam(Vector3(side*.85,.05,z),Vector3(side*.85,y+z*sin(-tilt),z),.09,graphite)
			panel(Vector3(side*.85,.05,z),Vector3(.4,.1,.4),graphite)

func cargo_vault() -> void:
	feet(1,.4); core_case(Vector3(0,1,0),Vector3(1.7,1.3,1.2))
	for x: float in [-.6,.6]:
		panel(Vector3(x,1.05,-.64),Vector3(.08,1.2,.05),titanium)
		beam(Vector3(x,1.7,-.3),Vector3(x,1.7,.3),.07,amber)

func pylon(power: bool) -> void:
	feet(.65,.35)
	lathe(Vector3.ZERO,[Vector2(.4,.25),Vector2(.26,.5),Vector2(.16,1.6),Vector2(.3,1.7),Vector2(.3,1.85),Vector2(0,1.9)],titanium)
	lathe(Vector3.ZERO,[Vector2(.31,1.66),Vector2(.31,1.78)],teal if power else amber)
	for a: float in [0.,PI/2,PI,PI*1.5]:
		panel(Vector3(cos(a)*.18,1.1,sin(a)*.18),Vector3(.16,.45,.07),graphite,Vector3(0,-a+PI/2,0))

func survey_drone() -> void:
	panel(Vector3.ZERO,Vector3(.7,.25,.85),ceramic)
	panel(Vector3(0,-.12,-.4),Vector3(.3,.15,.16),glass)
	for side: float in [-1.,1.]:
		beam(Vector3(side*.25,0,0),Vector3(side*.9,0,0),.09,titanium)
		lathe(Vector3(side*.9,0,0),[Vector2(.27,-.07),Vector2(.36,-.07),Vector2(.36,.08),Vector2(.27,.08)],graphite)
		beam(Vector3(side*.9-.28,0,0),Vector3(side*.9+.28,0,0),.035,titanium)
		panel(Vector3(side*.32,.1,-.1),Vector3(.04,.04,.25),teal)

func resource_formation(ice: bool) -> void:
	for i: int in range(7):
		var a := i*TAU/7; var h := .7+(i%3)*.35
		lathe(Vector3(cos(a)*.65,0,sin(a)*.65),[Vector2(.4,0),Vector2(.35,h*.7),Vector2(.05,h)],glass if ice else titanium,Vector3(sin(a)*.2,0,cos(a)*.2),7)

func climbing_rig(id: String) -> void:
	feet(.7,.4); core_case(Vector3(0,.7,0),Vector3(.6,.6,.6))
	lathe(Vector3(0,1.05,0),[Vector2(.4,-.3),Vector2(.4,-.22),Vector2(.26,-.2),Vector2(.26,.2),Vector2(.4,.22),Vector2(.4,.3)],titanium,Vector3(PI/2,0,0))
	for i: int in range(11): lathe(Vector3(0,1.05,-.2+i*.04),[Vector2(.28,-.01),Vector2(.29,.01)],amber,Vector3(PI/2,0,0),24)
	if id=="winch": panel(Vector3(.5,.9,0),Vector3(.4,.45,.7),graphite)
	beam(Vector3(0,.3,0),Vector3(0,-.35,0),.18,titanium)

func service_rig(id: String) -> void:
	feet(.8,.5); core_case(Vector3(0,.8,0),Vector3(.8,.7,.75))
	beam(Vector3(0,1,0),Vector3(0,2.3,0),.1,titanium)
	for side: float in [-1.,1.]:
		panel(Vector3(side*.5,2.25,0),Vector3(.75,.35,.2),ceramic)
		panel(Vector3(side*.5,2.25,-.12),Vector3(.6,.22,.04),teal if id=="floodlight" else amber)
	for i: int in range(6): panel(Vector3(.43,.55+i*.1,0),Vector3(.04,.04,.5),graphite)

func portable_climbing(id: String) -> void:
	if id in ["rope30","rope60"]:
		for i: int in range(12): lathe(Vector3(0,.2+i*.035,0),[Vector2(.32,-.012),Vector2(.42,0),Vector2(.32,.012)],amber)
	elif id=="harness":
		for x: float in [-.23,.23]: lathe(Vector3(x,.3,0),[Vector2(.2,0),Vector2(.2,.06)],graphite,Vector3(PI/2,0,0),24)
		beam(Vector3(-.4,.65,0),Vector3(.4,.65,0),.12,amber)
		for x: float in [-.25,.25]: beam(Vector3(x,.3,0),Vector3(x,.65,0),.09,graphite)
	else:
		panel(Vector3(0,.25,0),Vector3(.8,.15,.5),titanium)
		for x: float in [-.3,0,.3]: beam(Vector3(x,.3,-.2),Vector3(x,.05,-.2),.06,amber)

func rocket_component(id: String) -> void:
	lathe(Vector3.ZERO,[Vector2(.7,0),Vector2(.85,.15),Vector2(.85,2.5),Vector2(.65,2.8),Vector2(0,3.5)],ceramic)
	for y: float in [.3,1.4,2.4]: lathe(Vector3.ZERO,[Vector2(.86,y),Vector2(.86,y+.07)],titanium)
	for i: int in range(3):
		var a := i*TAU/3; lathe(Vector3(cos(a)*.45,-.25,sin(a)*.45),[Vector2(.3,0),Vector2(.16,.3),Vector2(.13,.5)],graphite)
	panel(Vector3(0,1.8,-.87),Vector3(.45,.3,.04),glass)
