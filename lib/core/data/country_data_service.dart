import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../models/country_data.dart';

class CountryDataService {
  Future<List<CountryData>> loadMapData() async {
    final jsonString = await rootBundle.loadString('assets/map/world_map_paths.json');
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final countries = data['countries'] as List;
    return countries.map((e) => CountryData.fromJson(e as Map<String, dynamic>)).toList();
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
