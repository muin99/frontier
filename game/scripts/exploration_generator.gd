extends RefCounted
## Generator v2. Local geological analogs, not inferred MOLA features.
const VERSION := 2
const REGION_SPECS := [
	["AEOLIAN SEA","dunes",Vector2(-350,180),Color("b9834d"),"traction","Wind-built ripples and dune slipfaces. Seek sheltered interdune passages."],
	["NOCTIS BASALT","basalt",Vector2(-350,-270),Color("343a40"),"drill","Jointed volcanic rock analog. Dark blocks preserve a different geological story."],
	["VERMILION CANYON","canyon",Vector2(130,-380),Color("a95336"),"climbing","Layered cliffs, narrow passages and elevated overlooks. Follow the low wash or carry a climbing rig."],
	["PALE MESA","mesa",Vector2(425,-60),Color("c3ad87"),"spectrometer","Light-toned layered terrain analog. Bright colour does not establish a mineral identification."],
	["FROSTBOUND RIDGE","highlands",Vector2(250,380),Color("a5b2bc"),"thermal","Cold elevated terrain analog. Frost here is a simulated seasonal scenario, not a Jezero measurement."],
	["ECHO IMPACT","crater",Vector2(-150,480),Color("927266"),"climbing","Terraced impact-rim analog. Traverse the broken rim to reach the sheltered basin."]
]
var world_seed := 42601
var regions: Array[Dictionary] = []
var discoveries: Array[Dictionary] = []
var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()

func generate(seed_value: int) -> void:
	world_seed = seed_value; regions.clear(); discoveries.clear()
	noise.seed = seed_value; noise.frequency = 0.009; noise.fractal_octaves = 3
	detail.seed = seed_value+719; detail.frequency = 0.035; detail.fractal_octaves = 3
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	for spec: Array in REGION_SPECS:
		var centre: Vector2 = spec[2]+Vector2(rng.randf_range(-24,24),rng.randf_range(-24,24))
		regions.append({"name":spec[0],"kind":spec[1],"centre":centre,"radius":170.0,"color":spec[3],"tool":spec[4],"description":spec[5],"angle":rng.randf_range(-0.35,0.35)})
		for j: int in range(6):
			var angle := float(j)*TAU/6+rng.randf_range(-0.24,0.24)
			var location := centre+Vector2(cos(angle),sin(angle))*rng.randf_range(35,118)
			var type: String = ["outcrop","cache","weather","core","refuge","overlook"][j]
			var required := "" if j in [1,2,4] else str(spec[4])
			var instrument := "drill" if j == 3 else ("spectrometer" if j == 0 else "camera")
			var name_prefix: String = ["STRATIGRAPHIC EXPOSURE","FIELD SUPPLY CACHE","MEDA ANALOG STATION","PROTECTED CORE","EMERGENCY REFUGE","RIDGE PANORAMA"][j]
			var reward := rng.randi_range(8,18)
			if j == 0 and rng.randf() < 0.35:
				type = "meteorite"; name_prefix = "METEORITE CANDIDATE"; instrument = "spectrometer"; required = ""; reward = 32
			if j == 5 and rng.randf() < 0.4:
				type = "tube"; name_prefix = "ERODED ROCK PASSAGE"; required = "climbing"; reward = 28
			discoveries.append({"name":str(spec[0])+" / "+name_prefix,"region":regions.size()-1,"position":location,"type":type,"tool":required,"instrument":instrument,"science":reward,"observation":str(spec[5])+" This feature and target placement are procedurally simulated. Compare observations before making a claim.","source":"https://science.nasa.gov/mission/mars-2020-perseverance/science/"})

func region_at(x: float,z: float) -> int:
	var index := -1; var best := 210.0
	for i: int in range(regions.size()):
		var d: float = regions[i].centre.distance_to(Vector2(x,z))
		if d < best: best = d; index = i
	return index

func local_height(x: float,z: float) -> float:
	var p := Vector2(x,z); var index := region_at(x,z)
	var value := noise.get_noise_2d(x,z)*6+detail.get_noise_2d(x,z)*1.7
	if index >= 0:
		var region: Dictionary = regions[index]; var offset: Vector2 = (p-region.centre).rotated(float(region.angle))
		var d: float = offset.length(); var blend := 1-smoothstep(120,205,d)
		match str(region.kind):
			"dunes": value += blend*(pow((sin(offset.x*0.065+sin(offset.y*0.015)*2)+1)*0.5,2.6)*15+noise.get_noise_2d(x*1.5,z*1.5)*6)
			"basalt": value += blend*(absf(noise.get_noise_2d(x,z))*19+detail.get_noise_2d(x*1.5,z*1.5)*2)
			"canyon":
				var wash := offset.x+sin(offset.y*0.024)*20
				value += blend*(smoothstep(14,40,absf(wash))*47+noise.get_noise_2d(x,z)*5)
			"mesa": value += blend*(smoothstep(48,65,d)*-32+32+sin(offset.y*0.07)*2)
			"highlands": value += blend*(pow(maxf(0,1-d/180),1.2)*78+absf(detail.get_noise_2d(x,z))*20)
			"crater": value += blend*(exp(-pow((d-104)/23,2))*42-(1-smoothstep(65,105,d))*9)
	# A safe starter district and traversable radial corridors preserve reachability.
	var safe := smoothstep(115,195,p.length())
	var angle := atan2(z,x); var path_weight := 1.0
	for region: Dictionary in regions:
		var centre: Vector2 = region.centre; var direction := centre.normalized()
		var along := p.dot(direction); var cross_track := absf(p.cross(direction))
		if along > 60 and along < centre.length()+35: path_weight = minf(path_weight,smoothstep(20,65,cross_track))
	if index >= 0:
		var centre: Vector2 = regions[index].centre
		for site: Dictionary in discoveries:
			if int(site.region) != index: continue
			var segment: Vector2 = site.position-centre
			var t := clampf((p-centre).dot(segment)/maxf(segment.length_squared(),0.01),0,1)
			var distance_to_path := p.distance_to(centre+segment*t)
			path_weight = minf(path_weight,smoothstep(14,55,distance_to_path))
	return value*safe*path_weight

func signature() -> String:
	var out := "%d:%d" % [VERSION,world_seed]
	for item: Dictionary in discoveries: out += ":%.3f,%.3f" % [item.position.x,item.position.y]
	return out.sha256_text()

func distance_to_route(p: Vector2) -> float:
	if p.length() < 130: return 0
	var best := INF
	for region: Dictionary in regions:
		var end: Vector2 = region.centre
		var t := clampf(p.dot(end)/end.length_squared(),0,1)
		best = minf(best,p.distance_to(end*t))
	var index := region_at(p.x,p.y)
	if index >= 0:
		var centre: Vector2 = regions[index].centre
		for site: Dictionary in discoveries:
			if int(site.region) != index: continue
			var segment: Vector2 = site.position-centre
			var t := clampf((p-centre).dot(segment)/maxf(segment.length_squared(),0.01),0,1)
			best = minf(best,p.distance_to(centre+segment*t))
	return best
