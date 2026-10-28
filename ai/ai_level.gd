class_name AILevel
extends RefCounted

## How well the AI plays: Easy, Normal or Hard. Levels differ in how well the AI
## reads the player's moves and hides its own, never in what it knows or which
## rules it gets. Only Normal, the AI as built so far, can be played yet; match
## setup shows the others as coming soon.

enum Level { EASY, NORMAL, HARD }

## Every level, easiest first.
const ALL: Array[Level] = [Level.EASY, Level.NORMAL, Level.HARD]
## The levels that can be played.
const BUILT: Array[Level] = [Level.NORMAL]

const _TITLES: Dictionary[Level, String] = {
	Level.EASY: "Easy",
	Level.NORMAL: "Normal",
	Level.HARD: "Hard",
}

## How each level plays, as match setup shows it.
const _DESCRIPTIONS: Dictionary[Level, String] = {
	Level.EASY: "Learns slowly and gives a lot away.",
	Level.NORMAL: "Reads your moves and keeps its own rule well hidden.",
	Level.HARD: "Gives almost nothing away, reads every move, and never hesitates.",
}


static func title(level: Level) -> String:
	return _TITLES[level]


static func description(level: Level) -> String:
	return _DESCRIPTIONS[level]


static func is_built(level: Level) -> bool:
	return BUILT.has(level)
