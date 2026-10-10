# Product Brief

## Working title

**Project Ares: The Long Way Home**

Tagline: **Design the mission. Read the planet. Bring them home.**

## Product thesis

Most educational mission tools either hide the engineering or overwhelm the learner with spreadsheets. Project Ares turns authentic mission trade-offs into a coherent adventure: the spacecraft the player designs becomes the system they must live with.

The differentiator is not “a Mars survival game with NASA branding.” It is a playable chain of evidence:

`NASA observation -> engineering decision -> simulated consequence -> scientific explanation`

Every important number shown to a player should be one of:

1. a value derived from a named NASA dataset;
2. a value from a cited NASA technical source;
3. a transparent gameplay abstraction labeled as such.

## Audience

- Primary: students aged roughly 13–22 who are curious about space but are not yet aerospace engineers.
- Secondary: teachers, science communicators, hackathon judges, and space enthusiasts.
- Accessibility goal: playable without prior orbital-mechanics knowledge; deeper explanations available without blocking play.

## Complete mission loop

1. **Briefing** — choose a science objective, crew profile, landing region, mission duration, and difficulty.
2. **Procurement** — buy a launch vehicle, habitat, propulsion, power, life-support redundancy, rover, tools, shielding, food, spares, and instruments within budget and mass limits.
3. **Integration lab** — connect modules and solve a few contextual calculations. The handbook explains each equation and units. Wrong answers create diagnosis and recovery opportunities, not arbitrary punishment.
4. **Launch and transit** — monitor propellant, power, crew health, communications, and radiation; respond to data-driven events such as a close-approach debris warning or solar radiation event.
5. **Entry, descent, and landing** — outcome depends on selected site, landing mass, entry system, atmosphere, elevation, and player decisions.
6. **Outpost survival** — balance oxygen, carbon-dioxide scrubbing, water recovery, food, heat, power, waste, maintenance, and crew workload.
7. **Mars exploration** — traverse a chunked, fog-of-war map. Terrain comes from Mars topography; science targets are sparse, seeded, and weighted by real geology/mineral layers.
8. **Field science** — choose appropriate instruments, take measurements, form a hypothesis, and decide which samples/data deserve limited storage and return mass.
9. **Ascent and return** — reserve propellant, maintain life support, survive the return window, and reach Earth.
10. **Debrief** — receive a score, scientific findings, mission timeline, failure tree, NASA source cards, and credits for the next mission.

## Design pillars

### Consequences, not decoration

Equipment is never a cosmetic purchase. A drill consumes power and adds mass but enables subsurface sampling. Extra water is consumable, contingency reserve, and radiation shielding. Instrument choice controls which discoveries can be confirmed.

### Authentic but teachable

Use real relationships and plausible ranges, then compress time and reduce variables. The player can switch between three layers:

- **Mission view:** clear choices and consequences.
- **Engineer view:** equations, units, assumptions, and sensitivity.
- **Source view:** dataset, mission, instrument, spatial/temporal coverage, and link.

### Exploration with scientific intent

Fog-of-war reveals terrain by movement and orbital/rover sensing. Points come from evidence quality and diversity, not walking every tile. A rare target is valuable only when the player has the correct instrument, power, time, storage, and safe return route.

### Failure teaches

Every failure produces a causal explanation: “night-time battery reserve fell below habitat load,” not merely “mission failed.” Recovery paths include rationing, load shedding, repair, sheltering, route changes, and abort.

## Map generation

Use **data-conditioned procedural generation**, not a fictional random Mars:

- Select a real landing-region bounding box.
- Resample MOLA elevation into tiles and derive slope.
- Add geology/mineral/science likelihood from compatible orbital products.
- Generate traversability and hazards from slope, roughness, thermal inertia, and uncertainty.
- Use a recorded seed for placement within scientifically valid probability masks.
- Reveal chunks around astronaut/rover sensors.
- Store the seed and source-product versions in every mission report for reproducibility.

This permits replayability while preserving a defensible relationship to Mars observations.

## Scoring

The score must resist one dominant strategy.

| Dimension | Suggested weight | Evidence |
|---|---:|---|
| Crew survival and safe return | 30% | health, reserves, no unrecovered critical failure |
| Scientific value | 25% | novelty, evidence quality, instrument match, sample diversity |
| Engineering performance | 20% | margins, redundancy, mass/power/propellant discipline |
| Exploration | 10% | scientifically useful area and route diversity, not raw tile count |
| Resource stewardship | 10% | budget, consumables, maintenance, waste recovery |
| Learning/mastery | 5% | correct calculations and improved decisions |

Mission failure can still earn science and learning points, but safe return provides the largest multiplier and unlocks campaign credits.

## MVP scope for a 48-hour hackathon

Build one polished vertical slice:

- one landing region;
- one mission architecture and a focused catalog of 12–18 components;
- four coupled resources: mass, money, power, and life-support reserve;
- three meaningful calculations;
- one short transit sequence with two event types;
- one surface habitat loop;
- one rover/astronaut exploration map with fog-of-war;
- three science target classes and two instruments;
- one return/debrief screen;
- visible NASA data provenance throughout.

Do not attempt multiplayer, a whole-planet seamless map, full fluid simulation, detailed rocket construction, or dozens of datasets in the competition MVP.

## Presentation-ready three-minute story

1. **0:00–0:20 — Problem:** mission engineering trade-offs are invisible to most learners.
2. **0:20–0:45 — Design:** choose hardware while the budget/mass/power risk diagram changes.
3. **0:45–1:10 — Calculation:** solve one compact launch or power-margin problem using the handbook.
4. **1:10–1:50 — Mars:** reveal real MOLA-conditioned terrain, divert around a slope hazard, and inspect a science target.
5. **1:50–2:20 — Survival:** a dust/power or radiation event forces a consequential choice.
6. **2:20–2:45 — Return/debrief:** show score, causal mission log, and source provenance.
7. **2:45–3:00 — Impact:** a classroom-ready game that makes NASA data explorable and engineering understandable.

