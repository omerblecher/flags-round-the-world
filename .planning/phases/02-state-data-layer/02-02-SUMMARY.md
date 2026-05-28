---
phase: 02-state-data-layer
plan: 02
subsystem: game-state
tags: [flutter, dart, riverpod, game-session, state-machine, tdd, scoring, ticker]

requires:
  - phase: 02-state-data-layer
    plan: 01
    provides: GameSession model, GamePhase/GameMode enums, Ticker abstraction, HighScoreRepository, GameStateRepository, RED-state test stubs

provides:
  - GameSessionNotifier (AsyncNotifier<GameSession>) with full state machine: idle → countdown → playing → paused → completed
  - gameSessionProvider (AsyncNotifierProvider, top-level, no codegen)
  - Ticker DI via constructor injection; ref.onDispose(_ticker.stop) guard
  - Scoring formula: (elapsedSeconds ~/ 10) + (errorCount * 5) — golf-style
  - countdownSecondsRemaining getter (notifier-level derived state)
  - 5 unit tests green: SC1, SC2, SCOR-01, SCOR-02, SC4

affects:
  - 02-03 (provider setup depends on gameSessionProvider declared here)
  - 03-map-rendering (WorldMapPainter reads gameSessionProvider)
  - 04-game-modes (completeGame + scoring drives completion screen)
  - 05-polish (pause/resume wired to pauseGame/resumeGame)

tech-stack:
  added: []
  patterns:
    - "Manual AsyncNotifier with constructor-injected Ticker: FakeTicker.tick() drives deterministic tests without real Timer.periodic delays"
    - "ref.onDispose(_ticker.stop): Riverpod lifecycle hook guards against Ticker leak on provider disposal (T-02-04 mitigation)"
    - "state.value null-guard in _onTick(): T-02-03 DoS mitigation — stale/null state is silently skipped"
    - "ProviderContainer override pattern: gameSessionProvider.overrideWith(() => GameSessionNotifier(ticker: fakeTicker, ...)) in test setUp"
    - "mocktail registerFallbackValue(_FakeGameSession()) in setUpAll: required for any() matchers on custom types in sound null-safe Dart"
    - "startGame as void (not async): state mutation is synchronous; no await needed; tests call without await"

key-files:
  created:
    - lib/features/game/game_session_notifier.dart
  modified:
    - test/unit/game_session_notifier_test.dart

key-decisions:
  - "gameSessionProvider declared at top level as AsyncNotifierProvider with no @riverpod annotation (D-07)"
  - "build() returns GameSession synchronously — provider initializes as AsyncData immediately, no loading state"
  - "startGame() is void (not Future<void>) — all state mutations are synchronous; countdown triggers from Ticker callbacks"
  - "_remainingIsoCodes field stubbed with // ignore: unused_field — intentional Phase 4 placeholder per plan spec"
  - "registerFallbackValue added for GameSession and GameMode in setUpAll — required for mocktail any() in sound null-safe mode"

metrics:
  duration: 3min
  completed: 2026-05-28
  tasks: 3
  files_created: 1
  files_modified: 1
---

# Phase 2 Plan 02: GameSessionNotifier — State Machine & Scoring Summary

**GameSessionNotifier: manual AsyncNotifier with FakeTicker DI, idle→completed state machine, golf-style scoring formula, and all 5 TDD tests (SC1, SC2, SCOR-01, SCOR-02, SC4) green**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-28T05:55:24Z
- **Completed:** 2026-05-28T05:58:56Z
- **Tasks:** 3 (RED, GREEN, REFACTOR)
- **Files created:** 1 (`lib/features/game/game_session_notifier.dart`)
- **Files modified:** 1 (`test/unit/game_session_notifier_test.dart`)

## Accomplishments

