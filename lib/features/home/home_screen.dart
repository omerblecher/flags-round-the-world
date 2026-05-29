import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';
import 'package:flags_around_the_world/core/data/high_score_repository.dart';

// Private local provider for high scores on the home screen.
// Plan 04-03 promotes a canonical provider to high_score_repository.dart;
// Plan 04-04 will remove this private one once both plans have merged.
final _homeHighScoreRepoProvider = FutureProvider<HighScoreRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesHighScoreRepository(prefs);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repoAsync = ref.watch(_homeHighScoreRepoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
      ),
      body: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (repo) => _buildModeList(context, ref, l10n, repo),
      ),
    );
  }

  Widget _buildModeList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    HighScoreRepository repo,
  ) {
    final modes = [
      _ModeInfo(
        mode: GameMode.learn,
        name: l10n.modeLearnName,
        description: l10n.modeLearnDescription,
      ),
      _ModeInfo(
        mode: GameMode.flagsMaster,
        name: l10n.modeFlagsMasterName,
        description: l10n.modeFlagsMasterDescription,
      ),
      _ModeInfo(
        mode: GameMode.geographicalMaster,
        name: l10n.modeGeoMasterName,
        description: l10n.modeGeoMasterDescription,
      ),
      _ModeInfo(
        mode: GameMode.grandMaster,
        name: l10n.modeGrandMasterName,
        description: l10n.modeGrandMasterDescription,
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      itemCount: modes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final info = modes[index];
        return Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              info.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(info.description),
            trailing: FutureBuilder<int?>(
              future: repo.getBestScore(info.mode),
              builder: (ctx, snap) {
                final text = snap.hasData && snap.data != null
                    ? l10n.homeBestScore(snap.data!)
                    : l10n.homeNoBestScore;
                return Text(
                  text,
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
            onTap: () => context.go('/play/${info.mode.name}'),
          ),
        );
      },
    );
  }
}

class _ModeInfo {
  final GameMode mode;
  final String name;
  final String description;

  const _ModeInfo({
    required this.mode,
    required this.name,
    required this.description,
  });
}
