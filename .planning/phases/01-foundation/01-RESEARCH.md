# Phase 1: Foundation - Research

**Researched:** 2026-05-27
**Domain:** Flutter project scaffold, Python GIS data pipeline, Dart domain models, i18n infrastructure, COPPA/offline compliance baseline
**Confidence:** HIGH (architecture and approach); MEDIUM (some package version details)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Feature-folder skeleton: `lib/features/game/`, `lib/features/map/`, `lib/features/ads/`, `lib/core/`. Directories for phases 2–6 created with `.gitkeep` files.
- **D-02:** `lib/core/` contains: `lib/core/models/`, `lib/core/data/`, `lib/core/l10n/`.
- **D-03:** Full assets skeleton in Phase 1: `assets/flags/` (195+ SVGs), `assets/map/` (`world_map_paths.json`), `assets/data/` (countries_en.json, countries_es.json), `assets/audio/` (.gitkeep). All registered in `pubspec.yaml`.
- **D-04:** Single entry per ISO alpha-2 code with `List<String> pathStrings` for all polygons (islands/exclaves grouped).
- **D-05:** Overseas territories rendered under parent country's ISO code.
- **D-06:** Tiny island nations included at natural geographic size; Phase 3 applies minimum hit radius.
- **D-07:** Single centroid per ISO code (not per polygon), from geographic center or largest polygon's bounding box.
- **D-08:** 196 countries: UN-193 + Holy See + Taiwan (TW) + Kosovo (XK). Western Sahara and Palestine excluded from gameplay.
- **D-09:** All references to "195 countries" updated to "196 countries" everywhere.
- **D-10:** Taiwan included under ISO code `TW` with Republic of China flag from lipis/flag-icons.
- **D-11:** `features/ads/` stub created in Phase 1: `AdLoadState` (sealed class/enum with `loaded` and `failed` states) + `AdService` abstract interface. Stub always returns `AdLoadState.failed`.
- **D-12:** Architecture enforcement test `test/architecture/ads_isolation_test.dart` reads all Dart files in `lib/features/game/`, `lib/features/map/`, and `lib/core/` and asserts zero imports referencing `features/ads/`.

### Claude's Discretion

None documented — all Phase 1 decisions were locked in the discussion.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within Phase 1 scope.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMP-01 | App does not collect, transmit, or store any device identifiers, precise location, or personal data | No Firebase, no analytics SDK, no INTERNET permission in release manifest |
| COMP-03 | All game assets bundled on-device; app functions fully offline after install | All flags, map JSON, and country name JSON bundled as Flutter assets; no network calls |
| I18N-01 | All UI chrome strings externalized to ARB files via `flutter gen-l10n` | `flutter gen-l10n` + `l10n.yaml` setup; ARB for chrome strings only |
| I18N-02 | All 196 country names stored in per-locale JSON asset files loaded at runtime | `countries_en.json` + `countries_es.json` in `assets/data/`; loaded via `rootBundle` |
| I18N-03 | App supports adding a new language by adding locale JSON file and ARB entry — no Dart code changes | Architecture: `CountryDataService` falls back to English; ARB locale delegation is automatic |

</phase_requirements>

---

## Summary

Phase 1 is a greenfield project creation phase. The primary technical challenges are: (1) the Python SVG pipeline — Natural Earth ships shapefiles, not SVG, so the pipeline must use geopandas+shapely to read the shapefile directly and emit SVG path strings; (2) verified presence of all 196 target ISO codes in lipis/flag-icons; and (3) the i18n architecture, which has a breaking change in Flutter 3.32 (synthetic package removed — `synthetic-package: false` is now the non-deprecated approach).

The research confirms the prior STACK.md and ARCHITECTURE.md findings are substantially correct, with three key updates: Riverpod is now at version 3.x (major bump from the 2.x documented in STACK.md), `flutter gen-l10n` changed its synthetic package behavior in Flutter 3.32, and the `path_drawing` package (not `dart:ui` directly) provides `parseSvgPathData`. Kosovo (XK) and Taiwan (TW) are both confirmed present in lipis/flag-icons. Natural Earth's ISO_A2 field has known quirks for Kosovo that the pipeline must work around using the `ADM0_A3` or `SOV_A3` fallback field.

**Primary recommendation:** Use geopandas+shapely directly from the Natural Earth 110m shapefile (no intermediate SVG step). Output SVG path strings using only M/L/Z commands (no arcs or curves — shapefiles only have linear polygon boundaries). Parse those strings in Dart using the `path_drawing` package's `parseSvgPathData`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Python SVG pipeline | Build-time script | — | Runs offline before Flutter build; no runtime dependency |
| Dart domain models (`CountryData`, `BoundingBox`) | `lib/core/models/` | — | Cross-cutting data; no feature owns it |
| `CountryDataService` (JSON loading) | `lib/core/data/` | — | Infrastructure service; shared by game and map features |
| Flag SVG assets | `assets/flags/` bundled | — | Static offline bundle; no network |
| ARB i18n (UI chrome) | `lib/l10n/` (gen-l10n) | — | Flutter SDK tooling owns code generation |
| Country name JSON (per-locale) | `assets/data/` bundled | `CountryDataService` (runtime load) | Data not code; loaded at runtime based on locale |
| Ad stub | `lib/features/ads/` | — | Walled garden; zero game logic imports |
| Architecture enforcement test | `test/architecture/` | — | Build-time assertion; dart:io file walk |
| Android manifest baseline | `android/app/src/main/` | `android/app/src/debug/` | Release manifest clean; INTERNET only in debug overlay |

---

## Standard Stack

