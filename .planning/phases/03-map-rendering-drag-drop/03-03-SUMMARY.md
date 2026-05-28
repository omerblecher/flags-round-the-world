---
plan: 03-03
phase: 03-map-rendering-drag-drop
status: complete
completed: 2026-05-28
---

# Plan 03-03 Summary: FlagTray + DragTarget + Hit Detection

## What was built

| File | Status |
|------|--------|
| `lib/features/map/hit_detection.dart` | NEW — pure `dart:ui`/`dart:math` hit-test logic |
| `lib/features/game/flag_tray.dart` | NEW — FlagTray widget with Draggable<String> + bounce animation |
| `lib/features/map/map_screen.dart` | UPDATED — real DragTarget wired to hitTest, FlagTray replaces placeholder |
| `test/features/map/hit_detection_test.dart` | UPDATED — 4 RED stubs → 4 GREEN tests |
| `test/features/map/drag_drop_widget_test.dart` | UPDATED — 3 RED stubs → 3 skipped (TODO Phase 4) |

## Verification results

```
flutter test hit_detection_test.dart drag_drop_widget_test.dart ads_isolation_test.dart
  → 5 passed, 3 skipped, 0 failures

flutter analyze lib/features/map/hit_detection.dart lib/features/game/flag_tray.dart lib/features/map/map_screen.dart
  → No issues found

flutter build apk --debug
  → Built build/app/outputs/flutter-apk/app-debug.apk  (26 s)
```

## Key design details

### hit_detection.dart
- `const double _kMinBboxDiagonal = 32.0` — minimum diagonal before bbox expansion kicks in.
- `hitTest(Offset scenePoint, List<CountryData> countries) → String?`
  - Primary pass: `Path.contains()` on all country paths.
  - Fallback pass: expanded bbox (scaled to 32-unit diagonal) for micro-states (e.g. LU, SM, MC).
  - Tiebreaker: smallest `width × height` bbox area wins (most-specific country).
- `_expandedBbox(CountryData)` — private helper, pure geometry, no Flutter widgets.
- No Flutter widget imports — only `dart:ui` + `dart:math`.

### flag_tray.dart
- `FlagTrayState` is **public** (not `_FlagTrayState`) so `GlobalKey<FlagTrayState>` works from MapScreen.
- `triggerBounce()` plays forward-then-reverse elasticOut animation (called on wrong drop).
- Uses `flutter_svg` `SvgPicture.asset('assets/flags/<iso>.svg')`.
- No `features/ads/` imports.

### map_screen.dart new state fields
- `List<CountryData> _countries` — populated alongside `_countryIndex` when FutureProvider resolves.
- `String _currentIsoCode = 'de'` — hardcoded placeholder; marked `// ignore: prefer_final_fields`.
- `final GlobalKey _trayCardKey` — key for the drag card widget.
- `final GlobalKey<FlagTrayState> _trayKey` — used to call `triggerBounce()` on wrong drop.

### map_screen.dart new methods
- `_handleDrop(String? hitIso, bool isCorrect)` — calls `gameSessionProvider.notifier.recordDrop()`, clears hover, triggers bounce on miss.
- `_countryName(String isoCode)` — returns `isoCode.toUpperCase()` as placeholder.

## Notes for Plan 03-04

1. **`_currentIsoCode`** is the only field that needs to be driven by a real country sequence. Plan 03-04 should replace the `'de'` placeholder with actual session logic (e.g. `ref.watch(gameSessionProvider).value?.activeIsoCode`).
2. **`_countryName(isoCode)`** is a stub returning `isoCode.toUpperCase()`. Plan 03-04 should look up the localised name from the country data JSON or ARB files.
3. **`drag_drop_widget_test.dart`** has 3 skipped tests. Plan 03-04 (or a dedicated test plan) should wire mock `GameSessionNotifier` via `ProviderScope.override` and implement gesture simulation.
4. **`_trayCardKey`** is recreated as a `GlobalKey()` field — if Plan 03-04 replaces `_currentIsoCode` dynamically, a new `_trayCardKey` should be generated per flag to allow `AnimatedSwitcher` to detect child changes correctly (use `ValueKey(_currentIsoCode)` on the FlagTray instead).
5. The `_countries` list is populated lazily on first `_buildMap` call. If the provider refreshes, it will not update because the `isEmpty` guard prevents re-population. Plan 03-04 should consider resetting `_countryIndex` and `_countries` on provider invalidation if needed.
