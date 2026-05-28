/// Comprehensive per-country test: hit detection, flag assets, degenerate
/// rendering, and centroid validity for all 196 countries.
library;

import 'dart:io';
import 'dart:math' show sqrt;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flags_around_the_world/core/data/country_data_service.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';
import 'package:flags_around_the_world/features/map/hit_detection.dart';

void main() {
  late List<CountryData> countries;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    countries = await CountryDataService().loadMapData();
  });

  // ---------------------------------------------------------------------------
  // 1. Data integrity
  // ---------------------------------------------------------------------------

  group('data integrity — all 196 countries', () {
    test('exactly 196 countries loaded', () {
      expect(countries.length, 196);
    });

    test('no duplicate ISO codes', () {
      final isos = countries.map((c) => c.isoCode).toList();
      final unique = isos.toSet();
      expect(unique.length, equals(isos.length),
          reason: 'duplicate ISOs: ${isos..removeWhere(unique.remove)}');
    });

    test('every country has a non-empty path', () {
      for (final c in countries) {
        expect(c.pathStrings, isNotEmpty,
            reason: '${c.isoCode} has no paths');
        expect(c.paths, isNotEmpty,
            reason: '${c.isoCode} has no parsed paths');
      }
    });

    test('every bounding box has positive width and height', () {
      for (final c in countries) {
        expect(c.boundingBox.w, greaterThan(0),
            reason: '${c.isoCode} bbox w=${c.boundingBox.w}');
        expect(c.boundingBox.h, greaterThan(0),
            reason: '${c.isoCode} bbox h=${c.boundingBox.h}');
      }
    });

    test('every centroid is within the 2000×1000 canvas', () {
      for (final c in countries) {
        expect(c.centroid.dx, inInclusiveRange(0.0, 2000.0),
            reason: '${c.isoCode} centroid.x=${c.centroid.dx} out of range');
        expect(c.centroid.dy, inInclusiveRange(0.0, 1000.0),
            reason: '${c.isoCode} centroid.y=${c.centroid.dy} out of range');
      }
    });

    test('centroid lies within or very close to bounding box', () {
      for (final c in countries) {
        final bb = c.boundingBox.rect.inflate(20);
        expect(bb.contains(c.centroid), isTrue,
            reason:
                '${c.isoCode} centroid (${c.centroid}) is outside inflated bbox $bb');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Flag SVG assets
  // ---------------------------------------------------------------------------

  group('flag SVG assets', () {
    test('flag file exists for every country', () {
      for (final c in countries) {
        final path =
            'assets/flags/${c.isoCode.toLowerCase()}.svg';
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: 'missing flag: $path');
      }
    });

    test('no flag file is empty', () {
      for (final c in countries) {
        final file =
            File('assets/flags/${c.isoCode.toLowerCase()}.svg');
        if (file.existsSync()) {
          expect(file.lengthSync(), greaterThan(0),
              reason: '${c.isoCode}.svg is empty');
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Hit detection — centroid drop at various zoom scales
  // ---------------------------------------------------------------------------

  group('hit detection — centroid drop', () {
    const scales = [0.18, 0.5, 1.0, 2.0, 4.0];

    for (final scale in scales) {
      test('all 196 centroids hit their own country at scale $scale', () {
        final failures = <String>[];
        for (final c in countries) {
          final hit = hitTest(c.centroid, countries, scale: scale);
          if (hit != c.isoCode) {
            failures.add('${c.isoCode}: got $hit at scale $scale');
          }
        }
        expect(failures, isEmpty,
            reason: 'centroid-drop failures:\n${failures.join('\n')}');
      });
    }

    test('degenerate-country centroids hit correctly at low zoom (0.18)', () {
      final degenerate = countries.where((c) => c.isDegenerate).toList();
      expect(degenerate, isNotEmpty, reason: 'expected some degenerate countries');
      final failures = <String>[];
      for (final c in degenerate) {
        final hit = hitTest(c.centroid, countries, scale: 0.18);
        if (hit != c.isoCode) {
          failures.add('${c.isoCode}: got $hit (degenerate at low zoom)');
        }
      }
      expect(failures, isEmpty,
          reason: 'degenerate hit failures:\n${failures.join('\n')}');
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Degenerate countries
  // ---------------------------------------------------------------------------

  group('degenerate countries', () {
    test('degenerate flag correctly set on known tiny nations', () {
      const expectedDegenerate = ['ad', 'mv', 'sm', 'va', 'li', 'mc', 'sg'];
      for (final iso in expectedDegenerate) {
        final c = countries.firstWhere((x) => x.isoCode == iso,
            orElse: () => throw TestFailure('$iso not in countries list'));
        expect(c.isDegenerate, isTrue,
            reason: '$iso should be degenerate');
      }
    });

    test('non-degenerate countries with large bboxes are not flagged degenerate',
        () {
      const expectedNormal = ['us', 'ru', 'cn', 'br', 'au', 'in', 'fr', 'de'];
      for (final iso in expectedNormal) {
        final c = countries.firstWhere((x) => x.isoCode == iso,
            orElse: () => throw TestFailure('$iso not in countries list'));
        expect(c.isDegenerate, isFalse,
            reason: '$iso should NOT be degenerate');
      }
    });

    test('degenerate centroid is inside or near its 8×8 bbox', () {
      for (final c in countries.where((c) => c.isDegenerate)) {
        final bb = c.boundingBox.rect.inflate(5);
        expect(bb.contains(c.centroid), isTrue,
            reason: '${c.isoCode} degenerate centroid outside inflated bbox');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Bounding-box expansion sanity
  // ---------------------------------------------------------------------------

  group('bbox expansion sanity', () {
    test('all countries produce a valid (non-NaN, non-infinite) expanded bbox', () {
      for (final c in countries) {
        final bb = c.boundingBox;
        final diag = sqrt(bb.w * bb.w + bb.h * bb.h);
        // Simulate _expandedBbox logic
        if (diag < 1e-6) {
          // Would use minSceneDiag square — not NaN
        } else if (diag < 40.0) {
          final sf = 40.0 / diag;
          final ew = bb.w * sf;
          final eh = bb.h * sf;
          expect(ew.isNaN, isFalse, reason: '${c.isoCode} expanded w is NaN');
          expect(ew.isInfinite, isFalse,
              reason: '${c.isoCode} expanded w is Infinite');
          expect(eh.isNaN, isFalse, reason: '${c.isoCode} expanded h is NaN');
          expect(eh.isInfinite, isFalse,
              reason: '${c.isoCode} expanded h is Infinite');
        }
      }
    });
  });
}
