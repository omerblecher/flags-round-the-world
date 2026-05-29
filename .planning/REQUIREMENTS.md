# Requirements: Flags Around the World

**Defined:** 2026-05-27
**Core Value:** A child or adult must be able to learn every country's flag and location through satisfying, rewarding gameplay — with zero frustration from tiny tap targets, unreadable text, or data privacy concerns.

---

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Map & Canvas

- [ ] **MAP-01**: User sees an interactive SVG world map with all ~195 countries rendered as distinct droppable regions
- [ ] **MAP-02**: User can pinch-to-zoom and pan the map with smooth gesture handling
- [ ] **MAP-03**: User can zoom in and out via prominent on-screen zoom buttons
- [ ] **MAP-04**: Country name labels rendered on the map scale proportionally with zoom level and remain readable at all zoom levels
- [ ] **MAP-05**: The country under a dragged flag is visually highlighted during the drag gesture

### Game Modes

- [ ] **MODE-01**: User can play Learn mode — country names displayed both on the map AND under the active flag card
- [ ] **MODE-02**: User can play Flags Master mode — country name shown only under the active flag; map is completely blank
- [ ] **MODE-03**: User can play Geographical Master mode — country names shown only on the map; no name displayed under the flag
- [ ] **MODE-04**: User can play Grand Master mode — no country names displayed anywhere on screen
- [ ] **MODE-05**: Grand Master mode presents flags in a distinctiveness-ordered sequence (most recognizable flags first, harder flags later)

### Gameplay

- [ ] **GAME-01**: User can drag a flag card and drop it onto the correct country region on the map
- [ ] **GAME-02**: Drag-drop hit detection uses a forgiving snap radius (~30% of country SVG size) so small countries remain reachable
- [ ] **GAME-03**: Correct flag drop triggers a positive visual animation (flag snaps to country), audio chime, and haptic pulse
- [ ] **GAME-04**: Incorrect flag drop triggers a gentle error visual, distinct audio tone, and short haptic buzz; flag returns to tray
- [ ] **GAME-05**: Each game session draws flags from the full pool of unmatched countries in random order (one at a time)
- [ ] **GAME-06**: Game session ends when all 195 flags are successfully matched; completion screen is shown
- [ ] **GAME-07**: User has 2 free hints per session that reveal the correct country location for the active flag
- [ ] **GAME-08**: User can watch a rewarded ad to replenish hints after the 2 free hints are exhausted

### Scoring & Progress

- [x] **SCOR-01**: Score increments by 1 point for every 10 seconds of elapsed game time *(Validated in Phase 2: State & Data Layer)*
- [x] **SCOR-02**: Score increments by 5 points for every incorrect flag placement *(Validated in Phase 2: State & Data Layer)*
- [ ] **SCOR-03**: Live score and running timer are displayed in the persistent top HUD throughout gameplay
- [x] **SCOR-04**: The lowest (best) score for each of the 4 levels is stored locally on the device *(Validated in Phase 2: State & Data Layer)*
- [ ] **SCOR-05**: If the user beats their lowest score for a level, a celebratory personal-best milestone screen is shown
- [ ] **SCOR-06**: Completion screen displays a 1–3 star rating based on performance relative to personal best
- [ ] **SCOR-07**: A progress bar showing flags matched vs. total flags remaining is always visible in the HUD

### Session Management

- [ ] **SESS-01**: Persistent top HUD showing score, timer, progress bar, and a large pause/settings button is visible during all gameplay
- [ ] **SESS-02**: Game automatically pauses when the app goes to background (AppLifecycleState.paused)
- [ ] **SESS-03**: Game state (current score, matched flags, elapsed time, active mode) is written to local storage on every correct flag drop
- [ ] **SESS-04**: On app relaunch with an in-progress session, user is offered a "Continue your game?" dialog before the session resumes
- [ ] **SESS-05**: On first launch, an animated tutorial walkthrough is shown with a skip button visible from the first frame
- [ ] **SESS-06**: App layout responds correctly to both portrait and landscape orientations
- [ ] **SESS-07**: An "End Game" / exit button is always accessible from the pause screen (no hidden exits)

### Social Sharing

- [ ] **SHAR-01**: Victory screen includes a one-tap "Share Score" button that captures an in-app screenshot
- [ ] **SHAR-02**: The shared screenshot includes a stylized overlay header: "New lowest score in [Level Name] level!"
- [ ] **SHAR-03**: Before the OS share sheet opens, a parental gate challenge (multi-digit multiplication puzzle) must be solved
- [ ] **SHAR-04**: On passing the parental gate, the native OS share sheet opens with the screenshot ready to share

