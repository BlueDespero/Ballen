extends GutTest

# The web tests wait for these console lines, so their text must stay exact.

const Markers := preload("res://gui/web_markers.gd")


func test_scene_line_names_the_scene() -> void:
	assert_eq(Markers.scene_line("Main"), "[ballen] scene=Main")


func test_match_started_line_says_who_goes_first() -> void:
	assert_eq(Markers.match_started_line(true), "[ballen] match_started first=player")
	assert_eq(Markers.match_started_line(false), "[ballen] match_started first=ai")


func test_ball_placed_line_says_who_placed_and_where() -> void:
	assert_eq(Markers.ball_placed_line(true, Vector2i(2, 3)), "[ballen] ball_placed by=player cell=2,3")
	assert_eq(Markers.ball_placed_line(false, Vector2i(0, 5)), "[ballen] ball_placed by=ai cell=0,5")


func test_deck_saved_line_names_the_deck() -> void:
	assert_eq(Markers.deck_saved_line("My deck"), "[ballen] deck_saved name=My deck")


func test_decks_line_lists_the_decks_in_order() -> void:
	var names: Array[String] = ["Starter", "Web deck", "Other"]
	assert_eq(Markers.decks_line(names), "[ballen] decks=Starter,Web deck,Other")


func test_line_with_no_fields_is_prefix_and_event() -> void:
	assert_eq(Markers.line("match_started"), "[ballen] match_started")
