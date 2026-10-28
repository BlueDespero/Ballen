extends CanvasLayer

## The rotate hint (autoload `RotateHint`): the game plays in landscape, so
## while the visible rect is taller than it is wide (a phone held upright) a
## card covers the whole screen asking the player to turn the device, and the
## game takes no input until they do. Its text follows Larger text.
##
## Web builds print `[ballen] rotate_hint=shown` / `=hidden` to the console
## when it appears or goes (and once at start), for the browser tests.

## Above every scene and overlay.
const LAYER: int = 100
const BACKDROP_COLOUR: Color = Color(0.07, 0.08, 0.1)
## The visible rect is always 1280 wide upright (the base width), so the text
## is sized for a phone's narrow screen.
const TITLE_FONT_SIZE: int = 96
const LINE_FONT_SIZE: int = 56
const TITLE: String = "Rotate your device"
const LINE: String = "Ballen plays in landscape."
const MARKER_PREFIX: String = "[ballen] rotate_hint="

var _shown: Variant = null


## Whether the hint covers a screen of this visible size: only when it is
## taller than it is wide.
static func should_show(screen_size: Vector2) -> bool:
	return screen_size.y > screen_size.x


func _init() -> void:
	layer = LAYER
	visible = false
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOUR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Swallows taps and clicks on whatever is under it.
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(centre)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.add_theme_constant_override("separation", 24)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(lines)
	lines.add_child(_label("Title", TITLE, TITLE_FONT_SIZE, Color.WHITE))
	lines.add_child(_label("Line", LINE, LINE_FONT_SIZE, Palette.HINT_COLOUR))


func _ready() -> void:
	get_viewport().size_changed.connect(_on_size_changed)
	Settings.changed.connect(_apply_text_scale)
	_apply_text_scale()
	_on_size_changed()


## Shows or hides the hint for a screen of this visible size, and turns the
## game's input off while it shows.
func fit(screen_size: Vector2) -> void:
	var shows: bool = should_show(screen_size)
	visible = shows
	if _shown != null and _shown == shows:
		return
	var first: bool = _shown == null
	_shown = shows
	if not (first and not shows):
		get_viewport().set_disable_input(shows)
	if OS.has_feature("web"):
		print(MARKER_PREFIX + ("shown" if shows else "hidden"))


func _on_size_changed() -> void:
	fit(get_viewport().get_visible_rect().size)


func _apply_text_scale() -> void:
	TextScale.apply(self, Settings.text_scale())


func _label(node_name: String, text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Palette.label(text, colour, font_size)
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
