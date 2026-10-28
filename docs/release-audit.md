# Release audit: web build 0.2.0

What the itch.io web build does and ships, checked against the code on `web-release` (Godot 4.7.1, the "Web"
preset in `export_presets.cfg`). Re-run the checklist at the end before each public release.

## Network

None. The game's code (everything outside `addons/`, `test/`, `harness/` and `.claude/`) has no `HTTPRequest`,
`HTTPClient`, `StreamPeer*`, `PacketPeer*`, `TCPServer`, `UDPServer`, `WebSocket*`, `WebRTC*`, ENet or
`MultiplayerPeer`, and no `JavaScriptBridge` or `OS.shell_open`.

The one way out is the player's own click: the Credits card's two `LinkButton`s (`gui/menus/settings_menu.tscn`)
open `https://www.kenney.nl` and `https://godotengine.org/license`, which on the web opens a new browser tab.

## File access

- **Writes, `user://` only:** `Settings` saves `user://settings.cfg` (`game_settings.gd`, including the one-time
  hint flags) and `DeckStore` saves `user://decks.json` (`model/deck_store.gd`). Nothing else writes files.
- **Reads, `res://`:** `RuleBook` reads `res://rules/data/rules.json` and `templates.json`; the Licences card reads
  `res://assets/fonts/OFL.txt`; the rest is scenes, scripts and textures loaded by the engine.
- **Browser storage:** on the web Godot keeps `user://` in the browser's IndexedDB (per origin, so per itch.io
  game page). Clearing the site's data resets settings and saved decks. The Playwright test "a saved deck is
  still listed after a reload" checks it survives a reload.

## OS and engine calls

- No `OS.execute`, `OS.create_process`, `OS.kill` or shell. `OS.has_feature("web")` in `WebMarkers` and
  `RotateHint` only decides whether to print console markers.
- `Engine.get_license_text()`, `get_copyright_info()` and `get_license_info()` fill the Licences card.
- The main menu's Quit button calls `get_tree().quit()`. It hides itself when `OS.has_feature("web")`, since
  quitting in a browser only stops the engine and leaves a frozen canvas (the GDD wants Quit on desktop only).

## Addons

Only GUT 9.7.1 (`addons/gut/`), for the test suite. The preset excludes `addons/gut/*`, and the export below
holds none of it.

## Autoloads

| Autoload | Script | What it does |
| --- | --- | --- |
| `EventBus` | `event_bus.gd` | Global signals (match started, ball placed, deck saved, decks listed, drag). |
| `Constants` | `constants.gd` | The ball colours. |
| `Settings` | `game_settings.gd` | Player settings, loaded from and saved to `user://settings.cfg`; `changed` signal. |
| `WebMarkers` | `gui/web_markers.gd` | Web builds only: prints `[ballen] …` console lines on scene changes and key events for the web tests. Does nothing elsewhere. |
| `RotateHint` | `gui/rotate_hint.gd` | A top `CanvasLayer` that covers the screen and takes input while the screen is taller than wide. |
| `SymbolFont` | `gui/symbol_font.gd` | Adds the bundled Noto Sans Symbols as a fallback of the default font (the web has no system fonts for ← →). |

## What the export contains

`godot --headless --path . --export-release "Web" build/web/index.html` (after `mkdir -p build/web`) writes:

| File | Size |
| --- | --- |
| `index.wasm` (engine, `nothreads` template) | 39.5 MB |
| `index.pck` (the game) | 2.0 MB |
| `index.js`, `index.html`, two audio worklets | 0.3 MB |
| `index.png` (boot splash), `index.icon.png`, `index.apple-touch-icon.png` | 0.1 MB |

