---
phase: 04-game-modes-scoring
reviewed: 2026-05-29T00:00:00Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - lib/app.dart
  - lib/core/ads/ad_load_state.dart
  - lib/core/ads/ad_service.dart
  - lib/core/ads/ad_service_provider.dart
  - lib/core/data/country_data_service.dart
  - lib/core/data/high_score_repository.dart
  - lib/core/l10n/app_en.arb
  - lib/core/l10n/app_es.arb
  - lib/features/ads/ad_load_state.dart
  - lib/features/ads/ad_service.dart
  - lib/features/game/flag_tray.dart
  - lib/features/game/game_hud.dart
  - lib/features/game/game_session_notifier.dart
  - lib/features/home/home_screen.dart
  - lib/features/map/completion_screen.dart
  - lib/features/map/flag_sequence.dart
  - lib/features/map/highlight_painter.dart
  - lib/features/map/map_screen.dart
  - lib/features/map/world_map_painter.dart
  - test/features/game/phase4_test.dart
  - test/features/home/home_screen_test.dart
  - test/features/map/flag_sequence_test.dart
  - test/features/map/grand_master_sequence_test.dart
findings:
  critical: 4
  warning: 4
  info: 5
  total: 13
status: issues_found
---

# Phase 04: Code Review Report (Re-review after fix commits)

**Reviewed:** 2026-05-29T00:00:00Z
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

Two fix commits landed since the prior review:
- `fix(04): English country names + hint locating snackbar`
- `fix(04): HUD size, hint tooltip, snackbar context bug, hint penalty`

**Issues resolved since prior review:**
- WR-03 (FutureBuilder re-fires): The `FutureBuilder` is now built with a stable `repo` reference from `ref.watch(highScoreRepositoryProvider)`. Flutter's `FutureBuilder` only re-executes when the `future` instance changes; since `repo` is a stable object and `repo.getBestScore(mode)` returns a new Future each build, the flicker risk is lower — however a `ConsumerStatefulWidget` memoisation approach would be fully safe. Marked as partially mitigated, downgraded to Info.
- WR-01 (hint penalty missing from `recordDrop`): Partially — `useHint()` now correctly includes `_hintPenalty` in its score recomputation, but `recordDrop()` on an **incorrect** drop still omits `_hintPenalty`. Remains a BLOCKER.

**Issues still present (from prior review):**
- CR-01 (double save / previousBest): The double-save remains. `previousBest` value is now correctly captured before `completeGame()`, which is an improvement, but the redundant `repo.saveBestScore` call on line 269 persists.
- CR-02 (useHint outside playing phase): UI-level guard added in `_useHint()`, but the notifier method itself is still unguarded. Downgraded to WARNING given the UI guard.
- CR-03 (forced unwrap after await): Still present.
- WR-02 (magic number 196): Still present.
- WR-04 (countdownSecondsRemaining not reset in build): Still present.
- WR-05 (unguarded cast in /result): Still present, upgraded to CRITICAL.
- IN-01 through IN-04: All still present.

**New issues found:**
- WR-NEW: Hint tooltip in `FlagTray` is a hardcoded English string, not localized.
- IN-NEW: Test suite has no assertion that hint penalty appears in the score.

---

## Critical Issues

### CR-01: Best score saved twice on game completion

**File:** `lib/features/map/map_screen.dart:268-269`

**Issue:** `_advanceToNextFlag()` calls `ref.read(gameSessionProvider.notifier).completeGame()` at line 268. Inside `completeGame()`, the notifier already calls `_highScoreRepository.saveBestScore(current.mode, current.score)` (game_session_notifier.dart line 138). Then `map_screen.dart` line 269 calls `await repo.saveBestScore(sessionBeforeComplete.mode, sessionBeforeComplete.score)` a second time. Two saves occur for every game completion. The `saveBestScore` guard (`score < current`) prevents data corruption in isolation, but:

