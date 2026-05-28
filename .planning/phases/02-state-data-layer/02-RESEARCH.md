# Phase 2: State & Data Layer - Research

**Researched:** 2026-05-28
**Domain:** Flutter state management (Riverpod 3.x AsyncNotifier), Dart immutable models, SharedPreferences testing
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `GameSession` is an immutable value object (all fields `final`) with fields: `GamePhase phase`, `GameMode mode`, `int score`, `Duration elapsed`, `int errorCount`, `String? activeIsoCode`, `int hintsRemaining`. Initialized with `hintsRemaining: 2`. No matched/remaining flag lists on the model — those live in the notifier's internal state.
- **D-02:** `activeIsoCode` is nullable — `null` when game is not playing or between drops.
- **D-03:** `hintsRemaining` is included on the model in Phase 2 (not deferred), initialized to 2. Phase 4 reads it directly rather than bolting it on later.
- **D-04:** Time tracking uses an injectable `Ticker` abstraction: `abstract class Ticker { void start(void Function() onTick); void stop(); }`. Real implementation wraps `Timer.periodic(const Duration(seconds: 1), ...)`. Tests inject `FakeTicker` and call `tick()` manually.
- **D-05:** Ticker fires 1-second ticks. The notifier increments an internal seconds counter each tick; score time component recomputes as `(elapsedSeconds ~/ 10)` pts.
- **D-06:** 3-second countdown before play begins. `startGame()` transitions idle → countdown; the notifier counts down 3 ticks, then auto-transitions to playing. The countdown value is NOT on `GameSession` model — it's notifier-internal.
- **D-07:** `GameSessionNotifier` is a manual `AsyncNotifier<GameSession>` — no `@riverpod` codegen, no `build_runner` step. Provider defined as `final gameSessionProvider = AsyncNotifierProvider<GameSessionNotifier, GameSession>(GameSessionNotifier.new)`.
- **D-08:** `GameSessionNotifier` lives in `lib/features/game/game_session_notifier.dart`. Co-located: `game_session.dart` (model), `game_phase.dart` (enum), `game_mode.dart` (enum).
- **D-09:** `Ticker` abstraction lives in `lib/core/ticker.dart` — infrastructure, not game-domain.
- **D-10:** Phase 2 introduces two repositories: `HighScoreRepository` and `GameStateRepository` — both abstract interfaces + SharedPreferences implementations in `lib/core/data/`.
- **D-11:** Both repositories live in `lib/core/data/` alongside `CountryDataService`.
- **D-12:** Tests use `SharedPreferences.setMockInitialValues({})` (the package's built-in test helper). Repository constructors accept a `SharedPreferences` instance for injection.
- **D-13:** Score = `(elapsedSeconds ~/ 10) + (errorCount * 5)`. Lower = better (golf-style). ROADMAP SC2 "8 points" is a typo — correct value for 30s + 3 errors = **18 points**.

### Claude's Discretion

None — all decisions were locked during discussion.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCOR-01 | Score increments by 1 point for every 10 seconds of elapsed game time | D-05/D-13: `elapsedSeconds ~/ 10` formula; Ticker drives 1-second increments; tested in SC2 |
| SCOR-02 | Score increments by 5 points for every incorrect flag placement | D-13: `errorCount * 5` formula; `recordError()` method on notifier increments errorCount |
| SCOR-04 | The lowest (best) score for each of the 4 levels is stored locally on the device | D-10: `HighScoreRepository` writes/reads per-GameMode best score to SharedPreferences |
</phase_requirements>

---

## Summary

Phase 2 delivers pure Dart (zero widgets) state machine primitives that every subsequent phase consumes. The `GameSessionNotifier` extends `AsyncNotifier<GameSession>` manually (no codegen), manages an injectable `Ticker` for deterministic time testing, and coordinates two SharedPreferences-backed repositories. The Riverpod 3.3.1 already in `pubspec.yaml` introduces `ProviderContainer.test()` as the canonical test container — no custom `createContainer` helper needed.

The critical testing insight for this phase: `AsyncNotifier.build()` can return a synchronous `GameSession` value (not a Future), which means the provider initializes as `AsyncData<GameSession>` immediately. State transitions are synchronous assignments (`state = AsyncData(newSession)`) that tests can observe without awaiting anything. The `FakeTicker.tick()` pattern enables precise control of countdown and elapsed-time advancement without any real-time delay.

**Primary recommendation:** Use `ProviderContainer.test(overrides: [gameSessionProvider.overrideWith(() => GameSessionNotifier(ticker: FakeTicker()))])` in every notifier test, call `FakeTicker.tick()` to advance time, and assert `container.read(gameSessionProvider)` equality at each state boundary.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Game session state machine | Domain (Notifier) | — | Pure Dart logic; no widget dependency; Phase 3 widgets read it |
| Elapsed-time tracking | Domain (Notifier internal) | Ticker abstraction | Ticker is infrastructure; notifier owns the counter |
| Scoring formula | Domain (Notifier) | — | SCOR-01/SCOR-02 math is pure Dart; lives in notifier methods |
| High score persistence | Data layer (Repository) | SharedPreferences | Read by Phase 4 completion screen; separate from session logic |
| Session snapshot persistence | Data layer (Repository) | SharedPreferences | Written on every correct drop; read by Phase 5 resume dialog |
| Ad isolation enforcement | Architecture test | CI | Existing `ads_isolation_test.dart` guards this layer |

---

## Standard Stack

### Core (all already in pubspec.yaml — no new packages)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | ^3.3.1 | AsyncNotifier, ProviderContainer.test() | Locked in Phase 1; 3.x brings unified Ref and test utilities |
| `shared_preferences` | ^2.5.5 | HighScoreRepository + GameStateRepository persistence | Locked in Phase 1; supports setMockInitialValues for test isolation |
| `mocktail` | ^1.0.5 | Mock collaborators in tests | Locked in Phase 1; replaces mockito; no code generation needed |
| `flutter_test` | SDK | ProviderContainer.test(), expect, group, setUp | Standard Flutter test SDK |

[VERIFIED: pubspec.yaml] — all four packages confirmed present in `pubspec.yaml` and resolved versions in `flutter pub deps` output.

### No New Packages

No packages beyond those already installed are required for Phase 2. The `Ticker` abstraction is hand-rolled (2 classes, ~20 lines). Serialization is a flat `Map<String, dynamic>` — no additional JSON package needed. `freezed` / `equatable` are explicitly NOT used per D-01 (hand-rolled `copyWith` + manual `==`).

**Installation:** No `flutter pub add` commands needed.

---

## Package Legitimacy Audit

No new packages are being installed in Phase 2. All packages are carried forward from Phase 1 which was already verified.

| Package | Registry | Age | Downloads | Source Repo | Disposition |
|---------|----------|-----|-----------|-------------|-------------|
| `flutter_riverpod` 3.3.1 | pub.dev | 5+ yrs | Very high | github.com/rrousselGit/riverpod | Approved (Phase 1) |
| `shared_preferences` 2.5.5 | pub.dev | 7+ yrs | Very high | github.com/flutter/packages | Approved (Phase 1) |
| `mocktail` 1.0.5 | pub.dev | 4+ yrs | High | github.com/felangel/mocktail | Approved (Phase 1) |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
Test / ProviderContainer
        │
        ▼
gameSessionProvider (AsyncNotifierProvider)
        │
        ▼
GameSessionNotifier (AsyncNotifier<GameSession>)
   ├─── Ticker (injected) ──► FakeTicker.tick() [tests]
   │                          RealTicker (Timer.periodic) [prod]
   ├─── internal: _elapsedSeconds, _countdownTick, _remainingIsoCodes
   │
   ├── startGame(mode) ──► idle → countdown (3 ticks) → playing
   ├── pauseGame()     ──► playing → paused (Ticker.stop())
   ├── resumeGame()    ──► paused → playing (Ticker.start())
   ├── recordDrop(isoCode, isCorrect)
   │       correct: update state, write GameStateRepository
   │       incorrect: increment errorCount, update state
   └── completeGame()  ──► playing → completed, write HighScoreRepository
            │
            ▼
      HighScoreRepository (abstract)
      SharedPreferencesHighScoreRepository
            │
            ▼
      SharedPreferences (injected in tests via setMockInitialValues)

      GameStateRepository (abstract)
      SharedPreferencesGameStateRepository
            │
            ▼
      SharedPreferences (same instance, same injection pattern)
```

### Recommended Project Structure

```
lib/
├── core/
│   ├── data/
│   │   ├── country_data_service.dart      # existing
│   │   ├── high_score_repository.dart     # Phase 2: abstract + impl
│   │   └── game_state_repository.dart     # Phase 2: abstract + impl
│   ├── models/
│   │   └── country_data.dart              # existing
│   └── ticker.dart                        # Phase 2: abstract + RealTicker + FakeTicker
│
└── features/
    ├── ads/                               # existing walled garden — DO NOT IMPORT
    └── game/
        ├── game_mode.dart                 # Phase 2: enum
        ├── game_phase.dart                # Phase 2: enum
        ├── game_session.dart              # Phase 2: immutable model + copyWith
        └── game_session_notifier.dart     # Phase 2: AsyncNotifier<GameSession>

test/
├── architecture/
│   └── ads_isolation_test.dart            # existing — must stay green
└── unit/
    ├── country_data_service_test.dart     # existing
    ├── country_data_test.dart             # existing
    ├── game_session_notifier_test.dart    # Phase 2: SC1, SC2, SC4
    ├── high_score_repository_test.dart    # Phase 2: SC3
    └── game_state_repository_test.dart   # Phase 2: SC4 (write side)
```

### Pattern 1: Manual AsyncNotifier Declaration (no codegen)

**What:** AsyncNotifier with a synchronous build() that returns the initial idle state.
**When to use:** Any Notifier where initial state is known synchronously, avoiding an unnecessary AsyncLoading flash.

```dart
// Source: riverpod.dev/docs/migration/from_state_notifier [CITED]
// + official Riverpod 3.0 changelog [CITED: riverpod.dev/docs/whats_new]

class GameSessionNotifier extends AsyncNotifier<GameSession> {
  GameSessionNotifier({required Ticker ticker}) : _ticker = ticker;

  final Ticker _ticker;
  int _elapsedSeconds = 0;
  int _countdownTick = 0;
  List<String> _remainingIsoCodes = [];

  @override
  GameSession build() {
    ref.onDispose(_ticker.stop);
    return const GameSession(
      phase: GamePhase.idle,
      mode: GameMode.learn,
      score: 0,
      elapsed: Duration.zero,
      errorCount: 0,
      activeIsoCode: null,
      hintsRemaining: 2,
    );
  }
}

// Provider at top level — one line, no annotation
final gameSessionProvider =
    AsyncNotifierProvider<GameSessionNotifier, GameSession>(
  () => GameSessionNotifier(ticker: RealTicker()),
);
```

[CITED: riverpod.dev/docs/migration/from_state_notifier] — build() return type is `FutureOr<T>`; returning a plain `T` (not a Future) means the provider initializes as `AsyncData` immediately with no loading flash.

### Pattern 2: Synchronous State Updates in AsyncNotifier

**What:** Directly assign `state = AsyncData(newValue)` for in-method state transitions. No `await`, no `update()` needed when the new value is fully synchronous.
**When to use:** State machine transitions (phase changes, score increments) that never involve I/O.

```dart
// Source: github.com/rrousselGit/riverpod discussions #2423 [CITED]
// Confirmed pattern in Riverpod 3.x [CITED: riverpod.dev/docs/whats_new]

void _onTick() {
  if (state case AsyncData(:final value)) {
    if (value.phase == GamePhase.countdown) {
      _countdownTick++;
      if (_countdownTick >= 3) {
        state = AsyncData(value.copyWith(phase: GamePhase.playing));
      }
      return;
    }
    if (value.phase == GamePhase.playing) {
      _elapsedSeconds++;
      final newScore = (_elapsedSeconds ~/ 10) + (value.errorCount * 5);
      state = AsyncData(value.copyWith(
        score: newScore,
        elapsed: Duration(seconds: _elapsedSeconds),
      ));
    }
  }
}
```

Key: `if (state case AsyncData(:final value))` uses Dart 3 pattern matching — clean and null-safe. [ASSUMED — Dart 3.12 supports this pattern; verified Flutter 3.44 / Dart 3.12 is in use, but explicit API doc not found for this exact syntax combination.]

### Pattern 3: Ticker Abstraction

**What:** Abstract `Ticker` with `RealTicker` (Timer.periodic) and `FakeTicker` (synchronous `tick()` for tests).
**When to use:** Anywhere you need time-based callbacks that must be tested without real delays.

```dart
// Source: [ASSUMED] — standard Flutter/Dart DI pattern for timer testability
// Consistent with patterns in bloclibrary.dev/tutorials/flutter-timer/ [CITED]

// lib/core/ticker.dart

abstract class Ticker {
  void start(void Function() onTick);
  void stop();
}

class RealTicker implements Ticker {
  Timer? _timer;

  @override
  void start(void Function() onTick) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

class FakeTicker implements Ticker {
  void Function()? _onTick;

  @override
  void start(void Function() onTick) {
    _onTick = onTick;
  }

  @override
  void stop() {
    _onTick = null;
  }

  /// Call from tests to simulate one elapsed second.
  void tick() => _onTick?.call();
}
```

### Pattern 4: Immutable Value Object with copyWith

**What:** Hand-rolled `copyWith` using the nullable-override trick. No code generation.
**When to use:** Phase 2 `GameSession` model (and any model with 4+ fields where each field may be individually updated).

```dart
// Source: dart.academy/immutable-data-patterns-in-dart-and-flutter/ [CITED]

class GameSession {
  const GameSession({
    required this.phase,
    required this.mode,
    required this.score,
    required this.elapsed,
    required this.errorCount,
    this.activeIsoCode,
    required this.hintsRemaining,
  });

  final GamePhase phase;
  final GameMode mode;
  final int score;
  final Duration elapsed;
  final int errorCount;
  final String? activeIsoCode;
  final int hintsRemaining;

  GameSession copyWith({
    GamePhase? phase,
    GameMode? mode,
    int? score,
    Duration? elapsed,
    int? errorCount,
    // Use Object? sentinel to allow null assignment for activeIsoCode
    Object? activeIsoCode = _sentinel,
    int? hintsRemaining,
  }) {
    return GameSession(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      score: score ?? this.score,
      elapsed: elapsed ?? this.elapsed,
      errorCount: errorCount ?? this.errorCount,
      activeIsoCode: activeIsoCode == _sentinel
          ? this.activeIsoCode
          : activeIsoCode as String?,
      hintsRemaining: hintsRemaining ?? this.hintsRemaining,
    );
  }

  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSession &&
          phase == other.phase &&
          mode == other.mode &&
          score == other.score &&
          elapsed == other.elapsed &&
          errorCount == other.errorCount &&
          activeIsoCode == other.activeIsoCode &&
          hintsRemaining == other.hintsRemaining;

  @override
  int get hashCode => Object.hash(
        phase, mode, score, elapsed, errorCount, activeIsoCode, hintsRemaining);
}
```

The sentinel pattern for nullable fields (`activeIsoCode`) is the standard Dart solution when `null` is a valid copyWith value distinct from "keep the current value". [CITED: dart.academy/immutable-data-patterns-in-dart-and-flutter/]

### Pattern 5: Repository — Abstract Interface + SharedPreferences Impl

**What:** Abstract interface so tests can inject `SharedPreferences.setMockInitialValues({})` instance directly, without needing a mock.
**When to use:** Any repository backed by SharedPreferences in this project (established by AdService / StubAdService pattern in Phase 1).

```dart
// Source: lib/features/ads/ad_service.dart (established Phase 1 pattern) [VERIFIED: codebase]

// lib/core/data/high_score_repository.dart

abstract interface class HighScoreRepository {
  Future<int?> getBestScore(GameMode mode);
  Future<void> saveBestScore(GameMode mode, int score);
}

class SharedPreferencesHighScoreRepository implements HighScoreRepository {
  SharedPreferencesHighScoreRepository(this._prefs);
  final SharedPreferences _prefs;

  static String _key(GameMode mode) => switch (mode) {
    GameMode.learn              => 'high_score_learn',
    GameMode.flagsMaster        => 'high_score_flags_master',
    GameMode.geographicalMaster => 'high_score_geographical_master',
    GameMode.grandMaster        => 'high_score_grand_master',
  };

  @override
  Future<int?> getBestScore(GameMode mode) async =>
      _prefs.getInt(_key(mode));

  @override
  Future<void> saveBestScore(GameMode mode, int score) async {
    final current = _prefs.getInt(_key(mode));
    if (current == null || score < current) {
      await _prefs.setInt(_key(mode), score);
    }
  }
}
```

### Pattern 6: ProviderContainer.test() for AsyncNotifier Tests

**What:** Riverpod 3.x canonical test setup — `ProviderContainer.test()` auto-disposes after test ends. Override the provider to inject `FakeTicker`.
**When to use:** Every unit test for `GameSessionNotifier`.

```dart
// Source: riverpod.dev/docs/whats_new (Riverpod 3.0 changelog) [CITED]
// Source: riverpod.dev/docs/how_to/testing [CITED]

test('idle → countdown → playing transition', () async {
  final fakeTicker = FakeTicker();

  final container = ProviderContainer.test(
    overrides: [
      gameSessionProvider.overrideWith(
        () => GameSessionNotifier(ticker: fakeTicker),
      ),
    ],
  );

  // Initial state is synchronous AsyncData
  expect(
    container.read(gameSessionProvider).value?.phase,
    GamePhase.idle,
  );

  // Start game — transitions to countdown
  await container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
  expect(
    container.read(gameSessionProvider).value?.phase,
    GamePhase.countdown,
  );

  // Tick 3 times — should auto-transition to playing
  fakeTicker.tick();
  fakeTicker.tick();
  fakeTicker.tick();
  expect(
    container.read(gameSessionProvider).value?.phase,
    GamePhase.playing,
  );
});
```

### Pattern 7: SharedPreferences Mock Testing

**What:** Call `SharedPreferences.setMockInitialValues({})` in `setUp` (not `setUpAll`) to get a fresh in-memory store before each test.
**When to use:** All repository unit tests.

```dart
// Source: blog.victoreronmosele.com/mocking-shared-preferences-flutter [CITED]
// Note: call in setUp (not setUpAll) to reset between tests

group('SharedPreferencesHighScoreRepository', () {
  late SharedPreferences prefs;
  late HighScoreRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = SharedPreferencesHighScoreRepository(prefs);
  });

  test('returns null when no score stored', () async {
    expect(await repo.getBestScore(GameMode.learn), isNull);
  });

  test('saves and reads back best score', () async {
    await repo.saveBestScore(GameMode.learn, 18);
    expect(await repo.getBestScore(GameMode.learn), 18);
  });

  test('only updates when new score is lower (golf-style)', () async {
    await repo.saveBestScore(GameMode.learn, 18);
    await repo.saveBestScore(GameMode.learn, 25); // worse — should not overwrite
    expect(await repo.getBestScore(GameMode.learn), 18);
    await repo.saveBestScore(GameMode.learn, 12); // better — should overwrite
    expect(await repo.getBestScore(GameMode.learn), 12);
  });
});
```

**Critical note:** `setMockInitialValues` can only be reliably called once per test process using `setUpAll`. Calling it in `setUp` (once per test) works in practice because the in-memory platform channel mock resets correctly between tests, but this is an implementation detail. The D-12 decision to inject a `SharedPreferences` instance into repositories makes this safe: each test calls `SharedPreferences.getInstance()` after `setMockInitialValues`, and gets an in-memory instance reflecting only the values set for that test. [CITED: github.com/flutter/flutter/issues/28837 — known limitation documented]

### Anti-Patterns to Avoid

- **Storing Ticker in a class-level field initialized in the constructor before `build()`:** In Riverpod 3.x, notifiers may be recreated; always register `ref.onDispose(_ticker.stop)` inside `build()` to ensure the timer is cancelled on disposal.
- **Importing `features/ads/` from `game_session_notifier.dart`:** The `ads_isolation_test.dart` will catch this immediately. The ad layer is completely out of scope for Phase 2.
- **Using `@riverpod` annotation:** D-07 explicitly bans codegen. Do not add `part` directives or `@riverpod` to any Phase 2 file.
- **Putting flag pool logic in `GameSession` model:** The model only holds current-session scalars. The notifier holds `_remainingIsoCodes` as private mutable state.
- **Deferring the GameStateRepository write:** SC4 asserts that writes happen on every correct drop, not at game-end. Write inside `recordDrop()` when `isCorrect == true`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SharedPreferences mock isolation | Custom `FakePrefsStorage` wrapper | `SharedPreferences.setMockInitialValues({})` | Built into the package; zero lines of mock code needed |
| Provider test cleanup | Manual `container.dispose()` in `tearDown` | `ProviderContainer.test()` | Auto-disposes after test in Riverpod 3.x; eliminates boilerplate |
| Time advancement in tests | `Future.delayed` or `sleep` in tests | `FakeTicker.tick()` | Deterministic, instant, no flaky real-time waits |
| Null-safety for nullable copyWith fields | Complicated overloaded constructors | `Object? _sentinel` pattern | Standard Dart idiom; 4 lines; avoids `freezed` code generation |

**Key insight:** The `SharedPreferences.setMockInitialValues` + injected-instance pattern means zero mock objects are needed for repository tests. Mocktail is only needed if a future phase tests collaborators that cannot be injected by value.

---

## Common Pitfalls

### Pitfall 1: AsyncLoading Includes Previous Data in Riverpod 3.x

**What goes wrong:** Tests assert `isA<AsyncLoading>()` on a state but the value comparison fails because `AsyncLoading` in Riverpod 3.x carries the previous `AsyncData` value via `AsyncLoading.copyWithPrevious`. Exact equality checks against `AsyncLoading()` fail.
**Why it happens:** Riverpod design decision to preserve previous data during loading so UIs can show stale-while-revalidate.
**How to avoid:** For Phase 2 (synchronous state transitions), never emit `AsyncLoading` — only emit `AsyncData(newValue)` directly. Loading state is only relevant if `build()` returns a `Future`.
**Warning signs:** Test assertions like `expect(state, const AsyncLoading())` fail despite the notifier entering a "loading" branch.

### Pitfall 2: GameSessionNotifier.build() Must Return Synchronous GameSession

**What goes wrong:** If `build()` returns `Future<GameSession>`, the provider initializes as `AsyncLoading` for one microtask, then `AsyncData`. Tests that immediately read `container.read(gameSessionProvider).value` get `null` (the value is not yet populated).
**Why it happens:** `AsyncNotifier.build()` returns `FutureOr<T>`. Returning a bare `T` skips the loading state entirely.
**How to avoid:** Return the initial `GameSession` directly without `async`: `GameSession build() => const GameSession(...)`.
**Warning signs:** `container.read(gameSessionProvider).value` is `null` on the first read in tests.

### Pitfall 3: SharedPreferences Singleton Leaking Between Tests

**What goes wrong:** A test that writes a value leaves it in the in-memory SharedPreferences singleton. The next test reads stale data.
**Why it happens:** SharedPreferences uses a static singleton even in tests.
**How to avoid:** Call `SharedPreferences.setMockInitialValues({})` at the start of each test (in `setUp`, not just `setUpAll`). This resets the in-memory store.
**Warning signs:** Tests pass individually but fail when run in sequence with `flutter test`.

### Pitfall 4: Ticker Not Stopped on Notifier Disposal

**What goes wrong:** `RealTicker` continues firing after `ProviderContainer.dispose()` in tests, causing "setState called after dispose" errors or timer leaks.
**Why it happens:** `Timer.periodic` is not automatically cancelled by Dart's GC.
**How to avoid:** Register `ref.onDispose(_ticker.stop)` inside `build()`. Do NOT stop in a Dart destructor or `dispose()` override (AsyncNotifier has no `dispose()`).
**Warning signs:** Test output shows timer callbacks firing after test completion; subsequent tests see unexpected state changes.

### Pitfall 5: Architecture Test Violation

**What goes wrong:** Any import of `features/ads/` in `lib/features/game/`, `lib/features/map/`, or `lib/core/` fails `test/architecture/ads_isolation_test.dart`.
**Why it happens:** Accidental IDE auto-import or copy-paste.
**How to avoid:** Never import anything from `features/ads/` in Phase 2 files. The walled-garden ad stub returns `AdFailed` silently — Phase 2 has zero interaction with it.
**Warning signs:** `ads_isolation_test.dart` fails with a "Found illegal imports" message.

### Pitfall 6: Scoring Formula Off-By-One (the ROADMAP Typo)

**What goes wrong:** Test written against ROADMAP SC2's stated "8 points" assertion fails.
**Why it happens:** ROADMAP.md contains a confirmed typo — the self-correcting footnote in the same sentence gives the correct answer.
**How to avoid:** Always use **18 points** for 30s + 3 errors: `(30 ~/ 10) + (3 * 5) = 3 + 15 = 18`. Document the corrected value in the test's comment.
**Warning signs:** SC2 test passes with score == 8 assertion — this means the scoring formula is WRONG.

---

## Code Examples

### Scoring Formula Verification Test

```dart
// Source: D-13 from 02-CONTEXT.md [VERIFIED: codebase context]
// 30 seconds elapsed, 3 errors: (30 ~/ 10) + (3 * 5) = 3 + 15 = 18 points

