extends GutTest

# The ✗ and ? buttons take less room in the rules panel than a finger needs,
# so each one answers taps in a 44 px square around it: ✗ reaches out to its
# left, ? to its right, so the two never share a point.


func _button(mark: NoteMark.Mark) -> NoteMarkButton:
	var button: NoteMarkButton = autofree(NoteMarkButton.new(mark))
	button.size = button.custom_minimum_size
	return button


func test_the_touch_area_is_44_px_square() -> void:
	for mark: NoteMark.Mark in [NoteMark.Mark.CROSS, NoteMark.Mark.QUESTION]:
		var area: Rect2 = _button(mark).touch_rect()
		assert_eq(area.size, Vector2(44, 44), "mark %d" % mark)


func test_the_cross_reaches_out_to_its_left() -> void:
	var button: NoteMarkButton = _button(NoteMark.Mark.CROSS)
	assert_true(button._has_point(Vector2(-7, 18)), "left of the button")
	assert_false(button._has_point(Vector2(button.size.x + 1, 18)), "right of the button")


func test_the_question_reaches_out_to_its_right() -> void:
	var button: NoteMarkButton = _button(NoteMark.Mark.QUESTION)
	assert_true(button._has_point(Vector2(button.size.x + 7, 18)), "right of the button")
	assert_false(button._has_point(Vector2(-1, 18)), "left of the button")


func test_both_reach_above_and_below() -> void:
	var button: NoteMarkButton = _button(NoteMark.Mark.CROSS)
	assert_true(button._has_point(Vector2(18, -3)), "above")
	assert_true(button._has_point(Vector2(18, button.size.y + 3)), "below")
	assert_false(button._has_point(Vector2(18, button.size.y + 5)), "past the 44 px")
