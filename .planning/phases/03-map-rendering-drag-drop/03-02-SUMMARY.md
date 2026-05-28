---
plan: 03-02
phase: 03-map-rendering-drag-drop
status: complete
completed: 2026-05-28
---

# Plan 03-02 Summary: WorldMapPainter + HighlightPainter + MapScreen

## What was built

### Files created
- `lib/features/map/world_map_painter.dart` — Static CustomPainter drawing 196 country fills (6-color atlas palette cycling by index, grey for matched), dark borders (strokeWidth 1.2), and centroid labels (font 10, white with drop shadow). `shouldRepaint` uses O(1) length check.
- `lib/features/map/highlight_painter.dart` — Dynamic CustomPainter drawing gold (#FFD700) fill on the hovered country only. `shouldRepaint` returns `false` when `hoveredIso` is unchanged.
- `lib/features/map/map_screen.dart` — `ConsumerStatefulWidget` with `TransformationController`, viewport-center-anchored zoom buttons, two-layer `RepaintBoundary`-separated `CustomPaint` stack inside a 2000×1000 `SizedBox` inside `InteractiveViewer`, loading/error states wired to `countryDataProvider`, and a 120px grey flag tray stub. Includes `_toSceneFromGlobal` coordinate helper for Plan 03-03.
- `lib/features/map/map_screen.dart` also declares top-level `countryDataProvider = FutureProvider<List<CountryData>>((ref) => CountryDataService().loadMapData())`.

### Files modified
- `test/features/map/world_map_painter_test.dart` — Replaced two RED-state `fail()` stubs with real unit tests for `shouldRepaint` returning false (same length) and true (growing set). Both GREEN.
- `lib/core/l10n/app_en.arb` — Added `zoomInTooltip`, `zoomOutTooltip`, `loadingMap`, `mapLoadError`.
- `lib/core/l10n/app_es.arb` — Spanish translations for all four new keys.
- `lib/app.dart` — `Scaffold` body replaced from placeholder `Text` to `MapScreen()`. Spike FAB kept.

### Generated (by flutter gen-l10n)
- `lib/generated/l10n/app_localizations.dart` — new abstract getters for four keys
- `lib/generated/l10n/app_localizations_en.dart` / `app_localizations_es.dart` — concrete implementations

## Verification results

```
$ flutter test test/features/map/world_map_painter_test.dart test/architecture/ads_isolation_test.dart
00:00 +3: All tests passed!

$ flutter analyze lib/features/map/
No issues found! (ran in 10.4s)

$ flutter build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk

grep features/ads/ lib/features/map/ lib/core/  →  0 matches
```

## Notes

- `AppLocalizations.of(context)` returns a non-nullable type in this project's generated code; removed unnecessary `!` operators flagged by the analyzer.
- Removed `import 'dart:ui'` from `world_map_painter.dart` — all used types (`Color`, `Canvas`, `Size`, `Offset`, `Paint`, `PaintingStyle`, `TextPainter`, `TextSpan`, `TextStyle`, `Shadow`, `TextDirection`) are re-exported by `package:flutter/material.dart`.
- Widget tree follows the spec exactly: `InteractiveViewer(constrained: false, minScale: 0.08, maxScale: 8.0)` wrapping `SizedBox(2000×1000)` wrapping a `Stack` of two `RepaintBoundary`-wrapped `CustomPaint` layers plus a `SizedBox.expand()` DragTarget stub.
- `_countryIndex` is built lazily in `_buildMap` on first non-empty data arrival; map is passed by reference to `HighlightPainter` on each rebuild.
- Plan 03-03 will replace the `SizedBox.expand()` stub with a real `DragTarget` and wire the flag tray.
