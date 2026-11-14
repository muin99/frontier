extends RefCounted
## Small atomic JSON store used for Earth lab progress.
static func read(path: String) -> Dictionary:
	for candidate: String in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate))==OK and parser.data is Dictionary: return parser.data
	return {}

static func write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(data)); file.close()
	if FileAccess.file_exists(path) and DirAccess.rename_absolute(path,path+".bak")!=OK: return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK
