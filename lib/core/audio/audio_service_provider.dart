import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_service.dart';
import 'real_audio_service.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = RealAudioService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});
