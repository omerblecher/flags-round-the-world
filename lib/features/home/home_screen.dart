import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';
import 'package:flags_around_the_world/features/game/game_phase.dart';
import 'package:flags_around_the_world/features/game/game_session.dart';
import 'package:flags_around_the_world/core/constants.dart';
import 'package:flags_around_the_world/core/data/high_score_repository.dart';
import 'package:flags_around_the_world/core/data/game_state_repository.dart';
import 'package:flags_around_the_world/core/data/country_data_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final repo = await ref.read(gameStateRepositoryProvider.future);
    final session = await repo.loadSession();
    if (!mounted) return;
    if (session != null &&
        (session.phase == GamePhase.playing ||
            session.phase == GamePhase.paused)) {
      _showContinueDialog(session);
    } else if (session != null) {
      // Stale session in bad state — clear silently (D-S02)
      await repo.clearSession();
    }
  }

  void _showContinueDialog(GameSession session) {
    final l10n = AppLocalizations.of(context);
    final minutes = session.elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds =
        (session.elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final modeName = _modeDisplayName(session.mode, l10n);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.continueGameTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.continueGameMode(modeName)),
            Text(l10n.continueGameScore(session.score)),
            Text(l10n.continueGameTime('$minutes:$seconds')),
            Text(l10n.continueGameFlags(
                session.matchedIsoCodes.length, 196)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final r =
                  await ref.read(gameStateRepositoryProvider.future);
              await r.clearSession();
            },
            child: Text(l10n.newGameButton),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _continueGame(session);
            },
            child: Text(l10n.continueButton),
          ),
        ],
      ),
    );
  }

  Future<void> _continueGame(GameSession session) async {
    // Load all countries, then compute remaining = all - matched.
    final countries = await ref.read(countryDataProvider.future);
    final allIsoCodes = countries.map((c) => c.isoCode).toList();
    final matched = session.matchedIsoCodes.toSet();
    final remaining =
        allIsoCodes.where((iso) => !matched.contains(iso)).toList();

    if (!mounted) return;
    context.go('/play/${session.mode.name}', extra: {
      'matchedIsoCodes': session.matchedIsoCodes,
      'remainingIsoCodes': remaining,
      'restoredSession': session,
    });
  }

  String _modeDisplayName(GameMode mode, AppLocalizations l10n) =>
      switch (mode) {
        GameMode.learn => l10n.modeLearnName,
        GameMode.flagsMaster => l10n.modeFlagsMasterName,
        GameMode.geographicalMaster => l10n.modeGeoMasterName,
        GameMode.grandMaster => l10n.modeGrandMasterName,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repoAsync = ref.watch(highScoreRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (repo) => _buildBody(context, l10n, repo),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    HighScoreRepository repo,
  ) {
    return Column(
      children: [
        Expanded(child: _buildModeList(context, l10n, repo)),
        // Privacy policy footer (COMP-02)
        _buildPrivacyFooter(context, l10n),
      ],
    );
  }

  Widget _buildPrivacyFooter(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextButton(
        onPressed: () async {
          final uri = Uri.parse(AppConstants.privacyPolicyUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Text(
          l10n.privacyPolicyLink,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildModeList(
    BuildContext context,
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
