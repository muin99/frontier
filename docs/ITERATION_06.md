# Frontier 6: streamed exploration and local-network co-op

Run `build/windows-v6/Mohashunnyo.exe` with its adjacent `.pck`, or use `Play.cmd`.
Older builds and saves are retained. Version 6 writes `expedition_v6.json` and
can import a version 5 checkpoint. Start a fresh expedition to try all new systems.

## Exploration architecture

The old invisible perimeter is removed. The original six-district, 1,536 m MOLA
composite remains the starting survey. Beyond it, 256 m terrain sectors stream
ahead and unload behind the player. Each has deterministic terrain, geological
colour/material families, outcrops, scattered rocks, an activity, and a service
pod. Negative coordinates work. A fixed seed regenerates a visited sector;
completed activities and discovered-sector records persist separately from meshes.

At most 49 sectors are wanted around a solo player. The host may additionally
load nine around each distant crew member. Mesh generation runs on a worker;
scene/collision attachment happens on the main thread. Shared edges use identical
height samples. The controller waits if its destination terrain is not ready.
The scene origin shifts at about 1.5 km to keep nearby physics coordinates small.

This is effectively endless procedural exploration: there is no designed arena
edge or fixed count of generated destinations. It is not mathematical infinity.
Finite integer/float precision, disk space for exploration records and hardware
still apply. Far travel has been tested at roughly 250 km; unlimited-distance
precision and multi-day sessions are not certified. It is an invented extension
of a regional Mars analog, not an infinite reconstruction of the actual planet.
The extension does not invent additional observed MOLA coverage or MEDA records.

## Activities and controls

F starts work at a gold beacon. J opens a journal showing nearby work and active
objectives. The activity families are relay repair, solar-array maintenance,
rover recovery, sealed-sample delivery, three-station seismic deployment,
context survey, navigation transect, protected drilling, ice-core investigation,
meteorite assessment, supply-cache inspection, and seven-platform low-G courses.
Procedures have three ordered choices, including rejected unsafe/unsupported
actions. Transects require two-second station dwells. Samples must reach a pod;
recovered rovers require a different pod. Courses require ordered on-foot landings
within 150 seconds. Goals receive a world-space ring and journal directions.

Tasks award science and spares once; completed work stays completed when a sector
returns. B spends two spares and 12 battery for an emergency oxygen/integrity kit
and visible field marker. This is a consumable recovery action, not a persistent
crafting/building system. E at a field pod opens the existing equipment console.
R deploys the detailed NASA concept rover. Life support and weather still matter.
These are twelve reusable activity families with seeded placement, not an unlimited
set of unique authored narratives. Models, task rewards and field pods are fictional.

## Astronaut and movement repair

The Z2 glove vertices previously exceeded the skinning code's forward-coordinate
gate, leaving them weighted to the torso while forearms moved. The arm envelope
now includes the full gloves, with corrected elbow/shoulder pivots and a relaxed
arm pose. Embedded WebP textures are converted to PNG during asset preparation
for reliable Godot import. The detailed suit and textures remain NASA derivatives.

Jump velocity was previously overwritten by the grounded controller. Buffered
jumps and 120 ms coyote time now apply takeoff within the physics step. Mars uses
3.71 m/s²; takeoff speed is sqrt(2gh), for 0.8 m normal or 1.3 m equipped jumps.
Those heights and suit damage thresholds are gameplay balances, not EVA predictions.
Hard falls damage suit integrity. The rover cannot jump. The NASA JPL reference
lists Mars gravity as 3.71 m/s²: https://ssd.jpl.nasa.gov/planets/phys_par.html

## LAN feasibility and operation

Choose Local Network Co-op or press L. One player hosts a listen server on UDP
24642. Up to three others join the host's LAN IP. All must run this same build.
No third-party server, authentication service, relay, account, UPnP or outbound
hosting platform is used. LAN connections do not require router port forwarding.

Allow the game on Windows private networks if prompted. Guest Wi-Fi, client/AP
isolation, VPN routing and local firewalls can prevent connectivity even when
devices use the same router. Use the address belonging to the common local network;
the UI lists possible host IPv4 addresses. Internet play, automatic discovery,
host migration, split-screen and commercial anti-cheat are not implemented.

The host distributes the seed and shared evidence/activity rewards, validates
interaction proximity, movement displacement/terrain envelope and client task
progress, then replicates results. Clients predict their own controller movement;
remote suits/rovers interpolate snapshots. Resources remain personal. Weather
time is synchronized to the host. Each player can travel independently and stream
their own surroundings. Menus stop only the local astronaut; the host process and
network must remain running. Host disconnection returns clients to a local pause;
their last received progress remains available. This is trusted-LAN co-op, not a
fully authoritative competitive physics simulation or hostile-internet service.

Godot's official networking guidance supports LAN join by internal IP and ENet/UDP:
https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
Origin shifting is an established large-world option:
https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html

## Validation

The retained source suite checks the original expedition, procurement/launch,
Earth-to-Mars transfer, nine-seed regional generation, weather/data units,
equipment/save logic and controller routes through all six original districts.
The new frontier integration checks deterministic sector sites, shared boundaries,
streamed collision at negative/far coordinates, bounded loaded sectors, roughly
250 km origin shifts, persistent completion, duplicate reward prevention, actual
Mars jump height, all seven platforms using the controller, and repair UI choices.

Two independent processes exercise ENet handshake, seed agreement, crew avatars,
host-validated/shared evidence, distant request rejection and late reconnect.
`tools/Verify-LAN.ps1` repeats the test for source or an exported executable.
This loopback test does not certify router/firewall behavior on a second physical PC.

GPU captures inspected the relaxed suit, course and streamed extension. On the
RTX 3050 laptop, a short 1280×720 streamed capture averaged about 142 FPS with
8.3 ms p95 after moving mesh work to a worker thread. Initial generation previously
caused 125 ms stalls. These short captures are not four-player, cross-hardware or
long-session performance guarantees. Dataset caveats remain in WEATHER_DATA.md.
