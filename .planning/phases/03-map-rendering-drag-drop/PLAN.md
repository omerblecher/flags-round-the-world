# Phase 3: Map Rendering & Drag-Drop — Master Plan

**Phase:** 03-map-rendering-drag-drop
**Status:** Ready to execute
**Depends on:** Phase 2 complete

---

## Phase Goal

**As a** player, **I want to** drag flag cards onto an interactive world map and receive instant feedback at any zoom level, **so that** I can learn all 196 countries by matching their flags.

---

## Wave Structure

| Wave | Plans | Blocks On |
|------|-------|-----------|
| 1 | 03-01 | Nothing — mandatory spike + foundation |
| 2 | 03-02 | Wave 1 spike passing (human checkpoint) |
| 3 | 03-03 | Wave 2 map rendering complete |
| 4 | 03-04 | Wave 3 drag-drop wired |
| 5 | 03-05 | Wave 4 complete — integration gate |

---

## Plans

**Wave 1**
- [ ] 03-01-PLAN.md — Coordinate-transform spike + AudioService stub + test stubs (RED state)

**Wave 2** *(blocked on Wave 1 human spike checkpoint)*
- [ ] 03-02-PLAN.md — WorldMapPainter + HighlightPainter + InteractiveViewer screen

**Wave 3** *(blocked on Wave 2 completion)*
- [ ] 03-03-PLAN.md — FlagTray widget + Draggable + DragTarget + hit detection

**Wave 4** *(blocked on Wave 3 completion)*
- [ ] 03-04-PLAN.md — Correct/incorrect feedback animations + audio calls + haptics + flag sequence + completion screen

**Wave 5** *(blocked on Wave 4 completion)*
- [ ] 03-05-PLAN.md — Integration gate: full suite green + 60fps profile + SC4 manual zoom verification

---

## Requirements Addressed

MAP-01, MAP-02, MAP-03, MAP-04, MAP-05, GAME-01, GAME-02, GAME-03, GAME-04, GAME-05, GAME-06

---

## Cross-Cutting Constraints

- **Coordinate transform:** Always global → `renderBox.globalToLocal()` → `_controller.toScene()`. Never skip step 2. Write a helper `_toSceneFromGlobal()` and use it everywhere.
- **Widget tree:** Flag tray OUTSIDE InteractiveViewer. DragTargets INSIDE. This is LOCKED after Phase 3.
- **One DragTarget:** Single full-coverage transparent `DragTarget<String>` over the 2000×1000 canvas. NOT 196 individual targets.
- **Two CustomPaint layers:** WorldMapPainter (static, `isComplex: true`) + HighlightPainter (dynamic, `willChange: true`), each wrapped in its own `RepaintBoundary`.
- **Ads walled garden:** GameSessionNotifier has zero imports from `features/ads/`. AudioService lives in `lib/core/audio/` — not in `features/ads/`. The ads_isolation_test.dart must stay green throughout.
- **No Firebase:** No `firebase_core` in pubspec.yaml. No analytics, no Crashlytics.
- **I18N-01:** All new UI strings (zoom button tooltips, completion screen text) go in `lib/core/l10n/app_en.arb` and `app_es.arb` via `flutter gen-l10n`.
- **196 countries:** Enforce 196 (not 195) — includes Kosovo (XK), Taiwan (TW), Holy See (VA), and the full UN-193 set.

---

## Source Audit

