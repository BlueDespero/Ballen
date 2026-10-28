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
# Menu -> Single Player -> tap R03 to make it your true rule -> Start -> wait out the coin toss
# -> (pick the AI's first colour if you go second) -> wait for your turn
# -> drag your ball onto cell (2,2) -> pick red for the AI -> wait for its turn -> screenshot
godot --path . -s .claude/skills/run-ballen/driver.gd -- wait:10 click:640,362 wait:60 click:368,428 wait:5 click:461,648 wait:150 click:624,660 until:Layout/PlayerBall:draggable=true drag:440,660,400,320 wait:5 get:Layout/Status:text click:624,660 until:Layout/PlayerBall:draggable=true ss:turn
```

Prints `Layout/Status.text = Pick the AI's next colour. That ends your turn.` and writes
`.claude/skills/run-ballen/out/turn.png` (gitignored). Exit code 0; 1 on an unknown command.

| command | what it does |
|---|---|
| `wait:N` | let N frames pass |
| `until:NODE/PATH:prop=VALUE` | wait until `str(prop) == VALUE`, at most 600 frames; prints `met` or `TIMED OUT` |
| `click:X,Y` | left press + release at viewport pixel X,Y |
| `press:X,Y` / `release:X,Y` | left press, or release, at X,Y; put `wait:N` between them to hold |
| `drag:X1,Y1,X2,Y2` | press at X1,Y1, move there in 10 steps, release at X2,Y2 |
| `touch:X1,Y1,X2,Y2` | the same drag with a finger (screen touch and drag events) |
| `key:NAME` | press and release a key by name (`Left`, `Right`, `Space`; `OS.find_keycode_from_string`) |
| `type:TEXT` | type TEXT into the focused control, e.g. a name field you clicked (quote it if it has spaces) |
| `ss:NAME` | save `.claude/skills/run-ballen/out/NAME.png` (needs a window) |
| `tree` | print the current scene tree |
| `get:NODE/PATH:prop` | print a property; path is relative to the current scene |
| `scene:res://…tscn` | switch scene directly, skipping the menu |
| `quit` | exit (appended automatically) |

