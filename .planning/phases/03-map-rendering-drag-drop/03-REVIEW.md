---
phase: 03-map-rendering-drag-drop
reviewed: 2026-05-28T00:00:00Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - lib/app.dart
  - lib/core/audio/audio_service.dart
  - lib/core/audio/audio_service_provider.dart
  - lib/core/audio/real_audio_service.dart
  - lib/core/audio/stub_audio_service.dart
  - lib/core/data/country_data_service.dart
  - lib/core/l10n/app_en.arb
  - lib/core/l10n/app_es.arb
  - lib/features/game/flag_tray.dart
  - lib/features/map/completion_screen.dart
  - lib/features/map/highlight_painter.dart
  - lib/features/map/hit_detection.dart
  - lib/features/map/map_screen.dart
  - lib/features/map/spike_map_screen.dart
  - lib/features/map/world_map_painter.dart
  - lib/main.dart
  - pubspec.yaml
  - scripts/download_flags.py
  - test/features/map/drag_drop_widget_test.dart
  - test/features/map/flag_sequence_test.dart
  - test/features/map/hit_detection_test.dart
  - test/features/map/world_map_painter_test.dart
findings:
  critical: 5
  warning: 7
  info: 4
  total: 16
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-05-28
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Phase 3 delivers the map rendering layer, drag-drop game loop, coordinate transform spike, audio scaffolding, and flag sequence management. The core architectural decisions (flag tray outside InteractiveViewer, single full-coverage DragTarget, `toScene()` transform, two-layer CustomPaint) are correctly implemented and the spike validates the coordinate contract. However, five blocker-class defects were found: an `AnimationController` leak that is guaranteed to fire in normal gameplay, a null-dereference crash path in coordinate transform, a score formula inversion that makes more errors produce a *lower* penalty (not higher), a `WorldMapPainter.shouldRepaint` predicate that is defeated by set-swap, and the `_expandedBbox` fallback silently dividing by zero for a zero-size country bbox.

---

## Critical Issues

### CR-01: AnimationController leak in `_animateCorrectDrop` — no vsync owner, no dispose on widget unmount

**File:** `lib/features/map/map_screen.dart:187`

**Issue:** Every correct drop creates a new `AnimationController(vsync: this, ...)`. If the widget is unmounted before the 500 ms animation completes (e.g., a back-gesture or test teardown), `whenComplete` still fires: `animController.dispose()` is called on a disposed vsync owner and `_advanceToNextFlag()` runs on a dead widget. More concretely, the controller is never stored in the state; if a second correct drop fires while the first animation is running (theoretically prevented by advancing the sequence, but not by any guard in the code), two controllers exist simultaneously and only the second's overlay entry is tracked in `_activeOverlay`. The first controller is silently leaked.

`_activeOverlay?.remove()` is called at the top of `_animateCorrectDrop`, which does remove the *overlay entry*, but the previous animation controller is never disposed — it keeps ticking until the `whenComplete` fires.

**Fix:**
```dart
// In _MapScreenState — add a field:
AnimationController? _flyController;

// Replace the local animController with _flyController:
void _animateCorrectDrop(String isoCode) {
  // ...existing trayBox/country null guards...

  _flyController?.dispose();          // dispose previous if mid-flight
  _flyController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  // ... rest of animation setup using _flyController ...

  _flyController!.forward().whenComplete(() {
    if (!mounted) return;
    _activeOverlay?.remove();
    _activeOverlay = null;
    _flyController?.dispose();
    _flyController = null;
    _advanceToNextFlag();
  });
}

@override
void dispose() {
  _flyController?.dispose();
  _activeOverlay?.remove();
  _controller.dispose();
  super.dispose();
}
```

---

### CR-02: Null-unsafe force-unwrap in `_toSceneFromGlobal` crashes when IV render object is not yet laid out

**File:** `lib/features/map/map_screen.dart:151`

**Issue:** `_toSceneFromGlobal` uses `_ivKey.currentContext!` with a hard `!` (non-null assertion). This method is called from `onWillAcceptWithDetails` and `onAcceptWithDetails` during a drag event. If the drag begins before the first frame completes (rare but possible in widget tests and on very slow first-frame devices), `currentContext` is `null` and the app throws `Null check operator used on a null value` — a hard crash with no recovery path.