### Core (Phase 1)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | ^3.3.1 | State management framework | Flutter team endorsed; current major is 3.x [VERIFIED: pub.dev] |
| `riverpod_annotation` | ^4.0.2 | Code-gen annotations for `@riverpod` | Companion to flutter_riverpod 3.x [VERIFIED: pub.dev] |
| `flutter_svg` | ^2.3.0 | SVG flag rendering | Flutter team publisher; latest stable [VERIFIED: pub.dev] |
| `go_router` | ^17.2.3 | Declarative navigation | Flutter team publisher; official recommendation [VERIFIED: pub.dev] |
| `path_drawing` | ^1.0.1 | `parseSvgPathData` → `dart:ui Path` | Standard Flutter SVG path parsing; no other pub.dev package does this correctly [VERIFIED: pub.dev] |
| `shared_preferences` | ^2.5.5 | Score and settings persistence | Flutter team publisher [VERIFIED: pub.dev] |
| `intl` | ^0.20.2 | i18n primitives; used by gen-l10n | Dart team publisher [VERIFIED: pub.dev] |

### Dev Dependencies (Phase 1)

| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| `riverpod_generator` | ^4.0.3 | build_runner code gen for @riverpod | Required companion to riverpod_annotation 4.x [VERIFIED: pub.dev] |
| `build_runner` | ^2.15.0 | Dart code generation runner | Standard; tools.dart.dev publisher [VERIFIED: pub.dev] |
| `mocktail` | ^1.0.5 | Mocking in unit tests | Maintained by felangel.dev; no code-gen required [VERIFIED: pub.dev] |
| `flutter_test` | SDK | Unit + widget test framework | Flutter SDK bundled |
| `integration_test` | SDK | On-device integration tests | Flutter SDK bundled |

### Python Pipeline Dependencies

| Library | Purpose | Installation |
|---------|---------|--------------|
| `geopandas` | Read Natural Earth shapefile; project coordinates | `pip install geopandas` |
| `shapely` | Geometry operations; polygon → coordinate extraction | Installed as geopandas dependency |
| `pyproj` | Coordinate reference system transforms | Installed as geopandas dependency |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `path_drawing` | `flutter_svg` parseSvgPathData internal | flutter_svg's internal parser is private API; path_drawing is the public extraction |
| `geopandas` | `pyshp` (pypi: pyshp) | pyshp reads shapefile but has no geometry projection; geopandas+shapely handles coordinate transforms in one pipeline |
| `geopandas` | mapshaper CLI → parse SVG | Extra toolchain step; mapshaper not on PyPI; geopandas is pure Python |
| `mocktail` | `mockito` | mockito requires code generation; mocktail is zero-codegen |
| `go_router` | Navigator 2.0 directly | Navigator 2.0 requires manual implementation; go_router is the Flutter team's declared standard |

**Installation (pubspec.yaml — Phase 1 minimal):**
```yaml
environment:
  sdk: '>=3.7.0 <4.0.0'
  flutter: '>=3.32.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # SVG rendering
  flutter_svg: ^2.3.0

  # SVG path string → dart:ui Path
  path_drawing: ^1.0.1

  # State management
  flutter_riverpod: ^3.3.1
  riverpod_annotation: ^4.0.2

  # Navigation
  go_router: ^17.2.3

  # Storage (Phase 1: only for ad-state stub; used more in Phase 2)
  shared_preferences: ^2.5.5

  # i18n
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  riverpod_generator: ^4.0.3
  build_runner: ^2.15.0
  mocktail: ^1.0.5

flutter:
  generate: true          # REQUIRED for flutter gen-l10n with synthetic-package: false
  uses-material-design: true
  assets:
    - assets/flags/
    - assets/map/
    - assets/data/
    - assets/audio/
```

---

## Package Legitimacy Audit

> Note: These are Dart/Flutter packages verified on pub.dev (not PyPI). The `slopcheck` tool checks PyPI and correctly flagged these as non-existent on PyPI — that is expected. Legitimacy is verified directly via pub.dev with publisher verification badges.

| Package | Registry | Age | Publisher | Verified Publisher | Disposition |
|---------|----------|-----|-----------|--------------------|-------------|
| `flutter_riverpod` 3.3.1 | pub.dev | 5+ yrs | dash-overflow.net | Yes | Approved |
| `riverpod_annotation` 4.0.2 | pub.dev | 3+ yrs | dash-overflow.net | Yes | Approved |
| `riverpod_generator` 4.0.3 | pub.dev | 3+ yrs | dash-overflow.net | Yes | Approved |
| `flutter_svg` 2.3.0 | pub.dev | 5+ yrs | flutter.dev | Yes | Approved |
| `go_router` 17.2.3 | pub.dev | 3+ yrs | flutter.dev | Yes | Approved |
| `path_drawing` 1.0.1 | pub.dev | 4+ yrs | dnfield.dev | Yes | Approved |
| `shared_preferences` 2.5.5 | pub.dev | 5+ yrs | flutter.dev | Yes | Approved |
| `intl` 0.20.2 | pub.dev | 8+ yrs | dart.dev | Yes | Approved |
| `build_runner` 2.15.0 | pub.dev | 5+ yrs | tools.dart.dev | Yes | Approved |
| `mocktail` 1.0.5 | pub.dev | 3+ yrs | felangel.dev | Yes | Approved |
| `geopandas` (Python) | PyPI | 10+ yrs | geopandas org | — | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none

*Packages above are all from verified, long-standing publishers on their respective registries. No slopcheck concerns.*

---

## Architecture Patterns

### System Architecture Diagram

