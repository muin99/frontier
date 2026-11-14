"""Edit actual Godot Movie Maker captures into captioned, judge-ready MP4s.

Prerequisite footage: guided.avi, adventure.avi, lab-{arrival,bay,crew,control,ascent}.avi.
No images or speech are generated. Raw captures and encoded MP4s stay under build/.
"""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import textwrap

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/media_vendor'))
import imageio_ffmpeg

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
RAW = ROOT / 'build/footage/raw'
OUT = ROOT / 'build/media'
WORK = ROOT / 'build/footage/edit'
SUBTITLES = ROOT / 'docs/media'

def run(args, log_name):
    with (WORK / log_name).open('w', encoding='utf-8') as log:
        result = subprocess.run([FFMPEG, '-hide_banner', '-y', *args], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f'Video command failed; see {WORK / log_name}')

def duration(path):
    result = subprocess.run([FFMPEG, '-hide_banner', '-i', str(path)], capture_output=True, text=True, encoding='utf-8', errors='replace')
    match = re.search(r'Duration: (\d+):(\d+):(\d+\.\d+)', result.stderr)
    if not match:
        raise RuntimeError('Could not read duration: ' + str(path))
    return int(match[1])*3600 + int(match[2])*60 + float(match[3])

def stamp(seconds, ass=False):
    units = round(seconds * (100 if ass else 1000))
    scale = 100 if ass else 1000
    hours, rem = divmod(units, 3600*scale)
    minutes, rem = divmod(rem, 60*scale)
    secs, fraction = divmod(rem, scale)
    return f'{hours}:{minutes:02}:{secs:02}.{fraction:02}' if ass else f'{hours:02}:{minutes:02}:{secs:02},{fraction:03}'

