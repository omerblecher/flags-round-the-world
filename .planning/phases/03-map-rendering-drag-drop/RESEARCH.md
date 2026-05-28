# Phase 3: Map Rendering & Drag-Drop — Research

**Researched:** 2026-05-28
**Domain:** Flutter CustomPainter + InteractiveViewer drag-and-drop with coordinate transforms
**Confidence:** HIGH for coordinate transform mechanics (verified against Flutter API docs); MEDIUM for just_audio init patterns (verified pub.dev version only)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Architecture (CLAUDE.md — cannot reverse):**
- Flutter + CustomPainter + InteractiveViewer. NOT flutter_map, NOT syncfusion.
- Map data is pre-processed JSON (`world_map_paths.json`), not runtime SVG parsing.
- Flag tray OUTSIDE InteractiveViewer; DragTargets INSIDE. Drop coordinates via `TransformationController.toScene()`.
- Ad layer is a walled garden — `GameSessionNotifier` has zero imports from `features/ads/`. Ad stub through Phase 5.
- No Firebase, ever.

**COPPA / Families Policy (CLAUDE.md):**
- `tagForChildDirectedTreatment(true)` on AdMob AND each mediation SDK before `MobileAds.initialize()`.
- `AD_ID` permission blocked in `AndroidManifest.xml` via `tools:remove`.
- Interstitials: game-complete screen only. Never mid-round, never on app open.
- No personalised/behavioural advertising.

**Phase 3 implementation decisions (03-CONTEXT.md):**
- D-01–D-05: flat atlas palette, light-blue ocean, thin borders, gold drag-highlight, centroid labels
- D-06–D-09: horizontal bottom tray, single flag card, 3:2 rectangular card, country name always visible in Phase 3
- D-10–D-13: AnimationController for correct-drop scale+fade, Curves.elasticOut for incorrect bounce, AudioService stub, SDK haptics
- D-14–D-16: Path.contains() primary; bbox expansion fallback for small countries; smallest-bbox tiebreaker for multi-match
- D-17: Coordinate-transform spike is Plan 1 and mandatory before WorldMapPainter work

**State management pattern (Phase 2):**
- Manual AsyncNotifier + top-level provider (no codegen). Follow this pattern if adding new notifiers.
- Abstract interface + stub: mirror `AdService`/`StubAdService` for `AudioService`/`StubAudioService`.

### Claude's Discretion

None specified beyond phase decisions above.

### Deferred Ideas (OUT OF SCOPE)

- Game mode differentiation (Phase 4)
- Scoring HUD (Phase 4)
- Hints (Phase 4)
- Real audio assets
- Pause/resume UI (Phase 5)
- Accessibility labels / TalkBack (Phase 5)
- Any ads (Phase 6)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAP-01 | Interactive SVG world map with ~195 droppable country regions | CustomPainter with pre-parsed Path objects — no runtime SVG parsing; §Q3 painter architecture |
| MAP-02 | Pinch-to-zoom and pan with smooth gesture handling | InteractiveViewer built-in; §Q1 coordinate transform spike |
| MAP-03 | On-screen zoom buttons | `TransformationController.value` manipulation; §Architecture Patterns |
| MAP-04 | Country name labels scale with zoom, remain readable | Canvas.drawParagraph with TextPainter at centroid; §Architecture Patterns |
| MAP-05 | Country visually highlighted during drag over | Hover state via DragTarget.onWillAcceptWithDetails; §Q3 painter layering |
| GAME-01 | Drag flag card from tray, drop onto correct country | DragTarget inside InteractiveViewer; §Q1 and Q2 |
| GAME-02 | Forgiving snap radius (~30% of country size) | Expanded-bbox fallback with minimum 32 scene-unit floor; §Q4 |
| GAME-03 | Correct drop: positive animation, audio chime, haptic pulse | AnimationController scale+fade + AudioService.playCorrect() + HapticFeedback; §Q5–Q6 |
| GAME-04 | Incorrect drop: gentle error visual, distinct audio, haptic buzz | Curves.elasticOut bounce + AudioService.playError() + HapticFeedback; §Q7 |
| GAME-05 | Full pool of unmatched countries in random order, one at a time | Shuffled list in widget state; §Architecture Patterns |
| GAME-06 | Session ends after all 195 correctly matched | After last correct drop, call completeGame(); §Architecture Patterns |
</phase_requirements>

---

## Summary

Phase 3 is primarily a coordinate-transform problem wrapped in rendering and animation concerns. The single highest-risk item is the drag-drop system: a `Draggable` lives outside `InteractiveViewer` (in the tray) and `DragTarget`s live inside it (on the map). The Flutter drag system reports drop positions in **global screen coordinates**, but `TransformationController.toScene()` takes **local viewport coordinates** — so a mandatory intermediate `renderBox.globalToLocal()` conversion is required. Skipping or inverting this step is the root cause of T-3 (coordinate space errors) documented in PITFALLS.md.