```
BUILD TIME (Python script — runs once, output committed to git):
  Natural Earth .shp → geopandas.read_file()
                      → shapely geometry per country row
                      → project from WGS-84 to equirectangular
                      → emit M/L/Z path string per polygon ring
                      → group by ISO code
                      → compute bounding box + centroid
                      → write world_map_paths.json
                             │
                             ▼
ASSETS (bundled at build time):
  assets/map/world_map_paths.json   ← map geometry + ISO codes + centroids
  assets/data/countries_en.json     ← canonical English country names
  assets/data/countries_es.json     ← Spanish overrides
  assets/flags/xk.svg               ← one per ISO code (196 total)
  assets/flags/tw.svg
  ...
                             │
                             ▼
APP STARTUP (once, on first load):
  rootBundle.loadString('assets/map/world_map_paths.json')
  → JSON decode → List<CountryData>
  → path_drawing.parseSvgPathData(pathString) → dart:ui Path
  → stored in CountryDataService (cached)

  rootBundle.loadString('assets/data/countries_en.json')
  + rootBundle.loadString('assets/data/countries_${locale}.json')
  → merged Map<String, Country>
  → stored in CountryDataService

RIVERPOD PROVIDERS (wrapping services):
  CountryDataProvider  → provides List<CountryData>  (Phase 2+)
  CountryNamesProvider → provides Map<String, String> (Phase 2+)

PHASE 1 DELIVERABLES (no widget tree):
  lib/core/models/          CountryData, BoundingBox, CountryPath
  lib/core/data/            CountryDataService (loads + parses)
  lib/features/ads/         AdLoadState enum + AdService stub
  lib/l10n/                 app_en.arb, app_es.arb + l10n.yaml
  test/architecture/        ads_isolation_test.dart
  test/unit/                country_data_service_test.dart
  scripts/generate_map.py   Python pipeline
```

### Recommended Project Structure (Phase 1 creates all of this)

```
flags_around_the_world/
├── scripts/
│   └── generate_map.py          # Python pipeline: shapefile → world_map_paths.json
├── assets/
│   ├── flags/                   # 196 SVG files (ad.svg ... zw.svg + xk.svg, tw.svg)
│   ├── map/
│   │   └── world_map_paths.json # Pipeline output (committed to git)
│   ├── data/
│   │   ├── countries_en.json    # Canonical country names
│   │   └── countries_es.json    # Spanish overrides
│   └── audio/
│       └── .gitkeep
├── lib/
│   ├── main.dart                # Minimal: WidgetsFlutterBinding + runApp(ProviderScope)
│   ├── app.dart                 # MaterialApp with GoRouter + localizations delegates
│   ├── core/
│   │   ├── models/
│   │   │   ├── country_data.dart        # CountryData, BoundingBox, CountryPath
│   │   │   └── country.dart             # Country (name, capital, continent)
│   │   ├── data/
│   │   │   └── country_data_service.dart # Loads + parses JSON assets
│   │   └── l10n/
│   │       ├── app_en.arb
│   │       └── app_es.arb
│   ├── features/
│   │   ├── game/
│   │   │   └── .gitkeep
│   │   ├── map/
│   │   │   └── .gitkeep
│   │   ├── ads/
│   │   │   ├── ad_load_state.dart       # sealed class / enum
│   │   │   └── ad_service.dart          # abstract interface + stub impl
│   │   └── home/
│   │       └── .gitkeep
│   └── l10n/                    # gen-l10n output (generated, not committed)
├── test/
│   ├── architecture/
│   │   └── ads_isolation_test.dart
│   └── unit/
│       └── country_data_service_test.dart
├── android/
│   └── app/src/
│       ├── main/AndroidManifest.xml     # No INTERNET, no dangerous permissions
│       └── debug/AndroidManifest.xml    # INTERNET permission (debug only, for hot reload)
├── l10n.yaml
├── pubspec.yaml
└── analysis_options.yaml
```

### Pattern 1: Python Pipeline — Shapefile to JSON

**What:** Reads Natural Earth ne_110m_admin_0_countries.shp directly with geopandas; reprojects to equirectangular (EPSG:4326 → equirectangular pixel space); emits M/L/Z SVG path strings per polygon; groups by ISO code; computes bounding box and centroid; writes JSON.

**When to use:** Build-time only. Run once; commit output to git. Re-run when Natural Earth releases updated data.

**Key consideration — ISO code field:** The `ISO_A2` field in Natural Earth has known `-99` placeholder values for some disputed/non-UN territories including Kosovo. The pipeline must use a fallback field lookup:

```python
# Source: training knowledge of Natural Earth attribute schema; verified via GitHub issues
def get_iso_code(row):
    iso = row.get('ISO_A2', '-99')
    if iso == '-99' or not iso or len(iso) != 2:
        # Fall back to ADM0_A3 (3-letter) then SOV_A3
        # Kosovo has ISO_A2 = -99 but can be matched by NAME or ADM0_A3 = 'KOS'
        name = row.get('NAME', '')
        if 'Kosovo' in name:
            return 'XK'
        if 'Taiwan' in name:
            return 'TW'
        # Other disputed/special cases
        return None  # Skip if truly unknown
    return iso.lower()
```

**Coordinate projection approach:**
```python
import geopandas as gpd
import json
import math

def polygon_to_path_string(polygon, scale_x, scale_y, origin_x, origin_y):
    """Convert a Shapely Polygon to an SVG M/L/Z path string."""
    coords = list(polygon.exterior.coords)
    if len(coords) < 3:
        return None
    parts = []
    for i, (lon, lat) in enumerate(coords[:-1]):  # skip repeated last point
        # Equirectangular projection: lon maps to x, lat maps to y (flipped)
        x = round((lon - origin_x) * scale_x, 2)
        y = round((origin_y - lat) * scale_y, 2)  # Y flips for SVG
        cmd = 'M' if i == 0 else 'L'
        parts.append(f'{cmd}{x},{y}')
    parts.append('Z')
    return ' '.join(parts)
```

