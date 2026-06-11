import 'dart:math' show max, sqrt, pi;
import 'dart:ui' show Offset, Rect;

import 'package:flags_around_the_world/core/models/country_data.dart';

final _svgVertexRe = RegExp(r'[ML]([\d.]+),([\d.]+)');

// Minimum tap target expressed in logical screen pixels.
// At any zoom level, every country is expanded so its on-screen diagonal
// reaches at least this many pixels — making it reliably hittable.
const double _kMinScreenDiagonal = 40.0;

// Minimum on-screen bounding-box area in logical pixels (ACCS-03).
// Any country whose on-screen bbox area falls below this threshold receives
// a centroid-based circular expansion guaranteeing a physical 48dp tap target.
// Value: 48 × 48 = 2304 logical pixels².
const double _kMinScreenArea = 2304.0;

/// Returns the ISO code of the country that the [scenePoint] falls in,
/// or `null` if no country matches.
///
/// [scale] is the current InteractiveViewer scale (scene→screen factor).
///
/// Algorithm:
/// 1. Exact-path pool: countries whose SVG path contains the point, PLUS
///    degenerate micro-states whose expanded bbox contains it (they have no
///    real polygon — a surrounding country's path would otherwise beat them).
/// 2. Bbox-only pool: non-degenerate countries whose expanded bbox contains
///    the point (catches drops near small countries when path is just missed).
/// 3. Fallback: expanded bbox for ALL countries (ocean drops near coasts).
/// 4. Tiebreaker within the chosen pool (exact-path pool always wins over
///    bbox-only pool, preventing a neighbour's close polygon vertex from
///    beating the correct country whose polygon actually contains the drop).
///    — Exact-path hits: min(polygon-bbox-center, country-centroid) distance.
///    — Bbox-only hits: nearest polygon vertex distance.
String? hitTest(Offset scenePoint, List<CountryData> countries,
    {double scale = 1.0}) {
  final minSceneDiag = _kMinScreenDiagonal / scale;

  // 1. Split into exact-path hits and bbox-only hits.
  //    Keeping them separate is the key fix: a country whose polygon contains
  //    the drop point must always beat a neighbour that only qualifies via
  //    expanded bounding box, regardless of vertex distances.  Without this,
  //    the nearest-vertex tiebreaker used for bbox-only hits can beat the
  //    correct country's centroid/bbox-centre distance when the drop is near
  //    the polygon border (observed for Morocco, Chile, Poland, Kazakhstan,
  //    Laos, Hungary, Turkmenistan, …).
  //
  //    Degenerate micro-states (synthetic 4-vertex rectangles for countries
  //    too small to digitise) are promoted into the exact-path pool so that
  //    Singapore, Monaco, etc. can still beat the surrounding country whose
  //    real polygon covers their location.
  final exactHits = <CountryData>[];
  final bboxHits  = <CountryData>[];
  for (final c in countries) {
    if (c.paths.any((p) => p.contains(scenePoint))) {
      exactHits.add(c);
    } else if (_expandedBbox(c, minSceneDiag, scale: scale).contains(scenePoint)) {
      if (c.isDegenerate) {
        exactHits.add(c);
      } else {
        bboxHits.add(c);
      }
    }
  }

  // 2 & 3. Choose pool: exact-path > bbox-only > ocean fallback.
  final List<CountryData> pool;
  if (exactHits.isNotEmpty) {
    pool = exactHits;
  } else if (bboxHits.isNotEmpty) {
    pool = bboxHits;
  } else {
    pool = countries
        .where((c) => _expandedBbox(c, minSceneDiag, scale: scale).contains(scenePoint))
        .toList();
  }

  if (pool.isEmpty) return null;
  if (pool.length == 1) return pool.first.isoCode;

  // 4. Tiebreaker within the chosen pool.
  pool.sort((a, b) {
    final aDist = _tiebreakDistSq(a, scenePoint);
    final bDist = _tiebreakDistSq(b, scenePoint);
    return aDist.compareTo(bDist);
  });

  return pool.first.isoCode;
}

/// Distance-squared metric used to break ties among candidates.
///
/// Exact-path hit: returns min of (polygon-bbox-center, country-centroid)
/// distances squared — handles multi-territory countries (Malaysia, US)
/// while avoiding bbox centers that fall outside the target territory
/// (Norway mainland bbox center lies deep in Swedish territory).
///
/// Bbox-only hit: returns nearest polygon vertex distance squared — avoids
/// penalising large countries whose centroids are far from border cities
/// (e.g. DRC centroid is ~40 scene units from Goma; Rwanda centroid is ~4,
/// but DRC's polygon has a vertex only ~0.3 units from Goma whereas Rwanda's
/// nearest vertex is ~0.9 units away, so DRC correctly wins).
double _tiebreakDistSq(CountryData country, Offset point) {
  for (final path in country.paths) {
    if (path.contains(point)) {
      final polyCenter = path.getBounds().center;
      final polyDist = (polyCenter - point).distanceSquared;
      final centDist = (country.centroid - point).distanceSquared;
      return polyDist < centDist ? polyDist : centDist;
    }
  }
  return _nearestVertexDistSq(country.pathStrings, point);
}

double _nearestVertexDistSq(List<String> pathStrings, Offset point) {
  var minDist = double.infinity;
  for (final s in pathStrings) {
    for (final m in _svgVertexRe.allMatches(s)) {
      final dx = point.dx - double.parse(m.group(1)!);
      final dy = point.dy - double.parse(m.group(2)!);
      final d = dx * dx + dy * dy;
      if (d < minDist) minDist = d;
    }
  }
  return minDist;
}

Rect _expandedBbox(CountryData country, double minSceneDiag, {double scale = 1.0}) {
  final rect = country.boundingBox.rect;

  // Viewport-area threshold (VIS-02 / ACCS-03): if on-screen bbox area is
  // smaller than a 48×48dp square, guarantee a circular expansion of that
  // minimum area regardless of shape or diagonal.
  final screenArea = rect.width * rect.height * scale * scale;
  if (screenArea < _kMinScreenArea) {
    final expansionRadius = sqrt(_kMinScreenArea / pi) / scale;
    return Rect.fromCenter(
      center: country.centroid,
      width: expansionRadius * 2,
      height: expansionRadius * 2,
    );
  }

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
