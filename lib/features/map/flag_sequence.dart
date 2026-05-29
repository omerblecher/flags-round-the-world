import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';

/// Returns a shuffled list of ISO codes for all [countries].
List<String> buildFlagSequence(List<CountryData> countries) {
  final list = countries.map((c) => c.isoCode).toList();
  list.shuffle();
  return list;
}

/// Returns the Grand Master distinctiveness-ordered sequence from the bundled
/// JSON asset, filtered to codes that actually exist in [countries].
/// Any codes in [countries] not present in the asset are appended at the end.
Future<List<String>> buildGrandMasterSequence(List<CountryData> countries) async {
  final jsonStr = await rootBundle.loadString('assets/data/grand_master_order.json');
  final raw = (jsonDecode(jsonStr) as List).cast<String>();
  // De-duplicate the raw list (the asset may have duplicates from manual editing).
  final seen = <String>{};
  final ordered = raw.where((iso) => seen.add(iso)).toList();
  final allCodes = countries.map((c) => c.isoCode).toSet();
  // Keep only codes that exist in the loaded country data.
  final result = ordered.where((iso) => allCodes.contains(iso)).toList();
  final resultSet = result.toSet();
  // Append any codes not covered by the asset (alphabetical tiebreak).
  final missing = allCodes.difference(resultSet).toList()..sort();
  result.addAll(missing);
  return result;
}
