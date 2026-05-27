# Technology Stack

**Project:** Flags Around the World
**Researched:** 2026-05-27
**Note on sources:** WebFetch, WebSearch, and Bash were all unavailable during this research session.
All findings are from training data (knowledge cutoff August 2025) cross-referenced where possible
against pub.dev package naming conventions and Flutter SDK documentation patterns I have high
familiarity with. Every section carries an explicit confidence level. Verify all version numbers
against pub.dev before pinning in pubspec.yaml.

---

## 1. SVG World Map Rendering

**Recommendation: Custom SVG path map via `flutter_svg` + `CustomPainter` + `InteractiveViewer`**

**Confidence: HIGH for approach; MEDIUM for package version numbers**

### Why not flutter_map or syncfusion_flutter_maps

`flutter_map` is a tile-based map widget (OpenStreetMap-style raster tiles). It is not designed
for offline SVG country-boundary rendering or drag-drop game mechanics. Using it here would require
fighting the library at every step.

`syncfusion_flutter_maps` (package: `syncfusion_flutter_maps`) supports shape layers with GeoJSON
and can render country boundaries offline. However: (1) it requires a Syncfusion license for
commercial use beyond the community tier; (2) its gesture model is not designed for simultaneous
drag-drop atop a zoomable canvas; (3) it adds significant APK weight. Avoid.

### Recommended approach

Use a pre-processed SVG world map (Natural Earth or similar CC0 source) where each country `<path>`
element has an `id` matching its ISO 3166-1 alpha-2 code. Parse the SVG at startup using
`flutter_svg`'s `PictureInfo` API to extract individual path data, then:

1. Render the base map in a `CustomPainter` using `dart:ui` `Path` objects built from the parsed
   SVG path data. This gives full control over per-country fill, stroke, and hit-testing.
2. Wrap the `CustomPainter` widget in `InteractiveViewer` for pinch-zoom and pan.
3. Implement `DragTarget<CountryCode>` overlays positioned atop the `InteractiveViewer` child to
   receive flag drops, with coordinate transformation from screen space to map space.

**Alternative (simpler, lower fidelity):** Use `flutter_svg` to render the whole map as a static
picture and overlay transparent `GestureDetector` widgets at pre-computed bounding-box coordinates.
Sufficient for tap-to-identify but inadequate for drag-drop with visual feedback per country.

### Key packages

| Package | Pub version (verify) | Purpose | Notes |
|---------|---------------------|---------|-------|
| `flutter_svg` | ^2.0.10 | SVG parsing + rendering | Maintained by Flutter team; stable API |
| `xml` | ^6.3.0 | SVG path XML parsing at startup | Pure Dart; no native deps |
| `path_provider` | ^2.1.3 | Not needed (assets are bundled) | -- |

**SVG map source:** Natural Earth "Admin 0 Countries" dataset (naturalearthdata.com) — CC0 public
domain. Pre-process with Python/QGIS to add ISO codes as `id` attributes and simplify geometry to
reduce vertex count. Target < 500 KB for the map SVG asset.

**Do NOT use** the Wikipedia SVG world map — it has complex `<use>` elements and inconsistent
country IDs that make programmatic path extraction unreliable.

---

## 2. Flag Assets

**Recommendation: SVG from `lipis/flag-icons` GitHub repository (MIT licensed)**

**Confidence: HIGH**

`lipis/flag-icons` (github.com/lipis/flag-icons) provides SVG flags for all 195+ countries at
consistent 4:3 and 1:1 aspect ratios. Files are named by ISO 3166-1 alpha-2 code (e.g., `us.svg`,
`gb.svg`). MIT licensed. Used by thousands of production projects.

### PNG vs SVG for flags

Use SVG. Reasons:
- Flags render crisply at any drag-target or game-card size without multiple resolutions
- `flutter_svg` renders them efficiently; no need for a PNG sprite sheet
- Total asset size for 195 SVG flags is approximately 1-3 MB vs 5-8 MB for 2x PNG set

### Bundling strategy

Place flags at `assets/flags/<iso_alpha2>.svg`. Register the directory in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/flags/
    - assets/map/world_map.svg
