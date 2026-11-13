# Decision Log

## D-007 — Third-person staffed mission-design loop

- Date: 2026-10-19
- Decision: replace first-person camera navigation with a visible third-person astronaut and add lightweight animated facility staff.
- Mission systems: introduce a data-driven shop, $6.5B gameplay budget, delivery queue, engineering manifest, readiness gate, persistent T−10 countdown and liftoff handoff.
- Evidence rule: label NASA reference values, NASA architecture targets and gameplay engineering estimates separately. Prices are always estimates because the cited NASA sources do not provide a compatible procurement catalog.
- Catalog scope: 21 variants spanning crew/transit/landing vehicles, oxygen and carbon-dioxide control, water, food, cryogenic propellant, Mars ISRU, solar/fission power, surface habitat/rover and safety systems.
- Signage: room names appear only on cyan semi-transparent panels above doors. Separate single-sided captions make both approaches read left-to-right; redundant floating destination text is removed.
- Limitation: staff follow authored work routes; the ground-crew NPC carries a representative delivery crate, while item-specific installation animation is deferred. Liftoff ends at mission commitment; flight simulation is deferred.

## D-006 — Native 3D spaceport, Godot 4

- Date: 2026-10-19
- Decision: start a native Godot 4.7.2 first-person facility prototype, superseding D-001's planning-only restriction and D-002's proposed web-first 2D stack at the user's explicit request.
- Hardware evidence: i5-13420H, RTX 2050 with 4 GB VRAM, approximately 8 GB installed RAM. User considered Unreal Engine 5, then authorized Godot for a lighter development setup.
- First iteration: connected outfitting shop, spacecraft integration hall, mission control and outdoor launch pad; movement, collision, facility map, settings and a drag-and-drop visual module preview.
- Rendering: native Compatibility renderer, shared materials, batched structural geometry, downloaded 1K CC0 textures and scalable shadows/antialiasing.
- Science boundary: cited NASA/JPL planetary reference parameters are displayed, but terrain datasets and mission physics are deferred. Facility and vehicle are fictional concepts.
- Competition eligibility remains unverified. This decision records the user's development authorization, not organizer approval.

## D-001 — Plan before implementation

- Date: 2026-10-10
- Decision: create research, scope, provenance, and iteration documents only.
- Reason: official local-event guidance says intended solutions are built during the hackathon. The user also requested a plan and iteration guide first.
- Revisit: after explicit rules confirmation and the full challenge release on October 28.

## D-002 — Web-first 2D vertical slice

- Date: 2026-10-10
- Proposed stack: TypeScript, Vite, Phaser 3, deterministic seeded simulation, compact preprocessed data assets, and a static-host deployment.
- Reason: zero-install judge access, fast iteration, offline-capable demo, strong 2D support, and a realistic 48-hour deployment path.
- Status: proposed, not initialized.

## D-003 — Single-player first

- Date: 2026-10-10
- Decision: borrow social tension and role identity from cooperative games, but do not build networking for the MVP.
- Reason: multiplayer infrastructure does not directly satisfy the challenge and threatens reliability.

## D-004 — Data-conditioned procedural Mars

- Date: 2026-10-10
- Decision: terrain comes from a real landing region; procedural generation controls replayable placement only within evidence-based masks.
- Reason: preserves discovery and replayability without falsely presenting invented targets as NASA observations.

## D-005 — Three calculation moments

- Date: 2026-10-10
- Decision: prioritize propellant/mass, energy balance, and consumables/recycling for the MVP.
- Reason: together they connect spacecraft design, surface operations, and survival while remaining teachable.

