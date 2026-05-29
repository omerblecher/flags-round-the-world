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

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.public, size: 32, color: Color(0xFF1565C0)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Flags Around the World',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'An educational geography game for all ages. '
              'Drag-and-drop national flags onto their countries on the world map. '
              'Learn every country\'s flag and location.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              '© 2025 Otis & Brooke',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(AppConstants.privacyPolicyUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('Privacy Policy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repoAsync = ref.watch(highScoreRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: repoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (repo) => _buildBody(context, l10n, repo),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    HighScoreRepository repo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
          child: Row(
            children: [
              const Icon(Icons.public, color: Color(0xFF1565C0), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.homeTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D2E6B),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.grey),
                tooltip: 'About',
                onPressed: () => _showAboutDialog(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 12),
          child: Text(
            l10n.modeSectionTitle,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Mode cards
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ModeCard(
                mode: GameMode.learn,
                name: l10n.modeLearnName,
                description: l10n.modeLearnDescription,
                icon: Icons.explore,
                cardColor: const Color(0xFF2E7D32),
                bestScoreFuture: repo.getBestScore(GameMode.learn),
                onTap: () => context.go('/play/${GameMode.learn.name}'),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: GameMode.flagsMaster,
                name: l10n.modeFlagsMasterName,
                description: l10n.modeFlagsMasterDescription,
                icon: Icons.flag,
                cardColor: const Color(0xFF1565C0),
                bestScoreFuture: repo.getBestScore(GameMode.flagsMaster),
                onTap: () => context.go('/play/${GameMode.flagsMaster.name}'),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: GameMode.geographicalMaster,
                name: l10n.modeGeoMasterName,
                description: l10n.modeGeoMasterDescription,
                icon: Icons.compass_calibration,
                cardColor: const Color(0xFFBF360C),
                bestScoreFuture: repo.getBestScore(GameMode.geographicalMaster),
                onTap: () =>
                    context.go('/play/${GameMode.geographicalMaster.name}'),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: GameMode.grandMaster,
                name: l10n.modeGrandMasterName,
                description: l10n.modeGrandMasterDescription,
                icon: Icons.emoji_events,
                cardColor: const Color(0xFF4A148C),
                bestScoreFuture: repo.getBestScore(GameMode.grandMaster),
                onTap: () =>
                    context.go('/play/${GameMode.grandMaster.name}'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // Privacy footer
        _buildPrivacyFooter(context, l10n),
      ],
    );
  }

  Widget _buildPrivacyFooter(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: TextButton(
          onPressed: () async {
            final uri = Uri.parse(AppConstants.privacyPolicyUrl);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Text(
            l10n.privacyPolicyLink,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode card widget
// ---------------------------------------------------------------------------

class _ModeCard extends StatefulWidget {
  final GameMode mode;
  final String name;
  final String description;
  final IconData icon;
  final Color cardColor;
  final Future<int?> bestScoreFuture;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.name,
    required this.description,
    required this.icon,
    required this.cardColor,
    required this.bestScoreFuture,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  int _starsForScore(int? score) {
    if (score == null) return 0;
    if (score <= 80) return 3;
    if (score <= 150) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.cardColor,
                Color.lerp(widget.cardColor, Colors.black, 0.2)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.cardColor.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Mode icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),

              // Name + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Stars
              FutureBuilder<int?>(
                future: widget.bestScoreFuture,
                builder: (ctx, snap) {
                  final stars = snap.hasData
                      ? _starsForScore(snap.data)
                      : 0;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          return Icon(
                            i < stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < stars
                                ? Colors.amber
                                : Colors.white.withValues(alpha: 0.4),
                            size: 18,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      if (snap.hasData && snap.data != null)
                        Text(
                          'Best: ${snap.data}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        )
                      else
                        Text(
                          'Not played',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
