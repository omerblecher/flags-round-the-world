# Phase 5: Session Polish & Accessibility - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 delivers: a pause button in the HUD (with modal overlay pause screen), auto-pause on app background, "Continue your game?" session restore via `GameSession.matchedIsoCodes` (a new field added to the model), a first-launch coach-mark tutorial in MapScreen, portrait/landscape layout correctness, accessibility labels and 48dp touch targets, a mute toggle persisted via SharedPreferences, social sharing gated behind a parental challenge with a privacy policy link on HomeScreen, plus three canvas/UX fixes identified from build video review: zoom-dependent label culling, 48dp proximity-snap hit targets via viewport-area threshold, and canvas bounds backfill to eliminate black letterboxing.

**In scope:**
- Add `matchedIsoCodes: List<String>` field to `GameSession` model + `GameStateRepository` serialization
- Pause button added to HUD strip (rightmost, after timer): `Score | progress | timer | pause`
- Pause modal overlay: semi-opaque sheet over the map with Resume, End Game (→ HomeScreen), and Mute toggle buttons
- Auto-pause on `AppLifecycleState.paused` via `WidgetsBindingObserver` in MapScreen
- "Continue your game?" dialog on HomeScreen: checks for saved in-progress session, shows mode name / score / elapsed / flags matched; "Continue" passes matchedIsoCodes + remainingIsoCodes in GoRouter extras to MapScreen; "Start fresh" clears the snapshot
- Sessions in countdown or other non-playing/paused state treated as bad state and cleared silently
- Coach-mark tutorial overlay on first MapScreen entry: 4 steps (flag tray → drag gesture → zoom → hint button); skip button always visible; 'tutorial_seen' bool in SharedPreferences; first launch only, no replay; game timer must NOT start until the tutorial is dismissed
- Orientation (SESS-06): portrait + landscape both work correctly (MapScreen `_fitMapToScreen()` already adapts to viewport size — verify/fix if needed)
- ACCS-01: Mute toggle button in HUD (or accessible from pause overlay); mute pref persisted in SharedPreferences, respects device silent switch
- ACCS-02: Correct/incorrect feedback verified to use shape + sound + color (not color alone)
- ACCS-03: All tappable targets ≥ 48dp; verify and fix flag tray, hint button, zoom buttons, HUD pause button
- ACCS-04: Semantic accessibility labels on all interactive elements (TalkBack / VoiceOver)
- SHAR-01–04: CompletionScreen "Share Score" button → parental gate (2-digit × 1-digit multiplication, 3 failed attempts regenerate a new problem rather than locking out) → `RepaintBoundary.toImage()` capture of score card → stylized overlay header "New lowest score in [Level] level!" → native OS share sheet via `share_plus`
- COMP-02: Privacy policy URL `https://otis.brooke.dev/privacy` wired as a constant; small "Privacy Policy" link in HomeScreen footer via `url_launcher`
- COMP-04: Add `AD_ID` permission block via `tools:remove` to AndroidManifest.xml
- **VIS-01 Zoom-dependent label culling:** `WorldMapPainter` receives `viewScale` (currently passed to `HighlightPainter` but not `WorldMapPainter`). Labels for micro-states (bbox diagonal < 30 scene units) are suppressed below 2.5× viewport scale and fade in smoothly above it. Labels for small countries (bbox diagonal < 100 units) suppress below 1.5× and fade in above. Large countries always show labels. Use opacity variation in `TextSpan` style rather than per-country `AnimatedOpacity` (painter context; no widget layer).
- **VIS-02 Radial proximity-snap hit targets:** The existing `hitTest` already expands degenerate countries; Phase 5 adds an explicit **viewport-area threshold**. Any country whose on-screen bounding-box area (bbox area × scale²) is below a configurable pixel threshold (≈ 2304 px², i.e. a 48×48dp square) receives centroid-based radial expansion to guarantee a 48dp tap target regardless of shape. This replaces the current diagonal-based expansion for those countries.
- **VIS-03 Canvas bounds backfill:** Wrap the `Expanded(Stack(...))` map area in a `ColoredBox` using `_oceanColor` (`0xFFA8D5E8`). This fills the space outside the map canvas when zoomed out, eliminating the black letterboxing. No change to `WorldMapPainter` needed — the fix is in the widget layout layer.

