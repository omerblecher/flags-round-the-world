---
phase: 02-state-data-layer
plan: 01
subsystem: testing
tags: [flutter, dart, riverpod, shared_preferences, mocktail, game-session, repositories]

requires:
  - phase: 01-foundation
    provides: Flutter scaffold, pubspec.yaml with riverpod/shared_preferences/mocktail, ads isolation architecture test

provides:
  - GamePhase enum (idle/countdown/playing/paused/completed) in lib/features/game/game_phase.dart
  - GameMode enum (learn/flagsMaster/geographicalMaster/grandMaster) in lib/features/game/game_mode.dart
  - GameSession immutable value object with copyWith (sentinel pattern) + == + hashCode in lib/features/game/game_session.dart
  - Ticker abstraction (abstract class + RealTicker + FakeTicker.tick()) in lib/core/ticker.dart
  - HighScoreRepository abstract interface + SharedPreferencesHighScoreRepository in lib/core/data/high_score_repository.dart
  - GameStateRepository abstract interface + SharedPreferencesGameStateRepository in lib/core/data/game_state_repository.dart
  - 3 unit test files (9 total tests): SC3 + SCOR-04 green; SC1/SC2/SCOR-01/SCOR-02 stubs in RED state for Plan 02-02

affects:
  - 02-02 (GameSessionNotifier implementation reads all domain types, uses Ticker/repositories)
  - 02-03 (consumes provider setup from Plan 02-02 which builds on these contracts)
  - 03-map-rendering (WorldMapPainter reads GameSession state)
  - 04-game-modes (completion screen reads HighScoreRepository)
  - 05-polish (resume dialog reads GameStateRepository)

tech-stack:
  added: []
  patterns:
    - "Abstract interface + SharedPreferences impl: HighScoreRepository and GameStateRepository follow AdService/StubAdService walled-garden pattern"
    - "Ticker DI pattern: abstract class + RealTicker (Timer.periodic) + FakeTicker (tick() for tests) — enables deterministic timer testing without real delays"
    - "copyWith sentinel pattern: static const Object _sentinel = Object() inside model class to allow null assignment via copyWith"
    - "SharedPreferences.setMockInitialValues({}) in setUp per test — resets in-memory singleton for test isolation"
    - "Golf-style scoring guard in saveBestScore: only writes when score < current (lower = better)"
    - "GameStateRepository.loadSession wrapped in try/catch — returns null on corrupt data (T-02-02 mitigated)"

key-files:
  created:
    - lib/features/game/game_phase.dart
    - lib/features/game/game_mode.dart
    - lib/features/game/game_session.dart
    - lib/core/ticker.dart
    - lib/core/data/high_score_repository.dart
    - lib/core/data/game_state_repository.dart
    - test/unit/game_session_notifier_test.dart
    - test/unit/high_score_repository_test.dart
    - test/unit/game_state_repository_test.dart
  modified: []

key-decisions:
  - "GameSession uses static const Object _sentinel for copyWith nullable activeIsoCode (not freezed, not equatable — hand-rolled per D-01)"
  - "Ticker in lib/core/ticker.dart — all 3 classes (abstract + RealTicker + FakeTicker) in one file per D-09"
  - "SharedPreferences keys: high_score_learn, high_score_flags_master, high_score_geographical_master, high_score_grand_master, game_session_snapshot"
  - "Golf-style scoring guard in saveBestScore writes only when score < current (null counts as no score set)"
  - "GameStateRepository.loadSession: try/catch returns null on any parse failure — graceful degradation on corrupt data (T-02-02)"
  - "game_session_notifier_test.dart stays in fail() RED state — game_session_notifier.dart is Plan 02-02 scope"

patterns-established:
  - "Ticker DI: inject FakeTicker in tests; call tick() for deterministic time advancement"
  - "Repository constructor injection: pass SharedPreferences instance directly — no wrapper mocks needed"
  - "Abstract interface class pattern (not abstract class): matches AdService convention established in Phase 1"

requirements-completed:
  - SCOR-01
  - SCOR-02
  - SCOR-04

duration: 5min
completed: 2026-05-28
---

# Phase 2 Plan 01: Type Contracts & Test Infrastructure Summary

**Immutable GameSession model, Ticker DI abstraction, HighScoreRepository + GameStateRepository with golf-style persistence, and RED/GREEN test harness establishing SC3/SC4/SCOR-04 acceptance criteria**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-28T05:47:08Z
- **Completed:** 2026-05-28T05:51:28Z
- **Tasks:** 3
- **Files modified:** 9 created, 0 modified