**Output JSON schema:**
```json
{
  "version": 1,
  "viewBox": { "width": 2000, "height": 1000 },
  "countries": [
    {
      "iso": "de",
      "paths": ["M100,200 L150,220 L130,240 Z"],
      "boundingBox": { "x": 100, "y": 200, "w": 50, "h": 40 },
      "centroid": { "x": 128, "y": 220 }
    }
  ]
}
```

### Pattern 2: Dart Path Parsing (`path_drawing`)

**What:** The `parseSvgPathData` function from `package:path_drawing` converts an SVG path string into a `dart:ui Path` object. This is the standard Flutter approach — `dart:ui` does NOT expose `parseSvgPathData` directly.

**Key constraint:** `path_drawing` supports M, m, L, l, H, h, V, v, C, c, Q, q, S, s, T, t, Z, z. Arc commands (A/a) are handled by approximation via cubic Bézier curves. Since Natural Earth shapefile geometry is all linear (no curves), the pipeline only emits M/L/Z — this is the safe path that avoids any arc approximation issues. [ASSUMED — path_drawing arc support inferred from source structure; confirmed M/L/Z is sufficient for shapefile polygons]

```dart
// Source: pub.dev/packages/path_drawing documentation
import 'package:path_drawing/path_drawing.dart';

Path pathFromSvgString(String svgPath) {
  return parseSvgPathData(svgPath);
}
```

### Pattern 3: `flutter gen-l10n` with `synthetic-package: false` (Flutter 3.32+)

**What:** Flutter 3.32 made `synthetic-package: false` the non-deprecated default. The generated ARB-backed class is written to source, not a synthetic package. [VERIFIED: docs.flutter.dev breaking changes]

**l10n.yaml:**
```yaml
arb-dir: lib/core/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/generated/l10n
synthetic-package: false
required-resource-attributes: true
nullable-getter: false
```

**pubspec.yaml addition:**
```yaml
flutter:
  generate: true    # REQUIRED — without this, l10n.yaml is ignored
```

**Import in Dart code (new style):**
```dart
// NOT: import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../generated/l10n/app_localizations.dart';
```

### Pattern 4: Architecture Enforcement Test

**What:** A pure Dart test that uses `dart:io` to walk the file system and assert no game/map/core files import `features/ads/`. This runs in the normal `flutter test` suite.

```dart
// test/architecture/ads_isolation_test.dart
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('game, map, and core layers have no imports from features/ads/', () {
    const dirsToCheck = [
      'lib/features/game',
      'lib/features/map',
      'lib/core',
    ];

    final violations = <String>[];

    for (final dir in dirsToCheck) {
      final directory = Directory(dir);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          if (content.contains("features/ads/")) {
            violations.add(entity.path);
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'These files import from features/ads/:\n${violations.join('\n')}',
    );
  });
}
```

**Note:** This test uses `dart:io` and must run relative to the project root. It works correctly with `flutter test` from the project root.

### Pattern 5: `CountryDataService` with Locale Fallback

```dart
// lib/core/data/country_data_service.dart
class CountryDataService {
  Future<List<CountryData>> loadMapData() async {
    final json = await rootBundle.loadString('assets/map/world_map_paths.json');
    final data = jsonDecode(json) as Map<String, dynamic>;
    return (data['countries'] as List<dynamic>)
        .map((e) => CountryData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, String>> loadCountryNames(Locale locale) async {
    // Always load English base
    final enJson = await rootBundle.loadString('assets/data/countries_en.json');
    final base = Map<String, String>.from(
      (jsonDecode(enJson) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as Map)['name'] as String)),
    );

    // Try locale override; fall back silently
    try {
      final localeJson = await rootBundle
          .loadString('assets/data/countries_${locale.languageCode}.json');
      final overrides = jsonDecode(localeJson) as Map<String, dynamic>;
      for (final entry in overrides.entries) {
        final name = (entry.value as Map<String, dynamic>)['name'] as String?;
        if (name != null) base[entry.key] = name;
      }
    } catch (_) {
      // No locale file — English is the fallback
    }
    return base;
  }
}
```

### Anti-Patterns to Avoid

