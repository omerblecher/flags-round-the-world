import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'generated/l10n/app_localizations.dart';
import 'features/home/home_screen.dart';
import 'features/home/welcome_screen.dart';
import 'features/map/map_screen.dart';
import 'features/map/completion_screen.dart';
import 'features/game/game_mode.dart';
import 'features/game/game_session.dart';
import 'features/game/game_phase.dart';
import 'features/game/game_session_notifier.dart';
import 'core/ads/ad_service_provider.dart';
import 'core/ads/app_state_observer.dart'; // re-exports AppStateEventNotifier, AppState

/// Top-level GoRouter — defined at file scope so it is created once and reused.
final _router = GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/play/:mode',
      builder: (context, state) {
        final modeName = state.pathParameters['mode']!;
        final mode = GameMode.values.byName(modeName);
        final extra = state.extra as Map<String, dynamic>?;
        return MapScreen(
          mode: mode,
          restoredMatchedIsoCodes:
              extra?['matchedIsoCodes'] as List<String>?,
          restoredRemainingIsoCodes:
              extra?['remainingIsoCodes'] as List<String>?,
          restoredSession: extra?['restoredSession'] as GameSession?,
        );
      },
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! Map<String, dynamic>) return const HomeScreen();
        final session = extra['session'];
        if (session is! GameSession) return const HomeScreen();
        return CompletionScreen(
          session: session,
          previousBest: extra['previousBest'] as int?,
        );
      },
    ),
  ],
);

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  StreamSubscription<AppState>? _appStateSubscription;

  @override
  void initState() {
    super.initState();
    AppStateEventNotifier.startListening();
    _appStateSubscription = AppStateEventNotifier.appStateStream.listen(
      (appState) {
        if (appState == AppState.foreground) _onAppResumed();
      },
    );
  }

  void _onAppResumed() {
    // D-O02: suppress App Open when a game session is active.
    final phase = ref.read(gameSessionProvider).value?.phase;
    if (phase == GamePhase.playing || phase == GamePhase.paused) return;
    ref.read(adServiceProvider).showAppOpenAd();
  }

  @override
  void dispose() {
    _appStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flags Around the World',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
