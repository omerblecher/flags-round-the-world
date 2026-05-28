import 'dart:math' show sqrt;
import 'dart:ui' show Offset, Rect;

import 'package:flags_around_the_world/core/models/country_data.dart';

// Minimum tap target expressed in logical screen pixels.
// At any zoom level, every country is expanded so its on-screen diagonal
// reaches at least this many pixels — making it reliably hittable.
const double _kMinScreenDiagonal = 40.0;

/// Returns the ISO code of the country that the [scenePoint] falls in,
/// or `null` if no country matches.
///
/// [scale] is the current InteractiveViewer scale (scene→screen factor).
/// It converts the fixed screen-pixel minimum into scene units so that every
/// country presents the same tap-target size regardless of zoom level.
///
/// Algorithm:
/// 1. Primary pass: exact path hit, or scale-aware expanded bbox when the
///    country's on-screen diagonal would be below [_kMinScreenDiagonal] px.
/// 2. Fallback pass: same scale-aware expanded bbox for all countries (catches
///    drops that land in ocean but close to a coast).
/// 3. Tiebreaker: smallest bounding-box area wins (most specific country).
String? hitTest(Offset scenePoint, List<CountryData> countries, {double scale = 1.0}) {
  // Minimum bbox diagonal in scene units for the current zoom level.
  final minSceneDiag = _kMinScreenDiagonal / scale;

  // 1. Primary: exact path OR scale-aware expanded bbox.
  final primary = countries
      .where((c) => _primaryContains(c, scenePoint, minSceneDiag))
      .toList();

  final candidates = primary.isNotEmpty
      ? primary
      // 2. Fallback: scale-aware expanded bbox for all countries.
      : countries
          .where((c) => _expandedBbox(c, minSceneDiag).contains(scenePoint))
          .toList();

  if (candidates.isEmpty) return null;

  // 3. Tiebreaker: smallest bbox area (prefers small/precise countries).
  candidates.sort((a, b) {
    final aArea = a.boundingBox.rect.width * a.boundingBox.rect.height;
    final bArea = b.boundingBox.rect.width * b.boundingBox.rect.height;
    return aArea.compareTo(bArea);
  });

  return candidates.first.isoCode;
}

/// Returns true if [point] is inside [country] in the primary pass.
/// A country qualifies if the exact path contains the point, OR if the
/// country's on-screen bbox is below the [minSceneDiag] threshold and the
/// expanded bbox contains the point.
bool _primaryContains(CountryData country, Offset point, double minSceneDiag) {
  if (country.paths.any((p) => p.contains(point))) return true;
  return _expandedBbox(country, minSceneDiag).contains(point);
}

/// Returns the bounding box for [country], expanded if necessary so its
/// diagonal reaches [minSceneDiag] scene units.
///
/// Expansion is centred on the country centroid and preserves the aspect
/// ratio of the original bbox. Degenerate (near-zero) bboxes receive a
/// [minSceneDiag]-square centred on the centroid.
Rect _expandedBbox(CountryData country, double minSceneDiag) {
  final rect = country.boundingBox.rect;
  final diagonal = sqrt(rect.width * rect.width + rect.height * rect.height);
  if (diagonal < 1e-6) {
    return Rect.fromCenter(
      center: country.centroid,
      width: minSceneDiag,
      height: minSceneDiag,
    );
  }
  if (diagonal >= minSceneDiag) return rect;
  final scaleFactor = minSceneDiag / diagonal;
  return Rect.fromCenter(
    center: country.centroid,
    width: rect.width * scaleFactor,
    height: rect.height * scaleFactor,
  );
}
