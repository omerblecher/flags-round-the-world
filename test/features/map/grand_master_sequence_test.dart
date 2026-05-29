import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Grand Master sequence', () {
    setUp(() {
      // Provide the grand_master_order.json asset to the test environment.
      // We use a minimal 5-code list to keep the test fast and deterministic.
      final fakeJson = jsonEncode(['JP', 'US', 'GB', 'FR', 'DE']);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'assets/data/grand_master_order.json') {
            return ByteData.sublistView(utf8.encode(fakeJson) as Uint8List);
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('MODE-05: buildGrandMasterSequence returns all ISO codes', () async {
      final countries = [
        _makeCountry('JP'),
        _makeCountry('US'),
        _makeCountry('GB'),
        _makeCountry('FR'),
        _makeCountry('DE'),
      ];
      final result = await buildGrandMasterSequence(countries);
      expect(result.length, equals(5));
      expect(result.toSet().length, equals(5), reason: 'No duplicates');
      expect(result, containsAll(['JP', 'US', 'GB', 'FR', 'DE']));
    });

    test('MODE-05: sequence has no duplicates', () async {
      final countries = [
        _makeCountry('JP'),
        _makeCountry('US'),
        _makeCountry('GB'),
        _makeCountry('FR'),
        _makeCountry('DE'),
      ];
      final result = await buildGrandMasterSequence(countries);
      final seen = <String>{};
      for (final iso in result) {
        expect(seen.contains(iso), isFalse,
            reason: 'ISO $iso must not appear twice');
        seen.add(iso);
      }
    });
  });
}