1. The two saves may use **different score values**: `sessionBeforeComplete.score` is captured before `completeGame()` stops the ticker. If the ticker fires in the gap, `completeGame()` saves a higher score than the first save. On a future run both saves will then have different reference points.
2. The redundant call couples `_advanceToNextFlag` to the persistence implementation detail, meaning the notifier's `completeGame()` cannot be trusted as the sole persistence boundary.
3. In Phase 6, when `_highScoreRepository` is wired to the real SharedPreferences (non-stub), this becomes two actual disk writes per game completion.

**Fix:** Remove line 269 from `_advanceToNextFlag`. `completeGame()` owns score persistence entirely:

```dart
// _advanceToNextFlag — corrected completion block
final sessionBeforeComplete = ref.read(gameSessionProvider).value!;
final repo = await ref.read(highScoreRepositoryProvider.future);
final previousBest = await repo.getBestScore(sessionBeforeComplete.mode);
await ref.read(gameSessionProvider.notifier).completeGame();
// REMOVE: await repo.saveBestScore(...) -- completeGame() already handles this
final completedSession = ref.read(gameSessionProvider).value;
if (completedSession == null || !mounted) return;
context.go('/result', extra: {
  'session': completedSession,
  'previousBest': previousBest,
});
```

---

### CR-02: `recordDrop` on incorrect drop omits `_hintPenalty` — score flickers after wrong drop

**File:** `lib/features/game/game_session_notifier.dart:107`

**Issue:** The incorrect-drop branch recomputes score as:
```dart
final newScore = (_elapsedSeconds ~/ 10) + (newErrorCount * 5);
```
`_hintPenalty` is absent. The ticker's `_onTick` adds it back one second later. For a player who has used hints and then makes a wrong drop, the displayed score momentarily drops by `_hintPenalty` points (e.g. 5 or 10), then snaps back up on the next tick. This is a visible score flicker that can mislead the player about their current standing.

The prior review filed this as WR-01. The fix commit addressed `useHint()` but did not address `recordDrop()`. It remains unfixed and is promoted to CRITICAL because it represents incorrect game state being exposed to the player.

**Fix:**
```dart
void recordDrop(String isoCode, {required bool isCorrect}) {
  final current = state.value!;
  if (isCorrect) {
    _gameStateRepository?.saveSession(current);
  } else {
    final newErrorCount = current.errorCount + 1;
    final newScore =
        (_elapsedSeconds ~/ 10) + (newErrorCount * 5) + _hintPenalty; // add _hintPenalty
    state = AsyncData(current.copyWith(
      errorCount: newErrorCount,
      score: newScore,
    ));
  }
}
```

---

### CR-03: Forced unwrap `state.value!` after async gap — crash on dispose

**File:** `lib/features/map/map_screen.dart:270`

**Issue:** `_advanceToNextFlag()` is `async` with two `await` calls (lines 266, 268). After line 268 (`await completeGame()`), line 270 reads `ref.read(gameSessionProvider).value!` with a forced unwrap. The `mounted` guard at line 271 comes one line too late — it protects `context.go(...)` but not the unwrap. Between the two awaits, if the user navigates back or the OS kills the activity, the `ProviderContainer` may be disposed. Riverpod reverts disposed providers to their initial state (`AsyncData(idle session)`), so `value` is non-null in that specific path — but if any error occurs during `completeGame()` that sets the state to `AsyncError`, `value` returns null and the force-unwrap crashes.

**Fix:** Null-safe read with a mounted check before the unwrap:

```dart
await ref.read(gameSessionProvider.notifier).completeGame();
if (!mounted) return;
final completedSession = ref.read(gameSessionProvider).value;
if (completedSession == null) return;
context.go('/result', extra: {
  'session': completedSession,
  'previousBest': previousBest,
});
```

---

### CR-04: Unguarded `as` cast on `/result` route — crash on null `extra`

**File:** `lib/app.dart:29`

**Issue:** `final extra = state.extra as Map<String, dynamic>;` performs a hard cast with no null guard. `state.extra` is typed `Object?` in GoRouter. GoRouter does **not** persist `extra` across process death. If the app is killed and relaunched via a deep link or if the OS restores the navigation stack to `/result` without extras, `state.extra` is `null` and this throws `type 'Null' is not a subtype of type 'Map<String, dynamic>'`, crashing the app on launch.

