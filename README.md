# Frontier 11: learn while playing

Run **[Play.cmd](Play.cmd)** and select **PLAY FIRST MISSION**. No rocket or space
knowledge is required to start. The first scans explain the tools and teach how
scientists interpret evidence. F1 defines unfamiliar terms. In campaign flight,
the coach explains each choice before you act and explains the result afterward.
This Windows release is in `build/windows-v11`.

The NASA services directory is `nasadatasets.md`. The game uses cached NASA PDS
MOLA terrain and MEDA temperature, pressure and wind products from that service
family. It does not connect to every listed API or require an online account.
See [the precise dataset mapping](docs/DATASETS.md) and
[beginner playtest notes](docs/ONBOARDING_PLAYTEST.md).

---

# Frontier 10: less floaty Mars movement

Run **[Play.cmd](Play.cmd)** for the updated build in `build/windows-v10`.
Mars acceleration remains 3.71 m/s²; the suited jump is now a restrained
0.75-metre hop instead of 1.35 metres. A controller test measured a 0.77-metre
apex and 1.28-second airtime. Increased downward floor snapping keeps walking
grounded over small terrain changes. The seven-platform course still passes
with the same jump height used in normal gameplay.

---

# Frontier 9: a playable first mission

Run **[Play.cmd](Play.cmd)** and choose **PLAY FIRST MISSION / GUIDED PRACTICE**.
This release is in `build/windows-v9`; older open game windows still run older
versions. The shareable package remains `build/Mohashunnyo-Windows.zip`.

The first mission supplies a rocket and equipment, teaches walking and scanning,
guides you to two observations, then marks the habitat for return. It has a short
briefing, a visible destination and distance, context-sensitive instructions,
F1 help and a simplified habitat console. Practice never spends campaign funds
or writes over expedition saves. Building is optional in this introductory loop.

Campaign setup now shows three steps: pack the recommended equipment, clear the
rocket, then choose a crew architecture and launch. The full equipment workshop
and weather rehearsal remain available as optional customization.

The full first-mission test used the real character controller with live weather,
survival and held scans: two observations, return, ascent and debrief completed in
131.47 simulated seconds with 100% integrity. See
[playtest findings and validation](docs/ONBOARDING_PLAYTEST.md).

---

# Frontier 8: mission review and NASA weather rehearsal

Run **[Play.cmd](Play.cmd)** or `build/windows-v8/Mohashunnyo.exe`.
The shareable Windows x64 package is `build/Mohashunnyo-Windows.zip`.
Keep the executable and `.pck` together. Gameplay works offline.

In mission planning, open **REHEARSE / NASA WEATHER & SURVIVAL TRADE-OFFS**.
Compare all three architectures under the same seed and landing region, see
oxygen and battery after an exposed EVA versus an early return to shelter,
and select a loadout. This uses the existing cached NASA PDS MEDA observations
in a new planning tool. Weather timing and reserve rates remain game models.

This update also hardens corrupt-save recovery, rejects duplicate evidence in
saves, prevents active-flight rocket reintegration, persists integration resets,
and fits menu scrolling to the viewport. The launcher prefers the new release.

All source verification groups passed, including real controller routes through
six regions, construction, campaign progression and host/client LAN. The exported
release passed expedition integration and host/client LAN checks. Manual release
UI checks covered title, planning, rehearsal, architecture selection, scrolling
and return to planning. This is not exhaustive testing of every procedural seed.

See **[challenge assessment, changes and remaining limits](docs/RELEASE_REVIEW.md)**.
The project matches the supplied `nasaguide.md` core objective. Freely selectable
orbits, detailed communications bandwidth and Internet matchmaking remain outside
this build. Competition eligibility and awards are organizer decisions.

---

# Frontier 7: build your Mars expedition

Run `build/windows-v7/Mohashunnyo.exe` with its `.pck`, or `Play.cmd`.

**Purchase → deploy → assemble → power → gather → fabricate → expand.**
Twenty original deployable hardware designs now support an outpost construction
and survival loop, alongside the streamed world, twelve field activities and LAN co-op.

Open **Mission Control / Field Systems** before launch and buy the **580-credit
starter outpost**. A physical procurement console also sits inside Mission Control.
On Mars, deploy two HELIOS solar arrays, VAULT, AERIS, HAVEN and FORGE within 20 m
of each other. Hold E for three assembly stages. Add ice extraction, a refinery,
greenhouse, relays and scientific instruments as your expedition expands.

