---
phase: 04-game-modes-scoring
plan: 04
subsystem: ads-isolation, game-ui, map-rendering
tags: [flutter, dart, riverpod, game-hud, highlight-painter, hint-ux, grand-master, go_router]

# Dependency graph
requires:
  - plan: 04-01
    provides: useHint(), ARB hint strings (hintOutTitle, hintOutMessage, hintWatchAd, hintCancel, hintAdFailed)
  - plan: 04-02
    provides: MapScreen.mode, GoRouter navigation (/result route), HomeScreen private provider stub
  - plan: 04-03
    provides: buildFlagSequence, buildGrandMasterSequence, FlagTray hint params, highScoreRepositoryProvider, countryNamesProvider

provides:
  - lib/core/ads/ — canonical ad type definitions (AdLoadState, AdService, StubAdService, adServiceProvider)
  - lib/features/ads/ — re-exports from core for backward compatibility
  - lib/features/game/game_hud.dart — 48dp HUD strip with score, progress bar, MM:SS timer
  - lib/features/map/highlight_painter.dart — hintIso param + bright yellow-green (0xFFBBFF44) hint highlight
  - lib/features/map/map_screen.dart — fully wired: HUD above map, mode visibility, hint flow, Grand Master sequence, GoRouter navigation
  - lib/features/home/home_screen.dart — promoted to canonical highScoreRepositoryProvider (private stub removed)
  - test/features/map/grand_master_sequence_test.dart — MODE-05 RED stubs turned GREEN

affects:
  - 04-05: MapScreen is now fully functional; CompletionScreen previousBest display can be wired
  - 06: adServiceProvider is the hook point for real AdMob wiring

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "core/ads/ walled garden: features/ads/ re-export backward-compat pattern preserves existing callers"
    - "ads_isolation_test: scans lib/features/game, lib/features/map, lib/core for features/ads/ imports"
    - "HighlightPainter hintIso: drawn above hover; color 0xFFBBFF44 distinct from gold hover and orange target ring"
    - "AnimationController for hint zoom: Matrix4Tween with CurvedAnimation easeInOut to country centroid at 3x scale"
    - "Timer for hint expiry: 3s Duration, clears _hintIso, mounted-check before setState"
    - "Grand Master sequence: async buildGrandMasterSequence in _initSequence; other modes synchronous buildFlagSequence"
    - "MockBinaryMessenger pattern: setMockMessageHandler('flutter/assets', ...) for rootBundle tests"

key-files:
  created:
    - lib/core/ads/ad_load_state.dart
    - lib/core/ads/ad_service.dart
    - lib/core/ads/ad_service_provider.dart
    - lib/features/game/game_hud.dart
  modified:
    - lib/features/ads/ad_load_state.dart
    - lib/features/ads/ad_service.dart
    - lib/features/map/highlight_painter.dart
    - lib/features/map/map_screen.dart
    - lib/features/home/home_screen.dart
    - test/features/map/grand_master_sequence_test.dart

key-decisions:
  - "lib/features/ads/ files become re-exports (not deletions) to preserve any callers from earlier phases that import features/ads/"
  - "ad_service.dart import in map_screen.dart replaced with ad_load_state.dart — AdLoaded class is in ad_load_state.dart, not ad_service.dart"
  - "grand_master_sequence_test RED stubs turned GREEN in this plan (deviation Rule 2) since buildGrandMasterSequence was implemented in 04-03 but tests remained RED"
  - "dart:ui FontFeature removed from game_hud.dart — Flutter material.dart already re-exports FontFeature; import was flagged as unnecessary_import"

# Metrics
duration: 11min
completed: 2026-05-29
---

# Phase 4 Plan 04: Integration — HUD, Hints, Mode Wiring Summary

**Ad types migrated to lib/core/ads/; GameHud created; HighlightPainter extended with hint highlight; MapScreen fully wired with HUD, mode visibility, hint flow, Grand Master sequence, and GoRouter game completion navigation**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-05-29T05:00:40Z
- **Completed:** 2026-05-29T05:11:00Z
- **Tasks:** 2 (+ 1 test GREEN conversion)
- **Files modified:** 6 (4 modified + 4 created)

## Accomplishments

### Task 1: Ad Types Migration + GameHud Widget

- Created `lib/core/ads/` directory with 3 files: `ad_load_state.dart`, `ad_service.dart`, `ad_service_provider.dart`
- Updated `lib/features/ads/ad_load_state.dart` and `ad_service.dart` to re-export from core (backward-compatible)
- Created `lib/features/game/game_hud.dart`: 48dp `Container` with grey.shade800 background; Row with `Score: $score` left, `LinearProgressIndicator` center, `MM:SS` timer right
- `ads_isolation_test.dart` remains GREEN after migration

### Task 2: HighlightPainter + MapScreen + HomeScreen