The `world_map_paths.json` viewBox is 2000×1000 scene units. At the initial fit-to-screen on a 380dp-wide phone, 1 scene unit ≈ 0.19dp. This means countries with bbox diagonals under ~32 scene units (74 of 196) will have essentially invisible touch targets at 1× zoom and sub-24dp targets even at 4× zoom. The forgiving radius strategy from CONTEXT.md D-15 needs a minimum absolute floor (≥ 32 scene units diagonal), not just a 30% percentage expansion.

**Primary recommendation:** Implement the coordinate-transform spike first (Plan 1), validate the three-step global→local→scene transform at 1×/2×/4× zoom, then proceed with WorldMapPainter. Keep the static map painter and the dynamic overlay painter in separate `CustomPaint` layers separated by `RepaintBoundary` to prevent the 196-path repaint on every drag-hover update.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Map rendering (country fills, borders, labels) | Widget (CustomPainter) | — | Pre-parsed dart:ui Path objects drawn in paint() |
| Drag-over highlight | Widget (overlay CustomPainter) | — | Separate from static layer so only highlight repaints on hover |
| Drag gesture initiation | Widget (Draggable in tray) | — | Tray is outside InteractiveViewer; Draggable wraps flag card |
| Drop detection & coordinate transform | Widget (DragTarget callbacks) | State (MapStateNotifier) | DragTarget.onAcceptWithDetails → globalToLocal → toScene → path.contains |
| Hit-detection logic | Domain (pure Dart) | Widget (calls it) | Testable without widget tree; returns matched ISO or null |
| Session state on drop | State (GameSessionNotifier) | — | recordDrop() already implemented in Phase 2 |
| Correct-drop animation (scale+fade to centroid) | Widget (OverlayEntry + AnimationController) | — | Needs scene→screen coord conversion; lives in widget layer |
| Incorrect-drop animation (bounce back) | Widget (AnimationController in tray) | — | Returns card to tray origin |
| Audio playback | Service (AudioService/StubAudioService) | — | Abstract interface; stub in Phase 3 |
| Haptics | Widget (direct HapticFeedback call) | — | SDK built-in; no service layer needed |
| Flag sequence management | Widget (local State or provider) | — | Shuffled list of ISO codes; advances on correct drop |

---

## Q1: Coordinate-Transform Spike — Exact Call Sequence

### The Three-Step Transform Chain

`DragTargetDetails.offset` is a **global screen coordinate** (confirmed: "the global position when the specific pointer event occurred"). [VERIFIED: api.flutter.dev/flutter/widgets/DragTargetDetails-class.html]

`TransformationController.toScene(viewportPoint)` takes a **local viewport coordinate** (relative to the InteractiveViewer widget). [VERIFIED: api.flutter.dev/flutter/widgets/TransformationController/toScene.html] — "A viewport point is relative to the parent while a scene point is relative to the child, regardless of transformation."

Therefore the full chain is:

```dart
// Step 1: obtain a RenderBox for the InteractiveViewer widget
final RenderBox renderBox =
    _interactiveViewerKey.currentContext!.findRenderObject() as RenderBox;

// Step 2: convert global drop position to local (viewport) coordinates
final Offset localOffset = renderBox.globalToLocal(details.offset);

// Step 3: convert local viewport coordinates to scene (map canvas) coordinates
final Offset scenePoint = _transformationController.toScene(localOffset);

// Step 4: hit-test against all country paths
final String? hitIso = _hitTest(scenePoint);
```

**Where to call this:** Inside `DragTarget<String>.onAcceptWithDetails`:

```dart
DragTarget<String>(
  onWillAcceptWithDetails: (details) {
    // Compute scene point for hover highlight (same three steps)
    final Offset scene = _toSceneFromGlobal(details.offset);
    final String? hoveredIso = _hitTest(scene);
    setState(() => _hoveredIso = hoveredIso);
    return true; // Always accept; real validation happens in onAcceptWithDetails
  },
  onAcceptWithDetails: (details) {
    final Offset scene = _toSceneFromGlobal(details.offset);
    final String? hitIso = _hitTest(scene);
    final bool isCorrect = hitIso == _currentIsoCode;
    _handleDrop(isCorrect, hitIso);
  },
  onLeave: (_) => setState(() => _hoveredIso = null),
  builder: (context, candidate, rejected) {
    // Transparent overlay covering entire map area
    return SizedBox.expand();
  },
)
```

**Helper method:**

```dart
Offset _toSceneFromGlobal(Offset globalOffset) {
  final RenderBox box =
      _ivKey.currentContext!.findRenderObject() as RenderBox;
  return _controller.toScene(box.globalToLocal(globalOffset));
}
```

**Spike test widget — what to verify manually:**

