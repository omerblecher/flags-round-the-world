import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flags_around_the_world/features/map/completion_screen.dart';
import 'package:flags_around_the_world/features/game/game_session_notifier.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';
import 'package:flags_around_the_world/features/game/game_phase.dart';
import 'package:flags_around_the_world/core/ticker.dart';

class _ManualTicker implements Ticker {
  void Function()? _callback;
  bool _running = false;

  @override
  void start(void Function() callback) {
    _callback = callback;
    _running = true;
  }

  @override
  void stop() {
    _running = false;
  }

  void tick() {
    if (_running) _callback?.call();
  }
}

void main() {
  group('star rating', () {
    test('D-D01: first game (null previousBest) returns 3 stars', () {
      expect(computeStarCount(42, null), equals(3));
    });

    test('D-D02: new PB (score < previousBest) returns 3 stars', () {
      expect(computeStarCount(30, 40), equals(3));
    });

    test('D-D02: within 20% of PB returns 2 stars', () {
      // 48 <= (40 * 1.20).ceil() = 48 -> 2 stars
      expect(computeStarCount(48, 40), equals(2));
    });

    test('D-D02: worse than 20% of PB returns 1 star', () {
      // 49 > 48 -> 1 star
      expect(computeStarCount(49, 40), equals(1));
    });
  });

  group('useHint', () {
    late _ManualTicker ticker;
    late ProviderContainer container;

    setUp(() {
      ticker = _ManualTicker();
      container = ProviderContainer(
        overrides: [
          gameSessionProvider
              .overrideWith(() => GameSessionNotifier(ticker: ticker)),
        ],
      );
      addTearDown(container.dispose);
    });

    test('GAME-07: useHint decrements hintsRemaining', () {
      container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
      // Tick 3 times to pass countdown (GamePhase.countdown -> playing).
      ticker.tick();
      ticker.tick();
      ticker.tick();
      expect(
        container.read(gameSessionProvider).value!.phase,
        equals(GamePhase.playing),
      );
      expect(
        container.read(gameSessionProvider).value!.hintsRemaining,
        equals(2),
      );
      final result = container.read(gameSessionProvider.notifier).useHint();
      expect(result, isTrue);
      expect(
        container.read(gameSessionProvider).value!.hintsRemaining,
        equals(1),
      );
    });

    test('GAME-07: useHint returns false when hintsRemaining is 0', () {
      container.read(gameSessionProvider.notifier).startGame(GameMode.learn);
      ticker.tick();
      ticker.tick();
      ticker.tick();
      container.read(gameSessionProvider.notifier).useHint(); // 2 -> 1
      container.read(gameSessionProvider.notifier).useHint(); // 1 -> 0
      expect(
        container.read(gameSessionProvider).value!.hintsRemaining,
        equals(0),
      );
      final result = container.read(gameSessionProvider.notifier).useHint();
      expect(result, isFalse);
      expect(
        container.read(gameSessionProvider).value!.hintsRemaining,
        equals(0),
      );
    });
  });
}
