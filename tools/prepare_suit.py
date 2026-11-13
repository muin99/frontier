"""Normalize/decompress NASA Z2 and add a lightweight locomotion rig.
Requires numpy, DracoPy. Source remains unchanged in local tooling cache.
"""
from pathlib import Path
import json,struct,hashlib,math,urllib.request,io
from PIL import Image
import numpy as np
import DracoPy
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'tools/godot/cache'; CACHE.mkdir(exist_ok=True)
SOURCE=CACHE/'z2_spacesuit.glb'
URL='https://raw.githubusercontent.com/nasa/NASA-3D-Resources/master/3D%20Models/Z2%20Spacesuit/Z2%20Spacesuit.glb'
if not SOURCE.exists(): SOURCE.write_bytes(urllib.request.urlopen(URL,timeout=120).read())
b=SOURCE.read_bytes(); size=struct.unpack_from('<I',b,12)[0]; src=json.loads(b[20:20+size]); binary=b[28+size:]
prim=src['meshes'][0]['primitives'][0]; ext=prim['extensions']['KHR_draco_mesh_compression']; view=src['bufferViews'][ext['bufferView']]
mesh=DracoPy.decode(binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
attrs={a['unique_id']:a['data'] for a in mesh.attributes}
p=np.asarray(mesh.points,dtype=np.float32); p=np.column_stack([p[:,0],-p[:,2],p[:,1]])
scale=1.88/(p[:,1].max()-p[:,1].min()); p[:,1]-=p[:,1].min(); p*=scale
norm=np.asarray(attrs[ext['attributes']['NORMAL']],dtype=np.float32); norm=np.column_stack([norm[:,0],-norm[:,2],norm[:,1]])
uv=np.asarray(attrs[ext['attributes']['TEXCOORD_0']],dtype=np.float32)
out={'asset':{'version':'2.0','generator':'Mohashunnyo prepare_suit.py / NASA Z2 derivative'},'scene':0,'scenes':[{'nodes':[0]}],
     'nodes':[{'name':'Explorer','children':[1,2]},{'name':'Suit','mesh':0,'skin':0},{'name':'root','children':[]}],
     'materials':src['materials'],'textures':src['textures'],'samplers':src.get('samplers',[]),'images':[],
     'bufferViews':[],'accessors':[],'buffers':[{}]}
blob=bytearray()
def block(raw,target=None):
    while len(blob)%4: blob.append(0)
    v={'buffer':0,'byteOffset':len(blob),'byteLength':len(raw)}
    if target: v['target']=target
    out['bufferViews'].append(v); blob.extend(raw); return len(out['bufferViews'])-1
def accessor(a,kind,component=5126,target=None):
    a=np.asarray(a,dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[component]); v=block(a.tobytes(),target)
    item={'bufferView':v,'componentType':component,'count':len(a),'type':kind}
    if kind=='VEC3': item.update(min=a.min(axis=0).tolist(),max=a.max(axis=0).tolist())
    out['accessors'].append(item); return len(out['accessors'])-1
for im in src['images']:
    v=src['bufferViews'][im['bufferView']]; off=v.get('byteOffset',0)
    raw=binary[off:off+v['byteLength']]; mime=im['mimeType']
    if mime=='image/webp':
        target=io.BytesIO(); Image.open(io.BytesIO(raw)).save(target,format='PNG'); raw=target.getvalue(); mime='image/png'
    out['images'].append({'bufferView':block(raw),'mimeType':mime})
# Correct baked diffuse response; preserve source textures and its normal map.
out['materials'][0]['pbrMetallicRoughness']['roughnessFactor']=0.78
out['materials'][0]['doubleSided']=False
out['materials'][0].pop('extensions',None)
positions=[(0,0,0),(-.15,.87,0),(-.15,.43,0),(.15,.87,0),(.15,.43,0),(-.29,1.40,.10),(-.335,1.19,.31),(.29,1.40,.10),(.335,1.19,.31)]
names=['root','hip_l','knee_l','hip_r','knee_r','arm_l','elbow_l','arm_r','elbow_r']
parents=[None,0,1,0,3,0,5,0,7]
node_ids=[2]
for i in range(1,len(names)):
    node_ids.append(len(out['nodes'])); parent=parents[i]; delta=np.asarray(positions[i])-np.asarray(positions[parent])
    out['nodes'].append({'name':names[i],'translation':delta.tolist(),'children':[]})
    out['nodes'][node_ids[parent]]['children'].append(node_ids[i])
joints=np.zeros((len(p),4),dtype=np.uint16); weights=np.zeros((len(p),4),dtype=np.float32); weights[:,0]=1
for i,(x,y,z) in enumerate(p):
    side=1 if x<0 else 3
    if y<.87:
        knee=side+1; blend=np.clip((.52-y)/.15,0,1); joints[i,:2]=[side,knee]; weights[i,:2]=[1-blend,blend]
    elif (abs(x)>.245 or (abs(x)>.16 and z>.30)) and .87<y<1.49 and z>-.08:
        # The source gloves project to z=.61. The old z<.32 gate left them
        # attached to the torso while the forearms moved: the zombie hands bug.
        arm=5 if x<0 else 7; blend=np.clip((1.29-y)/.16,0,1)
        shoulder=max(np.clip((abs(x)-.245)/.07,0,1),np.clip((z-.26)/.10,0,1))
        joints[i,:3]=[0,arm,arm+1]; weights[i,:3]=[1-shoulder,shoulder*(1-blend),shoulder*blend]
ibms=[]
for pos in positions:
    m=np.eye(4,dtype=np.float32); m[:3,3]=-np.array(pos); ibms.append(m.T.flatten())
out['skins']=[{'inverseBindMatrices':accessor(ibms,'MAT4'),'joints':node_ids,'skeleton':2}]
out['meshes']=[{'name':'NASA_Z2_Articulated','primitives':[{'attributes':{'POSITION':accessor(p,'VEC3',target=34962),'NORMAL':accessor(norm,'VEC3',target=34962),'TEXCOORD_0':accessor(uv,'VEC2',target=34962),'JOINTS_0':accessor(joints,'VEC4',5123,34962),'WEIGHTS_0':accessor(weights,'VEC4',target=34962)},'indices':accessor(np.asarray(mesh.faces,dtype=np.uint32).flatten(),'SCALAR',5125,34963),'material':0}]}]
out['animations']=[]
assert np.isfinite(p).all() and np.isfinite(norm).all()
assert np.allclose(weights.sum(axis=1),1.0) and (weights>=0).all()
assert mesh.faces.min()>=0 and mesh.faces.max()<len(p)
assert abs(float(p[:,1].max()-p[:,1].min())-1.88)<0.001
for name,period,strength in [('idle',3.0,.012),('walk',1.15,.40),('run',.78,.62)]:
    times=np.linspace(0,period,33); ta=accessor(times,'SCALAR'); anim={'name':name,'channels':[],'samplers':[]}
    for bone in [1,2,3,4,5,6,7,8]:
        angles=[]
        for t in times:
            phase=t/period*2*math.pi+(math.pi if bone in [3,4,5,6] else 0)
            angle=math.sin(phase)*strength
            if bone in [2,4]: angle=max(0,-angle)*1.0
            if bone>=5: angle=0.57-angle*.34
            if bone in [6,8]: angle=0.10+abs(math.sin(phase))*.055
            angles.append([math.sin(angle/2),0,0,math.cos(angle/2)])
        ai=accessor(angles,'VEC4'); anim['channels'].append({'sampler':len(anim['samplers']),'target':{'node':node_ids[bone],'path':'rotation'}}); anim['samplers'].append({'input':ta,'output':ai,'interpolation':'LINEAR'})
    out['animations'].append(anim)
out['buffers'][0]['byteLength']=len(blob)
j=json.dumps(out,separators=(',',':')).encode(); j+=b' '*((-len(j))%4); blob+=b'\0'*((-len(blob))%4)
result=struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(blob))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(blob),0x004e4942)+blob
dest=ROOT/'game/assets/characters/explorer_z2.glb'; dest.write_bytes(result)
(dest.parent/'Z2_PROVENANCE.json').write_text(json.dumps({'source':URL,'credit':'NASA / Z2 Spacesuit model','sourceSha256':hashlib.sha256(b).hexdigest(),'derivativeSha256':hashlib.sha256(result).hexdigest(),'adaptation':'Draco decoded; normalized 1.88 m; authored nine-joint soft skin and idle/walk/run loops; baked textures retained. Concept suit, not validated Mars hardware.','triangles':len(mesh.faces)},indent=2))
print('Articulated suit',len(p),'vertices',len(mesh.faces),'triangles',len(result),'bytes')
