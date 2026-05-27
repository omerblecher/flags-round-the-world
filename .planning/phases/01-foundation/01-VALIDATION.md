---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-27
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + dart:test |
| **Config file** | None needed — `flutter test` discovers by convention |
| **Quick run command** | `flutter test test/unit/ test/architecture/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/ test/architecture/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-pipeline | — | 1 | COMP-03 | T-1-01 | No network calls in asset load | unit | `flutter test test/unit/country_data_test.dart` | ❌ W0 | ⬜ pending |
| 1-i18n-svc | — | 1 | I18N-02, I18N-03 | — | N/A | unit | `flutter test test/unit/country_data_service_test.dart` | ❌ W0 | ⬜ pending |
| 1-gen-l10n | — | 1 | I18N-01 | — | N/A | build | `flutter gen-l10n` exits 0 | ❌ W0 | ⬜ pending |
| 1-ads-isolation | — | 1 | D-12 | T-1-02 | No game/map/core imports features/ads/ | architecture | `flutter test test/architecture/ads_isolation_test.dart` | ❌ W0 | ⬜ pending |
| 1-manifest | — | 1 | COMP-01 | T-1-03 | No INTERNET permission in release manifest; no firebase in pubspec | manual | `grep -r "firebase" pubspec.yaml pubspec.lock` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/country_data_test.dart` — stub covering COMP-03, pipeline 196-entry assertion
- [ ] `test/unit/country_data_service_test.dart` — stubs covering I18N-02, I18N-03 (locale swap without Dart changes)
- [ ] `test/architecture/ads_isolation_test.dart` — D-12 isolation enforcement
- [ ] Python pipeline environment: `pip install geopandas pyproj shapely` verification step
- [ ] Flutter SDK install verification (Flutter not found in PATH per research audit)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No INTERNET permission in release manifest | COMP-01 | Manifest merger is build-time; automated check not reliable until build runs | `grep -r "INTERNET" android/app/src/main/AndroidManifest.xml` — expect no match; debug manifest may have it |
| No firebase in pubspec | COMP-01/ADS-10 | Transitive dependency check | `grep -r "firebase" pubspec.yaml pubspec.lock` — expect no matches |
| App builds offline on flight-mode device | COMP-03 | Requires physical or emulated device | Build release APK, enable flight mode, install, confirm launch succeeds |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
