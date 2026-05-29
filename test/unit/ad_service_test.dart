// RED test stubs for AdService interface redesign.
//
// These tests reference method signatures that do NOT yet exist on AdService
// (getBannerWidget, showRewardedAd, showInterstitialAd, showAppOpenAd).
// Compile errors are EXPECTED — this is the RED phase of TDD.
// Wave 2 redesigns the AdService interface to make these GREEN.
//
// Do NOT import google_mobile_ads here — all ad SDK access goes through
// the AdService interface (walled-garden boundary).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flags_around_the_world/core/ads/ad_service.dart';
import 'package:flags_around_the_world/core/ads/stub_ad_service.dart';

void main() {
  group('StubAdService', () {
    late AdService sut;
    setUp(() => sut = StubAdService());

    test('getBannerWidget returns SizedBox', () {
      final widget = sut.getBannerWidget();
      expect(widget, isA<SizedBox>());
    });

    test('showRewardedAd returns false', () async {
      final result = await sut.showRewardedAd();
      expect(result, isFalse);
    });

    test('showInterstitialAd completes without throwing', () async {
      await expectLater(sut.showInterstitialAd(), completes);
    });

    test('showAppOpenAd completes without throwing', () async {
      await expectLater(sut.showAppOpenAd(), completes);
    });
  });
}
