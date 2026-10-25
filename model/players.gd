class_name Players
extends RefCounted

## Players are plain ints: 0 and 1. Player 0 sits at the bottom of the board,
## player 1 at the top (see Board).

const COUNT: int = 2
## No player, e.g. the winner of a drawn match.
const NONE: int = -1


static func opponent(player: int) -> int:
	return 1 - player


static func is_valid(player: int) -> bool:
	return player == 0 or player == 1