def captions(name, entries):
    srt = OUT / (name + '.srt')
    srt.write_text('\n\n'.join(f'{i+1}\n{stamp(start)} --> {stamp(end)}\n{text}' for i,(start,end,text) in enumerate(entries))+'\n', encoding='utf-8')
    shutil.copy2(srt, SUBTITLES / srt.name)
    ass = WORK / (name + '.ass')
    header = '''[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 800
WrapStyle: 0
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Narration,Segoe UI,26,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1,0,2,45,45,13,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
    events = []
    for start,end,text in entries:
        wrapped = r'\N'.join(textwrap.wrap(text, width=90))
        events.append(f'Dialogue: 0,{stamp(start,True)},{stamp(end,True)},Narration,,0,0,0,,{wrapped}')
    ass.write_text(header+'\n'.join(events)+'\n', encoding='utf-8')
    return ass

def caption_video(source, name, entries):
    ass = captions(name, entries)
    video = OUT / (name + '.mp4')
    relative = ass.relative_to(ROOT).as_posix()
    run(['-i',str(source),'-vf',f'pad=1280:800:0:0:black,ass={relative}',
         '-c:v','libx264','-preset','fast','-crf','20','-threads','4','-pix_fmt','yuv420p',
         '-c:a','aac','-b:a','128k','-ar','48000','-ac','2','-movflags','+faststart',str(video)],name+'-encode.log')
    run(['-v','error','-i',str(video),'-f','null','NUL'],name+'-decode-check.log')
    length = duration(video)
    if any(start<0 or end<=start or end>length+.05 for start,end,_ in entries):
        raise RuntimeError('Subtitle timestamps outside video: '+name)
    print(f'VIDEO PASS: {name} / {length:.2f}s / {video.stat().st_size} bytes',flush=True)
    return {'file':video.name,'duration_seconds':length,'bytes':video.stat().st_size,'sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'subtitles':name+'.srt','dimensions':'1280x800 (720p game footage plus subtitle band)'}

def compose(name, segments):
    paths = []
    entries = []
    clock = 0.0
    for i,(source,start,length,text) in enumerate(segments):
        path = WORK / f'{name}-{i:02}.mp4'
        run(['-ss',str(start),'-i',str(RAW / source),'-t',str(length),'-vf','fps=30,setsar=1',
             '-c:v','libx264','-preset','fast','-crf','20','-threads','3','-pix_fmt','yuv420p',
             '-c:a','aac','-b:a','128k','-ar','48000','-ac','2',str(path)],f'{name}-{i:02}.log')
        actual = duration(path)
        paths.append(path)
        entries.append((clock,clock+actual,text))
        clock += actual
    listing = WORK / (name+'-concat.txt')
    listing.write_text('\n'.join("file '"+p.as_posix()+"'" for p in paths),encoding='utf-8')
    joined = WORK / (name+'-joined.mp4')
    run(['-f','concat','-safe','0','-i',str(listing),'-c','copy',str(joined)],name+'-join.log')
    return caption_video(joined,name,entries)

def main():
    for directory in (OUT,WORK,SUBTITLES): directory.mkdir(parents=True,exist_ok=True)
    guided_length = duration(RAW / 'guided.avi')
    entries = [
        (0,4,'A complete first mission, captured from the game. Scripted controller inputs; live physics and survival.'),
        (4,12,'No space knowledge is needed. Follow the cyan SCAN marker and the objective at the upper left.'),
        (12,22,'Read the dashboard: AIR is breathing oxygen. TOOL BATTERY powers scans. SUIT is integrity.'),
        (22,33,'WASD moves and the mouse looks. The destination distance decreases as you approach.'),
        (33,43.1,'Air and battery fall outside shelter. In this first mission, construction is optional.'),
        (43.1,46.13,'Hold E near the target for three seconds. A completed scan consumes 8 battery.'),
        (46.13,51.13,'The light scanner records a rock observation. A clue supports investigation; it is not proof of life.'),
        (51.13,55.13,'The learning screen explains the interpretation, then points you toward the next observation.'),
        (55.13,70,'The second target uses a drill. Different instruments reveal different kinds of evidence.'),
        (70,84,'NASA MOLA supplies regional elevation context. Local rocks, routes and discoveries are game scenarios.'),
        (84,97.2,'Watch the remaining air and tool battery while you travel. Return to shelter if reserves are low.'),
        (97.2,100.23,'Hold E again. Two distinct observations are required before the first return.'),
        (100.23,105.23,'This time the scripted player tries the overclaim. The game explains why it is not supported.'),
        (105.23,109.23,'A mistaken scientific explanation is a learning moment in practice, not a campaign penalty.'),
        (109.23,124,'With both observations collected, follow HOME back to the white crew shelter.'),
        (124,139,'The shelter restores breathing air and battery during active field play. Menus pause the simulation.'),
        (139,153.26,'Approach the main habitat and press E. The return action unlocks when you have both observations.'),
        (153.26,158.26,'Choose RETURN TO EARTH. Practice progress is separate from campaign funds and checkpoints.'),
        (158.26,163.26,'Ascent is committed. The rendered spacecraft and camera show the crew leaving the surface.'),
        (163.26,guided_length,'Debrief: two observations and a safe return. Continue into the Earth lab to design your own campaign.')]
    results = [caption_video(RAW/'guided.avi','First-Mission-Walkthrough',entries)]
    demo = [
        ('lab-arrival.avi',0,6,'MOHASHUNNYO: A LONG WAY HOME. Design a mission, read the planet, bring the crew home.'),
        ('lab-bay.avi',1,6,'Begin in the 3D Earth lab. Prepare equipment, balance resources and integrate the vehicle.'),
        ('lab-crew.avi',0,5,'Choose your commander. The lab, crew, spacecraft and consoles are actual game scenes.'),
        ('lab-control.avi',0,6,'The Flight Lab teaches engineering decisions. NASA data and game assumptions are identified separately.'),
        ('lab-ascent.avi',0,8,'Go for launch. A real in-engine ignition and ascent carries the mission toward Mars.'),
        ('adventure.avi',3,10,'Fly terminal descent, or use assisted landing. This clip shows the actual assisted flight model.'),
        ('adventure.avi',19,8,'Cancel speed and drift, then confirm touchdown. Landing quality affects mission resources and science.'),
        ('guided.avi',32,8,'Follow visible objectives and collect observations. The live first-mission route remains beginner-friendly.'),
        ('guided.avi',43.1,3,'Hold E to scan. Instruments cost electricity, so choices have resource consequences.'),
        ('adventure.avi',33.6,5,'Optional thruster demonstration: Ctrl+Space spends a finite charge while Mars gravity stays unchanged.'),
        ('adventure.avi',38.6,8,'Controlled hazard showcase: red rings warn of fictional impacts. Move clear or reach shelter.'),
        ('adventure.avi',53.63,8,'Staged outpost showcase: deployable power, oxygen, shelter, industry and research extend exploration.'),
        ('guided.avi',158.26,5,'Bring the evidence home. Real game footage, edited for this showcase; no generated imagery or voice.')]
    results.append(compose('Game-Demo',demo))
    controls = [
        ('guided.avi',4,10,'TOP LEFT: your next action and destination. Follow the cyan marker; its distance tells you where to go.'),
        ('guided.avi',16,10,'TOP RIGHT: breathing AIR, TOOL BATTERY and SUIT integrity. Falling reserves mean it is time to recover.'),
        ('guided.avi',40.1,6,'SCAN: get close and hold E until the progress bar fills. Each observation consumes tool battery.'),
        ('guided.avi',46.13,8,'LEARNING CARDS: read what the tool observed, try an explanation and review the feedback.'),
        ('adventure.avi',0,6,'LANDING CONTROLS: Space brakes, WASD steers, Enter toggles autopilot and Escape pauses.'),
        ('adventure.avi',27.6,6,'CAMPAIGN: meet the science quota, collect two observations and survey two districts before returning.'),
        ('adventure.avi',33.6,5,'THRUSTER: Ctrl+Space in the air spends charge. Standing on the ground recharges this game mechanic.'),
        ('adventure.avi',38.6,6,'HAZARDS: red impact rings are a warning. These are controlled adventure scenarios, not NASA forecasts.'),
        ('guided.avi',124,9,'RECOVERY: stand near the main white shelter to refill air and battery. F1 explains unfamiliar terms.'),
        ('guided.avi',153.26,8,'RETURN: press E at the habitat, choose Return to Earth, then review what your decisions achieved.'),
        ('guided.avi',163.26,5,'START SIMPLE: play guided practice first. Use the Earth lab for the complete mission-design campaign.')]
    results.append(compose('Controls-and-Dashboard',controls))
    manifest = {'source':'Godot Movie Maker captures of this repository; no generated visuals or voice',
                'disclosure':'Scripted controller inputs for the complete beginner route; edited cinematic shots and controlled/staged adventure scenarios in the short demo.',
                'videos':results}
    (OUT/'media-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    shutil.copy2(OUT/'media-manifest.json',SUBTITLES/'media-manifest.json')
    for name,at in [('Game-Demo',3),('First-Mission-Walkthrough',48),('Controls-and-Dashboard',14)]:
        run(['-ss',str(at),'-i',str(OUT/(name+'.mp4')),'-frames:v','1','-q:v','2',str(SUBTITLES/(name+'.jpg'))],name+'-thumbnail.log')
    print('ALL MEDIA: PASS / decoded videos, timed captions, source disclosure, thumbnails',flush=True)

if __name__=='__main__': main()
