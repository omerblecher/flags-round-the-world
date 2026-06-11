import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flags_around_the_world/features/map/hit_detection.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CountryData _makeCountry({
  required String iso,
  required Rect pathRect,
  required Offset centroid,
}) {
  final path = Path()..addRect(pathRect);
  final bbox = BoundingBox(
    x: pathRect.left,
    y: pathRect.top,
    w: pathRect.width,
    h: pathRect.height,
  );
  return CountryData(
    isoCode: iso,
    pathStrings: const [],
    paths: [path],
    boundingBox: bbox,
    centroid: centroid,
    isDegenerate: false,
  );
}

CountryData _makeDegenerate({
  required String iso,
  required Rect pathRect,
  required Offset centroid,
}) {
  final path = Path()..addRect(pathRect);
  final bbox = BoundingBox(
    x: pathRect.left,
    y: pathRect.top,
    w: pathRect.width,
    h: pathRect.height,
  );
  // pathStrings must include the rect corners so _nearestVertexDistSq works
  // in the tiebreaker when the drop is outside the exact path.
  final pathStr = 'M${pathRect.left},${pathRect.top} '
      'L${pathRect.right},${pathRect.top} '
      'L${pathRect.right},${pathRect.bottom} '
      'L${pathRect.left},${pathRect.bottom} Z';
  return CountryData(
    isoCode: iso,
    pathStrings: [pathStr],
    paths: [path],
    boundingBox: bbox,
    centroid: centroid,
    isDegenerate: true,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('hit detection', () {
    test('GAME-01: exact path hit returns correct isoCode', () {
      final country = _makeCountry(
        iso: 'DE',
        pathRect: Rect.fromLTWH(100, 100, 200, 200),
        centroid: const Offset(200, 200),
      );

      final result = hitTest(const Offset(150, 150), [country]);
      expect(result, equals('DE'));
    });

    test('GAME-01: miss returns null when scenePoint outside all countries', () {
      final country = _makeCountry(
        iso: 'DE',
        pathRect: Rect.fromLTWH(100, 100, 200, 200),
        centroid: const Offset(200, 200),
      );

      final result = hitTest(const Offset(500, 500), [country]);
      expect(result, isNull);
    });

    test('GAME-02: bbox expansion hit for LU (Luxembourg bbox diagonal < 32 units)', () {
      // 3×3 rect — diagonal ≈ 4.24 units, well below _kMinBboxDiagonal=32.
      const pathRect = Rect.fromLTWH(100, 100, 3, 3);
      final country = _makeCountry(
        iso: 'LU',
        pathRect: pathRect,
        centroid: const Offset(101.5, 101.5), // centre of the 3×3 rect
      );

      // (110, 110) is outside the 3×3 path but should be inside the
      // expanded ~32-unit bbox centred on (101.5, 101.5).
      final result = hitTest(const Offset(110, 110), [country]);
      expect(result, equals('LU'));
    });

    test('GAME-02: small country exact-path hit beats large neighbour exact-path hit (MK-class)', () {
      // Micro-state: tiny 3×3 path — both MK and GR contain the drop point via
      // exact path.  exactHits pool is [MK, GR]; tiebreaker picks MK because its
      // poly-bbox-centre is much closer to the drop (≈0.71 units) than GR's (≈69).
      final mk = _makeCountry(
        iso: 'MK',
        pathRect: Rect.fromLTWH(100, 100, 3, 3),
        centroid: const Offset(101.5, 101.5),
      );

      // Large neighbour — its path also contains (101, 101).
      final large = _makeCountry(
        iso: 'GR',
        pathRect: Rect.fromLTWH(50, 50, 200, 200),
        centroid: const Offset(150, 150),
      );

      // (101, 101) is inside BOTH MK's 3×3 exact path and GR's large path.
      // Both are in exactHits; MK wins via poly-bbox-centre proximity.
      final result = hitTest(const Offset(101, 101), [mk, large]);
      expect(result, equals('MK'));
    });

    test('GAME-02: smallest-bbox tiebreaker selects more specific country on border', () {
      // SM: tiny 2×2 path — both path and expanded bbox contain (201, 201).
      final sm = _makeCountry(
        iso: 'SM',
        pathRect: Rect.fromLTWH(200, 200, 2, 2),
        centroid: const Offset(201, 201),
      );

      // IT: large 200×200 path — also contains (201, 201) via primary pass.
      final it = _makeCountry(
        iso: 'IT',
        pathRect: Rect.fromLTWH(100, 100, 200, 200),
        centroid: const Offset(200, 200),
      );

      // Both match via primary check; SM has smaller bbox area (4 vs 40 000).
      final result = hitTest(const Offset(201, 201), [sm, it]);
      expect(result, equals('SM'));
    });

    test('GAME-02: degenerate micro-state wins at medium zoom when drop is just '
        'outside its rect but inside neighbour path (Singapore/Malaysia scenario)', () {
      // SG: 8.33×8.33 degenerate synthetic rect — diagonal ≈ 11.78 scene units.
      const sgRect = Rect.fromLTWH(1572.5, 488.61, 8.33, 8.33);
      final sg = _makeDegenerate(
        iso: 'sg',
        pathRect: sgRect,
        centroid: const Offset(1576.67, 492.78),
      );

      // MY: large rect whose path overlaps Singapore's area (Peninsular Malaysia).
      final my = _makeCountry(
        iso: 'my',
        pathRect: const Rect.fromLTWH(1556.0, 461.5, 106.0, 34.2),
        centroid: const Offset(1636.15, 480.38),
      );

      // Drop 3 units north of SG rect top (y=488.61 → y=485.61).
      // At scale=3: minSceneDiag=13.3 < diagonal=11.78 would normally skip
      // expansion, leaving SG out of candidates. The degenerate fix uses
      // effectiveMin = diagonal*2 = 23.56 → SG is a candidate and wins.
      const dropPoint = Offset(1576.67, 485.61);
      final result = hitTest(dropPoint, [sg, my], scale: 3.0);
      expect(result, equals('sg'));
    });
  });
}
