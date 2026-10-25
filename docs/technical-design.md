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
| Game model | Board, turn order, colour picks, skips, guesses, move history | Plain GDScript classes, no scene nodes |
| Rules engine | Templates, parts (selectors, filters, conditions, combiners), evaluation | Pure functions over a placement context; rules loaded from JSON-ready data |
| AI | Rule choice, placement, colour picks, deduction, guessing | Receives a public view only; Easy, Normal, Hard |
| Scenes / UI | Board (`gui/balls_board.gd`), ball drag (`gui/ball.gd`), rules box, menus | Show the model and send player actions; never decide legality themselves |
| Autoloads | `EventBus` (global signals), `Constants` (colour table), `Utils` (turn state) | `Utils.player_turn` moves into the game model |
| Online (later) | Both true rules; checks every move | Server-authoritative; clients never receive the opponent's true rule |

### Key decisions

- `valid_placement()` in `gui/ball.gd` asks the game model instead of checking rules itself.
- `rules/baserule.gd` (`class_name Rule`) becomes the base of the parts system and the
  custom-script fallback.
- The AI gets a `PublicView` object without the opponent's `true_rule` field. Unit-test that it
  cannot reach hidden state.

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

### Data format

A rule is a **template plus the values in its blanks**. The template holds the hand-written player
text ("Ball can't be placed in the same ___ as ___") and maps to parts underneath. Built-in and
player-made rules share one JSON-ready format:

```json
{ "template": "not_same_line_as", "values": { "axis": "row", "target": "same_colour" } }
```

The catalogue of planned rules lives in [rules-library.md](rules-library.md).

### Evaluation

- A rule is a pure function: `(context) -> bool` (pass / fail). No side effects, no scene access.
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
and summarised in the README's "How the AI thinks". Implementation notes:

- Exact Bayesian belief over the opponent's 5 rules, with a hard elimination mask and soft scores in
  log space.
- Easy and Normal use heuristics plus at most one-step lookahead (well under a frame).
- Hard adds Monte Carlo tree search keyed on public history, spread across frames or a thread, and keeps searching during the player's turn.
- AI thinking pause: up to 5 s, scaled with decision difficulty; Hard adds random jitter so pauses carry no information.
- A headless AI-vs-AI harness tunes randomisation and difficulty.

## Daily duel

- Seed a deterministic RNG from the UTC date (e.g. `hash("ballen-daily-" + date)`) for the AI's deck, its true rule, its colour choices and who starts, so every player faces the same opponent.
- The AI's own choices during the duel draw from that seeded RNG; the player's moves do not change the seed.
- One attempt per day and the streak are stored locally for the first release.

## Open technical questions

- [ ] Board representation: 64-bit bitmasks (36 cells) for speed in Hard's search?
- [ ] Threads on the web export need cross-origin isolation; check against the chosen host (itch.io).
- [ ] Save format and location for decks (local storage on web, user:// on mobile).
