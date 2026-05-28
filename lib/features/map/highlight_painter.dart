import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';

class HighlightPainter extends CustomPainter {
  const HighlightPainter({
    required this.hoveredIso,
    required this.countryIndex,
    this.targetIsoCode,
    this.viewScale = 1.0,
  });

  final String? hoveredIso;
  final Map<String, CountryData> countryIndex;
  /// The ISO code of the country the player currently needs to find.
  final String? targetIsoCode;
  /// Current InteractiveViewer scale (screen pixels per scene unit).
  /// Used to keep ring and hover-dot sizes fixed in screen pixels.
  final double viewScale;

  // Target ring: ~16 screen-px radius, clamped between 6 and 80 scene units.
  double get _ringRadius =>
      (16.0 / viewScale).clamp(6.0, 80.0);

  // Outer pulsing ring: slightly larger than inner.
  double get _outerRingRadius =>
      (24.0 / viewScale).clamp(9.0, 110.0);

  // Hover dot for degenerate countries: ~10 screen-px radius.
  double get _hoverDotRadius =>
      (10.0 / viewScale).clamp(5.0, 14.0);

  @override
  bool shouldRepaint(HighlightPainter old) =>
      old.hoveredIso != hoveredIso ||
      old.targetIsoCode != targetIsoCode ||
      (old.viewScale - viewScale).abs() > 0.005 ||
      !identical(old.countryIndex, countryIndex);

  @override
  void paint(Canvas canvas, Size size) {
    // Target ring — drawn first so hover highlight appears on top.
    if (targetIsoCode != null) {
      final country = countryIndex[targetIsoCode];
      if (country != null) _drawTargetRing(canvas, country);
    }

    // Hover highlight.
    if (hoveredIso != null) {
      final country = countryIndex[hoveredIso];
      if (country != null) _drawHover(canvas, country);
    }
  }

  void _drawTargetRing(Canvas canvas, CountryData country) {
    if (country.isDegenerate) {
      // Two concentric orange rings around the centroid — always ~16 & 24 px.
      final inner = Paint()
        ..color = const Color(0xFFFF6600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, 2.0 / viewScale);
      canvas.drawCircle(country.centroid, _ringRadius, inner);

      final outer = Paint()
        ..color = const Color(0x88FF6600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, 1.5 / viewScale);
      canvas.drawCircle(country.centroid, _outerRingRadius, outer);
    } else {
      final paint = Paint()
        ..color = const Color(0xFFFF6600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, 2.0 / viewScale);
      for (final path in country.paths) {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawHover(Canvas canvas, CountryData country) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    if (country.isDegenerate) {
      // Scale-adaptive gold dot — always ~10 screen px radius.
      canvas.drawCircle(country.centroid, _hoverDotRadius, paint);
    } else {
      for (final path in country.paths) {
        canvas.drawPath(path, paint);
      }
    }
  }
}
