---
phase: 04-game-modes-scoring
plan: 03
subsystem: map-rendering, game-ui, data-layer
tags: [flutter, dart, riverpod, flag-tray, world-map-painter, flag-sequence, grand-master]

# Dependency graph
requires:
  - phase: 03-map-rendering-drag-drop
    provides: WorldMapPainter with countries/matchedIsoCodes params, FlagTray with currentIsoCode/countryName/cardKey
  - plan: 04-01
    provides: useHint(), ARB strings, RED stubs for sequence contracts

provides:
  - WorldMapPainter showLabels/countryNames params for mode-specific label rendering
  - FlagTray showName/hintsRemaining/onHintPressed params and hint button UI
  - flag_sequence.dart with buildFlagSequence and buildGrandMasterSequence top-level functions
  - assets/data/grand_master_order.json with 210 deduplicated ISO codes
  - highScoreRepositoryProvider FutureProvider in high_score_repository.dart
  - countryNamesProvider FutureProvider in country_data_service.dart

affects:
  - 04-04 (Wave 3): MapScreen wire-up uses all these new params and providers; no further changes to these files needed

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "showLabels/countryNames default params: backward-compatible additions to CustomPainter"
    - "FlagTray static _noOp default: avoids required param breaking change while Wave 3 wires real callbacks"
    - "buildGrandMasterSequence: loads JSON asset, de-duplicates, filters to known ISOs, appends missing codes alphabetically"
    - "FutureProvider pattern: both highScoreRepositoryProvider and countryNamesProvider follow same async-init pattern"

key-files:
  created:
    - lib/features/map/flag_sequence.dart
    - assets/data/grand_master_order.json
  modified:
    - lib/features/map/world_map_painter.dart
    - lib/features/game/flag_tray.dart
    - lib/core/data/high_score_repository.dart
    - lib/core/data/country_data_service.dart
    - lib/features/map/map_screen.dart
    - test/features/map/flag_sequence_test.dart

key-decisions:
  - "FlagTray new params use defaults (showName=true, hintsRemaining=2, onHintPressed=_noOp) so existing map_screen.dart call site continues to compile during Wave 2 before 04-04 wires real values"
  - "grand_master_order.json de-duplicated at creation time (SS appeared twice in plan spec); buildGrandMasterSequence also de-duplicates at runtime as belt-and-suspenders"
  - "map_screen.dart buildFlagSequence removed entirely (not re-exported); import from flag_sequence.dart is sufficient for all call sites"
  - "countryNamesProvider uses const Locale('en') as default; Plan 04-04 can override with device locale"

# Metrics
duration: 20min
completed: 2026-05-29
---

# Phase 4 Plan 03: Data-Layer and Widget Extensions Summary

**WorldMapPainter/FlagTray widget params extended; flag_sequence.dart extracted with buildGrandMasterSequence; grand_master_order.json asset created; highScoreRepositoryProvider and countryNamesProvider added**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-05-29T04:31:00Z
- **Completed:** 2026-05-29T04:51:38Z
- **Tasks:** 2
- **Files modified:** 6 (+ 2 created)

## Accomplishments

### Task 1: WorldMapPainter + FlagTray extensions

- WorldMapPainter gains `showLabels` (default `true`) and `countryNames` (default `const {}`) params
- Label loop wrapped in `if (showLabels)`; labels now display `countryNames[isoCode] ?? isoCode`
- `shouldRepaint` updated to check `showLabels` and `!identical(old.countryNames, countryNames)`
- FlagTray gains `showName` (default `true`), `hintsRemaining` (default `2`), `onHintPressed` (default static `_noOp`)
- `_cardShell()` country name Padding wrapped in `if (widget.showName)` conditional
- `build()` replaced bare `AnimatedBuilder` with `Row([_buildHintButton(), SizedBox(8), AnimatedBuilder(...)])` inside `Center`
- `_buildHintButton()` added as `ElevatedButton.icon` with lightbulb icon and `Hint ×{count}` label

### Task 2: flag_sequence.dart + asset + providers

- `lib/features/map/flag_sequence.dart` created with `buildFlagSequence` and `buildGrandMasterSequence`
- `buildGrandMasterSequence` loads JSON, de-duplicates, filters to known ISOs, appends missing codes alphabetically
- `assets/data/grand_master_order.json` created — 210-element deduplicated array starting with JP (SS duplicate from plan spec removed)
- `highScoreRepositoryProvider = FutureProvider<HighScoreRepository>` appended to high_score_repository.dart
- `countryNamesProvider = FutureProvider<Map<String, String>>` appended to country_data_service.dart
- `map_screen.dart` `buildFlagSequence` implementation removed; import added from `flag_sequence.dart`
- `flag_sequence_test.dart` import updated from `map_screen` to `flag_sequence`

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | WorldMapPainter showLabels/countryNames + FlagTray showName/hint | c9b3711 | world_map_painter.dart, flag_tray.dart |
| 2 | Extract flag_sequence.dart, add JSON asset, add providers | 494ec2f | flag_sequence.dart (new), grand_master_order.json (new), high_score_repository.dart, country_data_service.dart, map_screen.dart, flag_sequence_test.dart |

## Verification Results

- `flutter analyze lib/features/map/world_map_painter.dart lib/features/game/flag_tray.dart` — No issues
- `flutter analyze lib/features/map/flag_sequence.dart lib/core/data/high_score_repository.dart lib/core/data/country_data_service.dart` — No issues
- `flutter test test/features/map/flag_sequence_test.dart` — 3/3 PASSED
- `flutter test test/architecture/ads_isolation_test.dart` — 1/1 PASSED (GREEN)
- `pubspec.yaml assets: assets/data/` — confirmed covering grand_master_order.json

## Deviations from Plan

**1. [Rule 1 - Bug] grand_master_order.json — removed duplicate SS code**
- **Found during:** Task 2, pre-creation check
- **Issue:** The plan's canonical ISO array contained "SS" twice (South Sudan appeared at both position ~101 and near the end of the list)
- **Fix:** Kept only the first occurrence (position 101, in the African-nations region). The resulting JSON has 210 entries instead of 211. `buildGrandMasterSequence` also de-duplicates at runtime as belt-and-suspenders
- **Files modified:** assets/data/grand_master_order.json
- **Commit:** 494ec2f

## Known Stubs

None — all params have functional defaults. The hint button fires `_noOp` until Plan 04-04 wires the real `useHint()` callback.

| Component | Stub | Resolving Plan |
|-----------|------|----------------|
| FlagTray.onHintPressed | static _noOp() {} default | 04-04 (MapScreen wire-up) |
| FlagTray.hintsRemaining | default 2 | 04-04 (wired from gameSessionProvider) |
| WorldMapPainter.countryNames | default const {} (shows ISO codes) | 04-04 (wired from countryNamesProvider) |

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries introduced. `grand_master_order.json` is a bundled asset accessed only via `rootBundle`; `buildGrandMasterSequence` filters the asset to known ISO codes only.

## Self-Check: PASSED

- `lib/features/map/flag_sequence.dart` — FOUND
- `assets/data/grand_master_order.json` — FOUND (contains "JP" at position 0)
- `lib/core/data/high_score_repository.dart` contains `highScoreRepositoryProvider` — FOUND
- `lib/core/data/country_data_service.dart` contains `countryNamesProvider` — FOUND
- Task 1 commit c9b3711 — FOUND in git log
- Task 2 commit 494ec2f — FOUND in git log
- 3/3 flag_sequence tests PASSED
- 1/1 ads_isolation test PASSED

---
*Phase: 04-game-modes-scoring*
*Completed: 2026-05-29*
