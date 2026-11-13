Earthdata Login	urs.earthdata.nasa.gov	Free account, .netrc or bearer token	—	Auth for most Earth data	Make the account now
earthaccess	pip install earthaccess	EDL	—	Search, download, stream to xarray	Yes
CMR Search	cmr.earthdata.nasa.gov/search	None	2,000 granules per page	REST: json, umm_json, echo10	Metadata only
Harmony	harmony.earthdata.nasa.gov	EDL token	Server-side jobs	Subset, reproject, reformat	Yes — subset once
AppEEARS	appeears.earthdatacloud.nasa.gov/api/	EDL to bearer	—	Point and area sampling	Yes
FIRMS	firms.modaps.eosdis.nasa.gov/api/	Free MAP_KEY	5,000 transactions per 10 min	Area CSV API	Yes — CSV to parquet
NASA POWER	power.larc.nasa.gov/api/	None	Throttled, one request per grid cell	Daily, hourly, monthly, climatology	Yes
api.nasa.gov	api.nasa.gov	api_key	DEMO_KEY 30/hr, 50/day · key 1,000/hr	APOD, EPIC, NeoWs, Mars Photos	Yes
GIBS	gibs.earthdata.nasa.gov/wmts/	None	—	WMTS and WMS tiles	Yes — to PMTiles
ASF (NISAR, Sentinel-1)	api.daac.asf.alaska.edu	EDL to download	—	SearchAPI and asf_search	Yes — pull scenes
IRSA / SPHEREx	irsa.ipac.caltech.edu	None	—	SIA v2, pyvo, astroquery, AWS	Yes — cutouts
PDS Search	pds.nasa.gov/api/search/1/	None	—	REST, pds.peppi	Metadata
Solar System Treks	trek.nasa.gov/tiles/	None	—	WMTS tiles, GetCapabilities	Yes — tiles
WebGeocalc	wgc2.jpl.nasa.gov:8443/webgeocalc/api/	None	Light use only	SPICE geometry online	Use SpiceyPy locally
SpiceyPy	pip install spiceypy	None	—	Local CSPICE geometry	Yes — kernels
OSDR / GeneLab	osdr.nasa.gov/osdr/data/	None	—	REST JSON and CSV	Yes
NTRS	ntrs.nasa.gov/api/	None	Not published	Citations, search, PDFs	Yes — PDFs
NASA ADS	api.adsabs.harvard.edu/v1/	Free bearer token	—	Literature search	Metadata
