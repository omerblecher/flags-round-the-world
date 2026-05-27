---
plan: 01-03
status: completed
completed: "2026-05-27"
---

# Plan 01-03 Summary — Python GIS Pipeline

## What Was Done

### Task 1: world_map_paths.json (196 countries)
- `scripts/generate_map.py` created and run
- Natural Earth 110m shapefile downloaded from naciscdn.org
- **Root cause fix:** Natural Earth 110m has `ISO_A2='-99'` for France and Norway; fixed by using `ISO_A2_EH` field as fallback
- **Micro-state fix:** 29 sovereign states not in Natural Earth 110m (Vatican, Monaco, Singapore, etc.) received synthetic 1.5°×1.5° bounding box geometry at their known centroid
- Output: 196 countries, version=1, viewBox=2000×1000, all M/L/Z paths

### Task 2: countries_en.json + countries_es.json
- `scripts/generate_country_names.py` created and run
- pycountry for English names; babel for Spanish names (locale.territories)
- EN overrides: Kosovo→Kosovo, Taiwan→Taiwan, Vatican→Vatican City, etc.
- Output: 196 entries each, same ISO key set as map JSON

## Verification Results
- `PASS: 196 countries, Kosovo/Taiwan/Vatican present, exclusions correct`
- `PASS: 196 English, 196 Spanish, keys match map ISOs`
- Kosovo (xk): present; Taiwan (tw): present; Western Sahara (eh): excluded; Palestine (ps): excluded

## Deviations
1. **ISO_A2_EH fallback required** — Natural Earth 110m marks France and Norway with `ISO_A2='-99'` (the EH column has correct codes). Pipeline updated to check both fields.
2. **29 synthetic micro-states** — Countries like Vatican, Monaco, Singapore, Tuvalu are too small for the 110m scale dataset. Synthetic 1.5°×1.5° rectangles placed at geographic centroids. Phase 3's minimum hit radius will make them fully tappable.