- **Putting country names in ARB files:** 196 countries × N locales = massive generated class. ARB is for UI chrome only. Country names go in JSON assets.
- **Parsing SVG at runtime with an XML parser:** Cold-start cost is high. Pipeline runs offline; Dart only loads pre-parsed JSON.
- **Using `ISO_A2` field from Natural Earth without fallback:** Kosovo and a few others have `-99` values. Pipeline must handle this with name-based matching.
- **`synthetic-package: true` in l10n.yaml:** Deprecated in Flutter 3.32. Use `synthetic-package: false` + `flutter: generate: true` in pubspec.yaml.
- **Importing `features/ads/` from game logic:** Enforced by `ads_isolation_test.dart` from commit 1.
- **Adding `firebase_core`, `firebase_analytics`, or `firebase_crashlytics` to pubspec.yaml:** COPPA-prohibited. Excluded from day one.
- **Leaving INTERNET permission in release manifest:** A blank Flutter project puts INTERNET only in `debug/AndroidManifest.xml` (since PR #22139). Verify it is not in `main/AndroidManifest.xml` after adding SDK dependencies like `google_mobile_ads` (Phase 6 concern, but establish baseline now).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SVG path string → dart:ui Path | Custom parser | `path_drawing` `parseSvgPathData` | Arc approximation is hard; path_drawing handles all SVG path commands including curves |
| Read shapefile geometry | Custom binary parser | `geopandas.read_file()` | Shapefile format has projection metadata, CRS transforms, attribute parsing — all handled by geopandas |
| Coordinate system transforms (EPSG) | Manual math | `geopandas.to_crs()` + pyproj | Projection math is error-prone; PROJ library handles correctly |
| ARB-backed locale strings | Custom i18n | `flutter gen-l10n` | Type safety, plural handling, locale fallback — all built in |
| Mocking in Dart tests | Manual fake classes | `mocktail` | Mocktail provides `when()`, `verify()`, `any()` with zero code gen |
| Import rule enforcement | Manual code review | `ads_isolation_test.dart` with dart:io file walk | Automated; runs in CI; catches violations at test time |

**Key insight:** The Python pipeline is the biggest "don't hand-roll" risk. The temptation to write a custom shapefile parser or SVG-to-JSON converter should be resisted — geopandas handles every edge case (projection, MultiPolygon, holes, antimeridian wrapping) that a custom script would get wrong.

---

## Common Pitfalls

### Pitfall 1: Kosovo ISO_A2 = `-99` in Natural Earth

**What goes wrong:** The Natural Earth `ISO_A2` field stores `-99` for Kosovo (XK) because Kosovo's ISO code is not in ISO 3166-1 officially (it uses the EU-assigned user-defined code XK). Iterating the shapefile and using `row['ISO_A2']` blindly will drop Kosovo from the map.

**Why it happens:** Natural Earth uses `-99` as the null sentinel for missing numeric and string attributes.

**How to avoid:** Pipeline must have a name-based fallback: if `ISO_A2 == '-99'`, match by `NAME` field containing "Kosovo" → assign `'xk'`. Similarly handle any other `-99` entries in the 258-row dataset.

**Warning signs:** Fewer than 196 entries in the generated JSON; Kosovo absent from map.

### Pitfall 2: Riverpod 3.x vs 2.x API Differences

**What goes wrong:** Prior research (STACK.md) documented Riverpod 2.x APIs. Current stable is 3.x. Breaking changes include: `Ref` subclasses removed (use `Ref` directly), `AutoDisposeNotifier` deprecated (use `Notifier`), `StateProvider`/`StateNotifierProvider` moved to `legacy.dart`. Code copying patterns from STACK.md's code snippets will fail to compile.

**How to avoid:** Use the Riverpod 3.x annotation pattern `Example example(Ref ref)` (not `ExampleRef ref`). Consult riverpod.dev/docs/3.0_migration before writing any notifier code.

### Pitfall 3: `flutter gen-l10n` synthetic-package Breaking Change

**What goes wrong:** Without `flutter: generate: true` in pubspec.yaml, the l10n.yaml is silently ignored. Without `synthetic-package: false` in l10n.yaml, the tool still generates into the deprecated synthetic package on some Flutter versions, causing import path confusion.

**How to avoid:** Always set both `flutter: generate: true` (pubspec.yaml) AND `synthetic-package: false` (l10n.yaml). Import generated class from the source path, not from `package:flutter_gen`.

**Warning signs:** `flutter gen-l10n` succeeds but the generated file is not where the import expects it; or the IDE doesn't resolve `AppLocalizations`.

### Pitfall 4: Antimeridian-Crossing Countries (Russia, USA, Fiji)

**What goes wrong:** Countries that cross the international date line (180°/-180° longitude) have polygon coordinates that jump from ~179° to ~-179°, creating a line across the entire map in naive equirectangular projection.

**How to avoid:** The pipeline must detect and handle antimeridian crossing. One approach: if two consecutive polygon vertices differ in longitude by more than 180°, split the polygon into two sub-paths. An alternative: use the Natural Earth "split at antimeridian" pre-clipped dataset. [ASSUMED — standard GIS issue; verify during pipeline implementation]

**Warning signs:** Russia or USA appear as a horizontal line across the map.

### Pitfall 5: Flag SVG Files Named With Lowercase ISO Codes

**What goes wrong:** lipis/flag-icons names files by lowercase ISO alpha-2 code (`flags/4x3/de.svg`, not `DE.svg`). If the pipeline emits uppercase ISO codes into `world_map_paths.json` and the Dart asset path is constructed as `'assets/flags/$isoCode.svg'`, case mismatch causes "asset not found" errors on Android (case-sensitive filesystem) while working fine on macOS/Windows.

**How to avoid:** Pipeline always emits lowercase ISO codes. `CountryData.isoCode` is always lowercase. Flag asset path always uses lowercase: `'assets/flags/${isoCode.toLowerCase()}.svg'`.

### Pitfall 6: `path_drawing` Is Unmaintained (last update 3 years ago)

**What goes wrong:** `path_drawing` 1.0.1 was published 3 years ago. It may have unresolved issues with very long path strings or edge-case SVG commands.

**How to avoid:** Since the pipeline only generates M/L/Z path strings (no curves, no arcs, no relative commands), the risk is minimal. Test with the actual generated `world_map_paths.json` in the unit test suite. If parsing fails for a specific country, the unit test will catch it.

**Warning signs:** `parseSvgPathData` throws or returns an empty Path for specific countries.

---

## Code Examples

### Python: Complete Pipeline Skeleton

```python
# scripts/generate_map.py
# Requires: pip install geopandas shapely
import geopandas as gpd
import json
import math
from shapely.geometry import MultiPolygon, Polygon

VIEWBOX_WIDTH = 2000.0
VIEWBOX_HEIGHT = 1000.0

# Equirectangular: lon [-180,180] → x [0, VIEWBOX_WIDTH]
#                  lat [90,-90]   → y [0, VIEWBOX_HEIGHT]
def lon_to_x(lon): return round((lon + 180.0) / 360.0 * VIEWBOX_WIDTH, 2)
def lat_to_y(lat): return round((90.0 - lat) / 180.0 * VIEWBOX_HEIGHT, 2)

def polygon_to_path(polygon):
    coords = list(polygon.exterior.coords)[:-1]  # drop repeated last
    parts = [f"M{lon_to_x(lon)},{lat_to_y(lat)}" for lon, lat in coords[:1]]
    parts += [f"L{lon_to_x(lon)},{lat_to_y(lat)}" for lon, lat in coords[1:]]
    parts.append("Z")
    return " ".join(parts)

def get_iso_code(row):
    iso = str(row.get('ISO_A2', '-99')).strip()
    if iso and iso != '-99' and len(iso) == 2:
        return iso.lower()
    name = str(row.get('NAME', ''))
    if 'Kosovo' in name:
        return 'xk'
    # Add other special cases as discovered
    return None

def compute_bounding_box(paths_coords):
    # Returns {'x', 'y', 'w', 'h'} in viewbox units
    all_x = [lon_to_x(lon) for poly_coords in paths_coords for lon, lat in poly_coords]
    all_y = [lat_to_y(lat) for poly_coords in paths_coords for lon, lat in poly_coords]
    x, y = min(all_x), min(all_y)
    return {'x': x, 'y': y, 'w': max(all_x) - x, 'h': max(all_y) - y}

def compute_centroid(geometry):
    c = geometry.centroid
    return {'x': lon_to_x(c.x), 'y': lat_to_y(c.y)}

def main():
    gdf = gpd.read_file(
        'https://naciscdn.org/naturalearth/110m/cultural/ne_110m_admin_0_countries.zip'
    )
    # Ensure WGS-84 for equirectangular
    gdf = gdf.to_crs('EPSG:4326')

    countries = {}
    for _, row in gdf.iterrows():
        iso = get_iso_code(row)
        if iso is None:
            continue

        geom = row.geometry
        if geom is None or geom.is_empty:
            continue

        polys = list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]
        paths = [polygon_to_path(p) for p in polys if isinstance(p, Polygon)]
        coords = [list(p.exterior.coords)[:-1] for p in polys if isinstance(p, Polygon)]

        if iso not in countries:
            countries[iso] = {
                'iso': iso,
                'paths': paths,
                'boundingBox': compute_bounding_box(coords),
                'centroid': compute_centroid(geom),
            }
        else:
            # Merge polygons under same ISO (e.g., France overseas)
            countries[iso]['paths'].extend(paths)

    output = {
        'version': 1,
        'viewBox': {'width': VIEWBOX_WIDTH, 'height': VIEWBOX_HEIGHT},
        'countries': list(countries.values()),
    }
    with open('assets/map/world_map_paths.json', 'w') as f:
        json.dump(output, f, separators=(',', ':'))
    print(f"Generated {len(countries)} countries")

if __name__ == '__main__':
    main()
```

### Dart: CountryData Model

```dart
// lib/core/models/country_data.dart
import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';

class BoundingBox {
  final double x, y, w, h;
  const BoundingBox({required this.x, required this.y,
                     required this.w, required this.h});

  Rect get rect => Rect.fromLTWH(x, y, w, h);

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num).toDouble(),
    h: (json['h'] as num).toDouble(),
  );
}

class CountryData {
  final String isoCode;          // 2-letter lowercase ISO alpha-2
  final List<String> pathStrings; // SVG path strings (one per disjoint polygon)
  final List<Path> paths;         // Parsed dart:ui Path objects (built at load time)
  final BoundingBox boundingBox;
  final Offset centroid;

  const CountryData({
    required this.isoCode,
    required this.pathStrings,
    required this.paths,
    required this.boundingBox,
    required this.centroid,
  });

  factory CountryData.fromJson(Map<String, dynamic> json) {
    final pathStrings = List<String>.from(json['paths'] as List<dynamic>);
    final paths = pathStrings.map(parseSvgPathData).toList();
    return CountryData(
      isoCode: json['iso'] as String,
      pathStrings: pathStrings,
      paths: paths,
      boundingBox: BoundingBox.fromJson(
          json['boundingBox'] as Map<String, dynamic>),
      centroid: Offset(
        (json['centroid']['x'] as num).toDouble(),
        (json['centroid']['y'] as num).toDouble(),
      ),
    );
  }
}
```

### Dart: AdLoadState Stub (walled garden)

```dart
// lib/features/ads/ad_load_state.dart
sealed class AdLoadState {
  const AdLoadState();
}

class AdLoaded extends AdLoadState {
  const AdLoaded();
}

class AdFailed extends AdLoadState {
  const AdFailed();
}

// lib/features/ads/ad_service.dart
abstract interface class AdService {
  Future<AdLoadState> loadBannerAd();
  Future<AdLoadState> loadInterstitialAd();
  Future<AdLoadState> loadRewardedAd();
}

class StubAdService implements AdService {
  const StubAdService();

  @override Future<AdLoadState> loadBannerAd() async => const AdFailed();
  @override Future<AdLoadState> loadInterstitialAd() async => const AdFailed();
  @override Future<AdLoadState> loadRewardedAd() async => const AdFailed();
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Riverpod 2.x (`@riverpod`, `AutoDisposeNotifier`, `ExampleRef ref`) | Riverpod 3.x (`Ref ref` directly, `Notifier`, unified) | 2025 | All provider code must use 3.x pattern; 2.x patterns in STACK.md are stale |
| `flutter gen-l10n` with synthetic package (`package:flutter_gen`) | `synthetic-package: false` + `flutter: generate: true` | Flutter 3.28-3.32 | Import paths change; pubspec.yaml must have `generate: true` |
| `path_parsing` package (older) | `path_drawing` wrapping `path_parsing` | Stable for years | `path_drawing` is the user-facing package |

**Deprecated/outdated (from prior STACK.md research):**
- Riverpod 2.5.1 versions: Current stable is 3.3.1. Use 3.x.
- `riverpod_annotation ^2.3.5`: Current is `^4.0.2`.
- `riverpod_generator ^2.4.0`: Current is `^4.0.3`.
- `flutter_svg ^2.0.10`: Current stable is `2.3.0`.
- `shared_preferences ^2.3.1`: Current is `2.5.5`.
- `intl ^0.19.0`: Current is `0.20.2`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `path_drawing` handles arc commands (A/a) by approximating with cubic Bézier curves | Standard Stack, Code Examples | Low risk — pipeline only emits M/L/Z (shapefile polygons have no curves); would only matter if we ever feed an arc-containing SVG path |
| A2 | The antimeridian-crossing issue (Russia, USA, Fiji) requires explicit handling in the pipeline | Common Pitfalls | Medium — if not handled, these countries appear as horizontal map lines; testable during pipeline development |
| A3 | Natural Earth 110m dataset correctly labels Taiwan under `NAME` field as "Taiwan" (allowing ISO `TW` assignment if `ISO_A2` is `-99`) | Code Examples | Medium — Taiwan may already have `ISO_A2 = 'TW'` in the dataset; needs verification when running the script |
| A4 | Flutter 3.32 is the current stable SDK version; Dart SDK minimum should be `>=3.7.0` | Standard Stack | Low — update to actual installed version when `flutter create` is run |
| A5 | `flutter create` does NOT include INTERNET permission in the main manifest (only in debug overlay) | Architecture Patterns | Low — verifiable immediately after `flutter create`; fix is trivial if wrong |
| A6 | Wikidata/Stefan Gabos world_countries dataset under CC-BY-SA 4.0 is acceptable for country names | Architecture Patterns | Medium — CC-BY-SA requires attribution; if license is not acceptable, use Unicode CLDR JSON directly (cldr-json on GitHub, Unicode license) |

---

## Open Questions (RESOLVED)

1. **Antimeridian handling complexity** — RESOLVED: Plan 01-03 includes x-coordinate jump detection. The pipeline checks consecutive polygon vertices for longitude jumps exceeding 180° and splits the polygon into sub-paths at the antimeridian. This resolves the rendering artifact for Russia, USA (Alaska), and Fiji.
   - What we know: Countries crossing 180° longitude produce rendering artifacts in equirectangular projection
   - What's unclear: How significant is this for the 110m scale dataset? Does Natural Earth pre-clip at the antimeridian for the 110m product?
   - Recommendation: Run the pipeline and visually inspect Russia, USA (Alaska), and Fiji first. If they look wrong, add antimeridian clipping.

2. **Kosovo in Natural Earth 110m dataset** — RESOLVED: Pipeline uses name-based fallback (match 'Kosovo' in NAME field → assign 'xk'). Plan 01-04 Task 2 unit test asserts 'xk' is present in the returned ISO codes, catching any regression.
   - What we know: Kosovo has `ISO_A2 = -99` in some Natural Earth versions; EU code is XK
   - What's unclear: The 110m dataset specifically — does it have a Kosovo polygon at all at this scale, or does it merge with Serbia?
   - Recommendation: Run the pipeline and grep the output JSON for 'XK' or check if a Kosovo polygon appears. If absent at 110m scale, document that Kosovo appears as part of Serbia geometry at this resolution.

3. **Country name data source license** — RESOLVED: pycountry (MIT) + babel (BSD) chosen. The pipeline uses pycountry for ISO 3166-1 code enumeration and babel for locale-specific country name lookup, both under permissive licenses with no attribution requirements in binary distribution.
   - What we know: Stefan Gabos world_countries is CC-BY-SA 4.0; Unicode CLDR uses the Unicode License; `common_locale_data` pub.dev package uses CLDR 46.0.0 data
   - What's unclear: Which license is best for this app? CC-BY-SA requires attribution; Unicode License has fewer conditions
   - Recommendation: Use the `common_locale_data` Dart package to programmatically extract country names per locale at build time, then emit `countries_XX.json` files. This keeps all data in-process and uses the established Unicode license.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3 | generate_map.py pipeline | Yes | 3.13.13 | — |
| geopandas | Pipeline: read shapefile | Not installed | — | `pip install geopandas` (install step in Wave 0) |
| shapely | Pipeline: geometry ops | Not installed | — | Installed as geopandas dependency |
| Flutter SDK | App build | Not in PATH | — | Install Flutter before executing; Flutter 3.32+ required |
| Dart SDK | App build | Not in PATH | — | Bundled with Flutter |
| Android SDK | Build + emulator | Unknown | — | Required for Android testing |

**Missing dependencies with no fallback:**
- Flutter SDK — must be installed before any Flutter tasks execute. Planner should include a Flutter SDK installation verification step as Wave 0 gate.

**Missing dependencies with fallback (install during Wave 0):**
- geopandas — `pip install geopandas` (may need `pip install geopandas pyproj shapely`)

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + dart:test |
| Config file | None needed — `flutter test` discovers by convention |
| Quick run command | `flutter test test/unit/ test/architecture/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMP-01 | No INTERNET permission in release manifest; no Firebase in pubspec | Manual inspection | `grep -r "firebase" pubspec.yaml pubspec.lock` | N/A |
| COMP-03 | World map loads offline; no rootBundle calls require network | Unit | `flutter test test/unit/country_data_service_test.dart` | Wave 0 |
| I18N-01 | ARB files generate valid `AppLocalizations`; no hardcoded strings | Build | `flutter gen-l10n` exits 0 | Wave 0 |
| I18N-02 | `countries_en.json` has exactly 196 entries; Spanish locale loads | Unit | `flutter test test/unit/country_data_service_test.dart` | Wave 0 |
| I18N-03 | Adding `countries_de.json` without Dart changes serves German names | Unit | `flutter test test/unit/country_data_service_test.dart` | Wave 0 |
| D-12 (arch) | Zero imports of `features/ads/` in game/map/core layers | Architecture | `flutter test test/architecture/ads_isolation_test.dart` | Wave 0 |
| Pipeline | `world_map_paths.json` has 196 entries with valid paths and coordinates | Unit | `flutter test test/unit/country_data_test.dart` | Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/ test/architecture/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps (must be created before implementation begins)

- [ ] `test/unit/country_data_service_test.dart` — covers COMP-03, I18N-02, I18N-03
- [ ] `test/unit/country_data_test.dart` — covers pipeline output (196 entries, valid paths)
- [ ] `test/architecture/ads_isolation_test.dart` — covers D-12
- [ ] Python pipeline: `pip install geopandas` verification step
- [ ] Flutter SDK install verification step

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth in app |
| V3 Session Management | No | Local state only; no network sessions |
| V4 Access Control | No | Single-user local app |
| V5 Input Validation | Minimal | JSON asset parsing — no user-provided input at this phase |
| V6 Cryptography | No | No sensitive data |
| V9 Data Classification | Yes | No PII collected — COPPA-compliant by design |

### Known Threat Patterns for Flutter/Android + Offline App

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Transitive INTERNET permission from SDK | Information Disclosure | Audit `AndroidManifest.xml` after each dependency add; use manifest merger log |
| Firebase/Analytics SDK accidentally added | Information Disclosure | `grep firebase pubspec.yaml` in CI; ads_isolation_test analogue for pubspec |
| JSON asset tampering (supply chain) | Tampering | Assets are bundled at build time; no runtime download; standard APK signing |
| AD_ID permission from future AdMob transitive dep | Information Disclosure | Phase 1 has no `google_mobile_ads`; baseline manifest must have no AD_ID |

**Phase 1 COPPA baseline actions:**
1. Verify `android/app/src/main/AndroidManifest.xml` has NO `<uses-permission>` elements after project creation
2. Verify `android/app/src/debug/AndroidManifest.xml` contains INTERNET (debug only)
3. Confirm no `firebase_*` package appears anywhere in pubspec.yaml or pubspec.lock

---

## Sources

### Primary (HIGH confidence)
- pub.dev/packages/flutter_riverpod — verified version 3.3.1 [VERIFIED: pub.dev]
- pub.dev/packages/riverpod_annotation — verified version 4.0.2 [VERIFIED: pub.dev]
- pub.dev/packages/riverpod_generator — verified version 4.0.3 [VERIFIED: pub.dev]
- pub.dev/packages/flutter_svg — verified version 2.3.0 [VERIFIED: pub.dev]
- pub.dev/packages/go_router — verified version 17.2.3 [VERIFIED: pub.dev]
- pub.dev/packages/shared_preferences — verified version 2.5.5 [VERIFIED: pub.dev]
- pub.dev/packages/build_runner — verified version 2.15.0 [VERIFIED: pub.dev]
- pub.dev/packages/mocktail — verified version 1.0.5 [VERIFIED: pub.dev]
- pub.dev/packages/intl — verified version 0.20.2 [VERIFIED: pub.dev]
- docs.flutter.dev/release/breaking-changes/flutter-generate-i10n-source — synthetic-package breaking change [VERIFIED: official Flutter docs]
- riverpod.dev/docs/whats_new — Riverpod 3.0 breaking changes [VERIFIED: official Riverpod docs]
- raw.githubusercontent.com/lipis/flag-icons/refs/heads/main/country.json — XK and TW confirmed present [VERIFIED: lipis/flag-icons repo]

### Secondary (MEDIUM confidence)
- GitHub nvkelso/natural-earth-vector issue #134 — Kosovo ISO_A2 known issue [CITED: github.com/nvkelso/natural-earth-vector/issues/134]
- naturalearthdata.com/downloads/110m-cultural-vectors/110m-admin-0-countries — 258 features at 110m scale [CITED: naturalearthdata.com]
- github.com/flutter/flutter/pull/22139 — INTERNET permission moved to debug manifest [CITED: flutter/flutter PR #22139]

### Tertiary (LOW confidence / ASSUMED)
- path_drawing arc command support — inferred from library description; M/L/Z confirmed safe for shapefile output [ASSUMED]
- Antimeridian handling in Natural Earth 110m — known GIS issue; severity at 110m scale unverified [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack (package names, versions): HIGH — all verified on pub.dev directly
- Python pipeline approach (geopandas + shapely): HIGH — well-established GIS toolchain
- Kosovo ISO_A2 workaround: HIGH — confirmed by GitHub issues and search results
- lipis/flag-icons XK/TW presence: HIGH — verified via raw JSON from repo
- flutter gen-l10n synthetic-package change: HIGH — verified via official Flutter breaking changes docs
- Riverpod 3.x breaking changes: HIGH — verified via official Riverpod docs
- Antimeridian handling: MEDIUM — standard GIS issue; specific behavior at 110m scale is [ASSUMED]
- path_drawing arc support: MEDIUM — library description implies support; unverified for edge cases

**Research date:** 2026-05-27  
**Valid until:** 2026-08-27 (stable for 90 days; re-verify package versions before starting Phase 2)
