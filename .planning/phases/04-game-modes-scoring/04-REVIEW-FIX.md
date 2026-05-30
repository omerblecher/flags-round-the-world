---
phase: 04-game-modes-scoring
fixed_at: 2026-05-29T07:40:00Z
review_path: .planning/phases/04-game-modes-scoring/04-REVIEW.md
iteration: 2
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-05-29T07:40:00Z
**Source review:** `.planning/phases/04-game-modes-scoring/04-REVIEW.md`
**Iteration:** 2

**Summary:**
- Findings in scope: 8 (4 Critical + 4 Warning)
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01 + CR-03: Remove redundant saveBestScore and guard forced unwrap

**Files modified:** `lib/features/map/map_screen.dart`
**Commit:** b58dccb
**Applied fix:** In `_advanceToNextFlag()`, removed the duplicate `await repo.saveBestScore(...)` call (line 269) since `completeGame()` already persists the score. Simultaneously fixed CR-03: moved the `mounted` check before the value read, replaced `ref.read(gameSessionProvider).value!` with a null-safe `ref.read(gameSessionProvider).value` plus an explicit `if (completedSession == null) return;` guard.

---

### CR-02: Include `_hintPenalty` in `recordDrop` incorrect-drop score

**Files modified:** `lib/features/game/game_session_notifier.dart`
**Commit:** b07c516
**Applied fix:** Added `+ _hintPenalty` to the score formula in the `else` branch of `recordDrop()`:
`final newScore = (_elapsedSeconds ~/ 10) + (newErrorCount * 5) + _hintPenalty;`
This matches the formula used in `_onTick` and `useHint()`, eliminating the visible score flicker after a wrong drop when hints have been used.

---

### CR-04: Guard `/result` route against null or invalid extra

**Files modified:** `lib/app.dart`
**Commit:** 51ea5a9
**Applied fix:** Replaced the hard cast `state.extra as Map<String, dynamic>` with a type-check pattern. The builder now checks `extra is! Map<String, dynamic>` and `session is! GameSession`, returning `const HomeScreen()` in both cases. This prevents a crash-on-launch when the OS restores the navigation stack to `/result` without extras.

---

### WR-01: Add phase guard to `useHint()` in notifier

**Files modified:** `lib/features/game/game_session_notifier.dart`
**Commit:** 166fbba + d5d213e (style fix for lint)
**Applied fix:** Added `current.phase != GamePhase.playing` to the guard condition in `useHint()`. Also wrapped the multi-condition guard in curly braces to satisfy the `curly_braces_in_flow_control_structures` lint rule (flagged by `flutter analyze`). The method now returns `false` immediately if called outside the playing phase, preventing `_hintPenalty` corruption from any caller that bypasses the UI-level guard.

---

### WR-02: Replace hard-coded `totalFlags = 196` with `countries.length`

**Files modified:** `lib/features/map/map_screen.dart`
**Commit:** 78249c4
**Applied fix:** Replaced `const totalFlags = 196` with `final totalFlags = countries.isNotEmpty ? countries.length : 1;` in `_buildMap`. The HUD progress bar now reflects the actual country count from the loaded JSON asset.

---

### WR-03: Reset per-session accumulators in `build()`

**Files modified:** `lib/features/game/game_session_notifier.dart`
**Commit:** d29fef4
**Applied fix:** Added `_elapsedSeconds = 0;`, `_countdownTick = 0;`, and `_hintPenalty = 0;` at the top of the `build()` method. This ensures that if Riverpod rebuilds the notifier (hot reload, `ref.invalidate`, test teardown/setup), the `countdownSecondsRemaining` getter and score computations start from a clean slate rather than stale values from a previous session.

---

### WR-04: Localize hint tooltip via AppLocalizations

**Files modified:** `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_es.arb`, `lib/features/game/flag_tray.dart`
**Commit:** e023a16
**Applied fix:**
1. Added `"hintTooltip"` key to `app_en.arb`: `"Reveals and zooms to the target country for 3 seconds (+5 pts)"`
2. Added `"hintTooltip"` key to `app_es.arb`: `"Muestra y acerca el país objetivo durante 3 segundos (+5 pts)"`
3. Added `import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';` to `flag_tray.dart`
4. Updated `_buildHintButton()` to accept `BuildContext context` parameter and use `AppLocalizations.of(context).hintTooltip` instead of the hardcoded English string literal
5. Updated the call site in `build()` to pass `context`: `_buildHintButton(context)`

`flutter gen-l10n` was run and confirmed no errors. `flutter analyze lib/` reports no issues.

---

## flutter analyze results

`flutter analyze lib/` — **No issues found.**

Full project `flutter analyze` shows 8 pre-existing issues all in test files (unused imports, unnecessary casts, style warnings in test helpers). None are in lib/ source files and none were introduced by these fixes.

---

_Fixed: 2026-05-29T07:40:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
