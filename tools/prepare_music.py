"""Original deterministic ambient score, no samples or third-party compositions."""
from pathlib import Path
import numpy as np,wave,json
root=Path(__file__).resolve().parents[1]/'game/assets/audio';root.mkdir(exist_ok=True)
sr=24000;duration=64;n=sr*duration;t=np.arange(n)/sr
for name,tension in [('frontier_ambient',False),('frontier_pressure',True)]:
 audio=np.zeros((n,2),dtype=np.float64)
 roots=[45,48,43,50,45,52,48,43]
 for chord,rootnote in enumerate(roots):
  start=chord*8;mask=(t>=start)&(t<start+8);tt=t[mask]-start
  env=np.sin(np.pi*tt/8)**2
  for voice,semi in enumerate([0,7,14,19]):
   f=round((440*2**((rootnote+semi-69)/12))*8)/8
   pad=(np.sin(2*np.pi*f*tt)+.19*np.sin(2*np.pi*f*2*tt))*.035*env
   audio[mask,voice%2]+=pad;audio[mask,1-voice%2]+=pad*.6
 for beat in range(0,128,1 if tension else 2):
  start=beat*.5;idx=np.where((t>=start)&(t<start+.45))[0];tt=t[idx]-start
  note=[69,76,81,72,79,74,83,76][beat%8];f=440*2**((note-69)/12)
  pulse=np.sin(2*np.pi*f*tt)*np.exp(-tt*(16 if tension else 9))*(1-np.exp(-tt*100))*(.042 if tension else .025)
  audio[idx,beat%2]+=pulse;audio[idx,1-beat%2]+=pulse*.3
 if tension: audio+=np.sin(2*np.pi*48*t)[:,None]*.018*(.5+.5*np.sin(2*np.pi*t*2))[:,None]
 fade=np.minimum(1,np.minimum(t/1.5,(duration-t)/1.5));audio*=fade[:,None]
 pcm=(np.clip(audio,-.8,.8)*32767).astype('<i2')
 with wave.open(str(root/(name+'.wav')),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes(pcm.tobytes())
 assert np.isfinite(audio).all() and np.max(np.abs(audio))<.8
 print(name,'peak',round(float(np.max(np.abs(audio))),3),'rms',round(float(np.sqrt(np.mean(audio**2))),4))
(root/'PROVENANCE.json').write_text(json.dumps({'creator':'Original procedural composition for Mohashunnyo','method':'Deterministic additive synthesis, harmonic pads and authored note sequences; no external audio samples','sampleRate':sr,'durationSeconds':duration,'files':['frontier_ambient.wav','frontier_pressure.wav']},indent=2))
