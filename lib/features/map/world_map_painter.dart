import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';

/// Atlas palette — one fill color per "continent bucket" cycling by list index.
const _palette = [
  Color(0xFF8DB87F), // Europe  — soft green
  Color(0xFFD4B483), // Asia    — tan
  Color(0xFFE8A055), // Africa  — orange
  Color(0xFFE89090), // Americas — pink
  Color(0xFFA07EC8), // Oceania  — purple
  Color(0xFFE8D870), // Antarctica / other — light yellow
];

// Base screen-pixel radius for micro-state dots.  Divided by viewScale so
// dots stay ~4 screen-pixels wide at any zoom — small enough not to overlap
// in dense areas (Europe) but still visible and hittable.
const double _kDotScreenRadius = 4.0;

const _matchedColor = Color(0xFFAAAAAA); // grey for already-matched countries
const _oceanColor   = Color(0xFFA8D5E8); // light blue background
const _borderColor  = Color(0xFF555555); // dark country borders

class WorldMapPainter extends CustomPainter {
  const WorldMapPainter({
    required this.countries,
    required this.matchedIsoCodes,
    this.showLabels = true,
    this.countryNames = const {},
    this.viewScale = 1.0,
  });

  final List<CountryData> countries;
  final Set<String> matchedIsoCodes;
  final bool showLabels;
  final Map<String, String> countryNames;
  final double viewScale;

  @override
  bool shouldRepaint(WorldMapPainter old) =>
      !setEquals(old.matchedIsoCodes, matchedIsoCodes) ||
      old.showLabels != showLabels ||
      !identical(old.countryNames, countryNames) ||
      old.viewScale != viewScale;

  @override
  void paint(Canvas canvas, Size size) {
    // Background covers the full doubled canvas (ocean behind both copies).
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _oceanColor,
    );

    // Draw the canonical world (x = 0..2000) then a right-hand copy
    // (x = 2000..4000) so the player can pan past the date line to the Americas.
    _drawWorldCopy(canvas);
    canvas.save();
    canvas.translate(2000, 0);
    _drawWorldCopy(canvas);
    canvas.restore();
  }

  void _drawWorldCopy(Canvas canvas) {
    final fillPaint  = Paint()..style = PaintingStyle.fill;
    // Stroke width in scene units = 1.0 / viewScale keeps borders at ~1 screen
    // pixel regardless of zoom, so tiny countries (Luxembourg, Bahamas) never
    // have borders that visually swamp their fill area.
    final borderPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..color       = _borderColor
      ..strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2);

    // Pass 1: all non-degenerate country fills + borders.
    for (int i = 0; i < countries.length; i++) {
      final country = countries[i];
      if (country.isDegenerate) continue;
      final isMatched = matchedIsoCodes.contains(country.isoCode);
      fillPaint.color = isMatched ? _matchedColor : _palette[i % _palette.length];
      for (final path in country.paths) {
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, borderPaint);
      }
    }

    // Pass 2: degenerate micro-state dots — fixed screen-pixel radius.
    final dotRadius = (_kDotScreenRadius / viewScale).clamp(1.0, 5.0);
    for (int i = 0; i < countries.length; i++) {
      final country = countries[i];
      if (!country.isDegenerate) continue;
      final isMatched = matchedIsoCodes.contains(country.isoCode);
      fillPaint.color = isMatched ? _matchedColor : _palette[i % _palette.length];
      canvas.drawCircle(country.centroid, dotRadius, fillPaint);
      canvas.drawCircle(country.centroid, dotRadius, borderPaint);
    }

    // Centroid labels with collision detection.
    // Larger countries are drawn first and take priority; small/dense regions
    // (Europe, Caribbean, Middle East) only show labels when there is room.
    if (showLabels) {
      final drawnRects = <Rect>[];
      final sorted = [...countries]..sort((a, b) {
          final ra = a.boundingBox.rect;
          final rb = b.boundingBox.rect;
          final da = sqrt(ra.width * ra.width + ra.height * ra.height);
          final db = sqrt(rb.width * rb.width + rb.height * rb.height);
          return db.compareTo(da);
        });
      for (final country in sorted) {
        _drawLabel(
          canvas,
          countryNames[country.isoCode] ?? country.isoCode,
          country.centroid,
          country,
          drawnRects,
        );
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset centroid,
      CountryData country, List<Rect> drawnRects) {
    final r = country.boundingBox.rect;
    final diagonal = sqrt(r.width * r.width + r.height * r.height);

    // Google Maps-style: labels appear based on how large the country is
    // ON SCREEN (diagonal × viewScale), not on viewScale alone.
    // This ensures small European countries only appear when zoomed in while
    // Russia/Canada/Brazil are always readable even at world zoom.
    final onScreen = diagonal * viewScale;
    final double opacity;
    if (diagonal < 20.0) {
      // Micro-state dot: show name when dot is ≥ 50 screen-px across (≈ zoom 5×)
      opacity = ((onScreen - 50.0) / 15.0).clamp(0.0, 1.0);
    } else if (diagonal < 70.0) {
      // Small country (Israel, Jordan, Austria…): appear at ≥ 60 screen-px
      opacity = ((onScreen - 60.0) / 20.0).clamp(0.0, 1.0);
    } else if (diagonal < 250.0) {
      // Medium country (France, Germany, Japan…): appear at ≥ 40 screen-px
      opacity = ((onScreen - 40.0) / 20.0).clamp(0.0, 1.0);
    } else {
      // Large country (Russia, Canada, USA, Brazil…): appear at ≥ 25 screen-px
      opacity = ((onScreen - 25.0) / 15.0).clamp(0.0, 1.0);
    }
    if (opacity <= 0.0) return;

    // Fixed screen-pixel font size (÷ viewScale converts to scene units).
    // Slightly larger for continent-sized countries, matching Google Maps
    // where country-name text is visually heavier than province text.
    final screenFontSize = diagonal > 250 ? 12.0 : 11.0;
    final fontSize = screenFontSize / viewScale;

    final labelAlpha = (opacity * 255).round();
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: diagonal > 250 ? FontWeight.w600 : FontWeight.normal,
          color: Color.fromARGB(labelAlpha, 0xFF, 0xFF, 0xFF),
          shadows: const [
            Shadow(
              color: Color(0xFF000000),
              blurRadius: 2,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final origin = centroid - Offset(tp.width / 2, tp.height / 2);
    final labelRect = Rect.fromLTWH(
      origin.dx - 1,
      origin.dy - 1,
      tp.width + 2,
      tp.height + 2,
    );

    // Skip drawing if another label already occupies this space.
    if (drawnRects.any((r) => r.overlaps(labelRect))) return;
    drawnRects.add(labelRect);

    canvas.save();
    tp.paint(canvas, origin);
    canvas.restore();
  }
}
