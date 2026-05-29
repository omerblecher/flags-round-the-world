---
phase: 04-game-modes-scoring
reviewed: 2026-05-29T00:00:00Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - lib/app.dart
  - lib/core/ads/ad_load_state.dart
  - lib/core/ads/ad_service.dart
  - lib/core/ads/ad_service_provider.dart
  - lib/core/data/country_data_service.dart
  - lib/core/data/high_score_repository.dart
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
  critical: 3
  warning: 5
  info: 4
  total: 12
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-05-29T00:00:00Z
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Phase 4 introduces four game modes, a HUD, hint system, star rating on completion, and personal best tracking. The structural approach is sound — the score model is intentional golf-style (lower is better), the ad isolation boundary is correctly maintained, and the hint/zoom animation plumbing is coherent.

Three blockers are present: a double-save of the best score that corrupts the `previousBest` comparison shown on the completion screen, a missing phase-guard in `useHint` that allows hint penalty to accrue outside an active round, and a crash risk from an unchecked forced-unwrap (`value!`) when completing a game after the widget is disposed. Five warnings cover inconsistent score re-computation, a hardcoded country count magic number, unused notifier state, a `FutureBuilder` re-fire on every rebuild, and a one-sided `computeStarCount` / `_CompletionScreenState` logic divergence. Four info items call out dead code, suppressed linting, and minor UX gaps.

---

## Critical Issues

### CR-01: Best score saved twice — `previousBest` passed to CompletionScreen is wrong

**File:** `lib/features/map/map_screen.dart:265-269`

**Issue:** `_advanceToNextFlag` fetches `previousBest` before calling `completeGame()`, then unconditionally calls `repo.saveBestScore` a second time after `completeGame()` has already saved it (line 138 of `game_session_notifier.dart`). Because `saveBestScore` uses a "save if better" guard, the second call is harmless for the stored value — but the first call reads `sessionBeforeComplete.score`, which is the score at the moment the last flag was dropped, not the final score after the ticker stops. The ticker is still running between the read and the `completeGame()` await, so `sessionBeforeComplete.score` may be 1-2 points lower than the score that actually gets persisted. The result is that `previousBest` passed to `CompletionScreen` is fetched before the new score is written, but after the old best has already been superseded on a prior run, so star rating can show 3 stars on a run that set no new personal best.

Additionally, the explicit `await repo.saveBestScore(...)` on line 269 is entirely redundant because `GameSessionNotifier.completeGame()` already calls `_highScoreRepository.saveBestScore` (line 138). When the notifier is created with the production `highScoreRepositoryProvider` wiring (Phase 6), this causes two writes per game completion.

**Fix:** Remove the redundant `saveBestScore` call from `_advanceToNextFlag`. Fetch `previousBest` before completing the game, and pass it directly — no second save needed:

```dart
// _advanceToNextFlag — corrected completion block
final sessionBeforeComplete = ref.read(gameSessionProvider).value!;
final repo = await ref.read(highScoreRepositoryProvider.future);
final previousBest = await repo.getBestScore(sessionBeforeComplete.mode);
await ref.read(gameSessionProvider.notifier).completeGame(); // saves internally
// Do NOT call repo.saveBestScore here — completeGame() already does it.
final completedSession = ref.read(gameSessionProvider).value!;
if (mounted) {
  context.go('/result', extra: {
    'session': completedSession,
    'previousBest': previousBest,
  });
}
```

---

### CR-02: `useHint` can be called outside `GamePhase.playing` — penalty accrues on idle/paused state

**File:** `lib/features/game/game_session_notifier.dart:120-131`

**Issue:** `useHint` checks `hintsRemaining <= 0` but does not guard against the game being in a non-playing phase. If `useHint` is somehow invoked while the game is paused or in countdown (possible if the hint button is tapped through a race condition or programmatically during tests), `_hintPenalty` is incremented and the new score is committed to state. When the ticker resumes, `_onTick` then recomputes the score including this penalty at every subsequent tick, so the penalty double-counts: it was already applied once by `useHint` and is re-applied on every tick thereafter.

The `_MapScreenState._useHint` caller does check `session.phase != GamePhase.playing` at line 165, but that guard lives in the view, not the model. Any other caller (e.g. test code, future refactors) bypasses it.

