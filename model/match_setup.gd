class_name MatchSetup
extends RefCounted

## What comes before a single-player match: the player's fixed starter deck
## and the AI's deck of 5 rules drawn at random. Both decks are known before
## the player chooses a true rule; start() then draws the AI's true rule and
## creates the match, whose coin toss picks the first player. Every random
## choice uses the injected rng.

const PLAYER: int = 0
const AI: int = 1

## The prototype's fixed deck for the player.
const STARTER_DECK_IDS: Array[String] = ["R01", "R03", "R05", "R08", "R18"]

var _decks: Array[Deck] = []
var _rng: RandomNumberGenerator


func _init(decks: Array[Deck], rng: RandomNumberGenerator) -> void:
	_decks = decks.duplicate()
	_rng = rng


## The player gets the starter deck, the AI a random deck from the book's rules.
static func against_ai(book: RuleBook, rng: RandomNumberGenerator) -> MatchSetup:
	var starter: Array[Rule] = []
	for rule_id: String in STARTER_DECK_IDS:
		starter.append(book.rule(rule_id))
	var decks: Array[Deck] = []
	decks.resize(Players.COUNT)
	decks[PLAYER] = Deck.new(starter)
	decks[AI] = Deck.draw(book, rng)
	return MatchSetup.new(decks, rng)


## A copy of a player's deck.
func deck(player: int) -> Deck:
	return _decks[player].copy()


## Starts a match with the player's chosen true rule and a random true rule
## from the AI's deck. Returns null (and reports an error) if the chosen rule
## is not in the player's deck.
func start(player_true_rule: Rule) -> Match:
	var true_rules: Array[Rule] = []
	true_rules.resize(Players.COUNT)
	true_rules[PLAYER] = player_true_rule
	true_rules[AI] = _decks[AI].rules[_rng.randi_range(0, Deck.SIZE - 1)]
	return Match.create(_decks, true_rules, _rng)
