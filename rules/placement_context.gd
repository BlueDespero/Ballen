class_name PlacementContext
extends RefCounted

## What a rule may look at when it judges one placement. Built by RuleChecker;
## parts read it and never change it.

## The board as it would be after the placement (the target holds the new ball).
var board: Board
var target: Vector2i
## The colour of the ball being placed.
var colour: String
## The player whose deck holds the rule ("you" in rule text).
var holder: int
## The position before the placement: first player, and whatever later tickets
## add for rules to read (history, turn number, skip counts).
var position: MatchPosition


func _init(p_position: MatchPosition, p_holder: int, p_colour: String, p_target: Vector2i) -> void:
	position = p_position
	holder = p_holder
	colour = p_colour
	target = p_target
	board = p_position.board.with_ball(p_target, Ball.new(p_colour, p_holder))
