---
plan: 03-04
phase: 03-map-rendering-drag-drop
status: complete
completed: 2026-05-28
---

# Plan 03-04 Summary: Feedback + Audio + Haptics + Flag Sequence + Completion Screen

## What was built

- `lib/features/map/map_screen.dart` — full rewrite with:
  - Top-level `buildFlagSequence(List<CountryData>)` exposed for unit testing
  - `_initSequence()` with `_sequenceInitialized` guard — runs once when country data arrives
  - `_remainingIsoCodes`, `_matchedIsoCodes` state; `_currentIsoCode` seeded from sequence
  - `_advanceToNextFlag()` — removes from front, calls `completeGame()` + pushes CompletionScreen on last flag, otherwise re-creates `_trayKey` to trigger AnimatedSwitcher transition
  - `_animateCorrectDrop()` — OverlayEntry fly-to-centroid animation (scale 1→0.15, opacity 1→0, position start→centroid) using dynamic AnimationController with `TickerProviderStateMixin`
  - `_centroidToScreen()` — scene-to-global coords via `MatrixUtils.transformPoint`
  - Full `_handleDrop()` — correct: haptic light + `playCorrect()` + fly animation; incorrect: haptic medium + `playError()` + `triggerBounce()`
  - `_matchedIsoCodes` passed live to `WorldMapPainter` (greyed matched countries)
  - `_activeOverlay` disposed in `dispose()` as safety net
  - `TickerProviderStateMixin` for multiple dynamic AnimationController instances

- `lib/features/map/completion_screen.dart` — new file:
  - Shows score, elapsed time (formatted as `Xm Ys`), and Play Again button
  - `Navigator.popUntil(isFirst)` to return to home

- `lib/core/l10n/app_en.arb` — added `completionTitle`, `completionScore`, `completionElapsed`, `completionPlayAgain`
- `lib/core/l10n/app_es.arb` — same keys in Spanish
- `lib/generated/l10n/` — regenerated via `flutter gen-l10n`
- `test/features/map/flag_sequence_test.dart` — 3 GREEN tests replacing 3 RED stubs

## Verification results

```
flutter test test/features/map/flag_sequence_test.dart test/architecture/ads_isolation_test.dart
00:00 +4: All tests passed!

flutter analyze lib/features/map/ lib/features/game/
No issues found!

flutter build apk --debug
✓ Built build/app/outputs/flutter-apk/app-debug.apk

grep -rn "features/ads/" lib/features/map/ lib/features/game/
(zero matches — ads isolation intact)
```

## Notes for Plan 03-05

- `_countryName()` still returns `isoCode.toUpperCase()` — real l10n names wired in Phase 4
- The `completeGame()` → `CompletionScreen` path needs an integration test in Phase 4 or 5 once GameSession is wired with `startGame()` in the UI
- `_animateCorrectDrop` falls back to `_advanceToNextFlag()` directly if the tray card RenderBox is null (e.g. widget not yet laid out) — safe for edge cases
- WorldMapPainter `shouldRepaint` checks `matchedIsoCodes.length` — now receives live `_matchedIsoCodes` so matched countries grey out correctly as the game progresses
- `_trayKey` is re-created (new GlobalKey instance) in `_advanceToNextFlag()` so AnimatedSwitcher detects the key change and plays the slide-in transition; `triggerBounce()` is called before `setState` to ensure the old instance is still valid
