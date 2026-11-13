# First-player experience — 13 November 2026

## Frontier 11 learning update

The start button appears before the optional briefing detail. Plain definitions
explain breathing air, stored electricity, shelter and observations. F1 includes
a glossary. Each guided scan explains the instrument and its battery cost, asks
the player to interpret a clue, and provides a gentle correction for overclaims.
Campaign flight shows a coach explanation before each decision and pauses to
explain the recommended action afterward. All ten event families have specific
explanations rather than assuming spacecraft vocabulary.

The `--learning-test` checks all ten explanations, presses the actual six flight
decision buttons, verifies feedback pauses, continues to landing and exercises
a wrong decision. The guided route test now answers one scientific question
correctly and one incorrectly, and still checks safe return and save isolation.
These checks do not substitute for independent first-time-player usability tests.

## Problems observed

The previous opening put a launch button before the player had purchased eight
required rocket parts. Clicking it led to an integration screen and a workshop
with 236 items. It did not teach movement or the actual field loop. Architecture
choices were below the launch button. The HUD emphasized a points quota while
the player needed a nearby goal and an explanation of how to scan and return.
An integration paragraph also displayed a literal `%d` instead of the quota.

Visual testing of the revised field HUD caught a large autowrapping panel that
obscured the scene; it was removed. A world-space marker could be hidden behind
the habitat, so an additional screen-space destination label was added.

## Changes

- The title fits three clear choices: guided practice, campaign, and extras.
- Guided practice provides equipment and uses a fixed, reachable starter route.
- A short briefing explains movement, scanning, oxygen recovery and the return.
- The HUD displays the current step, direction, distance and essential reserves.
- A cyan destination label stays visible through scenery; behind-camera targets
  get a turn-around instruction. The target changes after scanning or low reserves.
- F1 and the pause menu explain the player's next action.
- The introductory habitat console offers recovery instructions and a clear
  return-to-Earth action after two different observations.
- Practice failure can be retried; campaign funds, procurement and saves stay intact.
- Campaign setup has a recommended equipment pack and gated launch. Repeating the
  recommendation does not buy duplicates. Failed purchases roll back completely.
- Construction, complex equipment, LAN and NASA references remain available
  outside the introductory path.

## Validation

`tools/Verify.ps1` includes `--guided-test`. This moves the real CharacterBody
through the two target routes and home, runs the normal hold-to-scan path,
commands ascent and checks the debrief. Weather, suit, field and outpost updates
remain active; it is not a teleport-only or model-only success test.

Observed guided results: 131.47 simulated seconds, two observations, 100% suit
integrity and about 119 oxygen remaining. Campaign snapshots and the previous
expedition save were byte-for-byte unchanged. The isolated recommended-pack tests
also passed affordability, idempotence and insufficient-budget rollback checks.

Manual UI checks covered entering guided practice from the title, reading its
briefing, landing, a movement input, field HUD visibility and the removed oversized
panel. The full successful route was driven by automated controller inputs; it
is not represented as a complete manual human playthrough. The final Windows
executable is additionally tested with `--guided-test` after export.

This makes the first-player flow substantially clearer. It does not establish
that every new player will understand it: independent novice playtesting is still
valuable, and all procedural seeds have not been tested.
