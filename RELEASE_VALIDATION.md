# Judge Edition release validation

This record distinguishes direct UI checks, real-controller automation, model
checks, packaged startup and media validation. Finite testing cannot guarantee
zero defects on every PC or every generated world.

## Scope

- Beginner movement, both held scans, learning answers, habitat return, ascent and debrief.
- Lab consoles, capsule collision routes, avatars, integration and launch cinematic.
- Non-default architecture, landing site, world seed and earned lab rewards across scene changes.
- Assisted landing across 100 seeds and live descent UI-to-field handoff.
- Thruster lift, fuel, pause behavior, shelter protection, impact damage and hazard rebasing.
- Resource exhaustion, science gates, corrupted saves, backup recovery and duplicate rewards.
- Six geological routes, streamed terrain, construction, recipes, campaign and two-process LAN.
- Ready-to-play ZIP integrity and Windows-native dependency setup in an isolated folder.
- Real game video encoding, subtitle timing and decoded video integrity.

Final observed results and artifact hashes are recorded in the release notes and
the generated build verification reports. Videos disclose scripted input and
controlled scenarios; they do not imply an uninterrupted human campaign run.

## Observed judge-edition checks

| Check | Observed result |
| --- | --- |
| Source gameplay verification | All Verify.ps1 groups passed, including six traversal routes and host/client LAN |
| Lab progress persistence | Repeated atomic writes and recovery from a corrupt primary passed |
| Beginner recording | Complete 2:49 route, two scans, lessons, return and debrief; 100% suit integrity; campaign saves unchanged |
| Launcher, isolated folder with spaces | Passed with Windows-only PATH, offline reuse, damaged-runtime repair and bad-checksum rejection |
| Bundled launcher | Passed headless startup without Python or a separate engine installation |
| Video playback integrity | All three MP4s fully decoded without errors; subtitle bounds checked |
| Visual media QA | Sample encoded frames inspected; subtitle band keeps game controls visible |

The media are 1280×800: actual 1280×720 game footage plus a dedicated subtitle
band. Walkthrough: 169.30 seconds. Edited demo: 86.03 seconds. Dashboard explainer:
79.04 seconds. Their SHA-256 values are in docs/media/media-manifest.json.

## Remaining limits

- Forward+ lab captures can report seven texture RIDs at renderer shutdown. This
  is unresolved. Headless checks do not reproduce it and cannot establish whether
  it is harmless. Normal startup can fall back to the compatible graphics renderer.
- Some recording-mode runs also report ObjectDB instances at shutdown. Recording
  success and decoded videos do not establish that these diagnostics are harmless.
- New impact and quake scenarios are solo-campaign only. Existing LAN science,
  activities and construction are supported; Internet matchmaking is not included.
- Windows x64 is the released platform. Drivers and hardware must support one of
  the available renderers. An unsigned portable game can be subject to local PC policies.
- NASA terrain is regional and compressed. Local rocks, survival rates, hazard
  timing, thrusters and mission scores are authored educational game models.
- Participation eligibility, pre-event disclosures and competition judging remain
  organizer decisions. No award or universal usability claim is made.
