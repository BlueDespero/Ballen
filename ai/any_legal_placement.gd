class_name AnyLegalPlacement
extends PlacementStrategy

## Easy's placement: any cell its secret rule allows, at random. It makes no
## effort to keep its fakes believable, so its moves give its rule away: the
## honest, readable opponent a new player can learn on.


func choose(view: PublicView, _exposure: Belief, rng: RandomNumberGenerator) -> Vector2i:
	return pick(view.own_legal_cells(), rng)