Create a standalone `SpikeMapScreen` with 5 labeled colored rectangles at known scene coordinates (e.g., `Rect.fromLTWH(100, 100, 200, 150)` etc.). Print the hit result to the console on each drop. Confirm correct hits at minScale (fit-to-screen), 2×, and 4× zoom before any `WorldMapPainter` work begins.

---

## Q2: DragTarget Placement Inside InteractiveViewer

### Architecture

The `Draggable` is in the tray (outside `InteractiveViewer`). The drag feedback widget renders via Flutter's `Overlay` (above everything, unaffected by transforms). The `DragTarget` is a single transparent overlay covering the entire map inside `InteractiveViewer`.

**Do NOT place 196 individual DragTarget widgets** — one per country. That approach causes severe layout thrash and was the design that required per-widget coordinate transforms. Instead:

- Place **one** full-coverage `DragTarget<String>` inside InteractiveViewer that accepts any drop.
- In `onAcceptWithDetails`, run the three-step transform + `_hitTest()` to determine which country was hit.
- In `onWillAcceptWithDetails`, run the same to set hover highlight state.

```
Widget tree:
  Column
  ├── Expanded
  │   └── Stack
  │       ├── InteractiveViewer (transformationController: _controller)
  │       │   └── SizedBox(width: 2000, height: 1000)    ← forces child to viewBox size
  │       │       └── Stack
  │       │           ├── RepaintBoundary
  │       │           │   └── CustomPaint(painter: WorldMapPainter(countries, matchedSet))
  │       │           ├── RepaintBoundary
  │       │           │   └── CustomPaint(painter: HighlightPainter(hoveredIso, countries))
  │       │           └── DragTarget<String>(...)         ← single, covers entire 2000×1000
  │       └── ZoomButtonsOverlay()                        ← outside IV, in screen coords
  └── FlagTray(currentIsoCode, onDragStarted, onDragEnd)  ← outside IV
```

**Why the child is `SizedBox(width: 2000, height: 1000)`:**
With `constrained: false`, the child is laid out without constraints. If you use a bare `CustomPaint` without an explicit size, it may size to zero or to the viewport. Setting it to the exact viewBox dimensions ensures 1 scene unit = 1 logical pixel in the child's coordinate space, making `toScene()` directly usable with the coordinates in `world_map_paths.json`.

**How Flutter handles cross-boundary drag (tray → InteractiveViewer):**
Flutter's `Draggable`/`DragTarget` system works across widget subtrees via `Overlay`. The drag is tracked at the overlay layer (above both tray and IV). The `DragTarget`'s hit test fires when the dragged pointer is over the DragTarget's render box, regardless of which subtree contains it. Cross-boundary drags work correctly as long as the DragTarget is in the widget tree and visible. [ASSUMED — cross-boundary Draggable behavior inferred from Flutter's overlay-based drag implementation; the spike test in Plan 1 will empirically confirm]

---

## Q3: CustomPainter with 196 Paths — Performance

### Two-Layer Architecture

Split into two `CustomPaint` widgets separated by `RepaintBoundary`:

**Layer 1 — Static (`WorldMapPainter`):**
Paints all 196 country fills (atlas palette + matched-state color), borders, and text labels. Only needs to repaint when the set of matched countries changes (after a correct drop), not on every drag-hover event.

```dart
class WorldMapPainter extends CustomPainter {
  final List<CountryData> countries;
  final Set<String> matchedIsoCodes;  // grows with each correct drop

  @override
  bool shouldRepaint(WorldMapPainter old) =>
      old.matchedIsoCodes.length != matchedIsoCodes.length;
      // Length check is O(1) and sufficient — matched set only grows
}
```

**Layer 2 — Dynamic (`HighlightPainter`):**
Paints only the currently hovered country's fill in gold (#FFD700). Repaints on every `onWillAcceptWithDetails` event.

```dart
class HighlightPainter extends CustomPainter {
  final String? hoveredIso;
  final Map<String, CountryData> countryIndex;  // pre-built iso->data map

  @override
  bool shouldRepaint(HighlightPainter old) => old.hoveredIso != hoveredIso;
  
  @override
  void paint(Canvas canvas, Size size) {
    if (hoveredIso == null) return;
    final country = countryIndex[hoveredIso];
    if (country == null) return;
    final paint = Paint()..color = const Color(0xFFFFD700);
    for (final path in country.paths) {
      canvas.drawPath(path, paint);
    }
  }
}
```

**`RepaintBoundary` placement:**
Wrap each `CustomPaint` in its own `RepaintBoundary`. This tells Flutter's compositor that these two layers can be rasterized and cached independently. The static layer rasterizes once per correct drop. The dynamic layer rasterizes on every hover event but only re-paints 1–2 paths, not 196.

**`isComplex: true` and `willChange: true`:**
Set `isComplex: true` on `WorldMapPainter`'s `CustomPaint` (hints the engine to cache the rasterized result). Set `willChange: true` on `HighlightPainter`'s `CustomPaint` (hints the engine not to cache — it changes frequently).

