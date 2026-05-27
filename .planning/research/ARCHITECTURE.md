# Architecture Patterns: Flags Around the World

**Domain:** Educational geography / flag-matching Flutter mobile game
**Researched:** 2026-05-27
**Sources:** Official Flutter documentation (docs.flutter.dev, api.flutter.dev), cross-referenced
against existing STACK.md and FEATURES.md research.
**Overall confidence:** HIGH for structure and patterns; MEDIUM for specific coordinate-transform
implementation details (InteractiveViewer + Draggable interaction requires empirical validation).

---

## 1. Project Structure

### Decision: Feature-First, Not Layer-First

**Recommendation: Feature-first directory structure.**

Layer-first (`lib/models/`, `lib/services/`, `lib/widgets/`) collapses as the project grows — a
change to the game session feature touches five directories. Feature-first means each feature is
a self-contained vertical slice that can be reasoned about, tested, and built independently.

Flutter's official architecture guide does not mandate a specific directory structure, but its
case-study project (`compass_app`) uses feature-first organisation. The Flutter Games Toolkit
templates also organise by feature.

### Recommended Directory Tree

```
flags_around_the_world/
├── android/
├── ios/
├── assets/
│   ├── audio/
│   │   ├── sfx/
│   │   │   ├── correct.ogg
│   │   │   ├── incorrect.ogg
│   │   │   ├── milestone.ogg
│   │   │   └── countdown.ogg
│   │   └── music/
│   │       └── background_loop.ogg
│   ├── data/
│   │   ├── countries.json          # ISO code → { name_en, capital, continent, facts[] }
│   │   ├── countries_es.json       # Spanish country names
│   │   ├── countries_fr.json       # French country names
│   │   └── world_map_paths.json    # ISO code → SVG path string(s) + bounding box
│   ├── flags/
│   │   ├── ad.svg                  # Named by ISO 3166-1 alpha-2
│   │   ├── ae.svg
│   │   ├── af.svg
│   │   └── ... (195 total)
│   └── images/
│       └── tutorial/
├── lib/
│   ├── main.dart                   # App entry point; MobileAds.initialize(); runApp()
│   ├── app.dart                    # MaterialApp, GoRouter, ProviderScope
│   ├── flavors.dart                # appFlavor constant; AdMob ID routing
│   │
│   ├── core/                       # Cross-cutting infrastructure
│   │   ├── constants/
│   │   │   ├── ad_ids.dart         # Production + test AdMob unit IDs per flavor
│   │   │   ├── game_constants.dart # Timer tick, score penalties, snap radius
│   │   │   └── asset_paths.dart    # Centralised asset path strings
│   │   ├── models/
│   │   │   ├── country.dart        # Country value object (ISO code, name, capital...)
│   │   │   ├── game_mode.dart      # Enum: learn, flagsMaster, geoMaster, grandMaster
│   │   │   └── game_result.dart    # Score, duration, matched count, mode
│   │   ├── routing/
│   │   │   ├── app_router.dart     # GoRouter definition; all route constants
│   │   │   └── route_guards.dart   # Back-button interception during active game
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   └── color_palette.dart
│   │   └── utils/
│   │       ├── coordinate_transform.dart  # Screen ↔ SVG space maths
│   │       └── path_hit_test.dart         # dart:ui Path.contains() wrapper
│   │
│   ├── features/
│   │   │
│   │   ├── map/                    # World map rendering and interaction
│   │   │   ├── data/
│   │   │   │   ├── map_data_service.dart      # Loads world_map_paths.json asset
│   │   │   │   └── map_repository.dart        # Parses JSON → List<CountryRegion>
│   │   │   ├── domain/
│   │   │   │   └── country_region.dart        # dart:ui Path + bounding box + ISO code
│   │   │   └── presentation/
│   │   │       ├── map_view_model.dart        # Riverpod notifier; highlighted country
│   │   │       ├── world_map_widget.dart      # InteractiveViewer + CustomPainter wrapper
│   │   │       ├── world_map_painter.dart     # CustomPainter; draws paths per country
│   │   │       └── country_drop_target.dart   # DragTarget<String> overlay per country
│   │   │
│   │   ├── game/                   # Game session state machine
│   │   │   ├── data/
│   │   │   │   ├── country_data_service.dart  # Loads countries.json + locale JSON
│   │   │   │   └── country_repository.dart    # Returns List<Country>; caches
│   │   │   ├── domain/
│   │   │   │   ├── game_state.dart            # Enum + sealed class (see §2)
│   │   │   │   ├── game_session.dart          # Value object: score, matched, flags left
│   │   │   │   ├── scoring_service.dart       # Pure Dart; golf scoring logic
│   │   │   │   └── hint_service.dart          # Free hints remaining; consume/refill
│   │   │   └── presentation/
│   │   │       ├── game_session_notifier.dart # Riverpod AsyncNotifier; owns the timer
│   │   │       ├── game_screen.dart           # Scaffold; composes map + flag tray + HUD
│   │   │       ├── flag_tray_widget.dart      # Horizontal scrollable flag card strip
│   │   │       ├── flag_card_widget.dart      # Draggable<String> carrying ISO code
│   │   │       ├── game_hud_widget.dart       # Score, timer, progress bar, pause button
│   │   │       └── pause_overlay_widget.dart  # Pause state overlay; no ads here
│   │   │
│   │   ├── result/                 # Post-game result screen
│   │   │   └── presentation/
│   │   │       ├── result_view_model.dart
│   │   │       └── result_screen.dart        # Stars, PB celebration, share button
│   │   │
│   │   ├── home/                   # Home screen + mode selection
│   │   │   └── presentation/
│   │   │       ├── home_screen.dart
│   │   │       └── mode_card_widget.dart     # Shows mode name, PB, locked/unlocked
│   │   │
│   │   ├── settings/
│   │   │   └── presentation/
│   │   │       ├── settings_screen.dart
│   │   │       └── settings_notifier.dart    # Mute, text scale, fact-card toggle
│   │   │
│   │   ├── ads/                    # Ad lifecycle management (isolated from game logic)
│   │   │   ├── ad_service.dart            # Loads, caches, shows all ad formats
│   │   │   ├── ad_notifier.dart           # Riverpod notifier for ad state
│   │   │   └── rewarded_ad_gate.dart      # Widget that gates rewarded ad behind state check
│   │   │
│   │   ├── scores/                 # Persistence of high scores
│   │   │   ├── high_score_service.dart    # shared_preferences read/write
│   │   │   └── high_score_repository.dart # Domain interface
│   │   │
│   │   └── tutorial/
│   │       └── presentation/
│   │           ├── tutorial_overlay_widget.dart
│   │           └── tutorial_controller.dart   # 3-step animation driver
│   │
│   └── l10n/
│       ├── app_en.arb              # UI chrome strings only (not country names)
│       ├── app_es.arb
│       ├── app_fr.arb
│       └── l10n.dart               # Re-export of generated AppLocalizations
│
├── test/
│   ├── unit/
│   │   ├── scoring_service_test.dart
│   │   ├── path_hit_test_test.dart
│   │   ├── coordinate_transform_test.dart
│   │   └── game_session_notifier_test.dart
│   └── widget/
│       ├── flag_card_widget_test.dart
│       └── world_map_painter_test.dart
│
├── integration_test/
│   └── drag_drop_flow_test.dart
│
├── pubspec.yaml
├── l10n.yaml
└── analysis_options.yaml
```

