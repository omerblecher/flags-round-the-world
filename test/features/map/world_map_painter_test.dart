import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';
import 'package:flags_around_the_world/features/map/world_map_painter.dart';

CountryData _minimalCountry(String iso) => CountryData(
      isoCode: iso,
      pathStrings: const [],
      paths: const [],
      boundingBox: const BoundingBox(x: 0, y: 0, w: 10, h: 10),
      centroid: Offset.zero,
      isDegenerate: false,
    );

void main() {
  group('WorldMapPainter', () {
    test('MAP-01: shouldRepaint returns false when matchedIsoCodes length unchanged', () {
      final countries = [_minimalCountry('DE'), _minimalCountry('FR')];
      final p1 = WorldMapPainter(
        countries: countries,
        matchedIsoCodes: const {'DE', 'FR'},
      );
      final p2 = WorldMapPainter(
        countries: countries,
        matchedIsoCodes: const {'DE', 'FR'},
      );
      expect(p2.shouldRepaint(p1), isFalse);
    });

    test('MAP-01: shouldRepaint returns true when matchedIsoCodes grows', () {
      final countries = [_minimalCountry('DE'), _minimalCountry('FR')];
      final p1 = WorldMapPainter(
        countries: countries,
        matchedIsoCodes: const {'DE'},
      );
      final p2 = WorldMapPainter(
        countries: countries,
        matchedIsoCodes: const {'DE', 'FR'},
      );
      expect(p2.shouldRepaint(p1), isTrue);
    });
  });
}