| Source | Item | Covered By |
|--------|------|------------|
| GOAL | Interactive map, drag-drop, hit detection at 1×/2×/4× zoom | 03-01 (spike), 03-03 (hit detection) |
| MAP-01 | 196 droppable regions, ≥30fps | 03-02 (painter), 03-05 (profile gate) |
| MAP-02 | Pinch-to-zoom + two-finger pan | 03-02 (InteractiveViewer) |
| MAP-03 | On-screen zoom buttons | 03-02 (zoom buttons) |
| MAP-04 | Country name labels scale with zoom | 03-02 (WorldMapPainter labels) |
| MAP-05 | Drag-over visual highlight | 03-02 (HighlightPainter), 03-03 (hover state) |
| GAME-01 | Drag flag card to country | 03-03 (Draggable + DragTarget) |
| GAME-02 | Forgiving snap radius | 03-03 (bbox expansion, 32 scene-unit floor) |
| GAME-03 | Correct drop: animation + audio + haptic | 03-04 |
| GAME-04 | Incorrect drop: error visual + audio + haptic + return | 03-04 |
| GAME-05 | 196 flags random order, no repeats | 03-04 (flag sequence) |
| GAME-06 | Completion screen after last match | 03-04 (completeGame() trigger) |
| D-01 | Flat atlas color palette | 03-02 (WorldMapPainter) |
| D-02 | Light-blue ocean background (#A8D5E8) | 03-02 |
| D-03 | 1–1.5px borders, scales with transform | 03-02 |
| D-04 | Gold (#FFD700) drag-over highlight | 03-03 (HighlightPainter hover state) |
| D-05 | Centroid labels, 12–14sp, white+shadow | 03-02 (WorldMapPainter) |
| D-06 | Horizontal bottom tray strip | 03-03 (FlagTray) |
| D-07 | One active flag card at a time | 03-03/04 (AnimatedSwitcher) |
| D-08 | 3:2 card, rounded corners, drop shadow | 03-03 (FlagCard) |
| D-09 | Country name always visible in Phase 3 | 03-03 (FlagCard) |
| D-10 | Correct drop: scale+fade to centroid, pinned dot | 03-04 |
| D-11 | Incorrect drop: Curves.elasticOut bounce | 03-04 |
| D-12 | AudioService abstract interface + StubAudioService | 03-01 |
| D-13 | HapticFeedback.lightImpact / mediumImpact | 03-04 |
| D-14 | Path.contains(scenePoint) primary hit check | 03-03 (hit_detection.dart) |
| D-15 | Bbox expansion with 32 scene-unit floor | 03-03 (hit_detection.dart) |
| D-16 | Smallest-bbox tiebreaker for multi-match | 03-03 (hit_detection.dart) |
| D-17 | Coordinate-transform spike is Plan 1 | 03-01 |
| RESEARCH | Three-step global→local→scene transform | 03-01 (spike), 03-03 (helper) |
| RESEARCH | Single DragTarget architecture | 03-03 |
| RESEARCH | RepaintBoundary / isComplex / willChange | 03-02 |
| RESEARCH | RealAudioService with just_audio 0.10.5 | 03-01 |
| RESEARCH | Scene→screen centroid conversion (Matrix4) | 03-04 |
| RESEARCH | AnimatedSwitcher for next-card slide-in | 03-04 |

---

---
phase: 03-map-rendering-drag-drop
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - pubspec.yaml
  - assets/audio/correct.mp3
  - assets/audio/error.mp3
  - lib/core/audio/audio_service.dart
  - lib/core/audio/stub_audio_service.dart
  - lib/core/audio/real_audio_service.dart
  - lib/core/audio/audio_service_provider.dart
  - lib/features/map/spike_map_screen.dart
  - lib/main.dart
  - test/features/map/hit_detection_test.dart
  - test/features/map/flag_sequence_test.dart
  - test/features/map/world_map_painter_test.dart
  - test/features/map/drag_drop_widget_test.dart
autonomous: false
requirements:
  - GAME-03
  - GAME-04
  - GAME-01

must_haves:
  truths:
    - "flutter pub get exits 0 with just_audio in pubspec.yaml"
    - "AudioService abstract interface and StubAudioService compile with zero imports from features/ads/"
    - "RealAudioService.init() loads silent placeholder MP3s without throwing"
    - "SpikeMapScreen is reachable from main (dev route) and logs correct ISO at 1×/2×/4× zoom"
    - "All four test stub files exist with failing RED-state sentinels"
    - "ads_isolation_test.dart still exits 0"
  artifacts:
    - path: "lib/core/audio/audio_service.dart"
      provides: "AudioService abstract interface"
      contains: "abstract interface class AudioService"
    - path: "lib/core/audio/stub_audio_service.dart"
      provides: "StubAudioService no-op implementation"
      contains: "class StubAudioService implements AudioService"
    - path: "lib/core/audio/real_audio_service.dart"
      provides: "RealAudioService with just_audio"
      contains: "class RealAudioService implements AudioService"
    - path: "lib/features/map/spike_map_screen.dart"
      provides: "Standalone coordinate-transform test widget"
      contains: "class SpikeMapScreen"
    - path: "test/features/map/hit_detection_test.dart"
      provides: "RED-state test stubs for hit detection"
      contains: "test('GAME-01:"
    - path: "test/features/map/flag_sequence_test.dart"
      provides: "RED-state test stubs for flag sequence"
      contains: "test('GAME-05:"
  key_links:
    - from: "lib/core/audio/real_audio_service.dart"
      to: "assets/audio/correct.mp3"
      via: "setAsset('assets/audio/correct.mp3')"
      pattern: "assets/audio/correct"
    - from: "lib/core/audio/audio_service_provider.dart"
      to: "lib/core/audio/real_audio_service.dart"
      via: "Riverpod Provider override"
      pattern: "RealAudioService"

---

## Plan 03-01: Coordinate-Transform Spike + AudioService Stub + Test Stubs

<objective>
Establish the mandatory foundation before any WorldMapPainter work begins.

Purpose: D-17 requires the coordinate-transform spike to be the first deliverable — it proves that `TransformationController.toScene()` hit detection is correct at 1×, 2×, and 4× zoom before the real map is built on top of that mechanism. Simultaneously, this plan adds just_audio, creates the AudioService abstraction, and writes RED-state test stubs so Wave 2+ plans have a test harness.

Output:
- just_audio ^0.10.5 in pubspec.yaml; silent placeholder MP3s at assets/audio/
- AudioService abstract interface + StubAudioService + RealAudioService in lib/core/audio/
- audioServiceProvider (Riverpod Provider) with RealAudioService override in main.dart
- SpikeMapScreen: standalone screen with 5 labeled DragTarget regions, logs drop hits to console
- 4 test stub files in test/features/map/ with RED-state fail() sentinels
- Human checkpoint: manually verify SpikeMapScreen at 1×, 2×, 4× zoom before proceeding
</objective>

<execution_context>
@C:/Users/omerb/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/omerb/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/03-map-rendering-drag-drop/03-CONTEXT.md
@.planning/phases/03-map-rendering-drag-drop/RESEARCH.md

<interfaces>
<!-- Key types and patterns the executor needs. -->

From lib/features/ads/ad_service.dart — abstract interface + stub pattern to mirror:
```dart
abstract interface class AdService {
  Future<AdLoadState> loadBannerAd();
}
class StubAdService implements AdService {
  const StubAdService();
  @override Future<AdLoadState> loadBannerAd() async => const AdFailed();
}
```

From lib/core/models/country_data.dart — CountryData fields available at runtime:
```dart
class CountryData {
  final String isoCode;
  final List<Path> paths;         // dart:ui Path objects, ready to paint/contains()
  final BoundingBox boundingBox;  // .rect returns Rect
  final Offset centroid;
}
```

From lib/features/game/game_session_notifier.dart — existing provider declaration style:
```dart
final gameSessionProvider =
    AsyncNotifierProvider<GameSessionNotifier, GameSession>(
  () => GameSessionNotifier(ticker: RealTicker()),
);
```

From lib/main.dart — current ProviderScope (no overrides yet):
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: App()));
}
```

From lib/app.dart — has TODO comment "wire GoRouter in Phase 3"; currently a plain MaterialApp.

From test/architecture/ads_isolation_test.dart — checks lib/features/game/, lib/features/map/, lib/core/
for ANY import containing 'features/ads/'. AudioService must live in lib/core/audio/ — NOT features/ads/.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add just_audio to pubspec, create silent MP3 placeholders, create AudioService abstraction</name>
  <files>
    pubspec.yaml
    assets/audio/correct.mp3
    assets/audio/error.mp3
    lib/core/audio/audio_service.dart
    lib/core/audio/stub_audio_service.dart
    lib/core/audio/real_audio_service.dart
    lib/core/audio/audio_service_provider.dart
    lib/main.dart
  </files>
  <action>
    Add `just_audio: ^0.10.5` under `dependencies:` in pubspec.yaml (verify the exact current version with `flutter pub add just_audio --dry-run` first; use whatever stable version resolves). Run `flutter pub get`.

    Create silent placeholder MP3 files at `assets/audio/correct.mp3` and `assets/audio/error.mp3`. These must be valid MP3 binary files (not empty) so that `just_audio`'s `setAsset()` does not throw a PlayerException. Generate minimal valid silent MP3 bytes: the simplest approach is a 0.5-second 8kHz mono MP3 (44 bytes of silence). If generating real MP3 binary is not feasible in this context, create a file containing a known-good silent MP3 header. At minimum, the file must be non-empty so the asset bundler includes it — the catch block in RealAudioService.init() provides secondary protection.

    Create `lib/core/audio/audio_service.dart` — abstract interface following the AdService pattern:
    - `abstract interface class AudioService`
    - Methods: `Future<void> init()`, `Future<void> playCorrect()`, `Future<void> playError()`, `Future<void> dispose()`
    - No imports from `features/ads/` (enforced by ads_isolation_test.dart)

    Create `lib/core/audio/stub_audio_service.dart`:
    - `class StubAudioService implements AudioService` with `const StubAudioService()`
    - All four methods are `async {}` no-ops

    Create `lib/core/audio/real_audio_service.dart`:
    - `class RealAudioService implements AudioService` using `just_audio`
    - `init()` creates two `AudioPlayer` instances (`_correctPlayer`, `_errorPlayer`), calls `setAsset()` for each, wraps in try/catch on `PlayerException` — logs with `debugPrint`, sets `_initialized = false` on failure, degrades silently
    - `playCorrect()` and `playError()` each call `seek(Duration.zero)` then `play()` on the respective player; wrapped in try/catch; no-ops if `_initialized == false`
    - `dispose()` disposes both players
    - Import `package:just_audio/just_audio.dart` and `package:flutter/foundation.dart` for `debugPrint`

    Create `lib/core/audio/audio_service_provider.dart`:
    - Top-level `final audioServiceProvider = Provider<AudioService>((_) => const StubAudioService())`
    - This default provides the stub; main.dart overrides it with RealAudioService

    Update `lib/main.dart`:
    - Add `ProviderScope` override: `audioServiceProvider.overrideWith((_) { final svc = RealAudioService(); svc.init(); return svc; })`
    - Keep existing `ProviderScope(child: App())` structure — just add the `overrides:` list
    - Import `lib/core/audio/audio_service_provider.dart` and `lib/core/audio/real_audio_service.dart`
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter pub get && flutter analyze lib/core/audio/ && flutter test test/architecture/ads_isolation_test.dart</automated>
  </verify>
  <done>
    - pubspec.yaml contains `just_audio:` under dependencies
    - flutter pub get exits 0
    - assets/audio/correct.mp3 and assets/audio/error.mp3 are non-empty files
    - lib/core/audio/ contains 4 files: audio_service.dart, stub_audio_service.dart, real_audio_service.dart, audio_service_provider.dart
    - flutter analyze lib/core/audio/ exits with zero errors
    - ads_isolation_test.dart exits 0 (no features/ads/ imports in core/)
    - lib/main.dart ProviderScope has overrides list including audioServiceProvider
  </done>
</task>

<task type="auto">
  <name>Task 2: Create coordinate-transform spike widget and RED-state test stubs</name>
  <files>
    lib/features/map/spike_map_screen.dart
    test/features/map/hit_detection_test.dart
    test/features/map/flag_sequence_test.dart
    test/features/map/world_map_painter_test.dart
    test/features/map/drag_drop_widget_test.dart
  </files>
  <action>
    Create `lib/features/map/spike_map_screen.dart` — a standalone widget (does not depend on CountryData):
    - `class SpikeMapScreen extends StatefulWidget`
    - State holds `TransformationController _controller` and `GlobalKey _ivKey`
    - Widget tree: `InteractiveViewer` with `constrained: false`, `minScale: 0.1`, `maxScale: 10.0`, containing `SizedBox(width: 2000, height: 1000)` containing a `Stack` with:
      - A background `Container(color: Color(0xFFA8D5E8))`
      - 5 colored `Positioned` containers at known scene coordinates (e.g., at scene rects (100,100,200,150), (400,300,150,120), (800,200,180,160), (1200,400,140,130), (1600,600,160,140)) with visible label text ("Region A" through "Region E")
      - A single `DragTarget<String>` covering the full `SizedBox.expand()` area — in `onAcceptWithDetails`, compute scenePoint via `_toSceneFromGlobal(details.offset)`, hit-test against the 5 known rects, and print `debugPrint('Hit: $regionName at scene=$scenePoint zoom=${_controller.value.getMaxScaleOnAxis().toStringAsFixed(2)}x')` to the console
    - Private helper `Offset _toSceneFromGlobal(Offset globalOffset)`: obtains `RenderBox` from `_ivKey`, calls `box.globalToLocal(globalOffset)`, then `_controller.toScene(result)` — three steps, exactly as documented in RESEARCH.md §Q1
    - Include a small draggable widget in a fixed top-left overlay (outside InteractiveViewer) that can be dragged onto the map — a simple `Draggable<String>(data: 'test', child: ...)` wrapped in `Positioned`
    - Add zoom buttons (+/-) as `Positioned` overlays that call `_zoomIn()` and `_zoomOut()` per RESEARCH.md §Architecture Patterns
    - The SpikeMapScreen is wired into app.dart as a temporary dev route: add a floating debug button on the placeholder home screen that navigates to SpikeMapScreen. This route is removed in Phase 5 cleanup.

    Create `test/features/map/hit_detection_test.dart` — RED-state stubs:
    - Import `package:flutter_test/flutter_test.dart` and `package:flags_around_the_world/features/map/hit_detection.dart` with `// ignore: uri_does_not_exist`
    - Group `'hit detection'` with:
      - `test('GAME-01: exact path hit returns correct isoCode')` → `fail('GAME-01 not implemented — RED state')`
      - `test('GAME-01: miss returns null when scenePoint outside all countries')` → `fail('GAME-01 not implemented — RED state')`
      - `test('GAME-02: bbox expansion hit for LU (Luxembourg bbox diagonal < 32 units)')` → `fail('GAME-02 not implemented — RED state')`
      - `test('GAME-02: smallest-bbox tiebreaker selects more specific country on border')` → `fail('GAME-02 not implemented — RED state')`

    Create `test/features/map/flag_sequence_test.dart` — RED-state stubs:
    - Import `package:flutter_test/flutter_test.dart`
    - Group `'flag sequence'` with:
      - `test('GAME-05: shuffle produces 196 unique ISO codes with no repeats')` → `fail('GAME-05 not implemented — RED state')`
      - `test('GAME-05: sequence does not contain duplicates after advance')` → `fail('GAME-05 not implemented — RED state')`
      - `test('GAME-06: completeGame() is triggered after 196th correct drop')` → `fail('GAME-06 not implemented — RED state')`

    Create `test/features/map/world_map_painter_test.dart` — RED-state stubs:
    - Import `package:flutter_test/flutter_test.dart`
    - Group `'WorldMapPainter'` with:
      - `test('MAP-01: shouldRepaint returns false when matchedIsoCodes length unchanged')` → `fail('MAP-01 not implemented — RED state')`
      - `test('MAP-01: shouldRepaint returns true when matchedIsoCodes grows')` → `fail('MAP-01 not implemented — RED state')`

    Create `test/features/map/drag_drop_widget_test.dart` — RED-state stubs:
    - Import `package:flutter_test/flutter_test.dart` and `package:flutter_riverpod/flutter_riverpod.dart`
    - Group `'DragTarget callbacks'` with:
      - `test('MAP-05: hover state updates to correct isoCode on drag-over')` → `fail('MAP-05 not implemented — RED state')`
      - `test('GAME-01: recordDrop called with isCorrect:true on correct country drop')` → `fail('GAME-01 not implemented — RED state')`
      - `test('GAME-03/04: recordDrop called with isCorrect:false on wrong country drop')` → `fail('GAME-03/04 not implemented — RED state')`
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter analyze lib/features/map/spike_map_screen.dart && flutter test test/architecture/ads_isolation_test.dart test/unit/country_data_service_test.dart test/unit/country_data_test.dart</automated>
  </verify>
  <done>
    - lib/features/map/spike_map_screen.dart compiles without errors
    - SpikeMapScreen is reachable via debug button on home screen
    - All 4 test stub files exist in test/features/map/ with fail() bodies
    - ads_isolation_test.dart and existing unit tests still exit 0
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
    SpikeMapScreen is a live InteractiveViewer containing 5 labeled colored regions at fixed scene coordinates. A draggable widget in the top-left can be dragged onto the map. The console logs "Hit: Region X at scene=Offset(...) zoom=Nx" on every drop.
  </what-built>
  <how-to-verify>
    1. Run `flutter run` (debug mode, physical device or emulator)
    2. From the placeholder home screen, tap the debug "Spike" button to open SpikeMapScreen
    3. At 1× zoom (initial fit): drag the draggable onto each of the 5 colored regions in turn. Confirm the console prints the correct region name each time.
    4. Pinch or use zoom buttons to reach 2× zoom. Repeat — drag onto each region. Confirm correct region names in console.
    5. Zoom to 4×. Repeat drag tests. Confirm correct region names at 4× zoom.
    6. Drag into empty space (not on any region). Confirm console prints null or "Miss".
    7. Confirm hits are NOT offset or misaligned at any zoom level — the logged scenePoint should fall within the expected rect for the targeted region.
  </how-to-verify>
  <resume-signal>Type "spike-passed" to continue to Wave 2, or describe misalignment issues for investigation before proceeding.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| asset bundle read | MP3 and JSON assets loaded from device bundle at runtime — can be missing or malformed |
