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
  });
}
