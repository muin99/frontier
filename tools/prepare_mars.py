"""Reproducible, dependency-free NASA PDS MOLA crop. Run after downloading source."""
from pathlib import Path
import hashlib, json, struct, urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'game/assets/mola'
BASE = 'https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-5-megdr-l3-v1/mgsl_300x/meg004/'
DEST.mkdir(exist_ok=True)
for ext in ('lbl', 'img'):
    p = DEST / ('megt90n000cb.' + ext)
    if not p.exists() or p.stat().st_size == 0:
        p.write_bytes(urllib.request.urlopen(BASE + p.name, timeout=120).read())
raw = (DEST / 'megt90n000cb.img').read_bytes()
assert len(raw) == 720 * 1440 * 2
values = struct.unpack('>1036800h', raw)
# Pixel-centre coordinates follow label's 0.25-degree simple cylindrical grid.
row0, col0, n = 262, 286, 65
grid = [[values[(row0 + y) * 1440 + col0 + x] for x in range(n)] for y in range(n)]
data = dict(version=1, product='MEGT90N000CB.IMG', dataset='MGS-M-MOLA-5-MEGDR-L3-V1.0',
    source=BASE+'megt90n000cb.img', label=BASE+'megt90n000cb.lbl',
    sha256=hashlib.sha256(raw).hexdigest(), instrument='Mars Global Surveyor / MOLA',
    resolutionDegrees=0.25, north=90-(row0+0.5)/4, west=(col0+0.5)/4,
    width=n, heights=grid, units='metres relative to MOLA areoid',
    interpretation='Regional Isidis/Jezero context compressed into a 1536 m game arena, vertical factor 0.008. A 193 x 193 rendered/collision grid combines it with seeded local geological analogs and traversable routes. Rocks, targets and hardware are simulated; no measured local slope or mineral inference.',
    runtimeTransformation={'arenaMetres':1536,'molaVerticalFactor':0.008,'renderGridWidth':193,'localGeneratorVersion':2})
(DEST / 'isidis.json').write_text(json.dumps(data, separators=(',', ':')))
print('MOLA crop:', n, 'x', n, 'range', min(map(min,grid)), max(map(max,grid)), 'sha256', data['sha256'])