**Why this structure works for the build order:**

Map data (features/map) and game data (features/game/data) are built first since game session,
result, and home screens all depend on them. The ad layer (features/ads) is isolated so it can
be stubbed during early development and swapped to real AdMob IDs at the end.

---

## 2. Game State Machine

### State Enum

```dart
// lib/features/game/domain/game_state.dart

enum GamePhase {
  idle,        // No session started; game screen not mounted
  countdown,   // 3-2-1 countdown before play begins
  playing,     // Timer running; drag-drop accepting
  paused,      // Timer frozen; overlay shown; accepting no drops
  completed,   // All flags placed; timer stopped; result pending
}
```

### Game Session Value Object

```dart
// lib/features/game/domain/game_session.dart

@immutable
class GameSession {
  final GameMode mode;
  final GamePhase phase;
  final int score;                          // Golf-style: starts at 0, increases on time/error
  final Duration elapsed;
  final List<String> pendingIsoCodes;       // Flags not yet placed
  final Map<String, bool> results;          // ISO → correct/incorrect
  final int errorCount;                     // Per-flag error count for auto-hint trigger
  final int hintsRemaining;
  final String? activeIsoCode;             // Flag currently being dragged

  const GameSession({ ... });

  GameSession copyWith({ ... });
}
```

### Where It Lives: Riverpod AsyncNotifier

```dart
// lib/features/game/presentation/game_session_notifier.dart

@riverpod
class GameSessionNotifier extends _$GameSessionNotifier {
  Ticker? _ticker;

  @override
  GameSession build() => GameSession.initial();

  void startGame(GameMode mode, List<Country> countries) { ... }
  void pauseGame() { ... }
  void resumeGame() { ... }
  void onFlagDropped(String isoCode, String targetIsoCode) { ... }
  void _onTick(Duration elapsed) { ... }   // Called by Ticker each frame
  void useHint() { ... }
  void endGame() { ... }
}
```

### Timer Implementation

Use `Ticker` from `package:flutter/scheduler.dart`, not `Timer.periodic` or `Stream.periodic`.

Rationale: `Ticker` fires on each vsync (frame boundary), keeping timer updates synchronised with
the Flutter rendering pipeline. `Timer.periodic` fires on a background isolate timer and can
accumulate drift relative to rendering. The `TickerProvider` is obtained from the `GameScreen`
`State<>` and injected into the notifier via `ref.read`.

```dart
// Inside GameSessionNotifier
void _startTicker(TickerProvider vsync) {
  _ticker = vsync.createTicker(_onTick)..start();
}

void _onTick(Duration elapsed) {
  // Add time-based score increment (e.g., +1 every 10 seconds)
  final scoreIncrement = (elapsed.inSeconds ~/ 10) - (state.elapsed.inSeconds ~/ 10);
  if (scoreIncrement > 0) {
    state = state.copyWith(
      elapsed: elapsed,
      score: state.score + scoreIncrement,
    );
  } else {
    state = state.copyWith(elapsed: elapsed);
  }
}
```

### App Lifecycle → Auto-Pause

```dart
// Inside GameScreen (StatefulWidget)
class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(gameSessionNotifierProvider.notifier).pauseGame();
    }
  }
}
```

### State Serialisation (survive app kill)

On every `onFlagDropped` call, write the serialised `GameSession` to `shared_preferences`.
On game screen mount, check for a persisted session and offer "Continue your game?" dialog.

```
Key: "game_session_in_progress"
Value: JSON-encoded GameSession (ISO codes are strings; Duration is int milliseconds)
```

Clear the persisted session when `endGame()` is called (normal or explicit "give up" exit).

---

## 3. Map Data Architecture

### Storage Format: JSON Asset (not Dart constants, not raw SVG)

**Recommendation: `assets/data/world_map_paths.json`**

Do not embed raw SVG path strings as Dart constants — that bloats the compiled binary and makes
the map data opaque to non-Dart tooling. Do not ship the raw SVG at runtime and parse it with an
XML parser — parsing 195 complex path strings on the main thread at startup causes a noticeable
jank.

The correct pipeline is:

