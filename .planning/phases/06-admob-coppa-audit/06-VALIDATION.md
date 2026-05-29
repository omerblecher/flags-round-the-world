# Phase 6: AdMob & COPPA Audit — Validation

**Phase:** 6 — AdMob & COPPA Audit
**Status:** Pending execution

## Test Commands

| Scope | Command |
|-------|---------|
| Unit tests only | `flutter test test/unit/` |
| Full suite | `flutter test` |
| Walled-garden check | `grep -rn "google_mobile_ads" lib/ --include="*.dart" \| grep -v "lib/core/ads/"` |
| Firebase absence | `grep -c firebase pubspec.lock` (expect 0) |
| AD_ID manifest check | `./gradlew :app:mergeDebugAndroidManifest` then inspect output |

## Requirement → Test Map

| Req ID | Behavior | Test Type | File | Auto? |
|--------|----------|-----------|------|-------|
| ADS-05 | RequestConfiguration has tagForChildDirectedTreatment=yes and maxAdContentRating=G before initialize() | Unit | test/unit/ad_service_test.dart | Yes |
| ADS-05 | Unity and ironSource COPPA flags called before MobileAds.initialize() | Unit | test/unit/ad_service_test.dart | Yes |
| ADS-09 | AD_ID permission absent from merged manifest | Static | build/intermediates/merged_manifests | Manual |
| ADS-10 | firebase_core absent from pubspec.lock | Static | pubspec.lock grep | Manual |
| D-A01 | StubAdService.getBannerWidget() returns SizedBox.shrink() | Unit | test/unit/ad_service_test.dart | Yes |
| D-A03 | showRewardedAd() returns true on reward earned | Unit | test/unit/ad_service_test.dart | Yes |
| D-A03 | showRewardedAd() returns false on dismiss/fail | Unit | test/unit/ad_service_test.dart | Yes |
| Proxy | GAID/advertising_id zeroed in all ad network traffic | Manual | Charles/mitmproxy audit | Manual |
| Families | Unity Ads + ironSource on Play Families Self-Certified SDK list | Manual | Play Console Help URL | Manual |

## Sampling Rate

- **Per task commit:** `flutter test test/unit/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green + all manual checks passed + human proxy audit checkpoint in 06-04

## Human Checkpoint

Located in `06-04-PLAN.md` Task 2 (Wave 3). Requires:
1. Proxy audit results (zero GAID/advertising_id in traffic)
2. Merged manifest AD_ID absence confirmed
3. Firebase absence from pubspec.lock confirmed
4. Unity Ads + ironSource Families Self-Certified list status confirmed
5. Walled-garden grep returns zero matches