**Fix:** Add a phase guard inside `useHint`:

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

### CR-03: Forced-unwrap `state.value!` after `await` in `completeGame` — crash when widget is disposed mid-flight

**File:** `lib/features/map/map_screen.dart:270`

**Issue:** `_advanceToNextFlag` awaits `ref.read(highScoreRepositoryProvider.future)` (line 266) and then awaits `completeGame()` (line 268), then reads `ref.read(gameSessionProvider).value!` with a force-unwrap (line 270). Between any of these awaits the user can navigate away — GoRouter's `context.go` can be called by a back-gesture, completing route, or test harness. If the `ProviderContainer` is disposed during either await, `gameSessionProvider` may return `AsyncLoading` or `AsyncError`, making `.value` null and crashing with a null assertion error.

**Fix:** Guard the forced-unwrap:

```dart
final completedSession = ref.read(gameSessionProvider).value;
if (completedSession == null || !mounted) return;
context.go('/result', extra: {
  'session': completedSession,
  'previousBest': previousBest,
});
```

---

## Warnings

### WR-01: `recordDrop` on incorrect drop omits `_hintPenalty` from re-computed score — penalty disappears

**File:** `lib/features/game/game_session_notifier.dart:106-112`

**Issue:** When an incorrect drop is recorded, `newScore` is computed as `(_elapsedSeconds ~/ 10) + (newErrorCount * 5)` — `_hintPenalty` is missing. The ticker's `_onTick` adds it back on the next second, so the penalty flickers off for up to one second after a wrong drop. For a player who has used hints and is making errors, the displayed score briefly drops by `_hintPenalty * 5` points, then jumps back up, which is confusing.

**Fix:**
```dart
final newScore = (_elapsedSeconds ~/ 10) + (newErrorCount * 5) + _hintPenalty;
```

---

### WR-02: Magic number `196` hard-coded for `totalFlags` in HUD — diverges from actual country count

**File:** `lib/features/map/map_screen.dart:455`

**Issue:** `const totalFlags = 196` is hard-coded in `_buildMap`. The actual country list is loaded from `world_map_paths.json` and available as `countries.length` or `_countries.length` in the same scope. If the asset ever contains 195 or 197 entries (Natural Earth data revisions, disputed territories), the progress bar will either never fill or overflow its `1.0` maximum. `LinearProgressIndicator` with `value > 1.0` silently clamps, but the progress display will read "196/195" or "195/196", misleading the player.

**Fix:**
```dart
final totalFlags = _countries.isNotEmpty ? _countries.length : 196;
```
Pass this through `GameHud` instead of the constant.

---

### WR-03: `FutureBuilder` in `HomeScreen` re-fires on every parent rebuild — score flickers

**File:** `lib/features/home/home_screen.dart:73-82`

**Issue:** `FutureBuilder<int?>(future: repo.getBestScore(info.mode), ...)` is called inside `itemBuilder`, which Flutter re-invokes whenever the list is rebuilt. Since `getBestScore` returns a new `Future` on each call, `FutureBuilder` re-enters `ConnectionState.waiting` on every rebuild, causing the displayed score to momentarily show the loading state (empty/dash) before displaying the result again. This creates a visible flicker whenever the `HomeScreen` rebuilds (e.g. on orientation change, or after a game completes and the user returns here).

**Fix:** Hoist the futures into the widget's `build` by memoising them in a `ConsumerStatefulWidget`, or read all four scores once outside `itemBuilder`:

```dart
// In _buildModeList, before ListView.separated:
final futures = {
  for (final info in modes) info.mode: repo.getBestScore(info.mode)
};
// Then in itemBuilder:
future: futures[info.mode]!,
```

---

### WR-04: `countdownSecondsRemaining` getter is publicly exposed but `_countdownTick` is never reset on `build()` rebuild

**File:** `lib/features/game/game_session_notifier.dart:50`

**Issue:** `build()` returns the initial idle `GameSession` but does not reset `_countdownTick`, `_elapsedSeconds`, or `_hintPenalty`. If the Riverpod container invalidates and rebuilds the notifier mid-session (e.g. due to hot reload or `ref.invalidate`), these accumulators retain stale values from the previous session. The `startGame` method does reset them, but a rebuild prior to `startGame` will expose stale data via `countdownSecondsRemaining`. More concretely, if `ref.onDispose` fires and the notifier is rebuilt (e.g. in a test that calls `container.dispose()` and creates a new one with the same overrides), the second session starts with non-zero penalty from the first.

