extends Node
var ambient: AudioStreamPlayer
var pressure: AudioStreamPlayer
var volume := .45
var config := ConfigFile.new()
func _ready() -> void:
	config.load("user://music_settings.cfg"); volume = clampf(float(config.get_value("music","volume",.45)),0,1)
	for file: String in ["frontier_ambient","frontier_pressure"]:
		var player := AudioStreamPlayer.new(); add_child(player)
		var stream: AudioStreamWAV = load("res://assets/audio/"+file+".wav").duplicate(); stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_begin = 0; stream.loop_end = int(stream.get_length()*stream.mix_rate)
		player.stream = stream; player.volume_db = -80
		if file=="frontier_ambient": ambient = player
		else: pressure = player
		if DisplayServer.get_name()!="headless": player.play()

func update_mix(delta: float,danger: float) -> void:
	if not is_instance_valid(ambient): return
	var a := linear_to_db(maxf(.0001,volume*(.38-danger*.14)))
	var b := linear_to_db(maxf(.0001,volume*danger*.34))
	ambient.volume_db = lerpf(ambient.volume_db,a,1-exp(-delta*2)); pressure.volume_db = lerpf(pressure.volume_db,b,1-exp(-delta*2))

func set_volume(value: float) -> void:
	volume = clampf(value,0,1); config.set_value("music","volume",volume); config.save("user://music_settings.cfg")
