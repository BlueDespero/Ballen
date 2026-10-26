class_name MatchEndOverlay
extends Control

## The match-end screen over the board: the result for the player, how the
## match ended, both true rules revealed, and the way out. It dims the whole
## layout but sits below the rules panel in the tree, so the panel stays lit.
## Rematch (#56) goes in the Buttons row.

## The player pressed Main menu.
signal main_menu_requested

const FADE_SECONDS: float = 0.3
const WIN_COLOUR: Color = Color(1.0, 0.82, 0.3)
const LOSS_COLOUR: Color = Color(0.93, 0.4, 0.4)
const DRAW_COLOUR: Color = Color(0.65, 0.78, 0.95)

@onready var _headline: Label = %Headline
@onready var _reason: Label = %Reason
@onready var _ai_rule_id: Label = %AIRuleId
@onready var _ai_rule_text: Label = %AIRuleText
@onready var _player_rule_id: Label = %PlayerRuleId
@onready var _player_rule_text: Label = %PlayerRuleText
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	visible = false
	_main_menu_button.pressed.connect(main_menu_requested.emit)


## Fills the screen from the player's summary and fades it in the first time.
func show_summary(summary: MatchEndSummary) -> void:
	_headline.text = summary.headline
	_headline.add_theme_color_override("font_color", _outcome_colour(summary.outcome))
	_reason.text = summary.reason
	_ai_rule_id.text = summary.opponent_true_rule.id
	_ai_rule_text.text = summary.opponent_true_rule.text
	_player_rule_id.text = summary.own_true_rule.id
	_player_rule_text.text = summary.own_true_rule.text
	if visible:
		return
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)


func _outcome_colour(outcome: MatchEndSummary.Outcome) -> Color:
	match outcome:
		MatchEndSummary.Outcome.WIN:
			return WIN_COLOUR
		MatchEndSummary.Outcome.LOSS:
			return LOSS_COLOUR
	return DRAW_COLOUR
