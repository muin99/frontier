extends SceneTree
func _initialize() -> void:
	var store = preload("res://scripts/progress_store.gd")
	var path := "user://lab_store_test_"+str(Time.get_ticks_usec())+".json"
	var okay := true
	for i: int in range(4):
		okay = store.write(path,{"step":i}) and okay
	okay = int(store.read(path).get("step",-1))==3 and okay
	var broken := FileAccess.open(path,FileAccess.WRITE); broken.store_string("{broken"); broken.close()
	okay = int(store.read(path).get("step",-1))==2 and okay
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("LAB SAVE: ","PASS" if okay else "FAIL"," / repeated atomic writes and corrupt-primary backup recovery")
	quit(0 if okay else 1)
