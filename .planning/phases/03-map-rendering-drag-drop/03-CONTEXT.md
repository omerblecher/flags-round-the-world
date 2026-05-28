# Phase 3: Map Rendering & Drag-Drop - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 delivers a fully interactive world map with all 196 country regions rendered and droppable, a flag tray with a single draggable flag card, the complete drag-and-drop gameplay loop with correct/incorrect feedback, and hit-detection validated at 1×, 2×, and 4× zoom. The `GameSessionNotifier` from Phase 2 is the state backbone — Phase 3 wires it to real UI widgets for the first time.

**In scope:**
- Coordinate-transform spike (MANDATORY FIRST): standalone test widget proving `TransformationController.toScene()` hit detection works at 1×, 2×, and 4× zoom
- `WorldMapPainter` (CustomPainter): renders all 196 country paths from `CountryData.paths`, with flat atlas color palette, light-blue ocean background, thin borders, and drag-over highlight
- `InteractiveViewer` wrapper: pinch-to-zoom, two-finger pan, on-screen zoom buttons (MAP-02, MAP-03)
- Country name labels on map using centroid points (MAP-04) — always rendered in Phase 3; Phase 4 adds visibility toggle
- Flag tray widget (outside InteractiveViewer): single flag card, bottom strip layout, 3:2 rectangular card with shadow
- Country name shown under flag card in Phase 3 baseline; Phase 4 adds `showName` toggle
- Drag-and-drop system: `Draggable` in tray → `DragTarget`s inside InteractiveViewer scene
- Hit detection: `Path.contains(scenePoint)` primary check; bbox expansion for small countries; smallest-bbox tiebreaker for multi-match
- Correct-drop feedback: flag card animates (scale + fade) to country centroid and pins as small icon
- Incorrect-drop feedback: spring bounce back to tray
- Haptics: `HapticFeedback.lightImpact()` for correct, `HapticFeedback.mediumImpact()` for incorrect
- Audio stub: `AudioService` interface + `just_audio` initialized with silent placeholder assets
- Full session draw: 196 flags in random order, no repeats, completion screen after last correct match (GAME-05, GAME-06)
- Wires `GameSessionNotifier.recordDrop()` and `completeGame()` for correct/incorrect drops and session end

**Out of scope:**
- Game mode differentiation (Phase 4) — modes, mode-selection screen, `showName` flag behavior per mode
- Scoring HUD (Phase 4) — live score display, timer display, progress bar
- Hints (Phase 4)
- Real audio assets (deferred — stub only in Phase 3)
- Pause/resume UI (Phase 5)
- Accessibility labels and TalkBack (Phase 5)
- Any ads (Phase 6)

</domain>

<decisions>
## Implementation Decisions

### Map Visual Style
- **D-01:** Country fills use a **flat atlas palette** — continent-grouped colors (6–8 distinct colors) ensuring neighboring countries are visually distinct. Exact palette: researcher to select standard atlas-style colors; keep brightness mid-range to contrast with flag colors.
- **D-02:** Ocean/background color is **light blue** (e.g., `#A8D5E8` or similar Material-light equivalent). Fills the space behind/around the `WorldMapPainter` canvas.
- **D-03:** Country borders use a **thin, consistent stroke** — 1–1.5px at 1× zoom, scales proportionally with the InteractiveViewer transform so borders don't disappear at high zoom. Dark stroke color (e.g., `#555555`).
- **D-04:** Drag-over highlight is a **bright fill swap** — when a flag card is dragged over a country, that country's fill changes to a bright accent color (e.g., yellow/gold `#FFD700`). Returns to atlas color on drag exit or drop. Other countries are unaffected.
- **D-05:** Country name labels are rendered at the centroid point from `CountryData.centroid`. Font: small, readable (12–14sp effective at 1× zoom), white text with a dark text shadow for legibility over all fill colors. Labels scale with zoom (use canvas.scale inside CustomPainter). Phase 4 will add a `showLabels` parameter to toggle per-mode.

