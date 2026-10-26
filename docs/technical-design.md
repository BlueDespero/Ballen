# Ballen — Technical Design

How Ballen is built. The [game design document](game-design-document.md) says **what** the game is and
why; this document says **how** the code delivers it. When the two disagree, the game design document
wins and this file is updated.

## Engine and platforms

- Godot 4.7, statically typed GDScript, GL Compatibility renderer.
- Browser (web export) first, then Android and iOS. Mouse and touch input.
- Landscape, 1280 × 720 base resolution that scales (stretch mode `canvas_items`, aspect `expand`). Portrait layout for phones comes later.
- Game screen layout: the board in the main area, the player's side at the bottom and the AI's at the top, row labels on the board edge; balls wait below and above the board; one rules panel on the right with the AI's rules on top (with Guess) and the player's below (true rule highlighted); skip pips by each player's rules; the colour picker beside the player's ball.
- The current project still uses a 512 × 704 portrait window; change it when the game screen is rebuilt.

## Architecture

Game logic is kept apart from the scenes, so the AI, the legal-cell highlights and a future server
all run the same code.

| Layer | Holds | Notes |
| --- | --- | --- |
| Game model (`model/`) | Board, turn order, colour picks, skips, guesses, move history | Plain `RefCounted` classes, no scene nodes; `Match` is a passive state machine |
| Rules engine (`rules/`) | Templates, parts (selectors, filters, conditions, combiners), evaluation | Pure functions over a placement context; rules and templates loaded from `rules/data/*.json` |
| AI (`ai/`) | Placement, colour picks, deduction, guessing | Receives a public view only; one level now, Easy, Normal and Hard later |
| Scenes / UI | Match scene (`main_game.tscn`), pre-match overlay (`gui/pre_match_panel.tscn`), board (`gui/board_view.gd`), waiting balls and drag (`gui/ball_view.gd`), colour picker, rules panel (`gui/rules_panel.tscn`), match-end screen (`gui/match_end_overlay.tscn`), menus | Show the model and send player actions; never decide legality themselves |
| Autoloads | `EventBus` (global signals), `Constants` (colour table) | Turn state lives in `Match`, not in an autoload |
| Online (later) | Both true rules; checks every move | Server-authoritative; clients never receive the opponent's true rule |

### Key decisions

- The dragged ball (`gui/ball_view.gd`) asks the match whether the cell under it is legal
  (`Match.is_legal`) instead of checking rules itself; the glow shows `Match.legal_cells()`.
- The custom-script fallback gets a fresh base script when it is first needed (the old
  half-written `rules/baserule.gd` stub was deleted).
- The match never acts on its own. A driver (the scene, the AI-vs-AI harness, a test) asks
  `Match.awaiting_players()`, gets a `Command` from that player's `Controller`
  (`await controller.decide(match.public_view(player))`) and hands it to `Match.submit()`, which
  rejects any command illegal for the phase or the player. Human and AI share the `Controller`
  interface. `MatchDriver` runs that loop for the scene, waiting a random 0.5–1.5 s (seeded RNG,
  injected wait) before each AI action; the player's `HumanController` waits until the scene hands
  it the command from a drop or a colour button.
- A guess is a command like any other (`Command.guess(rule_id)`, naming a rule of the opponent's deck).
  The match accepts it only in the current player's guess windows, the `PLACE` phase (before placing)
  and the `PICK_COLOUR` phase (after placing or skipping, until the colour pick); `PublicView.can_guess()`
  tells a controller when its window is open. A right guess wins and a wrong one loses at once, and
  history records the guesser, the named rule and whether it was right. In the scene the player
  selects one of the AI's rules and holds Guess (`gui/guess_button.gd`) for about a second.
- The placement that fills the board starts the `FORCED_GUESS` phase instead of a colour pick. The
  match awaits the placer first: they may still pull the trigger with `Command.guess`, or make their
  forced guess (`Command.forced_guess(rule_id)`); then it awaits the opponent's. A forced guess is
  sealed: the match keeps it privately, so no `PublicView` and no history shows it until both are in
  (`PublicView.awaiting_players` and `forced_guess_due()` show only whose guess is due). Then history
  records both as guesses, the placer's first, and the match ends with `FORCED_GUESSES`: exactly one
  right wins, otherwise a draw. In the scene the player selects a rule and holds Seal, a second hold
  button beside Guess on a full board; while the player who filled it may still pull the trigger,
  Guess stays beside Seal, and the placer's opponent gets only Seal.
- The AI gets a `PublicView`: a snapshot copied for one viewer, without the opponent's true rule or
  legal cells and with no reference back to the match ([ADR 0002](adr/0002-public-view-is-a-snapshot.md)).
  A test compares views from matches that differ only in the opponent's true rule. Once the match is
  over, the view reveals both true rules (`revealed_true_rules`, empty while the match runs).
- The match-end screen (`gui/match_end_overlay.tscn`) shows what `MatchEndSummary.from_view()` makes
  of the player's finished view: win, lose or draw, how the match ended (a guess, a third skip or both
  forced guesses, read from the result and the guesses at the end of the history) and both true
  rules. The rules panel marks the AI's true rule. Rematch goes back to the pre-match overlay on the
  same decks; Main menu returns to `main.tscn`.
