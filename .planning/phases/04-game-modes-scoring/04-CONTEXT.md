# Phase 4: Game Modes & Scoring - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 delivers: a dedicated home/mode-selection screen, all four game modes with per-mode name visibility toggled via `showName` (FlagTray) and `showLabels` (WorldMapPainter), a fix to replace ISO-code map labels with full localized country names, a live scoring HUD strip, the 2-free-hints system with ad-stub refill dialog, and a completion screen with 1–3 star rating plus personal-best celebration overlay.

**In scope:**
- `HomeScreen` — new root screen with 4 mode cards (vertical list), each showing mode name, 1-line description of what's visible, and the player's personal best score for that mode
- Mode-specific visibility: `showName` bool on `FlagTray`, `showLabels` bool + `countryNames: Map<String, String>` on `WorldMapPainter`; map labels show full localized country name (NOT ISO code)
- Full country name labels on the map (fix Phase 3 ISO-code stub): `WorldMapPainter` receives a `Map<String, String>` (isoCode → localized name) and renders full names when `showLabels` is true
- Grand Master distinctiveness-ordered sequence (MODE-05) — researcher to define the ordering mechanism
- Live HUD strip: fixed-height row above the map — Score (left) | Progress bar (center, matched/total) | Timer MM:SS (right)
- Hint button in the flag tray (not HUD): shows remaining count, triggers zoom-to-country + 3s pulse on tap, shows "Watch ad to refill" modal when exhausted
- Completion screen with 1–3 stars + personal-best celebration overlay (banner + confetti, ~2s) when PB is beaten
- Session end navigates back to HomeScreen via GoRouter

**Out of scope:**
- Pause/resume UI and auto-pause on background (Phase 5)
- Session persistence / "Continue your game?" dialog (Phase 5)
- Accessibility labels and TalkBack (Phase 5)
- Real audio assets — stub continues from Phase 3 (a later phase)
- Real AdMob rewarded ads — stub returns AdLoadState.failed through Phase 5 (Phase 6 only)
- Social sharing (Phase 5)

</domain>

<decisions>
## Implementation Decisions

### Mode Selection Screen
- **D-A01:** Dedicated `HomeScreen` replaces the current direct-to-map launch. Player taps a mode card → `MapScreen` starts with that `GameMode`. HomeScreen is the new navigation root.
- **D-A02:** HomeScreen shows each mode's personal best score beneath its name card. `HighScoreRepository.readBest(mode)` is already implemented — call it for each of the 4 modes on HomeScreen load.
- **D-A03:** Layout: vertical list of 4 cards, each card shows the mode name + a 1-line description of what is visible in that mode (e.g., "No names anywhere" for Grand Master).

### Game Mode Name Visibility
- **D-A04:** Per-mode `showName` on `FlagTray` and `showLabels` on `WorldMapPainter`:
  - Learn: names on map (`showLabels: true`) AND under flag card (`showName: true`)
  - Flags Master: name under flag only (`showName: true`, `showLabels: false`)
  - Geographical Master: names on map only (`showLabels: true`, `showName: false`)
  - Grand Master: no names anywhere (`showLabels: false`, `showName: false`)
- **D-A05:** Map labels MUST show full localized country names — NOT ISO codes. Phase 3 left a stub rendering `country.isoCode`; Phase 4 fixes this. `WorldMapPainter` receives a `Map<String, String> countryNames` parameter (isoCode → name from locale JSON). `FlagTray` already accepts `countryName` as a full String — no change needed there.

### Live HUD Design
- **D-B01:** HUD is a fixed-height strip above the map — `Column([HudStrip, Expanded(InteractiveViewer), FlagTray])`. Not floating/overlapping. Always fully visible.
- **D-B02:** HUD layout left-to-right: Score (left) | Progress bar (center, flags matched / 196) | Timer MM:SS (right). Progress bar spans the available width between score and timer.
- **D-B03:** Hint button lives in the flag tray area (alongside the flag card) — NOT in the HUD strip. The tray shows the hint button with remaining count (e.g., "Hint ×2").

