import 'package:flutter/material.dart';

import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.score,
    required this.elapsed,
    required this.matchedCount,
    required this.totalFlags,
    required this.onPause,
    this.isMuted = false,
    this.onMuteToggle,
  });

  final int score;
  final Duration elapsed;
  final int matchedCount;
  final int totalFlags;
  final VoidCallback onPause;
  final bool isMuted;
  final VoidCallback? onMuteToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes =
        elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final progress = totalFlags > 0 ? matchedCount / totalFlags : 0.0;

    return Container(
      height: 48,
      color: Colors.grey.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            'Score: $score',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade600,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          // Mute toggle button — 48dp touch target
          Semantics(
            label: l10n.hudMuteSemanticLabel,
            button: true,
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                tooltip: isMuted ? l10n.pauseMuteOff : l10n.pauseMuteOn,
                icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onMuteToggle,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          // Pause button — 48dp touch target
          Semantics(
            label: l10n.hudPauseSemanticLabel,
            button: true,
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                tooltip: l10n.pauseButtonTooltip,
                icon: const Icon(
                  Icons.pause,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onPause,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