- A match can start from a `MatchPosition` (board, turn, colour, skip counts, history), and every
  random choice goes through an injected, seedable `RandomNumberGenerator`.
- `MatchSetup` is what comes before a single-player match: the player's fixed starter deck and the
  AI's deck of 5 distinct rules drawn from the built ones (`Deck.draw`). Both decks are shown first;
  `MatchSetup.start(true_rule)` then draws the AI's true rule from its deck and creates the match,
  whose coin toss picks the first player. The setup keeps both decks: `MatchSetup.rematch(true_rule)`
  starts the next match on them, with the player's new true rule, a new random true rule drawn from
  the AI's deck and no coin toss: whoever went second last time goes first (`Match.create` takes an
  optional first player), so rows are numbered from that player's side.

## Rules engine

Every rule is plain data built from shared parts. A new rule needs no code; a new mechanic is one new
part (plus, if needed, a new context field) and leaves existing rules untouched.

### Parts

| Part | Answers | Examples |
| --- | --- | --- |
| Selector | Which cells or balls to look at? | Neighbours (4 or 8), row, column, diagonals, whole board, your last ball, opponent's last ball |
| Filter | Which of those count? | Same colour as this ball, a fixed colour, mine / opponent's, empty / occupied |
| Condition | What must be true? | Count = 0, ≤ N, ≥ N, more A than B, exists / none |
| Combiner | How do conditions join? | AND, OR, NOT, IF … THEN |
| Context | What a rule may know | Board, target cell, ball colour, ball owner, move history, turn number, skips |

Example: "Never next to the same colour" = neighbours + same colour + count = 0.

Some rules judge groups of cells rather than single cells. A group selector yields several groups and a
group condition judges them (`rules/group_parts.gd`). Example: "Never complete a line of 3" = the lines
through the target (one per direction: horizontal, vertical, both diagonals) + no group of 3 or more.

### Data format

A rule is a **template plus the values in its blanks**, with an id and its hand-written player text.
Built-in and player-made rules share one JSON-ready format (`rules/data/rules.json`):

```json
{ "id": "R04", "text": "Never on the edge", "template": "not_on_zone", "values": { "zone": "edge" } }
```

A template is data too ([ADR 0001](adr/0001-rule-templates-are-data.md), `rules/data/templates.json`):
its blanks with their allowed values, and a tree of parts. Each node names a part and gives its
arguments; `"$zone"` is filled with the rule's value for the blank `zone`:

```json
"not_on_zone": {
	"blanks": { "zone": ["edge"] },
	"tree": { "part": "count_at_most", "n": 0,
		"of": { "part": "in_zone", "zone": "$zone", "of": { "part": "target" } } }
}
```

Part implementations live in `rules/parts.gd`. The JSON files are not Godot resources, so an export
preset must include `*.json` in its non-resource filter.

The catalogue of planned rules lives in [rules-library.md](rules-library.md).

### Evaluation

- A rule is a pure function: `(context) -> bool` (pass / fail). No side effects, no scene access.
  The context is the board as it would be after the placement, the target cell, the ball's colour,
  the rule's holder and the position before the placement (first player, history, skips, turn).
- `RuleChecker` answers whether a cell is legal for a rule, colour and holder, and lists the legal
  cells.
- The same evaluation drives the legal-cell highlights, skip detection, the AI and, later, the server.
- A rule that doesn't fit the parts gets its own script (fallback), still with the same signature.

### Strictness check

Used for player-made rules (later release) and to tune built-in ones: simulate the rule on many random
boards and record the share of placements it forbids. Accept rules that forbid roughly 20–60%
(thresholds set in playtesting). Store the measured value in the rules library.

### Rule tiers

AI-vs-AI runs measure how much each rule restricts its holder (skip rate, legal cells per turn, win rate as the true rule). The results rank each rule Simple, Intermediate or Hardcore, stored in the rules library's Tier column.

## AI opponent

The AI's design (belief updating, colour picks as information probes, when to guess, hiding,
difficulty levels, compute budget) is in [ai-decision-theory-research.md](ai-decision-theory-research.md)
and summarised in the README's "How the AI thinks".

### As built (milestone 1)

One level, using hard evidence only. `AIController` (`ai/ai_controller.gd`) is a `Controller`: it gets a
`PublicView`, returns a `Command`, and makes every random choice through an injected, seedable RNG.
Each `decide()` works out the candidates once and hands them to the pieces below.

