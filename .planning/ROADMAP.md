# Roadmap: Flags Around the World

## Overview

Six phases deliver a COPPA-compliant, fully offline Flutter educational game from a raw data pipeline through a polished, ad-monetized app ready for Google Play Families Program review. The build order is non-negotiable: the Python SVG pipeline and Dart domain models must exist before any rendering work begins; the ad layer is a walled-garden stub throughout all early phases and only receives real AdMob wiring in the final phase.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - Asset pipeline, Dart domain models, i18n infrastructure, and offline/compliance baseline
- [ ] **Phase 2: State & Data Layer** - GameSession state machine, scoring domain logic, repositories — no widgets
- [ ] **Phase 3: Map Rendering & Drag-Drop** - WorldMapPainter, InteractiveViewer wrapper, coordinate-transform spike, flag tray
- [ ] **Phase 4: Game Modes & Scoring** - All four game modes, full scoring HUD, hints, session persistence
- [ ] **Phase 5: Session Polish & Accessibility** - HUD, pause/resume, tutorial, orientation, accessibility, sharing
- [ ] **Phase 6: AdMob & COPPA Audit** - Isolated ad layer with all mediation SDKs, COPPA flags, AD_ID block, store prep

## Phase Details

### Phase 1: Foundation
**Goal**: The build-time data pipeline, Dart domain models, i18n infrastructure, and offline compliance baseline are in place so that every subsequent phase has stable, testable primitives to build on.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: COMP-01, COMP-03, I18N-01, I18N-02, I18N-03
**Success Criteria** (what must be TRUE):
  1. The Python script runs against the Natural Earth shapefile and produces a valid `world_map_paths.json` containing ISO code, SVG path string(s), bounding box, and centroid for all 196 countries.
  2. A Dart unit test can load `world_map_paths.json` from assets, parse it, and assert that every country entry has a non-empty ISO code and at least one path string — with zero network calls.
  3. Running `flutter gen-l10n` produces generated ARB-backed localisation classes; all UI chrome strings are externalized (no hardcoded English strings in Dart UI code).
  4. A Dart test loads `countries_en.json` and asserts exactly 196 entries are present with non-empty names; adding a `countries_es.json` file (with matching keys) causes the data service to serve Spanish names without any Dart code changes.
  5. The app builds and launches offline (flight-mode device) and no runtime network request is attempted; the app does not declare or request any dangerous Android permissions.
**Plans**: 6 plans

Plans:

**Wave 1**
- [ ] 01-01-PLAN.md — Flutter SDK + Python pipeline dependency verification (checkpoint)

**Wave 2** *(blocked on Wave 1 completion)*
- [ ] 01-02-PLAN.md — Flutter project scaffold, Walking Skeleton, pubspec, manifests, Dart models

**Wave 3** *(blocked on Wave 2 completion — plans run in parallel)*
- [ ] 01-03-PLAN.md — Python GIS pipeline: generate world_map_paths.json + countries_en/es.json
- [ ] 01-05-PLAN.md — ARB i18n infrastructure + flutter gen-l10n

**Wave 4** *(blocked on Wave 2 + Wave 3/01-03 completion)*
- [ ] 01-04-PLAN.md — Ad walled-garden stub + unit/architecture test files

**Wave 5** *(blocked on Wave 3 + Wave 4 completion)*
- [ ] 01-06-PLAN.md — Full integration verification + offline launch human check

Cross-cutting constraints:
- 196 countries (not 195): All plans enforce this — Kosovo (XK) + Taiwan (TW) + Holy See + UN-193
- Package ID: com.otis.brooke.flags.around.the.world — set explicitly in 01-02 after flutter create
- No firebase_*: COMP-01 truth enforced in 01-02 and verified in 01-06

