extends GutTest

# Drawing a random deck from the built rules (the AI's deck each new match).

const Fixtures := preload("res://test/helpers/fixtures.gd")

const BUILT_RULE_IDS: Array[String] = ["R01", "R02", "R03","R04", "R05", "R06", "R07", "R08", "R09", "R10", "R15", "R16", "R18", "R19", "R20", "R21", "R22"]

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


func _ids(deck: Deck) -> Array[String]:
	var ids: Array[String] = []
	for rule: Rule in deck.rules:
		ids.append(rule.id)
	return ids


func test_a_drawn_deck_holds_5_distinct_built_rules() -> void:
	for seed_value: int in 20:
		var ids: Array[String] = _ids(Deck.draw(_book, Fixtures.rng(seed_value)))
		assert_eq(ids.size(), Deck.SIZE, "seed %d" % seed_value)
		for rule_id: String in ids:
			assert_true(BUILT_RULE_IDS.has(rule_id), "seed %d drew %s" % [seed_value, rule_id])
			assert_eq(ids.count(rule_id), 1, "seed %d drew %s once" % [seed_value, rule_id])


func test_a_drawn_deck_holds_the_book_s_rule_objects() -> void:
	for rule: Rule in Deck.draw(_book, Fixtures.rng(3)).rules:
		assert_same(rule, _book.rule(rule.id))


func test_the_draw_follows_the_seeded_rng() -> void:
	assert_eq(_ids(Deck.draw(_book, Fixtures.rng(11))), _ids(Deck.draw(_book, Fixtures.rng(11))))


func test_every_built_rule_turns_up_over_20_seeds() -> void:
	var seen: Array[String] = []
	var decks: Array[String] = []
	for seed_value: int in 20:
		var ids: Array[String] = _ids(Deck.draw(_book, Fixtures.rng(seed_value)))
		var key: String = ",".join(ids)
		if not decks.has(key):
			decks.append(key)
		for rule_id: String in ids:
			if not seen.has(rule_id):
				seen.append(rule_id)
	seen.sort()
	assert_eq(seen, BUILT_RULE_IDS)
	assert_gt(decks.size(), 1, "different seeds draw different decks")


func test_a_book_with_too_few_rules_draws_no_deck() -> void:
	var small_book: RuleBook = RuleBook.new()
	assert_null(Deck.draw(small_book, Fixtures.rng(1)))
	assert_push_error("draw")
