# Ballen — Technical Design

How Ballen is built. The [game design document](game-design-document.md) says **what** the game is and
why; this document says **how** the code delivers it. When the two disagree, the game design document
wins and this file is updated.

## Engine and platforms

- Godot 4.7, statically typed GDScript, GL Compatibility renderer.
- Browser (web export) first, then Android and iOS. Mouse and touch input.
- Landscape, 1280 × 720 base resolution that scales (stretch mode `canvas_items`, aspect `expand`). Portrait layout for phones comes later.
- Game screen layout: the board in the main area, the player's side at the bottom and the AI's at the top, row labels on the board edge; balls wait below and above the board; one rules panel on the right with the AI's rules on top (with Guess) and the player's below (true rule highlighted); skip pips by each player's rules; the colour picker beside the player's ball.

## Architecture

Game logic is kept apart from the scenes, so the AI, the legal-cell highlights and a future server
all run the same code.

| Layer | Holds | Notes |
| --- | --- | --- |
| Game model (`model/`) | Board, turn order, colour picks, skips, guesses, move history | Plain `RefCounted` classes, no scene nodes; `Match` is a passive state machine |
| Rules engine (`rules/`) | Templates, parts (selectors, filters, conditions, combiners), evaluation | Pure functions over a placement context; rules and templates loaded from `rules/data/*.json` |
| AI (`ai/`) | Placement, colour picks, deduction, guessing | Receives a public view only; one level now, Easy, Normal and Hard later |
| Scenes / UI | Match scene (`main_game.tscn`), match setup screen (`gui/match_setup_screen.tscn`), board (`gui/board_view.gd`), waiting balls and drag (`gui/ball_view.gd`), colour picker, rules panel (`gui/rules_panel.tscn`), match-end screen (`gui/match_end_overlay.tscn`), menus | Show the model and send player actions; never decide legality themselves |
| Autoloads | `EventBus` (global signals), `Constants` (colour table), `Settings` (player settings, `user://settings.cfg`) | Turn state lives in `Match`, not in an autoload |
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
  rules. The rules panel marks the AI's true rule. Rematch goes back to the match setup screen on the
  same decks at the same level; Main menu returns to `main.tscn`.
- A match can start from a `MatchPosition` (board, turn, colour, skip counts, history), and every
  random choice goes through an injected, seedable `RandomNumberGenerator`.
- Past positions are rebuilt from a position's history: `MatchPosition.before(index)` is the position
  just before a placement or skip (the AI's deduction judges each event on it), `after_turn(n)` the
  position right after turn n's placement or skip, with that event last in its history. The match
  scene's history view (◀ Live ▶ under the board, or ← →) steps through `after_turn` boards of the
  player's view, ringing that turn's ball or showing its skipped ball at its owner's side. It only
  shows: the glow and dragging pause. Only the player's own actions return to the live board (pressing
  their ball, a colour pick, Guess or Seal, Live, or stepping past the latest turn); the colour picker,
  Guess and Seal keep following the live match meanwhile. When the AI plays on while a past board is on
  show, nothing animates: the board stays and Live lights up and pulses until the player returns (the
  match ending returns at once, for the match-end screen). New history events are shown by one run of
  the scene's event loop at a time, so the history view never opens mid-animation. Which turn is on
  show, the stepping and the past turn's status text live in `HistoryBrowser` (`gui/history_browser.gd`,
  unit-tested on a match's `PublicView`); `HistoryNav` only draws the buttons.
- The match setup screen (`gui/match_setup_screen.tscn`) comes before every match: the player picks
  a deck (`DeckStore`: the starter deck first, then the saved decks) and the AI level
  (`AILevel`: Easy, Normal, Hard; only Normal is built, the others show as coming soon), taps one rule
  of the deck to make it true, and presses Start. The AI's deck is drawn when the screen opens, and
  the rules panel beside the screen shows it and the picked deck while the player chooses (the AI's
  true rule stays hidden); the coin toss is then shown over the board.
- `MatchSetup.against_ai(deck, ai_deck, level, rng)` is what comes before a single-player match: the
  picked deck, the AI's deck of 5 distinct rules drawn from the built ones (`Deck.draw`) and the level
  (a level not built yet is refused). `MatchSetup.start(true_rule)` then draws the AI's true rule
  from its deck and creates the match, whose coin toss picks the first player. The setup keeps both
  decks and the level: `MatchSetup.rematch(true_rule)` starts the next match on them, with the
  player's new true rule, a new random true rule drawn from the AI's deck and no coin toss: whoever
  went second last time goes first (`Match.create` takes an optional first player), so rows are
  numbered from that player's side. A rematch shows the setup screen with the deck and level locked.