### Hint Reveal UX
- **D-C01:** Tapping hint (when hints remain): map animates to center on the target country via `TransformationController` `animateTo`, then the target country pulses with a distinct highlight color for ~3 seconds, then auto-reverts to its atlas color. Uses the existing `HighlightPainter` / `_hoveredIso` mechanism or a new `_hintIso` state field.
- **D-C02:** Hint highlight auto-dismisses after 3 seconds (Timer-based). Country returns to normal atlas color. The hint count decrements immediately on tap (before the animation).
- **D-C03:** When all hints are exhausted and the player taps the hint button: show a modal dialog "No hints left — watch an ad to refill?" with Watch / Cancel. In Phase 4 the ad stub always returns `AdLoadState.failed` (per CLAUDE.md), so Cancel is the only functional path. The dialog and flow are fully wired so Phase 6 can replace the stub without UI changes.

### Star Rating & Personal Best
- **D-D01:** First game (no prior best): 3 stars always shown (the score IS the new personal best). No PB celebration overlay (nothing to beat). Score is written to `HighScoreRepository` on game completion.
- **D-D02:** Subsequent games: 3 stars = player beat their personal best; 2 stars = score within 20% of best (i.e., `newScore <= bestScore * 1.20`); 1 star = otherwise. Lower score is better (golf-style).
- **D-D03:** When a PB is beaten: completion screen slides in normally, then a "New Personal Best!" banner + confetti burst animates as an overlay for ~2 seconds before settling. One screen — no separate navigation step. Stars (3) remain visible beneath the overlay.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 4 Requirements & Scope
- `.planning/ROADMAP.md` §Phase 4 — Phase goal, requirements list (MODE-01–05, SCOR-03/05/06/07, GAME-07/08), and 5 success criteria
- `.planning/REQUIREMENTS.md` §Game Modes (MODE-01–05), §Gameplay (GAME-07–08), §Scoring & Progress (SCOR-03/05/06/07) — full requirement text for Phase 4 scope

### Architecture (LOCKED)
- `CLAUDE.md` §Critical Architecture Decisions — D1 (Flutter+CustomPainter+InteractiveViewer), D3 (tray OUTSIDE InteractiveViewer, DragTargets INSIDE, TransformationController.toScene()), D4 (ad walled garden: GameSessionNotifier zero imports from features/ads/), D5 (no Firebase)

### Phase 2 & 3 Foundation (what Phase 4 builds on)
- `.planning/phases/02-state-data-layer/02-CONTEXT.md` — D-01 (GameSession model incl. hintsRemaining, GameMode), D-07 (manual AsyncNotifier pattern), D-10 (HighScoreRepository and GameStateRepository), D-13 (scoring formula)
- `.planning/phases/03-map-rendering-drag-drop/03-CONTEXT.md` — D-04 (drag-over highlight gold color), D-05 (showLabels Phase 4 parameter deferred here), D-09 (showName Phase 4 parameter deferred here), D-12 (AudioService stub pattern), D-14/15/16 (hit detection approach)
- `lib/features/game/game_session_notifier.dart` — `startGame(mode)`, `recordDrop()`, `completeGame()`, `countdownSecondsRemaining`, existing state machine
- `lib/features/map/map_screen.dart` — existing MapScreen structure; Phase 4 adds HUD strip, mode params, hint state
- `lib/features/map/world_map_painter.dart` — current `WorldMapPainter` constructor (needs `showLabels` bool + `countryNames` Map); `_drawLabel()` currently renders isoCode — Phase 4 changes to full name
- `lib/features/game/flag_tray.dart` — `FlagTray(countryName: String)` already accepts full name; Phase 4 adds `showName` bool param
- `lib/core/data/high_score_repository.dart` — `readBest(GameMode)` and `writeBest(GameMode, int)` already implemented

