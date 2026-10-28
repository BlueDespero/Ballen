class_name GameSettings
extends Node

## The player's settings, kept between runs in a config file. The `Settings`
## autoload is the one instance the game reads; anything that depends on a
## setting reads it there and listens to `changed`.

## A setting changed (once per load_settings()).
signal changed

const DEFAULT_PATH: String = "user://settings.cfg"
const DEFAULT_VOLUME: float = 0.8
const LARGER_TEXT_SCALE: float = 1.25
## Sections of the config file.
const AUDIO: String = "audio"
const ACCESSIBILITY: String = "accessibility"

## The config file the settings load from and save to.
var path: String = DEFAULT_PATH
## Master volume, 0 (silent) to 1.
var volume: float = DEFAULT_VOLUME:
	set(value):
		volume = clampf(value, 0.0, 1.0)
		_apply_volume()
		_notify()
## A distinct symbol on each ball colour.
var colour_blind_symbols: bool = false:
	set(value):
		colour_blind_symbols = value
		_notify()
## No decorative motion: pulses stay still, balls jump instead of flying.
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		_notify()
## Guess and Seal fire on a tap and a Confirm tap instead of a hold.
var guess_without_holding: bool = false:
	set(value):
		guess_without_holding = value
		_notify()
## Bigger text in the rules panel and the menus.
var larger_text: bool = false:
	set(value):
		larger_text = value
		_notify()

var _loading: bool = false


## The autoload loads the saved settings as the game starts.
func _ready() -> void:
	load_settings()
	_apply_volume()


## Reads the settings from `path`; anything missing or unreadable keeps its
## default.
func load_settings() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(path) != OK:
		return
	_loading = true
	volume = _read(file, AUDIO, "volume", DEFAULT_VOLUME)
	colour_blind_symbols = _read(file, ACCESSIBILITY, "colour_blind_symbols", false)
	reduced_motion = _read(file, ACCESSIBILITY, "reduced_motion", false)
	guess_without_holding = _read(file, ACCESSIBILITY, "guess_without_holding", false)
	larger_text = _read(file, ACCESSIBILITY, "larger_text", false)
	_loading = false
	changed.emit()


## How much bigger than built the rules panel and menu text is.
func text_scale() -> float:
	return LARGER_TEXT_SCALE if larger_text else 1.0


## Writes the settings to `path`.
func save_settings() -> Error:
	var file: ConfigFile = ConfigFile.new()
	file.set_value(AUDIO, "volume", volume)
	file.set_value(ACCESSIBILITY, "colour_blind_symbols", colour_blind_symbols)
	file.set_value(ACCESSIBILITY, "reduced_motion", reduced_motion)
	file.set_value(ACCESSIBILITY, "guess_without_holding", guess_without_holding)
	file.set_value(ACCESSIBILITY, "larger_text", larger_text)
	return file.save(path)


## The running settings (in the tree) set the Master bus, so every sound
## follows the volume; 0 mutes it.
func _apply_volume() -> void:
	if not is_inside_tree():
		return
	var master: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(master, volume <= 0.0)


func _notify() -> void:
	if not _loading:
		changed.emit()


## A value from the file, or the default when it is missing or of another
## type (a hand-edited file). A whole number is fine for the volume.
func _read(file: ConfigFile, section: String, key: String, default: Variant) -> Variant:
	var value: Variant = file.get_value(section, key, default)
	if typeof(default) == TYPE_FLOAT and typeof(value) == TYPE_INT:
		return float(value)
	return value if typeof(value) == typeof(default) else default