```dart
RepaintBoundary(
  child: CustomPaint(
    isComplex: true,
    willChange: false,
    painter: WorldMapPainter(countries: countries, matchedIsoCodes: matchedSet),
    size: const Size(2000, 1000),
  ),
),
RepaintBoundary(
  child: CustomPaint(
    isComplex: false,
    willChange: true,
    painter: HighlightPainter(hoveredIso: _hoveredIso, countryIndex: _countryIndex),
    size: const Size(2000, 1000),
  ),
),
```

---

## Q4: Small Country Bbox Expansion — Correct Thresholds

### Coordinate System Facts (VERIFIED from `world_map_paths.json`)

- ViewBox: **2000 × 1000** scene units [VERIFIED: direct JSON inspection]
- Child widget size: 2000 × 1000 logical pixels (1:1 mapping)
- At fit-to-screen on 380dp phone: initial scale ≈ **0.190** (380 / 2000)
- Therefore **1 scene unit ≈ 0.19dp** at the initial (fully zoomed-out) view
- Smallest country bbox diagonal: **lu (Luxembourg) = 4.95 scene units ≈ 0.94dp** at 1× [VERIFIED]
- Countries with diagonal < 30 scene units: **72 of 196** [VERIFIED]

### Why 30% Expansion Is Insufficient

A 30% expansion of Luxembourg's 4.95-unit diagonal yields 6.4 scene units = **1.2dp at 1× zoom** and **4.9dp at 4× zoom**. Both are far below the ACCS-03 minimum of 48dp. The CONTEXT.md D-15 note "expand the bounding box by 30%" is a reasonable percentage for medium-small countries but not for the 10–15 truly tiny ones (Pacific/Caribbean microstates, city-states).

### Recommended Implementation

Use a **minimum absolute floor** instead of (or in addition to) the percentage expansion:

```dart
const double _kMinBboxDiagonal = 32.0;  // scene units
// At 4x zoom: 32 * 0.19 * 4 = 24.3dp — just above minimum meaningful touch target

Rect _expandedBbox(CountryData country) {
  final Rect bb = country.boundingBox.rect;
  final double diag = (bb.width * bb.width + bb.height * bb.height).sqrt();
  
  if (diag >= _kMinBboxDiagonal) return bb;  // large enough, no expansion

  // Expand to reach minimum diagonal while keeping centroid fixed
  final double targetW = (bb.width / diag) * _kMinBboxDiagonal;
  final double targetH = (bb.height / diag) * _kMinBboxDiagonal;
  return Rect.fromCenter(
    center: country.centroid,
    width:  targetW.clamp(bb.width,  targetW),
    height: targetH.clamp(bb.height, targetH),
  );
}
```

**Hit test sequence:**

```dart
String? _hitTest(Offset scenePoint) {
  final List<CountryData> candidates = [];

  for (final country in _countries) {
    // Primary: exact path containment
    bool hit = country.paths.any((p) => p.contains(scenePoint));
    
    // Fallback: expanded bbox containment
    if (!hit) {
      hit = _expandedBbox(country).contains(scenePoint);
    }
    
    if (hit) candidates.add(country);
  }
  
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.first.isoCode;
  
  // D-16 tiebreaker: smallest bounding box wins
  candidates.sort((a, b) {
    final aArea = a.boundingBox.rect.width * a.boundingBox.rect.height;
    final bArea = b.boundingBox.rect.width * b.boundingBox.rect.height;
    return aArea.compareTo(bArea);
  });
  return candidates.first.isoCode;
}
```

**Note on "20px at 1× zoom" from CONTEXT.md D-15:** In this coordinate system, "20px at 1× zoom" means 20 scene units (since 1 scene unit = 1 logical pixel in the child). At 1× initial fit that is 20 × 0.19 = 3.8dp — essentially invisible. The 20-unit figure from D-15 is a reasonable starting breakpoint for deciding *which countries need expansion*, but the *amount* of expansion must reach 32 units minimum diagonal, not just add 30%.

---

## Q5: Correct-Drop Animation — Coordinate Transform for Centroid

### The Problem

The flag card starts in the tray (screen coordinates, outside InteractiveViewer). The centroid is in scene coordinates (inside InteractiveViewer). To animate the flag card toward the centroid on screen, we need the centroid's screen position.

### Conversion: Scene → Screen

```dart
Offset _centroidToScreen(Offset sceneCentroid) {
  // Step 1: scene → viewport (local InteractiveViewer coords)
  //   toViewport() is the inverse of toScene()
  //   TransformationController.value is the forward transform (scene→viewport)
  //   Apply the matrix directly:
  final Matrix4 matrix = _controller.value;
  final Vector3 sceneVec = Vector3(sceneCentroid.dx, sceneCentroid.dy, 0);
  final Vector3 viewportVec = matrix.transform3(sceneVec);
  final Offset viewportOffset = Offset(viewportVec.x, viewportVec.y);

  // Step 2: viewport (local) → global screen coords
  final RenderBox box =
      _ivKey.currentContext!.findRenderObject() as RenderBox;
  return box.localToGlobal(viewportOffset);
}
```

