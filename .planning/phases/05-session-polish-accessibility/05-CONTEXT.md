# Phase 5: Session Polish & Accessibility - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 delivers: a pause button in the HUD (with modal overlay pause screen), auto-pause on app background, "Continue your game?" session restore via `GameSession.matchedIsoCodes` (a new field added to the model), a first-launch coach-mark tutorial in MapScreen, portrait/landscape layout correctness, accessibility labels and 48dp touch targets, a mute toggle persisted via SharedPreferences, and social sharing gated behind a parental challenge with a privacy policy link on HomeScreen.

**In scope:**
- Add `matchedIsoCodes: List<String>` field to `GameSession` model + `GameStateRepository` serialization
- Pause button added to HUD strip (rightmost, after timer): `Score | progress | timer | pause`
- Pause modal overlay: semi-opaque sheet over the map with Resume, End Game (→ HomeScreen), and Mute toggle buttons
- Auto-pause on `AppLifecycleState.paused` via `WidgetsBindingObserver` in MapScreen
- "Continue your game?" dialog on HomeScreen: checks for saved in-progress session, shows mode name / score / elapsed / flags matched; "Continue" passes matchedIsoCodes + remainingIsoCodes in GoRouter extras to MapScreen; "Start fresh" clears the snapshot
- Sessions in countdown or other non-playing/paused state treated as bad state and cleared silently
- Coach-mark tutorial overlay on first MapScreen entry: 4 steps (flag tray → drag gesture → zoom → hint button); skip button always visible; 'tutorial_seen' bool in SharedPreferences; first launch only, no replay
- Orientation (SESS-06): portrait + landscape both work correctly (MapScreen `_fitMapToScreen()` already adapts to viewport size — verify/fix if needed)
- ACCS-01: Mute toggle button in HUD (or accessible from pause overlay); mute pref persisted in SharedPreferences, respects device silent switch
- ACCS-02: Correct/incorrect feedback verified to use shape + sound + color (not color alone)
- ACCS-03: All tappable targets ≥ 48dp; verify and fix flag tray, hint button, zoom buttons, HUD pause button
- ACCS-04: Semantic accessibility labels on all interactive elements (TalkBack / VoiceOver)
- SHAR-01–04: CompletionScreen "Share Score" button → parental gate (2-digit × 1-digit multiplication) → `RepaintBoundary.toImage()` capture of score card → stylized overlay header "New lowest score in [Level] level!" → native OS share sheet
- COMP-02: Placeholder privacy policy URL (`https://otis.brooke.dev/privacy` or similar) wired in app; small link in HomeScreen footer
- COMP-04: Verify `AD_ID` permission blocked in AndroidManifest.xml via `tools:remove` (may already exist from Phase 1 scaffold; confirm)

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
- **D-H02:** Screenshot capture uses `RepaintBoundary` with a `GlobalKey` wrapping the CompletionScreen score card widget. On share tap, call `key.currentContext!.findRenderObject()` as `RenderRepaintBoundary`, then `.toImage(pixelRatio: 3.0)`. Composite the overlay header "New lowest score in [Level Name] level!" onto the image using `Canvas.drawImage` before sharing.
- **D-H03:** Parental gate: **2-digit × 1-digit** multiplication puzzle (e.g., `43 × 7 = ?`). Random operands regenerated each time. User types the answer on a numeric keypad. Wrong answer: show "Incorrect — try again" and generate a new problem. No limit on attempts. Correct: proceed to share.
- **D-H04:** Privacy policy URL: **placeholder `https://otis.brooke.dev/privacy`** (or similar) wired as a constant in a `constants.dart` file. A small "Privacy Policy" tappable text in the HomeScreen footer opens this URL via `url_launcher`. The same URL will be entered in the Play Store listing before publish.

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
- `url_launcher` package: needed for privacy policy link. Check if already in pubspec.yaml; add if not.
- `Share` (share_plus package): for OS share sheet in SHAR-04. Check if already in pubspec.yaml; add if not.

</code_context>

<specifics>
## Specific Ideas

- **Pause button icon**: use `Icons.pause` in the HUD. When game is paused (phase == paused), the HUD could show `Icons.play_arrow` to hint at "tap to resume" — but since the pause overlay takes over, the HUD pause state isn't tapped directly while paused. Keep it simple: always `Icons.pause`.
- **Mute placement**: the mute toggle appears inside the pause overlay (alongside Resume and End Game). Additionally, ACCS-01 says it should be "visible in the HUD". Consider a small speaker icon in the HUD after the pause button: `Score | progress | timer | 🔇 | ⏸`. Or keep it only in the pause overlay for cleaner HUD design — this is a discretion call for the planner.
- **Tutorial animation**: the "drag gesture" step doesn't need to actually drag the real flag — an animated `CustomPaint` hand-cursor overlay moving from tray position toward a country centroid is sufficient to convey the mechanic without triggering game state.
- **Parental gate in CompletionScreen**: the gate dialog is an `AlertDialog` with a `TextField` (numeric keyboard). Generate new operands on each dialog open. Three incorrect attempts do NOT lock — just regenerate a new problem (COPPA: no lock-out that could frustrate a child trying to use a parent's phone).
- **`url_launcher` and `share_plus`**: both are common Flutter packages. The researcher should confirm if they're already in pubspec.yaml and add them if not.
- **GoRouter `onExit` guard**: the CLAUDE.md tech stack mentions "GoRouter with onExit back-button guard" — this was deferred from Phase 4. Phase 5 should add `onExit` to the `/play/:mode` route that shows a "Quit game?" confirmation dialog when the Android back button is pressed mid-game.
- **`clearSession()` on GameStateRepository**: this new method simply calls `_prefs.remove(_key)`. Needed for "Start fresh" and for `completeGame()` — completed sessions should be cleared so next launch doesn't offer "Continue".

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 5-Session Polish & Accessibility*
*Context gathered: 2026-05-29*
