import 'ad_load_state.dart';

abstract interface class AdService {
  Future<AdLoadState> loadBannerAd();
  Future<AdLoadState> loadInterstitialAd();
  Future<AdLoadState> loadRewardedAd();
}

class StubAdService implements AdService {
  const StubAdService();

  @override
  Future<AdLoadState> loadBannerAd() async => const AdFailed();

  @override
  Future<AdLoadState> loadInterstitialAd() async => const AdFailed();

  @override
  Future<AdLoadState> loadRewardedAd() async => const AdFailed();
}