- Replaced 4 `fail()` stubs with real SC1/SC2/SCOR-01/SCOR-02 test implementations; added SC4 mock-write-count test
- Implemented full `GameSessionNotifier` with 5-phase state machine, Ticker DI, golf-style scoring, and repository writes
- All 5 notifier tests green; `ads_isolation_test.dart` green; 18 tests total across unit + architecture suites
- `flutter analyze lib/features/game/game_session_notifier.dart` exits 0 (no issues)
- Zero imports from `features/ads/` — walled-garden constraint maintained

## Task Commits

Each task was committed atomically per TDD gate:

1. **Task 1: RED — failing tests for GameSessionNotifier** - `3856080` (test)
2. **Task 2: GREEN — implement GameSessionNotifier** - `3e41403` (feat)
3. **Task 3: REFACTOR — clean up after GREEN phase** - `e5b3e08` (refactor)

## Files Created/Modified

- `lib/features/game/game_session_notifier.dart` — `AsyncNotifier<GameSession>` with full state machine, scoring, repository writes, Ticker DI, and `countdownSecondsRemaining` getter
- `test/unit/game_session_notifier_test.dart` — 5 tests green: SC1 (state transitions), SC2 (18-point scoring), SCOR-01 (time score), SCOR-02 (error score), SC4 (saveSession call count via mocktail)

## Decisions Made

Pre-specified in 02-CONTEXT.md / 02-02-PLAN.md. No new architectural decisions required during execution.

- `startGame()` made `void` (not `Future<void>`) — state mutation is synchronous; `async` was superfluous
- `_remainingIsoCodes` kept as Phase 4 placeholder with `// ignore: unused_field`
- `registerFallbackValue` added for `GameSession` and `GameMode` (mocktail requirement for `any()` matchers)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical setup] Added mocktail registerFallbackValue for GameSession and GameMode**
- **Found during:** GREEN phase — tests failed immediately with "Bad state: A test tried to use `any` or `captureAny` on a parameter of type `GameSession`, but registerFallbackValue was not previously called"
- **Issue:** Mocktail's sound null-safe mode requires `registerFallbackValue` for any custom type used with `any()` matcher. The test stub in Plan 02-01 used `fail()` so this was not exercised during RED.
- **Fix:** Added `class _FakeGameSession extends Fake implements GameSession {}` and `setUpAll` block with `registerFallbackValue(_FakeGameSession())` and `registerFallbackValue(GameMode.learn)`
- **Files modified:** `test/unit/game_session_notifier_test.dart`
- **Commit:** `3e41403` (included in GREEN commit)

## TDD Gate Compliance

- RED gate: `3856080` — `test(02-02): add failing tests for GameSessionNotifier (RED state)` — tests compile but produce undefined-name errors (game_session_notifier.dart absent)
- GREEN gate: `3e41403` — `feat(02-02): implement GameSessionNotifier — full state machine with scoring` — all 5 tests pass
- REFACTOR gate: `e5b3e08` — `refactor(02-02): clean up GameSessionNotifier after GREEN phase` — tests still pass

## Threat Model Coverage

- **T-02-03 (DoS via null state in _onTick)**: Mitigated — `final current = state.value; if (current == null) return;` guard at top of `_onTick()`
- **T-02-04 (Ticker leak on dispose)**: Mitigated — `ref.onDispose(_ticker.stop)` registered in `build()` method
- **T-02-05 (ads import)**: Mitigated — `ads_isolation_test.dart` green; `grep -rn "features/ads/" lib/features/game/` returns no matches

## Known Stubs

- `_remainingIsoCodes = []` in `GameSessionNotifier` — Phase 4 placeholder. Does not affect Phase 2 or 3 behavior. Will be populated by Phase 4's mode-specific flag pool logic.

## Self-Check

Checked post-SUMMARY creation:

- `lib/features/game/game_session_notifier.dart` — FOUND
- `test/unit/game_session_notifier_test.dart` — FOUND (modified)
- Commits: `3856080` (RED), `3e41403` (GREEN), `e5b3e08` (REFACTOR) — all present in git log

## Self-Check: PASSED

---
*Phase: 02-state-data-layer*
*Completed: 2026-05-28*
