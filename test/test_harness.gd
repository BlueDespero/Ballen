extends GutTest

# Harness check: proves GUT runs and the engine is the 4.7 the project targets.


func test_runs_on_godot_4_7() -> void:
	var version: Dictionary = Engine.get_version_info()
	assert_eq(version.major, 4)
	assert_eq(version.minor, 7)