### Saved decks

`DeckStore` (`model/deck_store.gd`) keeps the player's named decks in `user://decks.json` (the path
is injectable for tests; on the web export Godot keeps `user://` in the browser's IndexedDB). A deck
is stored as its 5 rule ids, in the order the decks were saved; the rules themselves stay data in the
`RuleBook`, which turns the ids back into rules on load:

```json
{ "decks": [ { "name": "Mixed", "rules": ["R02", "R04", "R06", "R07", "R09"] } ] }
```

- The starter deck (`DeckStore.STARTER_DECK_NAME`, `STARTER_DECK_IDS`) is built in, never in the file:
  `names()` always lists it first, then the saved decks; `is_read_only(name)` is true only for it.
- `deck(name)` (a new `Deck` of the book's rules), `save(name, deck)` (replaces a deck of the same
  name), `rename(old, new)` (keeps the deck's place), `replace(old, new, deck)` (a rename and a save in
  one write) and `delete(name)`. Each change writes the file at once and returns false, changing
  nothing, if it can't. `save` refuses the starter deck's name; `rename`, `replace` and `delete` refuse
  the starter deck and unknown names, and `rename` and `replace` a blank or taken name.
- `name_problem(name, own_name = "")`: why a deck can't take a name ("Name the deck", "A deck named X
  already exists"; a deck may keep `own_name`), or "". The screens show it as a hint.
- On load, a deck with no name, the starter deck's name, a name already used, an unknown rule id, a
  repeated rule or not exactly 5 rules is skipped with an error; a file that isn't JSON or has the
  wrong shape loads as no decks. `save` refuses the same decks, so the file only ever holds decks that
  load.

### Deck builder