### Flag Tray Design
- **D-06:** Tray is a **horizontal bottom strip** — fixed below the map/InteractiveViewer, full device width. Height enough for one flag card plus padding. Not scrollable (single flag at a time).
- **D-07:** Tray shows **one active flag card** at a time — centered in the tray, no upcoming preview. When a correct match is made and the card departs, the next flag card slides in.
- **D-08:** Flag card is **3:2 aspect ratio, rectangular, rounded corners, drop shadow** — standard card metaphor. Flag SVG fills the card body; country name text below the flag inside the card.
- **D-09:** Country name is **always visible in Phase 3** below the flag image on the card. Phase 4 introduces `showName` (bool) parameter that modes will control — no Dart code changes needed in Phase 3 when Phase 4 adds it.

### Feedback Animations
- **D-10:** Correct drop: the flag card **animates (scale down + fade)** toward the country's centroid position on the map (coordinate-transformed back to screen space), then a small pinned flag icon appears at that centroid. Progress accumulates visually on the map as the session progresses. Use Flutter's `AnimationController` with a `CurvedAnimation`.
- **D-11:** Incorrect drop: the flag card **springs back to its tray position** using an elastic/bounce curve (e.g., `Curves.elasticOut`). No flash or error overlay needed in Phase 3 beyond the bounce; GAME-04 says "gentle error visual" — the bounce IS the visual.
- **D-12:** Audio: **`AudioService` abstract interface** with a `StubAudioService` implementation (always no-ops). `just_audio` is initialized and ready. Silent placeholder `.mp3` files at `assets/audio/correct.mp3` and `assets/audio/error.mp3`. Real audio assets added in a later phase — no code change needed, just replacing files.
- **D-13:** Haptics: **`HapticFeedback.lightImpact()`** on correct drop, **`HapticFeedback.mediumImpact()`** on incorrect drop. No external package needed — Flutter's built-in `services.dart` HapticFeedback.

### Hit-Detection Strategy
- **D-14:** Primary check: **`Path.contains(scenePoint)`** — after transforming the drop offset with `TransformationController.toScene()`, iterate over all 196 `CountryData` entries and call `path.contains(scenePoint)` for each of their paths. `CountryData.paths` are already parsed `dart:ui Path` objects — no parsing at drop time.
- **D-15:** Forgiving radius (GAME-02): if a country's bounding box diagonal is **below a threshold** (researcher to determine — ~20px at 1× zoom is a starting point), **expand the bounding box by 30%** and use an expanded-bbox check as a fallback if `Path.contains()` returns false. Large countries (Europe, Asia) use `Path.contains()` only.
- **D-16:** Multi-country tiebreaker: if multiple countries pass the hit test (border overlap), **select the country with the smallest bounding box area**. This correctly biases toward the more specific country.
- **D-17:** Mandatory spike first: the **coordinate-transform spike** is the very first deliverable in Phase 3 — a standalone widget with 5 labeled `DragTarget` regions at fixed scene coordinates, manually verified at 1×, 2×, and 4× zoom before any `WorldMapPainter` work begins. This is required by CLAUDE.md and cannot be skipped.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Phase Scope
- `.planning/ROADMAP.md` §Phase 3 — Phase goal, requirements list (MAP-01–05, GAME-01–06), success criteria (especially SC4: hit detection at 1×/2×/4×, the known critical risk)
- `.planning/REQUIREMENTS.md` §Map & Canvas (MAP-01–05), §Gameplay (GAME-01–06) — Full requirement text for Phase 3 scope

### Architecture (LOCKED — read before planning)
- `CLAUDE.md` §Critical Architecture Decisions — D1 (Flutter+CustomPainter+InteractiveViewer, NOT flutter_map), D3 (tray OUTSIDE InteractiveViewer, DragTargets INSIDE, TransformationController.toScene() for drop coords — cannot change after Phase 3), D4 (ad walled garden), D5 (no Firebase)

### Phase 2 Foundation (what Phase 3 builds on)
- `.planning/phases/02-state-data-layer/02-CONTEXT.md` — D-07 (GameSessionNotifier provider pattern), D-01 (GameSession model fields incl. activeIsoCode, hintsRemaining), D-04 (Ticker abstraction)
- `lib/features/game/game_session_notifier.dart` — `recordDrop()`, `completeGame()`, `startGame()`, `pauseGame()`, `resumeGame()` API — Phase 3 calls these from widget event handlers
- `lib/core/models/country_data.dart` — `CountryData` with `paths` (List<dart:ui Path>), `boundingBox`, `centroid`, `isoCode` — ready to paint
- `lib/core/data/country_data_service.dart` — how to load and parse `world_map_paths.json` as a Riverpod provider

