"""Fetch real MEDA sol 20 calibrated pressure/air-temperature products and labels."""
from pathlib import Path
import csv, hashlib, json, urllib.request, concurrent.futures
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'game/assets/meda'; DEST.mkdir(exist_ok=True)
RAW=ROOT/'data/nasa/meda'; RAW.mkdir(parents=True,exist_ok=True)
BASE='https://atmos.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/data_calibrated_env/sol_0000_0089/sol_0020/'
WIND_BASE='https://atmos.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/data_derived_env/sol_0000_0089/sol_0036/'
WIND_NAME='WE__0036___________DER_WS__________________P02'
NAMES=['WE__0020___________CAL_ATS_________________P01','WE__0020___________CAL_PS__________________P02']
def fetch(name):
    p=(RAW if name.endswith('.CSV') else DEST)/name
    if name.endswith('.CSV') and (DEST/name).exists() and not p.exists(): (DEST/name).replace(p)
    if not p.exists(): p.write_bytes(urllib.request.urlopen((WIND_BASE if name.startswith('WE__0036') else BASE)+name,timeout=120).read())
    return name,p.stat().st_size
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    print(list(pool.map(fetch,[n+e for n in NAMES+[WIND_NAME] for e in ['.CSV','.xml']])))
print('WIND:',(RAW/(WIND_NAME+'.CSV')).read_text().splitlines()[:3])
for n in NAMES:
    p=RAW/(n+'.CSV')
    print(n,p.read_text().splitlines()[:3])
from collections import defaultdict
from statistics import median
bins=defaultdict(lambda:{'temperatureK':[],'pressurePa':[]})
for n,key,column,limits in [(NAMES[0],'temperatureK','ATS_LOCAL_TEMP1',(100,350)),(NAMES[1],'pressurePa','BAROCAP1_PRESSURE',(400,1000))]:
    for r in csv.DictReader((RAW/(n+'.CSV')).open()):
        try:
            clock=r['LMST'].split('M')[1]; h,m,s=map(float,clock.split(':')); slot=int((h*3600+m*60+s)/900)
            value=float(r[column])
            if limits[0]<value<limits[1]: bins[slot][key].append(value)
        except (ValueError,KeyError,IndexError): continue
profile=[]
for slot,d in sorted(bins.items()):
    if not d['temperatureK'] or not d['pressurePa']: continue
    profile.append({'lmstHour':slot/4,'temperatureK':round(median(d['temperatureK']),2),'pressurePa':round(median(d['pressurePa']),2),'temperatureSamples':len(d['temperatureK']),'pressureSamples':len(d['pressurePa'])})
wind=[]; rejected_wind=0; wind_rows=0; missing_boom_flag=0; uncertainty_count=0
for r in csv.DictReader((RAW/(WIND_NAME+'.CSV')).open()):
    wind_rows+=1
    if not r.get('BOTH_BOOMS_USED_FOR_RETRIEVAL'): missing_boom_flag+=1
    if r.get('HORIZONTAL_WIND_SPEED_UNCERTAINTY'): uncertainty_count+=1
    try:
        speed=float(r['HORIZONTAL_WIND_SPEED'])
        if r.get('ROVER_STILL')=='1' and 0<=speed<60: wind.append(speed)
        else: rejected_wind+=1
    except (ValueError,KeyError): rejected_wind+=1
wind.sort()
wind_summary={'sol':36,'source':WIND_BASE,'product':WIND_NAME,'sha256':hashlib.sha256((RAW/(WIND_NAME+'.CSV')).read_bytes()).hexdigest(),'totalRows':wind_rows,'acceptedStationaryRows':len(wind),'rejectedRows':rejected_wind,'missingBoomFlagRows':missing_boom_flag,'reportedUncertaintyRows':uncertainty_count,'quantilesMps':{str(q):wind[round(q*(len(wind)-1))] for q in [.1,.2,.5,.75,.9,.95,.99]},'minMps':wind[0],'maxMps':wind[-1],'limits':'Stationary rover only; 999999999 sentinel rejected. Both-booms flag is missing; do not assume a validated dual-boom solution. Quantiles from sol 36 are scenario magnitudes, not contemporaneous with sol 20 pressure/temperature or a storm diagnosis.'}
data={'version':2,'mission':'Mars 2020 / MEDA','sol':20,'source':BASE,'products':[{ 'id':n,'csvSha256':hashlib.sha256((RAW/(n+'.CSV')).read_bytes()).hexdigest()} for n in NAMES], 'windAnalog':wind_summary,
      'profile':profile,'limitations':'15-minute medians of ATS local sensor 1 temperature and Barocap 1 pressure. Duty-cycle gaps excluded. Sensor local temperature is not a corrected global air-temperature climatology. One Jezero sol cannot determine weather across generated districts. Wind, haze, frost and storm states are seeded physically motivated scenarios, not inferred observed events or live forecasts.'}
(DEST/'weather_profile.json').write_text(json.dumps(data,indent=2))
print('Weather bins',len(profile),'temperature',min(p['temperatureK'] for p in profile),max(p['temperatureK'] for p in profile),'pressure',min(p['pressurePa'] for p in profile),max(p['pressurePa'] for p in profile))
print('Wind:',wind_summary)
# Godot's default CSV importer treats columns as translations. Keep scientific
# source tables outside res:// and quarantine only auto-generated import outputs.
cache=ROOT/'tools/godot/cache/meda_imports'; cache.mkdir(parents=True,exist_ok=True)
for pattern in ['*.translation','*.CSV.import']:
    for p in DEST.glob(pattern): p.replace(cache/p.name)