test('SC2: 30s + 3 errors = 18 points (golf-style)', () async {
  final fakeTicker = FakeTicker();
  final container = ProviderContainer.test(
    overrides: [
      gameSessionProvider.overrideWith(
        () => GameSessionNotifier(ticker: fakeTicker),
      ),
    ],
  );

  await container.read(gameSessionProvider.notifier).startGame(GameMode.learn);

  // Advance through countdown (3 ticks)
  fakeTicker.tick();
  fakeTicker.tick();
  fakeTicker.tick();

  // Advance 30 seconds of play
  for (var i = 0; i < 30; i++) {
    fakeTicker.tick();
  }

  // Record 3 incorrect drops
  await container.read(gameSessionProvider.notifier)
      .recordDrop('xx', isCorrect: false);
  await container.read(gameSessionProvider.notifier)
      .recordDrop('xx', isCorrect: false);
  await container.read(gameSessionProvider.notifier)
      .recordDrop('xx', isCorrect: false);

  final score = container.read(gameSessionProvider).value!.score;
  expect(score, 18, reason: 'SC2: 30s ÷ 10 = 3 pts + 3 errors × 5 = 15 pts = 18 total');
});
```

### Full State Transition Test (SC1)

```dart
// Source: D-06 from 02-CONTEXT.md [VERIFIED: codebase context]

