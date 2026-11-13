from pathlib import Path
p=Path('game/scripts/outpost_cargo.gd');s=p.read_text(encoding='utf-8').replace('outpost_procurement_v7.json','outpost_procurement_v8.json').replace('var credits := 600','var credits := 3200').replace('get("credits",600)','get("credits",3200)');s += '''
func rocket_pack() -> String:
	var before := snapshot()
	for id: String in catalog():
		if catalog()[id].get("required",false) and int(kits.get(id,0))<1:
			var reason := buy(id)
			if reason!="": restore(before); return reason
	return ""
''';p.write_text(s,encoding='utf-8')
p=Path('game/scripts/outpost_system.gd');s=p.read_text(encoding='utf-8');s=s.replace('func capacity() -> float:', 'func spec(unit: Dictionary) -> Dictionary:\n\treturn catalog().get(str(unit.get("sku",unit.kind)),catalog()[unit.kind])\n\nfunc capacity() -> float:')
s=s.replace('value += 100','value += 100*float(spec(unit).get("capacityFactor",1))')
s=s.replace('if item.category != category: continue','if item.category != category or item.get("portable",false) or item.get("rocket",false): continue')
s=s.replace('"kind":kind,"p":','"kind":catalog()[kind].get("family",kind),"sku":kind,"p":')
s=s.replace('catalog()[unit.kind].radius','spec(unit).radius').replace('catalog()[unit.kind].name','spec(unit).name').replace('catalog()[unit.kind].mass','spec(unit).mass').replace('catalog()[unit.kind].description','spec(unit).description')
s=s.replace('var spec: Dictionary = catalog()[u.kind]','var unit_spec: Dictionary = spec(u)').replace('float(spec.output)','float(unit_spec.output)')
s=s.replace('var draw: float = catalog()[u.kind].draw','var draw: float = spec(u).draw')
s=s.replace('minf(5,float(b.energy)/dt)','minf(5*float(spec(b).get("capacityFactor",1)),float(b.energy)/dt)').replace('5*dt,float(b.energy)','5*float(spec(b).get("capacityFactor",1))*dt,float(b.energy)').replace('100-float(b.energy)','100*float(spec(b).get("capacityFactor",1))-float(b.energy)')
s=s.replace('u.health-dt*.025','u.health-dt*.025/float(spec(u).get("durability",1))')
s=s.replace('u.oxygen+dt*.9','u.oxygen+dt*.9*float(spec(u).get("capacityFactor",1))')
s=s.replace('u.progress += dt; u.state = "RECORDING','u.progress += dt*float(spec(u).get("researchRate",1)); u.state = "RECORDING')
s=s.replace('var reach := 38.0 if u.kind=="coupler" or other.kind=="coupler" else 20.0','var reach := (38.0 if u.kind=="coupler" or other.kind=="coupler" else 20.0)*maxf(float(spec(u).get("reachFactor",1)),float(spec(other).get("reachFactor",1)))')
s=s.replace('cargo.kits[unit.kind] = int(cargo.kits.get(unit.kind,0))+1','var sku: String = str(unit.get("sku",unit.kind))\n\t\t\tcargo.kits[sku] = int(cargo.kits.get(sku,0))+1')
s=s.replace('Art.new().make(unit.kind)','Art.new().make(str(unit.get("sku",unit.kind)))')
s=s.replace('p.y = expedition.stream.surface(p.x,p.z)','p.y = expedition.field.floor_for(p,player_position()) if is_instance_valid(expedition.field) else expedition.stream.surface(p.x,p.z)',1)
s=s.replace('var h: float = expedition.stream.surface(p.x,p.z)','var h: float = expedition.field.floor_for(p,owner_position) if is_instance_valid(expedition.field) else expedition.stream.surface(p.x,p.z)',1)
s=s.replace('absf(expedition.stream.surface(p.x+offset.x,p.z+offset.y)-h)','absf((expedition.field.floor_for(p+Vector3(offset.x,0,offset.y),owner_position) if is_instance_valid(expedition.field) else expedition.stream.surface(p.x+offset.x,p.z+offset.y))-h)')
# Utilities act through the same local power allocation as existing equipment.
s=s.replace('\t\t"fabricator": tier = maxi(tier,2)','''		"scrubber":
			if position_of(u).distance_to(player_position())<8: expedition.field.dust = maxf(0,expedition.field.dust-dt*2)
		"heater":
			if position_of(u).distance_to(player_position())<9: expedition.field.cold = maxf(0,expedition.field.cold-dt*2)
		"shelter","radiometer":
			if position_of(u).distance_to(player_position())<8: expedition.field.exposure = maxf(0,expedition.field.exposure-dt*.4)
		"repair_station":
			if position_of(u).distance_to(player_position())<7 and expedition.model.integrity<95 and int(cargo.materials.alloy)>0:
				u.progress += dt
				if u.progress>=8: u.progress = 0; cargo.materials.alloy -= 1; expedition.model.integrity = minf(100,expedition.model.integrity+12)
		"oxygen_cache":
			if position_of(u).distance_to(player_position())<5 and u.progress<45:
				var amount := minf(dt*2,45-float(u.progress)); u.progress += amount; expedition.model.oxygen = minf(float(expedition.Model.LOADOUTS[expedition.model.loadout].oxygen),expedition.model.oxygen+amount)
		"fabricator": tier = maxi(tier,2)''')
s=s.replace('"weather","spectrometer","observatory","seismic":','"weather","spectrometer","observatory","seismic","survey_lidar","sample_vault":')
p.write_text(s,encoding='utf-8')
p=Path('game/scripts/player.gd');s=p.read_text(encoding='utf-8').replace('var gravity := 9.81','var gravity := 9.81\nvar rope_control := false\nvar rope_velocity := Vector3.ZERO')
s=s.replace('\tupdate_camera_rig()\n\tcamera_boom.spring_length', '\tif rope_control:\n\t\tvelocity = rope_velocity; move_and_slide(); update_camera_rig(); return\n\tupdate_camera_rig()\n\tcamera_boom.spring_length')
s=s.replace('RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED * (1.6 if suited else 1.0)','(3.2 if suited else RUN_SPEED) if Input.is_action_pressed("sprint") else WALK_SPEED * (1.1 if suited else 1.0)')
s=s.replace('var response := ACCELERATION if direction.length_squared() > 0.01 else DECELERATION','var response := (6.0 if suited else ACCELERATION) if direction.length_squared() > 0.01 else (7.0 if suited else DECELERATION)\n\tif suited and not is_on_floor(): response = 1.6 if direction.length_squared()>.01 else .25')
s=s.replace('peak_fall_speed > 6','peak_fall_speed > (4.2 if suited else 6)').replace('position = Vector3(0, 15, 42); velocity = Vector3.ZERO','hard_landing.emit(50); velocity = Vector3.ZERO')
s=s.replace('-0.85, 0.45','-1.35, 1.1');p.write_text(s,encoding='utf-8')
p=Path('game/scripts/expedition_model.gd');s=p.read_text(encoding='utf-8').replace('\n\t\tif storm: integrity = maxf(0,integrity-delta*0.10)','');p.write_text(s,encoding='utf-8')
