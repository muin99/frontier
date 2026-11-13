extends RefCounted
## All values here are explicitly compressed game balances, not mission certification.
const LOADOUTS := [
	{"name":"SOLAR SCOUT", "detail":"Lightweight. Strong science payload; dust reduces charging.", "cost":64,"mass":32,"power":8,"drill":false,"spectrometer":true,"battery":110.0,"oxygen":140.0},
	{"name":"RESILIENT EXPLORER", "detail":"Fission backup, drill and spectrometer. Heavier, safer in dust.", "cost":88,"mass":44,"power":14,"drill":true,"spectrometer":true,"battery":135.0,"oxygen":150.0},
	{"name":"DEEP FIELD", "detail":"Drill, extended oxygen. Lower power; no spectrometer.", "cost":76,"mass":39,"power":9,"drill":true,"spectrometer":false,"battery":100.0,"oxygen":190.0}
]
const TARGETS := [
	{"name":"DELTA STRATA","instrument":"spectrometer","science":35,"observation":"Layered sediment is consistent with deposition. Spectra can constrain composition; they do not establish life.","source":"https://science.nasa.gov/mission/mars-2020-perseverance/science/"},
	{"name":"SUBSURFACE CORE","instrument":"drill","science":40,"observation":"A protected subsurface sample tests how exposure alters material. This target and assay are fictional; no biosignature is claimed.","source":"https://science.nasa.gov/mission/mars-2020-perseverance/science/"},
	{"name":"BASALT TRANSECT","instrument":"spectrometer","science":30,"observation":"Comparing igneous and sedimentary contexts improves a sample set. A spectrum alone cannot date a rock.","source":"https://science.nasa.gov/mission/mars-2020-perseverance/science/"},
	{"name":"RIDGE CONTEXT","instrument":"camera","science":20,"observation":"Regional topography reveals relief and basin context. MOLA at 4 pixels per degree cannot resolve these individual rocks.","source":"https://pds-geosciences.wustl.edu/missions/mgs/megdr.html"}
]
var loadout := 1
var site := 0
var oxygen := 150.0
var battery := 135.0
var integrity := 100.0
var science := 0
var samples: Array[int] = []
var elapsed := 0.0
var storm := false
var storm_finished := false
var repaired := false
var transit_safe := true
var phase := "PLANNING"
var log: Array[String] = []
var scan_progress := 0.0
var interpreted: Array[int] = []
var downlinked := false
var targets: Array = TARGETS.duplicate(true)
var pack: Array[String] = ["traction","climbing"]
var weather_driven := false
var solar_fraction := 1.0

func configure(which: int, landing: int) -> void:
	loadout = clampi(which,0,2); site = clampi(landing,0,1)
	oxygen = float(LOADOUTS[loadout].oxygen); battery = float(LOADOUTS[loadout].battery)
	integrity = 100; science = 0; samples.clear(); elapsed = 0; storm = false
	storm_finished = false; repaired = false; transit_safe = true; scan_progress = 0; interpreted.clear(); downlinked = false; log.clear(); phase = "TRANSIT"
	log.append("Architecture: " + str(LOADOUTS[loadout].name))
	log.append("Landing: basin approach" if site == 0 else "Landing: upland approach; +15 science / −12 integrity")
	if site == 1: integrity -= 12; science += 15

func transit(shelter: bool) -> void:
	transit_safe = shelter
	if not shelter: integrity -= 20; log.append("Kept instruments online during radiation alert: −20 integrity, +10 science"); science += 10
	else: log.append("Crew sheltered during transit alert; instruments powered down")
	phase = "SURFACE"

func tick(delta: float, sheltered: bool, sprinting: bool) -> void:
	if phase != "SURFACE": return
	elapsed += delta
	if not weather_driven: storm = elapsed >= 65 and elapsed < 125
	storm_finished = elapsed >= 125
	if sheltered:
		oxygen = minf(float(LOADOUTS[loadout].oxygen),oxygen+delta*5)
		var charge := 3.0 if loadout == 1 else (2.0*solar_fraction if weather_driven else (0.35 if storm else 2.0))
		battery = minf(float(LOADOUTS[loadout].battery),battery+delta*charge)
	else:
		oxygen = maxf(0,oxygen-delta*(0.55 if sprinting else 0.35))
		battery = maxf(0,battery-delta*(0.20 if storm else 0.065))
	if oxygen <= 0 or battery <= 0: integrity = maxf(0,integrity-delta*2)

func can_sample(index: int) -> String:
	if index < 0 or index >= targets.size(): return "Unknown target"
	if samples.has(index): return "Evidence already secured"
	var required: String = str(targets[index].get("tool",""))
	if required in ["traction","climbing","thermal"] and not pack.has(required): return "Pack the " + required + " kit at a habitat/refuge console."
	var tool: String = targets[index].instrument
	if tool != "camera" and not bool(LOADOUTS[loadout][tool]): return "Requires " + tool + ". This architecture trades away that capability."
	if battery < 8: return "Need 8 battery. Recharge at habitat."
	return ""

