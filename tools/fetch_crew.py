from pathlib import Path
import urllib.request,concurrent.futures,json,hashlib
ROOT=Path(__file__).resolve().parents[1]; DEST=ROOT/'game/assets/characters'
BASE='https://raw.githubusercontent.com/MMWilliams/char-kit/master/'
def fetch(name):
    p=DEST/(name+'.glb'); u=BASE+'characters/'+name+'.glb'
    if not p.exists(): p.write_bytes(urllib.request.urlopen(u,timeout=120).read())
    return {'asset':name,'url':u,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'license':'CC0-1.0 per upstream MakeHuman asset statement'}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: result=list(pool.map(fetch,['mh_3183','mh_3122','mh_3427','mh_3305','mh_3488','mh_1037']))
(DEST/'CREW_PROVENANCE.json').write_text(json.dumps(result,indent=2))
(ROOT/'build/char-kit-AGENTS.md').write_bytes(urllib.request.urlopen(BASE+'AGENTS.md').read())
print(result)
