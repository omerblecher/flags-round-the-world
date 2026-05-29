---
phase: 05
plan: 03
subsystem: hud-session-restore
tags: [game-hud, session-restore, privacy-policy, go-router, accessibility, accs-01, accs-03, accs-04, sess-01, sess-04, sess-07, comp-02]
dependency_graph:
  requires: [05-01]
  provides: [GameHud.onPause, GameHud.isMuted, GameHud.onMuteToggle, HomeScreen.continueDialog, HomeScreen.privacyFooter, AppConstants.privacyPolicyUrl, MapScreen.restoredMatchedIsoCodes, MapScreen.restoredSession, app-router-extras-forwarding]
  affects: [game_hud, home_screen, map_screen, app_router]
tech_stack:
  added: []
  patterns: [ConsumerStatefulWidget-initState-async, GoRouter-extras-forwarding, Semantics-button-48dp]
key_files:
  created:
    - lib/core/constants.dart
  modified:
    - lib/features/game/game_hud.dart
    - lib/features/home/home_screen.dart
    - lib/core/data/country_data_service.dart
    - lib/features/map/map_screen.dart
    - lib/app.dart
decisions:
  - "countryDataProvider moved from map_screen.dart to country_data_service.dart so HomeScreen can import it without depending on the full MapScreen widget"
  - "onPause wired as stub () {} in map_screen.dart GameHud call — Plan 05-04 replaces with real pause overlay logic"
  - "home_screen_test.dart still passes because gameStateRepositoryProvider FutureProvider returns gracefully even without override (test only overrides highScoreRepositoryProvider)"
metrics:
  duration: 600s
  completed: "2026-05-29"
  tasks: 3
  files: 5
---

# Phase 5 Plan 03: HUD Pause/Mute, Session Restore Dialog, and Privacy Footer Summary

GameHud upgraded to 48dp with pause + mute buttons (Semantics-wrapped), HomeScreen converted to ConsumerStatefulWidget with session-restore dialog and privacy policy footer, MapScreen gains optional restore constructor params, and app.dart GoRouter forwards extras to MapScreen.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Upgrade GameHud with pause button and mute toggle | 590f2b2 | lib/features/game/game_hud.dart, lib/features/map/map_screen.dart |
| 2 | Create AppConstants and update HomeScreen with session restore + privacy footer | 3636cb6 | lib/core/constants.dart, lib/features/home/home_screen.dart, lib/core/data/country_data_service.dart, lib/features/map/map_screen.dart |
| 3 | Add restore params to MapScreen constructor and update app.dart GoRouter | fee5008 | lib/features/map/map_screen.dart, lib/app.dart |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added stub onPause to MapScreen GameHud call**
- **Found during:** Task 1
- **Issue:** Adding `onPause` as a required parameter to GameHud broke the existing call site in map_screen.dart (compile error: missing_required_argument).
- **Fix:** Added `onPause: () {}` stub to the GameHud constructor call in `_buildMap`. Plan 05-04 replaces this with the real pause overlay invocation.
- **Files modified:** lib/features/map/map_screen.dart
- **Commit:** 590f2b2

**2. [Rule 2 - Missing critical functionality] Moved countryDataProvider to shared file**
- **Found during:** Task 2
- **Issue:** The plan's `_continueGame()` implementation uses `countryDataProvider` in HomeScreen. The provider was only declared in map_screen.dart. HomeScreen importing map_screen.dart would create a circular-dependency risk and violates the architecture (HomeScreen should not depend on MapScreen widget).
- **Fix:** Moved `countryDataProvider` declaration from map_screen.dart to `country_data_service.dart` (the natural home for data providers). Updated map_screen.dart to use a comment noting the move. HomeScreen imports from country_data_service.dart.
- **Files modified:** lib/core/data/country_data_service.dart, lib/features/map/map_screen.dart
- **Commit:** 3636cb6

## Verification Results

- flutter analyze lib/features/game/game_hud.dart: PASS (0 issues)
- flutter analyze lib/core/constants.dart lib/features/home/home_screen.dart: PASS (0 issues)
- flutter analyze lib/features/map/map_screen.dart lib/app.dart: PASS (0 issues)
- flutter analyze lib/: PASS (0 issues)
- ads_isolation_test: PASS (1/1 green)
- home_screen_test.dart: PASS (2/2 green — SC1 renders 4 mode cards, SC1 shows dash when no best score)
- flutter build apk --debug: PASS (APK built successfully)

## Known Stubs

- **lib/features/map/map_screen.dart line ~470:** `onPause: () {}` — stub wired in GameHud call site. Real pause overlay behavior (Plan 05-04) replaces this stub.
- **MapScreen.restoredMatchedIsoCodes / restoredRemainingIsoCodes / restoredSession:** Constructor fields declared but not yet consumed in `_initSequence`. Plan 05-04 adds the restore logic in `initState`.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns introduced.
- `AppConstants.privacyPolicyUrl` is a compile-time constant (T-05-03-02 addressed).
- GoRouter extras are in-process only (T-05-03-01 accepted as designed).
- `launchUrl` failure is non-blocking (T-05-03-03 accepted as designed).

## Self-Check: PASSED

- lib/core/constants.dart: FOUND
- lib/features/game/game_hud.dart: FOUND (height 48, onPause, isMuted, onMuteToggle)
- lib/features/home/home_screen.dart: FOUND (ConsumerStatefulWidget, continueGameTitle, privacyPolicyLink)
- lib/core/data/country_data_service.dart: FOUND (countryDataProvider added)
- lib/features/map/map_screen.dart: FOUND (restoredMatchedIsoCodes, restoredRemainingIsoCodes, restoredSession)
- lib/app.dart: FOUND (restoredMatchedIsoCodes in GoRoute builder)
- Commit 590f2b2: FOUND
- Commit 3636cb6: FOUND
- Commit fee5008: FOUND
