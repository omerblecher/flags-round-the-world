import 'package:flutter_test/flutter_test.dart';

void main() {
  group('star rating', () {
    test('D-D01: first game (null previousBest) returns 3 stars', () => fail('D-D01 not implemented — RED state'));
    test('D-D02: new PB (score < previousBest) returns 3 stars', () => fail('D-D02 not implemented — RED state'));
    test('D-D02: within 20% of PB returns 2 stars', () => fail('D-D02 not implemented — RED state'));
    test('D-D02: worse than 20% of PB returns 1 star', () => fail('D-D02 not implemented — RED state'));
  });
  group('useHint', () {
    test('GAME-07: useHint decrements hintsRemaining', () => fail('GAME-07 not implemented — RED state'));
    test('GAME-07: useHint returns false when hintsRemaining is 0', () => fail('GAME-07 not implemented — RED state'));
  });
}
