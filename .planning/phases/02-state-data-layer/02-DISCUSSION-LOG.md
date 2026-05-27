# Phase 2: State & Data Layer - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 2-State & Data Layer
**Areas discussed:** GameSession model shape, Elapsed-time tracking, Riverpod API style, Repository scope, Scoring formula bug

---

## GameSession Model Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal — score + phase + elapsed + errorCount | GameSession carries: GamePhase, int score, Duration elapsed, int errorCount, GameMode mode. Matched-flags list lives in notifier internal state. | ✓ |
| Richer — also include matched/remaining flag lists | GameSession also holds: List<String> matchedIsoCodes, List<String> remainingIsoCodes, int hintsRemaining. | |

**User's choice:** Minimal shape

---

| Option | Description | Selected |
|--------|-------------|----------|
| activeIsoCode on GameSession model | GameSession includes nullable String? activeIsoCode. | ✓ |
| Inside the notifier, not on the model | Notifier tracks active flag internally; Phase 3 reads via separate provider. | |

**User's choice:** activeIsoCode on the model

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — int hintsRemaining, initialized to 2 | GAME-07 requires 2 free hints. Including now so Phase 4 reads the value rather than bolting on later. | ✓ |
| No — defer to Phase 4 | Phase 2 requirements are SCOR-01, SCOR-02, SCOR-04 only. | |

**User's choice:** Include hintsRemaining in Phase 2

---

## Elapsed-Time Tracking

| Option | Description | Selected |
|--------|-------------|----------|
| Injectable Ticker abstraction | Ticker interface + RealTicker (Timer.periodic) + FakeTicker for tests. Clean unit tests, no async timers. | ✓ |
| DateTime.now() + clock injection | Store startTime; injectable Clock interface. Requires accumulating segments for pauses. | |
| Timer.periodic directly (no abstraction) | Uses fake_async dev_dependency. Avoids custom abstractions but less obvious test setup. | |

**User's choice:** Injectable Ticker abstraction

---

| Option | Description | Selected |
|--------|-------------|----------|
| 1-second ticks | Ticker fires every 1s. Score time = elapsedSeconds ~/ 10. Enables live MM:SS HUD in Phase 3. | ✓ |
| 10-second ticks | One tick = one time point. Simpler math but HUD timer has no sub-10s resolution. | |

**User's choice:** 1-second ticks

---

| Option | Description | Selected |
|--------|-------------|----------|
| 3 seconds | Standard mobile game countdown (3-2-1-Go). Auto-transitions to playing after 3 ticks. | ✓ |
| No countdown — idle → playing directly | Fewer states to test. Phase 3 can add UI countdown independently. | |
| 5 seconds | Longer countdown for player orientation. | |

**User's choice:** 3-second countdown

---

## Riverpod API Style

| Option | Description | Selected |
|--------|-------------|----------|
| Manual AsyncNotifier — no codegen | Plain AsyncNotifier<GameSession>. No build_runner step for tests. Codegen can be adopted later. | ✓ |
| Use @riverpod codegen | Consistent with riverpod_annotation in pubspec. Requires build_runner before tests. | |

**User's choice:** Manual AsyncNotifier

---

| Option | Description | Selected |
|--------|-------------|----------|
| lib/features/game/ alongside the notifier | GameSession, GamePhase, GameMode, GameSessionNotifier all in features/game/. | ✓ |
| lib/core/state/ under core | Notifier treated as core infrastructure. | |

**User's choice:** lib/features/game/

---

## Repository Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Both HighScoreRepository + GameStateRepository | HighScoreRepository (SCOR-04) + GameStateRepository (write-on-drop for SC4). Both have abstract interfaces. | ✓ |
| HighScoreRepository only | SC4 write handled directly in notifier without a separate repo abstraction. | |

**User's choice:** Both repositories in Phase 2

---

| Option | Description | Selected |
|--------|-------------|----------|
| SharedPreferences.setMockInitialValues() in tests | Standard package helper. Repository constructors accept SharedPreferences instance. | ✓ |
| Abstract StorageInterface + mocktail mock | Fully isolated from shared_preferences package in tests but adds more layers. | |

**User's choice:** SharedPreferences.setMockInitialValues()

---

| Option | Description | Selected |
|--------|-------------|----------|
| lib/core/data/ alongside CountryDataService | Repositories as data-access layer, consistent with existing CountryDataService location. | ✓ |
| lib/features/game/ with the notifier | Repositories co-located with game logic. | |

**User's choice:** lib/core/data/

---

## Scoring Formula Bug Fix

| Option | Description | Selected |
|--------|-------------|----------|
| 18 points — the formula is right | 30s = 3 time pts, 3 errors × 5 = 15 pts, total = 18. "8 points" in ROADMAP.md SC2 is a typo. | ✓ |
| 8 points — the formula is wrong | The intended score is 8; scoring rules need clarification. | |

**User's choice:** 18 points — ROADMAP.md SC2 "8 points" is confirmed a typo.

---

## Claude's Discretion

None — all areas were explicitly decided by the user.

## Deferred Ideas

None — discussion stayed within phase scope.
