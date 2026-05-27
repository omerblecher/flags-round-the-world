# Walking Skeleton — Flags Around the World

**Phase:** 1 — Foundation
**Created:** 2026-05-27
**Purpose:** Records architectural decisions that all subsequent phases build on without renegotiating.

---

## What the Skeleton Delivers

The thinnest possible end-to-end working slice:
- Flutter project created with package ID `com.otis.brooke.flags.around.the.world`
- Complete directory structure (feature-folder skeleton per D-01, D-02, D-03)
- pubspec.yaml with all Phase 1 dependencies locked
- Python pipeline running successfully → `assets/map/world_map_paths.json` committed
- Dart unit tests loading and parsing `world_map_paths.json` from assets → green
- `flutter run` launches the app offline (no network, no crash)

---

## Architectural Decisions (Locked)

### Framework
| Concern | Decision | Rationale |
|---------|----------|-----------|
| UI framework | Flutter (Dart) | Cross-platform, single codebase, no JS bridge |
| Min SDK | `sdk: '>=3.7.0 <4.0.0'`, `flutter: '>=3.32.0'` | Matches current stable; required for gen-l10n synthetic-package:false |
| Package ID | `com.otis.brooke.flags.around.the.world` | Locked — cannot change after Play Store submission |

### State Management
| Concern | Decision | Rationale |
|---------|----------|-----------|
| State library | `flutter_riverpod: ^3.3.1` | Flutter team endorsed; current major (3.x API, NOT 2.x) |
| Code generation | `riverpod_annotation: ^4.0.2` + `riverpod_generator: ^4.0.3` | Companion packages for @riverpod annotation style |
| Provider pattern | `Notifier` + `@riverpod` annotation | AutoDisposeNotifier is deprecated in 3.x; use Notifier directly |

### Map Rendering (Phase 3, constrained here)
| Concern | Decision | Rationale |
|---------|----------|-----------|
| Map widget | `CustomPainter` + `InteractiveViewer` | NOT flutter_map (wrong model), NOT syncfusion (commercial) |
| Map data | Pre-processed `world_map_paths.json` (build-time) | No runtime SVG parsing; cold-start performance |
| Path parsing | `path_drawing: ^1.0.1` (`parseSvgPathData`) | Only public API for SVG path string → dart:ui Path |
| Drop coordinate transform | `TransformationController.toScene()` | NOT `RenderBox.globalToLocal()` — locked per CLAUDE.md |

### Data Pipeline
| Concern | Decision | Rationale |
|---------|----------|-----------|
| Map source | Natural Earth 1:110m shapefile (ne_110m_admin_0_countries) | CC0; balances detail vs. APK size |
| Pipeline language | Python + geopandas + shapely | Handles projection, MultiPolygon, antimeridian cleanly |
| Output format | JSON with M/L/Z SVG path strings | No runtime SVG parsing; path_drawing handles M/L/Z safely |
| Coordinate space | Equirectangular, viewBox 2000×1000 | Simple projection; lon/lat → x/y math is deterministic |
| ISO code field | `ISO_A2` with Kosovo name-fallback | Kosovo has ISO_A2=-99; fallback: if 'Kosovo' in NAME → 'xk' |
| Country count | 196 (UN-193 + Holy See + Taiwan TW + Kosovo XK) | D-08; all tests and assertions use 196, NOT 195 |

### Storage
| Concern | Decision | Rationale |
|---------|----------|-----------|
| Local storage | `shared_preferences: ^2.5.5` | Phase 1: ad state; Phase 2+: scores, session persistence |
| Asset loading | `rootBundle.loadString()` | Offline only; no network calls ever |

### Navigation
| Concern | Decision | Rationale |
|---------|----------|-----------|
| Router | `go_router: ^17.2.3` | Flutter team standard; declarative; onExit back-button guard |

### i18n
| Concern | Decision | Rationale |
|---------|----------|-----------|
| UI chrome strings | `flutter gen-l10n` + ARB files | Type-safe; plural handling built in |
| Country names | Per-locale JSON assets (`countries_en.json`, `countries_es.json`) | 196 × N locales would bloat generated ARB class |
| gen-l10n config | `synthetic-package: false` + `flutter: generate: true` | Flutter 3.32+ breaking change — required |
| ARB location | `lib/core/l10n/app_en.arb` (template), `app_es.arb` | arb-dir in l10n.yaml |
| Generated output | `lib/generated/l10n/app_localizations.dart` | Import from source path, NOT `package:flutter_gen` |

### Ads (Walled Garden)
| Concern | Decision | Rationale |
|---------|----------|-----------|
| Ad isolation | `features/ads/` stub only; zero game/map/core imports | COPPA; AdMob wired in Phase 6 only |
| Stub behavior | `AdLoadState.failed` always | Real wiring deferred; stub prevents crashes |
| Enforcement | `test/architecture/ads_isolation_test.dart` (dart:io file walk) | Automated; catches violations at test time |

