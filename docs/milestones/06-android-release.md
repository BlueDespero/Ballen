# Milestone 6 — Android release on Google Play

**Goal:** Ballen installs from Google Play on Android phones and tablets, first to a closed group through an
opt-in link, then publicly. This is the Android half of milestone 6 (Mobile release) in section 8 of the
[game design document](../game-design-document.md); iOS is a separate plan.

Read first: [game-design-document.md](../game-design-document.md) (sections 7–9),
[technical-design.md](../technical-design.md) and [release-audit.md](../release-audit.md). The design
document wins any conflict; flag conflicts instead of silently picking a side.

Requirements are as of November 2026. Re-check Google's pages before the first upload, because they change
every year:

- New apps and updates must target Android 16 (API 36)
  ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/11926878)).
- Uploads must be Android App Bundles (`.aab`). Native libraries must be aligned to 16 KB pages; Godot 4.7
  does this by itself (NDK r28b), and Ballen has no C# that could add unaligned libraries.
- A personal developer account created after 13 November 2023 must run a closed test with at least 12
  testers opted in for 14 days in a row before it can apply for production
  ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465)).
- Every app needs a privacy policy URL, a Data safety form, the IARC content rating questionnaire, a target
  audience and an ads declaration, even when it collects nothing.

## Decisions to make first

1. **Ads in the first Play release?** Section 9 of the GDD says the free mobile version earns from opt-in ads
   that double a duel's reward, and a paid version has none. Rewards and cosmetics don't exist yet, so there
   is nothing for an ad to double. **Recommended:** ship the first Play release free and without ads, and
   update section 9 to say so. Ads later mean an ads SDK, a consent dialog (GDPR), a changed Data safety
   form and "contains ads" on the listing: a milestone of its own.
2. **Leaving a match.** The Android back button needs a meaning during a match, and the GDD doesn't say
   whether a player can leave one mid-play, or whether leaving counts as a loss. **Recommended:** back asks
   "Leave this match?" and, if confirmed, goes to the main menu with no result recorded (there are no stats or
   rewards yet). Add the rule to the GDD.
3. **Account type.** Personal (identity check, the 12-tester closed test above) or organisation (D-U-N-S
   number, no closed-test rule). Recommended: personal, unless a company will publish it.
4. **Package name.** Permanent once uploaded, e.g. `com.<name>.ballen`.
5. **Target audience.** Recommended: 13 and over. Including under-13s brings in the Families policy.

## Tickets

In order; each ticket is one or a few small commits with tests, as `CLAUDE.md` requires. Tickets 1–6 are
code and can be done before the developer account exists.

### 1. Hide Quit on mobile

`gui/menus/quit_button.gd` hides the button only on the web, so it would show on Android, where apps don't
quit themselves and the GDD wants Quit on desktop only.

- `QuitButton.is_shown()` takes whether the platform is web or mobile (`OS.has_feature("mobile")`) and
  returns `false` for both.
- Tests: `is_shown` for desktop, web and mobile.

### 2. Android back button

Godot quits the app on Android's back gesture by default (`application/config/quit_on_go_back`), from any
screen. Back must step back instead, like Escape on desktop.

- Set `quit_on_go_back=false` and handle `NOTIFICATION_WM_GO_BACK_REQUEST` in each screen, doing what its
  `ui_cancel` handler does (deck editor, Decks screen, Settings); one shared helper so the two stay the same.
- Match setup panel: back goes to the main menu.
- During a match: decision 2 (a confirm dialog, then the main menu). On the match-end screen: main menu.
- Main menu: back quits the app (the Android convention at the root screen).
- Tests: send the notification to each scene and check where it ends up; the match confirm dialog opens and
  its two buttons do the right thing.

### 3. Landscape lock

Ballen is landscape-only. Without a lock, Android rotates to portrait and `RotateHint` covers the screen.

- `display/window/handheld/orientation` = sensor landscape (both landscape directions).
- Keep `RotateHint`: split-screen and tablet multi-window can still give a tall window.

### 4. Screen cutouts and the safe area

Landscape phones put the camera notch or punch hole at the left or right edge, over the board or panels.

- A small pure function turns the screen size and `DisplayServer.get_display_safe_area()` into margins; the
  menus' and the match's root containers apply them and update on resize.
- Tests: the margin function for no cutout, a left cutout and a right cutout.
- Check on a real phone with a punch hole, both landscape directions.

### 5. Text fields and the on-screen keyboard

The deck name fields (`deck_editor.tscn` `NameField`, `decks_screen.tscn` `DialogName`) bring up the
on-screen keyboard, which in landscape covers most of the screen.

- Check on a phone that the field stays visible while typing and that Done or Enter confirms.
- If it is hidden, move the dialog up by the keyboard height
  (`DisplayServer.virtual_keyboard_get_height()`), with a test for the layout function.