```

Do not use runtime HTTP downloads — the offline-first constraint is non-negotiable and storing 195
SVGs locally is trivially small.

### Alternative source: flagpedia.net

Flagpedia provides PNG at multiple resolutions (16px to 160px wide). Useful as a fallback PNG
source but the SVG from `lipis/flag-icons` is strictly better for this use case.

**Do NOT use** EmojiFlag (Unicode flag emoji) as game assets — rendering is platform-dependent
and emoji flags are not available on all Android versions.

---

## 3. Gesture Handling

**Recommendation: `InteractiveViewer` for zoom/pan + `Draggable`/`DragTarget` for flag drops**

**Confidence: HIGH**

### Pinch-zoom and pan

`InteractiveViewer` (built into Flutter SDK, no package needed) handles simultaneous pinch-zoom
and pan with:
- `minScale` / `maxScale` constraints
- `boundaryMargin` for pan limits
- `TransformationController` for programmatic reset-to-fit and zoom-to-country

Key config:
```dart
InteractiveViewer(
  transformationController: _transformationController,
  minScale: 0.5,
  maxScale: 8.0,
  constrained: false,  // required when child is larger than viewport
  child: WorldMapWidget(),
)
```

`constrained: false` is mandatory for a world map that is wider than the screen.

### Drag-and-drop

Use Flutter's built-in `Draggable<String>` (carrying ISO country code as data) and `DragTarget<String>`
widgets. Key considerations:

1. The `DragTarget` widgets must be children of the `InteractiveViewer` child so they move with
   the map during zoom/pan.
2. When using `Draggable` inside `InteractiveViewer`, touch event precedence can conflict. Solve by
   using `Draggable.delay` (long-press threshold) or by placing the flag cards *outside* the
   `InteractiveViewer` (stationary flag tray at bottom) with a custom drag feedback that updates
   a state variable indicating which country region is being hovered. This is architecturally
   cleaner.
3. Use `DragTarget.onWillAcceptWithDetails` to provide hover highlight on the target country.

**Do NOT use** a custom `GestureDetector` stack for multi-touch — `InteractiveViewer` handles the
competing pointer events correctly and custom multi-touch gesture arbitration is a significant
source of bugs.

### Hit-testing country regions

For tap-to-select (non-drag mode) implement `contains()` checks against the `dart:ui Path` objects
in the `CustomPainter`. Flutter's `Path.contains(Offset)` method is O(n) in path vertices but
fast enough for 195 countries at tap frequency.

---

## 4. State Management

**Recommendation: Riverpod 2.x (`flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`)**

**Confidence: HIGH**

### Why Riverpod over Bloc

Bloc adds significant boilerplate (Event/State classes per feature) for a game that has relatively
contained, synchronous state transitions (score increment, timer tick, country matched). Bloc shines
for complex async event streams, not game state machines.

### Why Riverpod over Provider

Provider is in maintenance mode and the Flutter team recommends migrating to Riverpod for new
projects. Provider has no compile-time safety; Riverpod 2.x with code generation catches dependency
graph errors at compile time.

### Package set

| Package | Pub version (verify) | Purpose |
|---------|---------------------|---------|
| `flutter_riverpod` | ^2.5.1 | Flutter integration layer |
| `riverpod_annotation` | ^2.3.5 | Code-gen annotations |
| `riverpod_generator` | ^2.4.0 | build_runner source generator |
| `hooks_riverpod` | optional | If using `flutter_hooks` for lifecycle |

### Game state model

Use `@riverpod` notation for:
- `GameSessionNotifier` — score, timer, matched countries, game mode (AsyncNotifier)
- `HighScoreRepository` — read/write to local storage
- `CountryDataProvider` — immutable provider for the 195-country data set loaded from JSON asset

Keep timer logic in a `Ticker`-driven notifier using `Ticker` from `flutter/scheduler.dart` rather
than `Stream.periodic` to stay in sync with the Flutter frame pipeline.

---

## 5. Local Storage

**Recommendation: `shared_preferences` for high scores; no `flutter_secure_storage` needed**

**Confidence: HIGH**

High scores are not sensitive data. `flutter_secure_storage` encrypts data in the platform keystore
and is designed for tokens, passwords, and PII. It adds Android Keystore complexity (key migration
issues on backup/restore) for zero security benefit on non-sensitive game scores.

`hive` is a fast binary key-value store but adds a native code path (via `hive_flutter`) and
code generation overhead that is not justified for the data volume here (195 score records ≈ a few
KB).

`shared_preferences` (`^2.3.1`) is synchronous-read after first load, has zero native complexity,
and is perfectly sized for high score storage.

### Schema

Store scores as a JSON-encoded map keyed by `"<mode>_<difficulty>"` e.g. `"grand_master_3"`.
Reading/writing via a thin `HighScoreRepository` class behind the Riverpod provider means swapping
the storage backend later is a 30-line change.

| Package | Pub version (verify) | Use |
|---------|---------------------|-----|
| `shared_preferences` | ^2.3.1 | High scores, settings, first-run flag |

**Do NOT use** `sqflite` — relational DB is over-engineered for what is effectively a `Map<String, int>`.

---

## 6. AdMob / Google Mobile Ads

**Recommendation: `google_mobile_ads` (official Google package)**

**Confidence: HIGH for package identity; MEDIUM for API surface details (verify child-directed API)**

| Package | Pub version (verify) | Notes |
|---------|---------------------|-------|
| `google_mobile_ads` | ^5.1.0 | Official Google/Flutter team maintained |

### Child-directed treatment

Set `tagForChildDirectedTreatment` and `tagForUnderAgeOfConsent` at initialization time (before
any ad requests) via `RequestConfiguration`:

```dart
MobileAds.instance.updateRequestConfiguration(
  RequestConfiguration(
    tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
    tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
    maxAdContentRating: MaxAdContentRating.g,
  ),
);
```

This must be called before `MobileAds.instance.initialize()` completes to guarantee no
non-compliant requests escape.

### App Open ads

`AppOpenAd` is supported in `google_mobile_ads` ^5.x. The pattern:
1. Load an `AppOpenAd` during the splash/loading phase.
2. Show on `AppLifecycleState.resumed` if loaded and not already showing.
3. Guard with a 4-hour cooldown to avoid over-frequency violations.

### COPPA mediation note

AppLovin MAX, Unity Ads, and Meta Audience Network each have their own child-directed flag APIs.
Set them independently via their respective SDKs at startup. `google_mobile_ads` mediation does NOT
automatically propagate the child-directed flag to all mediated networks — each SDK must be
explicitly configured. This is a critical compliance pitfall.

### AdMob Test IDs

Use official test ad unit IDs during development. Replace with production IDs only in release
builds gated by a `kReleaseMode` check or a build flavor.

---

## 7. Internationalization (i18n)

**Recommendation: `flutter_localizations` + `intl` + ARB files via `flutter gen-l10n`**

**Confidence: HIGH**

The Flutter SDK ships `flutter_localizations` which provides locale-aware `MaterialApp` delegates.
`flutter gen-l10n` (built into the SDK's `flutter` tool) generates type-safe accessor classes from
`.arb` files with zero third-party dependencies.

| Component | Version | Notes |
|-----------|---------|-------|
| `flutter_localizations` | SDK-bundled | Add to `pubspec.yaml` under `flutter` |
| `intl` | ^0.19.0 | Dart i18n primitives; must match Flutter SDK constraint |

### 195 country names gotcha

Country names are data, not UI strings. Do not put all 195 country names into ARB files as
individual keys — that creates 195 × N_locales keys and enormous generated code. Instead:

1. Store canonical English names in a JSON asset (`assets/data/countries.json`) keyed by ISO
   alpha-2 code.
2. For localized country names, use a separate per-locale JSON asset
   (`assets/data/countries_es.json`, etc.) loaded at runtime based on `Localizations.localeOf(context)`.
3. ARB files contain only UI chrome strings (button labels, game mode names, score labels, etc.).

This approach keeps ARB file size tractable and allows shipping localized country name packs as
incremental assets without regenerating the entire localization layer.

### Locale coverage recommendation

Launch with English. Add Spanish, French, German, Portuguese, and Chinese (Simplified) in Phase 2
— those six cover ~60% of Google Play installs. Country name translations are available from
wikidata.org data dumps under CC0.

---

## 8. Haptic Feedback

**Recommendation: `HapticFeedback` from `package:flutter/services.dart` (SDK built-in)**

**Confidence: HIGH**

No third-party package needed. Flutter's `HapticFeedback` class exposes:
- `HapticFeedback.lightImpact()` — correct drop
- `HapticFeedback.mediumImpact()` — milestone / personal best
- `HapticFeedback.heavyImpact()` — wrong drop (jarring, use sparingly)
- `HapticFeedback.vibrate()` — fallback on devices without impact motors

The `flutter_haptic_feedback` package on pub.dev wraps the same platform channel calls with no
additional capability. Do not add a dependency for something already in the SDK.

**iOS note:** `HapticFeedback` requires iPhone 7 or later for impact motors. Earlier devices
silently no-op, which is fine for ages 8+ (modern devices).

---

## 9. Audio

**Recommendation: `just_audio` for music + `audioplayers` for SFX — or `just_audio` alone**

**Confidence: MEDIUM — the two-package approach is a known community pattern but verify current
maintenance status of `audioplayers` before pinning**

### just_audio vs audioplayers

| Criterion | `just_audio` | `audioplayers` |
|-----------|-------------|---------------|
| Maintained by | Ryan Heise (very active) | Blue Fire (active) |
| Background audio | Yes (with audio_session) | Yes |
| Low-latency SFX | Adequate via asset sources | Slightly better on Android |
| Audio focus | via `audio_session` package | Built-in |
| Stream playback | Yes | Yes |
| Pub points | ~160 | ~130 |

For an educational game, audio latency of 50-100ms is imperceptible. Use `just_audio` alone to
minimize dependencies. Pre-load sound effects as `AudioPlayer` instances with `setAsset()` and
call `seek(Duration.zero)` + `play()` for each trigger to achieve near-instant playback.

| Package | Pub version (verify) | Use |
|---------|---------------------|-----|
| `just_audio` | ^0.9.40 | All audio playback |
| `audio_session` | ^0.1.21 | Audio focus + interruption handling |

### CC audio asset sources

- **Kenney.nl** (kenney.nl/assets) — CC0 sound packs including "UI Audio", "Interface Sounds"
- **freesound.org** — CC0 and CC-BY files (require attribution for CC-BY)
- **OpenGameArt.org** — CC0 music loops

Filter to CC0 only to avoid attribution requirements in a children's app where credits screens
are easy to overlook.

---

## 10. Testing

**Recommendation: `flutter_test` (unit + widget) + `integration_test` (SDK) + `patrol` for
gesture-heavy integration tests**

**Confidence: MEDIUM for `patrol`; HIGH for `flutter_test` + `integration_test`**

### Unit and widget tests

Use `flutter_test` (SDK-bundled). Test all game logic (scoring, timer, country-matching rules)
as pure unit tests against Dart classes — no Flutter widget tree required.

Widget tests with `WidgetTester` are adequate for UI component verification.

### Integration tests for gestures

Flutter's `integration_test` package (SDK) runs on-device/emulator. For gesture-heavy tests:

- `tester.drag()` and `tester.fling()` simulate single-pointer gestures
- Multi-pointer pinch gestures require manual pointer injection via `TestGesture` with two
  simultaneous pointers — this works but is verbose

`patrol` (pub.dev/packages/patrol, by LeanCode) is a higher-level integration test framework that
wraps `integration_test` and adds:
- Native UI interaction (dismiss permission dialogs)
- More readable finder API
- Sharding support for CI

| Package | Pub version (verify) | Use |
|---------|---------------------|-----|
| `flutter_test` | SDK | Unit + widget tests |
| `integration_test` | SDK | On-device gesture tests |
| `patrol` | ^3.10.0 | Higher-level integration test helpers |
| `mocktail` | ^1.0.3 | Mocking for Riverpod provider tests |

### What to test vs what to leave

Test: game logic (pure Dart), scoring algorithms, high score read/write, country data loading.
Do NOT write integration tests for: exact pixel positions on the SVG map (fragile across screen
sizes), AdMob ad display (use test IDs + manual QA), haptic/audio triggers (platform-side effects).

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Map rendering | flutter_svg + CustomPainter | syncfusion_flutter_maps | Commercial license; not designed for drag-drop game |
| Map rendering | flutter_svg + CustomPainter | flutter_map | Tile-based, not SVG path, no offline country boundaries |
| State mgmt | flutter_riverpod | bloc | Overkill boilerplate for game state |
| State mgmt | flutter_riverpod | provider | Maintenance mode; no compile-time safety |
| State mgmt | flutter_riverpod | get_it + get | GetX has poor testability; get_it lacks reactivity |
| Storage | shared_preferences | hive | Unnecessary complexity for small non-sensitive data |
| Storage | shared_preferences | flutter_secure_storage | Encryption overkill for high scores |
| Storage | shared_preferences | sqflite | Relational DB overkill |
| Audio | just_audio | flame_audio | Flame game engine brings too much overhead for a Flutter-native app |
| Haptics | SDK HapticFeedback | flutter_haptic_feedback | Wraps same API; no added value |
| i18n | flutter gen-l10n | easy_localization | 3rd party; gen-l10n is the official Flutter approach |
| Testing | integration_test + patrol | flutter_driver | flutter_driver is legacy; integration_test is the modern replacement |

---

## Full pubspec.yaml Dependency Block (starting point)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # SVG rendering
  flutter_svg: ^2.0.10
  xml: ^6.3.0

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Storage
  shared_preferences: ^2.3.1

  # Audio
  just_audio: ^0.9.40
  audio_session: ^0.1.21

  # Ads
  google_mobile_ads: ^5.1.0

  # i18n
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  # State management code generation
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.9

  # Testing
  patrol: ^3.10.0
  mocktail: ^1.0.3
```