This was filed as WR-05 in the prior review. With no fix applied and a clear crash-on-launch scenario for OS-level state restoration, it is promoted to CRITICAL.

**Fix:** Guard the cast and redirect to home on invalid extras:

```dart
GoRoute(
  path: '/result',
  builder: (context, state) {
    final extra = state.extra;
    if (extra is! Map<String, dynamic>) return const HomeScreen();
    final session = extra['session'];
    if (session is! GameSession) return const HomeScreen();
    return CompletionScreen(
      session: session,
      previousBest: extra['previousBest'] as int?,
    );
  },
),
```

---

## Warnings

### WR-01: `useHint()` in notifier has no phase guard — callable from any phase

**File:** `lib/features/game/game_session_notifier.dart:120-131`

**Issue:** The prior review filed this as CR-02. A UI-level guard was added in `_MapScreenState._useHint` (map_screen.dart line 165): `if (session == null || session.phase != GamePhase.playing) return;`. This prevents the button from triggering a hint outside a live round. However, the notifier method itself has no phase guard. Any caller other than `_useHint` (test code, future UI, refactors) can invoke `useHint()` during countdown, paused, or completed phases and will corrupt `_hintPenalty` and `hintsRemaining`. The fix is defense-in-depth at the model layer.

**Fix:** Add a phase guard in the notifier:

```dart
bool useHint() {
  final current = state.value;
  if (current == null ||
      current.phase != GamePhase.playing ||
      current.hintsRemaining <= 0) return false;
  // ... rest unchanged
}
```

---

### WR-02: Magic number `196` hard-coded for `totalFlags` — diverges from actual country count

**File:** `lib/features/map/map_screen.dart:455`

**Issue:** `const totalFlags = 196` is hard-coded in `_buildMap`. The actual country list is loaded from `world_map_paths.json` and available as `countries.length` in the same scope. If the asset contains a different number of entries, the progress bar will never fill (or overflow and clamp), and the completion trigger in `_advanceToNextFlag` actually fires correctly — creating a situation where the game ends but the HUD still shows incomplete progress.

**Fix:**
```dart
// Replace const totalFlags = 196 with:
final totalFlags = countries.isNotEmpty ? countries.length : 1;

GameHud(
  score: session?.score ?? 0,
  elapsed: session?.elapsed ?? Duration.zero,
  matchedCount: matchedCount,
  totalFlags: totalFlags,
),
```

---

### WR-03: `countdownSecondsRemaining` getter backed by field not reset in `build()`

**File:** `lib/features/game/game_session_notifier.dart:50`

**Issue:** `_countdownTick` is reset in `startGame()` (line 54) but not in `build()`. If Riverpod rebuilds the notifier (hot reload, `ref.invalidate`, test teardown/setup without full container dispose), `countdownSecondsRemaining` returns a stale value. A consumer that reads this getter before `startGame()` is called on the rebuilt notifier sees leftover state from the previous session. In tests, a container that creates two sequential `GameSessionNotifier` instances via overrides is at risk.

**Fix:** Reset all per-session accumulators in `build()`:

```dart
@override
GameSession build() {
  _elapsedSeconds = 0;
  _countdownTick = 0;
  _hintPenalty = 0;
  ref.onDispose(_ticker.stop);
  return const GameSession(
    phase: GamePhase.idle,
    mode: GameMode.learn,
    score: 0,
    elapsed: Duration.zero,
    errorCount: 0,
    activeIsoCode: null,
    hintsRemaining: 2,
  );
}
```

---

### WR-04: Hint tooltip in `FlagTray` is a hardcoded English string — not localized

**File:** `lib/features/game/flag_tray.dart:87`

**Issue:** `message: 'Reveals and zooms to the target country for 3 seconds (+5 pts)'` is a string literal. All other user-visible strings in the app go through ARB. This tooltip will not be translated for the Spanish locale (or any future locale). For a child-directed app targeting international audiences, untranslated strings are a quality regression.

**Fix:** Add an ARB key to both locale files and reference it from the widget:

