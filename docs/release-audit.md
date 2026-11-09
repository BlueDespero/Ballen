# Release audit: web build 0.2.0 and Android build

What the itch.io web build does and ships, checked against the code on `web-release` (Godot 4.7.1, the "Web"
preset in `export_presets.cfg`), and what the Google Play build adds ("Android build" below). Re-run the checklist at
the end before each public release.

## Network

None. The game's code (everything outside `addons/`, `test/`, `harness/` and `.claude/`) has no `HTTPRequest`,
`HTTPClient`, `StreamPeer*`, `PacketPeer*`, `TCPServer`, `UDPServer`, `WebSocket*`, `WebRTC*`, ENet or
`MultiplayerPeer`, and no `JavaScriptBridge` or `OS.shell_open`.

The one way out is the player's own click: the Credits card's three `LinkButton`s (`gui/menus/settings_menu.tscn`)
open `https://www.kenney.nl`, `https://godotengine.org/license` and the privacy policy
(`https://bluedespero.github.io/Ballen/privacy-policy.html`, from `site/`), which on the web opens a new browser tab.

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
| `WebMarkers` | `gui/web_markers.gd` | Web builds only: prints `[ballen] …` console lines on scene changes and key events for the web tests, and playtest measures (secret-rule pick time, guess turns, early Guess presses) to the browser console only. Does nothing elsewhere. |
| `RotateHint` | `gui/rotate_hint.gd` | A top `CanvasLayer` that covers the screen and takes input while the screen is taller than wide. |
| `SymbolFont` | `gui/symbol_font.gd` | Adds the bundled Noto Sans Symbols as a fallback of the default font (the web has no system fonts for ← →). |
| `BackButton` | `gui/back_button.gd` | Turns Android's go-back request into a `ui_cancel` press (Escape). Never fires on the web, where browsers send no go-back request. |
| `SafeArea` | `gui/safe_area.gd` | Phone and tablet apps only: insets the current scene to the display's safe area (clear of the camera cutout). Does nothing on the web. |

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

## Android build

The "Android" preset (`export_presets.cfg`) builds an App Bundle for Google Play with Gradle; CI's `android` job
builds and checks it (`.github/scripts/check_aab.sh`). Checked on 9 November 2026 with an unsigned APK export of the
same preset (no Gradle: this machine can't reach the Android SDK downloads):

- **Manifest:** package `io.github.bluedespero.ballen`, version name from `config/version`, min SDK 24, target SDK 36,
  `isGame`, `allowBackup="false"`, orientation `userLandscape` (both landscape directions, following the player's
  rotation lock).
- **Permissions:** none. The preset turns them all off; Godot adds INTERNET only to debug builds for remote debugging.
  AndroidX may declare its app-private `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, which prompts nothing and Play
  doesn't list.
- **Native libraries:** `libgodot_android.so` and `libc++_shared.so` for `arm64-v8a` and `armeabi-v7a`; the 64-bit
  ones are aligned to 16 KB pages (LOAD alignment `0x4000`), as Play requires. The preset packs them uncompressed.
- **Size:** the two-architecture APK is 55 MB, of which the game's files are 9.4 MB uncompressed; Play's per-device
  APKs from the bundle carry one architecture.
- **Game files:** the same filter as Web, minus the store-only icons (`assets/icon/android/`) and the Gradle project
  (`android/`); no `test/`, `harness/`, `addons/`, `docs/` or `site/` files.
- **Launcher icons:** the adaptive foreground, background and monochrome layers and the 192 px legacy icon from
  `assets/icon/android/`.
- **Storage:** `user://` is the app's private storage (`/data/data/io.github.bluedespero.ballen/files`): kept across
  updates, deleted on uninstall, not backed up (`user_data_backup/allow=false`).
- **Network and links:** as on the web: no network code; the Credits links open the browser.
- **Mobile-only autoloads:** `BackButton` (back steps back; the main menu closes the app) and `SafeArea` (clear of
  the camera cutout).

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
- **Android not yet on a device:** the bundle hasn't been installed on a phone or tablet; the safe-area inset, the
  keyboard above the Rename dialog and the back button are checked in tests and on a simulated cutout only. Ticket 12
  of `docs/milestones/06-android-release.md` is the device check.
- **CI's `android` job hasn't run yet:** it runs on the first pull request; until then the Gradle build itself is
  untested.

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
- [ ] Android: CI's `android` job passed for the release commit and its bundle was signed with the upload key (the
      artifact `android-bundle` exists); the version code is higher than the last one uploaded to Play.
- [ ] Android: the privacy policy page is live and still true.
- [ ] Re-read Known gaps: close what's fixed, add what's new.