test('SC1: idle → countdown → playing → paused → completed', () async {
  final fakeTicker = FakeTicker();
  final container = ProviderContainer.test(
    overrides: [
      gameSessionProvider.overrideWith(
        () => GameSessionNotifier(ticker: fakeTicker),
      ),
    ],
  );

  // idle
  expect(container.read(gameSessionProvider).value?.phase, GamePhase.idle);

  // → countdown
  await container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
  expect(container.read(gameSessionProvider).value?.phase, GamePhase.countdown);

  // → playing (after 3 countdown ticks)
  fakeTicker.tick();
  fakeTicker.tick();
  fakeTicker.tick();
  expect(container.read(gameSessionProvider).value?.phase, GamePhase.playing);

  // → paused
  container.read(gameSessionProvider.notifier).pauseGame();
  expect(container.read(gameSessionProvider).value?.phase, GamePhase.paused);

  // → playing again
  container.read(gameSessionProvider.notifier).resumeGame();
  expect(container.read(gameSessionProvider).value?.phase, GamePhase.playing);

  // → completed
  await container.read(gameSessionProvider.notifier).completeGame();
  expect(container.read(gameSessionProvider).value?.phase, GamePhase.completed);
});
```

### SC4: Verify Write on Every Correct Drop

```dart
// Source: D-10, D-12 from 02-CONTEXT.md [VERIFIED: codebase context]
// GameStateRepository is injected; use a spy/mock to count writes

