class_name BallColour
extends RefCounted

## The four ball colours. Colours are plain strings so rule data and history
## stay JSON-ready; the UI maps them to RGB through the Constants autoload.

const YELLOW: String = "yellow"
const BLUE: String = "blue"
const RED: String = "red"
const GREEN: String = "green"

const ALL: Array[String] = [YELLOW, BLUE, RED, GREEN]
## The translation context of a colour named in a sentence about a ball (Polish
## words agree with "kula", the ball).
const BALL_CONTEXT: StringName = &"ball"


static func is_valid(colour: String) -> bool:
	return colour in ALL


## The colour as a sentence about a ball of it names it ("red"), in the game's
## language.
static func word(colour: String) -> String:
	return TranslationServer.translate(colour, BALL_CONTEXT)