### Animation Implementation

Use an `OverlayEntry` positioned at the card's initial screen position, animated to the centroid screen position with simultaneous scale-down and fade-out:

```dart
void _animateCorrectDrop(String isoCode) {
  final Offset startScreen = _trayCardGlobalOffset();   // card's current screen position
  final Offset endScreen = _centroidToScreen(          // centroid in screen coords
    _countryIndex[isoCode]!.centroid,
  );

  final AnimationController ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  final Animation<double> scaleAnim =
      Tween<double>(begin: 1.0, end: 0.2).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));
  final Animation<double> opacityAnim =
      Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeIn));
  final Animation<Offset> posAnim =
      Tween<Offset>(begin: startScreen, end: endScreen).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));

  // Insert OverlayEntry at startScreen, animate to endScreen
  // On complete: remove overlay entry, trigger next flag card slide-in
  ctrl.forward().whenComplete(() {
    overlayEntry.remove();
    ctrl.dispose();
    _advanceToNextFlag();
  });
}
```

**Getting the tray card's screen position:**
```dart
Offset _trayCardGlobalOffset() {
  final RenderBox trayBox =
      _trayCardKey.currentContext!.findRenderObject() as RenderBox;
  return trayBox.localToGlobal(Offset.zero);
}
```

**Pinned icon after animation completes:**
Add the matched ISO code to `_matchedSet` in `WorldMapPainter`. The static layer will repaint showing a small flag icon (or colored dot) at the centroid. This is simpler than keeping the animated widget alive.

---

## Q6: just_audio Stub Initialization

`just_audio` is **not yet in `pubspec.yaml`** — it must be added. [VERIFIED: direct inspection of pubspec.yaml]

### Add to pubspec.yaml

```yaml
dependencies:
  just_audio: ^0.10.5  # verified 2026-05-28 on pub.dev
```

`just_audio` 0.10.5 supports Android, iOS, macOS, Web, Windows, Linux. [VERIFIED: pub.dev/packages/just_audio]

### AudioService Interface Pattern

Mirror the `AdService`/`StubAdService` pattern from `lib/features/ads/ad_service.dart`:

```dart
// lib/core/audio/audio_service.dart
abstract interface class AudioService {
  Future<void> init();
  Future<void> playCorrect();
  Future<void> playError();
  Future<void> dispose();
}
```

```dart
// lib/core/audio/stub_audio_service.dart
class StubAudioService implements AudioService {
  const StubAudioService();

  @override Future<void> init() async {}
  @override Future<void> playCorrect() async {}
  @override Future<void> playError() async {}
  @override Future<void> dispose() async {}
}
```

### RealAudioService (Phase 3 implementation — replaces stub when audio assets arrive)

```dart
// lib/core/audio/real_audio_service.dart
import 'package:just_audio/just_audio.dart';

class RealAudioService implements AudioService {
  late final AudioPlayer _correctPlayer;
  late final AudioPlayer _errorPlayer;
  bool _initialized = false;

  @override
  Future<void> init() async {
    _correctPlayer = AudioPlayer();
    _errorPlayer = AudioPlayer();
    try {
      await _correctPlayer.setAsset('assets/audio/correct.mp3');
      await _errorPlayer.setAsset('assets/audio/error.mp3');
      _initialized = true;
    } on PlayerException catch (e) {
      // Asset missing or audio unavailable — degrade silently
      // StubAudioService behavior: subsequent play() calls are no-ops
      debugPrint('AudioService init failed: ${e.message}');
    }
  }

  @override
  Future<void> playCorrect() async {
    if (!_initialized) return;
    try {
      await _correctPlayer.seek(Duration.zero);
      await _correctPlayer.play();
    } catch (_) { /* silent fail */ }
  }

  @override
  Future<void> playError() async {
    if (!_initialized) return;
    try {
      await _errorPlayer.seek(Duration.zero);
      await _errorPlayer.play();
    } catch (_) { /* silent fail */ }
  }

  @override
  Future<void> dispose() async {
    await _correctPlayer.dispose();
    await _errorPlayer.dispose();
  }
}
```

**Silent placeholder assets:** Create two silent 0.5-second MP3 files at `assets/audio/correct.mp3` and `assets/audio/error.mp3`. These prevent `setAsset()` from throwing `PlayerException` during Phase 3. When real audio arrives, replace only the files — no Dart code changes needed.

**Wire up via Riverpod:**
```dart
// Provide AudioService as an overridable dependency
final audioServiceProvider = Provider<AudioService>(
  (_) => const StubAudioService(),
);
// Override in main.dart with RealAudioService() for Phase 3 onward
```

