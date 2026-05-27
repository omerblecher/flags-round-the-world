# Phase 1: Foundation - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 delivers the complete development foundation: the Flutter project scaffold, the Python build-time data pipeline (Natural Earth SVG → `world_map_paths.json`), the Dart domain models, the i18n infrastructure (ARB + per-locale country name JSON), the walled-garden ad stub, and the offline compliance baseline. Every subsequent phase builds on these primitives.

**In scope:**
- Flutter project creation with feature-folder architecture
- Python pipeline: Natural Earth 1:110m → `world_map_paths.json` (ISO code, path array, bounding box, single centroid per country)
- Dart domain models: `CountryData`, `CountryPath`, `BoundingBox`
- `CountryDataService`: loads and parses `world_map_paths.json` and per-locale country name JSON
- i18n infrastructure: `flutter gen-l10n` ARB files for UI chrome + `assets/data/countries_XX.json` for country names
- Ad module walled garden: `AdLoadState` enum + `AdService` stub interface returning `AdLoadState.failed`
- Architecture enforcement test: asserts no game/session/map layer imports `features/ads/`
- Android manifest compliance baseline: no dangerous permissions, no internet permission
- Full Dart unit test coverage for pipeline output and i18n service (success criteria)

**Out of scope:**
- Any UI rendering (Phase 3)
- `GameSessionNotifier` state machine (Phase 2)
- Real AdMob wiring (Phase 6)
- Audio assets (Phase 4)
- Accessibility and orientation (Phase 5)

</domain>

<decisions>
## Implementation Decisions

### Flutter Project Structure
- **D-01:** Use a **feature-folder skeleton** for `lib/`: `lib/features/game/`, `lib/features/map/`, `lib/features/ads/`, `lib/core/`. Directories for phases 2–6 created with `.gitkeep` files in Phase 1 so future phases have clean homes.
- **D-02:** `lib/core/` contains: `lib/core/models/` (domain models), `lib/core/data/` (asset-loading services), `lib/core/l10n/` (ARB files and locale wiring).
- **D-03:** Full **assets skeleton** established in Phase 1: `assets/flags/` (195+ SVGs from lipis/flag-icons), `assets/map/` (world_map_paths.json), `assets/data/` (countries_en.json, countries_es.json), `assets/audio/` (.gitkeep). All directories registered in `pubspec.yaml`.

### Data Pipeline & Country Model
- **D-04:** The Dart `CountryData` model uses a **single entry per ISO alpha-2 code** with `List<String> pathStrings` for all polygons. Countries with disconnected islands/exclaves (USA, Russia, France, Norway) are grouped under their ISO code. Dropping on Alaska = correct for USA.
- **D-05:** Overseas territories (French Guiana, Puerto Rico, Hong Kong) are rendered under their parent country's ISO code, not as separate gameplay entities. They appear on the map but share the parent's flag target.
- **D-06:** Tiny island nations (Tuvalu, Nauru, Maldives) are included in the dataset at their real geographic size. Phase 3 applies a minimum hit-detection radius (~30% of country SVG size per GAME-02) to make them reachable — the data model stores their natural geometry.
- **D-07:** The Python pipeline computes a **single centroid per ISO code** (not per polygon). Used for country name label placement in Phase 3. Centroid is computed from the geographic center or largest polygon's bounding box.

### Country Dataset (196 countries)
- **D-08:** The game covers **196 countries**: UN-193 member states + Holy See (Vatican) + Taiwan (Republic of China, ISO: TW) + Kosovo (ISO: XK). Western Sahara and Palestine are excluded from gameplay (may appear as non-droppable geography on the map).
- **D-09:** **All references to "195 countries" throughout project docs, requirements, and success criteria MUST be updated to "196 countries."** This applies to: REQUIREMENTS.md, ROADMAP.md Phase 1 success criterion 2 and 4, PROJECT.md, CLAUDE.md.
- **D-10:** Taiwan is included under ISO code `TW` with its Republic of China flag from lipis/flag-icons. Note: if the China App Store is ever targeted in a future version, Taiwan's inclusion would need editorial treatment.