**Out of scope:**
- Real AdMob rewarded ads — stub continues (Phase 6)
- Real audio assets — stub/existing continues (not in Phase 5 scope)
- Firebase of any kind (permanently excluded)
- Global leaderboards (v2 only)

</domain>

<decisions>
## Implementation Decisions

### Pause Screen
- **D-P01:** Pause button is added to `GameHud` as the rightmost element: `Score | progress bar | timer | [pause icon]`. The HUD may need a slight height increase (36px → 48px) to meet ACCS-03's 48dp touch target requirement; this is a two-for-one improvement.
- **D-P02:** The pause screen is a **modal overlay** — a semi-opaque `Container` (or `showModalBottomSheet`) laid over the map. No navigation push. Dismissing (or tapping Resume) calls `resumeGame()` and removes the overlay.
- **D-P03:** Pause overlay contains exactly three controls: **Resume** (calls `resumeGame()`), **End Game** (calls `pauseGame()` then `context.go('/')` — no completion screen), and **Mute toggle** (toggles audio and persists to SharedPreferences).
- **D-P04:** Auto-pause: `_MapScreenState` mixes in `WidgetsBindingObserver`. On `AppLifecycleState.paused`, call `gameSessionProvider.notifier.pauseGame()`. On `AppLifecycleState.resumed`, leave paused — do NOT auto-resume (the overlay stays visible so the player consciously taps Resume).

### Session Restore
- **D-S01:** `GameSession` gets a new field: `matchedIsoCodes: List<String>` (default `const []`). `GameStateRepository.saveSession()` serializes it as a JSON array; `loadSession()` deserializes it. This is the minimal change needed to make the "Continue?" flow correct.
- **D-S02:** `HomeScreen` checks for a saved session on `initState` (reads from `GameStateRepository`). If a session is found with `phase == GamePhase.playing || phase == GamePhase.paused`, show a dialog with: mode name, score, elapsed time (MM:SS), flags matched count. Sessions in any other phase (countdown, idle, completed) are cleared silently.
- **D-S03:** Dialog buttons: **"Continue"** and **"Start fresh"**. "Start fresh" clears the snapshot (calls `gameStateRepository.clearSession()` — add this method) and dismisses. "Continue" builds the remaining flag sequence by calling `buildFlagSequence(countries)` then filtering out `matchedIsoCodes`, and navigates via `context.go('/play/${mode.name}', extra: {'matchedIsoCodes': ..., 'remainingIsoCodes': ...})`.
- **D-S04:** `MapScreen` checks `GoRouter` extras on init: if `matchedIsoCodes` is present, initialize `_matchedIsoCodes` from it and skip the normal sequence build. The sequence is then the passed `remainingIsoCodes`. The notifier's `startGame()` is called with the restored elapsed time and error count (need a `restoreGame(session)` method or extend `startGame` with optional restore params).

### Tutorial
- **D-T01:** Tutorial is a **coach-mark overlay** displayed on top of the real MapScreen. It shows 4 sequential steps, each highlighting a UI element with a spotlight + arrow + caption. Steps: (1) Flag tray — "This is the flag you need to place"; (2) Drag gesture — animated cursor/hand drags flag toward country; (3) Zoom buttons — "Pinch or use these buttons to zoom"; (4) Hint button — "Out of ideas? Use a hint".
- **D-T02:** A **Skip button** is always visible from the first frame (top-right or floating). Tapping Skip immediately dismisses all steps and sets `tutorial_seen = true` in SharedPreferences.
- **D-T03:** Tutorial triggers only on the first entry to `MapScreen` (not HomeScreen). `MapScreen.initState` reads `tutorial_seen` from SharedPreferences. If false, shows the tutorial overlay after the map loads (`addPostFrameCallback`). First-launch only — no replay path.
- **D-T04:** Tutorial does NOT auto-advance between steps. Player taps "Next" (or "Got it") to advance. This ensures the timer doesn't start until the tutorial is dismissed (tutorial auto-pauses the game, or game starts only after tutorial dismiss).

