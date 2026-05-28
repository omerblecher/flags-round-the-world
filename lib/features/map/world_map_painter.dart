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

const double _kDotRadius = 5.0; // scene units for degenerate-path dot markers

const _matchedColor = Color(0xFFAAAAAA); // grey for already-matched countries
const _oceanColor   = Color(0xFFA8D5E8); // light blue background
const _borderColor  = Color(0xFF555555); // dark country borders
const _labelColor   = Color(0xFFFFFFFF); // white centroid labels

class WorldMapPainter extends CustomPainter {
  const WorldMapPainter({
    required this.countries,
    required this.matchedIsoCodes,
  });

  final List<CountryData> countries;
  final Set<String> matchedIsoCodes;

  @override
  bool shouldRepaint(WorldMapPainter old) =>
      !setEquals(old.matchedIsoCodes, matchedIsoCodes);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background (ocean)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _oceanColor,
    );

    final fillPaint  = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..color       = _borderColor
      ..strokeWidth = 1.2;

    // 2 & 3. Fills + borders
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

    // 4. Centroid labels
    for (final country in countries) {
      _drawLabel(canvas, country.isoCode, country.centroid);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset centroid) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 7.0,
          color: _labelColor,
          shadows: [
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

    canvas.save();
    tp.paint(
      canvas,
      centroid - Offset(tp.width / 2, tp.height / 2),
    );
    canvas.restore();
  }
}