**State-only checks without a window** (doesn't touch your mouse; `ss` errors and is skipped).
Headless runs read state only: clicks, drags and touches reach no control, so play needs a window.

```powershell
godot --headless --path . -s .claude/skills/run-ballen/driver.gd -- scene:res://main_game.tscn wait:60 get:Layout/MatchSetup:visible get:Layout/MatchSetup/Backdrop/Centre/Card/Content/LevelDescription:text
```

Headless, the match never starts: it waits on the match setup screen's Start, which needs a window.

### Layout (landscape: 1280×720 base, stretch `canvas_items`, aspect `expand`)

At the default window size viewport px = window px. Another size (`--resolution WxH`) scales the
layout and centres it, so these coordinates no longer hold.

- Main menu: the board backdrop (`MainMenu/Backdrop`, a `BoardBackdrop`) fills the screen, with the
  "Ballen" title (`MainMenu/Title`) above the buttons on a dark card. Buttons (centre x 640): Single
  Player y=362, Decks y=398, Options y=435, Quit y=471 (with Larger text on: 357, 397, 437, 477).
  The version (`MainMenu/Version`, `v` + `application/config/version`) sits in the bottom-right corner.
- Decks screen (Decks; scene `Decks`, `gui/menus/decks_screen.tscn`, or `scene:` it directly): one row
  per deck under `Margin/Card/Content/Scroll/DeckList` (`%DeckList`), named `Row0`, `Row1`, … in list
  order (Starter first, then saved decks in save order; the deck's name is in meta `deck_name`), row centres y=176, 240, 304, … (step 64). Each row shows the
  name, its 5 rule ids with tier dots (`<row>/Line/Rules`) and buttons `<row>/Line/Edit|Rename|Delete`
  at x≈850, 956, 1062; Starter has only `Copy` (1062). Back (245,640), New deck (1035,640); Escape =
  Back (to `Main`). Rename and Delete open `%Dialog` (centred card): `%DialogName` (selected, so typing
  replaces it), `%DialogHint` (the name problem), `%DialogCancel` (642,431) and `%DialogConfirm`
  (798,431; Delete's card is shorter: (798,404)), disabled while the name has a problem; Enter confirms,
  Escape cancels. Larger text moves rows down (≈222, 286) and the dialog buttons too: read
  `global_position` with `get:`.
- Deck editor (New deck, Edit or Copy; node `DeckEditor`, a child of `Decks`, covering it): paths under
  `DeckEditor/Margin/Card/Content`. Name field `Header/NameField` (650,58; click it, then `type:My deck`),
  counter `Header/Counter:text` (`3 / 5`; flashes red on a 6th pick, which does nothing), filter chips
  `Filters/Chips/All|Simple|Intermediate|Hardcore` at y=110 (x≈215, 355, 495, 635), the rule rows
  `Scroll/RuleList/R01` … (click x≈600; with All shown R01 y=164, R02 218, … step 54, R09 596 is the
  last one visible; scroll or filter for the rest; a picked row turns gold). Footer: `Footer/Hint:text`
  (`Pick 5 rules (3 picked)`, `Name the deck`, `A deck named X already exists`, empty when it can be
  saved), Cancel (947,660), Save (1113,660, `Footer/SaveButton:disabled`). Save or Cancel (or Escape)
  returns to the list. A saved deck lands in `user://decks.json`, **shared by every worktree and the
  player's game**: back up `%APPDATA%\Godot\app_userdata\Ballen\decks.json` before a run that saves
  and restore it (or delete it if there was none) afterwards.
- Settings screen (Options; scene `Settings`, `gui/menus/settings_menu.tscn`): a centred card,
  nodes under `Centre/Card/Content`: `VolumeRow/Volume` (slider, x 600–860, y≈172), switches
  `ColourBlindSymbols` (y≈243), `ReducedMotion` (y≈341), `GuessWithoutHolding` (y≈439), `LargerText`
  (y≈514); click x≈500 on the row. Credits (702,595), Back (857,595). Every change is saved to
  `user://settings.cfg` at once (`%APPDATA%\Godot\app_userdata\Ballen\settings.cfg`); Back or Escape
  returns to `Main`. Credits shows `Centre/CreditsCard` (its Back or Escape returns). Larger text makes
  the card taller, so these y values drift; read positions with `get:…:global_position` (headless runs
  centre the card in a 1280×1280 window: subtract 280 from y).
- Settings in a match: the match reads the `Settings` autoload when the scene opens. To play with an
  option on, write `settings.cfg` before the run (UTF-8 **without** BOM: PowerShell
  `[IO.File]::WriteAllText($cfg, "[accessibility]`n`nreduced_motion=true`n")`; `Set-Content -Encoding
  utf8` adds a BOM and the file is then ignored) and **delete it afterwards** so later runs start from
  the defaults. Keys: `[audio] volume` (0–1), `[accessibility] colour_blind_symbols`, `reduced_motion`,
  `guess_without_holding`, `larger_text`, `[hints] note_marks_seen` (see Note marks hint). With guess without holding, a click on Guess arms it
  (`…/GuessButton:armed` true, it reads Confirm) and a second click guesses. Larger text packs the rules
  panel tighter: e.g. with one wrapped AI rule and the Starter deck, AI rows y≈71–293 (40 px each,
  49 when wrapped, 2 apart), Guess ≈(1173,325), your rows y≈405–613 (hint gone; see the Rules panel
  note).
- The match scene's nodes sit under `Layout` (a centred 1280×720 control).
- Match setup screen: `Layout/MatchSetup`, covering the layout left of the rules panel (x 0–736) when
  the scene opens; the rules panel beside it already shows the AI's deck and yours (no true rule
  marked; it follows the deck picker). Its card is `Layout/MatchSetup/Backdrop/Centre/Card/Content`
  (x 48–688, y 30–690; with Larger text x 16–720, y 31–688) over the board backdrop
  (`Layout/MatchSetup/Backdrop/BoardBackdrop`). Deck picker (`DeckRow/DeckPicker`, an OptionButton: `Starter` first, then the saved decks)
  centre (434,122); click it, then the list's items at x≈226, y=162, 189, 216, … (step 27). AI level buttons
  (`LevelRow/LevelButtons/Easy|Normal|Hard`) at y=176: Easy x≈287, Normal x≈432, Hard x≈579; only
  Normal is enabled (and pressed), the others read "(coming soon)"; `LevelDescription:text` describes
  the level. Your deck's rules as toggle buttons (x 80–656, centre x 368; a long rule wraps onto two
  lines, moving the rows below it down): starter deck R01 y=378,
  R03 y=428, R05 y=478, R08 y=528, R18 y=578 (nodes `RuleButtons/R01` …); a tapped rule turns gold.
  Start (`Buttons/StartButton`, disabled until a rule is tapped) centre (461,648), Main menu centre
  (275,648). Start hides the card and shows the coin toss over the board ("Coin toss: you go first" /
  "…the AI goes first", `Layout/MatchSetup/CoinToss`) for 2 s (`wait:150` covers it), then
  `Layout/MatchSetup:visible` turns false. The rules panel marks your true rule with the toss;
  `Layout/Status` reads `You go first.` / `The AI goes first.` during it. To try
  another deck, save one on the Decks screen first (back up `decks.json`, see above).
- Board: `Layout/Board`, top-left (200,120), 80 px cells, the AI's side on top (y=0), yours at the
  bottom (y=5). Cell `(x,y)` centre is `(240+80*x, 160+80*y)`. Legal cells glow on your turn.
- Row numbers 1–6 at x≈176–196, left of the board, counted from the first player's side: 1 at the
  bottom when you go first, at the top when the AI does.
- Your waiting ball: `Layout/PlayerBall`, centre (440,660); `draggable` is true on your placement turn.
  A drop on a non-legal cell or off the board snaps it back to `position (408,628)`.
- Colour picker for the AI's next ball, right of your ball at y=660: yellow x=512, blue x=568, red x=624,
  green x=680. Enabled only when you pick (your post-placement step, or the first colour if you go second):
  then a yellow ring pulses around each button and `Layout/Status` contains `Pick the AI's next colour.`;
  otherwise the buttons are dimmed (`Layout/ColourPicker:enabled`).
- History view: `Layout/HistoryNav`, left of `You` under the board (x 200–336, y 642–678): ◀ centre
  (218,660), Live (268,660), ▶ (318,660); `key:Left` / `key:Right` do the same. ◀ (from the live
  board) shows the latest turn with a placement or skip, then earlier ones; ▶ past the latest returns to
  live. A past board rings that turn's ball (a skipped ball shows at its owner's waiting spot), fades
  the waiting balls, shows no glow, sets `Layout/PlayerBall:draggable` false and the skip pips as they
  were; `Layout/Status` reads `Turn 3 of 4: you placed blue. …` / `…the AI had no legal cell for blue,
  so the ball was skipped. …`. Only your own actions return to live: pressing your ball (the press
  then drags), a colour pick, Guess or Seal (these stay enabled as in the live match), Live, or ▶ past
  the latest turn. When the AI plays meanwhile the past board stays (its `of N` count grows) and Live
  lights up yellow and pulses (`get:Layout/HistoryNav:live_lit` true) until you return; the match
  ending returns to live. `Layout/HistoryNav/Live:disabled` is false only while viewing; the buttons
  are disabled before the match starts, during the AI's animations and once the match is over.
- The AI's waiting ball: `Layout/AIBall`, centre (440,60); it flies onto its cell after a 0.5–1.5 s pause.
- A skipped ball appears on its owner's waiting spot in the skipped colour with the note
  `No legal cell, skipped` left of the side name (`Layout/AISkipNote` / `Layout/PlayerSkipNote`,
  `visible` while shown), stays 1.5 s, then shrinks and fades with the note over 0.8 s; the skip pips
  fill after it. Meanwhile `Layout/Status` is empty, input is off and the match waits (no AI action):
  gate on `until:Layout/PlayerSkipNote:visible=false` before picking after your skip.
- `Layout/Status` (left column) says whose turn it is and what to do, and names a skipped colour
  (`You had no legal cell for red, so your ball was skipped. …`); read it with `get`.
- Rules panel: `Layout/RulesPanel`, x 744–1264. The AI's rules on top (row centres y=94, 142, 190,
  238, 286; click x≈1000 to select one, again to clear; `get:Layout/RulesPanel:selected_rule_id`;
  two note mark buttons at the right end of each row, ✗ "Rule out" x≈1180 and ? "Suspect" x≈1218
  (nodes `…/AIRules/<id>/Line/Marks/Cross|Question`, `lit` true while on): a tap sets that mark,
  switches from the other or clears it when lit, without selecting the row; a ✗ row fades and is
  struck through, a ? row gets a yellow left edge. `get:Layout/RulesPanel:marks` prints
  `{ "R10": 1, … }`, 0 none, 1 ✗ (`NoteMark.Mark.CROSS`), 2 ? (`QUESTION`); marks are kept at match
  end and cleared by a rematch), then the Guess slot (hint text and the Guess button, centre
  (1173,344)), yours below (y≈454–646) with the true one highlighted. Three skip pips at the right of
  each title (`%AISkipPips` y≈48, `%PlayerSkipPips` y≈408), filled red per skip. Rule text wraps
  instead of being cut off: a rule too wide for one line (R15, R16, R17, R22) is one font step
  smaller and takes two lines in a row of the usual height. With Larger text the panel packs tighter
  (rows 40 px, 2 px apart; more rules wrap, so more drop the step) and a rule that wraps makes its
  row about 47 px (51 with TRUE beside it), so the y values shift with the decks: read
  `get:Layout/RulesPanel/Sections/AIRules/<id>:global_position` (and `:size`) instead.
- Note marks hint: until the player first taps a mark (`[hints] note_marks_seen` not true in
  `settings.cfg`, as with no file), a line under the AI's title (`…/Sections/MarkHint`, `visible`)
  explains the marks and pushes everything below it down 29 px: AI rows y=123–315, Guess (1173,373),
  your rows y≈483–675. The first mark tap hides it and **saves `settings.cfg`** with
  `note_marks_seen=true` (the y values above then hold). Back up the user's file before a run that
  taps a mark, and restore it afterwards.
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
  `Layout/Status` is empty. Buttons: Rematch centre (271,540), Main menu centre (457,540); Main menu
  returns to `Main`. To guess the AI's first rule and go back to the menu:
  `until:Layout/RulesPanel:guess_enabled=true click:1000,94 press:1173,344 wait:90 release:1173,344 until:Layout/MatchEnd:visible=true wait:40 ss:end click:457,540`.
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
- Rematch: hides the match-end screen and shows the match setup screen again, titled `Rematch`, with
  the deck picker and the other levels disabled (same decks, same level): tap a rule and Start. The
  toss then reads `Rematch: you go first` / `Rematch: the AI goes first` (no coin toss: the other
  player goes first) and the row numbers flip with it. Continue from the end screen with
  `click:271,540 wait:30 until:Layout/MatchSetup:visible=true wait:10 click:368,478 wait:5 click:461,648 until:Layout/MatchSetup:visible=false`.
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
  pauses are unseeded (your deck is the one you pick). If you go second, the first thing the match waits
  for is your colour pick (`Layout/Status` says so), so `until:Layout/PlayerBall:draggable=true` times
  out; click a colour first. Clicking a disabled picker does nothing, so `wait:150 click:624,660` right
  after Start is safe either way.
- **Reaching skips**: you can't see legal cells from the driver, so play blind. Each turn:
  `until:Layout/PlayerBall:draggable=true`, then drag onto every cell, `wait:12` after each (illegal
  drops snap back; once one lands the ball is no longer draggable and the rest do nothing), then
  `until:Layout/ColourPicker:enabled=true` and click a colour. On a turn you skip, the first `until`
  times out (harmless: your ball has already dissolved) and the picker opens for your colour. Skips
  come late (a blind R03 game went 12 turns without one) and depend on the AI's random rule and
  colours, so allow many turns, and call the Godot exe directly rather than the `godot.cmd` shim: a
  long command list overflows cmd.exe's 8 KB line. Read `Layout/Status` to see who skipped.
- **Fixed `wait:N` counts can fall out of step** when the window is slow to start, so a click lands on
  the wrong screen (e.g. a Rematch click picking a rule on the setup screen). Gate each screen with `until:` on
  its state (`Layout/MatchSetup:visible`, `Layout/MatchEnd:visible`), and put a `wait:60` between the
  Single Player click and the first `until:`: right after a scene change there is no current scene
  and `until:` errors out, leaving the window open (kill that Godot process).
- **One windowed run at a time**: two windowed runs (e.g. from parallel agents) fight over the real
  cursor and misplace each other's clicks. Check for a running `Godot_v4.7.1-stable_win64_console`
  with a `driver.gd` command line first.
- Files under `.claude/` are invisible to Godot's import (dot-folder), so `out/` PNGs and the driver
  get no `.uid`/`.import` files. `-s` and `res://.claude/...` paths still load fine.

## Troubleshooting

- **`godot : The term 'godot' is not recognized`** in a shell started before the PATH change:
  `$env:Path += ";$env:USERPROFILE\bin"`, or restart VS Code.
- **Run never exits after `ss:`**: you passed `--headless` with an old copy of the driver. Kill the
  `Godot_v4.7.1-stable_win64*` process you started (not the editor) and drop `--headless`.
