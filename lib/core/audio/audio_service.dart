abstract interface class AudioService {
  Future<void> init();
  Future<void> playCorrect();
  Future<void> playError();
  Future<void> dispose();
}
