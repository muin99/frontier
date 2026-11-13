# MOLA pipeline and scientific limits

## Iteration 5 update

The same 65 × 65 source crop now underlies a **1536 × 1536 game-metre** arena. Vertical MOLA metres scale by **0.008** relative to the habitat datum. A versioned, seeded generator adds local terrain at a 193 × 193 mesh resolution: dune, basalt, canyon, mesa, highland and impact analogs. These six districts are a fictional composite inspired by observed Martian landform families, not six measured adjacent regions in the crop. Valley approaches and discovery-site paths are generated for traversability. Props, feet and targets sample the same triangulated height surface as rendering/collision.

These procedural landforms and their composition are **not** inferred from MOLA. Source resolution, coordinate system and scientific limits below remain unchanged. The original iteration-4 transformation below is historical and superseded by this section. See [weather provenance](WEATHER_DATA.md) for the separate real MEDA profile and simulated event layer.

Primary source: NASA PDS Geosciences Node, MGS MOLA MEGDR, product `MEGT90N000CB.IMG`, dataset `MGS-M-MOLA-5-MEGDR-L3-V1.0`.

- Source binary: https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-5-megdr-l3-v1/mgsl_300x/meg004/megt90n000cb.img
- PDS label: https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-5-megdr-l3-v1/mgsl_300x/meg004/megt90n000cb.lbl
- Source SHA-256: `25f16fb7aaf857898dcf98bc4f841341a24f8b9f7e98453ca083bc45d897ca2c`
- 720 rows × 1440 columns, signed 16-bit big-endian; 0.25°/pixel; metres above the MOLA areoid.
- Label product version 2.0, creation date 3 April 2003. Data include observations through June 2001. This is archived observation, not live telemetry.

`python tools/prepare_mars.py` verifies the global binary length, unpacks the grid, and crops rows 262–326 and columns 286–350 inclusive. Crop pixel centres run from 24.375°N to 8.375°N and 71.625°E to 87.625°E. The JSON retains source URLs, checksum, coordinates, units and transformation description. No API key is required. The cached crop works offline.

The crop provides regional Isidis/Jezero **context**, not the actual Jezero crater floor at walking resolution. `mars_world.gd` bilinearly samples the crop and compresses it into a 512 × 512 game-metre arena; vertical metres are multiplied by 0.004 relative to the habitat datum. Terrain collision uses the rendered triangulated mesh. Height readings interpolate the original elevation, while the mesh samples its 65 × 65 nodes; minor subcell bilinear/triangle differences are expected.

At approximately 14.8 km/pixel north–south this product cannot establish local paths, safe landing slopes, rocks, mineral distributions or biosignatures. No such claim is made. Rocks, markers, individual sample targets, habitat and hardware are authored game geometry. Science observations in the cards are educational scenarios, not measurements extracted from MOLA.

The lower-basin and upland landing menu shows measured regional elevation and maps those contexts to fixed game consequences. The integrity penalty and science bonus are assumptions; they are not a computed entry/descent/landing risk model.

NASA science context: https://science.nasa.gov/mission/mars-2020-perseverance/science/

The game uses complementary geological contexts and cautious evidence interpretation. It does not claim to detect life, date a sample or identify a mineral from topography. Radiation, dust timing, resource units, fission/solar charging rates and mission scores are transparent game balances. Earth texture in the departure sequence is stylized procedural artwork, not a NASA Earth observation.