**Fix:** Reset all per-session accumulators in `build()`:

```dart
@override
GameSession build() {
  _elapsedSeconds = 0;
  _countdownTick = 0;
  _hintPenalty = 0;
  ref.onDispose(_ticker.stop);
  return const GameSession( ... );
}
```

---

### WR-05: Route `/result` uses unguarded `as` cast — crashes on malformed `extra`

**File:** `lib/app.dart:29-33`

**Issue:** The `/result` route casts `state.extra as Map<String, dynamic>` without null-checking, then performs two more `as` casts on values within the map. If `context.go('/result', extra: ...)` is called with a missing key, or if GoRouter's deep-link restoration provides a null `extra` (which it does on cold-start deep-link to `/result`), line 29 throws a `TypeError` and the app crashes. GoRouter does not preserve `extra` across process death.

**Fix:** Add a null guard and avoid force-casting:

```dart
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
```

---

## Info

### IN-01: `_remainingIsoCodes` in `GameSessionNotifier` is dead code — suppressed lint

**File:** `lib/features/game/game_session_notifier.dart:32-33`

**Issue:** `_remainingIsoCodes` is declared and assigned in `startGame` but never read. The `// ignore: unused_field` annotation confirms this is acknowledged dead code. The comment says it is "kept here so the notifier owns the full session state without model changes in a later phase," but the actual sequence is managed by `_MapScreenState._remainingIsoCodes` in the view. This creates false symmetry between view and notifier state, which will cause confusion when Phase 5 tries to persist or restore session state.

**Fix:** Remove the field from the notifier entirely until Phase 5 requires it, or document explicitly that it will replace the view-local list in Phase 5. Suppressing an unused-field lint as a placeholder is a code smell — use a `// TODO(phase-5): migrate sequence ownership here` comment without the suppression.

---

### IN-02: `computeStarCount` top-level function and `_CompletionScreenState.initState` duplicate star logic

**File:** `lib/features/map/completion_screen.dart:12-17` and `lib/features/map/completion_screen.dart:42-58`

**Issue:** The star count computation is written twice: once in `computeStarCount` (a standalone testable function) and once in `_CompletionScreenState.initState` (inlined copy). The `_isNewPb` flag is computed inline in `initState` and diverges slightly: `initState` treats `previousBest == null` as `_isNewPb = false` and 3 stars, while `computeStarCount` also returns 3 for null but has no concept of `_isNewPb`. If the branch logic in one is ever updated, the other will silently differ.

**Fix:** Use `computeStarCount` in `initState` and derive `_isNewPb` from the same comparison:

```dart
_starCount = computeStarCount(score, prev);
_isNewPb = prev != null && score < prev;
```

---

### IN-03: `countryNamesProvider` locale is hardcoded to English — ignores device locale

**File:** `lib/core/data/country_data_service.dart:44-46`

**Issue:**
```dart
final countryNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  return CountryDataService().loadCountryNames(const Locale('en'));
});
```
The locale is hard-wired to English regardless of the device locale or any `localeProvider` that might be introduced in Phase 5. Since `CountryDataService.loadCountryNames` already supports locale overlays, this is functional scaffolding that silently ignores the i18n infrastructure already in place.

**Fix:** Either thread the device locale through (using a `localeProvider`) or add a prominent TODO so Phase 5 does not overlook this.

---

### IN-04: `_ConfettiPainter._particles` is a `static final` — particles survive screen disposal and are shared across instances

**File:** `lib/features/map/completion_screen.dart:200`

**Issue:** `static final List<_Particle> _particles = _generateParticles()` means the particle list is generated once per application lifetime and shared by all `_ConfettiPainter` instances. This is intentional for the deterministic fixed-seed layout, but the field is mutable (`List`, not `const`). If any future code modifies the list (e.g. filtering or sorting particles for a variation), it will affect all past and future painter instances globally.

**Fix:** Change to an unmodifiable view or document clearly that mutation is prohibited:

```dart
static final List<_Particle> _particles =
    List.unmodifiable(_generateParticles());
```

---

_Reviewed: 2026-05-29T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
