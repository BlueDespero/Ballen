extends GutHookScript

# Tests check the game's English text. The Settings autoload has already set
# the locale from the player's saved language, which may be another one, so
# the run switches back to English first.


func run() -> void:
	TranslationServer.set_locale(GameSettings.ENGLISH)