### Social Sharing
- **D-H01:** CompletionScreen gets a "Share Score" button (visible only when the game produced a personal best, or always — decide at implementation time based on SHAR-01 wording: "victory screen" = completion screen).
- **D-H02:** Screenshot capture uses `RepaintBoundary` with a `GlobalKey` wrapping the CompletionScreen score card widget. On share tap, call `key.currentContext!.findRenderObject()` as `RenderRepaintBoundary`, then `.toImage(pixelRatio: 3.0)`. Composite the overlay header "New lowest score in [Level Name] level!" onto the image using `Canvas.drawImage` before sharing. Save to a temp file and share via `share_plus`.
- **D-H03:** Parental gate: **2-digit × 1-digit** multiplication puzzle (e.g., `43 × 7 = ?`). Random operands regenerated each time. User types the answer on a numeric keypad. **3 failed attempts regenerate a new problem — no lockout** (avoids frustrating a parent on a child's phone; COPPA best practice). Correct: proceed to share.
- **D-H04:** Privacy policy URL: **`https://otis.brooke.dev/privacy`** wired as a constant in `lib/core/constants.dart`. A small "Privacy Policy" tappable text in the HomeScreen footer opens this URL via `url_launcher`. Same URL in the Play Store listing before publish.

### Canvas & UX Fixes (from build review)
- **D-V01:** `WorldMapPainter` receives a new `viewScale: double` constructor parameter (default `1.0`). In `_drawLabel`, compute label opacity: micro-state countries (bbox diagonal < 30 scene units) → `opacity = ((viewScale − 2.5) / 1.0).clamp(0.0, 1.0)`; small countries (bbox diagonal < 100 units) → `opacity = ((viewScale − 1.5) / 1.0).clamp(0.0, 1.0)`; large countries → `opacity = 1.0`. Skip drawing if opacity == 0. Color alpha encodes opacity. `MapScreen` passes `_currentScale` (already tracked) to `WorldMapPainter`. `shouldRepaint` adds `old.viewScale != viewScale`.
- **D-V02:** `hitTest` in `hit_detection.dart` gains a **viewport-area threshold check**. Define `const double _kMinScreenArea = 2304.0` (48px × 48px, the ACCS-03 minimum). Any country whose on-screen bbox area (`rect.width * rect.height * scale * scale`) is below `_kMinScreenArea` gets its expansion target set to a circle of radius `48.0 / scale` centred on its centroid, overriding the diagonal-based expansion. This guarantees a physical 48dp tappable target for every country regardless of its SVG size.
- **D-V03:** In `MapScreen._buildMap`, wrap the `Expanded(Stack([...InteractiveViewer...]))` map section with `ColoredBox(color: const Color(0xFFA8D5E8), ...)`. The `_oceanColor` constant value used in `WorldMapPainter` is `0xFFA8D5E8` — the `ColoredBox` uses the same value so the background matches the painted ocean seamlessly. No painter change needed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 5 Requirements & Scope
- `.planning/ROADMAP.md` §Phase 5 — Phase goal, requirements list (SESS-01–07, ACCS-01–04, SHAR-01–04, COMP-02, COMP-04), 7 success criteria
- `.planning/REQUIREMENTS.md` §Session Management (SESS-01–07), §Accessibility (ACCS-01–04), §Social Sharing (SHAR-01–04), §Infrastructure & Compliance (COMP-02, COMP-04) — full requirement text

### Architecture (LOCKED)
- `CLAUDE.md` §Critical Architecture Decisions — D4 (ad walled garden: zero imports from features/ads/), D5 (no Firebase), tech stack table (GoRouter, shared_preferences, Riverpod)

### Foundation (what Phase 5 builds on)
- `.planning/phases/04-game-modes-scoring/04-CONTEXT.md` — GoRouter routes, GameHud design (D-B01–03), FlagTray hint pattern (D-C01–03)
- `.planning/phases/02-state-data-layer/02-CONTEXT.md` — GameSessionNotifier API (pauseGame/resumeGame/startGame), D-07 (manual AsyncNotifier pattern), D-10 (repository pattern)
- `lib/features/game/game_session_notifier.dart` — `pauseGame()`, `resumeGame()`, `startGame(GameMode mode)` — Phase 5 extends these
- `lib/features/game/game_session.dart` — current model fields; Phase 5 adds `matchedIsoCodes: List<String>`
- `lib/core/data/game_state_repository.dart` — `saveSession()` / `loadSession()` already implemented; Phase 5 adds `clearSession()` and extends JSON serialization for `matchedIsoCodes`
- `lib/features/game/game_hud.dart` — current HUD widget (36px, no pause button); Phase 5 adds pause icon + potentially expands height to 48px
- `lib/features/map/map_screen.dart` — `_MapScreenState`; Phase 5 adds `WidgetsBindingObserver`, pause overlay, tutorial overlay, GoRouter extras handling
- `lib/features/home/home_screen.dart` — Phase 5 adds session-restore dialog and privacy policy footer
- `lib/features/map/completion_screen.dart` — Phase 5 adds "Share Score" button and screenshot capture
- `lib/app.dart` — GoRouter config; Phase 5 may add `onExit` guard to `/play/:mode` route (back-button safety)
- `lib/core/audio/audio_service.dart` — abstract AudioService interface; Phase 5 wires mute toggle through it

### Compliance
- `android/app/src/main/AndroidManifest.xml` — verify `AD_ID` permission is blocked via `tools:remove` (COMP-04)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/game/game_session_notifier.dart` — `pauseGame()` / `resumeGame()` are fully implemented. Phase 5 only needs to wire them to the pause button tap and `AppLifecycleObserver`.
- `lib/core/data/game_state_repository.dart` — `saveSession()` is already called on every correct drop and hint use (SESS-03 partially satisfied). Phase 5 extends the JSON schema, adds `clearSession()`, and wires `loadSession()` in HomeScreen.
- `lib/features/game/game_hud.dart` — `GameHud` is a `StatelessWidget` receiving `score`, `elapsed`, `matchedCount`, `totalFlags`. Adding a pause button requires adding an `onPause: VoidCallback` param. No state change in `GameHud` itself.
- `lib/core/audio/audio_service.dart` + `lib/core/audio/stub_audio_service.dart` — mute toggle calls `audioService.setMuted(bool)` (add method to interface) or can be a separate `MuteRepository` using SharedPreferences. Simpler: add `isMuted` getter + `setMuted()` to `AudioService` abstract interface; `RealAudioService` wires it to `just_audio` volume; `StubAudioService` no-ops.
- `lib/features/map/map_screen.dart` — `_fitMapToScreen()` already reads viewport size via `RenderBox` — should work for both portrait and landscape without changes. Verify by rotating during testing.

### Established Patterns
- Manual `AsyncNotifier` + top-level provider (no codegen) — any new notifier (e.g., `MuteNotifier` if mute state needs to be reactive across widgets) follows the same pattern
- Abstract interface + stub: `AdService`/`StubAdService` — mute toggle through `AudioService` follows the same pattern
- SharedPreferences access via `SharedPreferencesGameStateRepository` pattern — `tutorial_seen` and `mute_pref` can go in a lightweight `UserPrefsRepository` following the same abstract-interface approach

### Integration Points
- `GoRouter` extras: Phase 5 adds `extra: {'matchedIsoCodes': List<String>, 'remainingIsoCodes': List<String>, 'restoredSession': GameSession}` to the `/play/:mode` navigation from HomeScreen on "Continue". `app.dart` GoRoute builder for `/play/:mode` must parse these extras.
- `WidgetsBindingObserver` in `_MapScreenState`: `@override void didChangeAppLifecycleState(AppLifecycleState state)` — calls `pauseGame()` on `AppLifecycleState.paused`.
- `url_launcher` package: NOT currently in pubspec.yaml — must be added for privacy policy link.
- `share_plus` package: NOT currently in pubspec.yaml — must be added for OS share sheet in SHAR-04.
- `WorldMapPainter` call sites in `MapScreen._buildMap`: currently passes `showLabels`, `countryNames`, `matchedIsoCodes` — Phase 5 adds `viewScale: _currentScale`. `_currentScale` is already tracked in `_MapScreenState`.
- `hitTest()` call sites in `map_screen.dart` (2 calls in `onWillAcceptWithDetails` and `onAcceptWithDetails`): existing `scale:` param already passed — `hit_detection.dart` changes are internal, no call-site changes needed.
- `ColoredBox` wrapping map area in `MapScreen._buildMap` — one-line layout change.

</code_context>

<specifics>
## Specific Ideas

- **Pause button icon**: use `Icons.pause` in the HUD. Keep it simple — always `Icons.pause` since the overlay takes over when paused.
- **Mute placement**: ACCS-01 says mute should be "visible in the HUD". Add a small speaker icon after the pause button: `Score | progress | timer | 🔇 | ⏸`. Tapping opens an inline toggle. Also present in pause overlay. Planner decides final placement.
- **Tutorial animation**: the drag gesture step uses a `CustomPaint` hand-cursor overlay with an `AnimationController`. The cursor moves from the tray's flag card position toward the nearest country centroid (e.g. France or Germany — large and visible). It must NOT trigger the actual `Draggable` — purely visual.
- **Tutorial and game timer**: the `startGame()` call in `MapScreen` must be deferred until the tutorial is dismissed. Either delay `startGame()` until the tutorial `onDismiss` callback fires, or show the tutorial before the sequence is initialized. Best approach: tutorial runs before `_initSequence()` is called.
- **Parental gate**: `AlertDialog` + `TextField` (numeric keyboard). Wrong answer: show inline error "Incorrect — try again" and generate new problem. No attempt limit — regenerate on each wrong answer. Correct: proceed to `share_plus` flow.
- **`clearSession()` on GameStateRepository**: simply calls `_prefs.remove(_key)`. Needed for "Start fresh" AND for `completeGame()` — completed sessions must be cleared so next launch doesn't offer "Continue".
- **`restoreGame(GameSession)` on `GameSessionNotifier`**: sets `_elapsedSeconds = session.elapsed.inSeconds`, derives `_hintPenalty = session.score − (elapsed ~/ 10) − (errorCount × 5)`, skips countdown, calls `state = AsyncData(session.copyWith(phase: GamePhase.playing))` and starts the ticker. The `_remainingIsoCodes` field in the notifier is unused (MapScreen owns sequence state) so no change there.
- **Label opacity implementation**: since `CustomPainter` has no widget tree, implement opacity by computing alpha in `_drawLabel` and passing it to `TextSpan` color: `Color(_labelColor.value).withValues(alpha: opacity)`. For opacity == 0, return early without painting. This avoids a `saveLayer` call.
- **Viewport-area threshold**: `_kMinScreenArea = 2304.0` (48 × 48 logical pixels). The check is `bbox.width * bbox.height * scale * scale < _kMinScreenArea`. Countries satisfying this get a circular expansion of radius `sqrt(_kMinScreenArea / pi) / scale` centred on `country.centroid`. Researcher should verify this formula gives ≈ 27 scene-unit radius at 1× for a 48dp target.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 5-Session Polish & Accessibility*
*Context gathered: 2026-05-29*