```
Pre-build (offline tooling, run once):
  Natural Earth SVG → Python script → world_map_paths.json

Runtime (app startup, once):
  world_map_paths.json → dart:convert JSON decode → List<CountryRegion>
  (each CountryRegion holds a dart:ui Path pre-built from the path string)
```

### JSON Schema

```json
{
  "version": 1,
  "viewBox": { "width": 2000, "height": 1000 },
  "countries": [
    {
      "iso": "de",
      "nameEn": "Germany",
      "paths": ["M 100,200 L 150,220 ..."],   // One entry per disjoint region (islands)
      "boundingBox": { "x": 98, "y": 195, "w": 60, "h": 45 },
      "centroid": { "x": 128, "y": 217 }       // For label placement and snap targeting
    }
  ]
}
```

Country code is the primary key throughout — every feature that references a country uses its
ISO 3166-1 alpha-2 code (2-letter lowercase), not a name string or numeric ID.

### Building `dart:ui Path` Objects

```dart
// lib/features/map/domain/country_region.dart

class CountryRegion {
  final String isoCode;
  final Path combinedPath;   // dart:ui Path; union of all sub-paths
  final Rect boundingBox;    // For quick AABB rejection before Path.contains()
  final Offset centroid;     // Snap target for forgiving drop

  static CountryRegion fromJson(Map<String, dynamic> json) {
    final paths = (json['paths'] as List<dynamic>)
        .map((p) => parseSvgPathData(p as String))  // See §3 hit-testing
        .toList();
    final combined = paths.reduce((a, b) => Path.combine(PathOperation.union, a, b));
    return CountryRegion(
      isoCode: json['iso'] as String,
      combinedPath: combined,
      boundingBox: _boundingBoxFromJson(json['boundingBox']),
      centroid: _centroidFromJson(json['centroid']),
    );
  }
}
```

### Hit-Testing: Given Drop (x, y), Which Country?

Hit-testing happens in SVG/map coordinate space, not screen coordinate space.

**Two-phase test:**

Phase 1 — AABB (bounding box) rejection: iterate 195 `Rect.contains()` checks; O(1) per country.
Phase 2 — Precise path test: for candidates that pass AABB, call `Path.contains(offset)`. O(n)
in path vertices, but typically only 1-3 countries pass the AABB check for a given point.

```dart
// lib/core/utils/path_hit_test.dart

String? hitTest(Offset mapPoint, List<CountryRegion> regions) {
  for (final region in regions) {
    if (!region.boundingBox.contains(mapPoint)) continue;  // Phase 1
    if (region.combinedPath.contains(mapPoint)) {          // Phase 2
      return region.isoCode;
    }
  }
  return null;
}
```

**Forgiving snap radius:** After identifying the target country from the drop position, if the
result is null (dropped on ocean/gap), find the nearest centroid within a threshold radius and
accept that country as the target. The threshold is expressed in SVG coordinates and is constant
regardless of zoom level.

```dart
String? hitTestWithSnap(Offset mapPoint, List<CountryRegion> regions, double snapRadius) {
  final exact = hitTest(mapPoint, regions);
  if (exact != null) return exact;

  // Find nearest centroid within snap radius
  CountryRegion? nearest;
  double nearestDist = double.infinity;
  for (final region in regions) {
    final dist = (region.centroid - mapPoint).distance;
    if (dist < snapRadius && dist < nearestDist) {
      nearestDist = dist;
      nearest = region;
    }
  }
  return nearest?.isoCode;
}
```

### Coordinate Space Mapping: Screen → SVG

`InteractiveViewer` applies a 4×4 matrix transform to its child. To map a screen-space drop
position back to SVG coordinates:

```dart
// lib/core/utils/coordinate_transform.dart

Offset screenToMapCoordinates(
  Offset screenPoint,
  TransformationController transformationController,
) {
  // InteractiveViewer exposes the current transform via TransformationController.value
  // Invert the matrix to map screen → child (SVG) coordinates
  final matrix = transformationController.value;
  final inverse = Matrix4.inverted(matrix);
  final local = MatrixUtils.transformPoint(inverse, screenPoint);
  return local;
}
```

This must be called on the drop offset provided by `DragTarget.onAcceptWithDetails(details)`,
using `details.offset` (which is in global screen coordinates).

**Critical:** The `DragTarget` widgets must be positioned as children of the `InteractiveViewer`
child widget so their `RenderBox.globalToLocal()` transform already incorporates the zoom/pan.
If `DragTarget` is placed outside the `InteractiveViewer`, coordinate remapping becomes much
harder and the highlight-on-hover effect becomes impossible to implement correctly.

---

## 4. Drag-and-Drop System

### Architecture Decision: Flag Tray Is Outside InteractiveViewer

The flag tray (bottom panel of draggable flag cards) is placed **outside and below** the
`InteractiveViewer`. This solves the primary gesture conflict: the `InteractiveViewer` needs to
handle pinch-zoom and pan, while `Draggable` needs to handle long-press-drag. Placing the drag
source outside the interactive viewport eliminates the gesture arena conflict.

```
┌─────────────────────────────────────────────────────┐
│                      HUD                           │  ← StatelessWidget, no gesture conflict
├─────────────────────────────────────────────────────┤
│                                                     │
│             InteractiveViewer                       │  ← Handles pinch-zoom, pan
│   ┌─────────────────────────────────────────────┐  │
│   │         WorldMapWidget                      │  │
│   │   (CustomPainter + DragTarget overlays)     │  │
│   └─────────────────────────────────────────────┘  │
│                                                     │
├─────────────────────────────────────────────────────┤
│                   FlagTray                          │  ← Draggable<String> cards here
└─────────────────────────────────────────────────────┘
```

### Flag Card Structure

