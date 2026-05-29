---
phase: 05
plan: 02
subsystem: map-canvas
tags: [label-culling, hit-detection, accessibility, vis-01, vis-02, accs-03]
dependency_graph:
  requires: [05-01]
  provides: [WorldMapPainter.viewScale, hitTest._kMinScreenArea, viewScale-plumbing-ready]
  affects: [world_map_painter, hit_detection]
tech_stack:
  added: []
  patterns: [opacity-via-Color.fromARGB-alpha, bbox-area-threshold-before-diagonal]
key_files:
  created: []
  modified:
    - lib/features/map/world_map_painter.dart
    - lib/features/map/hit_detection.dart
decisions:
  - "Removed unused _labelColor constant when Color.fromARGB(labelAlpha, ...) replaced it — avoids analyzer warning"
  - "_expandedBbox area check uses scale param threaded from hitTest; _primaryContains signature extended with scale named param"
  - "Area check short-circuits before diagonal check — guarantees 48dp target even when diagonal-based logic would skip expansion"
metrics:
  duration: 420s
  completed: "2026-05-29"
  tasks: 2
  files: 2
---

# Phase 5 Plan 02: Canvas and Hit Detection Fixes Summary

VIS-01 zoom-dependent label culling and VIS-02 viewport-area hit target threshold — WorldMapPainter suppresses micro-state and small-country labels at low zoom via opacity, and hitTest guarantees a physical 48dp tap target for every country at any scale.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add viewScale param and opacity-based label culling to WorldMapPainter | faba4ac | lib/features/map/world_map_painter.dart |
| 2 | Add viewport-area threshold to hitTest | 91a6143 | lib/features/map/hit_detection.dart |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused _labelColor constant**
- **Found during:** Task 1 (flutter analyze reported unused_element warning)
- **Issue:** `_labelColor = Color(0xFFFFFFFF)` was declared but the new `_drawLabel` implementation uses `Color.fromARGB(labelAlpha, 0xFF, 0xFF, 0xFF)` directly, making the constant unreferenced.
- **Fix:** Removed the `_labelColor` constant declaration.
- **Files modified:** `lib/features/map/world_map_painter.dart`
- **Commit:** faba4ac

## Verification Results

- flutter analyze lib/features/map/world_map_painter.dart: PASS (0 issues)
- flutter analyze lib/features/map/hit_detection.dart: PASS (0 issues)
- flutter analyze lib/: PASS (0 issues)
- world_map_painter_test.dart: PASS (2/2 green)
- hit_detection_test.dart: PASS (6/6 green)

## Known Stubs

None — both changes are fully functional implementations. `WorldMapPainter.viewScale` defaults to 1.0 and is not yet wired from `MapScreen._currentScale`; Plan 05-04 will pass `viewScale: _currentScale` at the call site per the plan's `key_links`.

## Threat Flags

None — viewScale is bounded by InteractiveViewer's clamp [0.08, 32.0]; scale in hitTest comes from `controller.getMaxScaleOnAxis()` (non-negative). Both threat boundaries (T-05-02-01, T-05-02-02) are addressed as designed.

## Self-Check: PASSED

- lib/features/map/world_map_painter.dart: FOUND
- lib/features/map/hit_detection.dart: FOUND
- Commit faba4ac: FOUND
- Commit 91a6143: FOUND
