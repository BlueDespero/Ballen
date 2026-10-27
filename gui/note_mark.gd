class_name NoteMark
extends RefCounted

## A private note the player keeps on one of the AI's rules. The game never
## checks it; it only helps the player remember what they have deduced.

enum Mark { NONE, RULED_OUT, SUSPECT }


## The mark one more tap gives: none -> ruled out -> suspect -> none.
static func next(mark: Mark) -> Mark:
	match mark:
		Mark.NONE:
			return Mark.RULED_OUT
		Mark.RULED_OUT:
			return Mark.SUSPECT
		_:
			return Mark.NONE
