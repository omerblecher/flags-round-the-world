import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';
import 'package:flags_around_the_world/core/data/country_data_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('CountryData.fromJson', () {
    test('parses a well-formed entry', () {
      final json = {
        'iso': 'de',
        'paths': ['M0,0 L10,0 Z'],
        'boundingBox': {'x': 0.0, 'y': 0.0, 'w': 10.0, 'h': 10.0},
        'centroid': {'x': 5.0, 'y': 5.0},
      };
      final country = CountryData.fromJson(json);
      expect(country.isoCode, 'de');
      expect(country.pathStrings.length, 1);
      expect(country.paths.length, 1);
      expect(country.boundingBox.w, 10.0);
      expect(country.centroid.dx, 5.0);
    });
  });

  group('path_drawing parseSvgPathData', () {
    test('returns a non-empty Path for a valid M/L/Z string', () {
      final path = parseSvgPathData('M0,0 L10,0 L10,10 Z');
      expect(path, isA<dynamic>());
      final metrics = path.computeMetrics().toList();
      expect(metrics, isNotEmpty);
    });
  });

  group('CountryDataService.loadMapData', () {
    test('returns 196 entries with valid ISO codes, paths, and bounding boxes',
        () async {
      final service = CountryDataService();
      final countries = await service.loadMapData();

      expect(countries.length, 196);
      for (final c in countries) {
        expect(c.isoCode.length, 2);
        expect(c.pathStrings, isNotEmpty);
        expect(c.boundingBox.w, greaterThan(0));
        expect(c.boundingBox.h, greaterThan(0));
      }
      final isos = {for (final c in countries) c.isoCode};
      expect(isos.contains('xk'), isTrue, reason: 'Kosovo must be present');
      expect(isos.contains('tw'), isTrue, reason: 'Taiwan must be present');
    });
  });
}
