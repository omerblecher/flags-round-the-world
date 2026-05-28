import 'audio_service.dart';

class StubAudioService implements AudioService {
  const StubAudioService();

  @override
  Future<void> init() async {}

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playError() async {}

  @override
  Future<void> dispose() async {}
}
