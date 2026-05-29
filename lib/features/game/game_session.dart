import 'game_phase.dart';
import 'game_mode.dart';

class GameSession {
  const GameSession({
    required this.phase,
    required this.mode,
    required this.score,
    required this.elapsed,
    required this.errorCount,
    this.activeIsoCode,
    required this.hintsRemaining,
    this.matchedIsoCodes = const [],
  });

  final GamePhase phase;
  final GameMode mode;
  final int score;
  final Duration elapsed;
  final int errorCount;
  final String? activeIsoCode;
  final int hintsRemaining;
  final List<String> matchedIsoCodes;

  static const Object _sentinel = Object();

  GameSession copyWith({
    GamePhase? phase,
    GameMode? mode,
    int? score,
    Duration? elapsed,
    int? errorCount,
    Object? activeIsoCode = _sentinel,
    int? hintsRemaining,
    List<String>? matchedIsoCodes,
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
      matchedIsoCodes: matchedIsoCodes ?? this.matchedIsoCodes,
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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
          hintsRemaining == other.hintsRemaining &&
          _listEquals(matchedIsoCodes, other.matchedIsoCodes);

  @override
  int get hashCode => Object.hash(
        phase,
        mode,
        score,
        elapsed,
        errorCount,
        activeIsoCode,
        hintsRemaining,
        Object.hashAll(matchedIsoCodes),
      );
}
