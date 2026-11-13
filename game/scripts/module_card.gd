extends PanelContainer
## Native Control drag payload; assembly drop targets validate it.
var module_id: String = ""
var display_name: String = ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = "  + " + display_name + "  "
	preview.add_theme_font_size_override("font_size", 23)
	preview.modulate = Color("73eadf")
	set_drag_preview(preview)
	return {"module": module_id, "title": display_name}
