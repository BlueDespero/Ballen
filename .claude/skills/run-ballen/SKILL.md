---
name: run-ballen
description: Run, launch, drive and screenshot Ballen (the Godot game). Use when asked to start or play the game, click through its menu, drag a ball onto the board, take a screenshot of the UI, inspect the running scene tree, or confirm a gameplay change works in the real game rather than only in tests.
---

Ballen is a Godot 4.7 game. Drive it with `.claude/skills/run-ballen/driver.gd`, a `SceneTree` script
that loads the main scene, then runs commands passed after `--` (click, drag, screenshot, read a node
property) and quits. All paths are relative to the repo root. Commands are PowerShell on Windows.

## Prerequisites

Godot 4.7.1 (the console build) reachable as `godot`. On this machine that's a shim,
`%USERPROFILE%\bin\godot.cmd`, pointing at
`C:\Users\cezar\Documents\Godotinstalers\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`.

```powershell
godot --version   # 4.7.1.stable.official.a13da4feb
```

## Setup

Once after a fresh clone (no `.godot/` yet), import assets. Takes a few seconds.

```powershell
godot --headless --path . --import
```

## Run (agent path)

One process per script of commands; read the `[driver]` lines on stdout, look at the PNGs.

```powershell
# Menu -> Single Player -> drag the ball onto the player board -> screenshot
godot --path . -s .claude/skills/run-ballen/driver.gd -- wait:10 click:256,297 wait:10 drag:30,670,170,470 wait:5 get:Ball:position ss:placed
```

Prints `Ball.position = (160.0, 480.0)` (snapped to the cell centre) and writes
`.claude/skills/run-ballen/out/placed.png` (gitignored). Exit code 0; 1 on an unknown command.

| command | what it does |
|---|---|
| `wait:N` | let N frames pass |
| `click:X,Y` | left press + release at viewport pixel X,Y |
| `drag:X1,Y1,X2,Y2` | press at X1,Y1, move there in 10 steps, release at X2,Y2 |
| `ss:NAME` | save `.claude/skills/run-ballen/out/NAME.png` (needs a window) |
| `tree` | print the current scene tree |
| `get:NODE/PATH:prop` | print a property; path is relative to the current scene |
| `scene:res://…tscn` | switch scene directly, skipping the menu |
| `quit` | exit (appended automatically) |

**Logic-only checks without a window** (doesn't touch your mouse; `ss` errors and is skipped):

```powershell
godot --headless --path . -s .claude/skills/run-ballen/driver.gd -- scene:res://main_game.tscn get:Ball/BallSprite:modulate get:Ball:position
```

### Layout (viewport is 512×704, no stretch, so viewport px = window px)

- Main menu buttons (centre x 256): Single Player y=297, Loadout y=334, Options y=370, Quit y=407.
- Board tiles are 64 px. Cell `(col,row)` centre is `(64*col+32, 64*row+32)`.
  Player board: cols 1–5, rows 6–10. Opponent board: cols 1–5, rows 0–4. Rule columns: cols 6–7.
- Ball spawn: `(30,670)`. Dropping outside the player board sends it back there.
- After Single Player, the current scene is `MainGame` (paths like `Ball`, `Board/PlayerBoard`).
  Before it, it's `Main` (paths like `MainMenu/GameButtons/SinglePlayerButton`, `MainGame/Ball`).

## Run (human path)

Open `project.godot` in the Godot editor and press Play (F5), or:

```powershell
godot --path .   # window opens on the main menu; close it to stop
```

## Test

No test suite yet. Milestone 1 (`docs/milestones/01-prototype.md`) adds GUT; once it exists, its
command lives in `CLAUDE.md`.

## Gotchas

- **Windowed runs take over your real mouse cursor.** `Viewport.get_mouse_position()` reads the OS
  cursor, not injected events, and `gui/ball.gd` follows it while dragging. So the driver
  `Input.warp_mouse`s as well as injecting events. Without it the ball flew to wherever the real
  cursor was (`Ball.position = (935.0, 544.0)`) and never got its release. Don't move the mouse during a
  windowed run.
- **`ss` under `--headless` used to hang forever**: nothing draws, so `frame_post_draw` never fires.
  The driver now refuses `ss` when headless; use a windowed run for screenshots.
- **The main menu is drawn on top of the game board**, which shows through it (see a menu
  screenshot). That's the current game, not a driver artefact.
- **Ball colour is random each run** (`main_game.gd`), so screenshots differ in colour; read
  `Ball/BallSprite:modulate` when it matters.
- Files under `.claude/` are invisible to Godot's import (dot-folder), so `out/` PNGs and the driver
  get no `.uid`/`.import` files. `-s` and `res://.claude/...` paths still load fine.

## Troubleshooting

- **`godot : The term 'godot' is not recognized`** in a shell started before the PATH change:
  `$env:Path += ";$env:USERPROFILE\bin"`, or restart VS Code.
- **Run never exits after `ss:`**: you passed `--headless` with an old copy of the driver. Kill the
  `Godot_v4.7.1-stable_win64*` process you started (not the editor) and drop `--headless`.