| just_audio package | New pub.dev dependency introduced in this plan |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-01 | Denial of Service | RealAudioService.init() | mitigate | Wrap setAsset() in try/catch on PlayerException; set _initialized=false; all subsequent play() calls are no-ops. App never crashes due to missing audio. |
| T-03-02 | Tampering | just_audio package | accept | Verified publisher (ryanheise.com), active since 2019, pub.dev legitimacy audit in RESEARCH.md. Low-risk established package. |
| T-03-SC | Tampering | pub.dev package install | accept | just_audio assessed as Approved in RESEARCH.md Package Legitimacy Audit. No slopcheck tooling available; manual assessment sufficient for this well-known package. |
</threat_model>

<verification>
After all tasks and human checkpoint complete:

1. `flutter pub get` — exits 0
2. `flutter analyze lib/core/audio/ lib/features/map/spike_map_screen.dart` — zero errors
3. `flutter test test/architecture/ads_isolation_test.dart` — exits 0
4. `flutter test test/unit/` — all existing tests still green; new map stubs in fail() state (expected)
5. Manual spike verification passed (human checkpoint approved)
6. `grep -rn "features/ads/" lib/core/audio/ lib/features/map/` — zero matches
</verification>

<success_criteria>
- just_audio present in pubspec.yaml and resolves cleanly
- Silent placeholder MP3 files exist at assets/audio/correct.mp3 and assets/audio/error.mp3
- AudioService interface: init(), playCorrect(), playError(), dispose()
- StubAudioService: const constructor, all methods are async no-ops
- RealAudioService: degrades silently on PlayerException — never crashes
- audioServiceProvider provides RealAudioService in main.dart (overrides stub default)
- SpikeMapScreen: logs correct region name on drop at 1×, 2×, and 4× zoom (manually verified)
- 4 test stub files in test/features/map/ with RED-state fail() sentinels
- ads_isolation_test.dart green
</success_criteria>

<output>
Create `.planning/phases/03-map-rendering-drag-drop/03-01-SUMMARY.md` when done
</output>

---

---
phase: 03-map-rendering-drag-drop
plan: 02
type: execute
wave: 2
depends_on:
  - 03-01
files_modified:
  - lib/features/map/world_map_painter.dart
  - lib/features/map/highlight_painter.dart
  - lib/features/map/map_screen.dart
  - lib/core/l10n/app_en.arb
  - lib/core/l10n/app_es.arb
  - test/features/map/world_map_painter_test.dart
autonomous: true
requirements:
  - MAP-01
  - MAP-02
  - MAP-03
  - MAP-04
  - MAP-05

must_haves:
  truths:
    - "App opens to MapScreen showing the full world map with 196 colored country regions"
    - "Pinch-to-zoom, two-finger pan, and zoom buttons all operate smoothly"
    - "Dragging over any country changes its fill to gold (#FFD700)"
    - "Country name labels render at centroids and scale with zoom"
    - "WorldMapPainter.shouldRepaint returns false when matchedIsoCodes is unchanged"
    - "flutter test test/features/map/world_map_painter_test.dart exits 0"
  artifacts:
    - path: "lib/features/map/world_map_painter.dart"
      provides: "Static CustomPainter for 196 country fills, borders, labels"
      contains: "class WorldMapPainter extends CustomPainter"
    - path: "lib/features/map/highlight_painter.dart"
      provides: "Dynamic CustomPainter for hover highlight"
      contains: "class HighlightPainter extends CustomPainter"
    - path: "lib/features/map/map_screen.dart"
      provides: "Main game screen widget — InteractiveViewer + tray layout"
      contains: "class MapScreen"
  key_links:
    - from: "lib/features/map/map_screen.dart"
      to: "lib/features/map/world_map_painter.dart"
      via: "CustomPaint painter:"
      pattern: "WorldMapPainter"
    - from: "lib/features/map/map_screen.dart"
      to: "lib/core/data/country_data_service.dart"
      via: "Riverpod provider watch"
      pattern: "countryDataProvider"

---

## Plan 03-02: WorldMapPainter + HighlightPainter + InteractiveViewer Screen

<objective>
Build the static and dynamic map rendering layers and wire them into the main game screen.

Purpose: Phase 3 SC1 and SC2 require all 196 countries rendered as distinct areas with pinch-to-zoom and zoom buttons. The two-layer CustomPainter architecture (static WorldMapPainter + dynamic HighlightPainter in separate RepaintBoundary containers) is required to hit 30fps on mid-range Android — a single painter repainting 196 paths on every drag hover would drop below target frame rate (RESEARCH.md Pitfall 5).

Output:
- WorldMapPainter: draws atlas-palette fills, thin borders, centroid labels for 196 countries
- HighlightPainter: draws gold fill for the currently hovered country only
- MapScreen: Column with Expanded(InteractiveViewer) + zoom button overlay + placeholder FlagTray row (stubbed — real tray in Plan 03-03)
- countryDataProvider Riverpod provider wiring CountryDataService output
- WorldMapPainter shouldRepaint tests GREEN
</objective>

<execution_context>
@C:/Users/omerb/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/omerb/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/03-map-rendering-drag-drop/03-CONTEXT.md
@.planning/phases/03-map-rendering-drag-drop/RESEARCH.md
@.planning/phases/03-map-rendering-drag-drop/03-01-SUMMARY.md

<interfaces>
From lib/core/models/country_data.dart:
```dart
class CountryData {
  final String isoCode;
  final List<Path> paths;         // dart:ui Path — call canvas.drawPath() directly
  final BoundingBox boundingBox;  // .rect returns Rect
  final Offset centroid;          // use for label placement
}
```

From lib/core/data/country_data_service.dart:
```dart
class CountryDataService {
  Future<List<CountryData>> loadMapData() async { ... }
}
// Must be exposed as a Riverpod provider — add countryDataProvider in this plan
// Follow manual AsyncNotifierProvider style; no @riverpod codegen
```

