import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
// ignore: uri_does_not_exist
import 'package:flags_around_the_world/features/game/game_session_notifier.dart';
import 'package:flags_around_the_world/features/game/game_phase.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';
import 'package:flags_around_the_world/features/game/game_session.dart';
import 'package:flags_around_the_world/core/ticker.dart';
import 'package:flags_around_the_world/core/data/game_state_repository.dart';
import 'package:flags_around_the_world/core/data/high_score_repository.dart';

class MockGameStateRepository extends Mock implements GameStateRepository {}
class MockHighScoreRepository extends Mock implements HighScoreRepository {}

// Fallback values required by mocktail for any() matchers on custom types.
class _FakeGameSession extends Fake implements GameSession {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeGameSession());
    registerFallbackValue(GameMode.learn);
  });

  group('GameSessionNotifier', () {
    late FakeTicker fakeTicker;
    late MockGameStateRepository mockGameStateRepo;
    late MockHighScoreRepository mockHighScoreRepo;
    late ProviderContainer container;

    setUp(() {
      fakeTicker = FakeTicker();
      mockGameStateRepo = MockGameStateRepository();
      mockHighScoreRepo = MockHighScoreRepository();

      when(() => mockGameStateRepo.saveSession(any())).thenAnswer((_) async {});
      when(() => mockHighScoreRepo.saveBestScore(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockHighScoreRepo.getBestScore(any()))
          .thenAnswer((_) async => null);

      container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith(
            () => GameSessionNotifier(
              ticker: fakeTicker,
              gameStateRepository: mockGameStateRepo,
              highScoreRepository: mockHighScoreRepo,
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('SC1: idle → countdown → playing → paused → completed transitions',
        () async {
      // Initial state: idle
      final initial = container.read(gameSessionProvider).value!;
      expect(initial.phase, GamePhase.idle);

      // After startGame: countdown
      container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
      expect(container.read(gameSessionProvider).value!.phase,
          GamePhase.countdown);

      // After 3 ticks: playing
      fakeTicker.tick();
      fakeTicker.tick();
      fakeTicker.tick();
      expect(container.read(gameSessionProvider).value!.phase,
          GamePhase.playing);

      // After pauseGame: paused
      container.read(gameSessionProvider.notifier).pauseGame();
      expect(container.read(gameSessionProvider).value!.phase,
          GamePhase.paused);

      // After resumeGame: playing
      container.read(gameSessionProvider.notifier).resumeGame();
      expect(container.read(gameSessionProvider).value!.phase,
          GamePhase.playing);

      // After completeGame: completed
      await container.read(gameSessionProvider.notifier).completeGame();
      expect(container.read(gameSessionProvider).value!.phase,
          GamePhase.completed);
    });

    test('SC2: 30s + 3 errors = 18 points (golf-style, per D-13)', () async {
      // Start and advance through countdown
      container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
      fakeTicker.tick();
      fakeTicker.tick();
      fakeTicker.tick();
      expect(container.read(gameSessionProvider).value!.phase,
          GamePhase.playing);

      // 30 play ticks
      for (var i = 0; i < 30; i++) {
        fakeTicker.tick();
      }

      // 3 incorrect drops
      container
          .read(gameSessionProvider.notifier)
          .recordDrop('xx', isCorrect: false);
      container
          .read(gameSessionProvider.notifier)
          .recordDrop('xx', isCorrect: false);
      container
          .read(gameSessionProvider.notifier)
          .recordDrop('xx', isCorrect: false);

      // (30 ~/ 10) + (3 * 5) = 3 + 15 = 18
      expect(container.read(gameSessionProvider).value!.score, 18);
    });

    test('SCOR-01: score increments 1pt per 10s elapsed', () async {
      container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
      // Advance through countdown
      fakeTicker.tick();
      fakeTicker.tick();
      fakeTicker.tick();

      // 9 ticks: score == 0
      for (var i = 0; i < 9; i++) {
        fakeTicker.tick();
      }
      expect(container.read(gameSessionProvider).value!.score, 0);

      // 1 more tick = 10 total: score == 1
      fakeTicker.tick();
      expect(container.read(gameSessionProvider).value!.score, 1);

      // 10 more ticks = 20 total: score == 2
      for (var i = 0; i < 10; i++) {
        fakeTicker.tick();
      }
      expect(container.read(gameSessionProvider).value!.score, 2);
    });

    test('SCOR-02: score increments 5pt per incorrect drop', () async {
      container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
      // Advance through countdown
      fakeTicker.tick();
      fakeTicker.tick();
      fakeTicker.tick();

      // 1 incorrect drop at 0s elapsed: score == 5
      container
          .read(gameSessionProvider.notifier)
          .recordDrop('xx', isCorrect: false);
      expect(container.read(gameSessionProvider).value!.score, 5);

      // 2 incorrect drops: score == 10
      container
          .read(gameSessionProvider.notifier)
          .recordDrop('xx', isCorrect: false);
      expect(container.read(gameSessionProvider).value!.score, 10);
    });

    test('SC4: saveSession called once per correct drop', () async {
      container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
      // Advance through countdown
      fakeTicker.tick();
      fakeTicker.tick();
      fakeTicker.tick();

      container
          .read(gameSessionProvider.notifier)
          .recordDrop('de', isCorrect: true);
      container
          .read(gameSessionProvider.notifier)
          .recordDrop('de', isCorrect: true);

      verify(() => mockGameStateRepo.saveSession(any())).called(2);
    });
  });
}
