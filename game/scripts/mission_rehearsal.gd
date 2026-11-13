extends RefCounted
## Runs the same suit and MEDA-driven weather models as field play, without
## changing the real mission. Time, charging and consumption are game balances.
const Model = preload("res://scripts/expedition_model.gd")
const Weather = preload("res://scripts/mars_weather.gd")

static func run(loadout: int, site: int, seed_number: int, duration := 180, shelter_at := -1) -> Dictionary:
	var suit := Model.new(); suit.configure(loadout,site); suit.transit(true)
	suit.weather_driven = true
	var weather := Weather.new()
	var dust_seconds := 0
	var lowest_solar := 1.0
	var minimum_temperature := INF
	var maximum_wind := 0.0
	for second: int in range(clampi(duration,1,1800)):
		weather.update(float(second),"highlands" if site == 1 else "basin",seed_number)
		suit.storm = weather.severity >= .8; suit.solar_fraction = weather.solar_fraction
		suit.tick(1.0,shelter_at >= 0 and second >= shelter_at,false)
		if suit.storm: dust_seconds += 1
		lowest_solar = minf(lowest_solar,weather.solar_fraction)
		minimum_temperature = minf(minimum_temperature,weather.temperature_c)
		maximum_wind = maxf(maximum_wind,weather.wind_mps)
	return {"oxygen":suit.oxygen,"battery":suit.battery,"integrity":suit.integrity,"dust_seconds":dust_seconds,"solar":lowest_solar,"temperature":minimum_temperature,"wind":maximum_wind}