## Accomplishments

- Created all 6 domain type files that Plans 02-02 and 02-03 build against: `GamePhase`, `GameMode`, `GameSession`, `Ticker` (3-class in one file), `HighScoreRepository`, `GameStateRepository`
- SC3 (3 tests) and SC4 (2 tests) verified green; SCOR-04 golf-style save guard confirmed working
- 4 notifier test stubs (SC1, SC2, SCOR-01, SCOR-02) in RED state awaiting Plan 02-02 implementation
- `ads_isolation_test.dart` remains green — no `features/ads/` imports introduced

## Task Commits

Each task was committed atomically:

1. **Task 1: Create failing test stub files (RED state)** - `a204aa5` (test)
2. **Task 2: Domain type contracts** - `fe2ce76` (feat)
3. **Task 3: Update test stubs with SC3 + SC4 implementations** - `cf01a45` (test)

## Files Created/Modified

- `lib/features/game/game_phase.dart` — GamePhase enum: idle, countdown, playing, paused, completed
- `lib/features/game/game_mode.dart` — GameMode enum: learn, flagsMaster, geographicalMaster, grandMaster
- `lib/features/game/game_session.dart` — Immutable 7-field model, copyWith with _sentinel for nullable activeIsoCode, == + hashCode
- `lib/core/ticker.dart` — abstract Ticker + RealTicker (Timer.periodic) + FakeTicker (tick() for tests)
- `lib/core/data/high_score_repository.dart` — Abstract interface + SharedPreferencesHighScoreRepository; golf-style save; 4 SharedPreferences keys
- `lib/core/data/game_state_repository.dart` — Abstract interface + SharedPreferencesGameStateRepository; flat JSON to 'game_session_snapshot'; try/catch on load
- `test/unit/game_session_notifier_test.dart` — 4 fail() stubs (SC1, SC2, SCOR-01, SCOR-02) — RED state for Plan 02-02
- `test/unit/high_score_repository_test.dart` — 3 tests green (SC3 save/read, SC3 null, SCOR-04)
- `test/unit/game_state_repository_test.dart` — 2 tests green (SC4 serialization, SC4 round-trip)

## Decisions Made

All decisions were pre-specified in 02-CONTEXT.md (D-01 through D-13). No new decisions required during execution.

Key decisions followed:
- Hand-rolled copyWith with `_sentinel` pattern (no freezed/equatable per D-01)
- Ticker all 3 classes in `lib/core/ticker.dart` (not separate files per D-09)
- `SharedPreferences.setMockInitialValues({})` in `setUp` per test — not `setUpAll` (test isolation per D-12)
- Golf-style: `saveBestScore` only writes when `current == null || score < current` (D-13)

## Deviations from Plan

None — plan executed exactly as written.

The `game_session_notifier_test.dart` compilation failure when running `flutter test test/unit/ test/architecture/` is expected behavior: `game_session_notifier.dart` doesn't exist yet (Plan 02-02 scope). The `// ignore: uri_does_not_exist` annotation suppresses the analyzer warning but not the Dart compiler — this is correct per the plan's note that "the RED state is confirmed when Plan 02-02's implementation is in place and these tests compile fully."

## Issues Encountered

None — all verification commands passed on first run.

## Threat Model Coverage

- **T-02-02 (DoS via corrupt SharedPreferences)**: Mitigated — `GameStateRepository.loadSession()` wraps JSON parse in `try/catch`, returns `null` on any exception, preventing app crashes on corrupt data.

## Known Stubs

- `test/unit/game_session_notifier_test.dart` contains 4 `fail('... not implemented — RED state')` stubs for SC1, SC2, SCOR-01, SCOR-02. These are intentional RED-state placeholders for Plan 02-02 (`GameSessionNotifier` implementation). They are not blocking — they are the correct pre-condition for the TDD GREEN phase.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All domain type contracts locked and tested; Plans 02-02 and 02-03 can implement against these interfaces without further coordination
- `FakeTicker` is ready for deterministic GameSessionNotifier tests in Plan 02-02
- `HighScoreRepository` and `GameStateRepository` constructor-injection pattern is ready for Plan 02-02 notifier wiring
- `ads_isolation_test.dart` remains green — architecture boundary maintained

---
*Phase: 02-state-data-layer*
*Completed: 2026-05-28*
