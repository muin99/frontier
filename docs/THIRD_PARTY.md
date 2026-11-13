# Third-party resources

## Iteration 5 assets

- NASA Space Exploration Vehicle concept model, official NASA 3D Resources `3D Models/Space Exploration Vehicle`. Source textures are retained; Draco is decompressed for Godot and runtime dimensions are normalized for the game. Checksums and adaptation notes: `game/assets/vehicles/SEV_PROVENANCE.json`. This is concept imagery used with an arcade controller, not a claim of flight readiness, actual crew operations on Mars, or NASA endorsement.

- NASA [Z2 Spacesuit](https://science.nasa.gov/3d-resources/z2-spacesuit/), official NASA 3D Resources repository. Retained source textures and insignia identify the original asset; no NASA endorsement is claimed. Source and derivative checksums and adaptation notes: `game/assets/characters/Z2_PROVENANCE.json`. The project adds locomotion skinning/animations and scale normalization. Consult NASA's [media usage guidance](https://www.nasa.gov/nasa-brand-center/images-and-media/) for redistribution; do not relabel the NASA asset as a CC0 creation by this project.
- Four active textured MakeHuman characters from MMWilliams/char-kit: `mh_3183`, `mh_3488`, `mh_3427`, `mh_1037`, CC0 per upstream generated body/asset statement. Additional inspected variants remain source tooling; provenance URLs and hashes are recorded in `CREW_PROVENANCE.json`. Original model textures and animations are retained; code adjusts materials and scale.
- ambientCG [Ground080](https://ambientcg.com/view?id=Ground080) and [Rock058](https://ambientcg.com/view?id=Rock058), CC0, 1K PBR surface art. These are Earth-scanned art materials, not NASA Martian observations. Source archive checksums are in each asset's `provenance.json`. Rock035 and Ground037 were inspected but are not used by the shipped Mars visual system and are excluded from the export.
- NASA PDS MEDA calibrated product derivatives and labels: `WEATHER_DATA.md`. Preserve scientific source attribution. Source CSV SHA-256 values are included in the derived JSON.

## Iteration 4 additions

The expedition terrain uses NASA PDS MGS MOLA `MEGT90N000CB.IMG`; [exact provenance](MARS_DATA.md) includes the primary data URL, label, SHA-256 and transformations. This is scientific data use, not NASA endorsement. Preserve attribution and the PDS label when redistributing. The new Mars habitat, astronaut suit, vehicles, terrain material, stylized Earth and interface are authored code geometry/shaders. No NASA insignia or generated image assets are used. Audio cues are generated sine waves.

The Windows distribution includes the official Godot 4.7.2 release runtime with its MIT license and third-party notices. The template is fetched from the official release archive, verified by ZIP CRC, and recorded in `tools/godot/templates/provenance.json`. Game-development guidance was read from `gamedev-skills/awesome-gamedev-agent-skills` revision `19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9` (Apache-2.0); it is development tooling, not bundled game content.

## Godot Engine

Portable Windows editor/runtime, version 4.7.2 stable. Downloaded from the official `godotengine/godot` GitHub release. Godot is MIT licensed; [license text and third-party notices](https://godotengine.org/license/). Engine binaries are local tooling and ignored by Git. Preserve license notices if redistributing binaries.

## Materials

| Asset | Provider | License | Use |
|---|---|---|---|
| [MetalPlates006](https://ambientcg.com/view?id=MetalPlates006) | ambientCG | CC0-1.0 | metal decks and work surfaces |
| [Concrete034](https://ambientcg.com/view?id=Concrete034) | ambientCG | CC0-1.0 | facility floors |

1K JPG color, OpenGL normal and roughness maps downloaded October 19, 2026. Metalness is retained where supplied. Each asset's `provenance.json` records its source-archive SHA-256. Source archives are local caches excluded from Git. [ambientCG licensing](https://docs.ambientcg.com/license/).

## Science references

[NASA/JPL Solar System Dynamics: Planetary Physical Parameters](https://ssd.jpl.nasa.gov/planets/phys_par.html), accessed October 19, 2026. Mars equatorial gravity 3.71 m/s²; mean radius 3389.50 ± 0.2 km. These reference parameters are informational in the current build. They are not a NASA endorsement, simulated telemetry, or evidence that the fictional facility or vehicle could support a real mission.

No downloaded spacecraft models, commercial asset packs, NASA insignia, or generated bitmap art are included. Facility structures, prop geometry and vehicles are authored in Godot code.

## Human character

The active player and crew use two textured, rigged MakeHuman characters from [MMWilliams/char-kit](https://github.com/MMWilliams/char-kit). The upstream project identifies its generated MakeHuman bodies and bundled MakeHuman assets as CC0 and provides each character as a self-contained GLB with animations. This build uses only the idle, walk and run clips. The game adds lightweight role accessories without replacing skin or clothing textures. Local provenance, exact download URLs and SHA-256 checksums are stored in `game/assets/characters/provenance.json`.


## Iteration 7 original field hardware

The twenty deployable module designs, resource formations and survey-drone mesh in
`game/scripts/field_hardware.gd` are original authored procedural geometry for this
project. They introduce no downloaded or generated third-party visual assets.
They are speculative game equipment; NASA does not supply or endorse their designs,
prices, capacities, industrial chemistry, resource distributions or production rates.
