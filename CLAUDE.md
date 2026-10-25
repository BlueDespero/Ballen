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

## Conventions

- Type everything: variables (`var x: int`), parameters, and return types (`-> void`).
- Tabs for indentation.
- Autoloads (see `project.godot`): `EventBus` (signals), `Constants` (ball colors), `Utils` (turn state).

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

- `main.tscn` / `main_game.tscn` — entry scenes
- `gui/` — ball, board, rules UI scenes and scripts
- `assets/` — Kenney art assets
- `test/` — GUT tests; `addons/gut/` — vendored GUT 9.7.1

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for BlueDespero/Ballen (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the root, ADRs in `docs/adr/`. See `docs/agents/domain.md`.