### Monetization & Compliance

- [x] **ADS-01**: Banner ads are shown on non-gameplay screens (home, mode selection, result screen); never on the pause screen
- [x] **ADS-02**: Interstitial ads are shown only at natural session break points (game-complete screen); never mid-round or on app open before first interaction
- [x] **ADS-03**: Rewarded interstitial ads are offered for hint refills after the 2 free session hints are exhausted
- [x] **ADS-04**: App Open ads are shown on the splash/loading screen, displayed only after the user is able to interact with the app
- [ ] **ADS-05**: AdMob SDK initialized with `tagForChildDirectedTreatment(true)`, `tagForUnderAgeOfConsent(true)`, `maxAdContentRating(G)` — set before `MobileAds.initialize()`
- [ ] **ADS-06**: AppLovin MAX SDK initialized with its own child-directed treatment flag at startup
- [ ] **ADS-07**: Unity Ads SDK initialized with its own child-directed/COPPA flag at startup
- [ ] **ADS-08**: Meta Audience Network SDK — either excluded, or initialized with its own child-directed flag at startup (editorial decision before AdMob phase)
- [ ] **ADS-09**: `AD_ID` permission blocked from merged Android manifest via `tools:remove` to prevent transitive GAID leakage
- [ ] **ADS-10**: Firebase Analytics and Crashlytics are not added to the project at any point (COPPA: both collect persistent device identifiers)

### Accessibility

- [ ] **ACCS-01**: A persistent mute toggle is visible in the HUD; the mute preference survives app restarts and respects the device silent switch
- [ ] **ACCS-02**: All correct/incorrect feedback uses shape + sound + color combinations — no feedback relies on color alone
- [ ] **ACCS-03**: All interactive UI elements have a minimum 48dp touch target size; flag drag-drop targets are extra-forgiving
- [ ] **ACCS-04**: All interactive elements have semantic accessibility labels for TalkBack (Android) and VoiceOver (iOS)

### Internationalization

- [ ] **I18N-01**: All UI chrome strings (button labels, dialog text, HUD labels) are externalized to ARB files via `flutter gen-l10n`
- [ ] **I18N-02**: All 195 country names are stored in per-locale JSON asset files (e.g., `countries_en.json`, `countries_es.json`) loaded at runtime
- [ ] **I18N-03**: App architecture supports adding a new language by adding a new locale JSON file and ARB entry — no Dart code changes required

### Infrastructure & Compliance

- [ ] **COMP-01**: App does not collect, transmit, or store any device identifiers, precise location, or personal data
- [ ] **COMP-02**: App includes a link to a hosted privacy policy (required for Google Play + COPPA)
- [ ] **COMP-03**: All game assets (SVG map, flag SVGs, audio files) are bundled on-device; app functions fully offline after install
- [ ] **COMP-04**: Android manifest `AD_ID` permission is blocked; app passes Google Play Families Policy pre-launch review checklist

---

## v2 Requirements

Deferred to future release. Architecturally supported but not in v1 roadmap.

### Enrichment

- **ENRI-01**: After a correct flag drop, a brief country fact card is shown (capital, region, population)
- **ENRI-02**: Country fact cards are available in all supported locales

### Progression

- **PROG-01**: Achievement badge system for milestones (e.g., "Matched all of Europe")
- **PROG-02**: Region-selectable practice mode (practice flags from one continent only)
- **PROG-03**: Streak mechanics (consecutive correct drops bonus)
- **PROG-04**: Daily challenge mode (fixed flag set, global comparison via anonymous hash)

### Accessibility Expansion

- **ACCS-05**: Colorblind mode that adds pattern overlays to visually similar flags
- **ACCS-06**: Adjustable text size for country labels

### Social

