---
phase: 05
plan: 01
subsystem: foundation
tags: [model, repository, audio, l10n, tdd]
dependency_graph:
  requires: [04-game-modes-scoring]
  provides: [GameSession.matchedIsoCodes, GameStateRepository.clearSession, gameStateRepositoryProvider, UserPrefsRepository, AudioService.setMuted, phase5-arb-strings, phase5-red-stubs]
  affects: [game_session_notifier, game_state_repository, audio_service, l10n]
tech_stack:
  added: [url_launcher ^6.3.0, share_plus ^10.0.0]
  patterns: [FutureProvider async repository wiring, ??= test-injection guard, async AsyncNotifier build]
key_files:
  created:
    - lib/core/data/user_prefs_repository.dart
    - test/features/game/phase5_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - lib/features/game/game_session.dart
    - lib/core/data/game_state_repository.dart
    - lib/features/game/game_session_notifier.dart
    - lib/core/audio/audio_service.dart
    - lib/core/audio/stub_audio_service.dart
    - lib/core/audio/real_audio_service.dart
    - lib/core/l10n/app_en.arb
    - lib/core/l10n/app_es.arb
    - test/unit/game_session_notifier_test.dart
    - test/features/game/phase4_test.dart
decisions:
  - "??= pattern guards test-injected repos from being overridden by real providers in async build()"
  - "setUp made async in both game_session_notifier_test and phase4_test to await build() future"
  - "phase4_test overrides gameStateRepositoryProvider and highScoreRepositoryProvider with stubs"
  - "UserPrefsRepository uses keys tutorial_seen and mute_pref to prevent typo bugs (T-05-01-02 mitigation)"
  - "matchedIsoCodes deserialization uses null-coalescing ?? const [] to handle old/corrupt data (T-05-01-01 mitigation)"
metrics:
  duration: 900s
  completed: "2026-05-29"
  tasks: 7
  files: 14
---

# Phase 5 Plan 01: Wave 1 Foundation Summary

Wave 1 foundation for Phase 5 session polish — adds url_launcher + share_plus, extends GameSession with matchedIsoCodes, wires real repositories into async GameSessionNotifier.build(), creates UserPrefsRepository with mute/tutorial prefs, adds setMuted() to AudioService, adds all 37 Phase 5 ARB strings in EN+ES, and writes 12 RED test stubs.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add url_launcher and share_plus packages | f2abac4 | pubspec.yaml, pubspec.lock, platform registrants |
| 2 | Extend GameSession with matchedIsoCodes | 9250162 | lib/features/game/game_session.dart |
| 3 | Add clearSession(), matchedIsoCodes serialization, gameStateRepositoryProvider | b787da6 | lib/core/data/game_state_repository.dart |
| 4 | Update GameSessionNotifier — async build, restoreGame, updated recordDrop | 718f0d0 | game_session_notifier.dart + 2 test fixes |
| 5 | Add setMuted() to AudioService and create UserPrefsRepository | 3bb8cc1 | 3 audio files + user_prefs_repository.dart |
| 6 | Add all Phase 5 ARB strings and regenerate l10n | fa8c9eb | app_en.arb, app_es.arb |
| 7 | Write RED test stubs for Phase 5 | 78906ac | test/features/game/phase5_test.dart |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Existing tests broke when build() was made async**
- **Found during:** Task 4
- **Issue:** `game_session_notifier_test.dart` and `phase4_test.dart` both called `container.read(gameSessionProvider).value!` directly after creating the container. When `build()` became async, the provider was in `AsyncLoading` state, making `.value` null.
- **Fix:** Made `setUp` async and added `await container.read(gameSessionProvider.future)` to resolve initial state before tests run. For `phase4_test.dart`, also added overrides for `gameStateRepositoryProvider` and `highScoreRepositoryProvider` with stub implementations so the async `build()` doesn't try to call real SharedPreferences.
- **Files modified:** `test/unit/game_session_notifier_test.dart`, `test/features/game/phase4_test.dart`
- **Commit:** 718f0d0

## TDD Gate Compliance

Task 7 is the RED phase for Phase 5. All 12 stubs fail with `fail(...)` messages. GREEN phases will be delivered by plans 05-02 through 05-06.

## Verification Results

- flutter pub get: PASS (url_launcher + share_plus resolved)
- flutter gen-l10n: PASS (37 new ARB keys, 0 errors)
- flutter analyze lib/: PASS (0 issues)
- ads_isolation_test: PASS (1/1 green)
- game_session_notifier_test: PASS (5/5 green)
- game_state_repository_test: PASS (2/2 green)
- phase4_test: PASS (6/6 green)
- phase5_test: FAIL (12/12 red — expected RED state)

## Known Stubs

None — this plan adds primitives and test stubs, not UI. The 12 test stubs in `phase5_test.dart` are intentional RED markers tracking unimplemented features for plans 05-02 through 05-06.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns introduced. matchedIsoCodes deserialization hardened with null-coalescing per T-05-01-01.

## Self-Check: PASSED

- lib/features/game/game_session.dart: FOUND
- lib/core/data/game_state_repository.dart: FOUND
- lib/features/game/game_session_notifier.dart: FOUND
- lib/core/data/user_prefs_repository.dart: FOUND
- lib/core/audio/audio_service.dart: FOUND
- test/features/game/phase5_test.dart: FOUND
- Commit f2abac4: FOUND
- Commit 9250162: FOUND
- Commit b787da6: FOUND
- Commit 718f0d0: FOUND
- Commit 3bb8cc1: FOUND
- Commit fa8c9eb: FOUND
- Commit 78906ac: FOUND
