import 'dart:math' show sqrt;
import 'dart:ui' show Offset, Rect;

import 'package:flags_around_the_world/core/models/country_data.dart';

const double _kMinBboxDiagonal = 32.0;

/// Returns the ISO code of the country that the [scenePoint] falls in,
/// or `null` if no country matches.
///
/// Algorithm:
/// 1. Primary pass: exact path hit-test via [Path.contains].
/// 2. Fallback pass: expanded bounding-box test for micro-states.
/// 3. Tiebreaker: smallest bounding-box area wins (most specific country).
String? hitTest(Offset scenePoint, List<CountryData> countries) {
  // 1. Primary: collect countries whose path geometries contain the point.
  final primary = countries
      .where((c) => c.paths.any((p) => p.contains(scenePoint)))
      .toList();

  final candidates = primary.isNotEmpty
      ? primary
      // 2. Fallback: expanded bbox for micro-states.
      : countries
          .where((c) => _expandedBbox(c).contains(scenePoint))
          .toList();

  if (candidates.isEmpty) return null;

  // 3. Tiebreaker: smallest bbox area.
  candidates.sort((a, b) {
    final aArea = a.boundingBox.rect.width * a.boundingBox.rect.height;
    final bArea = b.boundingBox.rect.width * b.boundingBox.rect.height;
    return aArea.compareTo(bArea);
  });

  return candidates.first.isoCode;
}

/// Returns an expanded bounding box for [country].
///
/// If the country's bbox diagonal is already >= [_kMinBboxDiagonal], the
/// original rect is returned unchanged. Otherwise it is scaled up (centred
/// on the country centroid) so that the diagonal reaches [_kMinBboxDiagonal].
Rect _expandedBbox(CountryData country) {
  final rect = country.boundingBox.rect;
  final diagonal = sqrt(rect.width * rect.width + rect.height * rect.height);
  if (diagonal >= _kMinBboxDiagonal) return rect;

  final scaleFactor = _kMinBboxDiagonal / diagonal;
  return Rect.fromCenter(
    center: country.centroid,
    width: rect.width * scaleFactor,
    height: rect.height * scaleFactor,
  );
}
