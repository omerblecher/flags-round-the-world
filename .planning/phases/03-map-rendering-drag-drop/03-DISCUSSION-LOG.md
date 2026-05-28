# Phase 3: Map Rendering & Drag-Drop - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-28
**Phase:** 3-Map Rendering & Drag-Drop
**Areas discussed:** Map visual style, Flag tray design, Feedback animations, Hit-detection strategy

---

## Map Visual Style

| Option | Description | Selected |
|--------|-------------|----------|
| Flat atlas palette | 6–8 continent-grouped colors, distinct neighbors | ✓ |
| Single muted tone | All countries same light gray/beige | |
| Vibrant rainbow palette | Bold varied colors per country | |

**Ocean/background:**

| Option | Description | Selected |
|--------|-------------|----------|
| Light blue | Classic map convention — readable as ocean | ✓ |
| Dark navy | More striking contrast | |
| Off-white / cream | Soft paper-map feel | |

**Drag-over highlight:**

| Option | Description | Selected |
|--------|-------------|----------|
| Bright fill swap | Hovered country fill changes to bright accent (yellow/gold) | ✓ |
| Outline glow only | Colored stroke/glow around border, fill unchanged | |
| Fill + thick border | Both fill swap and bold border stroke | |

**Border stroke:**

| Option | Description | Selected |
|--------|-------------|----------|
| Thin, consistent line | 1–1.5px at 1× zoom, scales with zoom | ✓ |
| Bold lines | 2–3px strokes | |
| No borders | Countries separated by color only | |

**User's choice:** All recommended options accepted.
**Notes:** No deviation from recommendations — user accepted atlas palette, light blue ocean, gold fill swap on drag, thin consistent borders.

---

## Flag Tray Design

**Position:**

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom strip | Horizontal tray anchored to bottom, map fills above | ✓ |
| Left side panel | Vertical tray on left edge | |
| Bottom sheet overlay | Semi-transparent overlay at bottom | |

**Card count:**

| Option | Description | Selected |
|--------|-------------|----------|
| Single active flag only | One large draggable card centered in tray | ✓ |
| Current + 2–3 upcoming previews | Active flag large, next few shown smaller | |
| Scrollable strip of all remaining | Player can scroll upcoming flags | |

**Card style:**

| Option | Description | Selected |
|--------|-------------|----------|
| Rectangular card with shadow | 3:2 ratio, rounded corners, drop shadow | ✓ |
| Circular badge | Flag cropped into circle | |
| Full-bleed rectangle, no decoration | Just flag image, no card styling | |

**Country name in Phase 3:**

| Option | Description | Selected |
|--------|-------------|----------|
| Always show name (Phase 3 baseline) | Phase 4 adds showName toggle | ✓ |
| No name, flag only | Phase 4 adds name label when needed | |

**User's choice:** All recommended options accepted.
**Notes:** User agreed Phase 3 should build the complete baseline with country name visible; Phase 4 adds the mode-specific toggle without Phase 3 code changes.

---

## Feedback Animations

**Correct drop animation:**

| Option | Description | Selected |
|--------|-------------|----------|
| Flag shrinks and pins to country centroid | Flag card scale+fade to centroid, small icon pinned | ✓ |
| Country fills green briefly | Green flash on country, flag disappears | |
| Flag snaps to map edge, country glows | Flag moves to bbox center and pulses | |

**Incorrect drop animation:**

| Option | Description | Selected |
|--------|-------------|----------|
| Spring bounce back | Elastic bounce return to tray | ✓ |
| Instant reset | Immediate snap back, no animation | |
| Slide back linearly | Constant-speed glide back | |

**Audio assets:**

| Option | Description | Selected |
|--------|-------------|----------|
| Stub audio — silent placeholders | AudioService interface + just_audio init + empty files | ✓ |
| Real audio files in Phase 3 | Bundle CC-licensed sounds now | |
| No audio wiring at all | Skip entirely until Phase 4/5 | |

**Haptics:**

| Option | Description | Selected |
|--------|-------------|----------|
| Flutter built-in HapticFeedback | lightImpact() correct, mediumImpact() incorrect | ✓ |
| vibration package | Custom vibration patterns | |
| No haptics in Phase 3 | Defer to Phase 5 | |

**User's choice:** All recommended options accepted.
**Notes:** Audio stubbed to avoid blocking Phase 3 on asset sourcing; HapticFeedback.lightImpact/mediumImpact keeps it zero-dependency.

---

## Hit-Detection Strategy

**Primary hit check:**

| Option | Description | Selected |
|--------|-------------|----------|
| Path.contains() on transformed point | Pixel-accurate, uses existing dart:ui Path objects | ✓ |
| Bounding-box check only | Fast but false-positives at borders | |
| Bbox pre-filter + Path.contains() tiebreaker | Best performance, more complex | |

**Forgiving radius (GAME-02):**

| Option | Description | Selected |
|--------|-------------|----------|
| Expand bbox 30% for small countries only | Size threshold gates the expansion | ✓ |
| Expand all countries uniformly | Simpler but false-positives for medium countries | |
| Minimum absolute radius (20dp circle at centroid) | Screen-space circle, zoom-invariant | |

**Spike strategy:**

| Option | Description | Selected |
|--------|-------------|----------|
| Spike first, full system after | Standalone test widget, verified before WorldMapPainter | ✓ |
| Build and validate inline | Implement directly, no separate spike | |
| Skip spike (not a real option — blocked by CLAUDE.md) | — | |

**Multi-country tiebreaker:**

| Option | Description | Selected |
|--------|-------------|----------|
| Smallest bounding box wins | Most specific country selected at borders | ✓ |
| First path match wins | Depends on iteration order | |
| Closest centroid wins | Can fail at irregular borders | |

**User's choice:** All recommended options accepted.
**Notes:** Spike-first is non-negotiable per CLAUDE.md — user confirmed. Path.contains() provides accuracy needed for the 1×/2×/4× zoom requirement (SC4).

---

## Claude's Discretion

None — all gray areas were decided by the user.

## Deferred Ideas

None — discussion stayed within phase scope.