class MockGameStateRepository extends Mock implements GameStateRepository {}

test('SC4: GameStateRepository.save called once per correct drop', () async {
  final fakeTicker = FakeTicker();
  final mockRepo = MockGameStateRepository();
  when(() => mockRepo.saveSession(any())).thenAnswer((_) async {});

  final container = ProviderContainer.test(
    overrides: [
      gameSessionProvider.overrideWith(
        () => GameSessionNotifier(
          ticker: fakeTicker,
          gameStateRepository: mockRepo,
        ),
      ),
    ],
  );

  // Advance to playing state
  await container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
  fakeTicker.tick(); fakeTicker.tick(); fakeTicker.tick();

  // 2 correct drops
  await container.read(gameSessionProvider.notifier)
      .recordDrop('de', isCorrect: true);
  await container.read(gameSessionProvider.notifier)
      .recordDrop('fr', isCorrect: true);

  verify(() => mockRepo.saveSession(any())).called(2);
});
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `StateNotifier` + custom `createContainer` helper | `AsyncNotifier` + `ProviderContainer.test()` | Riverpod 3.0 (2025) | Simpler test setup; no manual tearDown |
| `AutoDisposeNotifier` separate class | Unified `Notifier` (autoDispose as lint) | Riverpod 3.0 | No `AutoDisposeAsyncNotifier` needed |
| `FutureProviderRef`, `NotifierProviderRef` | Single unified `Ref` | Riverpod 3.0 | `ref` type in notifier methods is just `Ref` |
| `mockito` with code generation | `mocktail` (no generation) | Flutter community shift ~2022 | No `build_runner` for test doubles |
| `freezed` for copyWith | Hand-rolled sentinel pattern | Project decision (Phase 1) | No additional code generation step |

