import 'package:flutter/material.dart';
import 'package:flags_around_the_world/features/game/game_session.dart';
import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';

class CompletionScreen extends StatelessWidget {
  final GameSession session;
  // previousBest is wired fully in Plan 04-05; added here so the /result route compiles.
  final int? previousBest;

  const CompletionScreen({super.key, required this.session, this.previousBest});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = session.elapsed.inMinutes;
    final seconds = session.elapsed.inSeconds % 60;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.completionTitle,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.completionScore(session.score)),
            Text(l10n.completionElapsed('${minutes}m ${seconds}s')),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(l10n.completionPlayAgain),
            ),
          ],
        ),
      ),
    );
  }
}
