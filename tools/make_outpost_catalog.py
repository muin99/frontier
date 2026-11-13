import json
from pathlib import Path
rows=[
('solar','HELIOS / folding solar sail','Power',60,18,2.6,0,8,1,{'alloy':4,'circuits':2,'polymer':2},'Photovoltaic wings feed nearby connected equipment. Dust reduces output.'),
('battery','VAULT / solid-state buffer','Power',55,24,1.2,0,0,1,{'alloy':3,'circuits':3,'polymer':2},'Stores surplus energy and supplies up to 5 power during deficits.'),
('reactor','EMBER / isotope microgrid','Power',150,48,1.8,0,16,3,{'alloy':12,'circuits':8,'polymer':4},'Reliable concept power source. Tier 3 fabrication; fiction, not certified reactor hardware.'),
('coupler','NEXUS / power coupler','Power',20,5,.6,.1,0,1,{'alloy':2,'circuits':1},'Extends power connections from 20 to 38 metres. Glowing cables show the grid.'),
('oxygen','AERIS / oxygen processor','Survival',65,22,1.2,3,0,1,{'alloy':4,'circuits':2,'polymer':3},'Consumes stored water and power to replenish the outpost oxygen reservoir.'),
('ice','BOREAL / ice extractor','Survival',80,28,1.4,4,0,2,{'alloy':6,'circuits':3,'polymer':2},'Processes recovered raw ice, or extracts beside a surveyed ice deposit in the cold-highland analog. Requires power.'),
('habitat','HAVEN / expedition shelter','Survival',100,55,2.5,2,0,1,{'alloy':8,'circuits':3,'polymer':8},'A powered service zone draws stored oxygen, charges suits and protects against exposure.'),
('greenhouse','VERDANT / growth capsule','Survival',85,30,1.8,3,0,2,{'alloy':4,'circuits':4,'polymer':6},'Consumes water and power to make rations. Glazed ribs protect the crop trays.'),
('fabricator','FORGE / field assembler','Industry',75,30,1.5,4,0,1,{'alloy':6,'circuits':4,'polymer':3},'Build basic kits from gathered materials. Unlocks industry and survey instruments.'),
('refinery','CRUCIBLE / regolith refinery','Industry',70,28,1.5,5,0,2,{'alloy':5,'circuits':3,'polymer':2},'Processes regolith into structural alloy. Conversion is a game abstraction.'),
('cargo','ATLAS / cargo vault','Industry',25,10,1.2,0,0,1,{'alloy':3,'polymer':2},'Adds 100 kg to shared cargo capacity after assembly. Stores the expedition stock.'),
('relay','HORIZON / communications dish','Science',45,12,1.5,1,0,1,{'alloy':3,'circuits':3,'polymer':1},'Links instruments to base within 260m or another linked relay within 360m.'),
('weather','TEMPEST / atmosphere array','Science',40,8,1.1,1,0,1,{'alloy':2,'circuits':3,'polymer':1},'A powered, linked station records one research package per sector.'),
('seismic','ECHO / seismic anchor','Science',45,10,1.1,1.5,0,2,{'alloy':3,'circuits':3,'polymer':1},'Three powered linked anchors at least 20m apart form a seismic research array.'),
('spectrometer','PRISM / mineral laboratory','Science',70,16,1.3,2,0,2,{'alloy':4,'circuits':5,'polymer':2},'Records a geological district package and unlocks tier 3 after three sectors are explored.'),
('observatory','ORION / sky observatory','Science',110,25,1.8,3,0,3,{'alloy':7,'circuits':6,'polymer':3},'Linked observations require clear or high-cloud conditions and open sky.'),
('dronepad','SCOUT / autonomous survey dock','Exploration',95,22,1.8,3,0,2,{'alloy':5,'circuits':5,'polymer':3},'Runs a 45-second local mapping sortie and reveals nearby resource sites.'),
('beacon','WAYFINDER / navigation pylon','Exploration',15,3,.5,0,0,1,{'alloy':1,'circuits':1},'A persistent lit waypoint with a map marker for route planning.'),
('bridge','SPAN / modular walkway','Construction',35,14,3.4,0,0,1,{'alloy':4,'polymer':1},'A six-metre load-bearing deck for crossing shallow hollows; rotate to align it.'),
('ramp','ASCENT / articulated ramp','Construction',30,12,2.8,0,0,1,{'alloy':3,'polymer':1},'An inclined four-metre deck for reaching higher surfaces and assembled walkways.')]
items=[]
for r in rows:
 id,name,category,cost,mass,radius,draw,output,tier,recipe,description=r
 items.append(dict(id=id,name=name,category=category,cost=cost,mass=mass,radius=radius,draw=draw,output=output,tier=tier,recipe=recipe,description=description))
Path('game/assets/OUTPOST_CATALOG.json').write_text(json.dumps({'version':1,'credits':600,'capacityKg':260,'items':items,'note':'Original speculative game equipment. All costs, masses, outputs, recipes, timings and yields are gameplay assumptions, not NASA specifications.'},indent=2))