**Deprecated/outdated:**
- `StateNotifier`: replaced by `Notifier` / `AsyncNotifier` in all new Riverpod code.
- `ProviderContainer()` + manual `addTearDown(container.dispose)`: replaced by `ProviderContainer.test()` in Riverpod 3.x.
- `SharedPreferences.setMockInitialValues` in `setUpAll`: use `setUp` per test when state must be isolated — the mock resets correctly per call.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dart 3.12 supports `if (state case AsyncData(:final value))` pattern-matching syntax in switch expressions | Pattern 2 code example | Syntax error at compile time; replace with `state.value != null` guard instead |
| A2 | `FakeTicker.tick()` calling `_onTick?.call()` synchronously drives state updates before the next line of test code executes | Pattern 6 test example | State may not be updated synchronously; tests need `await Future.microtask(() {})` between ticks and asserts |
| A3 | `SharedPreferences.setMockInitialValues({})` called in `setUp` (once per test) correctly resets the in-memory singleton | Pattern 7 | Test isolation breaks; tests may interfere; use `tearDown(() => prefs.clear())` as fallback |

---

## Open Questions (RESOLVED)

1. **Countdown phase: does the HUD need to read countdown seconds?**
   - What we know: D-06 says the countdown value is "notifier-internal" and "Phase 3 can read elapsed ticks during the countdown phase if it needs to display it."
   - What's unclear: Whether Phase 3 will need a public getter like `int get countdownSecondsRemaining` on the notifier, or whether `GameSession.elapsed` during countdown phase is sufficient.
   - **Decision:** Expose `int get countdownSecondsRemaining` as a public getter on `GameSessionNotifier` (not on the model). Implemented in Plan 02-02.