Widget tree for MapScreen (from RESEARCH.md §Q2):
```
Column
├── Expanded
│   └── Stack
│       ├── InteractiveViewer(transformationController: _controller, constrained: false)
│       │   └── SizedBox(width: 2000, height: 1000)
│       │       └── Stack
│       │           ├── RepaintBoundary → CustomPaint(isComplex:true, painter: WorldMapPainter)
│       │           ├── RepaintBoundary → CustomPaint(willChange:true, painter: HighlightPainter)
│       │           └── DragTarget<String>(...)   ← wired in Plan 03-03; leave as SizedBox.expand() stub
│       └── Positioned zoom buttons (outside IV)
└── Container(height: 120) placeholder for FlagTray (wired in Plan 03-03)
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: WorldMapPainter — atlas fills, borders, centroid labels</name>
  <files>
    lib/features/map/world_map_painter.dart
    test/features/map/world_map_painter_test.dart
  </files>
  <behavior>
    - `shouldRepaint(WorldMapPainter old)` returns `false` when `old.matchedIsoCodes.length == matchedIsoCodes.length`, `true` when lengths differ
    - `shouldRepaint` test does NOT require a real canvas — test by instantiating two painters with different matchedIsoCodes sets and calling shouldRepaint directly
    - Atlas palette: 6 colors, continent-grouped. Exact mapping: Europe → soft green (#8DB87F), Asia → tan (#D4B483), Africa → orange (#E8A055), Americas → pink (#E89090), Oceania → purple (#A07EC8), Antarctica/other → light yellow (#E8D870). Neighboring countries within a continent get different colors by cycling the palette per the country's index within that continent's list. The palette ensures adjacent countries are visually distinct.
    - Matched countries (isoCode in matchedIsoCodes) render with a muted grey fill (#AAAAAA) to show they are already placed
    - Border stroke: dark (#555555), strokeWidth 1.2 (constant — does not need to scale with zoom; InteractiveViewer zoom makes borders appear proportionally thinner at low zoom, which is acceptable)
    - Labels: use `TextPainter` with `TextSpan`; font size 10sp; white text (#FFFFFF); `shadows: [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1,1))]`; painted at `country.centroid`; call `canvas.save()` / `canvas.restore()` per label to avoid state leak
    - `paint()` draws background rect first (`Color(0xFFA8D5E8)` fills the full size), then country fills, then borders, then labels — in that order
  </behavior>
  <action>
    Create `lib/features/map/world_map_painter.dart`:
    - Constructor: `WorldMapPainter({required List<CountryData> countries, required Set<String> matchedIsoCodes})`
    - Implement `paint(Canvas canvas, Size size)` following the draw order in the behavior block
    - Implement `shouldRepaint` as specified — O(1) length check only
    - Import `dart:ui` for Canvas, Size, Paint, Color; import `package:flutter/material.dart` for TextPainter, TextSpan, TextStyle, Shadow
    - Import `lib/core/models/country_data.dart`
    - Do NOT import anything from `features/ads/`

    Update `test/features/map/world_map_painter_test.dart`: replace RED-state stubs with real tests. The painter tests do not need a WidgetTester — instantiate WorldMapPainter with mock CountryData (create minimal CountryData instances with empty paths and a stub boundingBox) and call `shouldRepaint` directly. Use `expect(p2.shouldRepaint(p1), isFalse)` / `isTrue`.

    Note: WorldMapPainter tests cannot paint to a real canvas in a unit test without a widget tree — test only `shouldRepaint` behavior. Canvas-level rendering is covered by the 30fps profile test in Plan 03-05.
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter test test/features/map/world_map_painter_test.dart && flutter analyze lib/features/map/world_map_painter.dart</automated>
  </verify>
  <done>
    - world_map_painter_test.dart exits 0 (shouldRepaint tests green)
    - flutter analyze reports zero errors
    - WorldMapPainter.shouldRepaint(old): returns false for same-length matchedIsoCodes, true for different length
  </done>
</task>

<task type="auto">
  <name>Task 2: HighlightPainter + MapScreen + countryDataProvider + zoom buttons + ARB strings</name>
  <files>
    lib/features/map/highlight_painter.dart
    lib/features/map/map_screen.dart
    lib/core/l10n/app_en.arb
    lib/core/l10n/app_es.arb
  </files>
  <action>
    Create `lib/features/map/highlight_painter.dart`:
    - Constructor: `HighlightPainter({required String? hoveredIso, required Map<String, CountryData> countryIndex})`
    - `paint()`: if `hoveredIso == null`, return immediately (no-op). Look up `countryIndex[hoveredIso]`, draw each of its `paths` with fill `Color(0xFFFFD700)` (gold). No borders on the highlight layer.
    - `shouldRepaint(HighlightPainter old)`: return `old.hoveredIso != hoveredIso`
    - `isComplex: false`, `willChange: true` (set at the CustomPaint level in MapScreen)

    Create `lib/features/map/map_screen.dart` — `ConsumerStatefulWidget`:
    - State holds: `TransformationController _controller`, `GlobalKey _ivKey`, `String? _hoveredIso`, `Map<String, CountryData> _countryIndex` (built once from loaded countries list)
    - Expose a `countryDataProvider` at the top of the file: `final countryDataProvider = FutureProvider<List<CountryData>>((ref) => CountryDataService().loadMapData())`
    - In `build()`: `ref.watch(countryDataProvider)` — show loading indicator while loading, error widget on failure, full map when data is available
    - Widget tree follows the architecture in the plan context — Column with Expanded(Stack(InteractiveViewer, zoom buttons)) + placeholder 120dp tray area at bottom
    - InteractiveViewer: `constrained: false`, `minScale: 0.08`, `maxScale: 8.0`, `transformationController: _controller`, key assigned to `_ivKey`
    - Child of InteractiveViewer: `SizedBox(width: 2000, height: 1000)` containing a Stack with RepaintBoundary(WorldMapPainter), RepaintBoundary(HighlightPainter), and a `SizedBox.expand()` placeholder for the DragTarget (Plan 03-03 wires this)
    - Zoom buttons: `+` calls `_zoomIn()`, `-` calls `_zoomOut()`. Clamp scale to `[minScale, maxScale]` before applying. See RESEARCH.md §Architecture Patterns for the `Matrix4` manipulation pattern. Position buttons as `Positioned(bottom: 16, right: 16)` in the Stack outside InteractiveViewer.
    - Wire MapScreen as the app home in `lib/app.dart` — replace the placeholder `Scaffold(body: Center(child: Text(...)))` with `MapScreen()`

    Update ARB files for new UI strings (I18N-01 compliance):
    - Add to `app_en.arb`: `"zoomInTooltip": "Zoom in"`, `"zoomOutTooltip": "Zoom out"`, `"loadingMap": "Loading map..."`, `"mapLoadError": "Failed to load map."`
    - Mirror the same keys in `app_es.arb`: `"zoomInTooltip": "Acercar"`, `"zoomOutTooltip": "Alejar"`, `"loadingMap": "Cargando mapa..."`, `"mapLoadError": "Error al cargar el mapa."`
    - Run `flutter gen-l10n` after updating ARB files to regenerate `lib/generated/l10n/app_localizations.dart`
    - Use `AppLocalizations.of(context).zoomInTooltip` etc. in MapScreen

    Do NOT add any imports from `features/ads/` in any of these files.
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter gen-l10n && flutter analyze lib/features/map/ && flutter test test/architecture/ads_isolation_test.dart && flutter build apk --debug</automated>
  </verify>
  <done>
    - flutter build apk --debug exits 0 (app builds)
    - ads_isolation_test.dart exits 0
    - MapScreen renders world map when app opens (196 country regions visible)
    - Zoom buttons appear and respond to taps
    - HighlightPainter file compiles with shouldRepaint returning false when hoveredIso unchanged
    - New ARB keys present in both app_en.arb and app_es.arb
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| asset bundle read | world_map_paths.json loaded via rootBundle — can be missing or malformed |
| CountryData.paths | Pre-parsed dart:ui Path objects — no runtime SVG; safe to paint |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-02-01 | Denial of Service | countryDataProvider FutureProvider | mitigate | Show error widget on AsyncError state in MapScreen — app does not crash if JSON is missing or malformed |
| T-03-02-02 | Denial of Service | WorldMapPainter paint() | accept | All dart:ui Path operations are bounded; paths are pre-parsed at load time, not at paint time. No unbounded loops over external input at render time. |
| T-03-02-SC | Tampering | npm/pip/cargo installs | accept | No new packages in Plan 03-02; just_audio already assessed in Plan 03-01. |
</threat_model>

<verification>
After all tasks complete:

1. `flutter test test/features/map/world_map_painter_test.dart` — exits 0
2. `flutter test test/architecture/ads_isolation_test.dart` — exits 0
3. `flutter analyze lib/features/map/` — zero errors
4. `flutter build apk --debug` — exits 0
5. `grep -rn "features/ads/" lib/features/map/ lib/core/` — zero matches
6. App opens to MapScreen showing colored world map with zoom buttons
</verification>

<success_criteria>
- 196 country regions rendered with atlas palette fills and thin (#555555) borders
- Ocean background is light blue (#A8D5E8)
- Country name labels render at centroids with white text + shadow
- Matched countries show grey fill
- HighlightPainter: only repaints when hoveredIso changes; gold fill on hovered country
- Zoom buttons: + and - manipulate TransformationController, clamped to min/maxScale
- countryDataProvider: FutureProvider, loading/error/data states handled in MapScreen
- ARB strings externalized; flutter gen-l10n succeeds
- app.dart home is MapScreen (placeholder removed)
</success_criteria>

<output>
Create `.planning/phases/03-map-rendering-drag-drop/03-02-SUMMARY.md` when done
</output>

---

---
phase: 03-map-rendering-drag-drop
plan: 03
type: execute
wave: 3
depends_on:
  - 03-02
files_modified:
  - lib/features/map/hit_detection.dart
  - lib/features/game/flag_tray.dart
  - lib/features/map/map_screen.dart
  - test/features/map/hit_detection_test.dart
  - test/features/map/drag_drop_widget_test.dart
autonomous: true
requirements:
  - MAP-01
  - MAP-05
  - GAME-01
  - GAME-02

must_haves:
  truths:
    - "Dragging a flag card from the tray over the map highlights the correct country"
    - "Dropping on a country runs hit detection and returns the correct ISO code"
    - "hit_detection.dart is pure Dart — no Flutter widget dependencies"
    - "flutter test test/features/map/hit_detection_test.dart exits 0 (all tests green)"
    - "bbox expansion floor of 32 scene units prevents microstate misses"
  artifacts:
    - path: "lib/features/map/hit_detection.dart"
      provides: "Pure Dart hitTest() function returning matched ISO or null"
      contains: "String? hitTest("
    - path: "lib/features/game/flag_tray.dart"
      provides: "FlagTray widget with Draggable<String> and AnimatedSwitcher"
      contains: "class FlagTray"
  key_links:
    - from: "lib/features/map/map_screen.dart"
      to: "lib/features/map/hit_detection.dart"
      via: "DragTarget.onAcceptWithDetails calls hitTest()"
      pattern: "hitTest("
    - from: "lib/features/map/map_screen.dart"
      to: "lib/features/game/flag_tray.dart"
      via: "Column child"
      pattern: "FlagTray("

---

## Plan 03-03: FlagTray + Draggable + DragTarget + Hit Detection

<objective>
Wire the complete drag-drop mechanics: flag card draggable in the tray, single DragTarget on the map, hit detection logic as pure Dart, and hover highlight state.

Purpose: GAME-01 and GAME-02 require a working drag system with forgiving hit detection at all zoom levels. The architectural requirement (tray OUTSIDE InteractiveViewer, DragTarget INSIDE, three-step coordinate transform) was validated in the spike — this plan builds the production implementation on that validated foundation.

Output:
- hit_detection.dart: pure Dart `hitTest(scenePoint, countries)` function with Path.contains primary check + 32-unit-floor bbox expansion fallback + smallest-bbox tiebreaker
- FlagTray widget: Draggable<String> wrapping FlagCard, AnimatedSwitcher for next-card slide-in
- MapScreen updated: DragTarget stub replaced with real DragTarget wired to hitTest + hover state
- hit_detection_test.dart and drag_drop_widget_test.dart GREEN
</objective>

<execution_context>
@C:/Users/omerb/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/omerb/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/03-map-rendering-drag-drop/03-CONTEXT.md
@.planning/phases/03-map-rendering-drag-drop/RESEARCH.md
@.planning/phases/03-map-rendering-drag-drop/03-02-SUMMARY.md

<interfaces>
From lib/core/models/country_data.dart:
```dart
class CountryData {
  final String isoCode;
  final List<Path> paths;        // dart:ui Path — use p.contains(scenePoint)
  final BoundingBox boundingBox; // .rect returns Rect
  final Offset centroid;
}
```

From lib/features/game/game_session_notifier.dart:
```dart
// Call from DragTarget.onAcceptWithDetails:
ref.read(gameSessionProvider.notifier).recordDrop(isoCode, isCorrect: bool);
```

Three-step coordinate transform helper (from RESEARCH.md §Q1 — validated in spike):
```dart
Offset _toSceneFromGlobal(Offset globalOffset) {
  final RenderBox box = _ivKey.currentContext!.findRenderObject() as RenderBox;
  return _controller.toScene(box.globalToLocal(globalOffset));
}
```

Hit detection logic summary (from RESEARCH.md §Q4):
- Primary: `country.paths.any((p) => p.contains(scenePoint))`
- Fallback if primary misses: check `_expandedBbox(country).contains(scenePoint)` where expanded bbox has minimum diagonal of 32.0 scene units (centered on country.centroid)
- Tiebreaker: if multiple candidates, return the one with smallest `boundingBox.rect` area
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Pure Dart hit detection — hitTest() function + tests GREEN</name>
  <files>
    lib/features/map/hit_detection.dart
    test/features/map/hit_detection_test.dart
  </files>
  <behavior>
    - `hitTest(Offset scenePoint, List<CountryData> countries)` returns `String?` (ISO code of hit country, or null)
    - Primary check: `country.paths.any((p) => p.contains(scenePoint))` for each country
    - Fallback: if primary misses, use `_expandedBbox(country).contains(scenePoint)` — `_expandedBbox` expands bbox to minimum 32.0 scene-unit diagonal, centered on `country.centroid` (see RESEARCH.md §Q4 for exact implementation)
    - Tiebreaker: if multiple candidates hit, return the one with smallest `boundingBox.rect.width * boundingBox.rect.height` area
    - Unit test 'GAME-01: exact path hit': create a Path with a known rect, create a CountryData around it, call hitTest with a point inside the rect — expect the correct isoCode
    - Unit test 'GAME-01: miss returns null': call hitTest with a point far outside all paths and bboxes — expect null
    - Unit test 'GAME-02: bbox expansion hit for LU': create a CountryData with a tiny Path (bbox diagonal ~5 scene units, simulating Luxembourg). Drop point is outside the path but within the expanded 32-unit bbox. Expect the isoCode is returned.
    - Unit test 'GAME-02: smallest-bbox tiebreaker': two countries whose bboxes both contain the test point. The one with the smaller bbox area should win.
  </behavior>
  <action>
    Create `lib/features/map/hit_detection.dart`:
    - Top-level function `String? hitTest(Offset scenePoint, List<CountryData> countries)` implementing the three-step logic (primary, fallback, tiebreaker) exactly as in the behavior block and RESEARCH.md §Q4
    - Private function `Rect _expandedBbox(CountryData country)` with the 32.0-unit minimum diagonal floor: compute current diagonal, if already >= 32.0 return original rect, otherwise scale width and height proportionally to reach 32.0 diagonal, return `Rect.fromCenter(center: country.centroid, width: ..., height: ...)`
    - Import `dart:ui` for Offset, Rect, Path; import `lib/core/models/country_data.dart`
    - NO Flutter widget imports — this file must be testable with `dart:ui` only, not requiring a widget tree
    - The constant `_kMinBboxDiagonal = 32.0` should be a top-level const in the file

    Update `test/features/map/hit_detection_test.dart`: replace all four RED-state stubs with real tests. For test CountryData construction, create `Path()` instances with `addRect(Rect.fromLTWH(...))` to define known hit areas. For the Luxembourg simulation (GAME-02 bbox test), create a Path with a `Rect.fromLTWH(100, 100, 3, 3)` (diagonal ≈ 4.2 scene units, well below 32), then test a point at (110, 110) — inside the expanded bbox but outside the tiny path rect.
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter test test/features/map/hit_detection_test.dart && flutter analyze lib/features/map/hit_detection.dart</automated>
  </verify>
  <done>
    - flutter test test/features/map/hit_detection_test.dart exits 0 (all 4 tests green)
    - flutter analyze exits with zero errors
    - hitTest() is a pure top-level function with no widget dependencies
  </done>
</task>

<task type="auto">
  <name>Task 2: FlagTray widget + FlagCard + DragTarget wired into MapScreen</name>
  <files>
    lib/features/game/flag_tray.dart
    lib/features/map/map_screen.dart
    test/features/map/drag_drop_widget_test.dart
  </files>
  <action>
    Create `lib/features/game/flag_tray.dart`:
    - `class FlagTray extends StatefulWidget` — constructor: `FlagTray({required String currentIsoCode, required String countryName, required GlobalKey cardKey})`
    - Stateful for the bounce-back animation: state holds `AnimationController _bounceController` (vsync from SingleTickerProviderStateMixin), `Animation<Offset> _bounceOffsetAnim`
    - `_bounceController` uses duration 500ms; `_bounceOffsetAnim` is `Tween<Offset>(begin: Offset.zero, end: Offset(20, -10))` with `Curves.elasticOut`
    - Public method `void triggerBounce()` — calls `_bounceController.forward().then((_) => _bounceController.reverse())` (bounce right and back)
    - Layout: `Container(height: 120, color: Colors.grey.shade200)` containing `Center(child: AnimatedBuilder(animation: _bounceOffsetAnim, builder: (ctx, child) => Transform.translate(offset: _bounceOffsetAnim.value, child: child), child: _buildFlagCard()))`. The bounce animation offsets the card and returns it.
    - `_buildFlagCard()` returns a `GestureDetector`-free container (drag is handled by Draggable): `Draggable<String>(data: currentIsoCode, child: _card(), feedback: _card(), childWhenDragging: Opacity(opacity: 0.3, child: _card()))` — the feedback widget is the flag card rendered at drag-image size
    - `_card()`: `Container` with `width: 90, height: 60` (3:2 aspect ratio), `decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(blurRadius: 4, offset: Offset(2,2))], color: Colors.white)` containing a `Column` with `SvgPicture.asset('assets/flags/$currentIsoCode.svg', fit: BoxFit.cover)` in an `Expanded` area and a `Text(countryName)` below it (D-09: always visible in Phase 3). Assign `key: cardKey` to the card Container for GlobalKey-based position lookup in Plan 03-04.
    - Do NOT import anything from `features/ads/`

    Update `lib/features/map/map_screen.dart`:
    - Replace the `SizedBox.expand()` DragTarget stub with a real `DragTarget<String>`:
      - `onWillAcceptWithDetails`: compute `scenePoint = _toSceneFromGlobal(details.offset)`, call `hitTest(scenePoint, _countries)`, setState `_hoveredIso` to the result; always return `true`
      - `onAcceptWithDetails`: compute scenePoint, call hitTest, determine `isCorrect = hitIso == _currentIsoCode`, call `_handleDrop(hitIso, isCorrect)` (stub this method returning void for now — Plan 03-04 fills it in)
      - `onLeave`: setState `_hoveredIso = null`
      - Builder: returns `SizedBox.expand()` (transparent — the painters below handle rendering)
    - Add `_handleDrop(String? hitIso, bool isCorrect)` method — for now, just call `ref.read(gameSessionProvider.notifier).recordDrop(hitIso ?? _currentIsoCode, isCorrect: isCorrect)` and `setState(() => _hoveredIso = null)`. Plan 03-04 replaces this with the full animation + advance logic.
    - Replace the placeholder 120dp Container at the bottom with `FlagTray(currentIsoCode: _currentIsoCode, countryName: _countryName(_currentIsoCode), cardKey: _trayCardKey)`
    - Add `_trayCardKey = GlobalKey()` to state, and `_currentIsoCode` as a state field (initialized with a hardcoded ISO like 'de' for now — Plan 03-04 wires the shuffled sequence)
    - Import hit_detection.dart and flag_tray.dart; ensure no features/ads/ imports

    Update `test/features/map/drag_drop_widget_test.dart`: replace RED-state stubs with real widget tests using `WidgetTester`. Each test pumps a minimal widget tree (ProviderScope wrapping a simplified version of the DragTarget behavior). Test that `recordDrop` is called with the expected arguments by overriding `gameSessionProvider` with a mock notifier. If setting up a full mock notifier is complex in context, implement two of the three tests (hover state and isCorrect=true drop) and leave the third as a `skip('requires mock wiring — see Plan 03-04')` rather than fail().
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter test test/features/map/drag_drop_widget_test.dart test/architecture/ads_isolation_test.dart && flutter analyze lib/features/game/flag_tray.dart lib/features/map/map_screen.dart</automated>
  </verify>
  <done>
    - FlagTray renders a 3:2 flag card with country name text below
    - Draggable<String> wrapping the card with data=currentIsoCode
    - Bounce animation available via triggerBounce() on state
    - DragTarget in MapScreen: onWillAcceptWithDetails sets _hoveredIso, onAcceptWithDetails calls hitTest + recordDrop
    - drag_drop_widget_test.dart exits 0 (at minimum hover + isCorrect tests pass)
    - ads_isolation_test.dart exits 0
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| DragTargetDetails.offset | Global coordinate from Flutter drag system — must be transformed before use |
| hitTest() scenePoint | Computed from user gesture — could land anywhere in scene coordinate space |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-03-01 | Spoofing | DragTarget coordinate transform | mitigate | Always use three-step global→local→scene transform via `_toSceneFromGlobal()` helper. Validated in spike. Skip-step-2 bug is documented as Pitfall 1 in RESEARCH.md — helper function prevents accidental regression. |
| T-03-03-02 | Denial of Service | hitTest() on large country list | accept | 196 iterations with Path.contains() is O(196) per drop event — not per frame. Drop events are user-paced (max ~1/second). No performance risk. |
| T-03-03-SC | Tampering | npm/pip/cargo installs | accept | No new packages in Plan 03-03. |
</threat_model>

<verification>
After all tasks complete:

1. `flutter test test/features/map/hit_detection_test.dart` — exits 0 (4 tests green)
2. `flutter test test/features/map/drag_drop_widget_test.dart` — exits 0
3. `flutter test test/architecture/ads_isolation_test.dart` — exits 0
4. `flutter analyze lib/features/game/flag_tray.dart lib/features/map/` — zero errors
5. `grep -rn "features/ads/" lib/features/game/flag_tray.dart lib/features/map/` — zero matches
6. Visual: drag a card over the map — target country highlights gold; release — console shows correct/incorrect determination
</verification>

<success_criteria>
- hitTest(): path-contains primary, 32-unit-floor bbox fallback, smallest-bbox tiebreaker — all 4 unit tests green
- FlagTray: 3:2 card, Draggable<String> with data=isoCode, triggerBounce() animates with Curves.elasticOut
- DragTarget: single full-coverage target inside InteractiveViewer; hover sets _hoveredIso; drop calls hitTest + recordDrop
- Coordinate transform: always _toSceneFromGlobal() — three steps, no shortcuts
- ads_isolation_test.dart green
</success_criteria>

<output>
Create `.planning/phases/03-map-rendering-drag-drop/03-03-SUMMARY.md` when done
</output>

---

---
phase: 03-map-rendering-drag-drop
plan: 04
type: execute
wave: 4
depends_on:
  - 03-03
files_modified:
  - lib/features/map/map_screen.dart
  - lib/features/game/flag_tray.dart
  - lib/features/map/completion_screen.dart
  - lib/core/l10n/app_en.arb
  - lib/core/l10n/app_es.arb
  - test/features/map/flag_sequence_test.dart
autonomous: true
requirements:
  - GAME-03
  - GAME-04
  - GAME-05
  - GAME-06
  - MAP-01

must_haves:
  truths:
    - "Correct drop triggers scale+fade animation toward country centroid then pins a colored dot"
    - "Incorrect drop triggers Curves.elasticOut bounce on the flag card"
    - "HapticFeedback.lightImpact fires on correct drop, mediumImpact on incorrect"
    - "AudioService.playCorrect() and playError() are called on each respective drop"
    - "Flag sequence: 196 unique ISOs shuffled, no repeats, advances after each correct drop"
    - "After 196th correct drop, completeGame() is called and CompletionScreen is shown"
    - "flutter test test/features/map/flag_sequence_test.dart exits 0"
  artifacts:
    - path: "lib/features/map/completion_screen.dart"
      provides: "Session completion screen widget"
      contains: "class CompletionScreen"
  key_links:
    - from: "lib/features/map/map_screen.dart"
      to: "lib/features/map/completion_screen.dart"
      via: "Navigator.push or conditional render after completeGame()"
      pattern: "CompletionScreen"
    - from: "lib/features/map/map_screen.dart"
      to: "lib/core/audio/audio_service_provider.dart"
      via: "ref.read(audioServiceProvider)"
      pattern: "audioServiceProvider"

---

## Plan 03-04: Correct/Incorrect Feedback + Audio + Haptics + Flag Sequence + Completion Screen

<objective>
Complete the end-to-end game loop: correct drop animates to the centroid and pins a dot, incorrect drop bounces back, audio and haptics fire on each, the 196-flag sequence drives gameplay, and the session ends with a completion screen.

Purpose: SC3 (feedback), SC5 (full session), and GAME-03 through GAME-06 all require this plan. The correct-drop animation uses the scene→screen centroid conversion from RESEARCH.md §Q5, which requires the same RenderBox and TransformationController machinery validated in the spike.

Output:
- MapScreen._handleDrop() fully implemented: animation OverlayEntry, haptics, audio, advance-to-next-flag logic
- FlagTray triggerBounce() called on incorrect drop
- 196-flag shuffle list in MapScreen state; advances on correct drop; stops on completion
- CompletionScreen widget shown after last correct match
- flag_sequence_test.dart GREEN
</objective>

<execution_context>
@C:/Users/omerb/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/omerb/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/03-map-rendering-drag-drop/03-CONTEXT.md
@.planning/phases/03-map-rendering-drag-drop/RESEARCH.md
@.planning/phases/03-map-rendering-drag-drop/03-03-SUMMARY.md

<interfaces>
From lib/features/game/game_session_notifier.dart:
```dart
// Called on each drop:
ref.read(gameSessionProvider.notifier).recordDrop(isoCode, isCorrect: bool);
// Called after 196th correct drop:
await ref.read(gameSessionProvider.notifier).completeGame();
```

Scene-to-screen centroid conversion (RESEARCH.md §Q5):
```dart
Offset _centroidToScreen(Offset sceneCentroid) {
  final Matrix4 matrix = _controller.value;
  final Vector3 sceneVec = Vector3(sceneCentroid.dx, sceneCentroid.dy, 0);
  final Vector3 viewportVec = matrix.transform3(sceneVec);
  final Offset viewportOffset = Offset(viewportVec.x, viewportVec.y);
  final RenderBox box = _ivKey.currentContext!.findRenderObject() as RenderBox;
  return box.localToGlobal(viewportOffset);
}
// Requires import 'package:vector_math/vector_math_64.dart' for Vector3
// vector_math is bundled with Flutter — no separate pubspec entry needed
```

Tray card global position (RESEARCH.md §Q5):
```dart
Offset _trayCardGlobalOffset() {
  final RenderBox box = _trayCardKey.currentContext!.findRenderObject() as RenderBox;
  return box.localToGlobal(Offset.zero);
}
```

AnimatedSwitcher for next-card slide-in (RESEARCH.md §Q7):
```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  transitionBuilder: (child, animation) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
    child: child,
  ),
  child: FlagTray(key: ValueKey(_currentIsoCode), ...),
)
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: 196-flag shuffle sequence + flag_sequence_test.dart GREEN</name>
  <files>
    lib/features/map/map_screen.dart
    test/features/map/flag_sequence_test.dart
  </files>
  <behavior>
    - `_buildFlagSequence(List<CountryData> countries)`: takes the loaded countries list, extracts `List<String>` of ISO codes, shuffles with `Random()`, returns the shuffled list. This is a pure function extractable for testing.
    - Unit test 'GAME-05: shuffle produces 196 unique ISO codes with no repeats': call `_buildFlagSequence` (exposed as a top-level or static method in map_screen.dart, or extracted to a separate helper file for testability) with a mock list of 196 CountryData objects; assert the result has length 196 and no duplicates (`result.toSet().length == 196`)
    - Unit test 'GAME-05: sequence does not contain duplicates after advance': simulate advancing through the list by popping from the front; assert the remaining elements always maintain uniqueness
    - Unit test 'GAME-06: completeGame() triggered at 0 remaining flags': simulate the state where `_remainingIsoCodes` has exactly 1 element and a correct drop occurs; assert that the advance logic detects the empty list and triggers completeGame()
  </behavior>
  <action>
    Extract the flag sequence logic into a top-level function `List<String> buildFlagSequence(List<CountryData> countries)` at the top of `lib/features/map/map_screen.dart` (or a separate `lib/features/map/flag_sequence.dart` if you prefer — in that case update imports accordingly).

    Add to MapScreen state:
    - `List<String> _remainingIsoCodes = []` (initialized in `_initSequence()` called after countries load)
    - `String _currentIsoCode` (set to `_remainingIsoCodes.first` after init)
    - `Set<String> _matchedIsoCodes = {}` (passed to WorldMapPainter to grey out matched countries)
    - `_initSequence(List<CountryData> countries)`: calls `buildFlagSequence(countries)`, sets `_remainingIsoCodes` and `_currentIsoCode`

    `_advanceToNextFlag()`:
    - Removes `_currentIsoCode` from `_remainingIsoCodes`
    - Adds to `_matchedIsoCodes`
    - If `_remainingIsoCodes.isEmpty`: call `ref.read(gameSessionProvider.notifier).completeGame()` then navigate to CompletionScreen
    - Else: `setState(() => _currentIsoCode = _remainingIsoCodes.first)`

    Update `test/features/map/flag_sequence_test.dart`: replace all RED-state stubs with real tests. Import `buildFlagSequence` from map_screen.dart (or flag_sequence.dart). For mock CountryData construction, create minimal objects using `CountryData(isoCode: isoCode, pathStrings: [], paths: [], boundingBox: BoundingBox(x:0,y:0,w:1,h:1), centroid: Offset.zero)`.
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter test test/features/map/flag_sequence_test.dart && flutter analyze lib/features/map/map_screen.dart</automated>
  </verify>
  <done>
    - flutter test test/features/map/flag_sequence_test.dart exits 0 (3 tests green)
    - buildFlagSequence produces 196 unique ISOs
    - MapScreen state has _remainingIsoCodes, _currentIsoCode, _matchedIsoCodes
    - _advanceToNextFlag() calls completeGame() when list empties
  </done>
