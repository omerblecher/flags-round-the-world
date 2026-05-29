---
phase: 04-game-modes-scoring
plan: 05
subsystem: game-ui, testing
tags: [flutter, dart, riverpod, completion-screen, stars, confetti, go_router, unit-tests, widget-tests]

# Dependency graph
requires:
  - plan: 04-04
    provides: MapScreen fully wired, highScoreRepositoryProvider canonical, GoRouter /result route
  - plan: 04-02
    provides: CompletionScreen skeleton with previousBest param, ARB completionPersonalBest + completionDone keys
  - plan: 04-01
    provides: computeStarCount D-D01/D-D02 spec, ARB strings

provides:
  - lib/features/map/completion_screen.dart — full StatefulWidget rewrite with stars, PB overlay, confetti
  - computeStarCount() top-level function (golf-style star rating, testable without widgets)
  - test/features/game/phase4_test.dart — GREEN unit tests for star rating (D-D01/D-D02) + useHint (GAME-07)
  - test/features/home/home_screen_test.dart — GREEN widget tests for HomeScreen 4-mode-card rendering (SC1)

affects:
  - 05: CompletionScreen is now the final user-facing piece; Phase 5 polish will extend it
  - verifier: all 6 human checkpoint checks now have code backing them

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "computeStarCount() extracted as top-level pure function — golf-style (lower=better), testable without Flutter widget machinery"
    - "SingleTickerProviderStateMixin for PB banner: AnimationController 2000ms forward + whenComplete unmount check"
    - "_ConfettiPainter: deterministic fixed-seed math.Random(42) with 40 particles; withValues(alpha:) not deprecated withOpacity"
    - "_ManualTicker in tests: local tick() driver for countdown to playing transition without Timer.periodic"
    - "ProviderContainer.overrideWith for AsyncNotifierProvider in unit tests (no testWidgets needed for notifier tests)"
    - "highScoreRepositoryProvider.overrideWith((_) async => repo) pattern for HomeScreen widget tests"

key-files:
  created: []
  modified:
    - lib/features/map/completion_screen.dart
    - test/features/game/phase4_test.dart
    - test/features/home/home_screen_test.dart

key-decisions:
  - "computeStarCount() placed at file scope (not in class) so unit tests import it without any Flutter test infrastructure"
  - "First game (previousBest=null): _isNewPb=false per D-D01 clarification — 3 stars but NO overlay (nothing to beat)"
  - "grand_master_sequence_test.dart not rewritten in this plan — already GREEN from plan 04-04 deviation"
  - "pre-existing all_countries_test Norway/Sweden hit-detection failures are out of scope; not caused by this plan"

requirements-completed: [SCOR-05, SCOR-06, SCOR-07, GAME-08, MODE-01, MODE-02, MODE-03, MODE-04, MODE-05]

# Metrics
duration: 18min
completed: 2026-05-29
---

# Phase 4 Plan 05: CompletionScreen + Test GREEN Flip Summary

**CompletionScreen rewritten with golf-style 1-3 star rating, 2s "New Personal Best!" confetti overlay, and Done navigation; all RED test stubs for star rating, useHint, and HomeScreen are now GREEN**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-05-29T05:30:00Z
- **Completed:** 2026-05-29T05:48:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

### Task 1: Rewrite CompletionScreen

- Replaced `StatelessWidget` with `StatefulWidget + SingleTickerProviderStateMixin`
- Added `computeStarCount(int score, int? previousBest)` top-level pure function for testability
- Star logic (D-D01/D-D02): null previousBest = 3 stars no overlay; score < previousBest = 3 stars + PB overlay; within 20% = 2 stars; worse = 1 star
- `_pbController` AnimationController runs 2000ms forward; `_showPbOverlay` toggles via `whenComplete` + `mounted` guard
- PB overlay: `IgnorePointer > Opacity` fading from 1.0 to 0.0 over final 20% of animation
- "New Personal Best!" amber banner with `BoxShadow` + `_ConfettiPainter` (40 deterministic particles, `math.Random(42)`)
- Done button: `context.go('/')` via go_router — returns to HomeScreen
- `withValues(alpha: opacity)` used throughout (not deprecated `withOpacity`)
- `flutter analyze lib/features/map/completion_screen.dart` — No issues

