import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flags_around_the_world/features/game/game_session.dart';
import 'package:flags_around_the_world/features/game/game_phase.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';
import 'package:flags_around_the_world/core/ticker.dart';
import 'package:flags_around_the_world/core/data/game_state_repository.dart';
import 'package:flags_around_the_world/core/data/high_score_repository.dart';

final gameSessionProvider =
    AsyncNotifierProvider<GameSessionNotifier, GameSession>(
  () => GameSessionNotifier(ticker: RealTicker()),
);

class GameSessionNotifier extends AsyncNotifier<GameSession> {
  GameSessionNotifier({
    required Ticker ticker,
    GameStateRepository? gameStateRepository,
    HighScoreRepository? highScoreRepository,
  })  : _ticker = ticker,
        _gameStateRepository = gameStateRepository,
        _highScoreRepository = highScoreRepository;

  final Ticker _ticker;
  final GameStateRepository? _gameStateRepository;
  final HighScoreRepository? _highScoreRepository;

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

  /// Number of countdown seconds remaining (3 → 2 → 1 → 0).
  int get countdownSecondsRemaining => 3 - _countdownTick;

  Future<void> startGame(GameMode mode) async {
    _elapsedSeconds = 0;
    _countdownTick = 0;
    _remainingIsoCodes = [];
    state = AsyncData(
      state.value!.copyWith(
        phase: GamePhase.countdown,
        mode: mode,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        activeIsoCode: null,
        hintsRemaining: 2,
      ),
    );
    _ticker.start(_onTick);
  }

  void _onTick() {
    final current = state.value;
    if (current == null) return;

    if (current.phase == GamePhase.countdown) {
      _countdownTick++;
      if (_countdownTick >= 3) {
        state = AsyncData(current.copyWith(phase: GamePhase.playing));
      }
    } else if (current.phase == GamePhase.playing) {
      _elapsedSeconds++;
      final score =
          (_elapsedSeconds ~/ 10) + (current.errorCount * 5);
      state = AsyncData(current.copyWith(
        score: score,
        elapsed: Duration(seconds: _elapsedSeconds),
      ));
    }
  }

  void pauseGame() {
    _ticker.stop();
    state = AsyncData(state.value!.copyWith(phase: GamePhase.paused));
  }

  void resumeGame() {
    state = AsyncData(state.value!.copyWith(phase: GamePhase.playing));
    _ticker.start(_onTick);
  }

  void recordDrop(String isoCode, {required bool isCorrect}) {
    final current = state.value!;
    if (isCorrect) {
      _gameStateRepository?.saveSession(current);
    } else {
      final newErrorCount = current.errorCount + 1;
      final newScore = (_elapsedSeconds ~/ 10) + (newErrorCount * 5);
      state = AsyncData(current.copyWith(
        errorCount: newErrorCount,
        score: newScore,
      ));
    }
  }

  Future<void> completeGame() async {
    _ticker.stop();
    final current = state.value!;
    state = AsyncData(current.copyWith(phase: GamePhase.completed));
    if (_highScoreRepository != null) {
      await _highScoreRepository.saveBestScore(current.mode, current.score);
    }
  }
}