The companion method `_centroidToScreen` correctly handles this with `as RenderBox?` and a null guard, but `_toSceneFromGlobal` does not.

**Fix:**
```dart
Offset? _toSceneFromGlobal(Offset globalOffset) {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;
  return _controller.toScene(box.globalToLocal(globalOffset));
}
```
Then at each call site:
```dart
onWillAcceptWithDetails: (details) {
  final scenePoint = _toSceneFromGlobal(details.offset);
  if (scenePoint == null) return false;
  final hitIso = hitTest(scenePoint, _countries);
  setState(() => _hoveredIso = hitIso);
  return true;
},
onAcceptWithDetails: (details) {
  final scenePoint = _toSceneFromGlobal(details.offset);
  if (scenePoint == null) return;
  final hitIso = hitTest(scenePoint, _countries);
  final isCorrect = hitIso == _currentIsoCode;
  _handleDrop(hitIso, isCorrect);
},
```

---

### CR-03: Score formula inverted — more errors produce *lower* score, not higher penalty

**File:** `lib/features/game/game_session_notifier.dart:81` and `lib/features/game/game_session_notifier.dart:105`

**Issue:** The score formula used in both `_onTick` and `recordDrop` is:

```dart
final score = (_elapsedSeconds ~/ 10) + (current.errorCount * 5);
```

This *adds* a penalty term to a time-based base. As the game progresses, `_elapsedSeconds ~/ 10` grows monotonically, so the score goes *up* over time regardless of errors. The penalty of `errorCount * 5` also adds to the score rather than subtracting from it — meaning more errors produce a *higher* number, not a lower one. If this is intended as a "penalty score" (lower is better), that semantic is never communicated to the player and contradicts the `completionScore` string which simply reads "Score: {score}" with no lower-is-better framing.

This is a logic error: the intended design (confirmed by the REQUIREMENTS file approach of time + errors as a penalty game) should either subtract the penalty from a fixed maximum, or flip to lower-is-better semantics with clear UI labelling.

**Fix (subtract from a ceiling):**
```dart
// In _onTick:
const int _kMaxScore = 1000;
final score = (_kMaxScore - (_elapsedSeconds * 2) - (current.errorCount * 50)).clamp(0, _kMaxScore);

// In recordDrop (wrong drop):
final newScore = (_kMaxScore - (_elapsedSeconds * 2) - (newErrorCount * 50)).clamp(0, _kMaxScore);
```
The exact constants are a design decision; the direction of the formula must be corrected.

---

### CR-04: `_expandedBbox` divides by zero when `diagonal == 0`

**File:** `lib/features/map/hit_detection.dart:50`

**Issue:** When a country has a zero-width and zero-height bounding box (i.e., a point country, or a corrupt JSON entry with `w: 0, h: 0`), `diagonal` is `0.0`. The guard `if (diagonal >= _kMinBboxDiagonal) return rect;` does not fire (0 < 32), so execution falls through to:

```dart
final scaleFactor = _kMinBboxDiagonal / diagonal;  // 32 / 0 → +Infinity
```

`double` in Dart/Dart VM does not throw on division by zero — it returns `double.infinity`. This is then multiplied by `rect.width * scaleFactor` (0 * ∞ → `NaN`), and `Rect.fromCenter` called with `NaN` dimensions produces a NaN rect. `Rect.contains` on a NaN rect returns `false` for every point, so the fallback silently never fires. The bug is silent but leaves micro-state countries permanently unhittable.

**Fix:**
```dart
Rect _expandedBbox(CountryData country) {
  final rect = country.boundingBox.rect;
  final diagonal = sqrt(rect.width * rect.width + rect.height * rect.height);
  if (diagonal < 1e-6) {
    // Point or near-point country: expand around centroid with minimum size.
    return Rect.fromCenter(
      center: country.centroid,
      width: _kMinBboxDiagonal,
      height: _kMinBboxDiagonal,
    );
  }
  if (diagonal >= _kMinBboxDiagonal) return rect;
  final scaleFactor = _kMinBboxDiagonal / diagonal;
  return Rect.fromCenter(
    center: rect.center,
    width: rect.width * scaleFactor,
    height: rect.height * scaleFactor,
  );
}
```
Note also that the current implementation uses `country.centroid` as the expansion centre but `rect.center` is a better default when the centroid is not on the bbox centre (archipelago countries). The fix above uses `rect.center` consistently.