```dart
// lib/features/game/presentation/flag_card_widget.dart

class FlagCardWidget extends StatelessWidget {
  final String isoCode;         // Data payload for DragTarget
  final bool isBeingDragged;

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: isoCode,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _FlagDragFeedback(isoCode: isoCode),   // Floating visual during drag
      childWhenDragging: _FlagCardPlaceholder(),         // Greyed-out placeholder in tray
      child: _FlagCardNormal(isoCode: isoCode),
    );
  }
}

class _FlagDragFeedback extends StatelessWidget {
  // Rendered at pointer position during drag
  // Must be a top-level Overlay widget (Flutter handles this automatically for Draggable.feedback)
  // Size: slightly larger than the card to indicate "in flight"
  // Shadow + slight tilt transform to signal drag state
}
```

### DragTarget Registration Per Country

Each country region gets a `DragTarget<String>` overlay. These are positioned using a `Stack`
inside the `InteractiveViewer` child. The DragTarget's hit area is the country's `Path` shape,
enforced via `DragTarget.onWillAcceptWithDetails` checking the drop position:

```dart
// lib/features/map/presentation/country_drop_target.dart

class CountryDropTarget extends ConsumerWidget {
  final CountryRegion region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        // Accept any flag drag — let onAcceptWithDetails decide correctness
        return true;
      },
      onAcceptWithDetails: (details) {
        // details.offset is in global screen coordinates
        final mapPoint = screenToMapCoordinates(
          details.offset,
          ref.read(transformationControllerProvider),
        );
        ref
          .read(gameSessionNotifierProvider.notifier)
          .onFlagDropped(details.data, region.isoCode, mapPoint);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        // Render a transparent overlay; the actual country shape is drawn by CustomPainter
        // When isHighlighted, notify the MapViewModel to change the country's fill color
        return const SizedBox.expand();
      },
    );
  }
}
```

**DragTarget size problem:** The `DragTarget` widget must have a physical size to receive pointer
events. For small countries (Luxembourg, Monaco, Vatican), a bounding-box-sized DragTarget is too
small to be hittable. Solution: Use `GestureDetector` with `behavior: HitTestBehavior.translucent`
on an expanded area, and let the game logic's `hitTestWithSnap()` function determine the snap
target by centroid proximity. The DragTarget's formal acceptance is used for hover highlighting;
the actual country resolution uses the coordinate-space hit-test.

### Large Hit-Boxes While Detecting Correct Country

The separation is:

- `DragTarget` provides hover feedback (highlight the entire bounding box region when hovering).
- Correct-country determination uses `hitTestWithSnap()` against the precise SVG path.
- The snap radius is expressed in SVG coordinates. It is constant regardless of zoom level,
  which means it becomes proportionally harder to snap at high zoom (correct behavior — at 8×
  zoom, the player can place accurately).

---

## 5. Asset Pipeline

### Flag SVG Organisation

```
assets/flags/
  ad.svg    # Andorra
  ae.svg    # United Arab Emirates
  af.svg    # Afghanistan
  ...
  zw.svg    # Zimbabwe
```

Named by ISO 3166-1 alpha-2 code, all lowercase. 195 files total from `lipis/flag-icons` (MIT).

### pubspec.yaml Registration

```yaml
flutter:
  assets:
    - assets/flags/           # Registers all 195 SVG files
    - assets/data/            # countries.json, countries_*.json, world_map_paths.json
    - assets/audio/sfx/
    - assets/audio/music/
    - assets/images/tutorial/
```

### Loading Strategy: Lazy with Warm-Up

Do not pre-load all 195 flags at app start. `flutter_svg` renders SVGs via its internal cache;
a flag card appearing for the first time will parse and rasterize its SVG on first display.

Warm-up strategy: when a game session starts, pre-warm the cache for the 10-15 flags in the
current visible tray, then continue warming the remaining flags in the background using
`SvgPicture.asset().load()` while the player works through the game.

```dart
// In GameSessionNotifier.startGame()
void _prewarmFlagCache(List<String> isoCodes, BuildContext context) {
  for (final iso in isoCodes.take(15)) {
    final loader = SvgAssetLoader('assets/flags/$iso.svg');
    svg.cache.putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
  }
}
```

### Aspect Ratio Handling

`lipis/flag-icons` SVG flags have consistent 4:3 aspect ratio for most flags, with exceptions
(Nepal is approximately 3:4, Switzerland and Vatican are square). Always display flags with
`BoxFit.contain` inside a fixed-width card slot — never `BoxFit.fill`.

```dart
SvgPicture.asset(
  'assets/flags/$isoCode.svg',
  width: 64,
  height: 48,
  fit: BoxFit.contain,
  placeholderBuilder: (_) => const SizedBox(width: 64, height: 48),
)
```

---

## 6. AdMob Integration Layer

### Isolation Principle

Ad lifecycle management must not touch game logic. The `features/ads/` feature module is a
walled garden. Game logic (`GameSessionNotifier`) never imports from `features/ads/`. Instead,
the `GameScreen` widget observes both the game state provider and the ad state provider and
coordinates them at the presentation layer.

### Ad State Model

```dart
// lib/features/ads/ad_notifier.dart

enum AdLoadState { idle, loading, ready, shown, failed }

@freezed
class AdBankState with _$AdBankState {
  const factory AdBankState({
    required AdLoadState bannerState,
    required AdLoadState interstitialState,
    required AdLoadState rewardedState,
    required AdLoadState appOpenState,
    required DateTime? lastInterstitialShown,  // For frequency capping
  }) = _AdBankState;
}

@riverpod
class AdBankNotifier extends _$AdBankNotifier {
  // Loads ads eagerly on creation; refreshes when shown
  // Implements 4-hour cooldown for App Open ads
  // Exposes showInterstitial(), showRewarded(), showBanner() methods
  // Never exposes AdObject references directly — only AdLoadState
}
```

