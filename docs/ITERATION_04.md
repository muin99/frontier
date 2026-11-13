# Iteration 4 — complete Mars expedition

Built and checked on 4 November 2026. Scope is a complete short single-player expedition, not every feature of the original campaign proposal.

## Delivered

- New default native 3D Mars expedition and retained Earth facility accessible from the title screen.
- Three architectures; budget/mass margins, oxygen/battery/power/instrument tradeoffs.
- Observed MOLA elevation readouts for basin/upland approach; explicitly fictional risk/science consequences.
- Earth departure spacecraft sequence, radiation-response decision, surface landing, physical ascent animation and causal return/debrief.
- Four field targets, instrument restrictions, three-second held scanning, evidence interpretation and optional Earth archive downlink.
- Finite EVA reserves, sprint cost, dust front, differentiated fission/solar charging, safe habitat recharge and one-use repair.
- Suited explorer, camera self-collision exclusion, screen-relative mouse input, first/third person, full walking terrain collision and perimeter bounds.
- Batched rocks, textured procedural regolith, custom habitat/solar/ascent geometry, muted dark UI, readable beacon labels, exploration map and audio cues.
- Pause, focus-loss handling, graphics presets, sensitivity, fullscreen, versioned JSON checkpoint/backup and Continue.
- NASA source ledger, reproducible data pipeline, competition requirements matrix and development queue.
- Windows x64 release runtime + PCK, notices and shareable ZIP. Neither Python nor an editor is needed to play the export.

## Automated verification

`tools/Verify.ps1` checks explicit PASS sentinels, exit codes and errors/leaks. A frame-count backstop prevents parse errors or aborted test functions from being mistaken for a pass.

Expedition integration: all three architectures can meet return requirements; wrong instruments and duplicate evidence fail; radiation consequences, resource depletion, dust, charging, repair limits, interpretation and downlink gates work. JSON state roundtrips preserve evidence and score; invalid architecture saves are rejected. Rays hit actual terrain collision at critical targets. The real CharacterBody walks the full four-target route and returns; the active hold-scan path opens the evidence screen. Evidence/habitat/pause/source/debrief UI construction is exercised.

Retained spaceport smoke: briefing, purchasing/delivery, NASA equation checks, launch authorization, countdown/physical ascent, room routes, collisions, avatar walking/running, camera turns, first-person and drag/drop preview pass. A nondeterministic countdown assertion was fixed by explicitly advancing the tested countdown across zero.

The exported release executable also passed the expedition integration test with no script errors. Source tests finished without leaked objects after stopping test audio before exit.

## Render and native UI checks

Actual GPU captures were inspected for title, planning, surface, dust, orbital departure and debrief. The first capture exposed collapsed menu height, then the first native planning interaction exposed an offscreen launch control. Both were corrected. Overexposed materials, oversized beacon labels, hard terrain noise, camera self-collision and low-contrast notifications were also revised.

The Windows release was opened and clicked through title → planning → departure → transit decision → touchdown. Controls and text remained readable in the native window. Save & Quit followed by starting another release instance and Continue restored the same oxygen/battery reserves and position. The Earth integration-to-expedition handoff also passes an end-to-end test using real procurement, calculation, countdown and scene-transition code.

Hardware detected by renderer: NVIDIA GeForce RTX 3050 6 GB Laptop GPU, OpenGL Compatibility renderer, NVIDIA 610.62. Actual captures at the configured 1280 × 720 window, Balanced settings:

| View | Mean FPS | p95 frame time | Draw calls |
|---|---:|---:|---:|
| Surface | 144.0 | 6.94 ms | 498 |
| Dust front | 144.1 | 6.94 ms | 153 |
| Planning | 145.3 | 6.94 ms | 289 |
| Orbit | 142.8 | 8.74 ms | 30 |
| Debrief | 145.2 | 6.94 ms | 511 |

These are short scripted captures after warmup, not a hardware-independent performance guarantee or long soak benchmark. Final orbital lighting/HUD polish postdates its recorded capture. Captures/logs live in ignored `build/`.

## Practical limits

Art is cohesive authored procedural geometry, not photorealistic asset production. One region, one expedition and four science targets are shipped. The original proposal's rover driving, base construction, full trajectory mechanics, multiplayer and long-form campaign are not implemented. Legacy Earth procurement is optional; after its launch, the required fission architecture maps to Resilient Explorer. Ground mass/power are recorded in the expedition log, while capacities map to normalized game reserves rather than pretending the two abstractions are identical.

The 4-pixels/degree MOLA source provides regional terrain only. Weather, radiation, capacities, costs, instruments' assay outcomes and scoring are explicitly game abstractions. The radiation decision is educational, not a dose calculation. There is no live NASA network dependency.

External student/teacher playtesting, learning-outcome validation, other GPU/OS testing and official competition eligibility confirmation remain team work. Full 2026 challenge/FAQ pages could not be retrieved. See `COMPETITION_2026.md` before claiming compliance or submitting.
