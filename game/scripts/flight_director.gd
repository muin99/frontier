extends RefCounted
var stage := 0
var mistakes := 0
var seed_value := 0
const EVENTS := [
	["TRANSIT / radiation watch","Particle exposure is rising. The shelter is ready, but the survey payload is consuming the reserve bus.",["Keep the crew exposed for extra data","Power down the payload and shelter the crew","Discard the shielding"],1,"Radiation exposure is a simulated operational event; this is not a live forecast."],
	["TRANSIT / coolant imbalance","A coolant loop is losing pressure. A cross-strapped standby loop is available.",["Isolate the leaking branch and switch to standby","Override every pressure limit","Disable thermal monitoring"],0,"Thermal-control reliability is mission-critical; the failure and remedy are authored."],
	["TRANSIT / navigation correction","Tracking shows an approach error. A small early correction preserves the landing corridor.",["Wait until atmospheric entry","Shut down guidance","Use the planned low-thrust correction window"],2,"A simplified trajectory-management decision, not a numerical flight solution."],
	["TRANSIT / power reserve","The battery reserve is below its target while the cabin load is stable.",["Shed nonessential payload loads","Disable life support first","Keep every heater at maximum"],0,"A game power trade-off rather than a spacecraft electrical model."],
	["TRANSIT / seal inspection","A pressure-seal trend is worsening before entry. Cabin isolation and repair supplies are ready.",["Ignore the trend","Isolate, inspect and reseal the affected branch","Open the cabin to vacuum"],1,"Pressure loss is modeled through reserves and integrity, not lethal decompression physics."],
	["TRANSIT / instrument calibration","A star tracker disagrees with the inertial estimate. Independent reference measurements remain available.",["Trust the brighter display","Delete the measurements","Compare independent references before the burn"],2,"Cross-checking independent sensors is a grounded engineering practice."],
	["ENTRY / heat shield","The entry attitude corridor is closing. The thermal shield must face the incoming flow.",["Maintain the shield-first entry attitude","Expose the cabin hatch","Deploy a rope to slow down"],0,"Mars entry involves severe heating; this is an authored decision sequence."],
	["DESCENT / thin atmosphere","The parachute has reduced speed, but terminal descent remains too fast for touchdown.",["Assume a parachute is sufficient","Discard the landing radar","Arm terminal propulsion and verify descent sensors"],2,"The thin atmosphere makes Mars landing difficult; parachutes alone are insufficient for this fictional crew vehicle."],
	["LANDING / terrain diversion","Radar detects a steep, blocky patch inside the landing ellipse. A smoother divert corridor is within fuel margin.",["Land on the sharpest ridge","Divert to the verified low-slope patch","Disable radar to save power"],1,"Hazard avoidance and fuel margin are simplified game constraints."],
	["LANDING / dust obscuration","Plume dust is reducing visual contrast near touchdown. Radar and inertial estimates still agree.",["Use the cross-checked descent instruments","Fly only by the camera image","Switch off every sensor"],0,"The simulated scene is not a validated powered-descent solution."]
]

func reset(seed_number: int) -> void:
	stage = 0; mistakes = 0; seed_value = seed_number

func current() -> Array:
	var index := posmod(seed_value+stage*5,6) if stage<3 else 6+posmod(seed_value+stage,4)
	return EVENTS[index]

func answer(choice: int) -> bool:
	var correct := choice==int(current()[3])
	if not correct: mistakes += 1
	stage += 1; return correct

func finished() -> bool:
	return stage>=6
