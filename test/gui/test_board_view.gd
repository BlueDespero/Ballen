extends GutTest

# A tap on a board cell (pressed and released on the same cell) reports that
# cell, so the scene can place the player's ball there without a drag.

var _board: BoardView


func before_each() -> void:
	_board = BoardView.new()
	add_child_autofree(_board)
	_board.position = Vector2(200, 120)
	watch_signals(_board)


func _cell_point(cell: Vector2i) -> Vector2:
	return _board.cell_centre(cell)


func _send(pressed: bool, at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = at
	_board._gui_input(event)


func test_a_tap_on_a_cell_reports_it() -> void:
	_send(true, _cell_point(Vector2i(2, 3)))
	_send(false, _cell_point(Vector2i(2, 3)))
	assert_signal_emitted_with_parameters(_board, "cell_pressed", [Vector2i(2, 3)])


func test_sliding_to_another_cell_before_letting_go_cancels() -> void:
	_send(true, _cell_point(Vector2i(2, 3)))
	_send(false, _cell_point(Vector2i(4, 3)))
	assert_signal_not_emitted(_board, "cell_pressed")


func test_a_release_without_a_press_on_the_board_does_nothing() -> void:
	_send(false, _cell_point(Vector2i(1, 1)))
	assert_signal_not_emitted(_board, "cell_pressed")
