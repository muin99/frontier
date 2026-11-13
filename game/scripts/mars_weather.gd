extends RefCounted
## Sensor observations + explicitly simulated weather states.
const STATES := ["CLEAR","HIGH CLOUD","DUST HAZE","LOCAL DUST FRONT","COLD TWILIGHT","DUST DEVILS"]
var data: Dictionary
var seed_value := 42601
var temperature_c := -45.0
var measured_temperature_c := -45.0
var pressure_pa := 740.0
var state := "CLEAR"
var wind_mps := 3.0
var fog := 0.0012
var severity := 0.0
var solar_fraction := 1.0
var density := .017
var dynamic_pressure_pa := 0.0
var daylight := 1.0

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/meda/weather_profile.json"))

func update(elapsed: float,region: String,seed_number: int) -> void:
	seed_value = seed_number
	var profile: Array = data.profile
	var index := posmod(int(elapsed/16)+posmod(seed_value,profile.size()),profile.size())
	var next_index := (index+1)%profile.size(); var t := fmod(elapsed/16,1)
	temperature_c = lerpf(float(profile[index].temperatureK),float(profile[next_index].temperatureK),t)-273.15
	measured_temperature_c = temperature_c
	pressure_pa = lerpf(float(profile[index].pressurePa),float(profile[next_index].pressurePa),t)
	var block := int(elapsed/55)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value+block*104729
	var weather_index := rng.randi_range(0,5)
	# Early clear interval teaches exploration before the first hazard.
	if elapsed < 45: weather_index = 0
	state = STATES[weather_index]
	severity = [0.0,0.05,0.25,0.85,0.15,0.4][weather_index]
	fog = [0.0008,0.0012,0.003,0.011,0.0018,0.002][weather_index]
	var quantiles: Dictionary = data.windAnalog.quantilesMps
	wind_mps = float(quantiles[["0.2","0.5","0.75","0.99","0.1","0.9"][weather_index]])
	solar_fraction = [1.0,0.8,0.55,0.18,0.12,0.65][weather_index]
	# An explicitly compressed illumination cycle; sensor observations stay separate.
	daylight = clampf(sin(elapsed*TAU/1800+.9),.04,1)
	solar_fraction *= daylight
	temperature_c -= (1-daylight)*12
	density = pressure_pa/(188.92*(measured_temperature_c+273.15))
	dynamic_pressure_pa = .5*density*wind_mps*wind_mps
	if region == "highlands":
		temperature_c -= 10 # Explicit local-altitude scenario adjustment.
		if weather_index in [1,4]: state = "FROST HAZE"
