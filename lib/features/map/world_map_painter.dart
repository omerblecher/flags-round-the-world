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

const double _kDotRadius = 8.0; // scene units for degenerate-path dot markers (micro-states)

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
    final borderPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..color       = _borderColor
      ..strokeWidth = 1.2;

    // Fills + borders
    for (int i = 0; i < countries.length; i++) {
      final country = countries[i];
      final isMatched = matchedIsoCodes.contains(country.isoCode);
      fillPaint.color = isMatched ? _matchedColor : _palette[i % _palette.length];

      if (country.isDegenerate) {
        // SVG pipeline stored a 4-vertex bbox rectangle — draw a dot marker
        // at the centroid so it looks like a map pin, not a weird square.
        canvas.drawCircle(country.centroid, _kDotRadius, fillPaint);
        canvas.drawCircle(country.centroid, _kDotRadius, borderPaint);
      } else {
        for (final path in country.paths) {
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, borderPaint);
        }
      }
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
    // Compute bbox diagonal in scene units for opacity decision (D-V01).
    final r = country.boundingBox.rect;
    final diagonal = sqrt(r.width * r.width + r.height * r.height);

    // Opacity rules (D-V01):
    //   micro-state  (diagonal < 30):  fade in above 2.5×
    //   small country (diagonal < 100): fade in above 1.5×
    //   large country:                 always 1.0
    final double opacity;
    if (diagonal < 30.0) {
      opacity = ((viewScale - 2.5) / 1.0).clamp(0.0, 1.0);
    } else if (diagonal < 100.0) {
      opacity = ((viewScale - 1.5) / 1.0).clamp(0.0, 1.0);
    } else {
      opacity = 1.0;
    }
    if (opacity <= 0.0) return; // Skip drawing — avoids invisible TextPainter cost

    final labelAlpha = (opacity * 255).round();
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 7.0,
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
