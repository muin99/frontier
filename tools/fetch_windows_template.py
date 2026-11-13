"""Fetch only the official Windows release executable from the remote ZIP.

HTTP byte ranges avoid downloading all 1.28 GB of unrelated platform templates.
zipfile verifies the selected ZIP member's CRC on extraction.
"""
from pathlib import Path
import hashlib, io, json, struct, urllib.request, zipfile

ROOT = Path(__file__).resolve().parents[1]
URL = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
TOTAL = 1281349702

class RemoteZip(io.RawIOBase):
    def __init__(self): self.pos = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else (self.pos + offset if whence == 1 else TOTAL + offset)
        return self.pos
    def read(self, count=-1):
        if count < 0: count = TOTAL-self.pos
        count = min(count,TOTAL-self.pos)
        if count <= 0: return b''
        start = self.pos
        req = urllib.request.Request(URL,headers={'Range':f'bytes={start}-{start+count-1}'})
        with urllib.request.urlopen(req,timeout=120) as r:
            if r.status != 206: raise RuntimeError('Server did not honor Range')
            result = r.read()
        if len(result) != count: raise RuntimeError('Truncated range')
        self.pos += count
        return result

dest = ROOT/'tools/godot/templates'
dest.mkdir(exist_ok=True)
with zipfile.ZipFile(RemoteZip()) as archive:
    matches = [v for v in archive.infolist() if v.filename.endswith('windows_release_x86_64.exe')]
    if len(matches) != 1: raise RuntimeError([v.filename for v in archive.infolist() if 'windows' in v.filename])
    entry = matches[0]
    print('Fetching',entry.filename,entry.compress_size,'compressed bytes',flush=True)
    payload = archive.read(entry)
    (dest/'windows_release_x86_64.exe').write_bytes(payload)
    (dest/'provenance.json').write_text(json.dumps(dict(url=URL,member=entry.filename,sha256=hashlib.sha256(payload).hexdigest()),indent=2))
    print('Windows template ready',len(payload),flush=True)
