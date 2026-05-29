import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_service.dart';
import 'admob_ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  final service = AdMobAdService(ref);
  service.preloadAll();
  return service;
});
