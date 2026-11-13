extends RefCounted
## Shared purchasing UI embedded in the expedition planning and Earth consoles.
const Cargo = preload("res://scripts/outpost_cargo.gd")
const Art = preload("res://scripts/field_hardware.gd")

func show_shop(game: Node,category := "Power",selection := "solar",search := "") -> void:
	var earth := game.has_method("new_overlay")
	var stock: Cargo = Cargo.new()
	stock.read_draft()
	var campaign: RefCounted = preload("res://scripts/campaign.gd").new()
	if earth: campaign.read()
	else: campaign = game.campaign
	var content: VBoxContainer = game.new_overlay() if earth else game.menu(1120)
	var make_label := func(value: String,size := 18,color := Color("c3d5d8")) -> Label:
		var l := Label.new(); l.text = value; l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",color); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return l
	var make_button := func(value: String,callback: Callable) -> Button:
		return game.button(value,callback) if earth else game.action(value,callback)
	content.add_child(make_label.call("MISSION CONTROL / ROCKET & EXPEDITION PROCUREMENT",28,Color("8de0d4")))
	content.add_child(make_label.call("%d credits • %.1f / 260 kg cargo • purchases become deployable kits on Mars" % [stock.credits,stock.mass()],19,Color("eec393")))
	var search_row := LineEdit.new(); search_row.placeholder_text = "Search equipment name / variant; press Enter"; search_row.text = search; search_row.custom_minimum_size.y = 38; content.add_child(search_row); search_row.text_submitted.connect(func(value: String) -> void: show_shop(game,category,selection,value))
	var tabs := HFlowContainer.new(); content.add_child(tabs)
	for name: String in ["Launch","Power","Survival","Industry","Science","Exploration","Construction","Traversal","Safety","Gear"]:
		tabs.add_child(make_button.call(name,func() -> void: show_shop(game,name,first_in_category(name),search)))
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation",18); content.add_child(columns)
	var list_scroll := ScrollContainer.new(); list_scroll.custom_minimum_size = Vector2(420,300); columns.add_child(list_scroll)
	var left := VBoxContainer.new(); left.custom_minimum_size.x = 400; list_scroll.add_child(left)
	for id: String in Cargo.catalog():
		var item: Dictionary = Cargo.catalog()[id]
		if item.category != category or (search!="" and not (str(item.name)+str(item.description)).to_lower().contains(search.to_lower())): continue
		left.add_child(make_button.call("%s\n%d cr • %d kg • Packed %d" % [item.name,item.cost,item.mass,stock.kits.get(id,0)],func() -> void: show_shop(game,category,id,search)))
	var right := VBoxContainer.new(); right.custom_minimum_size.x = 500; columns.add_child(right)
	var viewport := SubViewport.new(); viewport.size = Vector2i(560,310); viewport.own_world_3d = true; viewport.transparent_bg = false
	var viewer := SubViewportContainer.new(); viewer.custom_minimum_size = Vector2(500,277); viewer.stretch = true; viewer.add_child(viewport); right.add_child(viewer)
	var asset: Node3D = Art.new().make(selection); viewport.add_child(asset); asset.rotation.y = -.5
	var environment := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("0d1922"); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("a0c3d4"); env.ambient_light_energy = .65; environment.environment = env; viewport.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-40,-35,0); light.light_energy = 1.6; viewport.add_child(light)
	var rim := OmniLight3D.new(); rim.position = Vector3(-3,2,1); rim.light_color = Color("4cd5cb"); rim.omni_range = 9; rim.light_energy = 2; viewport.add_child(rim)
	var camera := Camera3D.new(); viewport.add_child(camera); camera.fov = 44; camera.near = .03
	var bounds: AABB = asset.get_node("Shell").transform*asset.get_node("Shell").mesh.get_aabb()
	var extent := maxf(bounds.size.y,maxf(bounds.size.x/1.8,bounds.size.z/1.8))
	var centre := bounds.get_center(); camera.position = centre+Vector3(.65,.35,.8).normalized()*maxf(.7,extent*1.7); camera.look_at(centre)
	var selected: Dictionary = Cargo.catalog()[selection]
	right.add_child(make_label.call(str(selected.description),17))
	right.add_child(make_label.call("Power draw %.1f • output %.1f • assembly: anchor → wire → calibrate" % [selected.draw,selected.output],15,Color("8de0d4")))
	right.add_child(make_button.call("PURCHASE / %d CREDITS" % selected.cost,func() -> void:
		var reason := "An expedition is active; use field fabrication. Return successfully before new procurement." if campaign.status=="ACTIVE" else ("Campaign lost. Start a new campaign." if campaign.status=="FAILED" else stock.buy(selection))
		if reason == "" and not stock.write_draft(): reason = "Could not save procurement; order not committed"
		if earth: game.show_toast("KIT PROCURED" if reason=="" else reason)
		else: game.toast("KIT PROCURED" if reason=="" else reason)
		show_shop(game,category,selection,search)))
	var foot := HFlowContainer.new(); content.add_child(foot)
	foot.add_child(make_button.call("PACK STARTER OUTPOST / 580 cr",func() -> void:
		var reason := "Procurement locked during or after a failed mission" if campaign.status!="PLANNING" else stock.starter()
		if reason == "" and not stock.write_draft(): reason = "Could not save procurement; order not committed"
		if earth: game.show_toast("STARTER OUTPOST PACKED" if reason=="" else reason)
		else: game.toast("STARTER OUTPOST PACKED" if reason=="" else reason)
		show_shop(game,category,selection,search)))
	foot.add_child(make_button.call("ROCKET BASELINE / 1,420 cr",func() -> void:
		var reason := "Procurement locked" if campaign.status!="PLANNING" else stock.rocket_pack()
		if reason=="": stock.write_draft()
		show_shop(game,category,selection,search)))
	foot.add_child(make_button.call("RESET PURCHASES",func() -> void:
		if campaign.status!="PLANNING": return
		var reset := Cargo.new(); reset.credits = campaign.bank; stock.restore(reset.snapshot()); campaign.integrated = false; campaign.integration_step = 0; campaign.write(); stock.write_draft(); show_shop(game,category,selection,search)))
	foot.add_child(make_button.call("RETURN",game.clear_overlay if earth else game.planning))
	content.add_child(make_label.call("Original speculative hardware. Prices, recipes, outputs and compact life-support systems are gameplay models. Build power, oxygen and shelter first; then establish industry and remote science stations.",13))

func first_in_category(category: String) -> String:
	for id: String in Cargo.catalog():
		if Cargo.catalog()[id].category == category: return id
	return "solar"