### Rewarded Ad Gate (Hint Refill)

The rewarded ad is gated behind a clear user action (tapping "Watch ad for hints"). The flow:

```
Player taps "Watch ad" button
  → GameScreen checks AdBankState.rewardedState == AdLoadState.ready
    → YES: show ad; on reward callback → GameSessionNotifier.refillHints()
    → NO: show "Ad not available" snackbar; offer 1 free hint as fallback
```

The reward callback only fires via the AdMob SDK; it must not be triggerable by any other code
path (no test backdoor in release builds). Wire it through a closure passed to `AdService`:

```dart
AdService.showRewarded(onReward: () {
  ref.read(gameSessionNotifierProvider.notifier).refillHints();
});
```

### Ad Display Rules

| Ad Format | When to Show | Never Show |
|-----------|-------------|------------|
| App Open | App foreground after 4-hour gap | During active game session |
| Banner | Home screen, result screen, mode selection | During active game; on pause screen |
| Interstitial | On return to home after game completion | Mid-game; on app open; more than 1 per 2 games |
| Rewarded Interstitial | Only when player explicitly requests hint refill | Automatically; during countdown |

### Offline / Load Failure Handling

All ad show calls are wrapped with a try/catch and a `AdLoadState` guard. If the SDK throws or
the load state is `failed`, the UI degrades gracefully:

- Banner: slot collapses to zero height (do not show an empty placeholder box).
- Interstitial: skip silently; do not break navigation flow.
- Rewarded: show "Ads are unavailable right now. Here's one free hint." — do not block the game.

### COPPA Configuration (must happen before initialize)

```dart
// lib/main.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
      maxAdContentRating: MaxAdContentRating.g,
    ),
  );

  await MobileAds.instance.initialize();
  runApp(const ProviderScope(child: App()));
}
```

**CRITICAL:** `updateRequestConfiguration` must be called before `initialize`. Each mediation
network (AppLovin, Unity, Meta) must also be individually configured — the AdMob child-directed
flag does NOT propagate automatically to mediated SDKs.

---

## 7. Localization Data Layer

### Two-Track Approach: ARB for UI, JSON for Country Names

ARB files (processed by `flutter gen-l10n`) contain only UI chrome strings. Country names are
loaded from per-locale JSON data assets at runtime.

**Why separate tracks:**
- 195 countries × N locales = potentially 2000+ ARB keys. This makes the generated
  `AppLocalizations` class enormous, slows code generation, and makes translator tooling
  unwieldy.
- Country name data can be shipped as incremental asset updates without regenerating code.
- JSON allows runtime locale switching without a hot restart.

### ARB Content (UI Chrome Only)

```
lib/l10n/app_en.arb:
{
  "appTitle": "Flags Around the World",
  "modeLearn": "Learn",
  "modeFlagsMaster": "Flags Master",
  "modeGeoMaster": "Geographical Master",
  "modeGrandMaster": "Grand Master",
  "hud_score": "Score: {score}",
  "hud_flags_remaining": "{count} flags left",
  "pause_resume": "Resume",
  "pause_quit": "End Game",
  "result_personal_best": "New Personal Best!",
  "result_score_label": "Score",
  "hint_watch_ad": "Watch ad for hints",
  "hint_ad_unavailable": "Ads unavailable — here's a free hint",
  ...
}
```

### Country Name JSON Structure

```json
// assets/data/countries.json (canonical, English)
{
  "de": { "name": "Germany", "capital": "Berlin", "continent": "Europe" },
  "fr": { "name": "France",  "capital": "Paris",  "continent": "Europe" },
  ...
}

// assets/data/countries_de.json (German localisation)
{
  "de": { "name": "Deutschland" },
  "fr": { "name": "Frankreich" },
  ...
}
```

Only include the keys that differ from English in each locale file. The
`CountryDataService` merges the base JSON with the locale override at load time.

### Loading at Runtime

```dart
// lib/features/game/data/country_data_service.dart

Future<Map<String, Country>> loadCountries(Locale locale) async {
  final baseJson = await rootBundle.loadString('assets/data/countries.json');
  final base = json.decode(baseJson) as Map<String, dynamic>;

  Map<String, dynamic> localeOverride = {};
  final localePath = 'assets/data/countries_${locale.languageCode}.json';
  try {
    final localeJson = await rootBundle.loadString(localePath);
    localeOverride = json.decode(localeJson) as Map<String, dynamic>;
  } catch (_) {
    // No locale file for this language; fall back to English names
  }

  return base.map((iso, data) {
    final override = localeOverride[iso] as Map<String, dynamic>? ?? {};
    return MapEntry(iso, Country.fromJson(iso, {...data, ...override}));
  });
}
```

### l10n.yaml Configuration

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
synthetic-package: false
```

---

## 8. Navigation

### Recommendation: GoRouter

Flutter's official documentation explicitly states named routes are no longer recommended and
points to `go_router` as the preferred solution. GoRouter is the `go_router` package, maintained
by the Flutter team on pub.dev.

### Route Structure

```dart
// lib/core/routing/app_router.dart

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/game/:mode',
      builder: (_, state) => GameScreen(
        mode: GameMode.fromString(state.pathParameters['mode']!),
      ),
      // Back-button guard (see below)
      onExit: (context, state) async {
        final session = ProviderScope.containerOf(context)
            .read(gameSessionNotifierProvider);
        if (session.phase == GamePhase.playing) {
          return await _showQuitConfirmation(context) ?? false;
        }
        return true;
      },
    ),
    GoRoute(
      path: '/result',
      builder: (_, state) => ResultScreen(
        result: state.extra as GameResult,
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsScreen(),
    ),
  ],
);
```

### Android Back Button During Game

GoRouter's `onExit` callback on the `/game/:mode` route intercepts the system back gesture and
the hardware back button uniformly on Android and iOS swipe-back. When the game is in
`GamePhase.playing`, show a confirmation dialog:

```
"End this game? Your current score will be saved as a partial result."
[Stay] [End Game]
```

When paused (`GamePhase.paused`), back button resumes the game instead of exiting.

### Navigation Data Flow

```
HomeScreen
  → context.go('/game/learn')        # Start a new session
  → context.go('/settings')