- **SOCL-01**: Global anonymous leaderboard (lowest score per level, no account required, hash-based identity)

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Online/global leaderboards in v1 | Requires backend + identity system; COPPA compliance for children's accounts is out of scope for v1 |
| Real-time multiplayer | High complexity; not core to educational value |
| Paid download or IAP to remove ads | App is free with ads; no paywall in v1 |
| Custom-commissioned audio | Replaced by CC-licensed assets; can upgrade in v2 |
| Firebase Analytics or Crashlytics | COPPA-prohibited — both collect persistent device identifiers; Android Vitals used instead |
| Personalized/behavioral advertising | Child-directed treatment disables all personalized ads by policy |
| Real-time country border data | Political border changes require an editorial process; static bundled data only |
| In-app purchases | No payment flow in v1 |
| User accounts or login | No personal data collection; no accounts |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| COMP-01 | Phase 1: Foundation | Pending |
| COMP-03 | Phase 1: Foundation | Pending |
| I18N-01 | Phase 1: Foundation | Pending |
| I18N-02 | Phase 1: Foundation | Pending |
| I18N-03 | Phase 1: Foundation | Pending |
| SCOR-01 | Phase 2: State & Data Layer | Pending |
| SCOR-02 | Phase 2: State & Data Layer | Pending |
| SCOR-04 | Phase 2: State & Data Layer | Pending |
| MAP-01 | Phase 3: Map Rendering & Drag-Drop | Pending |
| MAP-02 | Phase 3: Map Rendering & Drag-Drop | Pending |
| MAP-03 | Phase 3: Map Rendering & Drag-Drop | Pending |
| MAP-04 | Phase 3: Map Rendering & Drag-Drop | Pending |
| MAP-05 | Phase 3: Map Rendering & Drag-Drop | Pending |
| GAME-01 | Phase 3: Map Rendering & Drag-Drop | Pending |
| GAME-02 | Phase 3: Map Rendering & Drag-Drop | Pending |
| GAME-03 | Phase 3: Map Rendering & Drag-Drop | Pending |
| GAME-04 | Phase 3: Map Rendering & Drag-Drop | Pending |
| GAME-05 | Phase 3: Map Rendering & Drag-Drop | Pending |
| GAME-06 | Phase 3: Map Rendering & Drag-Drop | Pending |
| MODE-01 | Phase 4: Game Modes & Scoring | Pending |
| MODE-02 | Phase 4: Game Modes & Scoring | Pending |
| MODE-03 | Phase 4: Game Modes & Scoring | Pending |
| MODE-04 | Phase 4: Game Modes & Scoring | Pending |
| MODE-05 | Phase 4: Game Modes & Scoring | Pending |
| SCOR-03 | Phase 4: Game Modes & Scoring | Pending |
| SCOR-05 | Phase 4: Game Modes & Scoring | Pending |
| SCOR-06 | Phase 4: Game Modes & Scoring | Pending |
| SCOR-07 | Phase 4: Game Modes & Scoring | Pending |
| GAME-07 | Phase 4: Game Modes & Scoring | Pending |
| GAME-08 | Phase 4: Game Modes & Scoring | Pending |
| SESS-01 | Phase 5: Session Polish & Accessibility | Pending |
| SESS-02 | Phase 5: Session Polish & Accessibility | Pending |
| SESS-03 | Phase 5: Session Polish & Accessibility | Pending |
| SESS-04 | Phase 5: Session Polish & Accessibility | Pending |
| SESS-05 | Phase 5: Session Polish & Accessibility | Pending |
| SESS-06 | Phase 5: Session Polish & Accessibility | Pending |
| SESS-07 | Phase 5: Session Polish & Accessibility | Pending |
| ACCS-01 | Phase 5: Session Polish & Accessibility | Pending |
| ACCS-02 | Phase 5: Session Polish & Accessibility | Pending |
| ACCS-03 | Phase 5: Session Polish & Accessibility | Pending |
| ACCS-04 | Phase 5: Session Polish & Accessibility | Pending |
| SHAR-01 | Phase 5: Session Polish & Accessibility | Pending |
| SHAR-02 | Phase 5: Session Polish & Accessibility | Pending |
| SHAR-03 | Phase 5: Session Polish & Accessibility | Pending |
| SHAR-04 | Phase 5: Session Polish & Accessibility | Pending |
| COMP-02 | Phase 5: Session Polish & Accessibility | Pending |
| COMP-04 | Phase 5: Session Polish & Accessibility | Pending |
| ADS-01 | Phase 6: AdMob & COPPA Audit | Complete |
| ADS-02 | Phase 6: AdMob & COPPA Audit | Complete |
| ADS-03 | Phase 6: AdMob & COPPA Audit | Complete |
| ADS-04 | Phase 6: AdMob & COPPA Audit | Complete |
| ADS-05 | Phase 6: AdMob & COPPA Audit | Pending |
| ADS-06 | Phase 6: AdMob & COPPA Audit | Pending |
| ADS-07 | Phase 6: AdMob & COPPA Audit | Pending |
| ADS-08 | Phase 6: AdMob & COPPA Audit | Pending |
| ADS-09 | Phase 6: AdMob & COPPA Audit | Pending |
| ADS-10 | Phase 6: AdMob & COPPA Audit | Pending |

**Coverage:**
- v1 requirements: 57 total
- Mapped to phases: 57/57
- Unmapped: 0

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-05-27 after roadmap creation*