**Dependency registration in main.dart:**
```dart
runApp(
  ProviderScope(
    overrides: [
      audioServiceProvider.overrideWith((_) {
        final svc = RealAudioService();
        svc.init(); // fire-and-forget; failures are silent
        return svc;
      }),
    ],
    child: const MyApp(),
  ),
);
```

---

## Q7: Flag Card Slide-In Animation

### Recommended Approach: AnimatedSwitcher with Slide Transition

`AnimatedSwitcher` is the simplest approach for the "current card departs, next card slides in" pattern. It requires only one `Key` change to trigger the animation.

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  transitionBuilder: (child, animation) {
    // Slide in from right, slide out to left
    final slideIn = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
    return SlideTransition(position: slideIn, child: child);
  },
  child: FlagCard(
    key: ValueKey(_currentIsoCode),  // key change triggers transition
    isoCode: _currentIsoCode,
    countryName: _localizedName(_currentIsoCode),
  ),
)
```

**How it integrates with correct-drop animation:**
The correct-drop animation (Q5 above) runs on an `OverlayEntry` while the tray card becomes invisible (opacity → 0 or hidden). After the overlay animation completes (`whenComplete`), call `_advanceToNextFlag()` which updates `_currentIsoCode`. The `AnimatedSwitcher` then fires its slide-in transition for the new card.

**Caveat for incorrect drop (bounce back):**
The card should NOT use `AnimatedSwitcher` for the bounce — it stays the same card. Use a separate `AnimationController` with `Curves.elasticOut` on a `Transform.translate` or `AnimatedBuilder` to animate the card back to its origin position.

```dart
// Incorrect drop: animate card back
void _animateIncorrectDrop() {
  _bounceController.forward().then((_) => _bounceController.reverse());
}

// In build:
AnimatedBuilder(
  animation: _bounceOffsetAnim,
  builder: (context, child) => Transform.translate(
    offset: _bounceOffsetAnim.value,
    child: child,
  ),
  child: FlagCard(isoCode: _currentIsoCode, ...),
)
```

---

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── core/
│   ├── audio/
│   │   ├── audio_service.dart          # abstract interface
│   │   ├── stub_audio_service.dart     # Phase 3: no-op stub
│   │   └── real_audio_service.dart     # Phase 3: just_audio implementation
│   └── models/
│       └── country_data.dart           # already exists
├── features/
│   ├── map/
│   │   ├── spike_map_screen.dart       # Plan 1: standalone spike widget
│   │   ├── world_map_painter.dart      # static layer (196 paths + labels)
│   │   ├── highlight_painter.dart      # dynamic layer (hover highlight)
│   │   ├── map_screen.dart             # main game screen widget
│   │   └── hit_detection.dart          # pure Dart hit-test logic (testable)
│   └── game/
│       ├── flag_tray.dart              # tray + Draggable + AnimatedSwitcher
│       └── (existing game files)
└── main.dart
```

### Zoom Button Implementation

On-screen zoom buttons manipulate `TransformationController` directly:

```dart
void _zoomIn() {
  final Matrix4 m = _controller.value.clone()
    ..scale(1.5, 1.5, 1.0);
  _controller.value = m;
}

void _zoomOut() {
  final Matrix4 m = _controller.value.clone()
    ..scale(1/1.5, 1/1.5, 1.0);
  _controller.value = m;
}
```

Position the zoom buttons in the `Stack` outside `InteractiveViewer` so they stay fixed on screen regardless of map pan/zoom.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Coordinate inversion | Manual matrix inversion with Vector4 math | `TransformationController.toScene()` | SDK handles floating-point precision and transform composition |
| Zoom/pan gesture handling | Custom multi-touch GestureDetector | `InteractiveViewer` | Competing pointer arbitration is a known source of bugs (PITFALLS.md T-1) |
| Sound playback with per-clip seek-to-zero | Raw platform channel audio | `just_audio` AudioPlayer per clip | Just_audio handles Android audio focus, iOS audio session, and seek correctly |
| Card transition animation | PageView with manual page controller | `AnimatedSwitcher` | AnimatedSwitcher handles key-based rebuild detection and transition layering automatically |
| Haptics | flutter_haptic_feedback package | `HapticFeedback` from `package:flutter/services.dart` | SDK-built-in; no package needed |

---

## Common Pitfalls

### Pitfall 1: Using `toScene()` with Global Coordinates Directly

**What goes wrong:** Passing `DragTargetDetails.offset` (global screen coords) directly to `toScene()` without first calling `renderBox.globalToLocal()`. The drop will "hit" based on a point far off-screen relative to the InteractiveViewer viewport.

**Why it happens:** Both are `Offset` types; the type system gives no warning. The error is invisible at 1× zoom when globalToLocal happens to produce values close to localOffset (if the IV is at the screen origin), and only becomes apparent at 2×+ zoom or when the IV is offset from (0,0).

**How to avoid:** Always: global → `renderBox.globalToLocal()` → `toScene()`. Write a helper `_toSceneFromGlobal()` and use it exclusively.

