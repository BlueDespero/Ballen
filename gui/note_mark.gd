class_name NoteMark
extends RefCounted

## A private note the player keeps on one of the AI's rules. The game never
## checks it; it only helps the player remember what they have deduced.

## The marks are named after their glyphs, ✗ and ?: the player calls them
## "ruled out" and "suspect" (see Note mark in the glossary), but they are
## beliefs, not the proof the AI's "ruled out" means.
enum Mark { NONE, CROSS, QUESTION }


## The mark one more tap gives: none -> ✗ -> ? -> none.
static func next(mark: Mark) -> Mark:
	match mark:
		Mark.NONE:
			return Mark.CROSS
		Mark.CROSS:
			return Mark.QUESTION
		_:
			return Mark.NONE