func collect(index: int) -> bool:
	if can_sample(index) != "": return false
	battery -= 8; science += int(targets[index].science); samples.append(index)
	if targets[index].get("type","") == "cache":
		oxygen = minf(float(LOADOUTS[loadout].oxygen),oxygen+45); battery = minf(float(LOADOUTS[loadout].battery),battery+25)
	log.append(str(targets[index].name) + ": " + str(targets[index].instrument) + ", −8 battery")
	return true

func repair() -> bool:
	if repaired or battery < 12: return false
	repaired = true; battery -= 12; integrity = minf(100,integrity+25)
	log.append("Used habitat spares: −12 battery, +25 integrity")
	return true

func return_gaps() -> String:
	if samples.size() < 2: return "Secure at least two different evidence targets before return."
	if integrity <= 0: return "Crew rescue required."
	return ""

func score() -> int:
	return maxi(0,science + int(integrity*0.5) + (20 if transit_safe else 0) + int((oxygen+battery)*0.05) + efficiency_score())

func efficiency_score() -> int:
	return int((100-int(LOADOUTS[loadout].cost))*0.5+(46-int(LOADOUTS[loadout].mass))*0.5)

func interpret(index: int, cautious: bool) -> bool:
	if not samples.has(index) or interpreted.has(index): return false
	interpreted.append(index)
	if cautious: science += 5; log.append(str(targets[index].name)+": limited inference supported by evidence (+5 science)")
	else: log.append(str(targets[index].name)+": overclaim rejected; these observations cannot establish life or age")
	return true

func downlink() -> bool:
	if downlinked or samples.is_empty() or battery < 15: return false
	downlinked = true; battery -= 15; science += 10
	log.append("Habitat high-gain downlink: −15 battery, +10 archived science; communication delay compressed")
	return true

func snapshot() -> Dictionary:
	return {"version":2,"loadout":loadout,"site":site,"oxygen":oxygen,"battery":battery,"integrity":integrity,"science":science,"samples":samples,"elapsed":elapsed,"repaired":repaired,"transit_safe":transit_safe,"phase":phase,"log":log,"interpreted":interpreted,"downlinked":downlinked,"pack":pack}

func restore(d: Dictionary) -> bool:
	if int(d.get("version",0)) not in [1,2]: return false
	for key: String in ["loadout","site","oxygen","battery","integrity","science","samples","elapsed","repaired","transit_safe","phase","log"]:
		if not d.has(key): return false
	if not d.loadout is float and not d.loadout is int: return false
	if not (d.site is float or d.site is int) or not is_finite(float(d.site)) or not is_finite(float(d.loadout)): return false
	if int(d.loadout) < 0 or int(d.loadout) > 2 or int(d.site) < 0 or int(d.site) > 1: return false
	if not d.samples is Array or not d.log is Array: return false
	if not d.get("interpreted",[]) is Array or not d.get("pack",[]) is Array: return false
	for entry: Variant in d.log:
		if not entry is String: return false
	if str(d.phase) not in ["SURFACE","RETURNED","FAILED"]: return false
	for v: Variant in [d.oxygen,d.battery,d.integrity,d.science,d.elapsed]:
		if not (v is float or v is int) or not is_finite(float(v)) or float(v) < 0: return false
	for v: Variant in d.samples:
		if not (v is float or v is int) or not is_finite(float(v)) or float(v) != float(int(v)) or int(v) < 0 or int(v) >= targets.size(): return false
	var unique_samples: Array = []
	for v: Variant in d.samples:
		if unique_samples.has(int(v)): return false
		unique_samples.append(int(v))
	loadout = int(d.loadout); site = int(d.site); oxygen = minf(float(d.oxygen),float(LOADOUTS[loadout].oxygen))
	battery = minf(float(d.battery),float(LOADOUTS[loadout].battery)); integrity = clampf(float(d.integrity),0,100)
	science = int(d.science); elapsed = float(d.elapsed); samples.assign(d.samples); log.assign(d.log)
	repaired = bool(d.repaired); transit_safe = bool(d.transit_safe); phase = str(d.phase)
	interpreted.clear()
	for v: Variant in d.get("interpreted",[]):
		if (v is int or v is float) and samples.has(int(v)) and not interpreted.has(int(v)): interpreted.append(int(v))
	downlinked = bool(d.get("downlinked",false))
	pack.clear()
	for value: Variant in d.get("pack",["traction","climbing"]):
		if str(value) in ["traction","climbing","thermal"] and not pack.has(str(value)) and pack.size() < 2: pack.append(str(value))
	return true
