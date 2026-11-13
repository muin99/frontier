# Iteration 5 — detailed characters and exploration

4 November 2026. This iteration responds to the request to replace weak character art and give Mars substantially more variety, terrain challenges and reproducible discovery.

## Characters and mission control

- Replaced the primitive Mars avatar with a NASA Z2 suit derivative: 50,864 vertices / 30,904 triangles, retained textile and normal maps, boots, gloves, visor and suit hardware.
- `prepare_suit.py` decompresses the official Draco source, normalizes height to 1.88 m, authors nine-joint soft skinning and idle/walk/run animation, and records source/derivative SHA-256. This is an adapted concept suit, not validated Mars EVA hardware.
- Two surface engineers use that articulated asset. Ground crew/player use four textured MakeHuman variants with different faces, hair and clothing. Rigid coat-panel overlays were removed; skin, eyes and hair receive separate material tuning. Character art is improved real-time asset work, not a claim of photorealistic digital humans.
- Mission control has paired console islands, keyboard details, seats, server bays, task lighting and a large trajectory/telemetry wall. Walking cross-aisles remain open.

## World and play

- Finite 1,536 m arena with six geological analog districts: aeolian dunes, basalt, layered canyon, pale mesa, cold highlands and impact rim.
- MOLA regional context plus seeded local geometry, distinct material families, textured strata and outcrops, connected valley approaches, and local site approaches. A cached triangulated height surface keeps props and collision aligned.
- Four starter targets plus 36 generated discoveries. Caches, weather stations, cores, refuges, outcrops and overlooks mix with rarer meteorite candidates and eroded rock passages. These are authored/generated hypotheses and objects, not claimed orbital detections.
- Advanced markers reveal near the explorer; seed changes alter district centres, terrain detail, site positions and rare finds. A seed reproduces the same generator version. Fresh sessions choose a new seed; planning accepts manual/shared seeds. Checkpoints retain seed, generator version, visited districts, evidence and equipment.
- Version 5 writes `expedition_v5.json` and its backup; the title screen can import an earlier checkpoint without overwriting the old save. This also avoids concurrent older executables writing into the new save slot.
- R deploys a detailed NASA Space Exploration Vehicle concept model for long travel, using a simplified arcade controller. It consumes battery and cannot jump or climb as steeply as an equipped astronaut. Space jumps on foot. The two-slot pack trades dune traction, climbing capability and thermal protection. Six refuges provide recovery and equipment swaps; return launch requires the main habitat.
- Complete the mission by surveying two districts and securing two evidence targets; continued exploration raises the report toward a 1,000-point cap.

## Weather and scientific limits

Real archived MEDA sol 20 calibrated temperature and pressure drive a visible interpolated sensor profile. Wind magnitudes use empirical quantiles of stationary-rover MEDA sol 36 retrievals, with missing-value screening and documented missing uncertainty/boom flags. Six seeded weather scenarios change haze, clouds, illumination, dust particles, visibility and solar charging. Assignment of wind quantiles, storm timing, frost scenarios and resource consequences are game models; different sols are not presented as contemporaneous. Read `WEATHER_DATA.md` and `MARS_DATA.md` before describing the simulation.

## Verification

The source suite checks: core mission economics/resource gates, retained spaceport procurement/calculations/launch, Earth-to-Mars scene handoff, nine-seed generator reproducibility and variation, district/site counts, all six weather states, sensor units, discovery collision/slopes, equipment gates and extended save roundtrip. A dedicated real-controller test follows generated valley/site approaches through all six districts, using ordinary movement and climbing jumps without teleporting along the route. An initial route test found steep approaches; connected local paths were added and all six routes then passed for seeds 42601 and 20261104. Off-route large geology has collision proxies while clear approaches remain open.

The Windows release's supported `--expedition-test` entry also passed runtime checks for 40-site assembly, repeatable seeds, packed NASA profiles, traversal tool gates, extended save restoration and the full core controller/scanning flow. Standalone SceneTree test scripts are run with the editor's headless runtime; release validation uses the in-game test entry.

Native GPU captures are inspected for the suit, crew, mission control and every district, including haze/cold cases. Short 1280×720 captures on the RTX 3050 6 GB laptop have generally remained around 130–145 FPS; the detailed NASA SEV rover view averaged 119.4 FPS (p95 10.42 ms). These are not long-session or cross-hardware guarantees. PBR texture previews were reviewed before use; an unsuitable vegetation texture was rejected and excluded from export. Native interaction checks covered seed planning, launch/transit, touchdown and rover entry/camera framing.

Remaining limits: this is a finite generated composite, not infinite Minecraft terrain or a geologically exact world. The rover uses the character collision controller rather than wheel/suspension physics. Rock passages are small geometric traversal features, not a large cave-network simulation. Long-term external playtesting and scientific review remain valuable. Competition eligibility is unchanged and unconfirmed; the pre-event development must be disclosed.
