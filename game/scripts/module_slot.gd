extends PanelContainer
signal installed(module_id: String, title: String)
var caption: Label

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("module") and data.has("title")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	caption.text = "MODULE FITTED\n\n" + str(data.title) + "\n\nDrag another module here to replace"
	installed.emit(str(data.module), str(data.title))
