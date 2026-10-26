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
# Menu -> Single Player -> tap R03 to make it your true rule -> wait out the coin toss
# -> (pick the AI's first colour if you go second) -> wait for your turn
# -> drag your ball onto cell (2,2) -> pick red for the AI -> wait for its turn -> screenshot
godot --path . -s .claude/skills/run-ballen/driver.gd -- wait:10 click:640,305 wait:30 click:428,364 wait:150 click:624,660 until:Layout/PlayerBall:draggable=true drag:440,660,400,320 wait:5 get:Layout/Status:text click:624,660 until:Layout/PlayerBall:draggable=true ss:turn
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
godot --headless --path . -s .claude/skills/run-ballen/driver.gd -- scene:res://main_game.tscn wait:60 get:Layout/Status:text get:Layout/PreMatch:visible
```

Headless, the match never starts: it waits on the pre-match tap, which needs a window.

### Layout (landscape: 1280×720 base, stretch `canvas_items`, aspect `expand`)

At the default window size viewport px = window px. Another size (`--resolution WxH`) scales the
layout and centres it, so these coordinates no longer hold.

- Main menu buttons (centre x 640): Single Player y=305, Loadout y=342, Options y=378, Quit y=414.
- The match scene's nodes sit under `Layout` (a centred 1280×720 control).
- Pre-match overlay: `Layout/PreMatch`, over the board (x 176–680, y 120–600), visible when the scene
  opens. Your starter deck as buttons (x 200–656, centre x≈428): R01 y=306, R03 y=364, R05 y=422,
  R08 y=480, R18 y=538 (nodes `Layout/PreMatch/Choice/RuleButtons/R01` …). Tapping one makes it your
  true rule and starts the match; the overlay then shows the coin toss ("Coin toss: you go first" /
  "…the AI goes first") for 2 s (`wait:150` covers it) and hides. Both decks are in the rules panel
  from the start; `Layout/Status` reads `Choose your true rule.`, then `You go first.` /
  `The AI goes first.` during the toss.
- Board: `Layout/Board`, top-left (200,120), 80 px cells, the AI's side on top (y=0), yours at the
  bottom (y=5). Cell `(x,y)` centre is `(240+80*x, 160+80*y)`. Legal cells glow on your turn.
- Row numbers 1–6 at x≈176–196, left of the board, counted from the first player's side: 1 at the
  bottom when you go first, at the top when the AI does.
- Your waiting ball: `Layout/PlayerBall`, centre (440,660); `draggable` is true on your placement turn.
  A drop on a non-legal cell or off the board snaps it back to `position (408,628)`.
- Colour picker for the AI's next ball, right of your ball at y=660: yellow x=512, blue x=568, red x=624,
  green x=680. Enabled only when you pick (your post-placement step, or the first colour if you go second).
- The AI's waiting ball: `Layout/AIBall`, centre (440,60); it flies onto its cell after a 0.5–1.5 s pause.
- A skipped ball appears on its owner's waiting spot in the skipped colour and shrinks and fades
  (0.4 s); the skip pips fill after it.
- `Layout/Status` (left column) says whose turn it is and what to do, and names a skipped colour
  (`You had no legal cell for red, so your ball was skipped. …`); read it with `get`.
- Rules panel: `Layout/RulesPanel`, x 744–1264. The AI's rules on top (row centres y=94, 142, 190,
  238, 286; click x≈1000 to select one, again to clear; `get:Layout/RulesPanel:selected_rule_id`),
  then the Guess slot (hint text and the Guess button, centre (1173,344)), yours below
  (y≈454–646) with the true one highlighted. Three skip pips at the right of each title
  (`%AISkipPips` y≈48, `%PlayerSkipPips` y≈408), filled red per skip.
- Guess: select an AI rule, then hold the button about 1 s: `press:1173,344 wait:90 release:1173,344`.
  Releasing earlier cancels. `Layout/RulesPanel:guess_enabled` is true in your guess windows (start of
  your turn, after placing or skipping until your colour pick); the button also needs a selected rule. The ring's
  fill is `Layout/RulesPanel/Sections/GuessSlot/GuessButton:progress` (0–1). Frames run faster than
  60 per second in driver runs, so pick a short `wait` (≈10) to catch the ring half full. A guess ends
  the match (the AI's true rule is random, so a guess is right about one time in five).
- Match end: `Layout/MatchEnd` (`visible` turns true) dims the layout and shows a card over the board;
  the rules panel stays lit, marks the AI's true rule and says the match is over. Read
  `Layout/MatchEnd/Centre/Card/Content/Headline:text` (`You win`, `You lose`, `Draw`) and
  `.../Content/Reason:text` (e.g. `You named R04 "Never on the edge", the AI's true rule.`);
  `Layout/Status` is empty. Main menu button centre (364,540); it returns to `Main`. To guess the
  AI's first rule and go back to the menu:
  `until:Layout/RulesPanel:guess_enabled=true click:1000,94 press:1173,344 wait:90 release:1173,344 wait:40 ss:end click:364,540`.
  A third skip ends the match the same way; its reason reads `You skipped for the third time.` /
  `The AI skipped for the third time.`