### 6. App icon

- An adaptive icon: a 432×432 foreground (the art inside the central 264×264 safe zone), a background, and
  a monochrome layer for Android 13 themed icons; made from `assets/icon/icon.png` (256×256, so redraw or
  export the source art larger).
- A 512×512 store icon. Both go in `assets/icon/`, with their licence noted in `THIRD_PARTY_NOTICES.md` if
  they use Kenney art.

### 7. Android export preset

A preset "Android" in `export_presets.cfg`, next to "Web":

- Gradle build on (needed for `.aab`), export format AAB, architectures `arm64-v8a` and `armeabi-v7a`.
- Package name (decision 4), name "Ballen", min SDK as Godot's default, **target SDK 36**.
- Version name from `config/version`; version code an integer that grows with every upload (CI sets it,
  ticket 8).
- No permissions; INTERNET off. The Credits links open the browser, which needs none.
- Immersive mode on; the same resource filter as Web (excludes `addons/gut/*`, `test/`, `harness/`).
- `.gitignore` the `android/` build template folder that Godot installs, or commit it if it gets changes
  (decide once; recommended: install it in CI and ignore it).
- No keystore in the repo. A local debug export uses the debug keystore.

### 8. CI: build and check the bundle

A job `android` in `.github/workflows/ci.yml`, after `test`, on every pull request and push to `master`:

- Install the Android SDK (platform 36, build-tools), the export templates and the Gradle build template.
- Stamp the version (as `web` does) and set the version code to the workflow run number.
- Export the AAB. On `master`, sign it with the upload key from secrets (`ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`); on pull requests, the debug key.
- Check the bundle with `bundletool`: `targetSdkVersion` is 36, no permissions in the manifest, and the
  native libraries pass the 16 KB alignment check (`zipalign -c -P 16` on APKs built from the bundle).
  Fail the job if any check fails.
- Upload the AAB as a workflow artifact.
- Later, once the Play app exists: upload `master` builds to the internal testing track with a Play service
  account (`PLAY_SERVICE_ACCOUNT_JSON`), as `deploy` does for itch.io.

Update the CI section of `CLAUDE.md` with the new job and secrets.

### 9. Running on Android in tests

The web tests wait for `[ballen] …` markers that only web builds print.

- First release: a manual device checklist (ticket 12) is enough.
- Later: let `WebMarkers` also print on Android, and add a CI job that installs the APK on an Android
  emulator, starts a match and waits for the markers in `adb logcat`.

### 10. Privacy policy

- `docs/privacy-policy.md` (English and Polish): no data collected or shared, settings and decks stay on the
  device, no ads, no accounts, how to reach the developer.
- Publish it at a public URL (GitHub Pages or the itch.io page) for the Play listing; link it from
  Settings → Credits too.

### 11. Release audit for Android

Add an Android section to `docs/release-audit.md`: what the AAB contains and its size, permissions (none),
where `user://` lives (app-private storage, deleted on uninstall, kept across updates), and the Android items
for the release checklist (target SDK, version code, signing, the bundletool checks).

### 12. Device check

On at least one real phone (Android 10 or newer, ideally one with a punch hole) and one tablet:

- Install from the internal testing track, play a full match, drag balls, use guess and colour pick.
- Back button on every screen; landscape both ways; split screen shows the rotate hint.
- Settings and a saved deck survive closing the app and installing an update.
- Larger text, colour-blind symbols and Polish all look right.
- Note frame rate, start-up time and battery in the release audit.

## Play Console steps (no code)

Done by the account owner, in this order, once tickets 1–8 and 10 are in:

1. Create the developer account (decision 3), pay the fee, pass identity verification.
2. Create the app; turn on Play App Signing and register the upload key from ticket 8.
3. Fill in App content: privacy policy URL, Data safety ("no data collected or shared"), IARC
   questionnaire, target audience (decision 5), ads ("no ads", decision 1).
4. Store listing in English and Polish: short and full description, 512×512 icon, 1024×500 feature
   graphic, at least two phone screenshots (and tablet ones). The Playwright tests can take screenshots at
   the right sizes from the web build.
5. **Internal testing:** upload the AAB, add up to 100 testers by email, share the opt-in link. No full
   review; the build is available within minutes.
6. **Closed testing (link-only access):** a Google Group as the tester list, at least 12 testers opted in for
   14 days in a row. The app can't be found by searching Play; testers join through the opt-in link, which
   appears once the release is published to the track.
7. Apply for production access, then publish (staged rollout recommended).

Open testing is not link-only: the app becomes visible on Play.

## Out of scope

iOS, ads and in-app purchases (decision 1), rewards and cosmetics, online play, portrait layout.
