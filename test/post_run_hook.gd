extends GutHookScript

# GUT skips a test script that fails to load with only a warning, and the run
# still exits 0. A script fails to load when it, or anything it preloads, has a
# parse error, or when it uses a class_name the import step has not registered.
# This hook turns that into a failed run (exit code 1). Name abstract test
# base classes without the test_ prefix, or they count as broken.

const TEST_DIR: String = "res://test"
const PREFIX: String = "test_"
const SUFFIX: String = ".gd"


func run() -> void:
	var broken: PackedStringArray = []
	for path: String in _find_test_scripts(TEST_DIR):
		# A script that failed to parse can come back from the cache as a
		# non-null Script that cannot be instantiated.
		var script: Script = load(path) as Script
		if script == null or not script.can_instantiate():
			broken.append(path)
	for path: String in broken:
		gut.logger.error("Test script failed to load (parse error?): %s" % path)
	if not broken.is_empty():
		set_exit_code(1)


func _find_test_scripts(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if file.begins_with(PREFIX) and file.ends_with(SUFFIX):
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_find_test_scripts(dir.path_join(sub)))
	return found
