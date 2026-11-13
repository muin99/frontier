extends RefCounted
## Morphological analogs, not mapped detections. 32 x 9 place profiles.
const NAMES := ["BARCHAN ERG","RIPPLE CORRIDOR","STAR DUNE FIELD","DEFLATION HOLLOW","VENTIFACT GARDEN","YARDANG MAZE","BASALT PAVEMENT","BLOCKY LAVA APRON","PRESSURE RIDGE","LAVA-TUBE SKYLIGHT","FRACTURE TUNNEL","COLLAPSED LAVA CHANNEL","LAYERED SCARP","SLOT CANYON","TALUS CHUTE","DEEP FRACTURE CAVE","DISSECTED GULLY","PALE MESA","ERODED KNOB FIELD","ALLUVIAL FAN","DELTA BENCH","CHAOS PLATEAU","ICE SCARP ANALOG","POLYGONAL UPLAND","FROST HOLLOW","COLD-SHADOW RIDGE","FRACTURED HIGHLAND","TERRACED IMPACT RIM","CENTRAL-PEAK CRATER","EJECTA BOULDER FIELD","NESTED PIT","DEEP IMPACT CHASM"]
const CONDITIONS := ["SUNLIT","WINDWARD","LEE-SIDE","COLD-SHADOW","FRACTURED","DUST-LOADED","EXPOSED","LOW-CONTRAST","THERMAL-CYCLE"]
const TASKS := ["SPECTRAL TRANSECT","PROTECTED CORE","CONTEXT PHOTOGRAMMETRY","THERMAL DWELL","SEISMIC BASELINE","DUST DEPOSITION STUDY","ROPE-ACCESS SAMPLE","RETURN-CACHE RECOVERY"]
const SOURCES := {"gravity":"https://ssd.jpl.nasa.gov/planets/phys_par.html","dust":"https://www.nasa.gov/solar-system/the-fact-and-fiction-of-martian-dust-storms/","caves":"https://www.nasa.gov/general/cavehopping-exploration-of-planetary-skylights-and-tunnels/","terrain":"https://pds-geosciences.wustl.edu/missions/mgs/megdr.html","geology":"https://science.nasa.gov/mission/mars-2020-perseverance/science/"}

static func code(seed_number: int,cell: Vector2i,salt := 0) -> int:
	var value := (str(seed_number)+":"+str(cell.x)+":"+str(cell.y)+":"+str(salt)).hash()&0x7fffffff
	value = ((value^(value>>16))*73244475)&0x7fffffff
	value = ((value^(value>>16))*73244475)&0x7fffffff
	return value^(value>>16)

static func landform(seed_number: int,cell: Vector2i,kind: int) -> int:
	var starts := [0,6,12,17,22,27]; var counts := [6,6,5,5,5,5]
	return starts[kind]+code(seed_number,cell,401)%counts[kind]

static func profile(seed_number: int,cell: Vector2i,kind: int) -> Dictionary:
	var index := landform(seed_number,cell,kind); var condition := code(seed_number,cell,419)%9
	return {"id":index*9+condition,"landform":index,"condition":condition,"name":NAMES[index]+" / "+CONDITIONS[condition],"cave":index in [9,10,15],"mountain":index in [8,12,14,21,22,25,26,27,28],"depth":index in [9,10,15,30,31],"task":code(seed_number,cell,431)%8,"source":SOURCES.caves if index in [9,10,15] else SOURCES.geology}

static func relief(seed_number: int,cell: Vector2i,kind: int,u: float,v: float) -> float:
	var index := landform(seed_number,cell,kind); var p := Vector2(u-.28,v-.75); var d := p.length()
	match index:
		0: return sin(u*TAU*6+v*3)*5
		1: return sin(v*TAU*10+sin(u*9))*3
		2: return absf(sin(u*18)+sin(v*17))*8
		3: return -exp(-pow(d/.17,2))*16
		4: return sin(u*30)*sin(v*30)*4
		5: return pow(absf(sin(u*27+v*3)),5)*17
		6: return sin(u*13)*cos(v*12)*3
		7: return floorf((sin(u*21)*cos(v*24)+1)*3)*3
		8: return exp(-pow((u-.28)/.08,2))*56
		9,10,15: return exp(-pow(d/.18,2))*24
		11: return -exp(-pow((u-.28+sin(v*12)*.03)/.045,2))*25
		12: return smoothstep(.14,.34,u)*60
		13: return -exp(-pow((u-.28+sin(v*10)*.03)/.026,2))*45
		14: return exp(-pow(d/.16,2))*68+sin(v*40)*4
		16: return -pow(absf(sin(u*22+v*4)),8)*23
		17: return (1-smoothstep(.1,.2,d))*48
		18: return pow(maxf(0,sin(u*20)*sin(v*18)),3)*28
		19: return -d*15+sin(u*24+v*20)*3
		20: return floorf((1-v)*6)*4
		21: return absf(sin(u*23)*cos(v*19))*55
		22: return smoothstep(.2,.25,u)*65
		23: return absf(sin(u*34)+sin(v*33)) * 4
		24: return -exp(-pow(d/.18,2))*25
		25: return exp(-pow((u-.28)/.055,2))*90
		26: return absf(sin(u*16+v*3))*65
		27: return floorf(exp(-pow((d-.19)/.1,2))*5)*9
		28: return exp(-pow(d/.09,2))*88
		29: return pow(maxf(0,sin(u*37)*cos(v*33)),3)*12
		30: return -exp(-pow(d/.10,2))*48
		31: return -exp(-pow((u-.28)/.035,2))*74
	return 0

static func cave_centre(cell: Vector2i) -> Vector2:
	return Vector2(cell.x*256+72,cell.y*256+192)

static func in_cave_footprint(p: Vector3,cell: Vector2i) -> bool:
	var centre := cave_centre(cell)
	return absf(p.x-centre.x)<7.8 and p.z>centre.y-24 and p.z<centre.y+24
