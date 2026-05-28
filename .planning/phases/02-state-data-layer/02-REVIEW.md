---
phase: 02-state-data-layer
reviewed: 2026-05-28T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - lib/features/game/game_phase.dart
  - lib/features/game/game_mode.dart
  - lib/features/game/game_session.dart
  - lib/core/ticker.dart
  - lib/core/data/high_score_repository.dart
  - lib/core/data/game_state_repository.dart
  - lib/features/game/game_session_notifier.dart
  - test/unit/game_session_notifier_test.dart
  - test/unit/high_score_repository_test.dart
  - test/unit/game_state_repository_test.dart
findings:
  critical: 2
  warning: 2
  info: 4
  total: 8
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-28T00:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

The domain types (`GamePhase`, `GameMode`, `GameSession`) are clean and well-structured. The `GameSession` sentinel-based `copyWith` pattern for nullable `activeIsoCode` is correct. Repositories follow the golf-scoring rule faithfully. The `GameStateRepository` try/catch round-trip is correct and `loadSession` handles parse failures. COPPA constraints are satisfied: no `features/ads/` imports appear in the game or core layers; no Firebase packages are present.

Two blockers exist in `RealTicker` and `GameSessionNotifier` together: calling `start()` on a still-running ticker leaks the old timer and causes double-ticking. The two-tier warning set covers an unawaited future that silently swallows persistence failures, and multiple force-unwraps on `state.value!` that will crash if the notifier is called during an async loading or error state.

---

## Critical Issues

### CR-01: `RealTicker.start()` leaks old timer on double-call — double-tick bug

**File:** `lib/core/ticker.dart:13`

**Issue:** `RealTicker.start()` overwrites `_timer` and `_onTick` without cancelling the existing timer first. If `start()` is called while a timer is already running, the previous `Timer.periodic` continues firing but its reference is lost. Both the old and new timers now invoke `_onTick` every second, doubling the tick rate. `_elapsedSeconds` increments twice per wall-clock second, scores diverge from real time, and the leaked timer cannot be stopped.

The trigger path in production is: **user taps "Play Again" while a game is in progress** — `startGame()` calls `_ticker.start(_onTick)` unconditionally (see CR-02). No `stop()` precedes it.

**Fix:**
```dart
@override
void start(void Function() onTick) {
  _timer?.cancel();   // cancel any running timer before starting a new one
  _onTick = onTick;
  _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick!());
}
```

---

### CR-02: `startGame()` does not stop the ticker before restarting — timer leak on restart

**File:** `lib/features/game/game_session_notifier.dart:51`

**Issue:** `startGame()` resets `_elapsedSeconds` and `_countdownTick` to 0 and immediately calls `_ticker.start(_onTick)`. There is no `_ticker.stop()` call first. If `startGame()` is invoked on a notifier whose ticker is already running (any phase other than `idle` or `completed`), a second timer is created without stopping the first. Combined with CR-01, this produces observable double-ticking: elapsed time advances at 2× speed and the score formula produces values twice as large as expected.

Even after CR-01 is fixed in `RealTicker`, this is still a latent issue for any `Ticker` implementation that does not self-guard in `start()`. The notifier should be the authoritative owner of ticker lifecycle.

**Fix:**
```dart
void startGame(GameMode mode) {
  _ticker.stop();          // always stop before starting
  _elapsedSeconds = 0;
  _countdownTick = 0;
  _remainingIsoCodes = [];
  state = AsyncData(
    state.value!.copyWith(
      phase: GamePhase.countdown,
      mode: mode,
      score: 0,
      elapsed: Duration.zero,
      errorCount: 0,
      activeIsoCode: null,
      hintsRemaining: 2,
    ),
  );
  _ticker.start(_onTick);
}
```

---

## Warnings

### WR-01: Unawaited `Future` in `recordDrop` — persistence failures silently swallowed

**File:** `lib/features/game/game_session_notifier.dart:102`

**Issue:** `_gameStateRepository?.saveSession(current)` is called without `await`. `saveSession` returns `Future<void>`. If the underlying `SharedPreferences.setString` call throws or rejects, the exception is lost entirely — the notifier continues as if the save succeeded. The game will not crash, but mid-game progress checkpoints are unreliable. The `unawaited_futures` lint rule (not enabled in `flutter_lints` by default) would normally catch this.