2. **GameStateRepository serialization of GamePhase and GameMode enums**
   - What we know: D-specific guidance says to serialize to a flat JSON map with key `phase`.
   - What's unclear: Whether to store the enum name (string) or ordinal (int). String is more robust to reordering.
   - **Decision:** Store as `phase.name` (string) and parse back with `GamePhase.values.byName(json['phase'])`. Implemented in Plan 02-01 Task 2.

3. **`completeGame()` responsibility: who calls it?**
   - What we know: Phase 2 must have `completed` state (SC1). The completion trigger (all flags matched) requires knowing the flag pool, which is a Phase 3 concern — Phase 3 builds the CountryData list and manages drag-drop sequencing.
   - **Decision:** Phase 3 is responsible for calling `completeGame()` when the last correct flag is placed. `recordDrop()` in Phase 2 does not auto-complete — it has no knowledge of the flag pool size. Phase 2 unit tests call `completeGame()` explicitly (SC1). This keeps the Phase 2 state machine dependency-free from CountryDataService.

---

## Environment Availability

Phase 2 is pure Dart/Flutter code with no external CLI tools or services beyond the project's own build toolchain.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | `flutter test` | ✓ | 3.44.0 | — |
| Dart SDK | All Dart code | ✓ | 3.12.0 | — |
| `flutter_riverpod` | GameSessionNotifier | ✓ | 3.3.1 (resolved) | — |
| `shared_preferences` | Repositories | ✓ | 2.5.5 (resolved) | — |
| `mocktail` | SC4 mock repository | ✓ | 1.0.5 (resolved) | — |

