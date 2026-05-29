// AdMob test app ID (matches AndroidManifest meta-data).
// Replace with real app ID before Play Store submission.
const String kAdMobTestAppId = 'ca-app-pub-3940256099942544~3347511713';

// Test ad unit IDs — replace with production IDs before Play Store submission.
const String kBannerAdUnitId       = 'ca-app-pub-3940256099942544/6300978111';
const String kInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
const String kRewardedAdUnitId     = 'ca-app-pub-3940256099942544/5224354917';
const String kAppOpenAdUnitId      = 'ca-app-pub-3940256099942544/9257395921';

// AppLovin — disabled pending account approval and Families Program re-entry.
// Set to true ONLY when: (1) AppLovin account is approved, (2) AppLovin is back
// on the Google Play Families Self-Certified Ads SDK Program list.
const bool   kAppLovinEnabled = false;
const String kAppLovinSdkKey  = ''; // populated when account approved
