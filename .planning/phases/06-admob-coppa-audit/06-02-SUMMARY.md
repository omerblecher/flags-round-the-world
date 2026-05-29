---
phase: "06-admob-coppa-audit"
plan: "02"
subsystem: "ads"
tags: [admob, interface-design, walled-garden, coppa]
dependency_graph:
  requires: ["06-01"]
  provides: ["AdMobAdService", "AdService-interface-v2", "StubAdService-standalone"]
  affects: ["lib/core/ads/", "lib/features/map/map_screen.dart"]
tech_stack:
  added: []
  patterns: ["walled-garden ad isolation", "merged load+show interface", "Ref-aware service"]
key_files:
  created:
    - lib/core/ads/stub_ad_service.dart
    - lib/core/ads/admob_ad_service.dart
  modified:
    - lib/core/ads/ad_service.dart
    - lib/core/ads/ad_service_provider.dart
    - lib/features/map/map_screen.dart
    - test/unit/ad_service_test.dart
decisions:
  - "getLargeAnchoredAdaptiveBannerAdSize(width) used — getCurrentOrientationAnchoredAdaptiveBannerAdSize is deprecated in GMA 8.0.0"
  - "AppOpenAd.load() uses request: param (not adRequest:) in GMA 8.0.0"
  - "AsyncValue.value getter used (not .valueOrNull — absent from flutter_riverpod 3.3.1)"
  - "D-O02 suppression placed inside AdMobAdService.showAppOpenAd() not in caller"
metrics:
  duration: "12m"
  completed: "2026-05-29"
  tasks: 2
  files: 6
---

# Phase 6 Plan 02: AdService Interface Redesign + AdMobAdService Summary

**One-liner:** Merged load+show AdService interface with production AdMobAdService isolating all google_mobile_ads usage inside lib/core/ads/.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Redesign AdService interface + StubAdService | 97bd610 | ad_service.dart, stub_ad_service.dart, ad_service_provider.dart, map_screen.dart, ad_service_test.dart |
| 2 | Implement AdMobAdService + swap provider | 271b7ab | admob_ad_service.dart, ad_service_provider.dart |

## Verification Results

- `flutter analyze lib/core/ads/` — No issues found
- `test/architecture/ads_isolation_test.dart` — PASS (no features/ads/ imports in game/map/core)
- `test/unit/ad_service_test.dart` — 4/4 PASS (GREEN phase achieved)
- `grep google_mobile_ads lib/features/ lib/app.dart` — zero results (walled garden intact)
- `ad_service_provider.dart` contains `AdMobAdService` — confirmed

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated map_screen.dart to use new AdService interface**
- **Found during:** Task 1
- **Issue:** `map_screen.dart` called `loadRewardedAd()` (returns `AdLoadState`) — method removed from new interface
- **Fix:** Replaced with `showRewardedAd()` (returns `bool`); removed now-unused `ad_load_state.dart` import
- **Files modified:** `lib/features/map/map_screen.dart`
- **Commit:** 97bd610

**2. [Rule 1 - Bug] Updated test import for relocated StubAdService**
- **Found during:** Task 1
- **Issue:** `test/unit/ad_service_test.dart` imported `StubAdService` from `ad_service.dart`; after extraction to `stub_ad_service.dart` it would compile-fail
- **Fix:** Added `import 'package:flags_around_the_world/core/ads/stub_ad_service.dart';` to test
- **Files modified:** `test/unit/ad_service_test.dart`
- **Commit:** 97bd610

**3. [Rule 1 - Bug] Corrected AdSize API — deprecated method replaced**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** Plan specified `getCurrentOrientationAnchoredAdaptiveBannerAdSize()` which is `@Deprecated` in GMA 8.0.0; analyzer raised warning
- **Fix:** Replaced with `getLargeAnchoredAdaptiveBannerAdSize(screenWidthDp)` — takes single `int` parameter, no Orientation arg
- **Commit:** 271b7ab

**4. [Rule 1 - Bug] Corrected AsyncValue getter name**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** Plan used `.valueOrNull` which does not exist on `AsyncValue` in flutter_riverpod 3.3.1; the getter is `.value`
- **Fix:** Changed `_ref.read(gameSessionProvider).valueOrNull` to `_ref.read(gameSessionProvider).value`
- **Commit:** 271b7ab

## Known Stubs

None — all four ad formats have production implementations. Banner load is deferred to screen `didChangeDependencies()` via `loadBannerForWidth()`.

## Threat Flags

No new threat surface introduced beyond what the plan's threat model covers. The walled-garden boundary (T-06-06) and App Open suppression (T-06-07) are both implemented. T-06-07 suppression is in `AdMobAdService.showAppOpenAd()` via `_ref.read(gameSessionProvider).value`.

## Self-Check

- [x] `lib/core/ads/ad_service.dart` exists — 4-method interface, no StubAdService
- [x] `lib/core/ads/stub_ad_service.dart` exists — implements all 4 methods
- [x] `lib/core/ads/admob_ad_service.dart` exists — full AdMob implementation
- [x] `lib/core/ads/ad_service_provider.dart` returns AdMobAdService
- [x] Commits 97bd610 and 271b7ab exist in git log
- [x] 5/5 tests pass (architecture + unit)
- [x] Zero google_mobile_ads imports outside lib/core/ads/
