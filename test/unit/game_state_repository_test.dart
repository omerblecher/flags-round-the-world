import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flags_around_the_world/core/data/game_state_repository.dart';
import 'package:flags_around_the_world/features/game/game_session.dart';

void main() {
  group('GameStateRepository', () {
    test('SC4: saveSession called once per correct drop', () {
      fail('SC4 not implemented — RED state');
    });

    test(
        'SC4: saveSession serializes GameSession to SharedPreferences key game_session_snapshot',
        () {
      fail('SC4 not implemented — RED state');
    });
  });
}
