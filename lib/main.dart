import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/audio/audio_service_provider.dart';
import 'core/audio/real_audio_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        audioServiceProvider.overrideWith((_) {
          final svc = RealAudioService();
          unawaited(svc.init());
          return svc;
        }),
      ],
      child: const App(),
    ),
  );
}
