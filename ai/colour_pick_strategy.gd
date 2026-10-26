class_name ColourPickStrategy
extends RefCounted

## How the AI chooses the colour the opponent places next: the colour with the
## highest score, ties broken at random. Swappable: hand AIController a
## subclass that overrides score() (another opponent model) or choose()
## (later difficulty levels).
##
## This is milestone 1's uniform model. Each candidate is equally likely to be
## the opponent's true rule, and the opponent places uniformly among that
## rule's legal cells, or skips if there are none. A colour scores the
## expected number of candidates its placement or skip would rule out. With no
## information every colour scores the same, so the pick is random.

## Scores closer than this are a tie.
const TIE: float = 1e-9


## The colour to hand the opponent.
func choose(view: PublicView, candidates: Array[Rule], rng: RandomNumberGenerator) -> String:
	var best: Array[String] = []
	var best_score: float = -INF
	for colour: String in BallColour.ALL:
		var colour_score: float = score(view, candidates, colour)
		if colour_score > best_score + TIE:
			best = []
			best_score = colour_score
		if colour_score > best_score - TIE:
			best.append(colour)
	return best[rng.randi_range(0, best.size() - 1)]


## The expected number of candidates ruled out by the opponent's next turn in
## this colour.
func score(view: PublicView, candidates: Array[Rule], colour: String) -> float:
	if candidates.size() < 2:
		return 0.0
	var opponent: int = view.opponent()
	var next: MatchPosition = next_turn(view, colour)
	# Each candidate's legal cells, checked once: a placement rules out the
	# candidates that don't allow its cell, a skip those that allow some cell
	# (Deduction.rules_out, without checking every rule again per event).
	var legal: Array[Dictionary] = []
	var skip_ruled_out: int = 0
	for rule: Rule in candidates:
		var cells: Dictionary[Vector2i, bool] = {}
		for cell: Vector2i in RuleChecker.legal_cells(rule, next, opponent, colour):
			cells[cell] = true
		legal.append(cells)
		if not cells.is_empty():
			skip_ruled_out += 1
	var ruled_out_by_cell: Dictionary[Vector2i, int] = {}
	var total: float = 0.0
	for cells: Dictionary in legal:
		if cells.is_empty():
			total += skip_ruled_out
			continue
		var sum: int = 0
		for cell: Vector2i in cells:
			if not ruled_out_by_cell.has(cell):
				var count: int = 0
				for other: Dictionary in legal:
					if not other.has(cell):
						count += 1
				ruled_out_by_cell[cell] = count
			sum += ruled_out_by_cell[cell]
		total += float(sum) / cells.size()
	return total / candidates.size()


## The position at the start of the opponent's next turn if the viewer picks
## this colour now.
static func next_turn(view: PublicView, colour: String) -> MatchPosition:
	var next: MatchPosition = view.position.copy()
	next.history.append(HistoryEntry.colour_pick(view.viewer, colour))
	next.turn += 1
	next.colour = colour
	return next
