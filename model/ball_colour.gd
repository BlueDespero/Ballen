class_name BallColour
extends RefCounted

## The four ball colours. Colours are plain strings so rule data and history
## stay JSON-ready; the UI maps them to RGB through the Constants autoload.

const YELLOW: String = "yellow"
const BLUE: String = "blue"
const RED: String = "red"
const GREEN: String = "green"

const ALL: Array[String] = [YELLOW, BLUE, RED, GREEN]


static func is_valid(colour: String) -> bool:
	return colour in ALL
