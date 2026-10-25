class_name Match
extends RefCounted

## One match of Ballen, held in plain objects: a passive state machine.
##
## The match never acts on its own. A driver (the scene, the harness, a test)
## asks which players it is waiting for, gets a Command from each one's
## Controller and hands it to submit(). A command that is illegal for the phase
## or the player is rejected and changes nothing.
##
## Phases of a turn:
##   FIRST_COLOUR  turn 0 only: the second player picks the first player's colour
##   PLACE         the current player places a ball of the current colour
##   PICK_COLOUR   the current player picks the opponent's colour, ending the turn

enum Phase { FIRST_COLOUR, PLACE, PICK_COLOUR }

var _position: MatchPosition
var _decks: Array[Deck] = []
var _true_rules: Array[Rule] = []
var _rng: RandomNumberGenerator
var _phase: Phase = Phase.FIRST_COLOUR


func _init(position: MatchPosition, decks: Array[Deck], true_rules: Array[Rule], rng: RandomNumberGenerator) -> void:
	_position = position
	_decks = decks.duplicate()
	_true_rules = true_rules.duplicate()
	_rng = rng


## A new match on an empty board. A coin toss on the rng picks the first
## player; the second player then picks the first colour.
## Returns null (and reports an error) if the decks or true rules don't fit.
static func create(decks: Array[Deck], true_rules: Array[Rule], rng: RandomNumberGenerator) -> Match:
	if not _setup_is_valid(decks, true_rules):
		return null
	var first_player: int = rng.randi_range(0, Players.COUNT - 1)
	return Match.new(MatchPosition.new(Board.new(), first_player), decks, true_rules, rng)


static func _setup_is_valid(decks: Array[Deck], true_rules: Array[Rule]) -> bool:
	if decks.size() != Players.COUNT or true_rules.size() != Players.COUNT:
		push_error("Match needs a deck and a true rule for each of the 2 players")
		return false
	for player: int in Players.COUNT:
		if decks[player].rules.size() != Deck.SIZE:
			push_error("Match: player %d's deck has %d rules, not %d" % [player, decks[player].rules.size(), Deck.SIZE])
			return false
		if not decks[player].has(true_rules[player]):
			push_error("Match: player %d's true rule is not in their deck" % player)
			return false
	return true


func phase() -> Phase:
	return _phase


## The player whose turn it is (during FIRST_COLOUR, the player picking it).
func current_player() -> int:
	return _position.current_player()


## The players the match is waiting for a command from.
func awaiting_players() -> Array[int]:
	return [current_player()]


func first_player() -> int:
	return _position.first_player


func turn() -> int:
	return _position.turn


## The colour the current player places; "" before the first colour pick.
func current_colour() -> String:
	return _position.colour


## A copy of the move history.
func history() -> Array[HistoryEntry]:
	return _position.copy().history


## The current player's legal cells for the current colour, under their true
## rule; empty outside the PLACE phase. Drives highlights and the drop check.
func legal_cells() -> Array[Vector2i]:
	if _phase != Phase.PLACE:
		return []
	var player: int = current_player()
	return RuleChecker.legal_cells(_true_rules[player], _position, player, _position.colour)


## Whether the current player may place the current ball on this cell now.
func is_legal(cell: Vector2i) -> bool:
	if _phase != Phase.PLACE:
		return false
	var player: int = current_player()
	return RuleChecker.is_legal(_true_rules[player], _position, player, _position.colour, cell)


## Hands a player's command to the match. Returns false, changing nothing,
## when the command is illegal for the phase or the player.
func submit(player: int, command: Command) -> bool:
	if command == null or not awaiting_players().has(player):
		return false
	match command.type:
		Command.Type.PLACE:
			return _place(player, command.cell)
		Command.Type.PICK_COLOUR:
			return _pick_colour(player, command.colour)
	return false


func _place(player: int, cell: Vector2i) -> bool:
	if not is_legal(cell):
		return false
	_position.board.place(cell, Ball.new(_position.colour, player))
	_position.history.append(HistoryEntry.placement(player, cell, _position.colour))
	_phase = Phase.PICK_COLOUR
	return true


func _pick_colour(player: int, colour: String) -> bool:
	if _phase != Phase.FIRST_COLOUR and _phase != Phase.PICK_COLOUR:
		return false
	if not BallColour.is_valid(colour):
		return false
	_position.history.append(HistoryEntry.colour_pick(player, colour))
	_position.turn += 1
	_position.colour = colour
	_start_turn()
	return true


func _start_turn() -> void:
	_phase = Phase.PLACE
