from pathlib import Path
import json
p=Path('game/assets/OUTPOST_CATALOG.json');d=json.loads(p.read_text(encoding='utf-8'))
for item in d['items']:
 if item.get('family')=='ropebridge':item['portable']=True
p.write_text(json.dumps(d,indent=2),encoding='utf-8')
p=Path('game/scripts/expedition_map.gd');s=p.read_text(encoding='utf-8').replace('if p.distance_to(pos)<90 or','if p.distance_to(pos)<(180 if expedition.field.owned("lidar") else 90) or');needle='\tdraw_circle(centre,4,Color.WHITE)';s=s.replace(needle,'\tif is_instance_valid(expedition.field) and expedition.field.owned("navigation"):\n\t\tvar previous := Vector2.INF\n\t\tfor at: Array in expedition.field.route:\n\t\t\tvar p := Vector2(float(at[0])-pos.x,float(at[2])-pos.z)\n\t\t\tif p.length()>350: previous = Vector2.INF; continue\n\t\t\tvar here := centre+p*scale_factor\n\t\t\tif previous!=Vector2.INF: draw_line(previous,here,Color("7f9db3"),1.2)\n\t\t\tprevious = here\n'+needle);p.write_text(s,encoding='utf-8')
p=Path('tools/Verify.ps1');s=p.read_text(encoding='utf-8').replace("powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Verify-LAN.ps1')","Invoke-GameCheck 'campaign-check' @('--headless','--fixed-fps','60','--path',$gamePath,'--quit-after','20000','--','--campaign-test') 'CAMPAIGN INTEGRATION: PASS'\npowershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Verify-LAN.ps1')");p.write_text(s,encoding='utf-8')