| Piece | Does | Notes |
| --- | --- | --- |
| `Deduction` (`ai/deduction.gd`) | The opponent's rules not yet ruled out (`candidates(view)`), in deck order | Hard elimination: a placement rules out the rules it breaks, a skip the rules that would have allowed a cell in that colour. Each event is judged on the position just before it (`position_before`), so rules that read rows, the last ball or the board see what the match saw. Stateless: recomputed from the view's history on every call, so nothing to reset on a rematch |
| `GuessPolicy` (`ai/guess_policy.gd`) | When to guess, and which rule | Names the top candidate once its `confidence()` reaches the threshold. Confidence is 1 / candidates and the threshold 1, so it guesses when one candidate is left. Asked whenever `view.can_guess()`: at the start of its turn, after placing or skipping, and as the placer on a full board |
| `ColourPickStrategy` (`ai/colour_pick_strategy.gd`) | The colour the opponent places next | Highest `score()`, ties at random. The score is the expected number of candidates ruled out by the opponent's next turn in that colour, if each candidate is equally likely and the opponent places at random among its legal cells (or skips). On the empty board every colour scores the same, so the first pick is random |
| Placement (`AIController`) | Where to place its own ball | Among its legal cells, those that satisfy the most of its own 5 rules, so any of them could be its true rule; ties at random |
| Forced guess (`AIController`) | Its sealed guess on a full board | A random remaining candidate (all are equally likely) |

The thinking pause is the scene's: `MatchDriver` waits a random 0.5–1.5 s before each AI command. Tests
and the harness play AIs with no pause.

### Later levels

Easy, Normal and Hard plug into the same seams; none needs the model to change:

- Soft evidence: a `GuessPolicy` subclass overrides `confidence()` with a belief, and the threshold sets how
  sure a level must be. `Deduction` stays the hard elimination mask under it.
- Colour picks: a `ColourPickStrategy` subclass overrides `score()` (another model of the opponent) or
  `choose()` (e.g. a softer, more random pick for Easy).
- Placement is a private method today; split it into a strategy object when levels need different hiding.
- `AIController.new(rng, guess_policy, colour_pick)` takes both objects, so a level is a choice of objects.

Planned implementation notes:

- Exact Bayesian belief over the opponent's 5 rules, with a hard elimination mask and soft scores in
  log space.
- Easy and Normal use heuristics plus at most one-step lookahead (well under a frame).
- Hard adds Monte Carlo tree search keyed on public history, spread across frames or a thread, and keeps searching during the player's turn.
- AI thinking pause: up to 5 s, scaled with decision difficulty; Hard adds random jitter so pauses carry no information.

## AI-vs-AI harness

A headless script that plays matches between two AIs and prints balance numbers; it seeds the rule
tiers and, later, tunes randomisation and difficulty. From the repo root, after an import
(`godot --headless --path . --import`):

```powershell
godot --headless --path . -s harness/run_harness.gd -- --matches 100 --seed 1
```

| Class (`harness/`) | Does |
| --- | --- |
| `Harness` | `play(book, seed)`: one match between two default `AIController`s, each with a deck drawn at random from the built rules (`Deck.draw`) and a random true rule; the coin toss picks the first player. `run(book, n, seed)` plays n matches, match i seeded `match_seed(seed, i)`, so any match can be replayed alone |
| `MatchRecord` | What a match leaves: each player's true rule (read from their own view), first player, result, turns played (placements and skips) and skips per player |
| `HarnessStats` | The numbers over finished matches, and `summary()`, the text the script prints |
| `run_harness.gd` | Command-line entry (`extends SceneTree`): parses `--matches` and `--seed` (defaults 100 and 1) |

- The summary: matches finished out of matches played; first player's wins, losses and draws; how
  matches ended (right guess, wrong guess, third skip, forced guesses); average turns per match; and per
  true rule, how often it was held, its holders' skip rate, win rate and wins / losses / draws.
- `Harness.play_out` is its own synchronous loop, not `MatchDriver`: no pauses, no signals, no awaits.
- Unfinished-match guard: the loop gives up on a match if an AI returns no command, the match rejects
  a command, or the match runs past `Harness.MAX_COMMANDS` (500) commands. A given-up match counts as
  played but not finished, and the script exits with code 1 if any match didn't finish (or an argument
  is bad), 0 otherwise.
- Same seed, same output. 100 matches take about 40 s (about 0.4 s a match).

## Daily duel

- Seed a deterministic RNG from the UTC date (e.g. `hash("ballen-daily-" + date)`) for the AI's deck, its true rule, its colour choices and who starts, so every player faces the same opponent.
- The AI's own choices during the duel draw from that seeded RNG; the player's moves do not change the seed.
- One attempt per day and the streak are stored locally for the first release.

## Open technical questions

- [ ] Board representation: 64-bit bitmasks (36 cells) for speed in Hard's search?
- [ ] Threads on the web export need cross-origin isolation; check against the chosen host (itch.io).
- [ ] Save format and location for decks (local storage on web, user:// on mobile).
