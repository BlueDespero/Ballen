# Ballen

Godot 4.7, GDScript, static typing. GL Compatibility renderer.

Use Godot 4 APIs and syntax only — never Godot 3 (e.g. `await` not `yield`,
`CharacterBody2D` not `KinematicBody2D`, `@export`/`@onready` annotations,
`signal.emit()` / `signal.connect(callable)`, `PackedVector2Array`, etc.).

## Design

- `docs/game-design-document.md` is the source of truth for game rules and scope. Read it before
  changing gameplay, and flag any code that contradicts it.
- `docs/technical-design.md`: architecture, rules engine (parts, data format) and AI implementation notes.
- `docs/rules-library.md`: catalogue of placement rules with status and strictness; update it when
  adding or changing a rule.
- `docs/ai-decision-theory-research.md` explains the AI opponent's design (belief updating,
  colour picks, guessing, difficulty levels).
- `docs/release-audit.md`: what the web build reaches (network, files, autoloads) and ships, licences, known
  gaps; update it when adding network, file or OS access, an autoload or an asset, and re-run its checklist
  before each public release.

## Conventions

- Type everything: variables (`var x: int`), parameters, and return types (`-> void`).
- Tabs for indentation.
- Autoloads (see `project.godot`): `EventBus` (signals), `Constants` (ball colors), `Settings` (`game_settings.gd`:
  player settings saved in `user://settings.cfg`; read them there and listen to `Settings.changed`), `WebMarkers`
  (`gui/web_markers.gd`: in web builds only, prints `[ballen] …` console markers for the web tests, from scene
  changes and `EventBus` signals), `RotateHint` (`gui/rotate_hint.gd`: covers the screen and blocks input while it
  is taller than wide), `SymbolFont` (`gui/symbol_font.gd`: adds the bundled Noto Sans Symbols as a fallback of the
  default font, for arrows the web build has no system font for). Turn state lives in the match.

## Tests

GUT 9.7.1 (`addons/gut`, config `.gutconfig.json`). Tests are `test/**/test_*.gd`, extending `GutTest`.
Run the whole suite headless from the repo root; exit code 0 means every test passed:

