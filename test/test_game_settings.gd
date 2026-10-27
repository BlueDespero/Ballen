extends GutTest

# The player's settings: defaults, and kept between runs in a config file.
# Each test uses its own file under user://, never the real settings.

const PATH: String = "user://test_settings.cfg"


func before_each() -> void:
	_remove_file()


func after_all() -> void:
	_remove_file()


func _remove_file() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func _settings() -> GameSettings:
	var settings: GameSettings = autofree(GameSettings.new())
	settings.path = PATH
	return settings


func test_without_a_saved_file_the_defaults_apply() -> void:
	var settings: GameSettings = _settings()
	settings.load_settings()
	assert_eq(settings.volume, 0.8)
	assert_false(settings.colour_blind_symbols)
	assert_false(settings.reduced_motion)
	assert_false(settings.guess_without_holding)
	assert_false(settings.larger_text)


func test_saved_settings_come_back_in_a_new_session() -> void:
	var settings: GameSettings = _settings()
	settings.volume = 0.25
	settings.colour_blind_symbols = true
	settings.reduced_motion = true
	settings.guess_without_holding = true
	settings.larger_text = true
	assert_eq(settings.save_settings(), OK)
	var next_session: GameSettings = _settings()
	next_session.load_settings()
	assert_eq(next_session.volume, 0.25)
	assert_true(next_session.colour_blind_symbols)
	assert_true(next_session.reduced_motion)
	assert_true(next_session.guess_without_holding)
	assert_true(next_session.larger_text)


func test_a_hand_edited_file_with_bad_values_falls_back_to_safe_ones() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("audio", "volume", 3.0)
	file.set_value("accessibility", "reduced_motion", "yes")
	file.set_value("accessibility", "larger_text", true)
	file.save(PATH)
	var settings: GameSettings = _settings()
	settings.load_settings()
	assert_eq(settings.volume, 1.0, "volume is clamped to 0-1")
	assert_false(settings.reduced_motion, "a value of the wrong type keeps the default")
	assert_true(settings.larger_text, "good values still load")


func test_an_unreadable_file_keeps_the_defaults() -> void:
	var broken: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	broken.store_string("this is [not a config file")
	broken.close()
	var settings: GameSettings = _settings()
	settings.load_settings()
	assert_eq(settings.volume, 0.8)
	assert_false(settings.larger_text)


func test_changing_a_setting_tells_listeners() -> void:
	var settings: GameSettings = _settings()
	watch_signals(settings)
	settings.reduced_motion = true
	assert_signal_emitted(settings, "changed")


func test_loading_tells_listeners_once() -> void:
	var settings: GameSettings = _settings()
	settings.larger_text = true
	settings.save_settings()
	var next_session: GameSettings = _settings()
	watch_signals(next_session)
	next_session.load_settings()
	assert_signal_emit_count(next_session, "changed", 1)


func test_the_running_settings_set_the_master_volume() -> void:
	var master: int = AudioServer.get_bus_index("Master")
	var before: float = AudioServer.get_bus_volume_db(master)
	var was_muted: bool = AudioServer.is_bus_mute(master)
	var settings: GameSettings = _settings()
	add_child(settings)
	settings.volume = 0.5
	assert_almost_eq(AudioServer.get_bus_volume_db(master), -6.02, 0.01, "half volume is about -6 dB")
	assert_false(AudioServer.is_bus_mute(master))
	settings.volume = 0.0
	assert_true(AudioServer.is_bus_mute(master), "volume 0 mutes")
	AudioServer.set_bus_mute(master, was_muted)
	AudioServer.set_bus_volume_db(master, before)
