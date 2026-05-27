---
phase: "01"
plan: "02"
subsystem: scaffold
tags: [flutter, android, riverpod, l10n, models]
dependency_graph:
  requires: ["01-01"]
  provides: ["flutter-scaffold", "pubspec-locked", "country-data-models", "directory-structure"]
  affects: ["01-03", "01-04", "01-05", "01-06"]
tech_stack:
  added:
    - flutter_riverpod: ^3.3.1
    - riverpod_annotation: ^4.0.2
    - flutter_svg: ^2.3.0
    - go_router: ^17.2.3
    - path_drawing: ^1.0.1
    - shared_preferences: ^2.5.5
    - intl: ^0.20.2
    - flutter_localizations (sdk)
  patterns:
    - ProviderScope root widget
    - Feature-folder architecture (features/{game,map,home,ads})
    - Core layer (models, data, l10n)
    - ARB-based i18n with generated output to lib/generated/l10n
key_files:
  created:
    - pubspec.yaml
    - pubspec.lock
    - l10n.yaml
    - android/app/build.gradle.kts
    - android/app/src/main/AndroidManifest.xml
    - android/app/src/main/kotlin/com/otis/brooke/flags/around/the/world/MainActivity.kt
    - lib/main.dart
    - lib/app.dart
    - lib/core/models/country_data.dart
    - lib/core/data/country_data_service.dart
    - lib/core/l10n/app_en.arb
    - assets/{flags,map,data,audio}/.gitkeep
    - lib/features/{game,map,home,ads}/.gitkeep
  modified:
    - .gitignore
decisions:
  - applicationId and Kotlin package path set to com.otis.brooke.flags.around.the.world (corrected from flutter create default)
  - synthetic-package removed from l10n.yaml (deprecated in Flutter 3.44.0, was causing pub get failure)
  - Minimal app_en.arb created with scaffoldHomeLabel key to unblock pub get (full ARB populated in Plan 05)
  - lib/generated/ added to .gitignore so generated l10n files are not tracked
metrics:
  duration_seconds: 453
  completed_date: "2026-05-27"
  tasks_completed: 2
  files_created: 23
---

# Phase 1 Plan 2: Flutter Project Scaffold Summary

Flutter app scaffold created: package `com.otis.brooke.flags.around.the.world`, feature-folder architecture, all pinned dependencies, COPPA-compliant Android manifest, and CountryData/BoundingBox models wired to path_drawing.

## What Was Built

**Task 1: Flutter project scaffold**
- Created Flutter project via `flutter create --org com.otis.brooke.flags --project-name flags_around_the_world`
- Corrected `applicationId` and `namespace` in `android/app/build.gradle.kts` to `com.otis.brooke.flags.around.the.world`
- Added `package` attribute to `android/app/src/main/AndroidManifest.xml`
- Created correct Kotlin class path at `com/otis/brooke/flags/around/the/world/MainActivity.kt`
- Feature-folder directory skeleton with `.gitkeep` files in all feature and asset directories
- Replaced `pubspec.yaml` with exact pinned dependencies (flutter_riverpod 3.3.1, go_router 17.2.3, path_drawing 1.0.1, etc.)
- Created `l10n.yaml` for ARB → `lib/generated/l10n` code generation pipeline
- Created `lib/core/models/country_data.dart` with `CountryData` and `BoundingBox` classes
- Created `lib/core/data/country_data_service.dart` for JSON asset loading
- Replaced `lib/main.dart` with `ProviderScope` root
- Created `lib/app.dart` referencing `AppLocalizations` (unresolved until Plan 05)
- Added `lib/generated/` to `.gitignore`
- `flutter pub get` exits 0, `pubspec.lock` generated

**Task 2: Compliance baseline verification**
- No `firebase` references in pubspec.yaml or pubspec.lock
- No `INTERNET` permission in release manifest (`android/app/src/main/AndroidManifest.xml`)
- `INTERNET` permission present in debug manifest (`android/app/src/debug/AndroidManifest.xml`) — correct
- No `AD_ID` permission in any manifest
- `applicationId = "com.otis.brooke.flags.around.the.world"` confirmed in build.gradle.kts
- All 13 required directories exist

