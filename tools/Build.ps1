$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$enginePath = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
$output = Join-Path $projectRoot 'build/windows-v11'
New-Item -ItemType Directory -Force $output | Out-Null
& $enginePath --headless --path (Join-Path $projectRoot 'game') --export-release 'Windows Desktop' (Join-Path $output 'Mohashunnyo.exe')
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'godot/LICENSE.txt') -Destination (Join-Path $output 'GODOT-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'godot/COPYRIGHT.txt') -Destination (Join-Path $output 'GODOT-COPYRIGHT.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/THIRD_PARTY.md') -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/MARS_DATA.md') -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/COMPETITION_2026.md') -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/WEATHER_DATA.md') -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/ITERATION_07.md') -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/RELEASE_REVIEW.md') -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/ONBOARDING_PLAYTEST.md') -Destination $output -Force
@'
MOHASHUNNYO: A LONG WAY HOME
FRONTIER 11 / LEARN WHILE PLAYING / 13 NOVEMBER 2026
No space knowledge needed: F1 explains terms, scans teach how to interpret evidence,
and the flight coach explains each engineering choice before and after you act.
Mars gravity remains 3.71 m/s2. Suited hops are now 0.75m with shorter airtime.
Start with PLAY FIRST MISSION / GUIDED PRACTICE. Equipment is provided.
WASD move, mouse look, follow cyan marker, hold E near target to scan.
Collect two observations, return to the habitat, E, RETURN TO EARTH.
F1 explains your next step. Escape pauses. Practice never replaces campaign saves.
Use REHEARSE in mission planning to compare NASA MEDA-driven suit reserves.
Run Mohashunnyo.exe. Keep the .pck beside it. No installation or network needed.
WASD move | mouse look | Shift sprint | E interact/hold to scan | V camera
B build | C cargo/fabricate | G gather | Hold E assemble/use | Q rotate ghost
Enter/left-click place | Escape/right-click cancel | N emergency kit
R rover | Space low-G jump | F activity | J journal | L LAN crew
Tab map | Escape pause/settings/save | F11 fullscreen
Before launch open FIELD SYSTEMS and buy the 580-credit starter outpost.
Deploy two HELIOS arrays, VAULT, AERIS, HAVEN, and FORGE within 20m of each other.
Hold E for each of three assembly stages. Oxygen needs water; ice processors
need nearby highland ice or recovered ice. C fabricates and consumes supplies.
Choose Resilient Explorer for your first mission. Survey two of the six districts,
collect two targets, return to the main habitat and open its console with E.
Follow valley approaches around cliffs; steep shortcuts require climbing gear.
The base habitat and six starter refuges refill suit reserves. Outer field pods
have one emergency reserve; build powered shelters for sustained support.
Press E at a refuge/habitat to equip two of traction, climbing and thermal kits.
Streamed sectors continue beyond the six starter districts. Each contains a field
activity and service pod. Completed work persists when sectors unload/reload.
Host/join up to four players using L or Local Network Co-op on the title screen.
Host shares its LAN IP; allow UDP 24642 on private networks if Windows asks.
No external service, account, relay or port forwarding is needed for LAN play.
Twenty deployable modules, eight construction contracts, twelve activity
families, resources, rare finds and weather vary by seed. Each new sector grants
8 science points; new instrument/sector research grants 36. Points are uncapped. Enter/share a seed in
planning or use New Seed. Saved missions regenerate their original world.
This is an independent fictional game using NASA regional topography.
Pre-event prototype; competition eligibility is not confirmed.
'@ | Set-Content -LiteralPath (Join-Path $output 'READ-ME.txt') -Encoding UTF8
Compress-Archive -Path (Join-Path $output '*') -DestinationPath (Join-Path $projectRoot 'build/Mohashunnyo-Windows.zip') -Force
Get-FileHash -LiteralPath (Join-Path $projectRoot 'build/Mohashunnyo-Windows.zip') -Algorithm SHA256
