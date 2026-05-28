# Phase 4: Game Modes & Scoring - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-28
**Phase:** 4-Game Modes & Scoring
**Areas discussed:** Mode selection screen, Live HUD design, Hint reveal UX, Star rating & PB flow

---

## Mode Selection Screen

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated home screen | New HomeScreen with 4 mode cards replaces direct-to-map launch | ✓ |
| Mode picker overlay on launch | MapScreen loads first, bottom sheet slides up for mode selection | |
| You decide | Leave navigation structure to the planner | |

**User's choice:** Dedicated home screen

| Option | Description | Selected |
|--------|-------------|----------|
| Mode buttons + best scores per mode | Show PB score beneath each mode card | ✓ |
| Mode buttons only | Minimal — just 4 mode options | |
| Mode buttons + app title/branding | App name, logo, then 4 mode buttons | |

**User's choice:** Mode buttons + best scores per mode

| Option | Description | Selected |
|--------|-------------|----------|
| Vertical list of cards | One card per mode with name + 1-line description | ✓ |
| 2×2 grid of large icon buttons | Four square tiles, icon-driven | |
| You decide | Leave visual layout to the planner | |

**User's choice:** Vertical list of cards

**Notes:** User also clarified mid-discussion that map labels and flag tray name labels must show **full localized country names**, not ISO abbreviations. Phase 3 left `WorldMapPainter._drawLabel()` rendering `country.isoCode` — Phase 4 must fix this by adding a `countryNames: Map<String, String>` parameter and rendering full names.

---

## Live HUD Design

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed top strip above the map | Non-scrolling HUD row above InteractiveViewer (~56dp) | ✓ |
| Floating overlay on top of the map | HUD floats in a Stack, semi-transparent, map uses full height | |

**User's choice:** Fixed top strip above the map

| Option | Description | Selected |
|--------|-------------|----------|
| Score \| Progress bar (center) \| Timer | Score left, MM:SS timer right, progress bar center | ✓ |
| Timer \| Progress bar \| Score \| Hint button | Timer left, score right, hint button in HUD | |
| You decide | Leave element order to the planner | |

**User's choice:** Score | Progress bar (center) | Timer

| Option | Description | Selected |
|--------|-------------|----------|
| In the flag tray | Hint button alongside flag card in the bottom tray | ✓ |
| In the top HUD strip | Hint button part of the HUD row | |
| You decide | Leave hint button placement to the planner | |

**User's choice:** In the flag tray

---

## Hint Reveal UX

| Option | Description | Selected |
|--------|-------------|----------|
| Zoom/pan to country + pulsing highlight | animateTo centers on target, pulses for ~3s | ✓ |
| Pulsing highlight only (no camera move) | Country pulses in place; may be off-screen | |
| Arrow/pointer overlay | Directional arrow pointing toward target | |

**User's choice:** Zoom/pan to country + pulsing highlight

| Option | Description | Selected |
|--------|-------------|----------|
| 3 seconds then auto-dismiss | Highlight pulses for 3s, country returns to atlas color | ✓ |
| Until next drop (persistent) | Highlight stays on until player makes a drop | |
| You decide | Leave duration to the planner | |

**User's choice:** 3 seconds then auto-dismiss

| Option | Description | Selected |
|--------|-------------|----------|
| Dialog: 'Watch an ad to refill hints' with Watch / Cancel | Modal dialog; ad stub fails in Phase 4, wired for Phase 6 | ✓ |
| Inline message in tray | Message/button in the tray area, no modal | |

**User's choice:** Dialog with Watch / Cancel

---

## Star Rating & PB Flow

| Option | Description | Selected |
|--------|-------------|----------|
| First game always sets PB and shows 3 stars | Encouraging; any first-game score is the new best | ✓ |
| First game shows 1 star | No comparison baseline; may feel discouraging | |
| First game skips stars entirely | Stars only on subsequent games | |

**User's choice:** First game → 3 stars, sets PB, no celebration overlay

| Option | Description | Selected |
|--------|-------------|----------|
| 3 = beat PB, 2 = within 20%, 1 = rest | Tight threshold rewards real improvement | ✓ |
| 3 = beat PB, 2 = within 50%, 1 = rest | More generous 2-star threshold | |
| You decide | Leave thresholds to the planner | |

**User's choice:** 3 stars = beat PB, 2 stars = within 20%, 1 star = otherwise

| Option | Description | Selected |
|--------|-------------|----------|
| Celebration overlay on completion screen | 'New Personal Best!' banner + confetti overlay ~2s, one screen | ✓ |
| Separate celebration screen before completion | Full splash screen, then navigate to completion (two screens) | |
| You decide | Leave PB presentation to the planner | |

**User's choice:** Celebration overlay on the completion screen

---

## Claude's Discretion

None — all areas had a clear user selection.

## Deferred Ideas

None — discussion stayed within phase scope.
