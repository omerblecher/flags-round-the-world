import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/country_data.dart';

class CountryDataService {
  Future<List<CountryData>> loadMapData() async {
    final jsonString = await rootBundle.loadString('assets/map/world_map_paths.json');

    // Decode JSON in a background isolate — 147k chars of SVG path data
    // is slow on the main thread and blocks the loading indicator from rendering.
    final rawEntries = await compute(_decodeJson, jsonString);

    // dart:ui Path objects must be created on the main thread.
    // Yield every 30 countries so the loading spinner can animate.
    final result = <CountryData>[];
    for (int i = 0; i < rawEntries.length; i++) {
      result.add(CountryData.fromJson(rawEntries[i]));
      if (i % 30 == 29) await Future.delayed(Duration.zero);
    }
    return result;
  }

  static List<Map<String, dynamic>> _decodeJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    return (data['countries'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, String>> loadCountryNames(Locale locale) async {
    final enJson = await rootBundle.loadString('assets/data/countries_en.json');
    final base = (jsonDecode(enJson) as Map<String, dynamic>).cast<String, String>();
    try {
      final localeJson = await rootBundle.loadString('assets/data/countries_${locale.languageCode}.json');
      final overlay = (jsonDecode(localeJson) as Map<String, dynamic>).cast<String, String>();
      overlay.forEach((k, v) => base[k] = v);
    } catch (_) {}
    return base;
  }
}

final countryNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  return CountryDataService().loadCountryNames(const Locale('en'));
});