GameScreen
  → context.go('/result', extra: gameResult)   # On completion
  → back button → onExit guard → confirmation  # During play
  → back button → resume game                  # When paused

ResultScreen
  → context.go('/home')              # Main menu
  → context.go('/game/:mode')        # Play again (same mode)
```

---

## 9. Testing Strategy

### Unit Tests (Pure Dart, No Widget Tree)

Test these in isolation with no Flutter dependency:

| Test Class | What to Test |
|------------|-------------|
| `ScoringService` | Golf scoring: +1/10s, +5/error, boundary cases |
| `PathHitTest` | `hitTest()` and `hitTestWithSnap()` with synthetic Path objects |
| `CoordinateTransform` | `screenToMapCoordinates()` against known Matrix4 values |
| `GameSessionNotifier` | State transitions: idle→countdown→playing→paused→playing→completed |
| `HighScoreRepository` | Read/write/update logic against a mock `SharedPreferences` |
| `CountryDataService` | JSON parsing, locale merge, missing-locale fallback |

**Path hit-testing unit tests are critical** because this logic determines correct/incorrect
game outcomes. Test with real (simplified) path data from the world_map_paths.json, not mocked
paths. Use `Rect`-based paths as stand-ins for easy manual coordinate calculation:

```dart
test('hitTest identifies Germany from point inside path', () {
  final germanyPath = Path()..addRect(const Rect.fromLTWH(100, 200, 60, 45));
  final region = CountryRegion(isoCode: 'de', combinedPath: germanyPath, ...);
  expect(hitTest(const Offset(130, 222), [region]), equals('de'));
});
```

### Widget Tests

| Widget | What to Test |
|--------|-------------|
| `FlagCardWidget` | Renders correct flag SVG; shows placeholder during drag |
| `GameHudWidget` | Displays score and timer from GameSession; pause button triggers state change |
| `PauseOverlayWidget` | Appears when phase == paused; resume button works |
| `ResultScreen` | Shows correct star count for known score/mode combinations |

Widget tests for drag-and-drop are limited — use them to verify the `Draggable` has the correct
`data` payload. Do not attempt to simulate the full drag path in a widget test.

### Integration Tests

Integration tests run on-device via `integration_test`. Use them for:

1. **Complete game flow**: Start game in Learn mode → drag one flag to correct country → verify
   score increments → drag to wrong country → verify error penalty → pause → resume → end game
   → result screen appears.

2. **App lifecycle**: Simulate backgrounding via `tester.binding.handleAppLifecycleStateChanged()`
   → verify game auto-pauses → bring to foreground → verify resume works.

3. **Navigation guards**: During active game, tap system back → verify dialog appears → tap Stay →
   verify game continues.

**Do NOT integration-test:**
- Exact pixel positions on the SVG map (screen-size fragile).
- AdMob ad display (use test ad unit IDs and manual QA only).
- Precise haptic/audio triggers (platform side effects; verify manually on device).

### Mocking Pattern with Mocktail

```dart
// Mock the HighScoreService for unit testing repository
class MockSharedPreferences extends Mock implements SharedPreferences {}

// Override Riverpod providers in tests
final container = ProviderContainer(
  overrides: [
    highScoreServiceProvider.overrideWith((_) => MockHighScoreService()),
  ],
);
```

---

## 10. Build Flavor / Environment Configuration

### Two Flavors: dev and production

```kotlin
// android/app/build.gradle.kts

android {
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Flags (Dev)")
        }
        create("production") {
            dimension = "env"
            // No suffix; uses base applicationId from defaultConfig
            resValue("string", "app_name", "Flags Around the World")
        }
    }
}
```

### AdMob ID Routing

```dart
// lib/flavors.dart

import 'package:flutter/services.dart';

const String _devBannerAdUnitId     = 'ca-app-pub-3940256099942544/6300978111';  // Test
const String _devInterstitialAdId   = 'ca-app-pub-3940256099942544/1033173712';  // Test
const String _devRewardedAdId       = 'ca-app-pub-3940256099942544/5224354917';  // Test
const String _devAppOpenAdId        = 'ca-app-pub-3940256099942544/9257395921';  // Test

const String _prodBannerAdUnitId     = 'ca-app-pub-XXXX/YYYY';  // Replace at ship
const String _prodInterstitialAdId   = 'ca-app-pub-XXXX/ZZZZ';
const String _prodRewardedAdId       = 'ca-app-pub-XXXX/WWWW';
const String _prodAppOpenAdId        = 'ca-app-pub-XXXX/VVVV';

class AdIds {
  static String get banner =>
      appFlavor == 'production' ? _prodBannerAdUnitId : _devBannerAdUnitId;
  static String get interstitial =>
      appFlavor == 'production' ? _prodInterstitialAdId : _devInterstitialAdId;
  static String get rewarded =>
      appFlavor == 'production' ? _prodRewardedAdId : _devRewardedAdId;
  static String get appOpen =>
      appFlavor == 'production' ? _prodAppOpenAdId : _devAppOpenAdId;
}
```

**`appFlavor`** is a compile-time constant provided by the Flutter flavors system
(`package:flutter/services.dart`). It is set correctly by `flutter run --flavor dev` and
`flutter build apk --flavor production`.

### Flutter Run Commands

```bash
# Development (test AdMob IDs, .dev package suffix)
flutter run --flavor dev

