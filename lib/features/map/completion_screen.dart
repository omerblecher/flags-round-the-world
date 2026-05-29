import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';
import 'package:flags_around_the_world/features/game/game_session.dart';
import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';

/// Returns the star count for a completed game.
///
/// [score] is the current game score; [previousBest] is null on the first game.
/// Lower score is better (golf-style).
int computeStarCount(int score, int? previousBest) {
  if (previousBest == null) return 3;
  if (score < previousBest) return 3;
  if (score <= (previousBest * 1.20).ceil()) return 2;
  return 1;
}

class CompletionScreen extends StatefulWidget {
  final GameSession session;
  final int? previousBest; // null = first game ever

  const CompletionScreen({
    super.key,
    required this.session,
    this.previousBest,
  });

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen>
    with SingleTickerProviderStateMixin {
  late final bool _isNewPb;
  late final int _starCount;
  late AnimationController _pbController;
  bool _showPbOverlay = false;

  // Share Score state
  final GlobalKey _scoreCardKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    final prev = widget.previousBest;
    final score = widget.session.score;
    if (prev == null) {
      _isNewPb = false;
      _starCount = 3;
    } else if (score < prev) {
      _isNewPb = true;
      _starCount = 3;
    } else if (score <= (prev * 1.20).ceil()) {
      _isNewPb = false;
      _starCount = 2;
    } else {
      _isNewPb = false;
      _starCount = 1;
    }

    _pbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (_isNewPb) {
      setState(() => _showPbOverlay = true);
      _pbController.forward().whenComplete(() {
        if (mounted) setState(() => _showPbOverlay = false);
      });
    }
  }

  @override
  void dispose() {
    _pbController.dispose();
    super.dispose();
  }

  Future<void> _onSharePressed() async {
    final l10n = AppLocalizations.of(context);
    final passed = await _showParentalGate(l10n);
    if (passed != true) return;
    await _captureAndShare(l10n);
  }

  Future<bool?> _showParentalGate(AppLocalizations l10n) async {
    final rng = math.Random();
    int a = 10 + rng.nextInt(90);
    int b = 2 + rng.nextInt(8);
    final controller = TextEditingController();
    String errorText = '';
    bool? result;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.parentalGateTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.parentalGateQuestion(a, b),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(l10n.parentalGateHint,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  errorText: errorText.isEmpty ? null : errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                result = false;
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.parentalGateCancel),
            ),
            ElevatedButton(
              onPressed: () {
                final answer = int.tryParse(controller.text.trim());
                if (answer == a * b) {
                  result = true;
                  Navigator.of(ctx).pop();
                } else {
                  a = 10 + rng.nextInt(90);
                  b = 2 + rng.nextInt(8);
                  controller.clear();
                  setDialogState(() {
                    errorText = l10n.parentalGateWrong;
                  });
                }
              },
              child: Text(l10n.parentalGateConfirm),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _captureAndShare(AppLocalizations l10n) async {
    if (!mounted) return;
    setState(() => _isSharing = true);
    try {
      final boundary = _scoreCardKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final tmpDir = Directory.systemTemp;
      final file = File('${tmpDir.path}/score_card.png');
      await file.writeAsBytes(bytes);

      final modeName = _modeDisplayName(widget.session.mode, l10n);
      final headerText = l10n.shareImageHeader(modeName);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: headerText,
        subject: headerText,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _modeDisplayName(GameMode mode, AppLocalizations l10n) =>
      switch (mode) {
        GameMode.learn => l10n.modeLearnName,
        GameMode.flagsMaster => l10n.modeFlagsMasterName,
        GameMode.geographicalMaster => l10n.modeGeoMasterName,
        GameMode.grandMaster => l10n.modeGrandMasterName,
      };

  Color _modeColor(GameMode mode) => switch (mode) {
        GameMode.learn => const Color(0xFF2E7D32),
        GameMode.flagsMaster => const Color(0xFF1565C0),
        GameMode.geographicalMaster => const Color(0xFFE65100),
        GameMode.grandMaster => const Color(0xFF4A148C),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = widget.session.elapsed.inMinutes;
    final seconds = widget.session.elapsed.inSeconds % 60;
    final modeColor = _modeColor(widget.session.mode);
    final modeName = _modeDisplayName(widget.session.mode, l10n);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: modeColor,
        foregroundColor: Colors.white,
        title: Text(modeName),
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Back to menu',
          onPressed: () => context.go('/'),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < _starCount ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i < _starCount ? Colors.amber : Colors.grey.shade400,
                        size: 56,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.completionTitle,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: modeColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isNewPb) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.completionPersonalBest,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // Score card (captured for sharing)
                RepaintBoundary(
                  key: _scoreCardKey,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatRow(
                          icon: Icons.emoji_events,
                          iconColor: Colors.amber.shade700,
                          label: 'Score',
                          value: '${widget.session.score}',
                        ),
                        const Divider(height: 24),
                        _StatRow(
                          icon: Icons.timer_outlined,
                          iconColor: Colors.blue.shade700,
                          label: 'Time',
                          value:
                              '${minutes}m ${seconds.toString().padLeft(2, '0')}s',
                        ),
                        const Divider(height: 24),
                        _StatRow(
                          icon: Icons.flag_outlined,
                          iconColor: modeColor,
                          label: 'Mode',
                          value: modeName,
                        ),
                        if (widget.previousBest != null) ...[
                          const Divider(height: 24),
                          _StatRow(
                            icon: Icons.history,
                            iconColor: Colors.grey.shade600,
                            label: 'Previous best',
                            value: '${widget.previousBest}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Primary CTA
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: modeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.home),
                    label: const Text(
                      'Back to Menu',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary: play again (same mode)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/play/${widget.session.mode.name}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: modeColor,
                      side: BorderSide(color: modeColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.replay),
                    label: const Text('Play Again'),
                  ),
                ),
                const SizedBox(height: 12),

                // Share button
                if (_isSharing)
                  const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _onSharePressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.share),
                      label: Text(l10n.shareScoreButton),
                    ),
                  ),
              ],
            ),
          ),

          // PB confetti overlay
          if (_showPbOverlay)
            AnimatedBuilder(
              animation: _pbController,
              builder: (ctx, _) {
                final opacity = _pbController.value < 0.8
                    ? 1.0
                    : (1.0 - ((_pbController.value - 0.8) / 0.2))
                        .clamp(0.0, 1.0);
                return IgnorePointer(
                  child: Opacity(
                    opacity: opacity,
                    child: Positioned.fill(
                      child: CustomPaint(
                        painter: _ConfettiPainter(progress: _pbController.value),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _Particle {
  final double x;
  final double speed;
  final Color color;

  const _Particle({
    required this.x,
    required this.speed,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;

  static final List<_Particle> _particles = _generateParticles();

  const _ConfettiPainter({required this.progress});

  static List<_Particle> _generateParticles() {
    final rng = math.Random(42);
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
    ];
    return List.generate(
      40,
      (i) => _Particle(
        x: rng.nextDouble(),
        speed: 0.5 + rng.nextDouble(),
        color: colors[i % colors.length],
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final px = p.x * size.width +
          math.sin(progress * math.pi * 3 + p.x * math.pi * 2) * 20;
      final py = progress * p.speed * size.height;
      final opacity = (1.0 - progress * 1.2).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(px, py), 6, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
