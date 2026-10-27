extends GutTest

# The note mark the player cycles on one of the AI's rules: each tap moves it
# none -> ✗ -> ? -> none.


func test_a_tap_on_an_unmarked_rule_gives_it_a_cross() -> void:
	assert_eq(NoteMark.next(NoteMark.Mark.NONE), NoteMark.Mark.CROSS)


func test_a_tap_on_a_cross_turns_it_into_a_question_mark() -> void:
	assert_eq(NoteMark.next(NoteMark.Mark.CROSS), NoteMark.Mark.QUESTION)


func test_a_tap_on_a_question_mark_clears_the_mark() -> void:
	assert_eq(NoteMark.next(NoteMark.Mark.QUESTION), NoteMark.Mark.NONE)