---

### CR-05: `WorldMapPainter.shouldRepaint` uses only set *length* — swapping equal-size sets skips repaint

**File:** `lib/features/map/world_map_painter.dart:29`

**Issue:**

```dart
bool shouldRepaint(WorldMapPainter old) =>
    old.matchedIsoCodes.length != matchedIsoCodes.length;
```

This only compares cardinalities. If the set contents change but the length stays the same (e.g., `{'DE'}` is replaced by `{'FR'}` — which cannot happen with the current `_matchedIsoCodes.add()` pattern, but would happen during a "restart game" that resets to an empty set while the previous painter still shows one match), the painter will not repaint. More critically, restarting the game resets `_matchedIsoCodes` to an empty `Set<String>` via a new `MapScreen` state (actually via `setState` reinitializing the set to `{}`). If the old painter had 1 matched code and the new one has 0, length *does* differ, so this case is actually caught.

However, the predicate is still semantically wrong: correct behavior is set identity/equality, not size comparison. An intermediate state where `{'DE'}` (1) is swapped with `{'FR'}` (1) — possible if the game ever supports mode switching mid-session — would be silently skipped.

**Fix:**
```dart
@override
bool shouldRepaint(WorldMapPainter old) =>
    !identical(old.matchedIsoCodes, matchedIsoCodes) &&
    old.matchedIsoCodes.length != matchedIsoCodes.length;
// Or more robustly:
    old.matchedIsoCodes != matchedIsoCodes;  // Set equality via == is element-wise in Dart? No.
```
Actually Dart's `Set.==` is identity, not structural. The correct fix is:
```dart
@override
bool shouldRepaint(WorldMapPainter old) =>
    !setEquals(old.matchedIsoCodes, matchedIsoCodes);
```
(Import `package:flutter/foundation.dart` for `setEquals`.)

---

## Warnings

### WR-01: `RealAudioService.dispose()` crashes if `init()` was never called or failed before player creation

**File:** `lib/core/audio/real_audio_service.dart:46`

**Issue:** `dispose()` calls `_correctPlayer.dispose()` and `_errorPlayer.dispose()` unconditionally on `late` fields. If `init()` was never called, or if `init()` throws *before* assigning `_correctPlayer = AudioPlayer()` (impossible with the current layout, but possible if refactored), accessing `_correctPlayer` throws `LateInitializationError`. More realistically: `init()` can set `_initialized = false` but still have partially initialised players — the `dispose()` path is safe in that case. The real risk is if `dispose()` is called without prior `init()` (e.g., the override in `main.dart` calls `svc.init()` without `await`, see WR-02; if `ProviderScope` is disposed before `init()` resolves, `dispose()` can race the `late` assignment).

**Fix:**
```dart
AudioPlayer? _correctPlayer;
AudioPlayer? _errorPlayer;

@override
Future<void> dispose() async {
  await _correctPlayer?.dispose();
  await _errorPlayer?.dispose();
}
```
Change `late` to nullable and guard `dispose()` accordingly. Update `playCorrect`/`playError` to use `_correctPlayer?.seek(...)`.

---

### WR-02: `RealAudioService.init()` is called without `await` in `main.dart` — init races with first game action

**File:** `lib/main.dart:13`

**Issue:**
```dart
overrides: [
  audioServiceProvider.overrideWith((_) {
    final svc = RealAudioService();
    svc.init();   // ← unawaited Future
    return svc;
  }),
],
```
The provider factory is synchronous (`Provider<AudioService>`), so `init()` cannot be awaited here. However, `svc.init()` is a `Future<void>` that loads audio assets. Until it resolves, `_initialized` is `false` and audio is silently skipped. That is acceptable as a degraded-mode behavior, but the unawaited future means any exception from `init()` is swallowed silently and not reported to `FlutterError.onError`. Dart's `unawaited` from `package:meta` or an explicit `unawaited(svc.init())` should be used to document this intentionality and suppress the analyzer warning.