```powershell
godot --headless --path . --import *> $null; godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

In Git Bash, call `"$HOME/bin/godot.cmd"` instead of `godot` and redirect with `> /dev/null 2>&1`.

Keep the import step: it registers new `class_name`s (and, in a fresh worktree, GUT's own). Skip it and
GUT runs nothing yet exits 0, or a test using a new class fails to load. `test/post_run_hook.gd` turns a
test script that fails to load into exit code 1.

## AI-vs-AI harness

Plays N matches between two AIs with random decks, headless and with no pauses, and prints balance numbers
(results, end reasons, average turns, skip and win rate per true rule). Same seed, same output; exit code 1 if
any match didn't finish. From the repo root, after the import step above:

```powershell
godot --headless --path . -s harness/run_harness.gd -- --matches 100 --seed 1
```

## Strictness check

Measures every built rule on the same seeded random boards and prints its strictness (average share of empty cells
it forbids), the share of boards where it leaves no legal cell, and whether it is inside the GDD's 20–60% band.
Same seed, same output. From the repo root, after the import step (about 3 minutes for 2000 boards):

```powershell
godot --headless --path . -s harness/run_strictness.gd -- --boards 2000 --seed 1
```

Rule tiers combine it with a large harness run (1000+ matches); method and thresholds in
`docs/technical-design.md` ("Rule tiers").

## Web tests

Playwright plays the web export in Desktop Chrome, Pixel 7 and iPhone 15 (WebKit) in landscape with touch, and
Desktop Firefox. The game prints `[ballen] …` console markers in web builds (`WebMarkers`) and the tests wait for
them; clicks are 1280×720 layout coordinates (run-ballen skill) scaled to the canvas. From the repo root, after
the import step (`build/` is gitignored; Godot needs the folder to exist):

```powershell
New-Item -ItemType Directory -Force build/web > $null; godot --headless --path . --export-release "Web" build/web/index.html
cd web-test; npm ci; npx playwright install; npx playwright test
```

`serve.mjs` serves `build/web` on port 8137 (`PORT` to change it); `--project=desktop-chrome` runs one browser.

## CI

`.github/workflows/ci.yml`, on GitHub Actions (Godot 4.7.1 on Linux):

- `test`, on every push and pull request: import step, GUT suite, harness with `--matches 20 --seed 1`.
- `deploy`, on pushes to `master` after `test` passes: stamps `config/version` with `+<short sha>`, exports Web,
  runs the web tests in all four browsers, then `butler push build/web <ITCH_GAME>:html5`. Failing web tests stop
  the push (the Playwright report is uploaded as an artifact).

Deploy needs, under the repo's Settings > Secrets and variables > Actions: the secret `BUTLER_API_KEY` (an itch.io
API key) and the variable `ITCH_GAME` (`user/game`). Without them its first step fails and names what is missing.

## Commits

IMPORTANT: history must read as a series of small, self-contained changes.

- One logical change per commit: a behaviour plus its tests, a refactor, a rename, a doc update. Never mix
  them. If the message needs "and", split the commit.
- Every commit builds and passes the GUT suite. In TDD, commit after green (test and implementation
  together); commit a refactor separately.
- Message: imperative subject of 72 characters or fewer (e.g. "Add skip rule to turn flow"), a blank line,
  then why the change was needed if it isn't obvious. Reference the ticket (e.g. "Refs #12").
- No "WIP", "fix typo" or "address review" commits in final history: fold them into the commit they fix
  with `git commit --fixup <sha>` and `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>`.
- Keep history linear: rebase ticket branches onto the integration branch and fast-forward merge. No merge
  commits, except a branch merged by a person on GitHub.
- Never rewrite commits that are already on `master`, and never force-push `master`.

## Layout

- `main.tscn` (main menu) / `main_game.tscn` + `main_game.gd` (match scene) — entry scenes
- `gui/` — board, ball, colour picker, guess button, rules panel, pre-match panel, match-end screen,
  colour-blind ball symbols (`BallSymbol`), larger text (`TextScale`), rotate hint, rule tier badges (`TierBadge`),
  the menus' animated board backdrop (`BoardBackdrop`), shared colours and labels (`Palette`),
  menus (`gui/menus/`: main menu, Decks screen and deck editor, Settings screen with Credits)
- `model/` — game model: `Match` (passive state machine), `MatchPosition`, `Board`, `Deck`, `Command`,
  `HistoryEntry`, `MatchResult`, `PublicView`, `Controller`, `HumanController`, `MatchDriver`,
  `MatchSetup`, `DeckStore` (saved decks), `DeckDraft` (deck editor); plain `RefCounted`, no scene nodes
- `rules/` — rules engine: `RuleBook`, `Rule`, `Parts`, `GroupParts`, `PlacementContext`, `RuleChecker`;
  rule and template data in `rules/data/`
- `ai/` — `AIController`, `Deduction`, `GuessPolicy`, `ColourPickStrategy`
- `harness/` — AI-vs-AI harness: `Harness` (plays matches), `MatchRecord`, `HarnessStats`, `run_harness.gd`;
  strictness check: `StrictnessCheck`, `run_strictness.gd`
- `assets/` — Kenney art assets
- `test/` — GUT tests, one folder per code folder, shared fixtures in `test/helpers/`;
  `addons/gut/` — vendored GUT 9.7.1
- `web-test/` — Playwright tests of the web export (own `package.json`): `serve.mjs`, `playwright.config.ts`,
  `tests/` (`game.ts` drives the canvas)

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for BlueDespero/Ballen (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the root, ADRs in `docs/adr/`. See `docs/agents/domain.md`.
