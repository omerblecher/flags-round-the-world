import 'package:flutter/widgets.dart';
import 'ad_service.dart';

/// No-op ad service used in tests and during phases 1–5.
/// [getBannerWidget] returns [SizedBox.shrink()] so screens compile with no
/// visible ads; all async methods complete immediately.
class StubAdService implements AdService {
  const StubAdService();

  @override
  Widget getBannerWidget() => const SizedBox.shrink();

  @override
  Future<void> showInterstitialAd() async {}

  @override
  Future<bool> showRewardedAd() async => false;

  @override
  Future<void> showAppOpenAd() async {}
}
