# Iteration 2 — Crew and mission design

Built October 19, 2026. This iteration turns the spaceport into a staffed third-person mission-design prototype.

## Player and staff

The controllable character is now a visible rigged human with a collision-aware third-person orbit camera. Movement stays camera-relative; the mouse orbits, the wheel changes distance, and the character turns toward travel. Five lightweight NPC staff members patrol bounded work routes in mission control, outfitting, engineering and the pad. Their roles are flight director, propulsion engineer, life-support engineer, systems engineer and ground crew. These are functional ambient workers with walking and idle motion, not conversational AI.

The human mesh and skeleton come from Quaternius's CC0 Universal Base Characters through a public repository with the license preserved locally. Runtime lab coats, collars, badges, role accents, equipment and procedural bone motion turn the shared efficient rig into facility scientists and crew. This replaces the original box-built placeholder humans while avoiding six heavyweight unique character meshes on an 8 GB development machine.

## Mission design loop

The outfitting terminal contains 21 purchasable variants across spacecraft, life support, consumables, propulsion, Mars ISRU, power, surface systems and safety. A $6.5 billion gameplay budget allows a minimum valid mission with limited room for optional equipment. Purchases update the HUD and manifest and enter a five-second delivery queue. The ground-crew NPC carries a visible equipment crate between outfitting and integration; the crate clears when delivery completes.

Engineering shows total mission mass, net power load, consumable quantities and mandatory readiness gaps. Launch control holds the vehicle until the baseline includes a crew capsule, transit habitat, Mars lander, oxygen generation, carbon-dioxide removal, water recovery, 500-day food pack, crew-scale ISRU, fission surface power, surface habitat, medical system, 25 tonnes of ascent oxygen and 1,000 kg of water. A valid manifest unlocks a visible T−10 terminal count and liftoff state. Ascent remains a later iteration.

These requirements form a legible game architecture, not a flight-certified Mars mission design. They do not yet cover trajectory, launch vehicle performance, redundancy voting, spares, boiloff, radiation dose, entry/descent/landing, crew workload, planetary protection, communications geometry, thermal control or abort modes.

## Data discipline

`game/assets/MISSION_CATALOG.json` stores every item and source. Each item labels one of three evidence classes:

- NASA spacecraft/reference value;
- NASA architecture or technology target;
- gameplay engineering estimate derived from the function or scale.

Costs are explicitly fictional gameplay estimates. NASA does not publish a compatible price list for these conceptual Mars systems. Several concept masses and power loads are estimates and are stated as such in the shop.

Primary references include Orion's four-crew/21-day capability, ISS environmental-control functions, NASA's 98% water-recovery milestone, NASA-STD-3001's 3,035 kcal crew-day requirement, COPV safety and use, MOXIE's measured oxygen production, Mars DRA 5.0, published Mars ISRU oxygen-production needs, Mars surface power studies and NASA's fission-power architecture decision. The in-game source ledger links directly to each record.

## Signage and visual direction

Room names now appear only on cyan, semi-transparent display panels above their doors. Each panel has a separately oriented front and back caption so lettering reads left-to-right from both approaches. Previous floating room titles, floor text and redundant destination labels were removed. Operational text remains attached to terminals and workstations.

## Verification

The automated smoke check still probes all navigation routes and wall/floor collision. It now also opens all terminals, verifies catalog purchase accounting and aggregation, proves an incomplete mission cannot bypass readiness, purchases the complete baseline, verifies all mandatory checks clear, and starts the countdown. NPC bodies are excluded only from static route probing because their positions vary; they retain runtime collision.
