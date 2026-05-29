abstract interface class AudioService {
  Future<void> init();
  Future<void> playCorrect();
  Future<void> playError();
  Future<void> setMuted(bool muted);
  Future<void> dispose();
}
