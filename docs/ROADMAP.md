# Iteration Roadmap

This roadmap separates competition-safe preparation from code produced during the official event.

## Phase 0 — Rules, challenge fit, and team (October 10–27)

Goal: remove eligibility and scope risks without implementing the intended submission.

- Register for the 2026 event and select a Bangladesh local event or the Universal Event.
- Form a team of up to six: game/frontend, data/GIS, aerospace/science, UX/art, narrative/pitch, and QA/integration.
- Ask the Local Lead whether research documents, generic experiments, engines, and pre-existing assets are allowed.
- Record all pre-existing assets and tools that may be used.
- Study past winners and rehearse a three-minute pitch using paper mockups only.
- Verify dataset access, formats, size, coordinate systems, licenses, and attribution.
- Identify one primary award narrative and one secondary award narrative.

Exit gate: written confirmation/interpretation of rules, registered team, and no ambiguity about pre-event work.

## Phase 1 — Challenge reconciliation (October 28–November 13)

Goal: turn the full official statement into a build contract, without crossing the organizer's start-work boundary.

- Read the full challenge statement, official resources, judging guide, and submission guide.
- Create a requirement traceability table: challenge sentence -> game feature -> evidence in demo.
- Remove any feature that does not directly strengthen relevance, validity, data use, or presentation.
- Lock the landing region and minimum dataset subset.
- Prepare a 48-hour task board and ownership map.
- Pre-plan data transformation steps, but only execute them when rules allow.

Exit gate: one-page MVP, fixed demo path, contingency plan, and team responsibilities.

## Iteration 1 — Skeleton vertical slice (event hours 0–6)

Goal: a complete but ugly loop.

- Initialize the repository and application.
- Implement deterministic game state and a single mission seed.
- Connect planning -> transit -> surface -> debrief screens.
- Add placeholder blocks and keyboard/touch controls.
- Commit a tagged baseline.

Acceptance: a player can reach a debrief in under five minutes with no dead end.

## Iteration 2 — Engineering core (hours 6–14)

Goal: choices create visible, correct trade-offs.

- Component catalog with source/assumption metadata.
- Budget, dry mass, payload, propellant, power generation/storage, and margin calculations.
- Three guided calculations with unit checking and hint levels.
- Failure explanations and mission log.

Acceptance: automated tests cover equations, bounds, units, and deterministic outcomes.

## Iteration 3 — NASA-data Mars slice (hours 14–24)

Goal: real data is mechanically essential.

- Transform a small MOLA region into a compact game-ready raster/JSON artifact.
- Generate slope/traversability and fog-of-war chunks.
- Add one additional science layer and uncertainty metadata.
- Seed three discovery classes inside valid masks.
- Display source cards for map tiles and discoveries.

Acceptance: removing the NASA-derived layer materially changes routes and science outcomes.

## Iteration 4 — Survival and incidents (hours 24–32)

Goal: create tension through coupled systems.

- Oxygen/water/food consumption and recovery efficiencies.
- Habitat load, solar generation, battery reserve, and load shedding.
- Transit and surface incidents with clear warning, choice, consequence, and recovery.
- Balance for a 6–8 minute judging build.

Acceptance: at least two viable strategies succeed; failures identify their causes.

## Iteration 5 — Art, story, accessibility (hours 32–39)

Goal: make the science legible and memorable.

- Replace critical placeholders with a consistent low-resolution 2D art kit.
- Add a mission-control guide character and concise radio narrative.
- Keyboard, readable color contrast, reduced motion, captions, and no color-only signals.
- Add Bangla welcome/impact element if time permits, while keeping the submission and pitch in English.

Acceptance: a first-time player understands the objective within 30 seconds.

## Iteration 6 — Evidence and submission (hours 39–48)

Goal: a resilient public demo and judge-ready story.

- Freeze features; fix only critical defects.
- Add dataset/provenance page and downloadable mission report.
- Record a fallback demo video and screenshots.
- Test a fresh install and deployment on two devices and a slow connection.
- Finalize README, architecture diagram, source ledger, limitations, team roles, pitch, and submission fields.
- Clearly label observed data, derived values, engineering references, and gameplay abstractions.

Acceptance: public URL works, repository is open, demo is deterministic, sources are clickable, and the pitch finishes inside the local time limit.

## Post-event iterations (only after submission)

### Iteration 7 — Campaign depth

Multiple landing regions, tech progression, more instrument types, mission replay comparison, and classroom lesson mode.

### Iteration 8 — Higher-fidelity science

Seasonal atmosphere, validated radiation scenarios, communications geometry, launch windows, formal uncertainty propagation, and scientist review.

### Iteration 9 — Collaboration

Optional 2–4 player roles (commander, flight engineer, scientist, EVA specialist) only after the single-player loop is stable.

## Keep/change log template

For every iteration add an entry to `DECISIONS.md`:

- Date/time and build identifier
- Hypothesis
- What changed
- Dataset/equation affected
- Test or playtest evidence
- Decision: keep, revise, or remove
- Known limitations