# Production build
flutter build appbundle --flavor production --release
flutter build ipa --flavor production --release
```

### Future A/B Testing Preparation

The `AppConfig` class is the insertion point for future A/B flags. Currently it just reads
from `appFlavor`, but its interface supports injecting a remote config source later:

```dart
// lib/core/constants/app_config.dart

class AppConfig {
  // Future: inject from Firebase Remote Config provider
  static bool get showCountryFactCards => true;
  static double get snapRadiusSvgUnits => 15.0;
  static int get freeHintsPerSession => 2;
  static int get interstitialCooldownGames => 2;
}
```

When A/B testing is needed, replace the static constants with a Riverpod provider backed by
Firebase Remote Config. No game logic needs to change — it already reads from `AppConfig`.

---

## Component Boundaries (What Talks to What)

```
┌──────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│                                                              │
│  HomeScreen ──→ GameScreen ──→ ResultScreen                 │
│       │              │                │                      │
│       │         FlagTray         (reads GameResult)          │
│       │         WorldMap                                     │
│       │         GameHUD                                      │
│       │         PauseOverlay                                 │
└──────────────────────────────────────────────────────────────┘
         │              │                │
         ↓              ↓                ↓
┌──────────────────────────────────────────────────────────────┐
│                    VIEWMODEL / NOTIFIER LAYER                │
│                                                              │
│  GameSessionNotifier  MapViewModel  AdBankNotifier           │
│  HighScoreRepository  SettingsNotifier                       │
│                                                              │
│  (Riverpod providers; no cross-notifier direct calls —       │
│   coordination happens in GameScreen or via provider watch)  │
└──────────────────────────────────────────────────────────────┘
         │              │                │
         ↓              ↓                ↓
┌──────────────────────────────────────────────────────────────┐
│                    DATA / SERVICE LAYER                      │
│                                                              │
│  CountryDataService  MapDataService  HighScoreService        │
│  AdService           AudioService                            │
│                                                              │
│  (Pure Dart classes; no Flutter widget imports;              │
│   return domain models, not raw JSON/API objects)            │
└──────────────────────────────────────────────────────────────┘
         │              │                │
         ↓              ↓                ↓
