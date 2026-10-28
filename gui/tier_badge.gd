class_name TierBadge
extends RefCounted

## How a rule's tier looks: Simple green, Intermediate amber, Hardcore red,
## as a labelled badge or a small dot.

const SIMPLE_COLOUR: Color = Color(0.4, 0.78, 0.45)
const INTERMEDIATE_COLOUR: Color = Color(0.96, 0.7, 0.26)
const HARDCORE_COLOUR: Color = Color(0.92, 0.36, 0.32)
const NO_TIER_COLOUR: Color = Color(0.6, 0.64, 0.7)
const DOT_SIZE: float = 12.0
const BADGE_WIDTH: float = 112.0


static func colour(tier: String) -> Color:
	match tier:
		Rule.TIER_SIMPLE:
			return SIMPLE_COLOUR
		Rule.TIER_INTERMEDIATE:
			return INTERMEDIATE_COLOUR
		Rule.TIER_HARDCORE:
			return HARDCORE_COLOUR
	return NO_TIER_COLOUR


## "Simple", "Intermediate" or "Hardcore".
static func title(tier: String) -> String:
	return tier.capitalize()


## The tier's name on a dark pill edged in its colour.
static func badge(tier: String) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.name = "Tier"
	pill.custom_minimum_size.x = BADGE_WIDTH
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour(tier).darkened(0.75)
	style.border_color = colour(tier)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = title(tier)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", colour(tier))
	label.add_theme_font_size_override("font_size", 14)
	pill.add_child(label)
	return pill


## A small dot in the tier's colour.
static func dot(tier: String) -> Panel:
	var circle: Panel = Panel.new()
	circle.custom_minimum_size = Vector2.ONE * DOT_SIZE
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour(tier)
	style.set_corner_radius_all(int(DOT_SIZE / 2.0))
	circle.add_theme_stylebox_override("panel", style)
	return circle
