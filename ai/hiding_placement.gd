class_name HidingPlacement
extends PlacementStrategy

## Normal's placement. Hiding counts only the AI's rules the opponent can
## still believe: a fake their evidence has already ruled out (exposure) costs
## nothing to break, so it no longer holds the AI to cells it allows. Among the
## cells that keep the most live rules possible, it keeps its options open:
## the cell after which its secret rule leaves the most legal cells for its
## next ball, in the worst of the 4 colours the opponent could hand it (fewer
## cells means a likelier skip). Ties at random.


func choose(view: PublicView, exposure: Belief, rng: RandomNumberGenerator) -> Vector2i:
	var hidden: Array[Vector2i] = most_shared(view, exposure.alive())
	if hidden.size() <= 1:
		return pick(hidden, rng)
	var best: Array[Vector2i] = []
	var best_room: int = -1
	for cell: Vector2i in hidden:
		var room: int = room_after(view, cell)
		if room > best_room:
			best = []
			best_room = room
		if room == best_room:
			best.append(cell)
	return pick(best, rng)


## The fewest legal cells the AI's secret rule leaves it on the board after it
## places on cell, over the colours it could be handed next.
static func room_after(view: PublicView, cell: Vector2i) -> int:
	var after: MatchPosition = view.position.copy()
	after.board.place(cell, Ball.new(view.position.colour, view.viewer))
	after.history.append(HistoryEntry.placement(view.viewer, cell, view.position.colour))
	var fewest: int = Board.SIZE * Board.SIZE
	for colour: String in BallColour.ALL:
		fewest = mini(fewest, RuleChecker.legal_cells(view.own_secret_rule, after, view.viewer, colour).size())
	return fewest
