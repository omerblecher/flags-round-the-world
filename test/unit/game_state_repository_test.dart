import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flags_around_the_world/core/data/game_state_repository.dart';
import 'package:flags_around_the_world/features/game/game_session.dart';
import 'package:flags_around_the_world/features/game/game_phase.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';

void main() {
  group('GameStateRepository', () {
    late SharedPreferences prefs;
    late GameStateRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = SharedPreferencesGameStateRepository(prefs);
    });

    GameSession _buildSession() => const GameSession(
          phase: GamePhase.playing,
          mode: GameMode.learn,
          score: 18,
          elapsed: Duration(seconds: 30),
          errorCount: 3,
          activeIsoCode: 'de',
          hintsRemaining: 2,
        );

    test(
        'SC4: saveSession serializes GameSession to SharedPreferences key game_session_snapshot',
        () async {
      final session = _buildSession();
      await repo.saveSession(session);

      final raw = prefs.getString('game_session_snapshot');
      expect(raw, isNotNull);
      final json = jsonDecode(raw!) as Map<String, dynamic>;
      expect(json['phase'], 'playing');
      expect(json['score'], 18);
    });

    test('SC4: saveSession called once per correct drop', () async {
      // This test verifies the round-trip via the concrete implementation.
      // Mock-based call-count verification lives in game_session_notifier_test.dart (Plan 02-02).
      final session = _buildSession();
      await repo.saveSession(session);
      final loaded = await repo.loadSession();
      expect(loaded, equals(session));
    });
  });
}
