extends RefCounted
## Explain the decision before asking for it; no prior spacecraft vocabulary.
const FLIGHT := {
	"radiation watch":"Radiation is energy that can harm the crew. The payload is the science equipment, not the crew. Turn it off briefly so everyone can use the protected room.",
	"coolant imbalance":"Coolant carries heat away from equipment. Isolate means close off the leaking part. Standby means a spare system ready to take over.",
	"navigation correction":"Navigation means knowing where the ship is going. A small engine push early can correct the path before landing becomes difficult.",
	"power reserve":"Life support supplies the air and conditions people need. When electricity is low, turn off optional science equipment before turning off life support.",
	"seal inspection":"A seal keeps breathable air inside. A worsening pressure reading can mean a leak. Close off the affected section, inspect it and repair it.",
	"instrument calibration":"A star tracker estimates direction from stars. An inertial sensor estimates motion. Compare independent measurements when they disagree; a brighter screen is not better evidence.",
	"heat shield":"A heat shield protects the spacecraft from heating as it enters the atmosphere. Keep that protected side facing the oncoming air.",
	"thin atmosphere":"Mars has much thinner air than Earth. For this heavy crew vehicle, a parachute cannot finish the landing alone. Use landing engines and check the height and speed sensors.",
	"terrain diversion":"Landing radar measures the ground below. Divert means steer to another spot. Use an inspected smoother patch while enough fuel remains.",
	"dust obscuration":"Landing engines lift dust and can hide the ground from a camera. Use height and motion instruments that agree instead of guessing from the picture."
}

static func flight_help(title: String) -> String:
	return str(FLIGHT.get(title.get_slice(" / ",1),"Protect people first. Compare the available measurements before acting."))

const GLOSSARY := "Oxygen = breathing air. Battery = stored electricity for equipment. Suit integrity = how undamaged your suit is. Habitat = the crew's shelter. Evidence = an observation you collected. Payload = equipment carried for the mission. Mass = how much matter must be launched. Power = how quickly equipment uses energy. Credits = game money. A district is a different area of the map."
