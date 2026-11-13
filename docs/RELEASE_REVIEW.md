# Mission design review — 13 November 2026

The supplied `nasaguide.md` is the challenge specification used for this review;
`nasadatasets.md` is a service directory, not a requirement to use every service.

## Assessment

The idea matches the core brief: players buy and integrate a mission, choose
instruments and power architecture, launch, manage resources, gather evidence,
build infrastructure and attempt a return. The strongest differentiator is a
playable field expedition with visible consequences of mission design.

The new REHEARSE screen compares all three architectures using the actual suit
model and cached NASA PDS MEDA profile. It compares a 180-second walking EVA with
return to shelter at 90 seconds. Players can select an architecture in that lab.
The scenario responds to seed and landing region. It is not mission certification:
outpost consumption, injuries, scanning, sprinting and thermal penalties are not
included. Observations and simulated weather timing remain explicitly separate.

NASA PDS is one of the services in the supplied dataset directory. Existing MOLA
elevation and MEDA temperature, pressure and wind products are reused in this
new decision tool; no new observational dataset is claimed. They work offline
without API keys. See MARS_DATA.md and WEATHER_DATA.md for source URLs, processing,
checksums, units and scientific limitations. Earth-only POWER or GIBS data would
not be a suitable substitute for Mars observations.

| Brief area | Implementation / remaining limit |
| --- | --- |
| Full mission lifecycle | Procurement, integration, departure, field operations, return, debrief and campaign grants |
| Mass, budget, power | Cargo capacity, architecture margins, solar/fission, battery and outpost networks |
| Instruments | Drill/spectrometer/camera capability gates; evidence and research rewards |
| Orbit and launch | Rocket integration and departure; freely selectable orbital mechanics are not implemented |
| Communications/data | Downlink and field relays; no packet-level bandwidth or storage simulation |
| Time/lifetime | EVA consumption and hazards; no multiyear lifecycle engineering model |
| Collaboration | Up to four LAN peers; no Internet matchmaking or dedicated role permissions |
| Learning and replay | Sources, causal debrief, seeded scenarios, architecture comparison and rehearsal |

## Correctness changes

- Reject malformed save structures, fractional/duplicate sample IDs and invalid
  landing-site values before restoring the model.
- Recover from invalid JSON using backups without emitting a parser error.
- Prevent rocket integration during an active mission and reject negative costs.
- Persist rejected integration resets and reset the campaign seed on restart.
- Fit menu scroll height to the viewport rather than requiring a fixed 680 pixels.
- Export to a fresh windows-v8 folder and make Play.cmd prefer it; the older
  executable can stay open without preventing the new export.

## Reproducible verification

`powershell -ExecutionPolicy Bypass -File tools/Verify.ps1` runs mission-review,
expedition, spaceport, transfer, generation, six-region traversal, streaming,
outpost, campaign and host/client LAN checks. The new regression check exercises
three seeds and all architectures, actual repeated save rotation and recovery
after corrupting an isolated test checkpoint. It never overwrites player saves.

`powershell -ExecutionPolicy Bypass -File tools/Build.ps1` creates the Windows
executable, PCK, notices, documentation and ZIP. This is a Windows x64 desktop
release, not a browser build. No public upload or submission is performed.

## Observed results

On 13 November 2026 all source Verify.ps1 checks passed. The exported Windows
v8 executable also passed the expedition integration test and both host/client
LAN tests. The interactive release opened correctly; manual inputs verified
title to planning, opening rehearsal, selecting Solar Scout, scrolling through
all architectures and returning to mission design. The complete field route
was exercised by the automated real-controller tests, not a claimed full manual
playthrough. Tests ran on this Windows machine; no other-machine claim is made.

## Judging demonstration

1. Show architecture margins and REHEARSE. Compare solar with fission under one seed.
2. Show NASA sources and the difference between observations and game assumptions.
3. Procure/integrate, launch, collect evidence and demonstrate the resource response.
4. Show cooperative field infrastructure, then return for the causal debrief.

Prepare a short recording of the full loop: interactive procurement and field
play take longer than a short judging pitch. Disclose pre-event work and asset
sources to organizers. No test suite establishes competition eligibility or
guarantees an award. Internet play, other hardware and every procedural seed
remain outside the tested scope.
