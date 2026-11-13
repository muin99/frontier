extends RefCounted
const DRAFT := "user://outpost_procurement_v8.json"
const STARTER := {"solar":2,"battery":1,"oxygen":1,"habitat":1,"fabricator":1,"relay":1,"weather":1,"ice":1}
static var cached_catalog: Dictionary = {}
var credits := 3200
var kits: Dictionary = {}
var materials := {"alloy":8,"circuits":6,"polymer":6,"regolith":0,"ice":0,"water":15,"rations":12}

static func catalog() -> Dictionary:
	if cached_catalog.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/OUTPOST_CATALOG.json"))
		for item: Dictionary in data.items: cached_catalog[item.id] = item
	return cached_catalog

func mass() -> float:
	var value := 0.0
	for id: String in kits: value += float(catalog()[id].mass)*int(kits[id])
	for id: String in materials: value += int(materials[id])*.25
	return value

func buy(id: String,capacity := 260.0) -> String:
	if not catalog().has(id): return "Unknown hardware"
	var item: Dictionary = catalog()[id]
	if credits < int(item.cost): return "Insufficient procurement credits"
	if mass()+float(item.mass) > capacity: return "Cargo capacity exceeded"
	credits -= int(item.cost); kits[id] = int(kits.get(id,0))+1
	return ""

func starter() -> String:
	var before := snapshot()
	for id: String in STARTER:
		for amount: int in range(int(STARTER[id])):
			var error := buy(id)
			if error != "": restore(before); return error
	return ""

func snapshot() -> Dictionary:
	return {"credits":credits,"kits":kits.duplicate(),"materials":materials.duplicate()}

func restore(d: Dictionary) -> void:
	credits = maxi(0,int(d.get("credits",3200))); kits.clear()
	if d.get("kits") is Dictionary:
		for id: String in d.kits:
			if catalog().has(id): kits[id] = clampi(int(d.kits[id]),0,1000)
	if d.get("materials") is Dictionary:
		for id: String in materials: materials[id] = clampi(int(d.materials.get(id,0)),0,1000000)

func read_draft(path := DRAFT) -> void:
	for candidate: String in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: continue
		var d: Variant = parser.data
		if d is Dictionary: restore(d); return

func write_draft(path := DRAFT) -> bool:
	var f := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(snapshot())); f.close()
	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(path,path+".bak")!=OK: return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func rocket_pack() -> String:
	var before := snapshot()
	for id: String in catalog():
		if catalog()[id].get("required",false) and int(kits.get(id,0))<1:
			var reason := buy(id)
			if reason!="": restore(before); return reason
	return ""

func recommended_pack() -> String:
	var before := snapshot()
	var reason := rocket_pack()
	if reason != "": return reason
	for id: String in STARTER:
		while int(kits.get(id,0)) < int(STARTER[id]):
			reason = buy(id)
			if reason != "": restore(before); return reason
	return ""
