import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flags_around_the_world/features/game/game_session.dart';
import 'package:flags_around_the_world/features/game/game_phase.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';

abstract interface class GameStateRepository {
  Future<void> saveSession(GameSession session);
  Future<GameSession?> loadSession();
  Future<void> clearSession();
}

class SharedPreferencesGameStateRepository implements GameStateRepository {
  SharedPreferencesGameStateRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'game_session_snapshot';

  @override
  Future<void> saveSession(GameSession session) async {
    final json = {
      'phase': session.phase.name,
      'mode': session.mode.name,
      'score': session.score,
      'elapsedSeconds': session.elapsed.inSeconds,
      'errorCount': session.errorCount,
      'activeIsoCode': session.activeIsoCode,
      'hintsRemaining': session.hintsRemaining,
      'matchedIsoCodes': session.matchedIsoCodes,
    };
    await _prefs.setString(_key, jsonEncode(json));
  }

  @override
  Future<GameSession?> loadSession() async {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return GameSession(
        phase: GamePhase.values.byName(json['phase'] as String),
        mode: GameMode.values.byName(json['mode'] as String),
        score: json['score'] as int,
        elapsed: Duration(seconds: json['elapsedSeconds'] as int),
        errorCount: json['errorCount'] as int,
        activeIsoCode: json['activeIsoCode'] as String?,
        hintsRemaining: json['hintsRemaining'] as int,
        matchedIsoCodes: (json['matchedIsoCodes'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    await _prefs.remove(_key);
  }
}

final gameStateRepositoryProvider = FutureProvider<GameStateRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesGameStateRepository(prefs);
});
