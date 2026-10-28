class_name MatchSetup
extends RefCounted

## What comes before a single-player match: the deck the player picked, the
## AI's level and its deck of 5 rules drawn at random. With the player's chosen
## true rule, start() draws the AI's true rule and creates the match, whose
## coin toss picks the first player. The setup keeps both decks and the level,
## so rematch() starts the next match from them, with the other player going
## first. Every random choice uses the injected rng.

const PLAYER: int = 0
const AI: int = 1

var _decks: Array[Deck] = []
var _ai_level: AILevel.Level
var _rng: RandomNumberGenerator
var _last_first_player: int = Players.NONE


func _init(decks: Array[Deck], level: AILevel.Level, rng: RandomNumberGenerator) -> void:
	_decks = decks.duplicate()
	_ai_level = level
	_rng = rng


## The player gets the deck they picked, the AI its deck (drawn with Deck.draw
## before the setup, so the player sees it while choosing a true rule) and
## plays at the level picked. Returns null (and reports an error) for a level
## not built yet.
static func against_ai(player_deck: Deck, ai_deck: Deck, level: AILevel.Level, rng: RandomNumberGenerator) -> MatchSetup:
	if not AILevel.is_built(level):
		push_error("MatchSetup: the AI level %s is not built yet" % AILevel.title(level))
		return null
	var decks: Array[Deck] = []
	decks.resize(Players.COUNT)
	decks[PLAYER] = player_deck.copy()
	decks[AI] = ai_deck.copy()
	return MatchSetup.new(decks, level, rng)


## A copy of a player's deck.
func deck(player: int) -> Deck:
	return _decks[player].copy()


func ai_level() -> AILevel.Level:
	return _ai_level


## Starts a match with the player's chosen true rule and a random true rule
## from the AI's deck. Returns null (and reports an error) if the chosen rule
## is not in the player's deck.
func start(player_true_rule: Rule) -> Match:
	return _start(player_true_rule, Players.NONE)


## Starts the next match on the same decks: the player's chosen true rule, a
## new random true rule from the AI's deck, and whoever went second last time
## goes first. Returns null (and reports an error) before any match started.
func rematch(player_true_rule: Rule) -> Match:
	if not Players.is_valid(_last_first_player):
		push_error("MatchSetup.rematch: no match was started yet")
		return null
	return _start(player_true_rule, Players.opponent(_last_first_player))


func _start(player_true_rule: Rule, first_player: int) -> Match:
	var true_rules: Array[Rule] = []
	true_rules.resize(Players.COUNT)
	true_rules[PLAYER] = player_true_rule
	true_rules[AI] = _decks[AI].random_rule(_rng)
	var current_match: Match = Match.create(_decks, true_rules, _rng, first_player)
	if current_match != null:
		_last_first_player = current_match.first_player()
	return current_match
