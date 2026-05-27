# Phase 2: State & Data Layer - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 delivers the `GameSessionNotifier` state machine, golf-style scoring domain logic, and local-storage repositories — fully implemented and unit-tested with zero widgets. Every subsequent phase consumes these primitives; the state machine is not modified again until Phase 4 adds mode-specific behavior.

**In scope:**
- `GameSession` model (immutable value object)
- `GamePhase` enum: idle, countdown, playing, paused, completed
- `GameMode` enum: learn, flagsMaster, geographicalMaster, grandMaster
- `GameSessionNotifier` (manual `AsyncNotifier<GameSession>`) — state machine, scoring, Ticker-driven timer
- `Ticker` abstraction: `abstract class Ticker` + `RealTicker` (Timer.periodic) + `FakeTicker` (test double)
- `HighScoreRepository` — read/write best (lowest) score per `GameMode` to SharedPreferences
- `GameStateRepository` — write current `GameSession` snapshot to SharedPreferences on every correct drop
- Unit tests for all success criteria (SC1–SC4)
- Scoring formula: +1 pt per 10 elapsed seconds, +5 pts per incorrect drop (lower = better)

**Out of scope:**
- Any widgets or rendering (Phase 3)
- Game modes differentiation logic (Phase 4)
- Session resume "Continue your game?" dialog (Phase 5)
- Hint replenishment via rewarded ad (Phase 4)
- Real AdMob wiring (Phase 6)

</domain>

<decisions>
## Implementation Decisions

### GameSession Model
- **D-01:** `GameSession` is an immutable value object (all fields `final`) with fields: `GamePhase phase`, `GameMode mode`, `int score`, `Duration elapsed`, `int errorCount`, `String? activeIsoCode`, `int hintsRemaining`. Initialized with `hintsRemaining: 2`. No matched/remaining flag lists on the model — those live in the notifier's internal state.
- **D-02:** `activeIsoCode` is nullable — `null` when game is not playing or between drops.
- **D-03:** `hintsRemaining` is included on the model in Phase 2 (not deferred), initialized to 2. Phase 4 reads it directly rather than bolting it on later.

### Elapsed-Time Tracking
- **D-04:** Time tracking uses an **injectable `Ticker` abstraction**: `abstract class Ticker { void start(void Function() onTick); void stop(); }`. Real implementation wraps `Timer.periodic(const Duration(seconds: 1), ...)`. Tests inject `FakeTicker` and call `tick()` manually to advance time without real delays.
- **D-05:** Ticker fires **1-second ticks**. The notifier increments an internal seconds counter each tick; score time component recomputes as `(elapsedSeconds ~/ 10)` pts. This gives the HUD in Phase 3 sub-10-second resolution for a live MM:SS display.
- **D-06:** **3-second countdown** before play begins. `startGame()` transitions idle → countdown; the notifier counts down 3 ticks from the Ticker, then auto-transitions to playing. The countdown value (3, 2, 1) is NOT on `GameSession` model — it's derived state or notifier-internal. Phase 3 can read elapsed ticks during the countdown phase if it needs to display it.

### Riverpod API Style
- **D-07:** `GameSessionNotifier` is a **manual `AsyncNotifier<GameSession>`** — no `@riverpod` codegen, no `build_runner` step. Provider is defined as a top-level `final gameSessionProvider = AsyncNotifierProvider<GameSessionNotifier, GameSession>(GameSessionNotifier.new)`.
- **D-08:** `GameSessionNotifier` lives in `lib/features/game/game_session_notifier.dart`. Co-located files: `game_session.dart` (model), `game_phase.dart` (enum), `game_mode.dart` (enum).
- **D-09:** `Ticker` abstraction lives in `lib/core/` (e.g., `lib/core/ticker.dart`) — it's infrastructure, not game-domain logic.

### Repository Scope
- **D-10:** Phase 2 introduces **two repositories**:
  - `HighScoreRepository` — reads/writes lowest score per `GameMode` (4 keys in SharedPreferences). Abstract interface + `SharedPreferencesHighScoreRepository` implementation.
  - `GameStateRepository` — writes the current `GameSession` as a JSON snapshot after every correct flag drop. Abstract interface + `SharedPreferencesGameStateRepository` implementation. Phase 5's resume dialog will read this.