- Full board: the placement that fills it brings no colour pick. When your forced guess is due,
  `Layout/RulesPanel:seal_enabled` is true, the Seal button shows and `Layout/Status` starts
  `The board is full.`; select an AI rule and hold Seal like Guess. If you filled the board, Guess
  stays too (`guess_enabled` true; right wins, wrong loses) and Seal sits left of it, centre
  (1022,356); otherwise Seal alone takes Guess's place, centre (1188,344). A sealed guess stays
  sealed (the status says so) until the AI's is in, then the match-end screen shows `You win`,
  `You lose` or `Draw`. A full board takes 36 placements; to
  check the screen quickly, temporarily start `main_game.gd`'s match from a nearly full
  `MatchPosition` (see `Fixtures.nearly_full_match` in `test/helpers/fixtures.gd`) and don't commit it.
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
- **Every match is random**: the AI's deck and true rule, the coin toss, the AI's colours, cells and
  pauses are unseeded (your starter deck is fixed). If you go second, the first thing the match waits
  for is your colour pick (`Layout/Status` says so), so `until:Layout/PlayerBall:draggable=true` times
  out; click a colour first. Clicking a disabled picker does nothing, so `wait:150 click:624,660` right
  after the pre-match tap is safe either way.
- **Reaching skips**: you can't see legal cells from the driver, so play blind. Each turn:
  `until:Layout/PlayerBall:draggable=true`, then drag onto every cell, `wait:12` after each (illegal
  drops snap back; once one lands the ball is no longer draggable and the rest do nothing), then
  `until:Layout/ColourPicker:enabled=true` and click a colour. On a turn you skip, the first `until`
  times out (harmless: your ball has already dissolved) and the picker opens for your colour. Skips
  come late (a blind R03 game went 12 turns without one) and depend on the AI's random rule and
  colours, so allow many turns, and call the Godot exe directly rather than the `godot.cmd` shim: a
  long command list overflows cmd.exe's 8 KB line. Read `Layout/Status` to see who skipped.
- Files under `.claude/` are invisible to Godot's import (dot-folder), so `out/` PNGs and the driver
  get no `.uid`/`.import` files. `-s` and `res://.claude/...` paths still load fine.

## Troubleshooting

- **`godot : The term 'godot' is not recognized`** in a shell started before the PATH change:
  `$env:Path += ";$env:USERPROFILE\bin"`, or restart VS Code.
- **Run never exits after `ss:`**: you passed `--headless` with an old copy of the driver. Kill the
  `Godot_v4.7.1-stable_win64*` process you started (not the editor) and drop `--headless`.