**B** build kits · **Q** rotate ghost · **Enter/left-click** place · **Hold E**
assemble/use · **C** cargo/crafting · **G** gather · **J** journal/contracts ·
**R** rover · **L** LAN · **N** emergency kit · **Esc/right-click** cancel placement.

New sectors grant exploration points. Instruments reward new sector research;
eight construction contracts reward infrastructure milestones. Points are uncapped.
Field equipment needs power, water, communication and appropriate locations.
Kits, depleted deposits, installed hardware and research persist in version 7 saves.

See [iteration 7 details and validation](docs/ITERATION_07.md) and
[hardware art direction](docs/ART_DIRECTION_07.md). This is original speculative
modular equipment using the existing NASA-informed setting; engineering outputs
and resource distributions are game models. The older sections below are historical.

---

# Frontier 6: streamed Mars and LAN co-op

Run `build/windows-v6/Mohashunnyo.exe` with its `.pck`, or `Play.cmd`.
The world now streams seeded terrain beyond the original six districts. Nearby
sectors load while distant ones unload; completed activities persist. There is
no designed arena edge. Finite computer precision and storage still apply.

Twelve field activity families include relay/solar repair, sample delivery,
rover recovery, seismic stations, navigation/context transects, coring,
meteorite/cache assessment and timed low-G platform courses. Corrected suit glove
weights remove the disconnected hand pose; buffered jumps use Mars gravity.

**F** activity · **J** journal · **L** LAN host/join · **B** emergency kit ·
**R** rover · **Space** jump · **E** scan/equipment console · **Esc** pause.
Up to four players can share a seed and evidence/activity progress using a PC
on the same local network as host. Join its LAN IP on UDP 24642; no external
hosting service is required. Router isolation/firewalls can block local access.

See [iteration 6 details and validation](docs/ITERATION_06.md) for the architecture,
scientific distinctions, networking instructions and limits. The sections below
record the earlier finite-world prototype and should be read as historical.

---

# Mohashunnyo: A Long Way Home

**Iteration 5 — characters and seeded exploration, 4 November 2026.** The Windows build now includes the detailed articulated NASA Z2 suit, updated textured crew, redesigned mission control, six geological districts, 36 generated discoveries plus four starter targets, six refuges, a rover, traversal equipment, and seeded weather scenarios driven by a real archived MEDA temperature/pressure profile. [Iteration 5 details and checks](docs/ITERATION_05.md).

Mars controls added: **R** toggles the rover; **Space** jumps on foot. At a habitat/refuge press **E** to choose two of traction, climbing and thermal equipment. A new seed is chosen for a new session; the planning screen lets you enter or share a seed. Saves regenerate that same seed. Follow natural valley approaches; steep shortcuts require climbing gear. Survey **two districts** and return **two evidence targets** to finish, or explore all six districts and pursue the 1,000-point science report.

The following iteration-4 instructions remain useful; iteration-5 world size, score, source notes and traversal controls above supersede their historical limits. The game remains a finite approximately 1.5 km arena with reproducible procedural variants, not an infinite planet.

**Iteration 4 — a complete playable Mars expedition**, built with Godot 4.7.2 on 4 November 2026. Design a mission, depart Earth, respond to a transit alert, explore a NASA-data-driven regional landscape, gather evidence, survive a dust front, and return your crew to Earth.

## Start here

Double-click **`build/windows-v5/Mohashunnyo.exe`** or **[Play.cmd](Play.cmd)**. Keep `Mohashunnyo.pck` beside the executable. The exported Windows x64 build works offline and needs neither Python nor the editor. A shareable ZIP is in `build/Mohashunnyo-Windows.zip`. An already-open older executable keeps running its older data; start the v5 executable to see this update.

For the editable source version, open **[Edit.cmd](Edit.cmd)** and press F5. **[Play.cmd](Play.cmd)** prefers the packaged build when present and otherwise runs source. The title screen opens the retained Earth spaceport; clearing its procurement/calculation/launch gates now continues into the expedition with its required fission baseline. The handoff records ground mass and power and explicitly maps them to normalized field reserves.

### Expedition controls

| Control | Action |
|---|---|
| WASD | Move relative to camera |
| Mouse | Orbit / look |
| Shift | Sprint; consumes oxygen faster |
| Hold E near a survey beacon | Scan for three seconds; consumes 8 battery |
| E within habitat perimeter | Open recovery, spares, downlink and return console |
| V / mouse wheel | First/third person / zoom |
| Tab | Survey map; explored regions reveal as you move |
| Escape | Pause, checkpoint, graphics and sensitivity |
| F11 | Fullscreen |
| Tab / Enter in menus | Focus / activate buttons |

