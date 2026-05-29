import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'generated/l10n/app_localizations.dart';
import 'features/home/home_screen.dart';
import 'features/home/welcome_screen.dart';
import 'features/map/map_screen.dart';
import 'features/map/completion_screen.dart';
import 'features/game/game_mode.dart';
import 'features/game/game_session.dart';

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

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flags Around the World',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
