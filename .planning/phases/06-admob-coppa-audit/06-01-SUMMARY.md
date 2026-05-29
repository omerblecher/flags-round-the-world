---
phase: "06-admob-coppa-audit"
plan: "01"
subsystem: "ads"
tags: [admob, coppa, mediation, foundation, wave-1]
dependency_graph:
  requires: []
  provides:
    - "google_mobile_ads package installed and resolvable"
    - "gma_mediation_{unity,ironsource,inmobi,applovin} packages installed"
    - "initializeAds() walled-garden compliant COPPA init function"
    - "All Phase 6 ad unit ID constants in lib/core/ads/ad_constants.dart"
    - "AdMob App ID in AndroidManifest.xml (prevents crash on launch)"
    - "network_security_config.xml for proxy audit (debug-overrides only)"
    - "RED test stubs for Wave 2 AdService interface redesign"
  affects:
    - "lib/main.dart (async, calls initializeAds)"
    - "android/build.gradle.kts (ironSource Maven repo)"
tech_stack:
  added:
    - "google_mobile_ads: ^8.0.0"
    - "gma_mediation_unity: ^1.8.0"
    - "gma_mediation_ironsource: ^2.4.1"
    - "gma_mediation_inmobi: ^2.1.0"
    - "gma_mediation_applovin: ^2.6.1"
  patterns:
    - "Walled-garden boundary: all google_mobile_ads imports confined to lib/core/ads/"
    - "COPPA mandatory init ordering: child-directed flags before MobileAds.instance.initialize()"
    - "debug-overrides-only network security config (safe for Play Store)"
key_files:
  created:
    - lib/core/ads/ad_constants.dart
    - lib/core/ads/ads_initializer.dart
    - android/app/src/main/res/xml/network_security_config.xml
    - test/unit/ad_service_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - android/build.gradle.kts
    - android/app/src/main/AndroidManifest.xml
    - lib/main.dart
decisions:
  - "GmaMediationUnity.setGDPRConsent/setCCPAConsent are instance methods in v1.8.0, not static — fixed to use GmaMediationUnity() instance"
  - "COPPA init sequence: updateRequestConfiguration first, then mediation COPPA flags, then MobileAds.instance.initialize() last"
  - "kAppLovinEnabled=false gate documents activation path without orphaned code"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-29"
  tasks_completed: 3
  tasks_total: 3
  files_created: 4
  files_modified: 5
---

# Phase 06 Plan 01: Wave 1 Foundation — Ad Packages, COPPA Init, Constants Summary

**One-liner:** Five gma_mediation_* packages installed, walled-garden compliant initializeAds() with mandatory COPPA ordering, and RED test stubs for Wave 2 interface redesign.

## What Was Built

Wave 1 establishes all foundation pieces required before Wave 2 can redesign the AdService interface. No widget changes were made; no existing functionality was broken.

### Task 1: Ad SDK Packages + ironSource Maven Repo

- Added 5 packages to `pubspec.yaml` dependencies (after `just_audio`):
  - `google_mobile_ads: ^8.0.0`
  - `gma_mediation_unity: ^1.8.0`
  - `gma_mediation_ironsource: ^2.4.1`
  - `gma_mediation_inmobi: ^2.1.0`
  - `gma_mediation_applovin: ^2.6.1`
- Added ironSource Maven repo to `android/build.gradle.kts` inside `allprojects { repositories }` — required for `gma_mediation_ironsource` to resolve its native AAR
- `flutter pub get` resolved all 5 packages; no `firebase_core` in pubspec.lock (COPPA constraint T-06-04 met)

### Task 2: AndroidManifest + network_security_config + ad_constants.dart

- Added AdMob test App ID meta-data to `AndroidManifest.xml` (prevents `RuntimeException: Missing application ID` crash on launch)
- Added `android:networkSecurityConfig="@xml/network_security_config"` attribute to `<application>` tag
- Created `android/app/src/main/res/xml/network_security_config.xml` using `<debug-overrides>` only — user-installed CA certs trusted in debug mode only; production builds unaffected (T-06-03 met)
- Created `lib/core/ads/ad_constants.dart` with all test ad unit IDs (`kBannerAdUnitId`, `kInterstitialAdUnitId`, `kRewardedAdUnitId`, `kAppOpenAdUnitId`) and `kAppLovinEnabled = false`
- Verified `tools:node="remove"` on `AD_ID` permission (COMP-04) is intact (T-06-02 met)

