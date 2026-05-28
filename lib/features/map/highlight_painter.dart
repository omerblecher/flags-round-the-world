import 'package:flutter/material.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';

class HighlightPainter extends CustomPainter {
  const HighlightPainter({
    required this.hoveredIso,
    required this.countryIndex,
  });

  final String? hoveredIso;
  final Map<String, CountryData> countryIndex;

  @override
  bool shouldRepaint(HighlightPainter old) => old.hoveredIso != hoveredIso;

  @override
  void paint(Canvas canvas, Size size) {
    if (hoveredIso == null) return;
    final country = countryIndex[hoveredIso];
    if (country == null) return;

    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    for (final path in country.paths) {
      canvas.drawPath(path, paint);
    }
  }
}
