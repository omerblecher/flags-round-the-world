import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: uri_does_not_exist
import 'package:flags_around_the_world/features/game/game_session_notifier.dart';
import 'package:flags_around_the_world/core/ticker.dart';

void main() {
  group('GameSessionNotifier', () {
    test('SC1: idle → countdown → playing → paused → completed transitions',
        () {
      fail('SC1 not implemented — RED state');
    });

    test('SC2: 30s + 3 errors = 18 points (golf-style, per D-13)', () {
      fail('SC2 not implemented — RED state');
    });

    test('SCOR-01: score increments 1pt per 10s elapsed', () {
      fail('SCOR-01 not implemented — RED state');
    });

    test('SCOR-02: score increments 5pt per incorrect drop', () {
      fail('SCOR-02 not implemented — RED state');
    });
  });
}