### Compliance
| Concern | Decision | Rationale |
|---------|----------|-----------|
| Analytics | NO Firebase, ever | COPPA: Firebase App Instance ID is a persistent device identifier |
| Crash reporting | Android Vitals only | No Crashlytics UUID; COPPA-safe |
| AD_ID permission | Blocked via `tools:remove` in manifest | Phase 6 adds this; baseline must be clean |
| INTERNET permission | Debug manifest only (Flutter default) | Release manifest must have NO uses-permission elements |

### Directory Layout
```
flags_around_the_world/
├── scripts/
│   └── generate_map.py          # Python pipeline: shapefile → world_map_paths.json
├── assets/
│   ├── flags/                   # 196 SVG files (from lipis/flag-icons, path: flags/4x3/{code}.svg)
│   ├── map/
│   │   └── world_map_paths.json # Pipeline output — committed to git
│   ├── data/
│   │   ├── countries_en.json    # 196 English country names, keyed by lowercase ISO alpha-2
│   │   └── countries_es.json    # 196 Spanish country names (same key structure)
│   └── audio/
│       └── .gitkeep             # Placeholder — audio assets added in Phase 4
├── lib/
│   ├── main.dart                # WidgetsFlutterBinding.ensureInitialized() + runApp(ProviderScope(child: App()))
│   ├── app.dart                 # MaterialApp.router with GoRouter + LocalizationsDelegates
│   ├── core/
│   │   ├── models/
│   │   │   └── country_data.dart        # CountryData, BoundingBox (dart:ui Offset for centroid)
│   │   └── data/
│   │       └── country_data_service.dart # Loads/parses world_map_paths.json + country name JSON
│   ├── core/l10n/               # ARB source files (NOT generated output)
│   │   ├── app_en.arb
│   │   └── app_es.arb
│   ├── features/
│   │   ├── game/
│   │   │   └── .gitkeep
│   │   ├── map/
│   │   │   └── .gitkeep
│   │   ├── ads/
│   │   │   ├── ad_load_state.dart       # sealed class: AdLoaded, AdFailed
│   │   │   └── ad_service.dart          # abstract AdService + StubAdService
│   │   └── home/
│   │       └── .gitkeep
│   └── generated/
│       └── l10n/                # gen-l10n output (generated, not committed to git)
├── test/
│   ├── architecture/
│   │   └── ads_isolation_test.dart      # dart:io file walk; zero features/ads/ imports in game/map/core
│   └── unit/
│       ├── country_data_test.dart       # 196 entries, non-empty ISO, non-empty paths, valid bbox+centroid
│       └── country_data_service_test.dart # locale fallback, Spanish names without Dart changes
├── android/
│   └── app/src/
│       ├── main/AndroidManifest.xml     # NO uses-permission elements
│       └── debug/AndroidManifest.xml    # INTERNET permission (debug only, hot reload)
├── l10n.yaml                    # arb-dir, synthetic-package: false, output-dir: lib/generated/l10n
├── pubspec.yaml                 # flutter: generate: true; all Phase 1 deps
└── analysis_options.yaml        # flutter_lints recommended
```

### Testing Strategy
| Layer | Framework | Run command |
|-------|-----------|-------------|
| Unit | flutter_test | `flutter test test/unit/` |
| Architecture | flutter_test + dart:io | `flutter test test/architecture/` |
| Full suite | flutter_test | `flutter test` |
| Build verification | flutter CLI | `flutter build apk --debug` |

---

## Constraints Future Phases Inherit

1. **Never import `features/ads/` from `features/game/`, `features/map/`, or `lib/core/`.** The architecture test enforces this from Phase 1.

2. **All ISO codes are lowercase** throughout the codebase. `CountryData.isoCode` is always lowercase. Flag asset paths: `assets/flags/${isoCode}.svg`.

3. **Country count is 196.** Tests assert exactly 196. Do not use 195.

4. **Map coordinate space: equirectangular, viewBox 2000×1000.** All geometry in subsequent phases uses this space. Phase 3's `WorldMapPainter` reads this viewBox from the JSON.

5. **Drag-drop coordinate transform: `TransformationController.toScene()` only.** `RenderBox.globalToLocal()` is wrong under zoom. This is enforced architecturally by the Phase 3 spike.

6. **No Firebase, no network calls.** `rootBundle` is the only data source. No `http` package ever added.

7. **Riverpod 3.x API.** Use `Notifier`, `@riverpod` annotation, `Ref ref` directly. `AutoDisposeNotifier`, `StateProvider`, `StateNotifierProvider` are all deprecated.

8. **`flutter gen-l10n` import path:** `import '../generated/l10n/app_localizations.dart'` — NOT `package:flutter_gen/...`.