## Acceptance Criteria Results

| Criterion | Status |
|-----------|--------|
| `flutter pub get` exits 0 | PASS |
| `pubspec.lock` exists | PASS |
| applicationId = com.otis.brooke.flags.around.the.world | PASS |
| flutter_riverpod: ^3.3.1 in pubspec.yaml | PASS |
| `generate: true` in pubspec.yaml | PASS |
| No firebase in pubspec.yaml/lock | PASS |
| `synthetic-package: false` in l10n.yaml | DEVIATION (removed — deprecated) |
| No uses-permission in release manifest | PASS |
| ProviderScope in main.dart | PASS |
| parseSvgPathData in country_data.dart | PASS |
| loadString in country_data_service.dart | PASS |
| All required directories exist | PASS |
| APK build (skipped per plan) | SKIPPED (expected — requires Plan 05 l10n) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created minimal app_en.arb to unblock flutter pub get**
- **Found during:** Task 1, Step 11
- **Issue:** `flutter pub get` was failing with exit code 1 because `lib/core/l10n/app_en.arb` did not exist. Flutter's l10n generation runs during pub get when `l10n.yaml` and `generate: true` are present — it requires the template ARB file to exist.
- **Fix:** Created `lib/core/l10n/app_en.arb` with a single key (`scaffoldHomeLabel`) matching the one referenced in `lib/app.dart`. Plan 05 will populate this file with all required keys.
- **Files modified:** `lib/core/l10n/app_en.arb` (created)
- **Commit:** ff8daea (included in f13f4c3 — actually in Task 1 commit)

**2. [Rule 3 - Blocking] Removed deprecated `synthetic-package: false` from l10n.yaml**
- **Found during:** Task 1, Step 11
- **Issue:** Flutter 3.44.0 emitted a warning: "The argument 'synthetic-package' no longer has any effect and should be removed." This was being treated as an error in the pub get process.
- **Fix:** Removed `synthetic-package: false` line from `l10n.yaml`. The plan's acceptance criterion checks for `synthetic-package: false` but this is now unsupported — the intent (non-synthetic package) is the new default.
- **Files modified:** `l10n.yaml`
- **Commit:** f13f4c3

**3. [Rule 3 - Cleanup] Removed wrong Kotlin package directory**
- **Found during:** Post-commit review
- **Issue:** `flutter create` generated `MainActivity.kt` at `com/otis/brooke/flags/flags_around_the_world/` (wrong). Correct path is `com/otis/brooke/flags/around/the/world/`.
- **Fix:** Created correct path, committed the wrong path removal in a follow-up fix commit.
- **Commit:** ff8daea

## Known Stubs

- `lib/app.dart` references `AppLocalizations.of(context)!.scaffoldHomeLabel` — this resolves only after Plan 05 runs `flutter gen-l10n`. The import is intentionally unresolved at this stage per plan design.
- `lib/core/l10n/app_en.arb` contains only `scaffoldHomeLabel` key — Plan 05 adds all game-relevant keys.

## Threat Flags

None — this plan establishes scaffold infrastructure only. No network endpoints, no auth paths, no trust boundaries introduced.

## Self-Check: PASSED

Files created/exist:
- pubspec.yaml: FOUND
- pubspec.lock: FOUND
- l10n.yaml: FOUND
- android/app/build.gradle.kts: FOUND
- lib/main.dart: FOUND
- lib/app.dart: FOUND
- lib/core/models/country_data.dart: FOUND
- lib/core/data/country_data_service.dart: FOUND
- lib/core/l10n/app_en.arb: FOUND

Commits:
- f13f4c3: feat(01-02): create Flutter project scaffold with feature-folder architecture
- ff8daea: fix(01-02): remove old Kotlin package directory with wrong applicationId
