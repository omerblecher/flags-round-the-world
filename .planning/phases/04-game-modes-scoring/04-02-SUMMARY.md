---
phase: 04-game-modes-scoring
plan: 02
subsystem: navigation, home-screen, game-session
tags: [flutter, dart, go_router, navigation, home-screen, riverpod, game-mode]

# Dependency graph
requires:
  - phase: 04-01
    provides: Phase 4 ARB strings (homeTitle, modeName, homeBestScore, etc.)
  - phase: 03-map-rendering-drag-drop
    provides: MapScreen, CompletionScreen, GameSessionNotifier

provides:
  - GoRouter navigation stack (/, /play/:mode, /result)
  - HomeScreen with 4 mode cards and personal-best display
  - MapScreen with required GameMode mode constructor param
  - startGame(widget.mode) called on MapScreen init

affects:
  - 04-03 (highScoreRepositoryProvider — canonical provider to replace private one in HomeScreen)
  - 04-04 (MapScreen mode param is now wired; grand master variant adds its own sequence logic)
  - 04-05 (CompletionScreen previousBest param added — body wired in 04-05)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GoRouter at file-scope final: prevents router recreation on widget rebuild"
    - "Private _homeHighScoreRepoProvider in home_screen.dart: parallel-plan safe stub, promoted by 04-03"
    - "MapScreen.mode required param: GameMode flows from HomeScreen tap through GoRouter to startGame()"

key-files:
  created:
    - lib/features/home/home_screen.dart
  modified:
    - lib/app.dart
    - lib/features/map/map_screen.dart
    - lib/features/map/completion_screen.dart

key-decisions:
  - "GoRouter defined as top-level final (not inside build) to avoid recreation on every rebuild"
  - "Private _homeHighScoreRepoProvider in home_screen.dart avoids compile conflict with parallel Plan 04-03"
  - "CompletionScreen.previousBest added as optional int? so /result route compiles; body wired in 04-05"
  - "HomeScreen uses ConsumerWidget (not ConsumerStatefulWidget) since all state is in providers"

# Metrics
duration: 25min
completed: 2026-05-29
---

# Phase 4 Plan 02: GoRouter Navigation and HomeScreen Summary

**GoRouter wired as the app entry point with HomeScreen showing 4 mode cards; MapScreen now accepts a required GameMode mode parameter and calls startGame(widget.mode) on init**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-29T08:00:00Z
- **Completed:** 2026-05-29T08:25:00Z
- **Tasks:** 2
- **Files modified:** 4 (3 modified + 1 created)

## Accomplishments

- Replaced `MaterialApp(home:...)` with `MaterialApp.router` using a top-level GoRouter config
- Registered 3 routes: `/` (HomeScreen), `/play/:mode` (MapScreen with GameMode.values.byName), `/result` (CompletionScreen with extra map for session and previousBest)
- Created `lib/features/home/home_screen.dart` as a ConsumerWidget with 4 mode cards (Learn, Flags Master, Geographical Master, Grand Master)
- Each mode card shows name, description, and personal best score via `FutureBuilder<int?>` reading from a private `_homeHighScoreRepoProvider`
- Tapping a card navigates via `context.go('/play/${mode.name}')`
- Added `required this.mode` to `MapScreen` constructor and a `GameMode` import
- Added `startGame(widget.mode)` call in `_initSequence` postFrameCallback after `_fitMapToScreen()`
- Added optional `previousBest` param to `CompletionScreen` for /result route forward compatibility
- `flutter analyze lib/` reports zero errors
- `ads_isolation_test.dart` remains GREEN
- `flutter build apk --debug` succeeds

## Task Commits

1. **Task 1: Wire GoRouter in app.dart and create HomeScreen skeleton** - `2eafe2b`
2. **Task 2: Add GameMode mode param to MapScreen and call startGame on init** - `76ecdba`

## Files Created/Modified

- `lib/app.dart` — Replaced MaterialApp with MaterialApp.router; GoRouter with 3 routes; removed SpikeMapScreen FAB
- `lib/features/home/home_screen.dart` — New: ConsumerWidget with 4 mode cards, personal best display, navigation via GoRouter
- `lib/features/map/map_screen.dart` — Added GameMode import, required mode param on constructor, startGame(widget.mode) in postFrameCallback
- `lib/features/map/completion_screen.dart` — Added optional `previousBest` int? param to constructor

## Decisions Made

- GoRouter defined as top-level `final _router` so it is created once and not rebuilt on widget tree changes
- `_homeHighScoreRepoProvider` defined locally in home_screen.dart to avoid compile conflict with Plan 04-03 (which creates `highScoreRepositoryProvider` in high_score_repository.dart)
- `CompletionScreen.previousBest` added as optional `int?` now so the /result route in GoRouter compiles; Plan 04-05 wires the body to display it
- HomeScreen uses `ConsumerWidget` (not `ConsumerStatefulWidget`) since it has no local mutable state — all state flows from Riverpod providers

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Generated l10n files not present in worktree**
- **Found during:** Task 1 analyze — `uri_does_not_exist` on generated/l10n/app_localizations.dart
- **Issue:** The worktree does not have `lib/generated/` directory; flutter gen-l10n had only been run in the main repo
- **Fix:** Ran `flutter gen-l10n` in the worktree directory; files generated successfully
- **Files modified:** `lib/generated/l10n/` (generated, not committed — build-time output)
- **Commit:** N/A (generated files are not committed per project conventions)

**2. [Rule 1 - Bug] Task 1 analysis reported undefined 'mode' param on MapScreen**
- **Found during:** Task 1 analysis pass (before Task 2 ran)
- **Issue:** `lib/app.dart` references `MapScreen(mode: mode)` but MapScreen lacked the param until Task 2
- **Fix:** Executed Task 2 (MapScreen constructor update) before committing Task 1 to ensure the worktree stayed in a compilable state across both commits. Tasks 1 and 2 were verified together. Each task was still committed as a separate atomic commit.
- **Commit:** Task 1 commit `2eafe2b` and Task 2 commit `76ecdba`

## Known Stubs

| File | Location | Description | Resolving Plan |
|------|----------|-------------|----------------|
| lib/features/home/home_screen.dart | `_homeHighScoreRepoProvider` | Private local provider; promoted to canonical by Plan 04-03 | 04-04 removes it after merge |
| lib/features/map/completion_screen.dart | `previousBest` param | Field exists but not rendered in the body | 04-05 |

These stubs are intentional and do not prevent this plan's goal (HomeScreen with 4 mode cards, navigation to MapScreen with correct mode).

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. GoRouter URL parsing uses `GameMode.values.byName()` which throws `StateError` on invalid mode names; the threat register (T-04-02-01) accepts this as the app is offline and mode values come only from HomeScreen taps.

## Self-Check: PASSED

- `lib/features/home/home_screen.dart` exists in worktree
- `lib/app.dart` updated with MaterialApp.router
- `lib/features/map/map_screen.dart` has required mode param
- `lib/features/map/completion_screen.dart` has previousBest field
- Task 1 commit `2eafe2b` verified in git log
- Task 2 commit `76ecdba` verified in git log
- `flutter analyze lib/` — no issues
- `ads_isolation_test.dart` — 1/1 passed
- `flutter build apk --debug` — Built successfully

---
*Phase: 04-game-modes-scoring*
*Completed: 2026-05-29*