```
// app_en.arb
"hintTooltip": "Reveals and zooms to the target country for 3 seconds (+5 pts)",

// app_es.arb
"hintTooltip": "Muestra y acerca el país objetivo durante 3 segundos (+5 pts)",
```

In `_buildHintButton`, pass `context` or read `AppLocalizations` from the `build` context that's already in scope (since `_buildHintButton` is called from `build`):

```dart
Widget _buildHintButton(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return Tooltip(
    message: l10n.hintTooltip,
    // ...
  );
}
```

---

## Info

### IN-01: `_remainingIsoCodes` in `GameSessionNotifier` is dead code with suppressed lint

**File:** `lib/features/game/game_session_notifier.dart:32-33`

**Issue:** `_remainingIsoCodes` is declared, initialized in `startGame()`, and never read. The `// ignore: unused_field` annotation acknowledges this. The field creates false symmetry with `_MapScreenState._remainingIsoCodes` and will cause confusion when Phase 5 migrates sequence state.

**Fix:** Remove the field and suppression comment until Phase 5 actually requires it. Add a `// TODO(phase-5)` comment at the relevant location instead.

---

### IN-02: Star rating logic duplicated between `computeStarCount` and `_CompletionScreenState.initState`

**File:** `lib/features/map/completion_screen.dart:12-17` and `45-58`

**Issue:** `initState` re-implements the star count and PB detection logic inline rather than calling `computeStarCount`. If the thresholds (currently 20%) change, both sites must be updated in sync. The `computeStarCount` function exists explicitly for unit testing and reuse, but `initState` ignores it.

**Fix:**
```dart
@override
void initState() {
  super.initState();
  final prev = widget.previousBest;
  final score = widget.session.score;
  _starCount = computeStarCount(score, prev);
  _isNewPb = prev != null && score < prev;
  // ... rest unchanged (pbController, overlay setup)
}
```

---

### IN-03: `countryNamesProvider` locale hardcoded to English — ignores device locale

**File:** `lib/core/data/country_data_service.dart:44-46`

**Issue:** `const Locale('en')` is passed regardless of the device's current locale. Since `loadCountryNames` already handles locale overlays and both ARB files exist, this is functional dead code for the locale parameter. Country names displayed on cards and map labels will always be English.

**Fix:** Use a `FutureProvider.family` keyed on the locale, or add a `localeProvider` and watch it:

```dart
final countryNamesProvider = FutureProvider.family<Map<String, String>, Locale>(
  (ref, locale) async => CountryDataService().loadCountryNames(locale),
);
// Callers use: ref.watch(countryNamesProvider(deviceLocale))
```

---

### IN-04: `_ConfettiPainter._particles` is mutable `static final` list

**File:** `lib/features/map/completion_screen.dart:200`

**Issue:** `static final List<_Particle> _particles = _generateParticles()` is a mutable list. While the `const` constructor signals immutability, the backing particle list can be mutated by any code holding a reference. Wrapping in `List.unmodifiable` enforces the intent at runtime.

**Fix:**
```dart
static final List<_Particle> _particles =
    List.unmodifiable(_generateParticles());
```

---

### IN-05: Test for `useHint` does not assert the hint penalty appears in the score

**File:** `test/features/game/phase4_test.dart:65-84`

**Issue:** The `GAME-07` test asserts `hintsRemaining` decrements from 2 to 1 but does not verify that the score increases by 5 (the hint penalty). The penalty calculation is the key game mechanic — it directly affects star ratings and personal best comparisons. Without a score assertion, the bug in CR-02 (missing `_hintPenalty` in `recordDrop`) could go undetected by this test suite.

**Fix:** Add a score assertion:

```dart
// After ticking to playing phase:
final scoreBefore = container.read(gameSessionProvider).value!.score;
final result = container.read(gameSessionProvider.notifier).useHint();
expect(result, isTrue);
final session = container.read(gameSessionProvider).value!;
expect(session.hintsRemaining, equals(1));
expect(session.score, greaterThan(scoreBefore),
    reason: 'hint penalty of 5 must be reflected immediately in score');
```

---

_Reviewed: 2026-05-29T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
