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

## Layout

- `main.tscn` / `main_game.tscn` — entry scenes
- `gui/` — ball, board, rules UI scenes and scripts
- `rules/` — rule logic (`baserule.gd`, `class_name Rule`)
- `assets/` — Kenney art assets
