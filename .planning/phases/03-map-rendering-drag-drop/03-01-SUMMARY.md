---
plan: 03-01
phase: 03-map-rendering-drag-drop
status: complete
completed: 2026-05-28
---

# Plan 03-01 Summary: Coordinate-Transform Spike + AudioService + Test Stubs

## What was built

- `just_audio ^0.10.5` added to `pubspec.yaml`; `flutter pub get` resolved 16 new dependencies
- Silent placeholder MP3 files at `assets/audio/correct.mp3` and `assets/audio/error.mp3` (431 bytes each, ID3v2 header + MPEG frame)
- `AudioService` abstract interface (`lib/core/audio/audio_service.dart`)
- `StubAudioService` no-op implementation (`lib/core/audio/stub_audio_service.dart`)
- `RealAudioService` with `just_audio`, degrades silently on `PlayerException` (`lib/core/audio/real_audio_service.dart`)
- `audioServiceProvider` Riverpod `Provider<AudioService>` (`lib/core/audio/audio_service_provider.dart`)
- `lib/main.dart` updated with `RealAudioService` override in `ProviderScope`
- `SpikeMapScreen`: `InteractiveViewer` with 5 colored labeled `DragTarget` regions, coordinate-transform helper using `TransformationController.toScene()` (`lib/features/map/spike_map_screen.dart`)
- Debug "Spike" `FloatingActionButton.extended` added to `lib/app.dart` home screen
- 4 RED-state test stub files in `test/features/map/`:
  - `hit_detection_test.dart` (GAME-01, GAME-02)
  - `flag_sequence_test.dart` (GAME-05, GAME-06)
  - `world_map_painter_test.dart` (MAP-01)
  - `drag_drop_widget_test.dart` (MAP-05, GAME-01, GAME-03/04)

## Verification results

```
flutter analyze lib/core/audio/ lib/features/map/spike_map_screen.dart
→ No issues found.

flutter test test/architecture/ads_isolation_test.dart test/unit/country_data_service_test.dart test/unit/country_data_test.dart
→ 8 tests passed.

grep -rn "features/ads/" lib/core/audio/ lib/features/map/spike_map_screen.dart
→ OK — no ads imports
```

## Notes

- `Matrix4.scale()` is deprecated in `vector_math ^2.2.0`; used `scaleByDouble(factor, factor, factor, 1.0)` for uniform scaling.
- `Color.withOpacity()` replaced with `withValues(alpha: ...)` per current Flutter deprecation guidance.
- RED-state test files intentionally fail — they assert `fail(...)` until Wave 2 implementations land.

## Human checkpoint required

`SpikeMapScreen` must be manually verified at 1×, 2×, and 4× zoom before Wave 2 begins.

**Instructions:**
1. Run `flutter run` (connect a device or emulator)
2. Tap the "Spike" floating action button on the home screen
3. On the Coordinate Transform Spike screen, drag the yellow "Drag me" widget onto each of the 5 colored regions (A–E)
4. Check the debug console — each drop should print the correct region name, e.g.:
   `Hit: Region A at scene=Offset(150.0, 175.0) zoom=1.00x`
5. Use the + / − zoom buttons to zoom to ~2× and ~4×, repeat the drag-drop test
6. Confirm the correct region name is always printed regardless of zoom level

**Resume signal:** `spike-passed`
