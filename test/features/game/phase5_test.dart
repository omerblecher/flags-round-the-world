import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session lifecycle — Phase 5', () {
    test('SESS-02: GameSessionNotifier.pauseGame() stops the timer', () =>
        fail('SESS-02 not wired to WidgetsBindingObserver — RED state'));
    test('SESS-04: HomeScreen shows Continue dialog when saved session exists', () =>
        fail('SESS-04 not implemented — RED state'));
    test('SESS-04: restoreGame() restores elapsed, errorCount, matchedIsoCodes', () =>
        fail('SESS-04 restoreGame wiring not implemented — RED state'));
    test('SESS-03: GameStateRepository.clearSession() removes persisted session', () =>
        fail('SESS-03 clearSession not implemented — RED state'));
    test('SESS-03: matchedIsoCodes persisted on correct drop', () =>
        fail('SESS-03 matchedIsoCodes persistence not implemented — RED state'));
    test('SESS-05: tutorial shown on first launch; not shown after tutorial_seen=true', () =>
        fail('SESS-05 tutorial not implemented — RED state'));
  });

  group('Accessibility — Phase 5', () {
    test('ACCS-03: GameHud height is at least 48dp', () =>
        fail('ACCS-03 GameHud height not updated — RED state'));
    test('ACCS-01: mute pref persists across UserPrefsRepository instances', () =>
        fail('ACCS-01 mute persistence not implemented — RED state'));
  });

  group('Social sharing — Phase 5', () {
    test('SHAR-03: parental gate rejects wrong answer and regenerates problem', () =>
        fail('SHAR-03 ParentalGate not implemented — RED state'));
    test('SHAR-03: parental gate accepts correct multiplication answer', () =>
        fail('SHAR-03 ParentalGate correct path not implemented — RED state'));
  });

  group('Canvas fixes — Phase 5', () {
    test('VIS-01: WorldMapPainter shouldRepaint fires when viewScale changes', () =>
        fail('VIS-01 viewScale param not added — RED state'));
    test('VIS-02: hitTest expands micro-country to 48dp target at any scale', () =>
        fail('VIS-02 viewport-area threshold not implemented — RED state'));
  });
}
