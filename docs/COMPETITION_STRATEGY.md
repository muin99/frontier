# Competition Strategy

## Official challenge fit

The published 2026 summary for **Space Mission Design Game** asks for an interactive game in which participants design, manage, and simulate a complete mission while making engineering decisions, managing limited resources, and seeing how choices affect success. It explicitly mentions objectives, spacecraft, instruments, launch vehicles, budget, power, mass, communications, and orbital constraints.

Mohashunnyo fits this closely. The full October 28 statement remains the authority; this document must be revised against it.

## Judging lens

Space Apps has historically evaluated impact, creativity, validity, relevance, and presentation, then recognizes award categories such as Best Use of Science, Best Use of Data, Best Mission Concept, Best Storytelling, and Art & Technology.

Recommended positioning:

- **Primary:** Best Mission Concept — the designed craft and surface architecture produce a complete, plausible mission outcome.
- **Secondary:** Best Use of Data — Mars data changes terrain, routes, risk, and discovery mechanics.
- **Supporting:** Best Use of Science and Storytelling — equations and a human “bring them home” arc make the data understandable.

Trying to claim every award will weaken the pitch.

## Lessons from prior winners

- A game can win when the data is central: the 2023 Best Use of Science winner combined an immersive experience with Apollo seismic data.
- A small interactive story can beat a huge simulation: Bangladesh's Team Voyagers won Best Storytelling in 2023 with a web game about the water cycle.
- Winners make the open data legible to a new audience; visual polish alone is insufficient.
- The judge must understand the problem, evidence, novelty, and impact within minutes.

## What makes this entry distinct from other 2026 teams

Other publicly visible teams already describe mission simulators built around mass, energy, budget, fuel, risk, and science value. Those features are table stakes. Differentiation should come from:

1. a full design-to-return narrative instead of a dashboard-only simulator;
2. a data-conditioned explorable Mars map where observations affect gameplay;
3. traceable provenance cards and reproducible mission seeds;
4. failure explanations that teach systems engineering;
5. strong character, sound, and visual identity within a tightly scoped vertical slice.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Building before the permitted window | Disqualification | Keep this repository to research/planning; confirm rules with Local Lead |
| Scope explosion | No stable demo | One region, short catalog, one complete loop |
| “Realistic” claims exceed model fidelity | Loss of validity | Label assumptions/abstractions; show uncertainty and limitations |
| NASA data is merely decorative | Weak relevance/data score | Require each shipped layer to change a player decision |
| Large remote data breaks demo | Presentation failure | Preprocess and bundle small attributed subsets |
| Random discoveries misrepresented as observations | Scientific credibility failure | Label as simulated and condition placement on observed layers |
| Too much arithmetic interrupts fun | Poor usability | Three contextual calculations, progressive hints, optional expert depth |
| Art consumes engineering time | Incomplete loop | Consistent placeholder kit first; replace only demo-critical assets |

## Team recommendation

Up to six people:

1. Product/gameplay lead and integrator
2. Game/frontend engineer
3. Data/GIS engineer
4. Aerospace/life-support researcher
5. Visual/UX/audio designer
6. Storytelling, QA, accessibility, and pitch lead

Everyone should be able to explain one dataset and one trade-off in the final pitch.

## Champion-level evidence checklist

- A public, reliable playable URL
- Open repository with setup instructions
- Exact challenge-language traceability
- Data transformation scripts and provenance
- A mission report that shows assumptions and causal outcomes
- Automated tests for key equations
- Playtest observations from target-age learners
- Limitations stated honestly
- Three-minute pitch plus offline backup video
- Memorable title, visual identity, and emotional reason to return the crew home