### Task 2: Flip RED Test Stubs GREEN

**phase4_test.dart:**
- Star rating unit tests (4 tests): null PB = 3, score < PB = 3, within 20% = 2, worse = 1
- useHint unit tests (2 tests): `_ManualTicker` ticks 3x to advance countdown to playing; `useHint()` decrements from 2 to 1 returns true; exhausted returns false
- All 6 tests pass in `ProviderContainer` without any Flutter widget machinery

**home_screen_test.dart:**
- Widget tests (2 tests): `_StubHighScoreRepository` with empty map stubs all modes to null
- SC1: renders 4 mode cards verifies "Learn", "Flags Master", "Geographical Master", "Grand Master" text
- SC1: shows dash verifies `find.textContaining('—')` finds widgets (homeNoBestScore = "Best: —")
- GoRouter + MaterialApp.router + AppLocalizations setup

**grand_master_sequence_test.dart:** Already GREEN from plan 04-04; no changes needed.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Rewrite CompletionScreen with stars, PB overlay, and confetti | f690c4c | lib/features/map/completion_screen.dart |
| 2 | Flip RED test stubs GREEN for star rating, useHint, and HomeScreen | 0aba491 | test/features/game/phase4_test.dart, test/features/home/home_screen_test.dart |

## Verification Results

- `flutter analyze lib/features/map/completion_screen.dart` — No issues
- `flutter analyze lib/` — No issues (zero errors)
- `flutter test test/features/game/phase4_test.dart` — 6/6 PASSED
- `flutter test test/features/map/grand_master_sequence_test.dart` — 2/2 PASSED
- `flutter test test/features/home/home_screen_test.dart` — 2/2 PASSED
- `flutter test test/architecture/ads_isolation_test.dart` — 1/1 PASSED
- Total target tests: 11/11 PASSED

## Deviations from Plan

None — plan executed exactly as written, with one notable pre-existing state:

**Observation: grand_master_sequence_test already GREEN**
- The plan listed `grand_master_sequence_test.dart` as a RED stub to flip GREEN
- It was already GREEN as of plan 04-04 (deviation in that plan turned it GREEN early)
- No action needed

## Known Stubs

| Component | Stub | Resolving Plan |
|-----------|------|----------------|
| `AdLoaded` branch in `_useHint()` (MapScreen) | `adServiceProvider.loadRewardedAd()` returns AdFailed stub | Phase 6 (AdMob wiring) |

This stub does not prevent this plan's goal from being achieved.

## Deferred Items (Out of Scope)

**Pre-existing `all_countries_test.dart` failures (Norway/Sweden hit detection):**
- 5 tests fail: "no: got se at scale X" (Norway centroid hits Sweden at all zoom levels)
- These were present at the plan 04-04 merge commit (59f9dff) before any changes in this plan
- Hit detection logic in `lib/features/map/hit_detection.dart` was not touched by this plan
- Deferred to Phase 5 polish or explicit bug-fix plan

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. `CompletionScreen` receives `session` and `previousBest` via in-process GoRouter `extra` map cast; no external input crosses trust boundaries.

## Self-Check: PASSED

- `lib/features/map/completion_screen.dart` — FOUND (contains computeStarCount, CompletionScreen, _ConfettiPainter)
- `test/features/game/phase4_test.dart` — FOUND (contains star rating + useHint tests)
- `test/features/home/home_screen_test.dart` — FOUND (contains HomeScreen widget tests)
- Task 1 commit f690c4c — FOUND in git log
- Task 2 commit 0aba491 — FOUND in git log
- `flutter analyze lib/` — No issues
- `flutter test` target files — 11/11 PASSED
- `ads_isolation_test.dart` — 1/1 PASSED

---
*Phase: 04-game-modes-scoring*
*Completed: 2026-05-29*
