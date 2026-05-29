import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flags_around_the_world/features/home/home_screen.dart';
import 'package:flags_around_the_world/core/data/high_score_repository.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';
import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';

class _StubHighScoreRepository implements HighScoreRepository {
  final Map<GameMode, int?> _scores;

  _StubHighScoreRepository(this._scores);

  @override
  Future<int?> getBestScore(GameMode mode) async => _scores[mode];

  @override
  Future<void> saveBestScore(GameMode mode, int score) async {}
}

Widget _wrap(Widget child, HighScoreRepository repo) {
  return ProviderScope(
    overrides: [
      highScoreRepositoryProvider.overrideWith((_) async => repo),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => child),
        ],
      ),
    ),
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('SC1: renders 4 mode cards', (tester) async {
      final repo = _StubHighScoreRepository({});
      await tester.pumpWidget(_wrap(const HomeScreen(), repo));
      await tester.pumpAndSettle();
      // Expect all 4 mode names are visible.
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Flags Master'), findsOneWidget);
      expect(find.text('Geographical Master'), findsOneWidget);
      expect(find.text('Grand Master'), findsOneWidget);
    });

    testWidgets('SC1: shows dash when no best score', (tester) async {
      final repo = _StubHighScoreRepository({}); // null for all modes
      await tester.pumpWidget(_wrap(const HomeScreen(), repo));
      await tester.pumpAndSettle();
      // At least one mode card shows the em dash (homeNoBestScore = "Best: —").
      expect(find.textContaining('—'), findsWidgets);
    });
  });
}
