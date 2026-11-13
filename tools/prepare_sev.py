"""Decode the official NASA SEV concept mesh for Godot; preserve texture provenance."""
from pathlib import Path
import json,struct,hashlib,urllib.request
import numpy as np
import DracoPy
ROOT=Path(__file__).resolve().parents[1]; CACHE=ROOT/'tools/godot/cache'; CACHE.mkdir(exist_ok=True)
URL='https://raw.githubusercontent.com/nasa/NASA-3D-Resources/master/3D%20Models/Space%20Exploration%20Vehicle/Space%20Exploration%20Vehicle.glb'
source=CACHE/'sev.glb'
if not source.exists(): source.write_bytes(urllib.request.urlopen(URL,timeout=120).read())
b=source.read_bytes(); n=struct.unpack_from('<I',b,12)[0]; src=json.loads(b[20:20+n]); binary=b[28+n:]
out={k:v for k,v in src.items() if k not in ['accessors','bufferViews','buffers','meshes','extensionsRequired','extensionsUsed']}
out['asset']={'version':'2.0','generator':'Mohashunnyo prepare_sev.py / NASA SEV derivative'}
out['accessors']=[]; out['bufferViews']=[]; blob=bytearray()
def block(raw,target=None):
    while len(blob)%4: blob.append(0)
    view={'buffer':0,'byteOffset':len(blob),'byteLength':len(raw)}
    if target: view['target']=target
    out['bufferViews'].append(view); blob.extend(raw); return len(out['bufferViews'])-1
def accessor(values,kind,component=5126,target=34962):
    a=np.asarray(values,dtype='<u4' if component==5125 else '<f4')
    item={'bufferView':block(a.tobytes(),target),'componentType':component,'count':len(a),'type':kind}
    if kind=='VEC3': item.update(min=a.min(axis=0).tolist(),max=a.max(axis=0).tolist())
    out['accessors'].append(item); return len(out['accessors'])-1
for image in out.get('images',[]):
    view=src['bufferViews'][image['bufferView']]; start=view.get('byteOffset',0)
    image['bufferView']=block(binary[start:start+view['byteLength']])
out['meshes']=[]; triangle_count=0
for original in src['meshes']:
    result={'name':original.get('name','SEV'),'primitives':[]}
    for primitive in original['primitives']:
        extension=primitive['extensions']['KHR_draco_mesh_compression']; view=src['bufferViews'][extension['bufferView']]; start=view.get('byteOffset',0)
        mesh=DracoPy.decode(binary[start:start+view['byteLength']]); attrs={a['unique_id']:a['data'] for a in mesh.attributes}
        attributes={}
        for name,uid in extension['attributes'].items():
            values=attrs[uid]; size=values.shape[1]; kind={2:'VEC2',3:'VEC3',4:'VEC4'}[size]
            assert np.isfinite(values).all()
            attributes[name]=accessor(values,kind)
        assert mesh.faces.max()<len(mesh.points)
        result['primitives'].append({'attributes':attributes,'indices':accessor(mesh.faces.flatten(),'SCALAR',5125,34963),'material':primitive.get('material',0)})
        triangle_count+=len(mesh.faces)
    out['meshes'].append(result)
for material in out.get('materials',[]):
    material['doubleSided']=False
    material.setdefault('pbrMetallicRoughness',{})['roughnessFactor']=0.7
    material.pop('extensions',None)
if any('extensions' in texture for texture in out.get('textures',[])): out['extensionsUsed']=['EXT_texture_webp']
out['buffers']=[{'byteLength':len(blob)}]
j=json.dumps(out,separators=(',',':')).encode(); j+=b' '*((-len(j))%4); blob+=b'\0'*((-len(blob))%4)
result=struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(blob))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(blob),0x004e4942)+blob
dest=ROOT/'game/assets/vehicles'; dest.mkdir(exist_ok=True); (dest/'sev.glb').write_bytes(result)
(dest/'SEV_PROVENANCE.json').write_text(json.dumps({'source':URL,'sourceSha256':hashlib.sha256(b).hexdigest(),'derivativeSha256':hashlib.sha256(result).hexdigest(),'triangles':triangle_count,'adaptation':'Draco decompressed; source textures retained; runtime scale/feet normalization. NASA concept vehicle, not certified Mars hardware. Arcade movement/collision proxy, not wheel physics.'},indent=2))
print('SEV:',triangle_count,'triangles',len(result),'bytes')
