# Research Summary: Flags Around the World

**Synthesized:** 2026-05-27

---

## Stack

- **Rendering:** `flutter_svg` + `CustomPainter` + `InteractiveViewer`. Parse Natural Earth SVG once at startup via a pre-processing Python script into `world_map_paths.json`, build `dart:ui Path` objects in memory, paint via `CustomPainter`. Never re-render the full SVG map at runtime. Do NOT use `syncfusion_flutter_maps` (commercial license, wrong gesture model).
- **Flags:** 195 SVG files from `lipis/flag-icons` (MIT), bundled at `assets/flags/<iso>.svg`. Named by ISO 3166-1 alpha-2. ~1–3 MB total. Always display with `BoxFit.contain`; Nepal and Switzerland have non-4:3 aspect ratios.
- **State:** Riverpod 2.x (`flutter_riverpod` + code-gen). Timer via `Ticker` (vsync-aligned), not `Timer.periodic`. `GameSessionNotifier` is an `AsyncNotifier` owning the full `GamePhase` state machine (idle → countdown → playing → paused → completed).
- **Storage:** `shared_preferences` only. Always `await` writes. Write game state on every correct drop, not only at game-end — prevents score loss on process kill.
- **Ads:** `google_mobile_ads` ^5.x. COPPA configuration (`tagForChildDirectedTreatment=yes`, `tagForUnderAgeOfConsent=yes`, `maxAdContentRating=G`) called **before** `MobileAds.initialize()`. Each mediation SDK requires its own child-directed call — AdMob does not cascade.
- **i18n:** `flutter gen-l10n` + ARB for UI chrome strings only. Country names go in per-locale JSON assets (`countries_es.json`, etc.) loaded at runtime — putting 195 names × N locales in ARB generates thousands of keys and bloats the generated class.

---

## Table Stakes

Features whose absence generates 1-star reviews or policy violations in v1:

1. **Skippable tutorial** — skip button from frame 1. No exceptions.
2. **Forgiving drag hit detection** — snap radius ~30% of country size in SVG coordinates. Age-8 fine motor skills are limited; missed correct answers cause rage-quits.
3. **Instant correct/incorrect feedback** — visual + audio + haptic on every drop.
4. **Pause + auto-pause on backgrounding** — `WidgetsBindingObserver` freezes timer on `AppLifecycleState.paused`. Game state written to `shared_preferences` on each flag placement.
5. **Session survives app kill** — on mount, check for persisted session and offer "Continue your game?" dialog.
6. **Progress bar / flag counter in HUD** — visible at all times.
7. **Mute toggle in HUD** — persistent, respects device silent switch. Mandatory for classrooms.
8. **Non-color-only feedback** — shape + sound + color. Color-only fails colorblind users.
9. **Portrait AND landscape support** — orientation lock generates 1-star complaints.
10. **COPPA compliance** — child-directed flags set on AdMob AND each mediation SDK before init. One non-compliant ad request is a policy violation.
11. **No Firebase Analytics or Crashlytics** — both collect persistent identifiers (App Instance ID, Crashlytics UUID) prohibited for COPPA-covered apps. Exclude from day one.
12. **Ad-free pause screen** — ads on the pause screen violate Families Policy.
13. **2 free hints per session** — baseline expectation; ad-rewarded refill is the monetization hook on top of this.
14. **Stars (1–3) + personal best display** — table stakes for the educational game genre.
15. **Graceful "End Game" exit** — always accessible; no hidden exit buttons.

---

## Architecture Decisions

Three decisions constrain everything else:

**1. Flag tray outside `InteractiveViewer`; `DragTarget`s inside.**
`Draggable` and `InteractiveViewer` compete for the pan gesture when drag source is inside the viewer. Flag tray goes below the map in the widget tree. `DragTarget` overlays are children of the InteractiveViewer child so they move with zoom/pan. Drop coordinate conversion uses `TransformationController.toScene()` — NOT `RenderBox.globalToLocal()`, which is not equivalent after user zoom. This is a non-negotiable architectural commit; reversing it requires rewriting the full drag system.

**2. Map data is pre-processed JSON, not runtime-parsed SVG.**
Pipeline: Natural Earth SVG → Python script → `world_map_paths.json` (ISO code → SVG path string(s), bounding box, centroid). At startup, parse JSON once, build `dart:ui Path` objects, keep in memory. CustomPainter draws from these. `RepaintBoundary` wraps the map widget so HUD animation repaints don't touch it. Hit-testing uses two phases: AABB bounding-box rejection (O(1) × 195) then `Path.contains()` only for candidates. The Python script is a build-time dependency that must exist before map rendering work starts.

**3. Ad layer is a walled garden.**
`GameSessionNotifier` has zero imports from `features/ads/`. Coordination only at `GameScreen` widget level. The ad module stubs as `AdLoadState.failed` throughout all early phases; real implementation replaces it in the final pre-release phase. COPPA audit scope is limited to `features/ads/` and `main.dart`.

---

## Watch Out For

Ordered by severity × likelihood:

