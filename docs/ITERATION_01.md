# Iteration 1 — Native spaceport

Built October 19, 2026 in Godot 4.7.2 stable. This iteration provides the walkable facility requested by the user. It is a first environment pass with original geometry and downloaded PBR materials, not final production art.

## Implemented

Five connected sectors: arrival, outfitting, integration, mission control and launch complex. Native first-person capsule movement, sprinting, acceleration/deceleration, gravity, static collision, source terminals, module drag-and-drop preview, schematic player map, room detection, sector visit tracking, pause on focus loss, fullscreen and saved graphics/sensitivity preferences.

Structural boxes are batched by material using MultiMesh, with separate collision shapes. Textures are 1K mipmapped color/normal/roughness maps. Balanced uses 2× MSAA and one shadow-casting sun; Performance disables both shadows and MSAA. Interior illumination is unshadowed. Rendering uses native OpenGL Compatibility to keep the project practical on the development laptop.

## Verification

Run `powershell -ExecutionPolicy Bypass -File tools/Verify.ps1` from the repository root. The headless check loads the actual scene, probes a capsule every 0.25 m along intended room-to-room routes, opens all four terminal types, rejects invalid drag payloads, replaces a module, performs a native GUI pointer drag from catalog to slot, and drives the actual character against a wall while checking floor contact.

The first route check found structural posts obstructing side-door openings; those posts were removed from the openings. Furniture is routed around rather than made non-colliding to satisfy the test.

The project was also rendered on the actual NVIDIA RTX 2050, using Balanced at a 1280×720 window. Each capture ran 360 rendered frames, discarding the first 120 frames for the timing sample. Latest short samples:

| View | Mean FPS | 95th percentile frame time | Draw calls at capture |
|---|---:|---:|---:|
| Shop | 60.0 | 16.7 ms | 230 |
| Engineering terminal overlay | 60.0 | 16.7 ms | 299 |
| Launch complex | 60.0 | 16.7 ms | 146 |

The refresh-limited figures do not measure maximum throughput. Startup can be slower while shaders compile; the initial arrival screenshot showed 42 FPS. This is not a long playtest, a full traversal benchmark, or evidence that later game systems will hold the same rate. Render logs and screenshots are local files in ignored `build/`.

For a new capture, create `build/` and run the portable engine with `--path game -- --capture=arrival`, `--capture=shop`, `--capture=launch`, `--capture=terminal` or `--capture=menu`. Rendering requires an interactive desktop and GPU; headless smoke checks do not render images. Capture mode exits automatically.

## Science and assets

The mission-control screens load a cached NASA/JPL reference JSON and link to its original source. They do not claim to show live telemetry. This iteration has no Mars terrain, environmental dataset pipeline or validated mission physics. See the dataset ledger for the next stages and THIRD_PARTY.md for material provenance.

No Blender installation or plugin was necessary for this iteration. Geometry is built in Godot code, with a consistent palette of structural steel, pale panels, cyan lighting and amber engineering markings. The editable source supports later replacement of props with authored meshes. The player is represented by a camera and collider, with no animated body yet.

## Next guidance

The user will guide subsequent iterations. Candidate work includes art refinement, shop inventory and budget, persistent drag-and-drop spacecraft assembly, then launch/mission progression and NASA observational datasets. No full economy, spacecraft validation, launch simulation, or standalone Windows export is included now.