</task>

<task type="auto">
  <name>Task 2: Correct/incorrect drop animations, haptics, audio, CompletionScreen</name>
  <files>
    lib/features/map/map_screen.dart
    lib/features/game/flag_tray.dart
    lib/features/map/completion_screen.dart
    lib/core/l10n/app_en.arb
    lib/core/l10n/app_es.arb
  </files>
  <action>
    Replace the stub `_handleDrop()` in MapScreen with the full implementation:

    Correct drop path (`isCorrect == true`):
    1. Call `ref.read(gameSessionProvider.notifier).recordDrop(hitIso!, isCorrect: true)`
    2. Call `HapticFeedback.lightImpact()` (from `package:flutter/services.dart`)
    3. Call `ref.read(audioServiceProvider).playCorrect()`
    4. Animate the flag card to centroid: create an `OverlayEntry` positioned at `_trayCardGlobalOffset()`, animating simultaneously to `_centroidToScreen(countryIndex[hitIso]!.centroid)` with scale (1.0 → 0.15) and opacity (1.0 → 0.0). Use `AnimationController(vsync: this, duration: const Duration(milliseconds: 500))` + `Curves.easeInOut`. On `whenComplete`: remove OverlayEntry, dispose AnimationController, call `_advanceToNextFlag()`. Use `_centroidToScreen()` from RESEARCH.md §Q5 (requires `package:vector_math/vector_math_64.dart` — import from `package:flutter/material.dart`'s transitive dep; no pubspec change needed).
    5. Add `hitIso!` to `_matchedIsoCodes` and setState to trigger WorldMapPainter repaint with a grey dot at that centroid (WorldMapPainter draws matched countries in grey — the "pin" is the grey fill change, not a separate widget — per RESEARCH.md open question #2 recommendation)

    Incorrect drop path (`isCorrect == false`):
    1. Call `ref.read(gameSessionProvider.notifier).recordDrop(hitIso ?? _currentIsoCode, isCorrect: false)`
    2. Call `HapticFeedback.mediumImpact()`
    3. Call `ref.read(audioServiceProvider).playError()`
    4. Access `_trayKey.currentState` to call `triggerBounce()` on the FlagTray state — add `GlobalKey<FlagTrayState> _trayKey` to MapScreen state, pass it as the key to FlagTray in the widget tree

    Update `lib/features/game/flag_tray.dart`:
    - Change FlagTray body to use `AnimatedSwitcher` wrapping FlagCard keyed on `currentIsoCode` (ValueKey) — slide-in from right on key change per RESEARCH.md §Q7
    - Keep the bounce AnimationController and triggerBounce() as before — the AnimatedBuilder wraps the entire AnimatedSwitcher so the bounce applies to whichever card is currently shown

    Create `lib/features/map/completion_screen.dart`:
    - `class CompletionScreen extends StatelessWidget` — constructor accepts `GameSession session`
    - Shows: congratulatory message, session score (from `session.score`), elapsed time (`session.elapsed`), a "Play Again" button that navigates back to MapScreen
    - Phase 4 will add star ratings, personal-best celebration — Phase 3 baseline is score + time only
    - Strings must be in ARB files (I18N-01): add `"completionTitle"`, `"completionScore"`, `"completionElapsed"`, `"completionPlayAgain"` to app_en.arb and app_es.arb; run `flutter gen-l10n`

    Navigate to CompletionScreen in `_advanceToNextFlag()` when list empties: use `Navigator.push(context, MaterialPageRoute(builder: (_) => CompletionScreen(session: ref.read(gameSessionProvider).value!)))`. The Phase 3 navigation is simple Navigator push; GoRouter is wired in Phase 5.

    Ensure all new files have zero imports from `features/ads/`.
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter gen-l10n && flutter analyze lib/features/map/ lib/features/game/flag_tray.dart && flutter test test/architecture/ads_isolation_test.dart && flutter build apk --debug</automated>
  </verify>
  <done>
    - flutter build apk --debug exits 0
    - ads_isolation_test.dart exits 0
    - Correct drop: OverlayEntry animation fires, matched country turns grey, next flag card slides in
    - Incorrect drop: FlagTray bounce animation triggers; card returns to original position
    - HapticFeedback called: lightImpact for correct, mediumImpact for incorrect
    - AudioService.playCorrect() / playError() called on each respective drop
    - CompletionScreen widget exists and shows after _advanceToNextFlag() detects empty list
    - Completion screen ARB strings present in both ARB files
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| OverlayEntry rendering | Positioned above all widgets; must be removed on dispose to avoid memory leak |
| vector_math Matrix4 transform | Scene-to-screen conversion; math errors produce wrong centroid position |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-04-01 | Denial of Service | OverlayEntry not removed | mitigate | Always remove in whenComplete + dispose AnimationController. Add a State.dispose() override in MapScreen that calls _activeOverlay?.remove() as a safety net. |
| T-03-04-02 | Denial of Service | _advanceToNextFlag() called while _remainingIsoCodes empty | mitigate | Guard with `if (_remainingIsoCodes.isEmpty) return;` at top of method. completeGame() is idempotent (sets phase to completed — safe to call multiple times). |
| T-03-04-SC | Tampering | npm/pip/cargo installs | accept | No new packages. vector_math is a transitive dependency already bundled with Flutter. |
</threat_model>

<verification>
After all tasks complete:

1. `flutter test test/features/map/flag_sequence_test.dart` — exits 0 (3 tests green)
2. `flutter test test/architecture/ads_isolation_test.dart` — exits 0
3. `flutter analyze lib/features/map/ lib/features/game/` — zero errors
4. `flutter build apk --debug` — exits 0
5. `grep -rn "features/ads/" lib/features/map/ lib/features/game/` — zero matches
6. Visual: correct drop triggers scale+fade + haptic + next card slide-in; incorrect drop triggers bounce + haptic
</verification>

<success_criteria>
- Correct drop: OverlayEntry scale+fade animation to centroid, matched country greyed in WorldMapPainter, next flag slides in via AnimatedSwitcher
- Incorrect drop: FlagTray bounce animation (Curves.elasticOut), card returns to position
- Haptics: HapticFeedback.lightImpact (correct) and mediumImpact (incorrect)
- Audio: audioService.playCorrect() and playError() called
- Flag sequence: 196 unique ISOs in random order, no repeats, _advanceToNextFlag() drives progression
- completeGame() called after 196th correct drop
- CompletionScreen shows score, elapsed time, and "Play Again" button
- All 3 flag_sequence tests green
- ads_isolation_test.dart green
</success_criteria>

<output>
Create `.planning/phases/03-map-rendering-drag-drop/03-04-SUMMARY.md` when done
</output>

---

---
phase: 03-map-rendering-drag-drop
plan: 05
type: execute
wave: 5
depends_on:
  - 03-04
files_modified:
  - test/features/map/hit_detection_test.dart
  - test/features/map/flag_sequence_test.dart
  - test/features/map/world_map_painter_test.dart
  - test/features/map/drag_drop_widget_test.dart
autonomous: false
requirements:
  - MAP-01
  - MAP-02
  - MAP-03
  - MAP-04
  - MAP-05
  - GAME-01
  - GAME-02
  - GAME-03
  - GAME-04
  - GAME-05
  - GAME-06

must_haves:
  truths:
    - "flutter test exits 0 — full test suite green"
    - "flutter run --profile shows ≥30fps during drag-hover on mid-range Android"
    - "SC4 manually verified: correct hit detection at 1×, 2×, and 4× zoom on physical or emulated device"
    - "Full 196-flag session completes without crash and shows CompletionScreen"
  artifacts:
    - path: "test/features/map/hit_detection_test.dart"
      provides: "All 4 hit detection tests passing"
      contains: "test('GAME-01:"
    - path: "test/features/map/flag_sequence_test.dart"
      provides: "All 3 flag sequence tests passing"
      contains: "test('GAME-05:"
  key_links:
    - from: "MapScreen"
      to: "TransformationController.toScene()"
      via: "_toSceneFromGlobal() helper"
      pattern: "toScene"

---

## Plan 03-05: Integration Gate — Full Suite + Performance + SC4 Manual Verification

<objective>
Verify the entire Phase 3 deliverable against all 5 success criteria before marking the phase complete.

Purpose: Phase 3 SC4 explicitly requires a manual test on a physical or emulated device — it cannot be automated because coordinate-transform correctness under real touch/pointer input is the "known critical risk" from CLAUDE.md. This plan runs the full automated suite, profiles for 30fps, runs a full session smoke test, and gates on human confirmation of SC4.

Output:
- Full test suite green (all test/features/map/ tests + all test/unit/ tests + test/architecture/)
- Performance profile log showing ≥30fps during drag-hover
- Human confirmation that hit detection is correct at 1×, 2×, and 4× zoom
- Phase 3 marked complete in STATE.md and ROADMAP.md
</objective>

<execution_context>
@C:/Users/omerb/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/omerb/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/03-map-rendering-drag-drop/03-CONTEXT.md
@.planning/phases/03-map-rendering-drag-drop/03-04-SUMMARY.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Full test suite — ensure all map tests and existing tests are green</name>
  <files>
    test/features/map/hit_detection_test.dart
    test/features/map/flag_sequence_test.dart
    test/features/map/world_map_painter_test.dart
    test/features/map/drag_drop_widget_test.dart
  </files>
  <action>
    Run the full test suite. For any test that is still in RED-state (fail() sentinel) or skipped from Plan 03-03, implement the missing test body now. The only acceptable reason for a test to remain skipped is if it requires mocking infrastructure that has not been built — in that case, document the gap in a comment inside the test with `// TODO Phase 4: requires ...` and ensure `skip:` is set so it does not count as a failure.

    Verify the full suite against all Phase 3 requirement IDs:
    - MAP-01: WorldMapPainter shouldRepaint tests
    - MAP-05 + GAME-01 + GAME-03/04: drag_drop_widget_test tests
    - GAME-01 + GAME-02: hit_detection_test tests (all 4 must be green)
    - GAME-05 + GAME-06: flag_sequence_test tests (all 3 must be green)

    Also verify the architecture guard and all Phase 2 unit tests still pass (no regressions from Phase 3 changes).

    Run `flutter analyze` on the full lib/ directory and fix any remaining warnings or errors introduced in Phase 3.
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter test && flutter analyze lib/</automated>
  </verify>
  <done>
    - `flutter test` exits 0 with zero failures (skipped tests documented with TODO Phase 4 comment)
    - `flutter analyze lib/` exits 0
    - test/architecture/ads_isolation_test.dart green
    - test/unit/ all green (no Phase 3 regressions)
  </done>
</task>

<task type="auto">
  <name>Task 2: Profile performance — confirm ≥30fps during drag-hover on mid-range target</name>
  <files></files>
  <action>
    Run `flutter run --profile` on a connected device or emulator. In the Flutter DevTools performance overlay or via Observatory, record the frame rate during an active drag-hover event (drag a flag card over the map and move it slowly across multiple countries).

    Target: ≥30fps sustained during drag-hover. The two-layer RepaintBoundary architecture (WorldMapPainter static, HighlightPainter dynamic) was specifically designed for this — the static layer should not repaint during hover events.

    If frame rate is below 30fps: diagnose using the Flutter performance overlay (toggle with `p` in the debug console). Common causes:
    - WorldMapPainter.shouldRepaint returning true on hover events (check the _hoveredIso state path)
    - RepaintBoundary missing around one of the layers
    - HighlightPainter.paint() iterating over all 196 paths instead of only the hovered country's paths

    Document the observed frame rate in the task done criteria. If a hardware device is not available, use `flutter run --profile` on an AVD emulator (Pixel 4 API 33 or similar) as a proxy.

    Note: This is an automated profiling task — no human interaction required. Claude can run the profile build and check DevTools output or the `--trace-skia` flag output. If profiling requires interactive device manipulation that Claude cannot perform, document the command and expected output for the user to run.
  </action>
  <verify>
    <automated>cd C:/code/Claude/FlagsRoundTheWorld && flutter build apk --profile && echo "Profile APK built — install and run flutter run --profile for frame rate measurement"</automated>
  </verify>
  <done>
    - Profile APK builds without errors
    - Frame rate during drag-hover: documented (target ≥30fps)
    - If below 30fps: root cause identified and fix applied before proceeding to human checkpoint
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
    The complete Phase 3 game loop: interactive world map with 196 colored country regions, flag tray with draggable cards, single-DragTarget hit detection using `TransformationController.toScene()`, correct/incorrect feedback with animation/haptics/audio, 196-flag session ending in CompletionScreen.
  </what-built>
  <how-to-verify>
    Run `flutter run` (debug or profile mode) on a physical Android device or emulator.

    **SC1 — Map rendering:**
    - Confirm all country regions are visible and distinctly colored
    - Drag a card over the map — confirm it does not freeze or stutter noticeably
    - (Profile mode) Confirm ≥30fps via DevTools overlay

    **SC2 — Zoom and pan:**
    - Pinch to zoom in and out — confirm smooth gesture handling
    - Two-finger pan — confirm smooth panning
    - Tap + and - buttons — confirm zoom steps work and do not go past min/max limits
    - Country name labels should be more readable at 2×–4× zoom than at 1×

    **SC3 — Correct and incorrect feedback:**
    - Start a session; drag a flag card onto the correct country. Confirm: (a) the card animates toward the centroid and fades out, (b) the country fill changes to grey, (c) the next flag card slides in from the right, (d) haptic pulse fires (if device supports haptics), (e) audio plays (may be silent in Phase 3 — that is expected).
    - Drag a flag card onto the wrong country. Confirm: (a) the card bounces back to the tray, (b) the bounce uses a springy curve (Curves.elasticOut), (c) haptic buzz fires.

    **SC4 (CRITICAL — the known risk):**
    - At 1× zoom (initial fit): drag the current flag card onto a medium-sized country (e.g., France, Brazil, Australia). Confirm the hit registers correctly.
    - Pinch to 2× zoom; repeat the drag-drop on the same country. Confirm the hit still registers correctly — the card must land where the country visually is, not at an offset position.
    - Pinch to 4× zoom; repeat. Confirm correct hit at 4× zoom.
    - Try a small country (e.g., Luxembourg, Singapore, Malta) at 2× and 4× zoom — confirm the forgiving bbox allows a drop slightly near (but not exactly on) the country to still register.

    **SC5 — Full session:**
    - Let the session run to at least 5–10 correct matches. Confirm flags advance in random order and no flag repeats.
    - (Optional) Fast-forward through the full 196 by making rapid correct drops — confirm CompletionScreen appears after the last match and shows score + elapsed time.
  </how-to-verify>
  <resume-signal>
    Type "phase3-complete" if all SC1–SC5 pass.
    Or describe which success criterion failed (e.g., "SC4 fails at 4× zoom — drops register offset by ~30px") so the issue can be diagnosed and a gap-closure plan created.
  </resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Physical device I/O | Real touch events — behavior may differ from simulated pointer events in widget tests |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-05-01 | Denial of Service | Full 196-flag session memory | accept | 196 CountryData objects with pre-parsed Paths are loaded once; no per-drop allocation beyond animation controller (disposed immediately). Memory profile acceptable for a mid-range Android device with 2GB+ RAM. |
| T-03-05-SC | Tampering | npm/pip/cargo installs | accept | No new packages in Plan 03-05. |
</threat_model>

<verification>
Phase 3 complete when ALL of the following are true:

1. SC1: `flutter test` exits 0 — all test/features/map/ tests green, no regressions in test/unit/ or test/architecture/
2. SC1: `flutter analyze lib/` exits 0
3. SC1: Profile APK builds; frame rate during drag-hover ≥30fps (documented)
4. SC2: Pinch-to-zoom, two-finger pan, and zoom buttons confirmed working (human SC3/SC4 checkpoint)
5. SC3: Correct-drop animation + haptic + audio; incorrect-drop bounce + haptic + audio confirmed (human checkpoint)
6. SC4: Hit detection correct at 1×, 2×, 4× zoom on physical or emulated device (human checkpoint — MANUAL REQUIRED)
7. SC5: Full 196-flag session draws all flags once, CompletionScreen appears after last match (human checkpoint)
8. ads_isolation_test.dart green
9. `grep -rn "features/ads/" lib/features/game/ lib/features/map/ lib/core/` exits with zero matches
</verification>

<success_criteria>
- `flutter test` exits 0
- `flutter analyze lib/` exits 0
- Frame rate ≥30fps during drag-hover (SC1)
- Zoom, pan, labels confirmed (SC2)
- Correct/incorrect feedback confirmed (SC3)
- Hit detection at 1×, 2×, 4× zoom confirmed by human on device (SC4 — mandatory manual test)
- Full 196-flag session + CompletionScreen confirmed (SC5)
- ads_isolation_test.dart green
- Phase 3 marked complete in STATE.md
</success_criteria>

<output>
Create `.planning/phases/03-map-rendering-drag-drop/03-05-SUMMARY.md` when done.
Update `.planning/STATE.md` to advance current phase to Phase 4.
Update `.planning/ROADMAP.md` Phase 3 status to complete with today's date.
</output>