**1. Draggable/DragTarget silently breaks under InteractiveViewer transforms** (CRITICAL)
Standard Flutter drag-drop uses global screen coordinates. After user zoom/pan, DragTargets inside the transformed canvas are never hit correctly. Test drag-drop at 3× zoom on the first working prototype — it fails unless `TransformationController.toScene()` is used for coordinate conversion. Discovered late, this is a complete rewrite.

**2. `tagForChildDirectedTreatment` does NOT cascade to mediation networks** (CRITICAL)
AppLovin, Unity Ads, and Meta Audience Network each require their own child-directed SDK call. AdMob does not propagate its flag. Verify with Charles Proxy or mitmproxy before any test track submission: any outbound request containing `gaid`, `idfa`, or `advertising_id` is a violation.

**3. Firebase Analytics and Crashlytics are COPPA-prohibited** (CRITICAL)
Both collect persistent identifiers by default. Do not add `firebase_core` to `pubspec.yaml`. Use Android Vitals for aggregated crash monitoring instead.

**4. SVG map jank on mid-range Android during pinch-zoom** (HIGH)
Re-rendering 195 paths per frame on a Galaxy A-series device drops well below 30fps. Prevention: pre-built `dart:ui Path` objects + `CustomPainter` + `RepaintBoundary` + separate static/interactive layers. Profile on a mid-range device with `flutter run --profile` before shipping Phase 2.

**5. Google Play Families Program review takes 2–4 weeks and rejects for non-obvious reasons** (HIGH)
Common surprise rejections: interstitial during active gameplay, App Open ad before user can interact, ad SDK not on the current approved-network list. Allocate a 4-week pre-launch buffer. Interstitials are only permitted at natural break points (game-complete screen), never mid-round and never on app open before first interaction.

---

## Phase Order Constraints

Hard dependencies from the architecture build graph:

**Phase 1 — Core domain (no UI):** `core/models/`, `core/utils/path_hit_test.dart`, `coordinate_transform.dart`, `scoring_service.dart`, plus the Python asset pipeline producing `world_map_paths.json`. All pure Dart, fully unit-testable. The Python script is a blocking dependency — nothing else can proceed without the JSON map data.

**Phase 2 — State machines and repositories:** `GameSession` + `GamePhase`, `GameSessionNotifier` (with Ticker), `HighScoreRepository`, `CountryDataService`. Still no widgets. Complete and green in tests before writing a single widget.

**Phase 3 — Rendering and interaction:** `WorldMapPainter`, `InteractiveViewer` wrapper, `CountryDropTarget` overlays, `FlagCardWidget` (Draggable), `GameScreen` composing all. Validate coordinate transform correctness on-device at multiple zoom levels before proceeding.

**Phase 4 — Navigation shell + secondary screens:** `HomeScreen`, `ResultScreen`, `SettingsScreen`, `GoRouter` with `onExit` back-button guard, `main.dart` final assembly.

**Parallel track:** `features/ads/` as a no-op stub from Phase 1. Real AdMob implementation added only in Phase 4 / pre-release.

**Last — COPPA audit + Families Program prep:** Proxy-test all mediation network ad requests, verify interstitial timing, privacy policy legal review, production build with real AdMob IDs.

---

## Open Questions

Prototype spikes needed before committing:

1. **DragTarget offset coordinate space under `InteractiveViewer`** — Build a throwaway prototype: 5 colored Rect regions as DragTargets inside InteractiveViewer; drag a widget; log whether hit-test resolves correctly at 1×, 2×, 4× zoom. Two-hour spike. This is the single highest-risk unknown.

2. **SVG parsing approach** — Python pre-process to JSON (recommended, no runtime cost) vs. startup SVG parse (simpler tooling, higher cold-start cost). Decide before any map work begins.

3. **CustomPainter performance on mid-range device** — Measure frame time for 195-path repaint on a Galaxy A-series before committing to the rendering architecture.

4. **Grand Master distinctiveness tier ordering** — Requires human editorial judgment. Cannot be generated programmatically. Schedule as a data task, not an implementation task.

5. **Meta Audience Network inclusion** — Business decision: Meta AN adds compliance complexity for an app with COPPA coverage. Decide before the AdMob integration phase.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack choices | HIGH | All recommendations are Flutter SDK built-ins or widely-deployed packages |
| Table stakes features | HIGH | Validated across comparable apps; Families Policy is public record |
| Architecture (structure, state machine, data layer) | HIGH | Matches Flutter official case study and Games Toolkit patterns |
| Drag-drop coordinate transform | MEDIUM | Math is correct; exact `details.offset` origin needs empirical prototype verification |
| COPPA/mediation compliance | HIGH | FTC enforcement actions are public record; AdMob non-cascade is documented by Google |
| Grand Master flag ordering | LOW | Editorial judgment; not tested with children |
| Package version numbers | MEDIUM | Training data cutoff August 2025; verify all versions on pub.dev before pinning |
| Families Program review timeline | MEDIUM | 2–4 week range is reported; actual timing varies |
