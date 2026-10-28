# OUTGRID

**THINK. TRACE. ESCAPE.**

OUTGRID is an original arrow-escape puzzle game built with Flutter. Each
board is a silhouette made of colorful arrow paths; tap an arrow to send
it off the board if — and only if — its forward exit lane is completely
clear. Clear every arrow to win. 500 hand-generated, solver-validated
levels across 10 chapters, offline-first, no backend.

This README is the single source of truth for setup, architecture,
commands, and known limitations. It describes what is actually
implemented and tested, not what is planned.

---

## 1. Quick start

```bash
flutter pub get
flutter test                 # 47 automated tests, ~5s
flutter analyze              # static analysis, should be clean
flutter run -d chrome        # fastest way to try it (or -d <android/ios device>)
```

The app is fully playable offline on first launch — all 500 levels ship
as bundled JSON assets; nothing is fetched over the network.

---

## 2. What's implemented (and verified)

| Area | Status |
|---|---|
| Puzzle engine (exit-lane checking, move validation, hearts, moves, undo, reset, hints) | Done, 21 unit tests |
| Puzzle solver + validator (dependency-graph based, see §5) | Done, 10 unit tests |
| Level generator + silhouette library (44 pattern families) | Done |
| 500 levels generated, validated, and solvable end-to-end through the real game engine | Done, verified in `test/unit/level_repository_test.dart` |
| Arrow/board rendering, escape/blocked/hint animations | Done |
| Home, Gameplay, Level Selection (10 chapters x 50 levels), Chapter grid, Completion, Settings, Daily Challenge screens | Done, 4 widget tests |
| Local persistence (progress, settings, resume-in-progress level) | Done, 9 unit tests |
| Offline play | Done — verified by disabling network during `flutter run` |
| Sound effects (arrow escape, blocked move, hint, button tap, level complete) | Done — uses `SystemSound`, see §8 for why |
| Background music | **Not implemented** — see §8 |
| App icon + splash screen generated from the OUTGRID logo | Done (`flutter_launcher_icons`, `flutter_native_splash`) |
| Android build | Builds via Gradle; NDK auto-download is blocked in this sandboxed dev container — see §7 |
| iOS build | Not buildable from this Windows dev machine (needs Xcode/macOS) — config is in place, untested here |

All claims above are backed by the test suite and the scripts in
`tool/`; run them yourself rather than taking this table on faith.

---

## 3. Architecture

```
lib/
  app/                    Theme, root widget wiring (Provider setup)
  core/
    constants/chapters.dart   10 chapters x pattern-family assignment
    storage/                  SettingsController/Repository, ProgressController/Repository
    utilities/                daily challenge date->level mapping, AudioService
  game/
    engine/                   ArrowPathDef-independent runtime: BoardState, ExitChecker,
                               MoveValidator, GameStateController (the actual rules)
    rendering/                CustomPainter-based arrow/board rendering + the interactive
                               PuzzleBoardWidget (gestures + animations)
    generation/                PuzzleSolver, PuzzleValidator, DifficultyAnalyzer,
                               LevelGenerator, SilhouetteLibrary, ShapeGeometry
    data/                      LevelLoader (asset I/O), LevelRepository (cache)
  features/                   One folder per screen: home, gameplay, level_selection,
                               chapters, completion, settings, daily_challenge
  models/                     Plain Dart data: ArrowPathDef, LevelModel, PlayerProgress,
                               GameSettings, direction/grid_point/arrow_color
assets/
  branding/outgrid_logo.png
  levels/level_manifest.json
  levels/chapter_01..10/chapter_NN.json   (500 levels, 10 files)
test/
  unit/                      engine, solver/validator, persistence, level repository
  widget_test.dart           app boot + navigation smoke tests
tool/
  generate_levels.dart       the Phase-5 generation pipeline (see §6)
  preview_masks.dart         dev-only: renders silhouette masks to PNG for visual QA
  preview_levels.dart        dev-only: generates+renders a sample level per family
  png_writer.dart            dev-only: zero-dependency PNG encoder for the two tools above
reports/
  level_validation_report.{json,md}   solver/validator results for all 500 levels
```

