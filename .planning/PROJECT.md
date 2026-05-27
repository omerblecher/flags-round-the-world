# Flags Around the World

## What This Is

A cross-platform educational mobile game where players drag-and-drop national flags onto an interactive world map. Targeted at general audiences including children aged 8+, the app features four difficulty levels — from guided learning to full "Grand Master" blackout — and is built to be fully COPPA-compliant and Google Play Families Policy-compliant from day one. It launches on Android (Google Play) with iOS support as a first-class build target from the start.

## Core Value

A child or adult must be able to learn every country's flag and location through satisfying, rewarding gameplay — with zero frustration from tiny tap targets, unreadable text, or data privacy concerns.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Interactive SVG world map with smooth pinch-to-zoom, pan, and zoom buttons
- [ ] 195 countries with flag data bundled on-device (fully offline)
- [ ] Drag-and-drop flag-to-country matching mechanic with forgiving hit targets
- [ ] 4 game modes: Learn, Flags Master, Geographical Master, Grand Master
- [ ] Golf-style scoring (+1 per 10s, +5 per error), local high scores per level
- [ ] Celebratory milestone notification when a personal best is beaten
- [ ] Social sharing via native OS share sheet, gated behind a parental challenge
- [ ] Persistent HUD: score, timer, progress bar, pause button
- [ ] COPPA-compliant AdMob integration (tagForChildDirectedTreatment=true, G-rating)
- [ ] Banner, Interstitial, Rewarded Interstitial, and App Open ad formats
- [ ] AdMob mediation placeholders: AppLovin, Unity Ads, Meta Audience Network
- [ ] Full i18n infrastructure from day one (country names, UI strings, all localizable)
- [ ] Playful haptic feedback for correct/incorrect drops
- [ ] Positive visual + audio feedback for correct matches; gentle feedback for incorrect
- [ ] Free/open-source audio assets for SFX and background music
- [ ] Kid-friendly UI: vibrant color palette, icon-driven navigation, large touch targets

### Out of Scope

- Online/global leaderboards — no backend, no user accounts, no personal data collection
- Real-time multiplayer — single-player only in v1
- Paid download or IAP unlock — ad-supported free app for maximum reach
- Custom-commissioned audio — using CC-licensed sound packs to avoid delays
- Platform-specific features beyond standard Flutter capabilities in v1

## Context

- **Package ID:** `com.otis.brooke.flags.around.the.world`
- **Suggested repo name:** `flags-round-the-world` (kebab-case, aligns with Flutter convention)
- **Framework:** Flutter — chosen over React Native because the map is a custom `CustomPainter` canvas with simultaneous pinch-zoom and drag-drop gesture detection; Flutter handles this in a single widget tree without a JS bridge, with native 60fps rendering and superior SVG support via `flutter_svg`
- **Flag data:** SVG flags bundled as assets; country boundary data as a lightweight GeoJSON or custom SVG path map
- **Audio:** Free/CC-licensed sound packs (e.g., freesound.org, Kenney.nl) — no licensing cost
- **Compliance:** Google Play Families Policy + COPPA — no device identifiers, no behavioral tracking, no third-party SDKs that collect personal data from children without explicit compliance routing. All AdMob networks must receive child-directed treatment flags.
- **Parental gate:** Simple math-challenge parental gate guards the native OS share sheet before any external sharing occurs

## Constraints

- **Compliance:** COPPA + Google Play Families Policy — no data collection, no behavioral ads, child-directed AdMob flags mandatory
- **Offline-first:** No network dependency after install — all 195 country + flag assets bundled in APK/IPA
- **Tech stack:** Flutter (Dart) — locked in; cross-platform parity is non-negotiable
- **i18n:** Full localization infrastructure from day one — country names and UI strings must be externalizable
- **Ad content:** AdMob max rating G/PG; tagForChildDirectedTreatment=true; all mediated networks flagged child-directed
- **Platform:** Android first (Google Play); iOS must be a zero-friction add once Android ships

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter over React Native | Custom canvas + gesture stack; no JS bridge overhead; superior SVG + animation performance | — Pending |
| Fully offline (no backend) | Avoids COPPA auth/data-collection complexity; simpler infra; better for kids | — Pending |
| Golf-style scoring | Rewards efficiency and mastery; keeps replay value high for all skill levels | — Pending |
| Full i18n from day one | Country name translations are the core data; retrofitting later is expensive | — Pending |
| Parental gate on sharing | COPPA best practice — simple math challenge before OS share sheet opens | — Pending |
| Free/CC audio assets | No licensing delay or cost; can upgrade to custom audio in v2 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-27 after initialization*
