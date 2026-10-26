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
# Menu -> Single Player -> (pick the AI's first colour if you go second) -> wait for your turn
# -> drag your ball onto cell (2,2) -> pick red for the AI -> wait for its turn -> screenshot
godot --path . -s .claude/skills/run-ballen/driver.gd -- wait:10 click:640,305 wait:120 click:624,660 until:Layout/PlayerBall:draggable=true drag:440,660,400,320 wait:5 get:Layout/Status:text click:624,660 until:Layout/PlayerBall:draggable=true ss:turn
```

Prints `Layout/Status.text = Pick the colour of the AI's next ball. That ends your turn.` and writes
`.claude/skills/run-ballen/out/turn.png` (gitignored). Exit code 0; 1 on an unknown command.

| command | what it does |
|---|---|
| `wait:N` | let N frames pass |
| `until:NODE/PATH:prop=VALUE` | wait until `str(prop) == VALUE`, at most 600 frames; prints `met` or `TIMED OUT` |
| `click:X,Y` | left press + release at viewport pixel X,Y |
| `press:X,Y` / `release:X,Y` | left press, or release, at X,Y; put `wait:N` between them to hold |
| `drag:X1,Y1,X2,Y2` | press at X1,Y1, move there in 10 steps, release at X2,Y2 |
| `touch:X1,Y1,X2,Y2` | the same drag with a finger (screen touch and drag events) |
| `ss:NAME` | save `.claude/skills/run-ballen/out/NAME.png` (needs a window) |
| `tree` | print the current scene tree |
| `get:NODE/PATH:prop` | print a property; path is relative to the current scene |
| `scene:res://…tscn` | switch scene directly, skipping the menu |
| `quit` | exit (appended automatically) |

**State-only checks without a window** (doesn't touch your mouse; `ss` errors and is skipped).
Headless runs read state only: clicks, drags and touches reach no control, so play needs a window.

```powershell
godot --headless --path . -s .claude/skills/run-ballen/driver.gd -- scene:res://main_game.tscn wait:120 get:Layout/Status:text get:Layout/PlayerBall:draggable
```

### Layout (landscape: 1280×720 base, stretch `canvas_items`, aspect `expand`)

At the default window size viewport px = window px. Another size (`--resolution WxH`) scales the
layout and centres it, so these coordinates no longer hold.

- Main menu buttons (centre x 640): Single Player y=305, Loadout y=342, Options y=378, Quit y=414.
- The match scene's nodes sit under `Layout` (a centred 1280×720 control).
- Board: `Layout/Board`, top-left (200,120), 80 px cells, the AI's side on top (y=0), yours at the
  bottom (y=5). Cell `(x,y)` centre is `(240+80*x, 160+80*y)`. Legal cells glow on your turn.
- Row numbers 1–6 at x≈176–196, left of the board, counted from the first player's side: 1 at the
  bottom when you go first, at the top when the AI does.
- Your waiting ball: `Layout/PlayerBall`, centre (440,660); `draggable` is true on your placement turn.
  A drop on a non-legal cell or off the board snaps it back to `position (408,628)`.
- Colour picker for the AI's next ball, right of your ball at y=660: yellow x=512, blue x=568, red x=624,
  green x=680. Enabled only when you pick (your post-placement step, or the first colour if you go second).
- The AI's waiting ball: `Layout/AIBall`, centre (440,60); it flies onto its cell after a 0.5–1.5 s pause.
- `Layout/Status` (left column) says whose turn it is and what to do; read it with `get`.
- Rules panel: `Layout/RulesPanel`, x 744–1264. The AI's rules on top (row centres y=94, 142, 190,
  238, 286; click x≈1000 to select one, again to clear; `get:Layout/RulesPanel:selected_rule_id`),
  then the Guess slot (hint text and the Guess button, centre (1173,344)), yours below
  (y≈454–646) with the true one highlighted.
- Guess: select an AI rule, then hold the button about 1 s: `press:1173,344 wait:90 release:1173,344`.
  Releasing earlier cancels. `Layout/RulesPanel:guess_enabled` is true in your guess windows (start of
  your turn, after placing until your colour pick); the button also needs a selected rule. The ring's
  fill is `Layout/RulesPanel/Sections/GuessSlot/GuessButton:progress` (0–1). Frames run faster than
  60 per second in driver runs, so pick a short `wait` (≈10) to catch the ring half full. The result
  then shows in `Layout/Status`, e.g. `You named R04 as the AI's true rule: right. You win!`
  (the scene's fixed true rule for both players is R04).
- Free room kept for later tickets: skip pips beside each panel title (`%AISkipPips`,
  `%PlayerSkipPips`).
- After Single Player, the current scene is `MainGame`; before it, `Main`
  (paths like `MainMenu/GameButtons/SinglePlayerButton`).

## Run (human path)

Open `project.godot` in the Godot editor and press Play (F5), or:

```powershell
godot --path .   # window opens on the main menu; close it to stop
```

## Test

GUT suite, headless (details and gotchas in `CLAUDE.md`, section Tests). Exit code 0 = all passed.

```powershell
godot --headless --path . --import *> $null; godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

## Gotchas

- **Windowed runs take over your real mouse cursor**: the driver `Input.warp_mouse`s as well as
  injecting events, because `Viewport.get_mouse_position()` reads the OS cursor. Keep your hands off
  the mouse during a windowed run.
- **`ss` under `--headless` used to hang forever**: nothing draws, so `frame_post_draw` never fires.
  The driver now refuses `ss` when headless; use a windowed run for screenshots.
- **Every match is random**: the coin toss, the AI's colours, cells and pauses are unseeded. If you go
  second, the first thing the match waits for is your colour pick (`Layout/Status` says so), so
  `until:Layout/PlayerBall:draggable=true` times out; click a colour first. Clicking a disabled picker
  does nothing, so `wait:120 click:624,660` at the start is safe either way.
- **Skips aren't built yet** (#47): with R04 as both true rules the 16 inner cells fill up and the
  match stops, with `Layout/Status` saying who has no legal cell.
- Files under `.claude/` are invisible to Godot's import (dot-folder), so `out/` PNGs and the driver
  get no `.uid`/`.import` files. `-s` and `res://.claude/...` paths still load fine.

## Troubleshooting

- **`godot : The term 'godot' is not recognized`** in a shell started before the PATH change:
  `$env:Path += ";$env:USERPROFILE\bin"`, or restart VS Code.
- **Run never exits after `ss:`**: you passed `--headless` with an old copy of the driver. Kill the
  `Godot_v4.7.1-stable_win64*` process you started (not the editor) and drop `--headless`.
