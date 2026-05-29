import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';

class HighlightPainter extends CustomPainter {
  const HighlightPainter({
    required this.hoveredIso,
    required this.countryIndex,
    this.targetIsoCode,
    this.viewScale = 1.0,
    this.hintIso,
  });

  final String? hoveredIso;
  final Map<String, CountryData> countryIndex;
  /// The ISO code of the country the player currently needs to find.
  final String? targetIsoCode;
  /// Current InteractiveViewer scale (screen pixels per scene unit).
  /// Used to keep ring and hover-dot sizes fixed in screen pixels.
  final double viewScale;
  /// The ISO code of the country currently highlighted as a hint.
  final String? hintIso;

  // Target ring: ~16 screen-px radius, clamped between 6 and 80 scene units.
  double get _ringRadius =>
      (16.0 / viewScale).clamp(6.0, 80.0);

  // Outer pulsing ring: slightly larger than inner.
  double get _outerRingRadius =>
      (24.0 / viewScale).clamp(9.0, 110.0);

  // Hover dot for degenerate countries: ~10 screen-px radius.
  double get _hoverDotRadius =>
      (10.0 / viewScale).clamp(5.0, 14.0);

  // Threshold below which a country's path is too small to see on screen.
  // When the bbox diagonal in screen pixels falls below this, we fall back to
  // the ring/dot treatment regardless of degeneracy — this catches real-geometry
  // countries that are tiny at the current zoom (e.g. Timor-Leste at 0.18× zoom
  // has a ~2 px diagonal, making its path stroke invisible).
  static const double _kTinyScreenDiag = 30.0;

  bool _isTinyOnScreen(CountryData country) {
    final bb = country.boundingBox;
    final screenDiag =
        math.sqrt(bb.w * bb.w + bb.h * bb.h) * viewScale;
    return screenDiag < _kTinyScreenDiag;
  }

  @override
  bool shouldRepaint(HighlightPainter old) =>
      old.hoveredIso != hoveredIso ||
      old.targetIsoCode != targetIsoCode ||
      (old.viewScale - viewScale).abs() > 0.005 ||
      !identical(old.countryIndex, countryIndex) ||
      old.hintIso != hintIso;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw at the canonical position (x=0..2000) then again for the right
    // copy (x=2000..4000) so rings/hovers are visible after wrapping.
    _paintHighlights(canvas);
    canvas.save();
    canvas.translate(2000, 0);
    _paintHighlights(canvas);
    canvas.restore();
  }

  void _paintHighlights(Canvas canvas) {
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

    // Hint highlight — bright yellow-green, drawn above hover.
    if (hintIso != null && hintIso != hoveredIso) {
      final country = countryIndex[hintIso];
      if (country != null) _drawHintHighlight(canvas, country);
    }
  }

  void _drawTargetRing(Canvas canvas, CountryData country) {
    if (country.isDegenerate || _isTinyOnScreen(country)) {
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
      // Semi-transparent fill first so the actual territory is visually clear.
      // This matters for concave/crescent-shaped countries (e.g. Croatia) where
      // the stroke outline alone encloses neighbouring territory, misleading the
      // player into dropping on the wrong country.
      final fillPaint = Paint()
        ..color = const Color(0x44FF6600)
        ..style = PaintingStyle.fill;
      for (final path in country.paths) {
        canvas.drawPath(path, fillPaint);
      }
      final strokePaint = Paint()
        ..color = const Color(0xFFFF6600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, 2.0 / viewScale);
      for (final path in country.paths) {
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  void _drawHover(Canvas canvas, CountryData country) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    if (country.isDegenerate || _isTinyOnScreen(country)) {
      // Scale-adaptive gold dot — always ~10 screen px radius.
      canvas.drawCircle(country.centroid, _hoverDotRadius, paint);
    } else {
      for (final path in country.paths) {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawHintHighlight(Canvas canvas, CountryData country) {
    final paint = Paint()
      ..color = const Color(0xFFBBFF44)
      ..style = PaintingStyle.fill;
    if (country.isDegenerate || _isTinyOnScreen(country)) {
      canvas.drawCircle(country.centroid, _hoverDotRadius, paint);
    } else {
      for (final path in country.paths) {
        canvas.drawPath(path, paint);
      }
    }
  }
}
