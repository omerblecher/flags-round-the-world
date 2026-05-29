import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_service.dart';

class RealAudioService implements AudioService {
  late AudioPlayer _correctPlayer;
  late AudioPlayer _errorPlayer;
  bool _initialized = false;

  @override
  Future<void> init() async {
    _correctPlayer = AudioPlayer();
    _errorPlayer = AudioPlayer();
    try {
      await _correctPlayer.setAsset('assets/audio/correct.wav');
      await _errorPlayer.setAsset('assets/audio/error.wav');
      _initialized = true;
    } on PlayerException catch (e) {
      debugPrint('AudioService init failed: $e');
      _initialized = false;
    } catch (e) {
      debugPrint('AudioService init error: $e');
      _initialized = false;
    }
  }

  @override
  Future<void> playCorrect() async {
    if (!_initialized) return;
    try {
      await _correctPlayer.seek(Duration.zero);
      await _correctPlayer.play();
    } catch (_) {}
  }

  @override
  Future<void> playError() async {
    if (!_initialized) return;
    try {
      await _errorPlayer.seek(Duration.zero);
      await _errorPlayer.play();
    } catch (_) {}
  }

  @override
  Future<void> setMuted(bool muted) async {
    final volume = muted ? 0.0 : 1.0;
    try {
      await _correctPlayer.setVolume(volume);
      await _errorPlayer.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _correctPlayer.dispose();
    await _errorPlayer.dispose();
  }
}