### Prior Phase Context
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-04 (CountryData: one entry per ISO code, multi-polygon support), D-05 (overseas territories under parent ISO), D-06 (tiny nations at natural size — Phase 3 applies forgiving radius), D-07 (single centroid per ISO for label placement)

### Technical Research
- `.planning/research/STACK.md` §1 (Flutter map rendering, CustomPainter, InteractiveViewer, dart:ui Path) — confirmed technology stack for Phase 3

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/core/models/country_data.dart` — `CountryData.paths` are already `dart:ui Path` objects (parsed from SVG at load time via `path_drawing` package). `WorldMapPainter.paint()` can call `canvas.drawPath(path, paint)` directly — no runtime SVG parsing.
- `lib/core/models/country_data.dart` — `CountryData.boundingBox.rect` is a `Rect` (via `BoundingBox.rect` getter) — usable for expanded-bbox fallback in hit detection and for label placement.
- `lib/core/models/country_data.dart` — `CountryData.centroid` is an `Offset` — direct input to label canvas position and correct-drop animation target.
- `lib/features/game/game_session_notifier.dart` — `gameSessionProvider` is a top-level `AsyncNotifierProvider` — consume in Phase 3 widgets with `ref.watch(gameSessionProvider)` and `ref.read(gameSessionProvider.notifier)`.
- `lib/features/ads/ad_service.dart` — abstract interface + stub pattern already established; `AudioService` should follow the same abstract-interface + `StubAudioService` pattern for consistency.

### Established Patterns
- Manual `AsyncNotifier` + top-level provider (no codegen) — Phase 3 should follow the same pattern if new notifiers are introduced (e.g., a `MapStateNotifier` for hover state)
- Abstract interface + stub implementation: `AdService`/`StubAdService` already in `lib/features/ads/` — mirror this for `AudioService`/`StubAudioService` in `lib/features/map/` or `lib/core/`
- Feature-folder structure: new Phase 3 widgets go in `lib/features/map/` (map painter, DragTarget overlay), tray widget in `lib/features/game/`

### Integration Points
- `GameSessionNotifier.recordDrop(isoCode, isCorrect: true/false)` — called by drop event handler in the `DragTarget.onAcceptWithDetails` callback
- `GameSessionNotifier.completeGame()` — called explicitly by the widget after the 196th correct match, NOT auto-triggered by `recordDrop()`
- `CountryDataService` → loaded via Riverpod provider, passed to `WorldMapPainter` and hit-detection logic
- `lib/core/l10n/` ARB files — any new UI strings (zoom button tooltips, completion screen text) must be externalized here per I18N-01

</code_context>

<specifics>
## Specific Ideas

- **Coordinate-transform spike** is Plan 1 of Phase 3 — it must produce a passing manual test before WorldMapPainter work begins. The spike output (the widget + verified approach) is the architecture foundation for the entire drag system. Do not merge the spike into the main WorldMapPainter widget — keep it as a separate standalone screen that can be re-run during development.
- **Atlas palette suggestion**: use a 6-color scheme similar to standard political maps — soft greens, tans, oranges, pinks, purples, and light yellows. Keep saturation moderate so the bright gold drag-highlight (#FFD700) stands out clearly.
- **Country label readability**: at 1× zoom the entire world is visible; most labels will overlap or be unreadable. This is acceptable — the labels are most valuable at 2×–4× zoom. Use `canvas.clipRect(bounds)` to avoid label text escaping the painted country area.
- **Pinned flag icons on map**: after a correct match, pin a mini version of the flag SVG (or a colored dot if SVG rendering is expensive) at the country centroid. This "flag trail" is satisfying feedback that shows how many countries have been matched.
- **`AudioService` location**: `lib/core/audio/audio_service.dart` (abstract) + `lib/core/audio/stub_audio_service.dart`. Phase 4 or 5 provides `RealAudioService` — no Dart code changes in Phase 3 are needed when it's wired up.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 3-Map Rendering & Drag-Drop*
*Context gathered: 2026-05-28*
