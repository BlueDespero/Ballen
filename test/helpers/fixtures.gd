extends RefCounted

## Shared test helpers. Not a test script (no test_ prefix); preload it:
##     const Fixtures := preload("res://test/helpers/fixtures.gd")

## A template whose rules allow every empty cell.
const ANYWHERE_TEMPLATE: Dictionary = {"blanks": {}, "tree": {"part": "all", "of": []}}


## The built-in rules plus the "anywhere" template for permissive test rules.
static func book() -> RuleBook:
	var rule_book: RuleBook = RuleBook.load_default()
	rule_book.add_template("anywhere", ANYWHERE_TEMPLATE)
	return rule_book


## A permissive rule defined as data.
static func anywhere(rule_book: RuleBook, id: String) -> Rule:
	return rule_book.make_rule({"id": id, "text": "Anywhere (%s)" % id, "template": "anywhere", "values": {}})


## A deck of 5: the given rule first, then permissive fillers named <prefix>1..4.
static func deck_with(rule_book: RuleBook, first: Rule, prefix: String) -> Deck:
	var rules: Array[Rule] = [first]
	for i: int in range(1, Deck.SIZE):
		rules.append(anywhere(rule_book, "%s%d" % [prefix, i]))
	return Deck.new(rules)


static func rng(seed_value: int) -> RandomNumberGenerator:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


## The one empty cell of nearly_full_match's board.
const LAST_EMPTY_CELL: Vector2i = Vector2i(5, 5)


## A match one placement from a full board: 35 balls, LAST_EMPTY_CELL empty,
## player 0 went first and is to place red. Permissive true rules "AT"
## (player 0) and "BT" (player 1) head decks filled with A1..A4 / B1..B4.
static func nearly_full_match(rule_book: RuleBook) -> Match:
	var position: MatchPosition = MatchPosition.from_board(Board.parse([
		"YbRgYb",
		"RgYbRg",
		"YbRgYb",
		"RgYbRg",
		"YbRgYb",
		"RgYbR.",
	]), 0)
	position.turn = 35
	position.colour = BallColour.RED
	var true_rules: Array[Rule] = [anywhere(rule_book, "AT"), anywhere(rule_book, "BT")]
	var decks: Array[Deck] = [deck_with(rule_book, true_rules[0], "A"), deck_with(rule_book, true_rules[1], "B")]
	return Match.from_position(position, decks, true_rules, rng(1))


## A new match whose true rules are the first rule of each deck.
static func new_match(rule_book: RuleBook, true_rule_0: Rule, true_rule_1: Rule, seed_value: int) -> Match:
	var decks: Array[Deck] = [deck_with(rule_book, true_rule_0, "A"), deck_with(rule_book, true_rule_1, "B")]
	var true_rules: Array[Rule] = [true_rule_0, true_rule_1]
	return Match.create(decks, true_rules, rng(seed_value))