┌──────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE                            │
│                                                              │
│  assets/data/*.json  SharedPreferences  MobileAds SDK        │
│  just_audio          dart:ui Path       rootBundle           │
└──────────────────────────────────────────────────────────────┘
```

**Cross-cutting rules:**
- Presentation widgets may only call notifiers/viewmodels via `ref.read` or `ref.watch`. They
  never call services directly.
- Notifiers/viewmodels call repositories, not services directly. Repositories own service calls.
- The `ads` feature is referenced only from `GameScreen` (to gate rewarded ads) and from
  `HomeScreen` (to show banners). `GameSessionNotifier` has no import from `features/ads/`.
- `core/` is imported by any layer. No feature imports from another feature — data flows only
  through shared Riverpod providers.

---

## Data Flow: Flag Drop to Score Update

```
Player releases flag over map
        │
        ▼
DragTarget.onAcceptWithDetails(details)
  details.offset = global screen coordinates
        │
        ▼
CoordinateTransform.screenToMapCoordinates(offset, transformationController)
  → Applies Matrix4.inverted(currentTransform)
  → Returns point in SVG coordinate space
        │
        ▼
PathHitTest.hitTestWithSnap(mapPoint, regions, snapRadius)
  → Phase 1: AABB bounding box check (195 comparisons, O(1) each)
  → Phase 2: Path.contains() for candidates
  → If null: centroid proximity snap
  → Returns: targetIsoCode (String) or null (ocean drop, no snap target)
        │
        ▼
GameSessionNotifier.onFlagDropped(draggedIso, targetIsoCode)
  → If targetIsoCode == draggedIso: CORRECT
      → Remove from pendingIsoCodes
      → Record result in results map
      → Trigger correct haptic + audio
      → If all placed: phase = completed → navigate to ResultScreen
  → If targetIsoCode != draggedIso: INCORRECT
      → score += 5  (golf penalty)
      → Increment per-flag error count
      → If errorCount[iso] >= 3: trigger auto-hint pulse
      → Trigger incorrect haptic + audio
      → Flag stays in tray (no removal)
  → If targetIsoCode == null: no-op (dropped on ocean far from any country)
  → notifyListeners() / ref.invalidate() triggers UI rebuild
        │
        ▼
GameHudWidget rebuilds (score, progress bar)
MapViewModel updates (country fill color changes to matched/error state)
FlagCardWidget updates (matched flag fades out of tray)
```

---

## Build Order Implications

The following graph shows which components must be completed before others can be built:

```
Level 0 (No dependencies — build first):
  ├── core/models/ (Country, GameMode, GameResult)
  ├── core/utils/path_hit_test.dart
  ├── core/utils/coordinate_transform.dart
  ├── features/game/domain/scoring_service.dart
  └── assets/ (JSON data, SVG flags, map paths)

Level 1 (Depends on Level 0):
  ├── features/game/data/ (CountryDataService, CountryRepository)
  ├── features/map/data/ (MapDataService, MapRepository)
  └── features/scores/ (HighScoreService, HighScoreRepository)

Level 2 (Depends on Level 1):
  ├── features/game/domain/game_state.dart + game_session.dart
  └── features/map/domain/country_region.dart

Level 3 (Depends on Level 2):
  ├── features/game/presentation/game_session_notifier.dart
  └── features/map/presentation/map_view_model.dart

Level 4 (Depends on Level 3):
  ├── features/map/presentation/world_map_painter.dart
  ├── features/map/presentation/country_drop_target.dart
  ├── features/game/presentation/flag_card_widget.dart
  ├── features/game/presentation/game_hud_widget.dart
  └── features/ads/ (can be developed in parallel — no game logic deps)

Level 5 (Depends on Level 4):
  └── features/game/presentation/game_screen.dart  (composes all Level 4 widgets)

Level 6 (Depends on Level 5):
  ├── features/result/presentation/result_screen.dart
  ├── features/home/presentation/home_screen.dart
  └── core/routing/app_router.dart

Level 7 (Depends on Level 6):
  └── main.dart + app.dart (final assembly, AdMob init, ProviderScope)
```

**Practical implication for phased development:**

Levels 0–3 can be built and fully unit-tested with no Flutter UI at all. The game state machine,
scoring logic, and hit-testing are pure Dart. This means Phase 1 of development should target
levels 0–3 as a complete, tested core, and Phase 2 builds the rendering on top.

The `features/ads/` module can be scaffolded with no-op stubs in early phases (return
`AdLoadState.failed` always) so the rest of the app compiles and runs without a live AdMob
dependency. Replace with real implementation in the final phase before release.

---

## Anti-Patterns to Avoid

### 1. DragTarget Inside InteractiveViewer With Drag Source Also Inside

**What goes wrong:** `InteractiveViewer` and `Draggable` both want to handle pan gestures from
the same pointer. The gesture arena resolves ambiguously — sometimes the map scrolls when the
player tries to drag a flag, and vice versa.

**Prevention:** Place all drag sources (`Draggable` flag cards) outside the `InteractiveViewer`
in a separate `FlagTray` widget below the map.

### 2. Calling Path.contains() on Every Frame

**What goes wrong:** Hover effects during a drag might be implemented by testing the drag
position against all 195 paths on every `PointerMove` event. At 60fps this is 195 path tests
per frame while the player is dragging — O(n × vertices) per frame.

**Prevention:** Use `DragTarget.onWillAcceptWithDetails` for hover highlighting (Flutter only
calls this when the drag enters the widget's bounding box), not raw `GestureDetector.onPanUpdate`.
The AABB bounding box rejection in Phase 1 of `hitTest()` makes this tractable.

### 3. Storing Country Names in ARB Files

**What goes wrong:** 195 × 15 locales = 2925 ARB keys. Generated `AppLocalizations` class
becomes enormous. `flutter gen-l10n` is slow. Adding a new language requires editing a 2925-key
file. Translators have no tooling that can diff or partially translate a 3000-key ARB file
efficiently.

**Prevention:** Store country names in per-locale JSON assets as described in §7.

### 4. Showing Ads During the Pause Screen

**What goes wrong:** Players accidentally tap an ad while looking for the resume button. Parents
see an ad immediately upon pausing. Both patterns generate App Store / Play Store complaints and
violate the Google Play Families Program ad policy for child-directed apps.

**Prevention:** The `PauseOverlayWidget` is a full-screen modal with no ad slots. Banner ads are
only shown on `HomeScreen` and `ResultScreen`.

### 5. Hardcoding Coordinate Space Assumptions

**What goes wrong:** If screen coordinates are used directly as SVG coordinates (or vice versa),
the hit-testing works at scale=1.0 but breaks immediately when the player zooms in or out.

**Prevention:** All coordinate math goes through `CoordinateTransform.screenToMapCoordinates()`.
This is the single authoritative transform function, tested in isolation with known matrix values.
No direct use of `Offset` values from drag events in game logic.

### 6. Initialising AdMob After runApp

**What goes wrong:** AdMob may fire ad requests before the child-directed treatment configuration
is applied, creating a COPPA compliance window where non-child-directed ads could be requested.

**Prevention:** The call sequence in `main()` is non-negotiable:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `MobileAds.instance.updateRequestConfiguration(...)` with child-directed flags
3. `await MobileAds.instance.initialize()`
4. `runApp(...)`

### 7. No RepaintBoundary on the World Map Painter

**What goes wrong:** HUD animations (score counter incrementing, timer ticking) trigger repaints
of the entire widget tree including the `CustomPainter`, even when the map itself has not changed.

**Prevention:** Wrap `WorldMapWidget` in a `RepaintBoundary`. The map only needs to repaint when
a country changes state (matched, hovered, auto-hint pulsing). The HUD lives in a separate
subtree outside the `RepaintBoundary`.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Feature-first directory structure | HIGH | Flutter official architecture case study + Games Toolkit both use feature-first |
| GamePhase enum + Riverpod AsyncNotifier | HIGH | Standard Flutter architecture recommendation; well-documented |
| Ticker for timer | HIGH | Official Flutter recommendation over Timer.periodic for vsync-aligned updates |
| JSON asset for map data | HIGH | Standard Flutter pattern; rootBundle.loadString is stable API |
| AABB + Path.contains() hit-test | HIGH | dart:ui Path.contains() is a stable, documented API |
| CoordinateTransform via Matrix4.inverted | HIGH | TransformationController.value + MatrixUtils are documented Flutter APIs |
| Flag tray outside InteractiveViewer | HIGH | Solves gesture arena conflict definitively; documented Draggable/InteractiveViewer interaction pattern |
| DragTarget details.offset → screenToMap | MEDIUM | details.offset coordinate space (global vs local) needs empirical verification; the transform math is correct but the offset origin must be confirmed against live InteractiveViewer behaviour |
| GoRouter onExit for back button | HIGH | Official GoRouter documentation; v6+ feature |
| Two-flavor (dev/prod) configuration | HIGH | Official Flutter flavors documentation |
| ARB for UI only, JSON for country names | HIGH | Well-reasoned from first principles; consistent with STACK.md recommendation |
| RepaintBoundary on map painter | HIGH | Flutter performance best practices documentation |
| Ad isolation (no game logic imports ads) | HIGH | Architectural principle; no framework-specific risk |