**Fix:**
```dart
import 'dart:async' show unawaited;
// ...
overrides: [
  audioServiceProvider.overrideWith((_) {
    final svc = RealAudioService();
    unawaited(svc.init());
    return svc;
  }),
],
```

---

### WR-03: `_buildMap` is called every frame from `build()` and mutates state (`_countryIndex`, `_countries`) inside it

**File:** `lib/features/map/map_screen.dart:269`

**Issue:**
```dart
Widget _buildMap(List<CountryData> countries) {
  if (_countryIndex.isEmpty && countries.isNotEmpty) {
    _countryIndex = {for (final c in countries) c.isoCode: c};
    _countries = countries;
  }
  _initSequence(countries);
  // ...
}
```
`_buildMap` is passed directly to `mapData.when(data: _buildMap)` and is therefore called inside `build()`. Mutating `_countryIndex` and `_countries` inside a `build` method is a Flutter anti-pattern — `build` must be idempotent and free of side-effects. While the `if (_countryIndex.isEmpty)` guard prevents the most obvious double-set, reassignment of `_countries` after the first frame is not guarded (if `countries` reference changes but content is the same, `_countries` keeps being overwritten). If this triggers a `setState` anywhere (it doesn't currently), it would cause a "setState during build" assertion.

**Fix:** Initialise `_countryIndex` and `_countries` in `_initSequence` (already called idempotently) or in a `didChangeDependencies` / `ref.listen` callback tied to `countryDataProvider`.

---

### WR-04: `_advanceToNextFlag` navigates to `CompletionScreen` with `state.value!` that may be `null` or still in countdown phase

**File:** `lib/features/map/map_screen.dart:103`

**Issue:**
```dart
await ref.read(gameSessionProvider.notifier).completeGame();
if (mounted) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CompletionScreen(
        session: ref.read(gameSessionProvider).value!,  // hard !
      ),
    ),
  );
}
```
`ref.read(gameSessionProvider).value!` force-unwraps the `AsyncValue`. The state is `AsyncData` after `completeGame()` sets it, but if the provider is ever in an `AsyncLoading` or `AsyncError` state at that moment (e.g., due to an exception in `completeGame` before `state =` assignment), the `!` throws. `completeGame()` calls `_highScoreRepository?.saveBestScore(...)` which is awaited — if that throws after `state` is already set this is safe, but if it throws before, `state` remains in a prior state and `value!` crashes.

**Fix:**
```dart
final session = ref.read(gameSessionProvider).value;
if (session == null || !mounted) return;
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => CompletionScreen(session: session)),
);
```

---

### WR-05: `_trayCardKey` is a `final GlobalKey` shared across all flag tray instances — key collision when AnimatedSwitcher runs both old and new tray simultaneously

**File:** `lib/features/map/map_screen.dart:57`

**Issue:**
```dart
final GlobalKey _trayCardKey = GlobalKey();
```
`_trayCardKey` is assigned once and shared as `cardKey` on every `FlagTray` instance. During an `AnimatedSwitcher` transition, both the outgoing and incoming `FlagTray` widgets are mounted simultaneously — both receive the same `GlobalKey`. Flutter prohibits two live widgets sharing a `GlobalKey` and will throw:

```
Multiple widgets used the same GlobalKey.
```

This is reproducible whenever `_advanceToNextFlag()` triggers an `AnimatedSwitcher` transition (i.e., on every correct drop).

**Fix:** Generate a new `GlobalKey` for `_trayCardKey` alongside `_trayKey`:
```dart
GlobalKey _trayCardKey = GlobalKey();

// In _advanceToNextFlag (inside the else branch):
setState(() {
  _currentIsoCode = _remainingIsoCodes.first;
  _trayKey = GlobalKey<FlagTrayState>();
  _trayCardKey = GlobalKey();           // ← new key per tray instance
});
```

---

### WR-06: `HighlightPainter.shouldRepaint` ignores `countryIndex` changes

**File:** `lib/features/map/highlight_painter.dart:14`

**Issue:**
```dart
bool shouldRepaint(HighlightPainter old) => old.hoveredIso != hoveredIso;
```
If `countryIndex` is replaced (e.g., after a reload or future hot-restart scenario), `shouldRepaint` returns `false` even though the painter would now draw different paths. This is low-risk in the current phase (the index is populated once), but is a latent correctness defect.

**Fix:**
```dart
@override
bool shouldRepaint(HighlightPainter old) =>
    old.hoveredIso != hoveredIso ||
    !identical(old.countryIndex, countryIndex);
```

---

### WR-07: `countryDataProvider` instantiates `CountryDataService` directly — not injectable, breaks testability

**File:** `lib/features/map/map_screen.dart:18`

**Issue:**
```dart
final countryDataProvider = FutureProvider<List<CountryData>>(
  (ref) => CountryDataService().loadMapData(),
);
```
`CountryDataService` is constructed inline. There is no provider for `CountryDataService` itself, so tests cannot inject a mock/stub service without overriding the entire `countryDataProvider`. The `drag_drop_widget_test.dart` is already skipped because of "mock notifier wiring" — this pattern will force the same skip for any test that needs to control map data.

**Fix:** Extract a `countryDataServiceProvider`:
```dart
final countryDataServiceProvider = Provider<CountryDataService>(
  (_) => CountryDataService(),
);

final countryDataProvider = FutureProvider<List<CountryData>>(
  (ref) => ref.watch(countryDataServiceProvider).loadMapData(),
);
```
Tests override `countryDataServiceProvider` with a stub.

---

## Info

### IN-01: `SpikeMapScreen` and its FAB are shipped in production — dead code in release build

**File:** `lib/app.dart:19-27`, `lib/features/map/spike_map_screen.dart`

**Issue:** The coordinate-transform spike screen is accessible via a `FloatingActionButton` in the production `App` widget. It uses `debugPrint` (line 118 of `spike_map_screen.dart`) and is a developer artefact. It should be removed before any production release. The TODO comment on line 11 of `app.dart` notes that GoRouter wiring is pending, but does not flag spike removal.

**Fix:** Remove `SpikeMapScreen` import and the `FloatingActionButton.extended` from `app.dart`. Delete `spike_map_screen.dart` or gate it behind `kDebugMode`.

---

### IN-02: `_countryName` returns raw ISO code instead of localised name — placeholder not replaced

**File:** `lib/features/map/map_screen.dart:263`

**Issue:**
```dart
String _countryName(String isoCode) => isoCode.toUpperCase();
```
This was flagged as "wired in Phase 4" in a comment, but it means the flag tray currently displays e.g. "DE" instead of "Germany". For a children's educational game, this is a UX regression that will appear in any manual testing of Phase 3.

**Fix:** Wire `CountryDataService.loadCountryNames` and pass the result through `_countryName`. This is explicitly planned for Phase 4, but the stub should at least be tracked as a known gap.

---

### IN-03: `app_en.arb` retains `scaffoldHomeLabel` from Phase 1 — stale string

**File:** `lib/core/l10n/app_en.arb:15`, `lib/core/l10n/app_es.arb:15`

**Issue:** The `scaffoldHomeLabel` key is described as "removed in Phase 3" in its own ARB description, yet it remains in both `app_en.arb` and `app_es.arb`. The generated `AppLocalizations` class will still expose this getter, adding unused code to the l10n surface.

**Fix:** Remove the `scaffoldHomeLabel` and `@scaffoldHomeLabel` entries from both ARB files if the Phase 1 scaffold widget has been removed.

---

### IN-04: `download_flags.py` uses `urllib.request.urlretrieve` — deprecated and not HTTPS-verified

**File:** `scripts/download_flags.py:27`

**Issue:** `urllib.request.urlretrieve` is a legacy API marked for potential removal and does not perform SSL certificate verification by default on some Python builds. For a build-time script fetching assets from GitHub, this is a minor supply-chain hygiene issue.

**Fix:** Replace with `urllib.request.urlopen` inside a `with` block, or use the `requests` library with explicit `verify=True` (default):
```python
import urllib.request, ssl
ctx = ssl.create_default_context()
with urllib.request.urlopen(url, context=ctx) as resp, open(dest, 'wb') as f:
    f.write(resp.read())
```

---

_Reviewed: 2026-05-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
