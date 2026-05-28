import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flags_around_the_world/core/data/high_score_repository.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';

void main() {
  group('HighScoreRepository', () {
    late SharedPreferences prefs;
    late HighScoreRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = SharedPreferencesHighScoreRepository(prefs);
    });

    test('SC3: saves and reads back best score per GameMode', () async {
      await repo.saveBestScore(GameMode.learn, 18);
      expect(await repo.getBestScore(GameMode.learn), 18);
    });

    test('SCOR-04: only updates when new score is lower (golf-style)', () async {
      await repo.saveBestScore(GameMode.learn, 18);
      // Save a worse score (higher) — should NOT overwrite
      await repo.saveBestScore(GameMode.learn, 25);
      expect(await repo.getBestScore(GameMode.learn), 18);
      // Save a better score (lower) — SHOULD overwrite
      await repo.saveBestScore(GameMode.learn, 12);
      expect(await repo.getBestScore(GameMode.learn), 12);
    });

    test('SC3: returns null when no score stored', () async {
      expect(await repo.getBestScore(GameMode.learn), isNull);
    });
  });
}