**Fix:** Make `recordDrop` async and await the save, or use `unawaited()` from `dart:async` with a logged error handler:
```dart
Future<void> recordDrop(String isoCode, {required bool isCorrect}) async {
  final current = state.value!;
  if (isCorrect) {
    await _gameStateRepository?.saveSession(current);
  } else {
    final newErrorCount = current.errorCount + 1;
    final newScore = (_elapsedSeconds ~/ 10) + (newErrorCount * 5);
    state = AsyncData(current.copyWith(
      errorCount: newErrorCount,
      score: newScore,
    ));
  }
}
```

---

### WR-02: Multiple `state.value!` force-unwraps will throw if notifier is in error/loading state

**File:** `lib/features/game/game_session_notifier.dart:56,91,95,100,115`

**Issue:** `startGame`, `pauseGame`, `resumeGame`, `recordDrop`, and `completeGame` all call `state.value!` unconditionally. `build()` is synchronous so `state` starts as `AsyncData`, but if any future code path (e.g., extending `build()` to be async, or an external `ref.invalidate`) leaves the provider in `AsyncLoading` or `AsyncError`, all five public methods crash with `Null check operator used on null value`. This is a defensive coding gap. It also means any widget that triggers these methods during an async rebuild triggers an unhandled exception.

**Fix:** Guard all callers with a null check and early return:
```dart
void pauseGame() {
  final current = state.value;
  if (current == null) return;
  _ticker.stop();
  state = AsyncData(current.copyWith(phase: GamePhase.paused));
}
```
Apply the same pattern to `startGame`, `resumeGame`, `recordDrop`, and `completeGame`.

---

## Info

### IN-01: `riverpod_annotation` declared as runtime dependency instead of `dev_dependency`

**File:** `pubspec.yaml:16`

**Issue:** `riverpod_annotation: ^4.0.2` is listed under `dependencies` (runtime), not `dev_dependencies`. This package only provides the `@riverpod` annotation used by code-generation at build time. No `@riverpod` annotations are used in the current codebase (verified — constraint compliant). The annotation package is not needed at runtime and ships unnecessarily in the release APK/IPA. `riverpod_generator` (also listed, under `dev_dependencies`) is already correctly placed.

**Fix:** Move `riverpod_annotation` to `dev_dependencies`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  riverpod_generator: ^4.0.3
  riverpod_annotation: ^4.0.2   # move here — annotation-only, build-time use
  build_runner: ^2.15.0
  mocktail: ^1.0.5
  flutter_lints: ^5.0.0
```

---

### IN-02: Duplicate test name `'SC3:'` in `high_score_repository_test.dart`

**File:** `test/unit/high_score_repository_test.dart:17,32`

**Issue:** Two tests inside the same `'HighScoreRepository'` group share the identical name `'SC3:'`. When either test fails, the failure output will be ambiguous — both test entries print the same label. The second test (line 32, null-score case) should be a distinct name.

**Fix:**
```dart
test('SC3: returns null when no score has been stored', () async {
  expect(await repo.getBestScore(GameMode.learn), isNull);
});
```

---

### IN-03: `mocktail` imported but never used in `game_state_repository_test.dart`

**File:** `test/unit/game_state_repository_test.dart:4`

**Issue:** `import 'package:mocktail/mocktail.dart'` is present but no `Mock`, `when`, `verify`, or `registerFallbackValue` calls appear in this file. The concrete `SharedPreferences` mock via `setMockInitialValues` is used instead. This is a dead import.

**Fix:** Remove the unused import line.

---

### IN-04: Misleading test name in `game_state_repository_test.dart`

**File:** `test/unit/game_state_repository_test.dart:44`

**Issue:** The test is named `'SC4: saveSession called once per correct drop'` but the test body performs a full round-trip serialization check (`saveSession` → `loadSession` → equality), not a call-count verification. The comment in the test body even acknowledges this: "Mock-based call-count verification lives in game_session_notifier_test.dart". The test name implies behaviour that this test does not verify, which will cause confusion when reviewing failures.

**Fix:** Rename to reflect what the test actually verifies:
```dart
test('SC4: round-trip saveSession/loadSession produces equal GameSession', () async {
```

---

_Reviewed: 2026-05-28T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
