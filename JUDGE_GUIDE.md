# Mohashunnyo: A Long Way Home — judge's guide

## Play in one minute

**Windows 10/11, 64-bit.** Download **Mohashunnyo-Windows.zip** from
[the release page](https://github.com/muin99/frontier/releases/tag/v0.13.0).
Extract the entire ZIP into a folder, then double-click **Play.cmd** inside it.
No editor, Python, account, API key, installer or administrator access is needed.
Keep the files together; don't run the game from inside the ZIP preview.

If you downloaded the source repository instead, Play.cmd downloads the verified
Windows game on its first run. That first download needs Internet. Afterward it
works offline. The game data and runtime are included in the Windows ZIP.

Start with **PLAY FIRST MISSION / GUIDED PRACTICE ON MARS**. Equipment is provided
and this practice never replaces a campaign save. Allow a few minutes to learn.
The title bar should say **Frontier 13**; an already-open older copy stays old.

## Your first mission

1. Choose guided practice, read the short instructions, then start.
2. Follow the cyan **SCAN** marker. Its distance and the top-left objective guide you.
3. Walk close to the target and **hold E for three seconds** until the scan fills.
4. Read the observation. Try an answer: the game explains the scientific reasoning.
5. Follow the next marker and collect a second observation.
6. Follow **HOME** to the white shelter. Stand nearby to refill air and battery.
7. Press **E** there and choose **RETURN TO EARTH**. Watch the ascent and debrief.

You do not need to build an outpost in the first mission. **F1** explains the next
step and defines unfamiliar words. **Escape** pauses; you can read without a timer.

## Read the dashboard

| Display | Meaning | What to do |
| --- | --- | --- |
| Top left | Your current goal, science and exploration progress | Follow the next instruction and cyan destination |
| AIR | Breathing oxygen remaining | Return to the main shelter before it is low |
| TOOL BATTERY | Stored electricity for your instruments | Each scan costs battery; recharge near the shelter |
| SUIT | Suit integrity; zero ends the mission | Avoid hazards and hard falls; use repairs in campaign mode |
| THRUSTER | Optional mobility charge, campaign only | Ctrl+Space in the air spends charge; ground contact recharges it |
| Evidence | Different observations collected | Two observations are needed for the first return |
| Bottom prompt | The action available near you | Hold E to scan; press E at the shelter |
| Map, Tab | Terrain and nearby destinations | Use it for orientation; markers give the immediate goal |

## Controls

| Key | Action |
| --- | --- |
| WASD / mouse | Walk / look |
| Hold E | Scan a nearby target; assemble placed equipment |
| E at shelter or lab console | Open its controls |
| Escape / F1 | Pause / help and definitions |
| Space | A restrained Mars jump |
| Ctrl+Space in the air | Thruster burst in campaign mode |
| V / mouse wheel | First/third person / camera distance |
| Tab / R | Map / rover |
| B / C / G | Build / cargo and crafting / gather material |
| J / L / F11 | Journal / LAN co-op / fullscreen |

## Show the complete mission-design challenge

Choose **START AT THE EARTH LAB / CAMPAIGN**. Walk toward the cyan beam and use
the physical consoles. The launch checklist leads you through:

1. **Mission Control:** accept the briefing.
2. **Crew locker:** choose a commander and suit.
3. **Outfitter:** pack the recommended rocket and outpost. Budget and cargo limits matter.
4. **High bay:** follow the three safety/integration steps. The nearby lamps show progress.
5. **Optional Flight Lab and landing simulator:** learn calculations and earn mission bonuses.
6. **Launch Control:** choose the crew architecture and landing approach, then launch.
7. **Transit:** read the flight coach, make decisions and review their consequences.
8. **3D descent:** start assisted or manual. Hold Space to brake, WASD to steer,
   Enter to toggle autopilot, Escape to pause. Confirm touchdown to enter the field.
9. **Surface:** meet the displayed science quota, collect two observations, survey
   two districts and return to the main habitat. Construction extends your reach.

The lab's architecture, landing choice, world seed and earned bonuses carry to
Mars. Solar and fission choices, instrument capability, mass, budget and reserves
have different consequences. Campaign failure forfeits that campaign's resources;
use guided practice to learn safely first.

## NASA evidence and original work

The game uses **MGS MOLA MEGDR** regional elevation and **Mars 2020 MEDA** historical
temperature, pressure and wind observations. See [the exact products](docs/DATASETS.md).
Local rocks, paths, equipment, costs, storm timing, thrusters, meteor scenarios and
scores are authored game models. They are not live forecasts or landing certification.
The source ledger and learning cards distinguish observations from game assumptions.

## Videos

The release includes a short cinematic **Game-Demo.mp4**, a complete beginner
**First-Mission-Walkthrough.mp4**, and a narrated-by-subtitles **Controls-and-Dashboard.mp4**.
All visuals are captured from the game. No AI-generated footage or synthetic voice
is used. SRT subtitle files accompany the burned-in captions. The short demo is an
edited showcase with controlled scenario shots; the first-mission walkthrough
records the full live controller route, scans, lessons and return.

## If the game doesn't open

Try **Play-Compatible.cmd** in the same folder. This uses the compatible graphics
renderer; the normal launcher also tries it after an early graphics startup failure.
Check that the entire ZIP was extracted and the EXE/PCK files remain together.
If launching from source, the first download requires Internet; a cached or bundled
release does not. No authentication is requested by the game.

Settings offers Performance, Balanced and High presets. Saves and settings stay
in your Windows user profile, so the extracted game folder can be moved.

## Tested scope and limits

The release checks cover the beginner route, lab consoles and collision routes,
lab-to-Mars handoff, landing, resource failure, saves, construction, campaign gates
and two-process LAN. New impact/quake hazards are solo-campaign only. LAN requires
the same build and a local network; Internet matchmaking is not provided.

Finite tests cannot establish zero bugs or compatibility with every PC. Any
remaining release diagnostics are listed in RELEASE_VALIDATION.md. Competition
eligibility and disclosure of pre-event work remain organizer decisions.