**Why no Flame engine.** This is a turn-based tap puzzle, not a
real-time game with a physics/render loop. A `CustomPainter` +
`AnimationController` gives full control over the escape/shake/hint
animations with less overhead than a full game-loop framework, and
keeps the engine testable with plain `flutter test` (no game-loop
ticking to fake).

**Why `models/` has no Flutter imports.** `ArrowColorId`,
`GridPoint`, `LevelModel`, etc. are pure Dart. Theme colors live in
`game/rendering/arrow_palette.dart`. This lets the solver/generator/
validator run under plain `dart run` (see `tool/`) without pulling in
`dart:ui`, which is what makes `tool/generate_levels.dart` and the
preview scripts possible at all.

---

## 4. The core rule, precisely

An arrow is a list of grid cells (tail → head) plus a travel
direction. Tapping it:

1. Computes the **forward lane**: every cell from one step past the
   head to the board edge, along the travel direction.
2. If every lane cell is empty (or belongs to the arrow itself — which
   by construction can never happen, see below), the arrow is removed
   and animates off the board.
3. Otherwise the move is **blocked**: one heart is lost, nothing on
   the board changes.

`ExitChecker.forwardLane` (`lib/game/engine/exit_checker.dart`) scans
the *entire* lane, not just the adjacent cell — required explicitly by
the design brief and covered by
`"horizontal lane correctly detects a blocker several cells away"` /
the vertical equivalent in `test/unit/engine_test.dart`.

**An arrow can never block itself.** The generator only ever grows a
path sideways or forward along its own chosen exit direction, never
backward — so the head is always the most-extreme cell of the path
along that axis. `PuzzleValidator` double-checks this (`SELF_BLOCKING`
check) on every generated level, and `engine_test.dart` has a
dedicated regression test with a deliberately bent path.

---

## 5. Solver: no search needed