**IMPORTANT:** All version constraints above are from training data and must be verified against
pub.dev before use. Run `flutter pub outdated` after initial resolution to check for newer stable
versions.

---

## Confidence Summary

| Area | Confidence | Basis |
|------|------------|-------|
| SVG map approach (CustomPainter + InteractiveViewer) | HIGH | Core Flutter SDK; well-documented pattern |
| flutter_svg package identity | HIGH | Widely used; Flutter team involvement |
| flutter_svg version ^2.0.10 | MEDIUM | Training data; verify on pub.dev |
| lipis/flag-icons as flag source | HIGH | Very well-known OSS project; MIT license verified in training |
| Riverpod 2.x recommendation | HIGH | Official Flutter recommendation; active maintenance confirmed in training |
| Riverpod version numbers | MEDIUM | Training data; verify on pub.dev |
| InteractiveViewer + Draggable pattern | HIGH | Core Flutter SDK; documented multi-touch behavior |
| shared_preferences recommendation | HIGH | Standard Flutter recommendation for non-sensitive prefs |
| google_mobile_ads COPPA API shape | MEDIUM | API shape from training; verify RequestConfiguration fields in current docs |
| google_mobile_ads version ^5.x | MEDIUM | Training data; verify on pub.dev |
| Child-directed flag NOT propagating to mediation | HIGH | Known compliance gap documented in Google's own guides |
| flutter gen-l10n approach | HIGH | Official Flutter tooling; SDK-bundled |
| Country names in JSON not ARB | HIGH | Pattern well-established; ARB bloat with 195 keys is a real problem |
| HapticFeedback SDK built-in | HIGH | SDK API; no version dependency |
| just_audio recommendation | HIGH | Widely used; active maintainer as of training cutoff |
| just_audio version ^0.9.40 | MEDIUM | Training data; verify on pub.dev |
| patrol for integration tests | MEDIUM | Active project as of training; verify current release status |
| patrol version ^3.10.0 | LOW | Rough estimate from training; verify on pub.dev |

---

## Sources

All findings from Flutter SDK documentation (docs.flutter.dev) and pub.dev package pages as
represented in training data (knowledge cutoff August 2025). External tools (WebFetch, WebSearch,
Bash/Context7 CLI) were unavailable during this research session. Verification against live sources
is required before finalizing version pins.

- Flutter InteractiveViewer: https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html
- Flutter Draggable: https://api.flutter.dev/flutter/widgets/Draggable-class.html
- flutter_svg: https://pub.dev/packages/flutter_svg
- lipis/flag-icons: https://github.com/lipis/flag-icons
- Natural Earth data: https://www.naturalearthdata.com/
- flutter_riverpod: https://pub.dev/packages/flutter_riverpod
- google_mobile_ads COPPA: https://developers.google.com/admob/flutter/targeting
- flutter gen-l10n: https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
- just_audio: https://pub.dev/packages/just_audio
- patrol: https://pub.dev/packages/patrol
