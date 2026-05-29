import 'package:flutter/material.dart';

class GameHud extends StatelessWidget {
  final int score;
  final Duration elapsed;
  final int matchedCount;
  final int totalFlags;

  const GameHud({
    super.key,
    required this.score,
    required this.elapsed,
    required this.matchedCount,
    required this.totalFlags,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final progress = totalFlags > 0 ? matchedCount / totalFlags : 0.0;

    return Container(
      height: 48,
      color: Colors.grey.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            'Score: $score',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade600,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