### Ad Module Walled Garden
- **D-11:** The `features/ads/` stub is created in **Phase 1**, alongside the project scaffold. It exposes: `AdLoadState` (sealed class/enum with `loaded` and `failed` states) + `AdService` abstract interface. The stub implementation always returns `AdLoadState.failed`. Phase 6 provides the real implementation.
- **D-12:** Phase 1 includes an **architecture enforcement test** (`test/architecture/ads_isolation_test.dart`) that reads all Dart files in `lib/features/game/`, `lib/features/map/`, and `lib/core/` and asserts zero imports referencing `features/ads/`. This test runs in CI and enforces the walled-garden constraint from the first commit.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Requirements & Architecture
- `.planning/ROADMAP.md` §Phase 1 — Phase goal, requirements list (COMP-01, COMP-03, I18N-01, I18N-02, I18N-03), success criteria (note: "195" must be read as "196")
- `.planning/REQUIREMENTS.md` §I18N, §Infrastructure & Compliance — Full requirement text for Phase 1 scope
- `CLAUDE.md` §Critical Architecture Decisions — Locked decisions: Flutter+CustomPainter+InteractiveViewer, pre-processed JSON pipeline, no Firebase, walled-garden ad layer

### Research & Technical Guidance
- `.planning/research/STACK.md` §1 (SVG map rendering), §7 (i18n), §10 (testing) — Technology choices, package list, pubspec starting point
- `.planning/research/PITFALLS.md` §Pitfall C-4, C-5 (Firebase COPPA), §Pitfall C-7 (GAID/AD_ID), §Pitfall M-3 (country name staleness), §Pitfall m-5 (disputed territories), §Pitfall m-3 (flutter_svg version) — Compliance and technical landmines for Phase 1

### External Data Sources
- Natural Earth Admin-0 Countries dataset (ne_110m_admin_0_countries) — CC0, source for map geometry
- lipis/flag-icons (github.com/lipis/flag-icons) — MIT, 196 target flags by ISO alpha-2 code
- Unicode CLDR or Wikidata CC0 dumps — source for localized country name translations (researcher to confirm best approach)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- No existing code — this is a greenfield Flutter project creation.

### Established Patterns
- No existing patterns — Phase 1 establishes the conventions all future phases follow.

### Integration Points
- `lib/core/models/CountryData` → used by Phase 2's `CountryDataProvider` (Riverpod) and Phase 3's `WorldMapPainter`
- `lib/core/data/CountryDataService` → loaded via Riverpod provider in Phase 2
- `lib/features/ads/AdService` stub → consumed (but never imported directly) by Phase 2's `GameSessionNotifier`
- `assets/map/world_map_paths.json` → loaded in Phase 2, rendered in Phase 3
- `lib/core/l10n/` ARB files → extended with all UI strings in Phases 2–5

</code_context>

<specifics>
## Specific Ideas

- **Package: lipis/flag-icons** — flags at `assets/flags/<iso_alpha2>.svg`, directory-registered in pubspec. Researcher should verify all 196 target ISO codes (including Kosovo `XK` and Taiwan `TW`) exist in the lipis/flag-icons repo.
- **Natural Earth 1:110m scale** — confirmed for the pipeline. Balances polygon detail vs. APK size. Researcher to determine exact processing approach (geopandas/shapely from shapefile vs. mapshaper CLI to SVG) since Natural Earth ships shapefiles not SVG natively.
- **countries_es.json in Phase 1** — the Phase 1 success criterion explicitly requires proving the locale-swap architecture works (adding countries_es.json serves Spanish names without Dart changes). Phase 1 must include at least one non-English locale file.
- **"196" update** — All downstream docs and tests must use 196. The success criterion "assert exactly 195 entries" becomes "assert exactly 196 entries."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Foundation*
*Context gathered: 2026-05-27*
