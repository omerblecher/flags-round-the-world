import 'dart:math' show max, sqrt;
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
///
/// Algorithm:
/// 1. Exact-path candidates: countries whose SVG path contains the point.
/// 2. Bbox-expansion candidates: countries whose scale-aware expanded bbox
///    contains the point (catches drops near tiny/degenerate countries).
/// 3. Fallback: expanded bbox for ALL countries (catches ocean drops near coasts).
/// 4. Tiebreaker: closest centroid to the drop point.
///    — This correctly handles all overlap cases: degenerate countries at low
///      zoom, border drops, and island nations in open ocean.
String? hitTest(Offset scenePoint, List<CountryData> countries,
    {double scale = 1.0}) {
  final minSceneDiag = _kMinScreenDiagonal / scale;

  // 1 & 2. Collect candidates from exact path OR expanded bbox.
  final candidates = countries
      .where((c) => _primaryContains(c, scenePoint, minSceneDiag))
      .toList();

  // 3. Fallback to expanded bbox for all countries when nothing hit above.
  final pool = candidates.isNotEmpty
      ? candidates
      : countries
          .where((c) => _expandedBbox(c, minSceneDiag).contains(scenePoint))
          .toList();

  if (pool.isEmpty) return null;
  if (pool.length == 1) return pool.first.isoCode;

  // 4. Tiebreaker: closest centroid wins.
  //    Rationale: the country whose centroid is nearest to the drop point is
  //    the most "intended" target, regardless of whether the hit came via exact
  //    path or expanded bbox. This correctly handles:
  //    - Degenerate countries whose 222×222-scene-unit expanded bboxes (at 0.18x
  //      zoom) would otherwise swallow the centroids of neighbouring countries.
  //    - Micro-states (San Marino inside Italy's path) — centroid distance 0.
  //    - Borders — nearest centroid is the more specific country.
  pool.sort((a, b) {
    final aDist = (a.centroid - scenePoint).distanceSquared;
    final bDist = (b.centroid - scenePoint).distanceSquared;
    return aDist.compareTo(bDist);
  });

  return pool.first.isoCode;
}

bool _primaryContains(CountryData country, Offset point, double minSceneDiag) {
  if (country.paths.any((p) => p.contains(point))) return true;
  return _expandedBbox(country, minSceneDiag).contains(point);
}

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
  // Degenerate countries (synthetic bbox rectangles placed by the SVG pipeline
  // for micro-states like Singapore) have a neighbouring country's path that
  // overlaps their tiny rect.  A drop just outside the rect must still register
  // — e.g. Malaysia's peninsular path contains Singapore's location.
  // Using max(minSceneDiag, diagonal×2) gives a consistent expansion zone
  // (≈ one rect-width of padding in each direction) at any zoom level.
  final effectiveMin =
      country.isDegenerate ? max(minSceneDiag, diagonal * 2.0) : minSceneDiag;
  if (diagonal >= effectiveMin) return rect;
  final scaleFactor = effectiveMin / diagonal;
  return Rect.fromCenter(
    center: country.centroid,
    width: rect.width * scaleFactor,
    height: rect.height * scaleFactor,
  );
}
