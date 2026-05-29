---
phase: 05
plan: 04
subsystem: map-screen-polish
tags: [pause-overlay, tutorial, session-restore, accessibility, vis-01, vis-03, accs-01, accs-03, accs-04, sess-01, sess-02, sess-04, sess-05, sess-06, sess-07]
dependency_graph:
  requires: [05-01, 05-02, 05-03]
  provides: [MapScreen.pauseOverlay, MapScreen.tutorial, MapScreen.sessionRestore, MapScreen.WidgetsBindingObserver, FlagTray.semanticLabels, MapScreen.viewScaleWired, MapScreen.ColoredBoxOcean]
  affects: [map_screen, flag_tray]
tech_stack:
  added: []
  patterns: [WidgetsBindingObserver-auto-pause, coach-mark-overlay-deferred-start, session-restore-GoRouter-extras, Semantics-48dp-button]
key_files:
  created: []
  modified:
    - lib/features/map/map_screen.dart
    - lib/features/game/flag_tray.dart
    - test/features/game/phase5_test.dart
decisions:
  - "Tasks 1+2+3 implemented in single MapScreen write — all map_screen changes committed atomically as they are interdependent (pause overlay uses _isMuted from Task 1; tutorial overlay sits in same Stack as pause overlay from Task 2)"
  - "phase5_test.dart RED stubs for SESS, ACCS, VIS requirements turned GREEN since implementations exist; SHAR-03 remains RED for Plan 05-05"
  - "all_countries_test Norway (no→se) failure is pre-existing and out-of-scope for this plan — logged as deferred"
metrics:
  duration: 600s
  completed: "2026-05-29"
  tasks: 4
  files: 3
---

# Phase 5 Plan 04: MapScreen Phase 5 Wiring and FlagTray Accessibility Summary

Full Phase 5 MapScreen wiring: pause button → modal overlay with Resume/Mute/EndGame, WidgetsBindingObserver auto-pause on app background, session restore from GoRouter extras, 4-step coach-mark tutorial with deferred game start, VIS-01 (WorldMapPainter viewScale), VIS-03 (ColoredBox ocean backfill), and FlagTray Semantics labels with 48dp hint button.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1+2+3 | Wire pause overlay, tutorial, session restore, VIS-01/03 in MapScreen | bac6eb1 | lib/features/map/map_screen.dart |
| 4 | FlagTray accessibility — Semantics labels + 48dp hint button | 3f25207 | lib/features/game/flag_tray.dart |
| meta | Turn phase5_test GREEN for implemented features | ce84aaa | test/features/game/phase5_test.dart |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tasks 1/2/3 committed as single atomic change**
- **Found during:** Task 1
- **Issue:** Tasks 1, 2, and 3 all modify `map_screen.dart`. The changes are tightly interdependent: Task 2's `_buildPauseOverlay` uses `_isMuted` from Task 1; Task 3's tutorial overlay sits in the same Stack as Task 2's pause overlay. Writing them separately would have required the file to be in an intermediate broken state (referencing not-yet-added fields).
- **Fix:** All three tasks implemented in a single file write and committed as one commit. The commit message captures all three tasks.
- **Files modified:** lib/features/map/map_screen.dart
- **Commit:** bac6eb1

## Verification Results

- flutter analyze lib/features/map/map_screen.dart: PASS (0 issues)
- flutter analyze lib/features/game/flag_tray.dart: PASS (0 issues)
- flutter analyze lib/: PASS (0 issues)
- ads_isolation_test: PASS (1/1 green)
- phase5_test (implemented features): PASS (10/12 green; SHAR-03 remains RED for Plan 05-05)
- flutter build apk --debug: PASS (APK built successfully)

## Known Stubs

None — all plan objectives fully implemented. The two remaining RED tests in phase5_test.dart (SHAR-03 parental gate) are for Plan 05-05, not this plan.

## Deferred Items

- **Norway hit detection (pre-existing):** `all_countries_test.dart` reports Norway (`no`) sometimes returns Sweden (`se`) at low zoom scales. This is a pre-existing issue from Phase 3 map data, unrelated to any change in this plan. Logged to deferred-items for investigation in a future plan.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns introduced.
- WidgetsBindingObserver only reads AppLifecycleState (T-05-04-01 mounted check present in _onTutorialDismissed).
- pauseGame() is idempotent in didChangeAppLifecycleState (T-05-04-02 accepted).
- restoredSession is type-safe from GoRouter extras (T-05-04-03 accepted).

## Self-Check: PASSED

- lib/features/map/map_screen.dart: FOUND
- lib/features/game/flag_tray.dart: FOUND
- test/features/game/phase5_test.dart: FOUND
- Commit bac6eb1: FOUND
- Commit 3f25207: FOUND
- Commit ce84aaa: FOUND
