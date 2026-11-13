extends RefCounted
const PATH := "user://campaign_v8.json"
const Cargo = preload("res://scripts/outpost_cargo.gd")
var id := ""
var status := "PLANNING"
var expedition_number := 1
var bank := 3200
var total_score := 0
var last_score := 0
var last_grant := 0
var integrated := false
var integration_step := 0
var persistent := true
var seed_value := 42601

func _init() -> void:
	id = str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec())

func quota() -> int:
	return 150+(expedition_number-1)*100

func read() -> void:
	for candidate: String in [PATH,PATH+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: continue
		var d: Variant = parser.data
		if d is Dictionary and d.get("id") is String and d.get("status") in ["PLANNING","ACTIVE","FAILED"]: restore(d); return

func snapshot() -> Dictionary:
	return {"id":id,"status":status,"expedition":expedition_number,"bank":bank,"score":total_score,"last_score":last_score,"last_grant":last_grant,"integrated":integrated,"integration_step":integration_step,"seed":seed_value}

func restore(d: Dictionary) -> void:
	id = str(d.get("id",id)); status = str(d.get("status","PLANNING")); expedition_number = maxi(1,int(d.get("expedition",1))); bank = maxi(0,int(d.get("bank",3200))); total_score = maxi(0,int(d.get("score",0))); last_score = maxi(0,int(d.get("last_score",0))); last_grant = maxi(0,int(d.get("last_grant",0))); integrated = bool(d.get("integrated",false)); integration_step = clampi(int(d.get("integration_step",0)),0,3)
	seed_value = int(d.get("seed",42601))

func write() -> bool:
	if not persistent: return true
	var f := FileAccess.open(PATH+".tmp",FileAccess.WRITE)
	if f==null: return false
	f.store_string(JSON.stringify(snapshot())); f.close()
	if FileAccess.file_exists(PATH) and DirAccess.rename_absolute(PATH,PATH+".bak")!=OK: return false
	return DirAccess.rename_absolute(PATH+".tmp",PATH)==OK

func missing(stock: RefCounted) -> Array[String]:
	var gaps: Array[String] = []
	for key: String in Cargo.catalog():
		var spec: Dictionary = Cargo.catalog()[key]
		if spec.get("required",false) and int(stock.kits.get(key,0))<1: gaps.append(str(spec.name))
	return gaps

func integrate(stock: RefCounted,answer: int) -> String:
	if status=="FAILED": return "Campaign lost. Start a new campaign."
	if status=="ACTIVE": return "Return from the active expedition before integrating another rocket."
	if not missing(stock).is_empty(): return "Purchase required rocket components first."
	var sequence := [1,2,0]
	if answer!=sequence[integration_step]:
		integration_step = 0; integrated = false; write()
		return "Integration order rejected. Review isolation, verification and clearance."
	integration_step += 1
	if integration_step>=3: integrated = true; integration_step = 0
	write(); return ""

func commit(stock: RefCounted,architecture_cost: int,seed_number := 42601) -> String:
	if architecture_cost < 0: return "Invalid architecture cost."
	if status=="FAILED": return "Campaign lost. Start again with a new budget."
	if status=="ACTIVE": return "An expedition is already active. Continue its checkpoint."
	var gaps := missing(stock)
	if not gaps.is_empty(): return "Rocket incomplete: "+", ".join(gaps)
	if not integrated: return "Integrate and clear the rocket before launch."
	if stock.credits<architecture_cost: return "Retain %d credits for the crew architecture." % architecture_cost
	stock.credits -= architecture_cost; bank = stock.credits; status = "ACTIVE"; last_score = 0; last_grant = 0; seed_value = seed_number
	write(); return ""

func settle(success: bool,score: int) -> int:
	if status!="ACTIVE": return 0
	if not success:
		bank = 0; total_score = 0; last_score = 0; last_grant = 0; integrated = false; integration_step = 0; status = "FAILED"; write()
		if persistent:
			var erased := Cargo.new(); erased.credits = 0; erased.kits.clear(); erased.materials.clear(); erased.write_draft()
		return 0
	last_score = maxi(0,score); total_score += last_score
	last_grant = 2200+int(last_score*1.25); bank += last_grant; expedition_number += 1; integrated = false; integration_step = 0; status = "PLANNING"
	write()
	if persistent:
		var next_stock := Cargo.new(); next_stock.credits = bank; next_stock.write_draft()
	return last_grant

func restart() -> void:
	id = str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec()); status = "PLANNING"; expedition_number = 1; bank = 3200; total_score = 0; last_score = 0; last_grant = 0; integrated = false; integration_step = 0; seed_value = 42601; write()
	if persistent:
		var stock := Cargo.new(); stock.write_draft()