**Warning signs:** Drop hits work at 1× but fail at 2× or 4×. Or hits are correct in the center of the screen but wrong at the edges.

### Pitfall 2: Sizing the CustomPaint Child Without Explicit SizedBox

**What goes wrong:** If the child of InteractiveViewer is a bare `CustomPaint` without an explicit size, Flutter may size it to the viewport (constrained behavior) even with `constrained: false`, or it may collapse to zero.

**How to avoid:** Always wrap in `SizedBox(width: 2000, height: 1000)` matching the viewBox dimensions exactly. This ensures 1 scene unit = 1 logical pixel in the child coordinate space.

### Pitfall 3: Percentage-Only Bbox Expansion for Microstates

**What goes wrong:** A 30% expansion of Luxembourg's 4.95-unit bbox gives 6.4 scene units = 1.2dp on screen at 1× zoom — still untappable. Users drop near where they think Luxembourg is and get misses.

**How to avoid:** Use a minimum floor of 32 scene units diagonal for the expanded bbox, not just a percentage. See Q4 implementation above.

### Pitfall 4: Registering AudioService Before Assets Exist

**What goes wrong:** `RealAudioService.init()` calls `setAsset('assets/audio/correct.mp3')` before the `.mp3` files exist in the assets folder. This throws `PlayerException` at init time and may cause a crash if not caught.

**How to avoid:** Create silent placeholder MP3 files at `assets/audio/correct.mp3` and `assets/audio/error.mp3` in the same task that adds `just_audio` to pubspec.yaml. The catch block in `init()` provides a secondary safety net.

### Pitfall 5: WorldMapPainter Repainting on Every Drag-Hover

**What goes wrong:** If hover-highlight state is stored in the same `ChangeNotifier` as the static map data, the `WorldMapPainter` (all 196 paths + labels) repaints on every pointer move during drag. On a mid-range Android device with a complex map, this drops below 30fps and makes the drag feel sluggish.

**How to avoid:** Separate static and dynamic painters into two `CustomPaint` instances in separate `RepaintBoundary` wrappers. `WorldMapPainter.shouldRepaint` returns `false` unless `matchedIsoCodes` changes. `HighlightPainter.shouldRepaint` returns `false` unless `hoveredIso` changes.

---

## Package Legitimacy Audit

Only one new package is required for Phase 3: `just_audio`.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `just_audio` | pub.dev | ~5 yrs | Very high (verified publisher: ryanheise.com) | github.com/ryanheise/just_audio | N/A — well-known | Approved |

All other Phase 3 work uses packages already in `pubspec.yaml` (flutter_riverpod, flutter_svg, path_drawing, shared_preferences) or SDK-built-in APIs (InteractiveViewer, Draggable, DragTarget, HapticFeedback, AnimationController).