The Decks screen (`gui/menus/decks_screen.tscn`, opened by the main menu's Decks button) lists every
deck of the `DeckStore` with its rule ids and tier dots. A saved deck has Edit, Rename and Delete (a
confirm first); the read-only starter deck has only Copy. The deck editor
(`gui/menus/deck_editor.tscn`) opens over the screen and emits `closed(saved)` on Save or Cancel.

The editor's logic is `DeckDraft` (`model/deck_draft.gd`), so the screen only draws it:

- A name and up to `Deck.SIZE` distinct rule ids in pick order. `DeckDraft.new()` is a new deck;
  `DeckDraft.editing(store, name)` edits a saved deck and may keep its name;
  `DeckDraft.copy_of(store, name)` is a new deck named "<name> copy" (or "<name> copy 2", …).
- `toggle(rule_id)` picks or drops a rule and returns false, changing nothing, for a pick past 5 (the
  editor flashes its counter); `count()`, `has()`, `rule_ids()`.
- `problem(store)`: the hint line and what disables Save: "Pick 5 rules (3 picked)" first, then the
  store's `name_problem`; "" when the draft can be saved.
- `to_deck(book)`; `save_to(store, book)` saves a new deck, or replaces the edited deck in place (one
  write, so a failed save keeps it as it was). Names are saved without leading or trailing spaces.
- Each rule's tier (`Rule.tier`: `simple`, `intermediate` or `hardcore`, from `rules.json`) shows as a
  badge or dot (`TierBadge`: Simple green, Intermediate amber, Hardcore red); the editor's chips show
  one tier at a time.

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

Built so far:

| Kind | Parts |
| --- | --- |
| Selector | `target`; `neighbours` (8, diagonals included); `same_axis` (the whole row); `whole_board`; `other_cells` (the board without the `of` cells); `within_distance` (n king moves) |
| Filter | `in_zone` (the edge); `with_parity` (even or odd row); `same_colour`; `of_colour` (a fixed colour); `next_colour` (yellow → blue → red → green); `any_ball`; `opponent_ball`; `my_last_ball`; `opponent_last_ball`; `empty` |
| Condition | `count_at_most`; `count_at_least`; `no_more_than` (no more cells in one selection than in another) |
| Combiner | `all` (with an empty list it always passes: the permissive rule tests use); `any` |
| Group selector, condition | `lines_through` (the unbroken same-colour stretch through a ball, per direction); `no_group_of` |
| Filter, row comparison | `in_row_relative` (row numbered higher or lower than every reference cell, e.g. your last ball; with no reference cell every cell is kept) |
| Time and game state | Combiner `if_then` ("then" applies only while "if" holds); conditions `own_turn_parity`, `own_turn_at_most` (the holder's own turn count, 1 on their first turn), `skips_at_least` (both players' skips); filters `in_rows` (row numbers from–to), `my_ball` (the holder's balls) |

Filters read the board after the placement. Rows are numbered 1–6 from the first player's side
(`Board.row_number`). In template ids and blanks a row or column is an `axis` (only rows are built);
"line" means only a line of one colour, as in the [glossary](../GLOSSARY.md).
Distances count king moves (`Board.distance`), so neighbours are 1 apart. A "must touch" rule
(template `must_touch`) passes when a ball of its kind is on a neighbour of the target or when no such
ball is anywhere else on the board: with nothing to touch it allows every cell.

### Data format

A rule is a **template plus the values in its blanks**, with an id and its hand-written player text.
Built-in and player-made rules share one JSON-ready format (`rules/data/rules.json`):

```json
{ "id": "R04", "text": "Never on the edge", "template": "not_on_zone", "values": { "zone": "edge" }, "tier": "intermediate" }
```

`tier` (`simple`, `intermediate` or `hardcore`) mirrors the rules library's Tier column and is optional
(test rules leave it out); any other value is rejected like a bad blank value.

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

`StrictnessCheck` (`harness/strictness_check.gd`) does it; `harness/run_strictness.gd` prints one row per
built rule (command in `CLAUDE.md`):

- **Random positions** (`random_positions(count, seed)`, one seeded RNG): a coin toss picks the first
  player, then turns are played until the board holds a random number of balls, uniform from 0 to 35.
  Each turn starts with a colour pick of a random colour by the other player; the player then skips
  (chance `SKIP_CHANCE`, 5%, never a third time) or places that colour on a random empty cell. So every
  position is one a match could reach, with owners, last balls, turn numbers and skip counts in its
  history for the history, time and game-state rules. The position ends at the start of a turn: the
  current player is the holder and places the last picked colour.
- **Share forbidden** of one position: empty cells the rule forbids its holder ÷ empty cells.
- **Strictness**: the average share over the positions, each position weighing the same; the same
  positions are used for every rule. **No legal cell**: the share of positions where the rule forbids
  every empty cell (its holder would skip).
- 2000 boards take about 3 minutes; seeds 1 and 2 agree within about 1 point per rule.
- The average hides how a rule forbids: a colour-gated rule such as R06 forbids everything or nothing
  (strictness = no-legal-cell share), so it scores low here and is harsh in play.

### Rule tiers

AI-vs-AI runs measure how much each rule restricts its holder (skip rate, legal cells per turn, win rate as the true rule). The results rank each rule Simple, Intermediate or Hardcore, stored in the rules library's Tier column.

**Method (provisional, #17).** Run the harness on at least 1000 matches (2000 at seed 1 gives each rule
about 180 holdings, so a win rate is good to about ±4 points) and the strictness check on 2000 boards.
The tier comes from the harness; strictness is a cross-check.

| Tier | Provisional threshold |
| --- | --- |
| Simple | win rate as the true rule ≥ 55% and skip rate < 5% |
| Hardcore | win rate as the true rule < 33% or skip rate ≥ 10% |
| Intermediate | everything else |

Why these numbers:

- Win rate as the true rule is the headline: it folds in both ways a rule hurts its holder, by
  skipping (R06, R15, R16) and by being easy to read (R17 skips on under 8% of turns, but every placement
  touches the next colour in the cycle, so the opponent rules the other rules out fast). In the 2000-match run the rules fall into
  three clusters with clear gaps: 61–74% (10 rules), 38–52% (6) and 4–28% (6). The thresholds sit in the
  gaps, so a few points of noise don't move a rule.
- Skip rate is a guard: a rule its holder skips under on 10% or more of turns is Hardcore whatever its
  win rate (each skip is a step to losing and a clue), and a Simple rule should almost never skip.
- Strictness agrees at the ends: every Simple rule forbids at most about 31% of cells; the two rules
  above the 60% band (R07, R11) are not Simple. It does not separate Intermediate from Simple well, since
  loose colour-gated rules (R02, R05, R10) score low but are read quickly through colour picks.
- Re-measure when the AI changes (M3 levels): the win rates depend on how the AI picks colours and
  deduces.

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
| `Deduction` (`ai/deduction.gd`) | The opponent's rules not yet ruled out (`candidates(view)`), in deck order | Hard elimination: a placement rules out the rules it breaks, a skip the rules that would have allowed a cell in that colour. Each event is judged on the position just before it (`MatchPosition.before`), so rules that read rows, the last ball or the board see what the match saw. Stateless: recomputed from the view's history on every call, so nothing to reset on a rematch |
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
| `StrictnessCheck`, `run_strictness.gd` | The strictness check and its command-line entry (`--boards`, `--seed`; defaults 2000 and 1); see "Strictness check" |

- The summary: matches finished out of matches played; first player's wins, losses and draws; how
  matches ended (right guess, wrong guess, third skip, forced guesses); average turns per match; and per
  true rule, how often it was held, its holders' skip rate, win rate and wins / losses / draws.
- `Harness.play_out` is its own synchronous loop, not `MatchDriver`: no pauses, no signals, no awaits.
- Unfinished-match guard: the loop gives up on a match if an AI returns no command, the match rejects
  a command, or the match runs past `Harness.MAX_COMMANDS` (500) commands. A given-up match counts as
  played but not finished, and the script exits with code 1 if any match didn't finish (or an argument
  is bad), 0 otherwise.
- Same seed, same output. 100 matches take about 40 s (about 0.4 s a match).

## Tests

GUT tests in `test/`, one folder per code folder, run headless (the command is in `CLAUDE.md`). They test
through the public seams only: the match (commands in; phase, result, history and `PublicView` out),
`RuleChecker` (rule data, position, holder and colour in; legal or not, legal cells out), the AI
(`PublicView` in, `Command` out), the harness, and scene-free helpers such as `MatchSetup` and
`MatchEndSummary`. Every RNG is seeded. `test/helpers/fixtures.gd` builds rule books, decks and
matches, including permissive rules written as data.

CI (`.github/workflows/ci.yml`) runs the suite, a short harness and the Playwright web tests on an exported web
build for every pull request and every push to `master`; on `master` it then pushes that tested build to itch.io
with butler.

## Web build

The first release is the web export on itch.io. Commands and CI settings are in `CLAUDE.md` ("Web tests", "CI");
what the build reaches and ships is in [release-audit.md](release-audit.md).

- **Preset:** "Web" in `export_presets.cfg`, exporting to `build/web/index.html` (gitignored). The `nothreads`
  template (thread support off), so the host needs no cross-origin isolation headers (no SharedArrayBuffer).
  Canvas resize policy adaptive, PWA off. The exclude filter keeps tests, harness, GUT, docs, `web-test/` and
  `.claude/` out of the pack; the include filter adds `assets/fonts/OFL.txt` for the Licences card.
- **Version:** `config/version` in `project.godot` (0.2.0), shown in the main menu's corner. CI's deploy stamps it
  `0.2.0+<short sha>` so a build on itch can be traced to its commit.
- **Storage:** `user://` (settings, saved decks) lives in the browser's IndexedDB.
- **Web-related autoloads:**
  - `WebMarkers` prints `[ballen] …` console lines on scene changes and key events (web builds only) for the
    tests, as the canvas has no DOM to inspect.
  - `RotateHint` covers the screen with "Rotate your device" and takes input while the screen is taller than
    wide (`RotateHint.should_show(size)`), in every build, until the portrait layout exists.
  - `SymbolFont` adds the bundled Noto Sans Symbols as a fallback of the default font: the web has no system fonts
    for the rule texts' arrows.
- **Touch:** every tap target is at least 44 px at 1280×720; small glyphs (✗, ◀ ▶) are drawn, not typed.
- **Web tests:** Playwright in `web-test/` plays the export in Desktop Chrome, Pixel 7 and iPhone 15 (WebKit) in
  landscape with touch, and Desktop Firefox: it loads with WebGL2 and no console errors, a match starts, a ball
  can be dragged (mouse; touch through CDP on Chromium, script-made touch events on WebKit), portrait shows the
  rotate hint, and a saved deck survives a reload. Clicks use the run-ballen skill's layout coordinates.

## Daily duel

- Seed a deterministic RNG from the UTC date (e.g. `hash("ballen-daily-" + date)`) for the AI's deck, its true rule, its colour choices and who starts, so every player faces the same opponent.
- The AI's own choices during the duel draw from that seeded RNG; the player's moves do not change the seed.
- One attempt per day and the streak are stored locally for the first release.

## Open technical questions

- [ ] Board representation: 64-bit bitmasks (36 cells) for speed in Hard's search?
- [x] Threads on the web export need cross-origin isolation: the web build uses the `nothreads` template (see Web
  build).
- [x] Save format and location for decks: rule ids in `user://decks.json` (see Saved decks).
