class_name NoteMark
extends RefCounted

## A private note the player keeps on one of the AI's rules. The game never
## checks it; it only helps the player remember what they have deduced.

## The marks are named after their glyphs, ✗ and ?: the player calls them
## "ruled out" and "suspect" (see Note mark in the glossary), but they are
## beliefs, not the proof the AI's "ruled out" means.
enum Mark { NONE, CROSS, QUESTION }


## The mark after the player presses one mark's button: pressing the lit mark
## clears it, pressing the other one switches to it.
static func toggled(current: Mark, pressed: Mark) -> Mark:
	return Mark.NONE if pressed == current else pressed