### Phase 2: State & Data Layer
**Goal**: The `GameSessionNotifier` state machine, golf-style scoring domain logic, and local-storage repositories are fully implemented and unit-tested before any widget is written.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: SCOR-01, SCOR-02, SCOR-04
**Success Criteria** (what must be TRUE):
  1. A unit test drives `GameSessionNotifier` through idle → countdown → playing → paused → completed transitions and asserts each `GamePhase` value is emitted in order.
  2. A unit test simulates 30 seconds elapsed + 3 incorrect drops and asserts the score is exactly 8 points (3 × 10s intervals = 3 pts + 3 × 5 incorrect = 15 pts → wait, 30s = 3 × 10s = 3 pts, 3 errors × 5 = 15 pts, total 18 pts); the scorer produces the correct golf-style total for any elapsed-time + error-count input.
  3. `HighScoreRepository` writes a new best score to `shared_preferences`, reads it back on a fresh instance, and returns the stored value — verified by a test using a mock `SharedPreferences`.
  4. After simulating a correct flag drop, `GameSessionNotifier` immediately writes current state to storage (not deferred to game-end), confirmed by asserting the mock storage write count equals the correct-drop count.
**Plans**: TBD

### Phase 3: Map Rendering & Drag-Drop
**Goal**: A tester can open the app, see the interactive world map, drag a flag card from the tray, drop it onto a country at any zoom level, and receive correct/incorrect feedback — with hit detection validated at 1×, 2×, and 4× zoom.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: MAP-01, MAP-02, MAP-03, MAP-04, MAP-05, GAME-01, GAME-02, GAME-03, GAME-04, GAME-05, GAME-06
**Success Criteria** (what must be TRUE):
  1. The world map renders all 196 country regions as distinct droppable areas; a tester can visually identify and tap any country without the app freezing or dropping below 30 fps on a mid-range Android device (profiled with `flutter run --profile`).
  2. Pinch-to-zoom, two-finger pan, and on-screen zoom buttons all work smoothly; country name labels remain readable and scale proportionally at every zoom level.
  3. Dragging a flag card over a country visually highlights that country; releasing the card on the correct country triggers a snap animation, audio chime, and haptic pulse; releasing on the wrong country triggers a gentle error visual, distinct audio tone, and short haptic buzz — and the card returns to the tray.
  4. Drag-drop hit detection resolves correctly at 1×, 2×, and 4× zoom levels (coordinate transform via `TransformationController.toScene()` is verified by a manual test on a physical or emulated device — the known critical risk).
  5. A full session draws all 196 flags in random order one at a time and ends with a completion screen after the last correct match; no flag is ever drawn twice in the same session.
**Plans**: TBD
**UI hint**: yes

### Phase 4: Game Modes & Scoring
**Goal**: All four game modes are selectable and behave correctly; the live scoring HUD displays accurate score, timer, and progress; hints are available; and the completion screen shows stars and personal-best celebration.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: MODE-01, MODE-02, MODE-03, MODE-04, MODE-05, SCOR-03, SCOR-05, SCOR-06, SCOR-07, GAME-07, GAME-08
**Success Criteria** (what must be TRUE):
  1. In Learn mode, country names appear both on the map and under the active flag card; in Flags Master mode, names appear only under the flag; in Geographical Master mode, names appear only on the map; in Grand Master mode, no names appear anywhere — all four variants behave correctly on the same device without a rebuild.
  2. Grand Master mode presents flags in the pre-defined distinctiveness-ordered sequence (most recognizable first), not in random order.
  3. The top HUD displays a live score, running timer, and a progress bar (flags matched / total) that update in real time throughout gameplay.
  4. After exhausting 2 free hints, a "Watch ad to refill hints" prompt appears; tapping it (with ad stub returning success) restores the hint count; the hint button correctly reveals the target country's location on the map.
  5. The completion screen displays a 1–3 star rating based on the player's score relative to their personal best; if the player beats their best score, a celebratory personal-best milestone screen is shown before the standard completion screen.
**Plans**: TBD
**UI hint**: yes

