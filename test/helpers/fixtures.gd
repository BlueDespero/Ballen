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


## A new match whose true rules are the first rule of each deck.
static func new_match(rule_book: RuleBook, true_rule_0: Rule, true_rule_1: Rule, seed_value: int) -> Match:
	var decks: Array[Deck] = [deck_with(rule_book, true_rule_0, "A"), deck_with(rule_book, true_rule_1, "B")]
	var true_rules: Array[Rule] = [true_rule_0, true_rule_1]
	return Match.create(decks, true_rules, rng(seed_value))
