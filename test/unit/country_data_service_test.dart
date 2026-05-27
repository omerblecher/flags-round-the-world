import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flags_around_the_world/core/data/country_data_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('CountryDataService.loadCountryNames', () {
    late CountryDataService service;

    setUp(() {
      service = CountryDataService();
    });

    test('loadCountryNames English — 196 entries, spot-check values', () async {
      final names = await service.loadCountryNames(const Locale('en'));
      expect(names.length, 196);
      expect(names.values.every((v) => v.isNotEmpty), isTrue);
      expect(names['de'], 'Germany');
      expect(names['xk'], 'Kosovo');
      expect(names['tw'], 'Taiwan');
    });

    test('loadCountryNames Spanish — 196 entries with Spanish names', () async {
      final names = await service.loadCountryNames(const Locale('es'));
      expect(names.length, 196);
      expect(names.containsKey('de'), isTrue);
      expect(names['de'], isNot('Germany'),
          reason: 'Spanish name for Germany should not be "Germany"');
      expect(names.containsKey('xk'), isTrue);
    });

    test('loadCountryNames unknown locale falls back to English (I18N-03)',
        () async {
      // countries_de.json does not exist — service must silently fall back
      final names = await service.loadCountryNames(const Locale('de'));
      expect(names.length, 196,
          reason: 'English fallback must return all 196 entries');
      expect(names['de'], 'Germany',
          reason: 'German locale falls back to English name for DE');
    });

    test('English and Spanish key sets are identical', () async {
      final en = await service.loadCountryNames(const Locale('en'));
      final es = await service.loadCountryNames(const Locale('es'));
      expect(en.keys.toSet(), equals(es.keys.toSet()));
    });
  });
}
