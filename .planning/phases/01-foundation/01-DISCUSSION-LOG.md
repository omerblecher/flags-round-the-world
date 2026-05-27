# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 1-Foundation
**Areas discussed:** Flutter scaffold depth, Multi-polygon countries, 195 countries definition, Ad stub timing

---

## Flutter Scaffold Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Feature-folder skeleton | lib/features/game/, lib/features/map/, lib/features/ads/, lib/core/ established now | ✓ |
| Flat minimal for now | lib/models/, lib/data/, lib/l10n/ — only what Phase 1 needs | |
| Clean architecture layers | lib/domain/, lib/data/, lib/presentation/ as top-level layers | |

**User's choice:** Feature-folder skeleton

| Option | Description | Selected |
|--------|-------------|----------|
| Directories only + .gitkeep | Empty directories with .gitkeep files | ✓ |
| Stub files with TODO comments | Each feature folder gets a stub Dart file | |
| Only what Phase 1 needs | Don't create future-phase folders yet | |

**User's choice:** Directories only + .gitkeep

| Option | Description | Selected |
|--------|-------------|----------|
| Models + data services + l10n | lib/core/models/, lib/core/data/, lib/core/l10n/ | ✓ |
| Just models | lib/core/models/ only | |
| You decide | Let the planner determine core subdivisions | |

**User's choice:** Models + data services + l10n

| Option | Description | Selected |
|--------|-------------|----------|
| Full assets skeleton now | assets/flags/, assets/map/, assets/data/, assets/audio/ all established | ✓ |
| Only what Phase 1 needs | assets/map/ and assets/data/ only | |
| You decide | Let the planner decide | |

**User's choice:** Full assets skeleton now

---

## Multi-Polygon Countries

| Option | Description | Selected |
|--------|-------------|----------|
| Single entry, array of paths | CountryData has List<String> pathStrings; all polygons under one ISO code | ✓ |
| Mainland polygon only | Keep only the largest polygon; islands disappear | |
| You decide | Let the planner choose | |

**User's choice:** Single entry, array of paths
**Notes:** Dropping on Alaska still counts as a correct USA match.

| Option | Description | Selected |
|--------|-------------|----------|
| Part of parent country | Territories rendered under parent ISO code; not separate flag targets | ✓ |
| Separate entities with own flags | Some territories have distinct flags; would expand scope beyond 196 | |

**User's choice:** Part of parent country

| Option | Description | Selected |
|--------|-------------|----------|
| Include all, force minimum touch target | Every country present; Phase 3 applies minimum hit-detection radius | ✓ |
| Include all at natural size | Render at actual geographic size; tiny nations may be frustrating | |
| You decide | Leave behavior to Phase 3 | |

**User's choice:** Include all, but force minimum touch target size

| Option | Description | Selected |
|--------|-------------|----------|
| Single centroid per country | One centroid per ISO code for label placement | ✓ |
| Centroid per polygon | Each polygon has its own centroid | |
| You decide | Let the planner decide | |

**User's choice:** Single centroid per country

---

## 195 Countries Definition

| Option | Description | Selected |
|--------|-------------|----------|
| UN-193 + Vatican + Palestine | Clean, internationally defensible, standard 195 claim | |
| UN-193 + Vatican + Taiwan | Taiwan chosen over Palestine; Republic of China flag | ✓ |
| You decide | Leave to researcher | |

**User's choice:** UN-193 + Vatican + Taiwan (ISO: TW)

| Option | Description | Selected |
|--------|-------------|----------|
| Exclude both Kosovo and Western Sahara | Neither is a flag target; both excluded | |
| Include Kosovo, exclude Western Sahara | Kosovo has broad European recognition and ISO code XK | ✓ |
| You decide | Leave edge cases to researcher | |

**User's choice:** Include Kosovo (XK), exclude Western Sahara and Palestine

| Option | Description | Selected |
|--------|-------------|----------|
| Update to 196 countries | UN-193 + Vatican + Taiwan + Kosovo = 196; update all docs | ✓ |
| Keep 195, drop Kosovo | UN-193 + Vatican + Taiwan = 195 | |
| Keep 195, drop one UN member | Unusual; would need to specify which | |

**User's choice:** Update to 196 countries
**Notes:** All "195" references in REQUIREMENTS.md, ROADMAP.md, PROJECT.md, and CLAUDE.md must be updated to "196."

---

## Ad Stub Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 1 | Create the stub alongside the scaffold; walled garden enforced from commit 1 | ✓ |
| Phase 2 | Natural when GameSessionNotifier is built | |
| Whenever first needed | Rely on linter/architecture test instead | |

**User's choice:** Phase 1

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add architecture test in Phase 1 | Dart test asserts no game/session/map imports from features/ads/ | ✓ |
| No, rely on code review | Enforce manually | |
| You decide | Leave to planner | |

**User's choice:** Yes, add architecture test in Phase 1

| Option | Description | Selected |
|--------|-------------|----------|
| Just AdLoadState enum + AdService interface | Minimal stub; sealed class + interface always returning failed | ✓ |
| Full ad format stubs | All 4 formats as no-ops | |
| You decide | Let the planner determine | |

**User's choice:** AdLoadState enum + AdService interface only

---

## Claude's Discretion

None — user made explicit choices in all areas.

## Deferred Ideas

None — discussion stayed within Phase 1 scope.