### Ad Stub Boundary
- `lib/features/ads/ad_service.dart` — abstract `AdService` interface; stub returns `AdLoadState.failed` for all formats through Phase 5. Hint refill dialog calls this but expects failure. Phase 6 replaces the stub without UI changes.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/map/world_map_painter.dart` — `WorldMapPainter` needs 2 new constructor params: `bool showLabels` and `Map<String, String> countryNames`. The existing `_drawLabel()` method just needs its `text` argument changed from `country.isoCode` to `countryNames[country.isoCode] ?? country.isoCode`.
- `lib/features/map/highlight_painter.dart` — already handles a highlighted ISO code. Phase 4 can reuse or extend it for the hint pulse (separate `_hintIso` vs `_hoveredIso` so drag-hover and hint highlights don't conflict).
- `lib/features/game/flag_tray.dart` — `FlagTray(showName: bool)` param needs adding; currently always shows name. Changing to conditional is a 1-line widget change.
- `lib/core/data/high_score_repository.dart` — `readBest(GameMode)` returns `int?` (null on first game). HomeScreen uses this to show "—" when no best exists yet.
- `lib/features/map/map_screen.dart` — `buildFlagSequence()` is a top-level function producing a random shuffle. Grand Master needs a distinctiveness-ordered variant (`buildGrandMasterSequence()`), same signature.
- `lib/features/map/completion_screen.dart` — currently bare (score + elapsed + play again). Phase 4 replaces/extends it with stars, PB overlay, and navigation back to HomeScreen.

### Established Patterns
- Manual `AsyncNotifier` + top-level provider (no codegen) — any new notifier (e.g., for hint state) follows the same pattern
- Abstract interface + stub: `AdService`/`StubAdService` — hint refill dialog calls `adService.loadRewardedAd()` through the same interface; no direct AdMob calls
- Feature-folder structure: new HomeScreen in `lib/features/home/home_screen.dart`; HUD widget in `lib/features/game/game_hud.dart` or co-located in `map_screen.dart`

### Integration Points
- `GoRouter` — Phase 4 adds `HomeScreen` as the `/` root route; `MapScreen` becomes `/play/:mode`. Navigation: HomeScreen → MapScreen(mode) → CompletionScreen → HomeScreen.
- `GameSessionNotifier.startGame(GameMode mode)` — called by HomeScreen when a mode card is tapped, passing the selected `GameMode`
- `CountryDataService` / `countryDataProvider` — already loads `CountryData` list; Phase 4 also loads the locale name map (from `countries_en.json`) to pass as `countryNames` to `WorldMapPainter`
- `lib/core/l10n/` ARB files — all new UI strings (mode names, HUD labels, hint dialog text, star labels, PB banner text) must be externalized per I18N-01

</code_context>

<specifics>
## Specific Ideas

- **Grand Master sequence**: MODE-05 requires flags in "distinctiveness-ordered" sequence (most recognizable first). Researcher should determine whether this is a hardcoded ordered list in assets (e.g., `assets/data/grand_master_order.json`) or an algorithmic ranking. Either way it replaces the random shuffle only for Grand Master mode.
- **Hint zoom target**: use `TransformationController.animateTo()` with a `Matrix4` that centers the target country's centroid in the viewport at a moderate zoom level (e.g., 2×–3×). The existing spike code (from `spike_map_screen.dart`) demonstrates the coordinate math.
- **PB celebration animation**: `confetti` package is not yet in pubspec.yaml; researcher should decide whether to use it or a hand-rolled `CustomPainter` particle burst. Keep it lightweight — this runs on mid-range Android.
- **HomeScreen personal best display**: show "Best: —" when `readBest(mode)` returns null (first game), "Best: 42" after first completion. Matches the golf-style "lower is better" mental model.
- **HUD progress bar**: simple `LinearProgressIndicator` or a custom `CustomPainter` strip. Value = `matchedCount / 196`. Update on every correct drop (driven by watching `gameSessionProvider`).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 4-Game Modes & Scoring*
*Context gathered: 2026-05-28*
