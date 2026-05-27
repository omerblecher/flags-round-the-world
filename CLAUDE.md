# Flags Around the World — Project Guide

## What We're Building

A cross-platform educational mobile game (Flutter/Dart) where players drag-and-drop national flags onto an interactive world map. Targets ages 8+. Fully COPPA-compliant, Google Play Families Policy-compliant, fully offline. Android first; iOS is a first-class build target from day one.

**Package:** `com.otis.brooke.flags.around.the.world`
**Repo:** `flags-round-the-world`

## Planning Files

All project context lives in `.planning/`:

| File | Purpose |
|------|---------|
| `.planning/PROJECT.md` | Project goals, requirements, key decisions |
| `.planning/ROADMAP.md` | 6-phase execution plan |
| `.planning/REQUIREMENTS.md` | 57 v1 requirements with REQ-IDs |
| `.planning/STATE.md` | Current phase and progress |
| `.planning/config.json` | Workflow settings (YOLO, parallel, standard granularity) |
| `.planning/research/` | Domain research: stack, features, architecture, pitfalls, summary |

**Always read `.planning/STATE.md` and the current phase section in `ROADMAP.md` before starting work.**

## GSD Workflow

This project uses the GSD (Get Shit Done) workflow:

```
/gsd:discuss-phase N   → gather context before planning
/gsd:plan-phase N      → create PLAN.md for the phase
/gsd:execute-phase N   → execute all plans in the phase
/gsd:verify-work N     → verify phase goal was achieved
/gsd:progress          → see current status
```

**Current status:** Initialized. Ready for Phase 1.

## Critical Architecture Decisions

These are locked — do not reverse without explicit discussion:

1. **Flutter + CustomPainter + InteractiveViewer** for the map. NOT flutter_map (wrong model), NOT syncfusion (commercial license).

2. **Map data is pre-processed JSON, not runtime SVG parsing.** Pipeline: Natural Earth SVG → Python script → `world_map_paths.json`. This runs at build time. The JSON is bundled as an asset.

3. **Flag tray is OUTSIDE InteractiveViewer; DragTargets are INSIDE.** Drop coordinates must use `TransformationController.toScene()`, NOT `RenderBox.globalToLocal()`. This cannot be changed after Phase 3 without rewriting the drag system.

4. **Ad layer is a walled garden.** `GameSessionNotifier` has zero imports from `features/ads/`. The ad module stubs as `AdLoadState.failed` through Phases 1–5. Real AdMob wiring is Phase 6 only.

5. **No Firebase, ever.** Firebase Analytics and Crashlytics both collect persistent device identifiers (App Instance ID, Crashlytics UUID) — COPPA-prohibited for this app. Use Android Vitals instead. Do not add `firebase_core` to `pubspec.yaml`.

## COPPA / Families Policy Non-Negotiables

- `tagForChildDirectedTreatment(true)` must be set on **AdMob AND each mediation SDK** before `MobileAds.initialize()`. AdMob does NOT cascade this flag.
- `AD_ID` permission must be blocked in `AndroidManifest.xml` via `tools:remove`.
- Interstitial ads: game-complete screen ONLY. Never mid-round, never on app open.
- Pause screen: NO ads of any kind.
- App Open ads: only after user can interact with the app.
- No personalised/behavioural advertising.

## Tech Stack

| Concern | Choice | Notes |
|---------|--------|-------|
| Framework | Flutter (Dart) | Cross-platform, no JS bridge |
| Map rendering | CustomPainter + InteractiveViewer | Pre-parsed dart:ui Path objects |
| Flag assets | lipis/flag-icons (MIT, SVG) | 195 flags by ISO alpha-2 |
| State | Riverpod 2.x + codegen | AsyncNotifier for GameSession |
| Storage | shared_preferences | Scores, mute pref, session state |
| Ads | google_mobile_ads ^5.x | Child-directed init required |
| Audio | just_audio | CC-licensed sound assets |
| i18n | flutter gen-l10n (ARB) + runtime JSON | ARB for UI; JSON for country names |
| Navigation | GoRouter | With onExit back-button guard |

## Build Order

Phases execute strictly in order (each depends on the previous):

1. **Foundation** — Python SVG pipeline, Dart models, i18n, offline baseline
2. **State & Data Layer** — GameSession state machine, scoring, repositories (no widgets)
3. **Map Rendering & Drag-Drop** — WorldMapPainter, gesture handling, full play loop
4. **Game Modes & Scoring** — All 4 modes, HUD, hints, stars, personal best
5. **Session Polish & Accessibility** — Pause/resume, tutorial, a11y, sharing + parental gate
6. **AdMob & COPPA Audit** — Isolated ad layer, mediation SDKs, proxy verification

## Key Risk: Drag-Drop Under Zoom

The highest-risk technical unknown is drag-drop hit detection under InteractiveViewer zoom. **Phase 3 starts with a mandatory coordinate-transform spike**: drag a widget over 5 DragTarget regions at 1×, 2×, and 4× zoom and confirm the correct region is always hit. Do not build the full drag system until this spike passes.
