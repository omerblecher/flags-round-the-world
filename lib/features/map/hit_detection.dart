import 'dart:math' show max, sqrt, pi;
import 'dart:ui' show Offset, Rect;

import 'package:flags_around_the_world/core/models/country_data.dart';

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
/// 1. Exact-path candidates: countries whose SVG path contains the point.
/// 2. Bbox-expansion candidates: countries whose scale-aware expanded bbox
///    contains the point (catches drops near tiny/degenerate countries).
/// 3. Fallback: expanded bbox for ALL countries (catches ocean drops near coasts).
/// 4. Tiebreaker: closest *effective centroid* to the drop point.
///    — For candidates with an exact path match, the effective centroid is the
///      bbox centre of the MATCHING POLYGON, not the country centroid.  This
///      correctly handles multi-polygon countries (e.g. Malaysia: country
///      centroid is in Borneo, but a drop on the Peninsula should match
///      Malaysia, not Indonesia whose Sumatra bbox overlaps the region).
///    — For bbox-only candidates (degenerate micro-states), the country
///      centroid is used as before.
String? hitTest(Offset scenePoint, List<CountryData> countries,
    {double scale = 1.0}) {
  final minSceneDiag = _kMinScreenDiagonal / scale;

  // 1 & 2. Collect candidates from exact path OR expanded bbox.
  final candidates = countries
      .where((c) => _primaryContains(c, scenePoint, minSceneDiag, scale: scale))
      .toList();

  // 3. Fallback to expanded bbox for all countries when nothing hit above.
  final pool = candidates.isNotEmpty
      ? candidates
      : countries
          .where((c) => _expandedBbox(c, minSceneDiag, scale: scale).contains(scenePoint))
          .toList();

  if (pool.isEmpty) return null;
  if (pool.length == 1) return pool.first.isoCode;

  // 4. Tiebreaker: closest effective centroid wins.
  pool.sort((a, b) {
    final aDist =
        (_effectiveCentroid(a, scenePoint) - scenePoint).distanceSquared;
    final bDist =
        (_effectiveCentroid(b, scenePoint) - scenePoint).distanceSquared;
    return aDist.compareTo(bDist);
  });

  return pool.first.isoCode;
}

/// For countries that have an exact path containing [point], returns the
/// centre of that polygon's bounding box.  This is a much better proxy for
/// "which country did the user intend" than the country-level centroid when
/// the country has non-contiguous territories (Malaysia, US, etc.).
/// Falls back to [country.centroid] when no path contains the point (i.e.
/// the candidate was added via expanded-bbox expansion).
Offset _effectiveCentroid(CountryData country, Offset point) {
  for (final path in country.paths) {
    if (path.contains(point)) {
      final polyCenter = path.getBounds().center;
      // Prefer the polygon bbox-center only when it's closer to the drop point
      // than the country centroid.  This keeps the multi-polygon advantage
      // (Malaysia Peninsula vs Borneo centroid) while fixing cases where a
      // large single-polygon's bbox center is far from the intended target
      // (Norway mainland bbox center falls deep into Swedish territory).
      final polyDist = (polyCenter - point).distanceSquared;
      final centDist = (country.centroid - point).distanceSquared;
      return polyDist < centDist ? polyCenter : country.centroid;
    }
  }
  return country.centroid;
}

bool _primaryContains(CountryData country, Offset point, double minSceneDiag, {double scale = 1.0}) {
  if (country.paths.any((p) => p.contains(point))) return true;
  return _expandedBbox(country, minSceneDiag, scale: scale).contains(point);
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