### Phase 5: Session Polish & Accessibility
**Goal**: Session lifecycle (pause, resume, auto-pause, persistence, tutorial) is complete; the app is fully accessible with correct touch targets and semantic labels; portrait/landscape work correctly; social sharing is gated behind a parental challenge.
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: SESS-01, SESS-02, SESS-03, SESS-04, SESS-05, SESS-06, SESS-07, ACCS-01, ACCS-02, ACCS-03, ACCS-04, SHAR-01, SHAR-02, SHAR-03, SHAR-04, COMP-02, COMP-04
**Success Criteria** (what must be TRUE):
  1. Backgrounding the app (pressing home or switching apps) automatically pauses the timer; returning to the app shows the game in a paused state; no score time accrues while the app is backgrounded.
  2. Force-quitting and relaunching the app during a session shows a "Continue your game?" dialog with the correct score, matched flags, and elapsed time restored from local storage.
  3. On first launch, an animated tutorial walkthrough is displayed with a skip button visible from the very first frame; pressing skip immediately dismisses the tutorial.
  4. An "End Game" / exit button is always reachable from the pause screen; tapping it ends the session and returns to the home screen without requiring additional taps.
  5. TalkBack (Android) or VoiceOver (iOS) correctly announces all interactive elements; all tappable targets measure at least 48dp; the mute toggle is visible in the HUD and persists across app restarts.
  6. Tapping "Share Score" on the victory screen triggers a multi-digit multiplication parental gate; solving it correctly opens the native OS share sheet with a stylized screenshot overlay ("New lowest score in [Level] level!"); failing or cancelling the gate does not open the share sheet.
  7. The app's Play Store listing includes a link to a hosted privacy policy URL; the Android manifest blocks `AD_ID` permission via `tools:remove`; a manual Google Play Families Policy checklist passes with no blocking issues.
**Plans**: TBD
**UI hint**: yes

### Phase 6: AdMob & COPPA Audit
**Goal**: The walled-garden ad layer is fully implemented with all mediation SDKs initialized with child-directed flags; all four ad formats serve correctly; a proxy audit confirms no GAID or device identifier leaks; the app is ready for Google Play Families Program review.
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: ADS-01, ADS-02, ADS-03, ADS-04, ADS-05, ADS-06, ADS-07, ADS-08, ADS-09, ADS-10
**Success Criteria** (what must be TRUE):
  1. Banner ads appear on the home screen, mode-selection screen, and result screen; no banner ad appears on the pause screen or during active gameplay.
  2. An interstitial ad fires at the game-complete screen (natural break point) and never during a round or on app open before the user has had a chance to interact.
  3. The rewarded interstitial ad flow triggers when hints are exhausted; a user who watches the full ad receives a hint refill; a user who skips or dismisses receives nothing.
  4. The App Open ad displays on the splash/loading screen only after the app is ready for user interaction (not blocking the launch).
  5. A Charles Proxy or mitmproxy audit of all ad network traffic confirms zero outbound requests containing `gaid`, `idfa`, `advertising_id`, or any persistent device identifier from AdMob, AppLovin, Unity Ads, or Meta Audience Network (if included).
  6. `tagForChildDirectedTreatment(true)`, `tagForUnderAgeOfConsent(true)`, and `maxAdContentRating(G)` are set and verified in code before `MobileAds.initialize()` is called; each mediation SDK has its own child-directed flag confirmed in its initialization block; `firebase_core` does not appear anywhere in `pubspec.yaml` or `pubspec.lock`.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/6 | Planning done | - |
| 2. State & Data Layer | 0/? | Not started | - |
| 3. Map Rendering & Drag-Drop | 0/? | Not started | - |
| 4. Game Modes & Scoring | 0/? | Not started | - |
| 5. Session Polish & Accessibility | 0/? | Not started | - |
| 6. AdMob & COPPA Audit | 0/? | Not started | - |
