extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var errors: Array[String] = []
	var Model = preload("res://scripts/expedition_model.gd")
	var lab = preload("res://scripts/mission_rehearsal.gd")
	for seed_number: int in [1,42601,20261113]:
		for architecture: int in range(3):
			var exposed: Dictionary = lab.run(architecture,0,seed_number)
			var recovered: Dictionary = lab.run(architecture,0,seed_number,180,90)
			if exposed != lab.run(architecture,0,seed_number): errors.append("Non-reproducible rehearsal")
			if recovered.oxygen <= exposed.oxygen or recovered.battery <= exposed.battery: errors.append("Shelter did not improve reserves")
			if exposed.oxygen < 0 or exposed.solar < 0 or exposed.solar > 1: errors.append("Invalid reserves/solar")
	var model := Model.new(); model.configure(1,0); model.transit(true)
	var good: Dictionary = model.snapshot()
	for patch: Dictionary in [{"site":{}},{"log":[7]},{"samples":[0,0]},{"samples":[0.5]},{"pack":5},{"interpreted":false}]:
		var bad: Dictionary = good.duplicate(true); bad.merge(patch,true)
		if model.restore(bad): errors.append("Malformed save accepted: "+str(patch))
	if not model.restore(good): errors.append("Valid save rejected")
	var campaign := preload("res://scripts/campaign.gd").new(); campaign.persistent = false
	var cargo := preload("res://scripts/outpost_cargo.gd").new()
	if cargo.recommended_pack()!="": errors.append("Recommended mission cannot be afforded")
	var packed: Dictionary = cargo.snapshot().duplicate(true)
	if cargo.recommended_pack()!="" or cargo.snapshot()!=packed: errors.append("Recommended pack duplicates equipment")
	var poor := preload("res://scripts/outpost_cargo.gd").new(); poor.credits = 1500
	var poor_before: Dictionary = poor.snapshot().duplicate(true)
	if poor.recommended_pack()=="" or poor.snapshot()!=poor_before: errors.append("Recommended pack not atomic")
	if campaign.commit(cargo,-10)=="": errors.append("Negative cost accepted")
	cargo.rocket_pack(); campaign.status = "ACTIVE"
	if campaign.integrate(cargo,1)=="": errors.append("Active flight reintegration accepted")
	# Exercise actual repeated backup replacement using an isolated test file.
	var path := "user://review_regression_"+str(Time.get_ticks_usec())+".json"
	for i: int in range(4):
		cargo.credits = 3000-i
		if not cargo.write_draft(path): errors.append("Repeated save failed")
	var restored := preload("res://scripts/outpost_cargo.gd").new(); restored.read_draft(path)
	if restored.credits != 2997: errors.append("Latest checkpoint not restored")
	var f := FileAccess.open(path,FileAccess.WRITE); f.store_string("{broken"); f.close()
	restored.read_draft(path)
	if restored.credits != 2998: errors.append("Backup recovery failed")
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	for error: String in errors: push_error(error)
	print("MISSION REVIEW: ","PASS" if errors.is_empty() else "FAIL"," / MEDA rehearsal, architecture trade-offs, corrupt saves, campaign gates, repeated saves, backup recovery")
	quit(0 if errors.is_empty() else 1)
