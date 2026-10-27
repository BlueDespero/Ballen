class_name MatchSetup
extends RefCounted

## What comes before a single-player match: the deck the player picked and
## the AI's deck of 5 rules drawn at random. With the player's chosen true
## rule, start() draws the AI's true rule and
## creates the match, whose coin toss picks the first player. The setup keeps
## both decks, so rematch() starts the next match from them, with the other
## player going first. Every random choice uses the injected rng.

const PLAYER: int = 0
const AI: int = 1

var _decks: Array[Deck] = []
var _rng: RandomNumberGenerator
var _last_first_player: int = Players.NONE


func _init(decks: Array[Deck], rng: RandomNumberGenerator) -> void:
	_decks = decks.duplicate()
	_rng = rng


## The player gets the deck they picked, the AI a random deck from the book's
## rules. Returns null (and reports an error) if the book has too few rules for
## the AI's deck.
static func against_ai(book: RuleBook, player_deck: Deck, rng: RandomNumberGenerator) -> MatchSetup:
	var ai_deck: Deck = Deck.draw(book, rng)
	if ai_deck == null:
		return null
	var decks: Array[Deck] = []
	decks.resize(Players.COUNT)
	decks[PLAYER] = player_deck.copy()
	decks[AI] = ai_deck
	return MatchSetup.new(decks, rng)


## A copy of a player's deck.
func deck(player: int) -> Deck:
	return _decks[player].copy()


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
