# Milestone 1 — Playable prototype

**Goal:** one full match of Ballen against a simple AI, on the real rules engine, playable in the Godot
editor and verified by automated tests. This is milestone 1 of section 8 (Production) of the
[game design document](../game-design-document.md).

Read first, in this order: [game-design-document.md](../game-design-document.md) (sections 2 and 5),
[technical-design.md](../technical-design.md), [rules-library.md](../rules-library.md),
and the README's "How the AI thinks". The design document wins any conflict; flag conflicts instead of
silently picking a side.

## In scope

### 1. Test harness first

- Add [GUT](https://gut.readthedocs.io/) (the Godot 4 release, 9.x) under `addons/gut/`, with a
  `.gutconfig.json` and tests in `res://test/`.
- Tests must run headless from the command line, e.g.
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` (exit code 0 = all pass).
  Find the local Godot 4 executable first; if it isn't on PATH, ask for its path once.
- Add the exact test command to `CLAUDE.md` so every later session uses it.

### 2. Game model (plain GDScript, no scene nodes)

Pure `RefCounted` classes that hold the whole match, so the AI, the UI and a future server share them:

- 6 × 6 board; balls with a colour (yellow, blue, red, green) and an owner.
- Each player: 5 rules, one marked true; skip count; the colour they must place next.
- Turn flow exactly as the turn-loop diagram in GDD section 2:
  1. Turn starts in the colour the opponent picked (the match's first colour is picked by the player
     going second; who starts is a coin toss).
  2. Optional guess **before** placing.
  3. If any cell is legal under the player's true rule, they must place on one; otherwise the ball is
     removed automatically and the player gains a skip (3 skips = loss).
  4. Optional guess **after** placing or skipping. Right guess wins, wrong guess loses.
  5. If the board is full, both players must guess: exactly one right wins, otherwise a draw.
  6. Pick the colour the opponent places next.
- Move history: every placement, skip (with its colour) and guess, so a past board can be rebuilt.
- A `PublicView` that exposes everything except the opponent's true rule. The AI receives only this.

### 3. Rules engine

As specified in technical-design.md: rules are data (template + blank values) built from parts
(selectors, filters, conditions, combiners) evaluated as pure functions over a placement context.

- Implement the parts needed for these rules from the rules library, all of which should be Simple:
  **R01, R03, R04, R05, R07, R08, R10, R18**.
- Each rule has its hand-written player text from the rules library.
- Replace the stub in `rules/baserule.gd` (R12) or keep it only as the custom-script fallback base.
- Update the rules library: Status → Built for each rule implemented.

### 4. Simple AI (one level)

Uses only `PublicView`. Pure logic, testable without scenes:

- **Deduction:** hard elimination: an opponent rule is ruled out when a placement breaks it, or when a
  skip happened although that rule would have allowed a cell.
- **Placement:** among its legal cells, prefer cells that satisfy as many of its own 5 rules as possible
  (gives little away); break ties randomly.
- **Colour pick:** choose the colour expected to rule out the most remaining opponent candidates.
- **Guessing:** guess when only one candidate remains; on a forced guess, name the most likely one.
- Thinking pause: a short delay before acting is enough for now (difficulty-scaled pauses come later).

Easy / Normal / Hard, Bayesian beliefs and tree search are **later milestones**; structure the code so
they can be added without rewriting the model.

### 5. Playable scene (landscape)

- Switch the project to landscape: 1280 × 720 base, stretch mode `canvas_items`, aspect `expand`.
- Board in the centre; the opponent's 5 rules in a side panel on one side, yours (true one marked) on
  the other; skip counters for both.
- Your legal cells glow for your whole turn; drag and drop with mouse (touch must also work); a drop on
  any other cell snaps back.
- Colour picker for the opponent's next ball.
- Guess: select one of the opponent's rules, then press and hold Guess for about 1 s (a ring fills;
  release early to cancel). Available at the start of your turn and after placing or skipping only.
- Skips: the ball visibly disappears and the skip counter updates.
- Pre-match: you get a fixed starter deck for the prototype and tap one of its rules to make it true;
  the AI gets a random 5-rule deck from the implemented rules.
- Match end: result (win, lose, draw), both true rules revealed, Rematch and Quit buttons.
- Use the existing Kenney assets; art, audio and polish come later.

### 6. AI-vs-AI harness

A headless script that plays N full matches between two AIs with random decks and reports: matches
finished, wins / losses / draws, average turns, skip rate per rule. It must finish 100 matches with no
errors. This is the seed of the tuning and rule-tier tool from technical-design.md.

## Out of scope for this milestone

Deck builder, tutorial and How to Play, Collection, history arrows UI, notes marks, daily duel, settings
and accessibility, audio, the Kenney asset swap, difficulty levels, online play, ads, the portrait
layout. Don't build them; leave clean seams where they will attach.

## Definition of done

1. The GUT suite passes headless (exit code 0), covering: the turn flow including skips, both guess
   windows, the third-skip loss and the full-board forced guess; every implemented rule (legal and
   illegal examples); hard elimination in the AI; `PublicView` never exposing the opponent's true rule.
2. The AI-vs-AI harness completes 100 matches with no errors; paste its summary into the PR.
3. A full match against the AI is playable from the main menu's Single Player button, in landscape.
4. `CLAUDE.md` lists the test and harness commands; the rules library and technical design reflect what
   was built; anything that contradicts the GDD is listed in the PR as a question.
5. All work is on one branch with a pull request to `master`. Never push to `master` directly and never
   force-push `master`.
6. The branch history follows the commit rules in `CLAUDE.md`: small, self-contained commits that each
   pass the tests, linear history with no merge commits, so the PR can be merged with "Rebase and merge".