### The playable loop

1. Select Solar Scout, Resilient Explorer or Deep Field. Instruments determine which targets you can collect. Cost and mass margins are visible; values are explicit game balances.
2. Select basin or upland approach. The menu shows the corresponding original MOLA elevation; upland adds science and reduces integrity.
3. Commit the departure burn and choose whether to shelter the crew during the transit alert.
4. Follow the cyan beacons. Hold E within five metres to secure evidence. Interpret it cautiously for a science bonus.
5. A dust front crosses the area 65–125 seconds after touchdown. Solar charging falls; exposed suits lose integrity. The fission architecture retains charging capacity.
6. Stand within 12 metres of the habitat to refill oxygen and charge batteries. Use spares once, or downlink evidence at a battery cost.
7. Secure at least two different evidence targets, return to the habitat, and command ascent. The debrief explains the consequences of your decisions.

All three architectures can complete a mission. Reserves reaching zero drain integrity; zero integrity ends the expedition with a causal explanation and retry. Menus pause simulation. Autosaves occur after evidence and every 20 seconds of active field play; Continue restores the latest valid save or backup.

### NASA evidence and competition status

Real NASA PDS MOLA elevations drive the terrain mesh/collision and landing-site readouts. The original 16-bit source, PDS label, crop, checksum and reproducible [processing script](tools/prepare_mars.py) are included. See [data transformations and limits](docs/MARS_DATA.md). The terrain represents regional context at independently compressed horizontal/vertical scales. Individual rocks, targets, hardware, weather and resource rates are fictional. No mineral, life, local slope or landing-safety inference is claimed.

**This is pre-event development. Competition eligibility is unconfirmed.** The official event is 14–15 November 2026; organizer guidance restricts pre-event solution work. Full challenge/FAQ retrieval failed during this build. Disclose this prototype and confirm current global/local rules before submitting. See the [verified facts, requirements matrix and outstanding team actions](docs/COMPETITION_2026.md). Winning is not guaranteed.

### Verification and build

```powershell
python tools/prepare_mars.py
powershell -ExecutionPolicy Bypass -File tools/Verify.ps1
python tools/fetch_windows_template.py
powershell -ExecutionPolicy Bypass -File tools/Build.ps1
```

Tests cover architecture viability, instrument/duplicate/return gates, resource exhaustion, dust effects, one-use repairs, interpretation, downlink, save roundtrips, actual terrain collision, full controller traversal of the four-target route, hold-to-scan and menus. The retained Earth spaceport has a separate briefing-to-liftoff smoke check. [Validation notes](docs/ITERATION_04.md) record captures, performance and limits.

