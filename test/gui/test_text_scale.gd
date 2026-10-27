extends GutTest

# Larger text: TextScale scales every label and button under a node from the
# size it was built with, so applying it again never compounds.


func _label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	return label


func test_text_under_a_node_grows_by_the_scale() -> void:
	var root: Control = autofree(Control.new())
	var title: Label = _label(20)
	var button: Button = Button.new()
	button.add_theme_font_size_override("font_size", 16)
	root.add_child(title)
	title.add_child(button)
	TextScale.apply(root, 1.25)
	assert_eq(title.get_theme_font_size("font_size"), 25)
	assert_eq(button.get_theme_font_size("font_size"), 20, "nested controls too")


func test_applying_again_does_not_compound_and_one_restores() -> void:
	var label: Label = autofree(_label(16))
	TextScale.apply(label, 1.25)
	TextScale.apply(label, 1.25)
	assert_eq(label.get_theme_font_size("font_size"), 20)
	TextScale.apply(label, 1.0)
	assert_eq(label.get_theme_font_size("font_size"), 16)


func test_labels_with_label_settings_grow_without_changing_the_shared_settings() -> void:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = 14
	var hint: Label = autofree(Label.new())
	var other: Label = autofree(Label.new())
	hint.label_settings = settings
	other.label_settings = settings
	TextScale.apply(hint, 1.5)
	assert_eq(hint.label_settings.font_size, 21)
	assert_eq(other.label_settings.font_size, 14, "a label not scaled keeps its size")
	TextScale.apply(hint, 1.0)
	assert_eq(hint.label_settings.font_size, 14)
