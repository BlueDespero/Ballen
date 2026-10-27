extends GutTest

# The note mark the player keeps on one of the AI's rules, with one button per
# mark: pressing an unlit mark sets it (replacing the other), pressing the lit
# one clears it.


func test_pressing_cross_on_an_unmarked_rule_marks_it_ruled_out() -> void:
	assert_eq(NoteMark.toggled(NoteMark.Mark.NONE, NoteMark.Mark.CROSS), NoteMark.Mark.CROSS)


func test_pressing_question_on_an_unmarked_rule_marks_it_suspect() -> void:
	assert_eq(NoteMark.toggled(NoteMark.Mark.NONE, NoteMark.Mark.QUESTION), NoteMark.Mark.QUESTION)


func test_pressing_the_lit_cross_clears_the_mark() -> void:
	assert_eq(NoteMark.toggled(NoteMark.Mark.CROSS, NoteMark.Mark.CROSS), NoteMark.Mark.NONE)


func test_pressing_the_lit_question_clears_the_mark() -> void:
	assert_eq(NoteMark.toggled(NoteMark.Mark.QUESTION, NoteMark.Mark.QUESTION), NoteMark.Mark.NONE)


func test_pressing_question_on_a_cross_switches_to_suspect() -> void:
	assert_eq(NoteMark.toggled(NoteMark.Mark.CROSS, NoteMark.Mark.QUESTION), NoteMark.Mark.QUESTION)


func test_pressing_cross_on_a_question_switches_to_ruled_out() -> void:
	assert_eq(NoteMark.toggled(NoteMark.Mark.QUESTION, NoteMark.Mark.CROSS), NoteMark.Mark.CROSS)


func test_a_tap_on_an_unmarked_rule_gives_it_a_cross() -> void:
	assert_eq(NoteMark.next(NoteMark.Mark.NONE), NoteMark.Mark.CROSS)


func test_a_tap_on_a_cross_turns_it_into_a_question_mark() -> void:
	assert_eq(NoteMark.next(NoteMark.Mark.CROSS), NoteMark.Mark.QUESTION)


func test_a_tap_on_a_question_mark_clears_the_mark() -> void:
	assert_eq(NoteMark.next(NoteMark.Mark.QUESTION), NoteMark.Mark.NONE)