Development used the requested [gamedev skills repository](https://github.com/gamedev-skills/awesome-gamedev-agent-skills), revision `19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9`: router, Godot 3D/UI/testing/export, camera systems, level design and save systems. The local clone is tooling excluded from Git.

## Legacy Earth spaceport documentation

The sections below describe the retained Earth facility and historical proposal. The current shipped expedition and competition status are documented above; historical dates/status below do not establish eligibility.

## Play the native game

Double-click **[Play.cmd](Play.cmd)**. The portable engine and textures are already downloaded on this machine. On a fresh checkout, the launcher uses Python 3 to download them before importing and starting the game. After setup, gameplay works offline. This is a native desktop application, not a browser game.

Double-click **[Edit.cmd](Edit.cmd)** to open Godot. Press F5 to play; the facility geometry is constructed from deterministic Godot code when the scene runs.

| Control | Action |
|---|---|
| WASD / arrow keys | Walk |
| Mouse | Orbit third-person camera |
| Mouse wheel | Change camera distance |
| V | Toggle first-person / third-person view |
| Shift | Sprint |
| Left click while aiming at a terminal | Open terminal |
| Drag catalog card onto integration slot | Preview module fit |
| Tab | Facility map |
| Escape | Pause / settings / resume |
| F11 | Fullscreen |

## Playable mission flow

Accept the flight-director briefing, procure a Mars mission architecture, wait for ground-crew delivery, inspect the integration manifest, and validate three NASA-based calculations. Launch Operations unlocks only after the vehicle, calculations, and logistics are complete. The T−10 sequence ends with engine ignition and a visible launch vehicle ascent.

The Flight Lab covers the NASA ideal rocket equation, NASA-STD-3001 crew food energy, and Earth–Mars communication latency from NASA human-systems research. Published values, equations, and fictional scenario assumptions are identified separately and link to their primary NASA sources.

## First playable iteration

Explore the arrival concourse, equipment shop, spacecraft integration hall, mission control and outdoor launch pad. The facility includes equipment racks, a pressure-suit display, a spacecraft on cradles, an overhead crane, diagnostic benches, launch vehicle, service gantry and storage tanks.

Movement uses camera-relative WASD, acceleration, floor/wall collision and sprinting. Mouse movement orbits an independent third-person camera while the textured, rigged player turns and animates with travel. Settings include graphics presets and saved mouse sensitivity. The facility map shows the player's position. Shop and engineering terminals offer a native drag-and-drop **visual module preview**.

The Compatibility renderer, shared PBR materials, batched structural geometry and downloaded 1K CC0 textures target the current RTX 2050 / 8 GB RAM laptop. Start with Balanced; choose Performance if needed. Interior lights do not cast shadows. The HUD displays FPS, and settings scale shadow and antialiasing costs. See [iteration notes](docs/ITERATION_01.md) for checks and limits.

Mission control displays cited NASA/JPL planetary parameters from the cached [reference file](game/assets/NASA_REFERENCES.json). These are reference information, not live telemetry or a gameplay-driving terrain dataset. The facility and vehicles are fictional concepts. Mars observational data and simulation are planned in the [dataset ledger](docs/DATASETS.md).

Downloaded materials: ambientCG [MetalPlates006](https://ambientcg.com/view?id=MetalPlates006) and [Concrete034](https://ambientcg.com/view?id=Concrete034), CC0. Source metadata and archive checksums accompany the textures. See [third-party notices](docs/THIRD_PARTY.md).

## Development

```powershell
python tools/setup.py
powershell -ExecutionPolicy Bypass -File tools/Verify.ps1
```

The `game/scripts` directory contains the facility builder, player controller, HUD, map and drag-and-drop components. Portable engine binaries, downloaded archives and import caches are ignored by Git. The launcher runs the project using portable Godot; a standalone exported game executable is not packaged yet.

## Iteration 2: crew and mission design

The player is now a visible third-person astronaut. Five animated staff NPCs work throughout the facility. The outfitting terminal offers 21 NASA-informed spacecraft, oxygen, water, food, propulsion, ISRU, power, surface and safety assets. Purchases use a constrained gameplay budget, create timed ground-crew deliveries and feed the engineering manifest.

Engineering tracks mass, power and consumables and explains every missing flight requirement. A complete baseline unlocks launch control and a visible T−10 countdown. NASA-published values, architecture targets and gameplay estimates are labeled separately in the catalog, with direct primary-source links in the source ledger. See [iteration 2 notes](docs/ITERATION_02.md).

Environmental room labels use cyan semi-transparent displays mounted above doors, with separate front/back lettering so both sides read left-to-right. Redundant floating labels were removed.

## Original proposal and planning archive

## Core pitch

Players receive a constrained budget and design a crewed Mars mission. Every choice has coupled consequences: payload increases science capability but also mass; mass changes launch and propellant needs; power architecture affects survival; landing-site terrain changes risk and discovery opportunities. After launch, players manage transit hazards, establish a surface outpost, keep a crew alive, explore a fog-covered Mars map, collect data-backed scientific discoveries, and attempt a safe return to Earth.

The experience combines:

- a first-person 3D exploration and discovery loop;
- tense cooperative-style incident management (designed as single-player first);
- short, meaningful engineering calculations rather than trivia quizzes;
- real NASA data with visible provenance inside the game;
- a complete mission loop that can be demonstrated in under three minutes.

## Documents

- [Product brief](docs/PRODUCT_BRIEF.md)
- [Iteration roadmap](docs/ROADMAP.md)
- [NASA dataset ledger](docs/DATASETS.md)
- [Science model and equations](docs/SCIENCE_MODEL.md)
- [Competition strategy](docs/COMPETITION_STRATEGY.md)
- [Research log](docs/RESEARCH_LOG.md)
- [Decision log](docs/DECISIONS.md)

## Current competition facts

- Event: **November 14–15, 2026**
- Theme: **The Next Frontier**
- Candidate challenge: **Space Mission Design Game**
- Full challenge statement/resources: expected **October 28, 2026**
- Team size: up to six
- Current date for this plan: **October 10, 2026 (Asia/Dhaka)**

## Compliance gate

The original plan deferred implementation until the event. The user subsequently authorized this native 3D prototype; see D-006 in the decision log. This authorization does not establish competition eligibility. Confirm the global and local rules and verify the historical event claims above before using pre-event work in a submission.

