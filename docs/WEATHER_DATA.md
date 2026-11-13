# MEDA weather evidence — observed versus simulated

Retrieved 4 November 2026 from the NASA PDS Atmospheres Node.

Base directory: https://atmos.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/data_calibrated_env/sol_0000_0089/sol_0020/

Products (CSV plus accompanying PDS4 XML labels retained in source):

- `WE__0020___________CAL_ATS_________________P01`: `ATS_LOCAL_TEMP1`, kelvin.
- `WE__0020___________CAL_PS__________________P02`: `BAROCAP1_PRESSURE`, pascal.

`python tools/prepare_weather.py` downloads products with certificate verification, reads LMST timestamps and numeric sensor columns, excludes missing/non-numeric samples and applies broad plausibility bounds (100–350 K and 400–1000 Pa). These bounds are application screening, not NASA quality flags. The script computes **15-minute medians** only where both products have samples. The derived JSON contains source IDs, SHA-256 for each CSV, sample counts, 32 populated bins and explicit limitations. No missing duty-cycle bins are represented as observations.

Profile ranges: 205.49–243.76 K (−67.66 to −29.39 °C); 733.54–750.84 Pa. ATS local sensor temperature is not a corrected, globally representative air temperature. Pressure comes from Barocap 1 as labelled; this is not a cross-sensor fused estimate. Uncertainty fields are not synthesized when absent.

The game linearly interpolates between available medians and loops/compresses that historical sol. Thus the HUD says **MEDA PROFILE**, not current Mars weather. A one-sol, one-location series cannot establish a global climate, seasonal frost, wind field or storm distribution.

## Wind analog from a second observed sol

Additional product: `WE__0036___________DER_WS__________________P02`, MEDA derived wind, metres/second, at https://atmos.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/data_derived_env/sol_0000_0089/sol_0036/ . Its XML label is included. The script accepts stationary-rover rows (`ROVER_STILL=1`) with finite plausible horizontal wind speed and rejects the `999999999` missing-value sentinel. Of 41,538 rows, 40,543 pass; 995 are excluded. Observed accepted values span 0–16.24 m/s.

The both-booms-used flag is blank in all rows and speed uncertainty is not reported. The game does not invent those fields or claim a validated dual-boom estimate. The derived JSON explicitly records missing-flag/uncertainty counts. Empirical P10, P20, P50, P75, P90 and P99 magnitudes are 1.78, 2.46, 4.86, 6.93, 8.96 and 11.85 m/s. Weather scenarios use these quantiles to constrain wind/particle speeds. Assigning a high quantile to a dust-front scenario does **not** diagnose an observed storm.

This sol 36 wind sample is not contemporaneous with sol 20 pressure/temperature. The HUD says **WIND ANALOG** and source cards identify the composite. The raw source CSVs live outside Godot's resource tree in `data/nasa/meda/` so they are not accidentally imported as translation tables. XML labels and the derived JSON stay in `game/assets/meda/`.

## Simulated layer

The world seed and 55-second scenario blocks select clear sky, high cloud, dust haze, a local dust front, cold twilight or dust devils. Event selection, cloud opacity, particle rendering, visibility, solar penalties and probabilities are **authored game scenarios**; wind amplitudes use the separate empirical quantiles above. They are not storm measurements extracted from the temperature/pressure files. Highland cooling of 10 °C is an explicit local scenario offset and is kept separate from the unmodified sensor profile in the HUD. The weather station card and source ledger repeat these distinctions.

Cold frost haze is inspired by documented Martian seasonal phenomena; it is not inferred from Jezero sol 20, and the game does not solve condensation/deposition microphysics. Dust rendering does not imply Earth-like aerodynamic force: Mars' thin atmosphere matters. No terrestrial rain, liquid-water rivers or Earth thunderstorms are generated.

Primary context:

- MEDA instrument/data guide: https://pds-atmospheres.nmsu.edu/data_and_services/atmospheres_data/PERSEVERANCE/meda.html
- NASA on seasonal frost and dunes: https://www.nasa.gov/solar-system/nasa-explores-a-winter-wonderland-on-mars/
- NASA on basaltic dunes and frost: https://www.jpl.nasa.gov/videos/mars-dry-ice-and-dunes/
- NASA on layered Martian hills: https://apod.nasa.gov/apod/ap100815.html

The data are cached for offline play. The exported game includes the derived profile, source metadata and XML labels; multi-megabyte raw CSVs remain in the source repository and are excluded from the runtime package.
