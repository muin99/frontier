# Frontier 12 — Earth Operations and Mars adventure

14 November 2026. Continues the supplied lab-rebuild handoff.

Run Play.cmd or build/windows-v12/Mohashunnyo.exe. Keep the PCK beside the EXE.
Older running copies do not update themselves; check the title says Frontier 12.

The Earth lab is the primary title-screen campaign option. Walk the arrival hall,
Mission Control, crew locker, outfitter, integration bay, Flight Lab, descent
simulator and launch pad. A checklist and cyan waypoint guide the preparation.
The rebuilt facility includes animated holograms, spacecraft displays, physical
consoles, crew and commander selection, and a cinematic ignition and launch.

The lab hands the selected architecture, landing site, world seed, earned science
and simulator fuel bonus to the expedition. Previously the handoff defaulted back
to one architecture and dropped rewards. Those values now survive scene changes.

After the coached transit decisions, the campaign runs a flyable 3D terminal
descent. It starts paused with instructions. Space fires the engine; WASD steers;
Enter toggles autopilot; Escape pauses. Assisted landing is available at the start.
The result changes science and suit integrity before stepping onto the surface.
The simplified descent arena is procedural, not a NASA landing-safety product.

On Mars, the HUD includes reserve bars and an explicit campaign destination.
Space retains the restrained Mars hop at 3.71 m/s². Ctrl+Space while airborne
activates an optional finite-charge thruster; it recharges on the ground.
This is a fictional mobility mechanic, not real flight hardware.

Solo campaign play adds telegraphed meteor impacts, recoverable fragments and
camera-shaking marsquake scenarios. Shelter prevents impact damage. Timers and
statistics persist, and pending markers shift with terrain rebasing. In-flight
rocks and loose fragments are temporary effects rather than persistent inventory.
Hazards are disabled in guided practice and LAN mode; multiplayer damage/visual
replication for these new hazards is not implemented. Existing LAN activities,
evidence and construction remain supported.

NASA MOLA and MEDA use is unchanged. Hazard frequency, injuries, resource rates,
thruster charge and training rewards are authored game models. Meteor showers
near the player and quake effects are adventure scenarios, not NASA forecasts.

## Verification

Verify.ps1 includes the existing mission, controller-route, construction, save,
beginner and LAN tests plus these new checks:

- 100 deterministic descent starts reach a good assisted landing with fuel left.
- Live scene components cover descent briefing pause, flying, result
  confirmation and transfer to surface; thruster lift, charge and pause; exposed
  versus sheltered impacts; hazard rebase/save; once-only quake credit.
- The lab launch cinematic carries a non-default architecture, upland site,
  seed, three Flight Lab rewards and simulator fuel bonus into the Mars scene.

GPU captures and interactive playtest observations are recorded after the final
export. Tests sample finite routes/seeds, not every possible action or machine.

Observed on this machine: the full Verify.ps1 suite passed, including the real
controller guided route, six region routes, construction, campaign and both LAN
peers. GPU captures measured roughly 108–119 FPS in the Earth lab and about
56 FPS in a capped Mars capture while other checks were running; these figures
are observations, not guaranteed performance on other hardware.

Interactive UI play checked the exported title-to-lab transition, welcome screen
and lab checklist. An isolated live landing run used the visible assisted-start
button, Escape pause and Enter resume, reached GOOD LANDING at about 1 m/s with
31% fuel and no suit damage, and continued into the surface HUD with the
STEP ONTO MARS button. This isolated run preserved campaign saves. The complete
walking/scanning/return route was driven by real-controller automated input;
it is not claimed as a fully manual human playthrough of every campaign option.

The final exported Windows executable also passed ADVENTURE SYSTEMS through its
normal startup path, exercising the packed resources and release scripts.

Known graphics diagnostic: Forward+ lab GPU captures may report seven Texture
RIDs at renderer shutdown. Headless verification reports no such warning; this
does not prove the warning harmless or a runtime memory leak. It remains an
unresolved shutdown diagnostic and must not be represented as a fully clean GPU
validation. Performance settings and the Compatibility renderer are available for
hardware that cannot run Forward+.
