class_name Harness
extends RefCounted

## The AI-vs-AI harness: plays matches between two AIs with no pauses and
## keeps a record of each, for balance numbers (HarnessStats).

## More commands than any match needs (36 placements, their colour picks and
## a few guesses); a match still running after this many is given up.
const MAX_COMMANDS: int = 500


## Plays match_count matches; match i is play(book, match_seed(seed_value, i)).
static func run(book: RuleBook, match_count: int, seed_value: int) -> HarnessStats:
	var stats: HarnessStats = HarnessStats.new()
	for i: int in match_count:
		stats.add(play(book, match_seed(seed_value, i)))
	return stats


## The seed of match i of a run, so any one match can be replayed alone.
## Hashed rather than seed_value + i, so runs from nearby seeds share no match.
static func match_seed(seed_value: int, i: int) -> int:
	return hash([seed_value, i])


## One match between two AIs: each gets a deck drawn at random from the
## book and a random true rule from it; the coin toss picks the first player.
## Every random choice comes from one RNG seeded with seed_value.
static func play(book: RuleBook, seed_value: int) -> MatchRecord:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var decks: Array[Deck] = []
	var true_rules: Array[Rule] = []
	var ais: Array[AIController] = []
	for player: int in Players.COUNT:
		var deck: Deck = Deck.draw(book, rng)
		decks.append(deck)
		true_rules.append(deck.random_rule(rng))
		ais.append(AIController.new(rng))
	var current_match: Match = Match.create(decks, true_rules, rng)
	play_out(current_match, ais)
	return MatchRecord.from_match(current_match)


## Asks the AI of every awaited player for a command and submits it until
## the match is over. Returns false, leaving the match unfinished, if an AI
## has no command, the match rejects one, or MAX_COMMANDS run out.
## AIs decide at once, so this needs no await.
static func play_out(current_match: Match, ais: Array[AIController]) -> bool:
	var commands: int = 0
	while current_match.phase() != Match.Phase.OVER:
		for player: int in current_match.awaiting_players():
			if commands >= MAX_COMMANDS:
				return false
			var command: Command = ais[player].decide(current_match.public_view(player))
			if command == null or not current_match.submit(player, command):
				return false
			commands += 1
	return true
