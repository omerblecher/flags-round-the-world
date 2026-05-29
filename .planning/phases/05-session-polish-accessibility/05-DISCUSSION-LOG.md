# Phase 5: Session Polish & Accessibility - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-29
**Phase:** 5-Session Polish & Accessibility
**Areas discussed:** Pause screen, Session restore, Tutorial, Sharing + privacy

---

## Pause Screen

### Q1: Where does the pause button live in the HUD?

| Option | Description | Selected |
|--------|-------------|----------|
| Add to HUD strip | Squeeze a small pause icon into the HUD — leftmost or rightmost. Consistent control bar. | ✓ |
| Floating button over the map | Semi-transparent FAB in top-right of map area. Doesn't require resizing HUD. | |
| Expand HUD height | Grow HUD to ~48–56px and add pause button prominently. | |

**User's choice:** Add to HUD strip
**Notes:** Rightmost placement chosen in follow-up (after timer).

---

### Q2: Where exactly in the HUD row?

| Option | Description | Selected |
|--------|-------------|----------|
| Rightmost — after the timer | Score \| progress bar \| timer \| pause. Thumb-friendly for right-handed players. | ✓ |
| Leftmost — before the score | Pause \| score \| progress bar \| timer. Mirrors media player layout. | |

**User's choice:** Rightmost — after the timer

---

### Q3: What form does the pause screen take?

| Option | Description | Selected |
|--------|-------------|----------|
| Modal overlay on top of the map | Semi-opaque sheet slides over game, blurring/dimming map behind. No nav push. | ✓ |
| Full-screen dedicated screen | GoRouter pushes /pause route. Hides map entirely. | |

**User's choice:** Modal overlay

---

### Q4: What controls appear on the pause overlay?

| Option | Description | Selected |
|--------|-------------|----------|
| Resume (required) | Dismiss overlay and resume the timer. | ✓ |
| End Game (required per SESS-07) | Ends session, navigates to HomeScreen. No completion screen. | ✓ |
| Mute toggle (ACCS-01) | Toggle audio on/off, persists via shared_preferences. | ✓ |
| Mode name display | Show current mode as read-only context. | |

**User's choice:** Resume, End Game, Mute toggle

---

## Session Restore

### Q1: How should matchedIsoCodes be stored?

| Option | Description | Selected |
|--------|-------------|----------|
| Add matchedIsoCodes: List<String> to GameSession | GameSession gets new field; repository serializes as JSON array. | ✓ |
| Store separately in SharedPreferences | Separate key outside GameSession. Inconsistent but works. | |

**User's choice:** Add matchedIsoCodes to GameSession model
**Notes:** This is a critical architectural fix — without it, "Continue?" can't restore progress.

---

### Q2: Where does the "Continue your game?" dialog appear?

| Option | Description | Selected |
|--------|-------------|----------|
| On HomeScreen before mode list | HomeScreen checks for saved session, shows dialog with mode/score/elapsed/flags matched. | ✓ |
| On app launch before HomeScreen | Splash/intercept screen. More prominent but more complex routing. | |

**User's choice:** On HomeScreen before mode list

---

### Q3: What happens on "Start fresh"?

| Option | Description | Selected |
|--------|-------------|----------|
| Clear saved session and show normal HomeScreen | Delete snapshot from SharedPreferences, dismiss dialog, normal HomeScreen. | ✓ |
| Navigate to the mode that was in progress | Pre-select that mode's card but still require a tap to start. | |

**User's choice:** Clear saved session and show normal HomeScreen
**Notes:** Sessions in non-playing/paused state (countdown, idle, completed) are cleared silently.

---

### Q4: How does MapScreen restore matched flags?

| Option | Description | Selected |
|--------|-------------|----------|
| Pass matchedIsoCodes + remainingIsoCodes in GoRouter extras | HomeScreen builds remaining sequence and passes both sets as extras to MapScreen. | ✓ |
| MapScreen reads from GameStateRepository directly | MapScreen self-heals in initState. Simpler routing but MapScreen does more work. | |