### Task 3: ads_initializer.dart + async main + RED test stubs

- Created `lib/core/ads/ads_initializer.dart` — the ONLY file importing `google_mobile_ads` outside `lib/core/ads/` ad service files (walled-garden boundary T-06-06 enforced)
- COPPA init sequence follows mandatory ordering per RESEARCH.md:
  1. `updateRequestConfiguration(tagForChildDirectedTreatment: yes, maxAdContentRating: G)` — before initialize
  2. ironSource `setDoNotSell(true)` — before initialize
  3. Unity `setGDPRConsent(false)` + `setCCPAConsent(false)` — before initialize
  4. AppLovin gate (`kAppLovinEnabled = false`) — documents activation path
  5. `await MobileAds.instance.initialize()` — last
- Updated `lib/main.dart`: made `main()` async, added `await initializeAds()` before `runApp()`; zero `google_mobile_ads` imports in `main.dart` (boundary intact)
- Created `test/unit/ad_service_test.dart` with 4 RED test stubs calling the new `AdService` interface (`getBannerWidget`, `showRewardedAd`, `showInterstitialAd`, `showAppOpenAd`) — compile errors expected until Wave 2 redesigns the interface

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] GmaMediationUnity consent methods are instance, not static**
- **Found during:** Task 3 — `flutter analyze lib/core/ads/` reported 2 errors
- **Issue:** Plan specified `GmaMediationUnity.setGDPRConsent(false)` and `GmaMediationUnity.setCCPAConsent(false)` as static calls. The actual `gma_mediation_unity: ^1.8.0` API declares these as instance methods on the `GmaMediationUnity` class.
- **Fix:** Changed to `await GmaMediationUnity().setGDPRConsent(false)` and `await GmaMediationUnity().setCCPAConsent(false)` (instance construction + await for async methods)
- **Files modified:** `lib/core/ads/ads_initializer.dart`
- **Commit:** 20be107

## Known Stubs

- `test/unit/ad_service_test.dart` — 4 tests are intentional RED stubs. They reference `AdService` methods (`getBannerWidget`, `showRewardedAd`, `showInterstitialAd`, `showAppOpenAd`) that do not yet exist on the interface. **This is by design** — Wave 2 (plan 06-02) redesigns `AdService` to make these GREEN. Do not treat as a defect.

## Threat Surface Scan

All changes fall within the threat model defined in the plan:
- T-06-01: `tagForChildDirectedTreatment: yes` + `maxAdContentRating: G` set before initialize — mitigated
- T-06-02: `tools:node="remove"` on AD_ID verified intact — mitigated
- T-06-03: `<debug-overrides>` only in network_security_config.xml — mitigated
- T-06-04: Zero `firebase_core` in pubspec.lock — mitigated
- T-06-06: Zero `google_mobile_ads` imports in `main.dart` — mitigated

No new threat surface introduced beyond what the plan's threat model covers.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | 9423a0d | chore(06-01): add ad SDK packages and ironSource Maven repo |
| 2 | a88613d | feat(06-01): AdMob App ID in manifest, network security config, ad constants |
| 3 | 20be107 | feat(06-01): ads_initializer.dart, async main, RED test stubs |

## Self-Check: PASSED

All created files verified present on disk. All 3 commits verified in git log. Full verification suite from plan executed:
- `flutter pub get` exits 0
- All 5 gma_mediation_* packages in pubspec.lock
- Zero `firebase_core` in pubspec.lock
- `android-sdk.is.com` in build.gradle.kts
- `APPLICATION_ID` meta-data in AndroidManifest.xml
- `AD_ID tools:node="remove"` intact
- `initializeAds` called in main.dart
- Zero `google_mobile_ads` imports in main.dart
- `flutter analyze lib/core/ads/` reports "No issues found"