The pack holds 1313 files (listed from the export log's "Storing File" lines):

| Folder | Files | What |
| --- | --- | --- |
| `.godot/imported/` | 966 | 965 imported textures (`.ctex`) and the font (`.fontdata`) |
| `.godot/exported/`, caches | 11 | The 9 scenes in binary form, `global_script_class_cache.cfg`, `uid_cache.bin` |
| `assets/` | 208 | `.import` stubs for the Kenney textures and the font, `icon/icon.png`, `fonts/OFL.txt` |
| `gui/` | 59 | Compiled scripts (`.gdc`) and remaps, including `gui/menus/` |
| `model/` | 34 | Compiled scripts and remaps |
| `rules/` | 14 | Compiled scripts, `data/rules.json`, `data/templates.json` |
| `ai/` | 10 | Compiled scripts and remaps |
| root | 9 | `project.binary`, the autoload and entry scripts and scenes |

Nothing from `test/`, `harness/`, `addons/`, `docs/`, `web-test/`, `.claude/` or `build/` is in it. Scripts are
exported compiled (`script_export_mode=2`).

The `all_resources` filter packs every imported Kenney texture, though the game draws only two of them
(`BoardView`'s cell and ball tiles) plus the icon. They cost little (the whole pack is 2 MB); trim them with a
resource filter if the pack ever grows.

## Licences

Shown in the game under Options → Credits → Licences and listed in `THIRD_PARTY_NOTICES.md`:

- **Godot Engine 4.7.1:** MIT. The Licences card reads the engine's notice, components and licence texts at run
  time, so they match the build. They describe the whole engine source, a superset of what the web template
  contains (Vulkan, Jolt and so on are listed but not in the web build); listing more is harmless.
- **Kenney assets:** CC0 1.0 (`License.txt`); credited on the Credits card with a link.
- **Noto Sans Symbols:** SIL OFL 1.1, `assets/fonts/OFL.txt` packed and shown on the Licences card. The bundled
  copy is modified (hhea and OS/2 ascent and descent set to 1069 and 293 to match the default font; glyphs
  unchanged), recorded in `THIRD_PARTY_NOTICES.md`. The OFL allows modified copies; the font keeps its name,
  which the OFL forbids only for Reserved Font Names, and Noto declares none.
- **GUT:** MIT, development only, not shipped.

## Known gaps

- **Firefox is not tested locally:** Playwright's Firefox won't launch on the Windows dev machine. CI runs the web
  tests on Linux in all four projects, Firefox included.
- **WebKit console noise:** Playwright's WebKit logs `glBlitFramebuffer: Read and write color attachments cannot be
  the same image` every frame, from Godot's final blit in the Compatibility renderer. The game renders correctly
  and the tests ignore that one message on WebKit. Check on a real iPhone.
- **WebGL startup warnings:** browsers warn about zero-size framebuffers while the canvas is first sized. Harmless
  so far.
- **WebKit touch drag is simulated:** WebKit has no CDP, so its drag test sends script-made `TouchEvent`s, not
  real touches. Chromium's touch drag goes through CDP `Input.dispatchTouchEvent`.
- **No real devices yet:** every phone run so far is an emulated Playwright device. Ideas for later: a device farm
  or an Android emulator.
- **Download size:** about 42 MB, nearly all the engine's `.wasm`; the first load on a phone connection is slow.

## Re-check before each public release

- [ ] Grep the game's code for network classes, `JavaScriptBridge`, `OS.shell_open`, `OS.execute` and
      `OS.create_process`; update this file if any appear.
- [ ] Grep for `user://`, `FileAccess`, `DirAccess`, `ConfigFile` and `ResourceSaver`: writes stay in `user://`.
- [ ] Compare the `[autoload]` list in `project.godot` with the table above.
- [ ] Export Web and list the pack from the export log: no `test/`, `harness/`, `addons/gut/`, `docs/`,
      `web-test/` or `.claude/` files; note size changes.
- [ ] A new asset or font: add its licence to `THIRD_PARTY_NOTICES.md` and, if it needs one, the Licences card.
- [ ] After a Godot upgrade: update the version in `THIRD_PARTY_NOTICES.md` and here; the Licences card follows by
      itself.
- [ ] `config/version` in `project.godot` is the release's version (CI adds `+<sha>`).
- [ ] The GUT suite and the web tests pass in all four projects (CI's `deploy` job).
- [ ] On the live page: it loads, the version label matches, a saved deck survives a reload, the rotate hint
      shows in portrait, and the console has no new errors.
- [ ] Re-read Known gaps: close what's fixed, add what's new.
