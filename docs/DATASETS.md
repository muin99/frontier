# NASA Dataset Ledger

This is a candidate-data registry, not a claim that every source will be shipped. The MVP should use a few datasets deeply and visibly. Every processed artifact must later include source URL, product identifier, retrieval date, transformation script/version, coordinate reference, resolution, missing-data behavior, checksum, and license/usage note.

## MVP candidates

| ID | Source/product | Mission/instrument | Game use | Planned transformation | Status |
|---|---|---|---|---|---|
| DS-001 | [MOLA MEGDR global topography](https://pds-geosciences.wustl.edu/missions/mgs/megdr.html) | Mars Global Surveyor / MOLA | Real elevation, derived slope, landing risk, rover energy cost, terrain rendering | Crop one region; reproject/resample; quantize elevation; derive slope; retain nodata mask | Primary, verified source |
| DS-002 | [THEMIS derived global mosaics](https://astrogeology.usgs.gov/search/map/Mars/Odyssey/THEMIS-IR-Mosaic-ASU/Mars_MO_THEMIS-IR-Day_mosaic_global_100m_v12) | Mars Odyssey / THEMIS IR | Visual texture and thermal-inertia-informed terrain/science probability | Crop to MOLA bounds; co-register; create low-resolution class layer | Candidate; verify exact product/version |
| DS-003 | [CRISM data archive](https://pds-geosciences.wustl.edu/missions/mro/crism.htm) | Mars Reconnaissance Orbiter / CRISM | Mineral-bearing science targets and instrument gameplay | Select documented summary products/regions; convert mineral detections to probability masks | Candidate; scientist/GIS review needed |
| DS-004 | [Mars surface weather data (REMS)](https://pds-atmospheres.nmsu.edu/data_and_services/atmospheres_data/MARS/curiosity.html) | Curiosity / REMS | Plausible temperature, pressure, wind, and daily environmental scenarios | Extract representative sol profiles; label location and season limits | Candidate; not global ground truth |
| DS-005 | [NAIF SPICE](https://naif.jpl.nasa.gov/naif/) | NASA/JPL ephemerides and geometry | Earth–Mars geometry, dates, distance, communication delay, launch-window context | Precompute a small table from named kernels and record kernel versions | Primary for later fidelity |
| DS-006 | [NASA OSDR/RadLab](https://visualization.osdr.nasa.gov/) | Multiple missions/dosimeters | Evidence-based radiation education and scenario ranges | Use a documented, bounded scenario table; do not present ISS measurements as Mars measurements | Candidate; careful contextualization |

## Supporting operational sources

| ID | Source | Game use | Status/constraint |
|---|---|---|---|
| DS-007 | [JPL CNEOS close-approach data API](https://ssd-api.jpl.nasa.gov/doc/cad.html) | Teach how small-body observations characterize encounters; seed optional educational event cards | Do not imply listed Earth close approaches are hazards on an Earth–Mars trajectory |
| DS-008 | [NASA DONKI API](https://api.nasa.gov/) | Solar-flare/CME/solar energetic particle event context | Live data must be cached; historical Earth-directed events are illustrative unless propagated for mission geometry |
| DS-009 | [NASA PDS Geosciences Node](https://pds-geosciences.wustl.edu/) | Canonical planetary geology archive and metadata | Use product-level citations, not only the portal URL |
| DS-010 | [NASA Mars Trek](https://trek.nasa.gov/mars/) | Human cross-checking of landing regions and layers | Visualization/reference service; identify underlying products for shipped data |

## Engineering references (not observational datasets)

| ID | Reference | Intended use |
|---|---|---|
| REF-001 | [NASA Systems Engineering Handbook, Rev 2](https://www.nasa.gov/reference/systems-engineering-handbook/) | Mission lifecycle, margins, risk, verification language, trade studies |
| REF-002 | [NASA Human Integration Design Handbook](https://www.nasa.gov/wp-content/uploads/2023/03/human-integration-design-handbook.pdf) | Human factors and habitability framing |
| REF-003 | [NASA-STD-3001 technical briefs](https://www.nasa.gov/directorates/esdmd/hhp/nasa-std-3001-technical-briefs/) | Human health, environment, nutrition, sleep, exercise, and radiation constraints |
| REF-004 | [Human Mars Missions: Requirements and Issues](https://ntrs.nasa.gov/citations/20130014012) | ISRU/resource context and mission trade-off background |
| REF-005 | [Mars Fact Sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html) | Planet constants and high-level environmental facts |

## Provenance card schema

Every in-game source card should expose:

```json
{
  "sourceId": "DS-001",
  "provider": "NASA PDS Geosciences Node",
  "mission": "Mars Global Surveyor",
  "instrument": "MOLA",
  "product": "exact product identifier here",
  "observedOrDerived": "derived",
  "spatialCoverage": "landing-region bounds here",
  "resolution": "source and game resolution here",
  "retrievedAt": "ISO-8601 timestamp",
  "processing": ["crop", "resample", "slope derivation", "quantization"],
  "limitations": "What this layer cannot establish",
  "sourceUrl": "canonical product URL",
  "checksum": "sha256 of raw/processed artifact"
}
```

## Data quality rules

- Never label a procedural placement as an observed discovery. Say “data-conditioned simulated target.”
- Never combine rasters before checking longitude convention, latitude type, datum, projection, resolution, and nodata.
- Preserve uncertainty or confidence classes when the source provides them.
- Do not use present-day Earth-directed space-weather data as a literal future Mars-transit forecast.
- Avoid false precision. Display ranges and assumptions where the model is coarse.
- Cache small processed subsets so the judge demo does not depend on network access.
- Put attribution both in the game and repository.

## Dataset acceptance test

A dataset enters the MVP only if the team can answer all five questions:

1. What spacecraft/instrument measured it?
2. What does each value physically mean?
3. What are its spatial/temporal limits and uncertainties?
4. What player decision changes because of it?
5. Can a judge trace the transformed value back to a canonical product?

