# Deferred Items — Phase 5

## Pre-existing Test Failures (out of scope for Phase 5)

### Norway/Sweden centroid conflict (all_countries_test.dart)

**Discovered during:** Plan 05-06, Task 3 full test run
**Tests failing:**
- `hit detection — centroid drop all 196 centroids hit their own country at scale 0.18`
- `hit detection — centroid drop all 196 centroids hit their own country at scale 0.5`
- `hit detection — centroid drop all 196 centroids hit their own country at scale 1.0`
- `hit detection — centroid drop all 196 centroids hit their own country at scale 2.0`
- `hit detection — centroid drop all 196 centroids hit their own country at scale 4.0`

**Root cause:** Norway's SVG-derived centroid point (`no`) falls within Sweden's expanded bounding box at all zoom scales, so `hitTest` returns `'se'` instead of `'no'`.

**Why not fixed:** Pre-existing before Phase 5 (confirmed by reverting to pre-05-06 state and reproducing the failures). Out of scope per deviation rule scope boundary.

**Recommended fix (for Phase 6 or bug-fix phase):** Adjust Norway's centroid in `world_map_paths.json` to move it inland away from Sweden's bbox, or add an explicit centroid override in the hit detection pipeline.
