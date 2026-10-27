class_name TextScale
extends RefCounted

## Larger text: scales the font size of every label and button under a node.
## Each control remembers the size it was built with, so applying a scale
## again (or 1.0 to undo it) never compounds.

const BASE_SIZE_META: StringName = &"text_scale_base_size"


## Sets the text under root (root included) to scale times its built size.
static func apply(root: Node, scale: float) -> void:
	var control: Control = root as Control
	if control is Label or control is Button:
		_scale_control(control, scale)
	for child: Node in root.get_children():
		apply(child, scale)


static func _scale_control(control: Control, scale: float) -> void:
	var label: Label = control as Label
	if label != null and label.label_settings != null:
		_scale_label_settings(label, scale)
		return
	if not control.has_meta(BASE_SIZE_META):
		control.set_meta(BASE_SIZE_META, control.get_theme_font_size("font_size"))
	var base: int = control.get_meta(BASE_SIZE_META)
	control.add_theme_font_size_override("font_size", roundi(base * scale))


## Label settings set the size themselves and are often shared between
## labels, so the label gets its own copy first.
static func _scale_label_settings(label: Label, scale: float) -> void:
	if not label.has_meta(BASE_SIZE_META):
		label.set_meta(BASE_SIZE_META, label.label_settings.font_size)
		label.label_settings = label.label_settings.duplicate()
	var base: int = label.get_meta(BASE_SIZE_META)
	label.label_settings.font_size = roundi(base * scale)