- `HighlightPainter` gains `hintIso` field; `_drawHintHighlight()` draws bright yellow-green (0xFFBBFF44) fill; `shouldRepaint` updated
- `MapScreen` state gains: `_hintIso`, `_hintTimer`, `_hintZoomController`, `_hintZoomAnim`
- `_initSequence()` updated: Grand Master calls `buildGrandMasterSequence()` async; other modes call `buildFlagSequence()` synchronously
- `_useHint()` wired: decrements via `gameSessionProvider.notifier.useHint()`, sets `_hintIso` for 3s, calls `_animateHintZoom()`
- Hint-exhausted dialog shows Watch Ad / Cancel; Watch Ad calls `adServiceProvider.loadRewardedAd()`; `AdFailed` result shows snackbar `hintAdFailed`
- `_animateHintZoom()` + `_applyHintZoom()`: Matrix4Tween from current to 3x scale centered on country centroid, 400ms easeInOut
- `_advanceToNextFlag()` updated: reads `highScoreRepositoryProvider.future`, saves best score, calls `context.go('/result', extra: {...})` on game completion
- `_countryName()` stub removed; `countryNames` map wired from `countryNamesProvider`
- `_buildMap()` adds `GameHud` above map column; computes `showLabels`/`showName` from `widget.mode`; passes all params to `FlagTray`
- `HomeScreen` promotes from private `_homeHighScoreRepoProvider` to canonical `highScoreRepositoryProvider` from `core/data/high_score_repository.dart`

### Extra: Grand Master Sequence Tests GREEN

- Turned 2 MODE-05 RED stubs GREEN using `TestWidgetsFlutterBinding` + mock asset handler
- Tests verify: no duplicates, all ISO codes present

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Move ad types to core/ads/ and create GameHud widget | 5aff338 | ad_load_state.dart (new), ad_service.dart (new), ad_service_provider.dart (new), game_hud.dart (new), features/ads re-exports |
| 2 | Wire MapScreen HUD/hints/modes, extend HighlightPainter | 326c1c9 | highlight_painter.dart, map_screen.dart, home_screen.dart |
| Extra | Turn grand_master_sequence RED stubs GREEN (MODE-05) | 65e697d | grand_master_sequence_test.dart |

## Verification Results

- `flutter analyze lib/core/ads/ lib/features/game/game_hud.dart` — No issues
- `flutter analyze lib/` — No issues (zero errors)
- `flutter test test/architecture/ads_isolation_test.dart` — 1/1 PASSED
- `flutter test test/features/map/flag_sequence_test.dart` — 3/3 PASSED
- `flutter test test/features/map/grand_master_sequence_test.dart` — 2/2 PASSED
- `grep -n "features/ads" lib/features/map/map_screen.dart` — No output (CLEAN)
- `flutter build apk --debug` — Built successfully

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wrong import for AdLoaded in map_screen.dart**
- **Found during:** Task 2 flutter analyze pass
- **Issue:** Imported `ad_service.dart` which doesn't export `AdLoaded`; `AdLoaded` is in `ad_load_state.dart`
- **Fix:** Changed import from `core/ads/ad_service.dart` to `core/ads/ad_load_state.dart`
- **Files modified:** `lib/features/map/map_screen.dart`
- **Commit:** 326c1c9

**2. [Rule 2 - Missing functionality] dart:ui unnecessary import in game_hud.dart**
- **Found during:** Task 1 flutter analyze pass
- **Issue:** `import 'dart:ui' show FontFeature'` flagged as `unnecessary_import` because `FontFeature` is already available via `package:flutter/material.dart`
- **Fix:** Removed the explicit `dart:ui` import
- **Files modified:** `lib/features/game/game_hud.dart`
- **Commit:** 5aff338

**3. [Rule 2 - Missing functionality] Turn MODE-05 RED stubs GREEN**
- **Found during:** Post-task review — `grand_master_sequence_test.dart` stubs marked as implementing plan 04-04 per 04-01 SUMMARY
- **Issue:** `buildGrandMasterSequence` was implemented in 04-03 but the 2 RED test stubs remained; this plan is the designated implementing plan
- **Fix:** Replaced `fail()` stubs with real tests using `TestWidgetsFlutterBinding` + mock `flutter/assets` message handler
- **Files modified:** `test/features/map/grand_master_sequence_test.dart`
- **Commit:** 65e697d

## Known Stubs

None — all plan requirements are fully wired. Remaining stub:

| Component | Stub | Resolving Plan |
|-----------|------|----------------|
| `AdLoaded` branch in `_useHint()` | Phase 6 will add `refillHints()` | 04-06 (AdMob wiring) |
| `CompletionScreen` body | `previousBest` param exists but body not rendered | 04-05 |

These stubs do not prevent this plan's goal from being achieved.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries introduced. `adServiceProvider` routes through `StubAdService` which always returns `AdFailed`; no real ad calls are made in Phases 1-5.

## Self-Check: PASSED

- `lib/core/ads/ad_load_state.dart` — FOUND
- `lib/core/ads/ad_service.dart` — FOUND
- `lib/core/ads/ad_service_provider.dart` — FOUND
- `lib/features/game/game_hud.dart` — FOUND (contains GameHud)
- `lib/features/map/highlight_painter.dart` — FOUND (contains hintIso)
- `lib/features/map/map_screen.dart` — FOUND (contains _useHint)
- `lib/features/home/home_screen.dart` — FOUND (uses highScoreRepositoryProvider)
- Task 1 commit 5aff338 — FOUND in git log
- Task 2 commit 326c1c9 — FOUND in git log
- Extra commit 65e697d — FOUND in git log
- `flutter analyze lib/` — No issues
- `ads_isolation_test.dart` — 1/1 PASSED
- `flag_sequence_test.dart` — 3/3 PASSED
- `grand_master_sequence_test.dart` — 2/2 PASSED
- `flutter build apk --debug` — Built successfully

---
*Phase: 04-game-modes-scoring*
*Completed: 2026-05-29*