- **D-11:** Both repositories live in `lib/core/data/` alongside `CountryDataService`.
- **D-12:** Tests use **`SharedPreferences.setMockInitialValues({})`** (the package's built-in test helper) — no custom mock interface around SharedPreferences. Repository constructors accept a `SharedPreferences` instance for injection.

### Scoring Formula (confirmed)
- **D-13:** Score = `(elapsedSeconds ~/ 10) + (errorCount * 5)`. Lower score = better (golf-style). ROADMAP.md SC2 contains a typo ("8 points") — the correct expected value for 30s + 3 errors is **18 points**: 3 time pts + 15 error pts = 18. All tests and documentation should use 18.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Requirements & Architecture
- `.planning/ROADMAP.md` §Phase 2 — Phase goal, requirements (SCOR-01, SCOR-02, SCOR-04), success criteria (note: SC2 "8 points" is a typo — use 18)
- `.planning/REQUIREMENTS.md` §Scoring & Progress — Full text for SCOR-01, SCOR-02, SCOR-04 (also SESS-03 which SC4 implements the write side of)
- `CLAUDE.md` §Critical Architecture Decisions — D-04 (ad walled garden: GameSessionNotifier must have zero imports from features/ads/), D-05 (no Firebase)

### Phase 1 Foundation (what Phase 2 builds on)
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-01 (feature-folder layout), D-04 (CountryData model), D-11/D-12 (ad stub walled garden and architecture enforcement test)
- `lib/core/models/country_data.dart` — The `CountryData` model Phase 2's notifier references for flag ordering
- `lib/features/ads/ad_service.dart` + `lib/features/ads/ad_load_state.dart` — Walled-garden stub (GameSessionNotifier must NOT import these)
- `pubspec.yaml` — `flutter_riverpod: ^3.3.1`, `shared_preferences: ^2.5.5`, `mocktail: ^1.0.5` — all available, no new packages expected

### Architecture Enforcement
- `test/architecture/ads_isolation_test.dart` — Existing test that asserts zero imports of `features/ads/` from game/map/core code. Phase 2 must not break this.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/core/models/country_data.dart` — `CountryData` (isoCode, paths, boundingBox, centroid) — Phase 2's notifier uses this to build the ordered flag pool for a session
- `lib/features/ads/ad_load_state.dart` — `sealed class AdLoadState` pattern (Phase 2 can follow the same sealed-class pattern for `GamePhase`)

### Established Patterns
- Abstract interface + stub implementation: `AdService` / `StubAdService` pattern is already established — `HighScoreRepository` and `GameStateRepository` should follow the same abstract-interface + concrete-implementation pattern
- Architecture enforcement test already guards `features/game/` from importing `features/ads/` — GameSessionNotifier must stay clean

### Integration Points
- `GameSessionNotifier` provider → consumed by Phase 3's `WorldMapPainter` and flag tray widgets
- `HighScoreRepository` → read by Phase 4's completion screen for star rating
- `GameStateRepository` → read by Phase 5's "Continue your game?" dialog
- `GameMode` enum → must be consistent with Phase 4's mode-selection UI (4 modes: learn, flagsMaster, geographicalMaster, grandMaster)

</code_context>

<specifics>
## Specific Ideas

- **Ticker location:** `lib/core/ticker.dart` — abstract class + two implementations in the same file (RealTicker and FakeTicker). FakeTicker exposes a `void tick()` method that tests call directly.
- **GameSession serialization:** `GameStateRepository` serializes `GameSession` to a flat JSON map (no nested objects needed for the minimal model shape). Keys: `phase`, `mode`, `score`, `elapsedSeconds`, `errorCount`, `activeIsoCode`, `hintsRemaining`.
- **SharedPreferences keys:** Use a consistent naming convention, e.g., `high_score_learn`, `high_score_flags_master`, `high_score_geographical_master`, `high_score_grand_master` for HighScoreRepository; `game_session_snapshot` for GameStateRepository.
- **Scoring bug fix:** ROADMAP.md SC2 states "exactly 8 points" — this is a confirmed typo. The correct assertion is `score == 18`. Downstream planner should note this and write the test against 18.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-State & Data Layer*
*Context gathered: 2026-05-27*