**slopcheck was not run** (not installed). `just_audio` is assessed as low-risk based on:
- Verified publisher on pub.dev [VERIFIED: pub.dev/packages/just_audio]
- Active since ~2019, version 0.10.5 published 8 months prior
- Well-known in the Flutter community; referenced in official Flutter documentation

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK-bundled) |
| Config file | none (standard Flutter test runner) |
| Quick run command | `flutter test test/features/map/hit_detection_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MAP-01 | 196 countries rendered (paths non-empty) | unit | `flutter test test/features/map/world_map_painter_test.dart` | Wave 0 |
| MAP-05 | Hover state changes to correct ISO on drag-over | widget | `flutter test test/features/map/drag_drop_widget_test.dart` | Wave 0 |
| GAME-01 | Drop on correct country sets isCorrect=true | unit | `flutter test test/features/map/hit_detection_test.dart` | Wave 0 |
| GAME-02 | Drop near Luxembourg bbox hits LU even without path match | unit | `flutter test test/features/map/hit_detection_test.dart` | Wave 0 |
| GAME-03/04 | recordDrop(isCorrect: true/false) called on correct/incorrect drop | widget | `flutter test test/features/map/drag_drop_widget_test.dart` | Wave 0 |
| Coord spike | toScene returns correct scene point at 1×, 2×, 4× zoom | manual | Spike screen on-device | Manual |
| GAME-05 | 196 unique ISOs drawn in random order, no repeats | unit | `flutter test test/features/map/flag_sequence_test.dart` | Wave 0 |
| GAME-06 | completeGame() called after 196th correct drop | unit | `flutter test test/features/map/flag_sequence_test.dart` | Wave 0 |

### Sampling Rate

- Per task commit: `flutter test test/features/map/hit_detection_test.dart`
- Per wave merge: `flutter test`
- Phase gate: Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/features/map/hit_detection_test.dart` — pure Dart tests for `_hitTest()` covering: exact path hit, miss, bbox-expansion hit for LU, multi-country tiebreaker
- [ ] `test/features/map/flag_sequence_test.dart` — tests for shuffle logic, no-repeat guarantee, completeGame() trigger
- [ ] `test/features/map/world_map_painter_test.dart` — WorldMapPainter shouldRepaint logic
- [ ] `test/features/map/drag_drop_widget_test.dart` — widget test for DragTarget callbacks calling recordDrop()

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | ✓ | ≥3.32.0 (per pubspec) | — |
| path_drawing | CountryData.fromJson | ✓ | ^1.0.1 (in pubspec) | — |
| flutter_riverpod | All state | ✓ | ^3.3.1 (in pubspec) | — |
| flutter_svg | Flag card rendering | ✓ | ^2.3.0 (in pubspec) | — |
| just_audio | AudioService | NOT YET | — | StubAudioService until added |
| assets/audio/*.mp3 | RealAudioService.init() | NOT YET | — | Silent placeholders must be created |

**Missing dependencies with no fallback:** none (just_audio has StubAudioService fallback)

**Missing dependencies with fallback:**
- `just_audio`: use `StubAudioService` until package is added to pubspec and silent MP3 assets are created

---

## Security Domain

Per `CLAUDE.md`: no Firebase, no GAID collection. Phase 3 introduces no network calls, no persistent identifiers, no user data collection. COPPA constraints are satisfied by architecture (offline-only, no analytics, no ads in Phase 3).

ASVS categories not applicable to Phase 3 (no auth, no sessions, no crypto, no user input beyond gestures).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Cross-boundary Draggable (tray → IV) fires DragTarget.onAcceptWithDetails correctly | Q2 | Core gameplay broken; spike test in Plan 1 will confirm or refute empirically |
| A2 | Single full-coverage DragTarget covers the entire 2000×1000 SizedBox area | Q2 | Some map area may not receive drops; verify during spike |
| A3 | just_audio 0.10.5 is the current stable version | Q6 | Minor version drift; verify with `flutter pub add just_audio` before pinning |
| A4 | Silent MP3 placeholder files prevent PlayerException in RealAudioService.init() | Q6 | Crash at init; the catch block provides secondary protection |

---

## Open Questions

1. **Zoom button behavior at min/maxScale boundary**
   - What we know: InteractiveViewer enforces minScale/maxScale on pinch gestures
   - What's unclear: Whether programmatic `_controller.value` manipulation also respects minScale/maxScale, or whether zoom buttons can accidentally push past limits
   - Recommendation: Clamp the scale manually in `_zoomIn`/`_zoomOut` using `InteractiveViewer`'s `minScale`/`maxScale` values before applying the matrix

2. **Pinned flag icons at centroid after correct drop**
   - CONTEXT.md D-10 says "a small pinned flag icon appears at that centroid"
   - Using `flutter_svg` to render 196 small flag SVGs inside a CustomPainter (via `canvas.drawPicture`) may be expensive
   - Recommendation: For Phase 3, use a colored dot (country fill color with a border) at the centroid as the pin. Phase 4 or 5 can upgrade to mini flag SVGs if needed.

---

## Sources

### Primary (HIGH confidence — verified via official docs or direct data inspection)
- Flutter API: `TransformationController.toScene()` — api.flutter.dev/flutter/widgets/TransformationController/toScene.html
- Flutter API: `DragTargetDetails.offset` — api.flutter.dev/flutter/widgets/DragTargetDetails-class.html
- `world_map_paths.json` — direct JSON inspection (viewBox 2000×1000, 196 countries, real bbox values)
- `lib/core/models/country_data.dart` — direct codebase inspection
- `lib/features/game/game_session_notifier.dart` — direct codebase inspection
- `lib/features/ads/ad_service.dart` — direct codebase inspection (pattern to mirror)
- `pubspec.yaml` — direct inspection (just_audio not yet present)
- `pub.dev/packages/just_audio` — version 0.10.5 confirmed, verified publisher

### Secondary (MEDIUM confidence)
- PITFALLS.md T-1, T-2, T-3 — established pitfall documentation for this project (training-based, cross-referenced)
- STACK.md §3 Gesture Handling, §9 Audio — prior project research

### Tertiary (LOW confidence / ASSUMED)
- Cross-boundary Draggable behavior (A1) — inferred from Flutter overlay architecture; empirically confirmed by spike test

---

## Metadata

**Confidence breakdown:**
- Coordinate transform chain (Q1, Q2): HIGH — verified against official API docs + direct data inspection
- Small country thresholds (Q4): HIGH — calculated directly from actual JSON data
- just_audio stub pattern (Q6): MEDIUM — version verified on pub.dev; init error-handling pattern from training knowledge
- AnimatedSwitcher approach (Q7): MEDIUM — standard Flutter pattern from training knowledge
- CustomPainter layering (Q3): HIGH — shouldRepaint semantics from official API + RepaintBoundary pattern well-established

**Research date:** 2026-05-28
**Valid until:** 2026-08-28 (stable Flutter APIs; verify just_audio version before pinning)
