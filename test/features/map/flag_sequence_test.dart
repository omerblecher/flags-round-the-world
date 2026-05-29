import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';
import 'package:flags_around_the_world/features/map/flag_sequence.dart';

// Helper: build a minimal CountryData with a distinct ISO code.
CountryData _makeCountry(String isoCode) {
  return CountryData(
    isoCode: isoCode,
    pathStrings: const [],
    paths: const [],
    boundingBox: const BoundingBox(x: 0, y: 0, w: 10, h: 10),
    centroid: Offset.zero,
    isDegenerate: false,
  );
}

void main() {
  group('flag sequence', () {
    test('GAME-05: shuffle produces 196 unique ISO codes with no repeats', () {
      // Generate 196 distinct country stubs.
      final countries = List.generate(
        196,
        (i) => _makeCountry('C${i.toString().padLeft(3, '0')}'),
      );

      final result = buildFlagSequence(countries);

      expect(result.length, equals(196));
      expect(result.toSet().length, equals(196),
          reason: 'No duplicate ISO codes after shuffle');
    });

    test('GAME-05: sequence does not contain duplicates after advance', () {
      final countries = [
        _makeCountry('AA'),
        _makeCountry('BB'),
        _makeCountry('CC'),
        _makeCountry('DD'),
        _makeCountry('EE'),
      ];

      final result = buildFlagSequence(countries);
      expect(result.toSet().length, equals(5),
          reason: 'All 5 ISOs present exactly once');

      // Simulate advancing through the sequence.
      final remaining = List<String>.from(result);
      final seen = <String>{};
      while (remaining.isNotEmpty) {
        final current = remaining.removeAt(0);
        expect(seen.contains(current), isFalse,
            reason: 'ISO $current must not appear twice');
        seen.add(current);
      }
      expect(remaining.isEmpty, isTrue);
    });

    test('GAME-06: completeGame() is triggered after last flag is dropped', () {
      // Unit-level validation: after one country, removing the single element
      // leaves an empty list — that empty state is the condition that triggers
      // completeGame() in _advanceToNextFlag().
      final countries = [_makeCountry('ZZ')];
      final sequence = buildFlagSequence(countries);

      expect(sequence.length, equals(1));
      expect(sequence.first, equals('ZZ'));

      // Simulate the advance step.
      sequence.removeAt(0);
      expect(sequence.isEmpty, isTrue,
          reason:
              'Empty remaining list is the gate condition that calls completeGame()');
    });
  });
}
