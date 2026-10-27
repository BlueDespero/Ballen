extends GutTest

# The note mark the player cycles on one of the AI's rules: each tap moves it
# none -> ruled out -> suspect -> none.


func test_a_tap_on_an_unmarked_rule_rules_it_out() -> void:
	assert_eq(NoteMark.next(NoteMark.Mark.NONE), NoteMark.Mark.RULED_OUT)


func test_a_tap_on_a_ruled_out_rule_makes_it_a_suspect() -> void:
	assert_eq(NoteMark.next(NoteMark.Mark.RULED_OUT), NoteMark.Mark.SUSPECT)


func test_a_tap_on_a_suspect_clears_its_mark() -> void:
	assert_eq(NoteMark.next(NoteMark.Mark.SUSPECT), NoteMark.Mark.NONE)