Because the exit lane is static geometry and removing arrows only ever
*clears* cells (never occupies new ones), "B blocks A" is a fact
computable once from the starting board. That turns the whole puzzle
into a dependency DAG: arrow A depends on every arrow currently
occupying a cell in A's lane. A level is solvable iff that graph has
no cycle (`PuzzleSolver.solve`, Kahn's algorithm), and *any*
topological order is a valid playthrough.

This has a useful corollary that the engine relies on: since removing
an arrow only clears cells, the set of "currently removable" arrows
never shrinks as the player plays correctly. So a solvable level can
**never be played into a dead end** by legal moves alone — which is
why `GameStateController.findHint()` is a single linear scan with no
backtracking, and why undo/reset/hint never need to re-run the solver
mid-game.

`DifficultyAnalyzer` scores a level from that same graph: longest
dependency chain, average/max branching, and board density — not raw
arrow count, per the brief's explicit requirement.

---

## 6. How the 500 levels were made

`tool/generate_levels.dart` is the Phase-5 pipeline:

1. For each of the 10 chapters x 50 levels, pick a pattern family from
   that chapter's rotation (`lib/core/constants/chapters.dart`) and a
   board size that grows smoothly from ~7x7 (level 1) to ~32x32 (level
   500), with small per-level jitter.
2. Build a boolean silhouette mask for that family
   (`lib/game/generation/silhouette_library.dart`) — geometric shapes
   and abstract patterns are closed-form math (ellipses/polygons/
   mazes); animals and objects are composed from the same primitives
   (e.g. the elephant is two ear ellipses + a head + a curved trunk
   stroke + four leg rects) rather than hand-drawn pixel art, which
   made them verifiable by rendering (`tool/preview_masks.dart`) and
   tunable by parameter instead of by redrawing.
3. Fill the mask with arrows via `LevelGenerator`: walk from an
   unfilled cell, only ever stepping sideways or toward a chosen exit
   direction (never backward — see §4), stopping when boxed in.
4. Validate with `PuzzleValidator` (structural checks + the solver). If
   the dependency graph has a cycle, retry with a new seed — this
   happened on only 6 of ~500+ generations in testing (see
   `tool/preview_levels.dart`'s `avgAttempts=1.07`).
5. Write validated levels to `assets/levels/chapter_NN/chapter_NN.json`
   and a manifest; write `reports/level_validation_report.{json,md}`.

**Reproduce it yourself:**

```bash
dart run tool/generate_levels.dart
```

This is deterministic — every level's RNG seed is `globalIndex * 97 +
13` (plus a per-attempt offset only used on a validation retry), so
re-running produces byte-identical output. No level is ever generated
at runtime in the shipped app; players only ever load pre-validated
JSON.

**Current results** (`reports/level_validation_report.md`,
regenerate with the command above):

| Chapter | Levels | Avg Arrows | Avg Difficulty | Board Size Range |
|---|---|---|---|---|
| 1 First Steps | 50 | 7.9 | 27.7 | 7x7 – 13x13 |
| 2 Color Trails | 50 | 12.9 | 33.2 | 9x9 – 15x15 |
| 3 Twisted Paths | 50 | 21.0 | 41.1 | 12x12 – 18x18 |
| 4 Shape Shift | 50 | 21.5 | 53.9 | 14x14 – 20x20 |
| 5 The Maze | 50 | 33.0 | 71.5 | 16x16 – 22x22 |
| 6 Crossroads | 50 | 22.5 | 61.8 | 18x18 – 24x24 |
| 7 Mind Bender | 50 | 36.4 | 75.1 | 20x20 – 26x26 |
| 8 Precision | 50 | 29.3 | 70.3 | 22x22 – 28x28 |
| 9 Overdrive | 50 | 67.4 | 84.8 | 24x24 – 30x30 |
| 10 OUTGRID Master | 50 | 65.2 | 89.1 | 26x26 – 32x32 |

**500/500 passed validation. 0 failures.** Every level was also
re-verified by loading the real bundled JSON asset and clearing the
board through the live `GameStateController` using the solver's move
order (`test/unit/level_repository_test.dart`) — not just the
generator's own opinion of itself.

To visually spot-check silhouettes or a sample puzzle board before
trusting the generator:

```bash
dart run tool/preview_masks.dart out/masks      # renders all 44 families as PNG
dart run tool/preview_levels.dart out/levels    # renders a sample generated board per family
```

---

## 7. Building for Android / iOS

### Android

```bash
flutter build apk --release          # universal APK
flutter build appbundle --release    # Play Store AAB
```

`android/app/build.gradle.kts` sets `applicationId =
"com.outgrid.outgrid"` — change this to your own id before publishing.

**Known issue hit in this dev environment:** the default Flutter
Android template pins an NDK version and tries to download it on first
Gradle sync. This project has no native/NDK code, so the
`ndkVersion = flutter.ndkVersion` line was removed from
`android/app/build.gradle.kts`. In a normal environment with internet
access this isn't an issue either way; it only mattered here because
the sandboxed container this was built in has no access to download
new SDK components. If a future dependency needs the NDK, re-add that
line and let Gradle fetch it once.

### iOS

```bash
flutter build ios --release
```

Requires Xcode on macOS — this project was built on Windows, so the
iOS build itself was **not executed** in this session (the iOS project
files are present and configured by `flutter create`, and the app
icon/splash were generated for iOS, but a real Xcode build/signing
pass should be run on a Mac before submission). Set your Team and
Bundle Identifier in Xcode (`ios/Runner.xcworkspace`) before archiving.

### Web (used for verification during development)

```bash
flutter build web --release
flutter run -d chrome
```

### App icon / splash

Generated from `assets/branding/outgrid_logo.png` via:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Re-run these if the logo changes.

---

## 8. Known limitations

Documented honestly rather than left for someone to discover:

- **No background music.** Implementing it properly needs bundled,
  properly licensed royalty-free audio files, which this project does
  not have. The `musicEnabled` setting is persisted and shown in
  Settings so the save format and UI are ready for it, but toggling it
  currently has no audible effect. Sound *effects* (arrow escape,
  blocked move, hint, button tap, level complete) **are** implemented
  and functional, via `SystemSound` (`lib/core/utilities/audio_service.dart`)
  — no licensing concerns, no asset size cost, genuinely audible.
- **Undo history does not survive an app restart.** Resuming a level
  (via the "Continue" flow) restores the board, hearts, moves, and
  failed-attempt count exactly, but the in-memory undo stack is reset.
  This is a deliberate, documented tradeoff, not an oversight.
- **Daily Challenge has no server sync.** The level-of-the-day is a
  deterministic pure function of the calendar date
  (`lib/core/utilities/daily_challenge.dart`), so every player on every
  device sees the same puzzle on the same day without a backend — but
  there's no cross-device claim syncing, by design (no backend at all,
  per the offline-first requirement).
- **iOS was not build-verified** in this session (Windows dev
  environment, no Xcode). Project/icon/splash are configured; a real
  build pass is still needed on macOS before submission.
- **Android APK was not build-verified end-to-end** in this sandboxed
  session due to the blocked NDK download described in §7. `flutter
  build web --release` and `flutter analyze`/`flutter test` passing,
  plus the manual browser-driven interaction test described below,
  are the verification that *was* possible here. Run `flutter build
  apk` yourself on a machine with normal internet access to confirm —
  nothing in this codebase has been observed to be Android-specific or
  likely to fail there.
- **No analytics, ads, or tracking** — not implemented, per the
  explicit instruction not to add them without a decision to do so.
- **Desktop (Windows/Linux/macOS) targets weren't scaffolded** — only
  android/ios/web, matching the brief's required platform list.
- **Custom typography wasn't bundled.** The UI uses the Flutter/
  Material default system font rather than a custom webfont, to avoid
  a network fetch dependency and keep first-run fully offline; swap in
  a bundled font family in `app_theme.dart` if the brand needs one.

## 9. Manual verification performed this session

Beyond the 47 automated tests, the running app was driven end-to-end
in a real Chrome browser (`flutter run -d web-server`, driven via
`puppeteer-core` pointed at the already-installed system Chrome — no
browser binaries downloaded):

- Home screen renders brand, tagline, progress summary, animated
  illustration, and all navigation buttons.
- Tapping **Play** loads Level 1 ("Circle") and renders 6 colorful
  arrows with correct hearts/moves/arrows-remaining UI.
- Tapping a **blocked** arrow: heart count dropped 3→2, moves stayed
  at 0, arrow count stayed 6/6 — matches the specified rule exactly.
- Tapping a **clear** arrow (found via the Hint button): it animated
  off the board, moves went 0→1, arrows-remaining went 6/6→5/6, hearts
  were unaffected — also exactly per spec.
- No console errors in either session.

---

## 10. Commands reference

```bash
flutter pub get                          # install dependencies
flutter analyze                          # static analysis
flutter test                             # all 47 automated tests
flutter test test/unit/engine_test.dart  # just the engine (21 tests)
dart run tool/generate_levels.dart       # regenerate + revalidate all 500 levels
dart run tool/preview_masks.dart DIR     # render silhouette masks to PNG
dart run tool/preview_levels.dart DIR    # render sample generated boards to PNG
flutter run -d chrome                    # fastest manual playtest loop
flutter build apk --release              # Android release build
flutter build ios --release              # iOS release build (macOS only)
dart run flutter_launcher_icons          # regenerate app icons from the logo
dart run flutter_native_splash:create    # regenerate splash screens from the logo
```