[VERIFIED: `flutter pub deps` output] — all packages resolved. No missing dependencies.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK, Flutter 3.44.0) |
| Config file | none — standard `flutter test` discovery |
| Quick run command | `flutter test test/unit/game_session_notifier_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCOR-01 | Score increments 1pt per 10s elapsed | unit | `flutter test test/unit/game_session_notifier_test.dart` | ❌ Wave 0 |
| SCOR-02 | Score increments 5pt per incorrect drop | unit | `flutter test test/unit/game_session_notifier_test.dart` | ❌ Wave 0 |
| SCOR-04 | Lowest score per mode persisted to device | unit | `flutter test test/unit/high_score_repository_test.dart` | ❌ Wave 0 |
| SC1 | idle→countdown→playing→paused→completed transitions | unit | `flutter test test/unit/game_session_notifier_test.dart` | ❌ Wave 0 |
| SC2 | 30s + 3 errors = 18 points exactly | unit | `flutter test test/unit/game_session_notifier_test.dart` | ❌ Wave 0 |
| SC3 | HighScoreRepository write + read-back with mock prefs | unit | `flutter test test/unit/high_score_repository_test.dart` | ❌ Wave 0 |
| SC4 | GameStateRepository write on every correct drop | unit | `flutter test test/unit/game_state_repository_test.dart` | ❌ Wave 0 |
| Arch | GameSessionNotifier has zero features/ads/ imports | architecture | `flutter test test/architecture/ads_isolation_test.dart` | ✅ exists |

### Success Criteria Assertion Summary

| SC | Assert | Expected Value |
|----|--------|---------------|
| SC1 | `GamePhase` sequence emitted in order | idle, countdown, playing, paused, playing, completed |
| SC2 | `session.score` after 30s + 3 errors | **18** (not 8 — ROADMAP typo) |
| SC3 | `repo.getBestScore(GameMode.learn)` after `saveBestScore(…, 18)` | 18 |
| SC4 | `verify(() => mockRepo.saveSession(any())).called(N)` | N = number of correct drops |

### Sampling Rate

- **Per task commit:** `flutter test test/unit/ test/architecture/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/unit/game_session_notifier_test.dart` — covers SC1, SC2, SCOR-01, SCOR-02
- [ ] `test/unit/high_score_repository_test.dart` — covers SC3, SCOR-04
- [ ] `test/unit/game_state_repository_test.dart` — covers SC4 write side (SESS-03 write path)

*(Existing test infrastructure: `flutter_test` SDK, `mocktail`, `shared_preferences` mock — all available. No new test framework setup needed in Wave 0.)*

---

## Security Domain

Phase 2 is a pure in-process state machine with no network calls, no user input validation, and no cryptographic operations. No ASVS categories apply. SharedPreferences stores only integer scores and serialized game state — no personal data, no device identifiers, consistent with COMP-01.

---

## Sources

### Primary (HIGH confidence)
- [riverpod.dev/docs/migration/from_state_notifier](https://riverpod.dev/docs/migration/from_state_notifier) — AsyncNotifier manual declaration pattern, `build()` return type
- [riverpod.dev/docs/whats_new](https://riverpod.dev/docs/whats_new) — Riverpod 3.0 `ProviderContainer.test()`, `NotifierProvider.overrideWithBuild`
- [riverpod.dev/docs/how_to/testing](https://riverpod.dev/docs/how_to/testing) — ProviderContainer usage, listen, overrides
- `pubspec.yaml` (this project) — confirmed package versions
- `flutter pub deps` output — confirmed resolved versions
- `test/architecture/ads_isolation_test.dart` (this project) — architecture enforcement pattern
- `lib/features/ads/ad_service.dart` (this project) — abstract interface + stub pattern

### Secondary (MEDIUM confidence)
- [blog.victoreronmosele.com/mocking-shared-preferences-flutter](https://blog.victoreronmosele.com/mocking-shared-preferences-flutter) — `setMockInitialValues` test patterns
- [codewithandrea.com/articles/unit-test-async-notifier-riverpod/](https://codewithandrea.com/articles/unit-test-async-notifier-riverpod/) — AsyncNotifier testing with listener mocks
- [dart.academy/immutable-data-patterns-in-dart-and-flutter/](https://dart.academy/immutable-data-patterns-in-dart-and-flutter/) — copyWith + sentinel pattern
- [github.com/flutter/flutter/issues/28837](https://github.com/flutter/flutter/issues/28837) — SharedPreferences singleton test limitation

### Tertiary (LOW confidence)
- [github.com/rrousselGit/riverpod/discussions/2423](https://github.com/rrousselGit/riverpod/discussions/2423) — synchronous `state = AsyncData(...)` update pattern

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages confirmed in pubspec.yaml + pub deps
- Architecture: HIGH — based on locked decisions from 02-CONTEXT.md + existing codebase patterns
- Riverpod 3.x API: HIGH — verified against official riverpod.dev docs
- SharedPreferences testing: MEDIUM — primary mechanism confirmed; singleton reset behavior documented via issue tracker
- Ticker pattern: MEDIUM — standard DI pattern, concrete code is [ASSUMED] (no official Flutter Ticker-abstraction docs found)
- Pitfalls: HIGH — sourced from official Riverpod docs + GitHub issue tracker

**Research date:** 2026-05-28
**Valid until:** 2026-08-28 (Riverpod 3.x stable; SharedPreferences 2.x stable)