**User's choice:** Pass via GoRouter extras

---

## Tutorial

### Q1: What form does the tutorial take?

| Option | Description | Selected |
|--------|-------------|----------|
| Overlay steps on the real game | Coach-mark overlay on actual MapScreen — spotlight + arrow + caption per step. | ✓ |
| Dedicated tutorial screen | Separate screen with illustrated animations. Requires new assets. | |

**User's choice:** Overlay steps on the real game

---

### Q2: What steps does the tutorial demonstrate?

| Option | Description | Selected |
|--------|-------------|----------|
| The flag card in the tray | Spotlight on flag tray: "This is the flag you need to place." | ✓ |
| Drag gesture | Animated hand drags flag to a country. Shows core mechanic. | ✓ |
| Zoom gesture | Highlight zoom buttons + pinch animation. | ✓ |
| Hint button | Point out hint button with count badge. | ✓ |

**User's choice:** All four steps

---

### Q3: When does the tutorial trigger?

| Option | Description | Selected |
|--------|-------------|----------|
| First launch only, no re-trigger | 'tutorial_seen' bool in SharedPreferences. No replay. | ✓ |
| First launch only, re-triggerable from HomeScreen | Same flag + a "How to play" button on HomeScreen. | |

**User's choice:** First launch only, no re-trigger

---

### Q4: When exactly during first launch?

| Option | Description | Selected |
|--------|-------------|----------|
| When the player first enters MapScreen | Shows after map loads via addPostFrameCallback. | ✓ |
| On HomeScreen before picking a mode | Tutorial overlays HomeScreen explaining mode cards. | |

**User's choice:** First entry to MapScreen

---

## Sharing + Privacy

### Q1: Screenshot capture approach

| Option | Description | Selected |
|--------|-------------|----------|
| RepaintBoundary.toImage() on CompletionScreen | Wrap score card in RepaintBoundary with GlobalKey. Capture widget area only. | ✓ |
| Full screenshot via render_screenshot package | Captures entire screen including system UI chrome. Extra package needed. | |

**User's choice:** RepaintBoundary.toImage()

---

### Q2: Parental gate difficulty

| Option | Description | Selected |
|--------|-------------|----------|
| 2-digit × 1-digit (e.g. 43 × 7 = ?) | Doable by adults, challenging for children. Fast on numeric keypad. | ✓ |
| 2-digit × 2-digit (e.g. 43 × 17 = ?) | Harder — requires written calculation. May frustrate adults. | |

**User's choice:** 2-digit × 1-digit

---

### Q3: Privacy policy approach

| Option | Description | Selected |
|--------|-------------|----------|
| Placeholder URL in-app now, real URL before ship | Wire link now; actual hosted URL created before publishing. | ✓ |
| In-app HTML page (no external URL) | Bundle static HTML opened in WebView. Play Store still requires public URL. | |

**User's choice:** Placeholder URL (e.g. https://otis.brooke.dev/privacy)

---

### Q4: Where does the privacy policy link appear?

| Option | Description | Selected |
|--------|-------------|----------|
| HomeScreen footer / settings row only | Small "Privacy Policy" link at bottom of HomeScreen. | ✓ |
| First-launch splash or about dialog | Legal notice on first app open before playing. | |

**User's choice:** HomeScreen footer only

---

## Claude's Discretion

- **HUD mute toggle placement**: user confirmed mute in pause overlay; whether a second mute icon appears in the main HUD was left to implementation discretion (see D-P03 and specifics note in CONTEXT.md)
- **Tutorial step advancement**: user did not specify tap-to-advance vs auto-advance; Claude chose tap-to-advance (D-T04) so timer doesn't start until tutorial is dismissed

## Deferred Ideas

None — discussion stayed within phase scope.
