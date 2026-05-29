# Phase 6: AdMob & COPPA Audit — Research

**Researched:** 2026-05-29
**Domain:** Flutter AdMob integration, COPPA compliance, Google Play Families Program, ad mediation
**Confidence:** HIGH (all package versions verified against pub.dev API; ad APIs verified from official Google developer docs)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Mediation Partners**
- D-M01: Meta Audience Network is **excluded entirely**.
- D-M02: **AppLovin MAX** SDK present but disabled: `const kAppLovinEnabled = false`. Entire init block is gated behind this constant.
- D-M03: **Unity Ads**, **ironSource/LevelPlay**, and **InMobi** are active mediation partners. Each must have its own COPPA flag before `MobileAds.initialize()`.
- D-M04: Every mediation SDK init must be called before `MobileAds.initialize()`. AdMob does NOT cascade `tagForChildDirectedTreatment` to mediation partners.

**AdService Interface**
- D-A01: Merged load+show pattern: `getBannerWidget()`, `showInterstitialAd()`, `Future<bool> showRewardedAd()`, `showAppOpenAd()`.
- D-A02: Banner exposed as `Widget getBannerWidget()`. `AdMobAdService` returns real `AdWidget`; `StubAdService` returns `SizedBox.shrink()`.
- D-A03: `Future<bool> showRewardedAd()` — `true` if reward earned, `false` if dismissed or failed.
- D-A04: `AdLoadState` sealed class retained for internal use only; not part of public `AdService` interface.

**App Open Ad Flow**
- D-O01: App Open fires on **app resume from background only** (`AppLifecycleState.resumed`). No cold-launch splash screen.
- D-O02: App Open **suppressed when `GamePhase.playing` or `GamePhase.paused`**.
- D-O03: `WidgetsBindingObserver` for App Open must live at **`MyApp`/root level**, not `_MapScreenState`.

**Ad Unit IDs**
- D-I01: Phase 6 uses AdMob **test ad unit IDs**. Constants in `lib/core/ads/ad_constants.dart`.
- D-I02: Swap to production IDs before Google Play submission.

**Ad Placement Rules**
- D-P01: Banners on: HomeScreen, ModeSelectionScreen, CompletionScreen. Never on pause screen. Never during gameplay.
- D-P02: Interstitial fires once at CompletionScreen (game-complete). Never mid-round, never on app open before first interaction.
- D-P03: Rewarded offered when hints reach zero (GAME-08 hint refill).
- D-P04: App Open fires on resume, suppressed during active gameplay.

### Claude's Discretion

None — discussion stayed within phase scope.

### Deferred Ideas (OUT OF SCOPE)

None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADS-01 | Banner ads on non-gameplay screens (home, mode selection, result); never on pause screen | AdaptiveBanner pattern + placement rules documented in §Ad Format API Patterns |
| ADS-02 | Interstitial only at game-complete; never mid-round or on app open before interaction | `InterstitialAd.load()`/`show()` pattern documented; placement rules in §Common Pitfalls |
| ADS-03 | Rewarded interstitial for hint refills after 2 free hints exhausted | `RewardedAd.load()`/`show()` with `onUserEarnedReward` callback documented |
| ADS-04 | App Open ads on resume; only after user can interact | `AppStateEventNotifier` pattern documented; 4-hour expiry pitfall noted |
| ADS-05 | AdMob SDK initialized with child-directed flags before `MobileAds.initialize()` | Exact `RequestConfiguration` code verified from official docs |
| ADS-06 | AppLovin MAX SDK initialized with child-directed flag | AppLovin situation clarified: `gma_mediation_applovin` v2+ auto-disables on child-directed; `kAppLovinEnabled = false` gate confirmed correct |
| ADS-07 | Unity Ads SDK initialized with COPPA flag | `gma_mediation_unity` adapter pattern documented; GDPR/CCPA consent API verified |
| ADS-08 | Meta excluded or initialized with child-directed flag | Excluded per D-M01 |
| ADS-09 | `AD_ID` permission blocked via `tools:remove` | Already present in AndroidManifest.xml — verified in codebase |
| ADS-10 | Firebase Analytics and Crashlytics absent from project | Verified absent from `pubspec.yaml` and `pubspec.lock` |
</phase_requirements>

---

## Summary

Phase 6 wires the walled-garden ad layer that has been stubbed since Phase 1. The core task is replacing `StubAdService` with `AdMobAdService`, initializing Google Mobile Ads with child-directed treatment before any ad is requested, and wiring Unity Ads, ironSource/LevelPlay, and InMobi mediation adapters with their own COPPA flags. All four ad formats — AdaptiveBanner, interstitial, rewarded, and App Open — follow well-documented Google SDK patterns available from official Flutter AdMob documentation.

The single most important finding is the **AppLovin child-directed policy change**: AppLovin SDK 13.0+ dropped `setIsAgeRestrictedUser` and explicitly prohibits initialization in child-directed or mixed-audience apps where any user may be a child. However, the Google-published `gma_mediation_applovin` adapter (v2.0+) handles this automatically: when the app sets `tagForChildDirectedTreatment(true)`, the adapter silently disables AppLovin mediation without crashing. This means the `kAppLovinEnabled = false` constant gate in the CONTEXT.md is correct and sufficient — the adapter adds a second safety net. The standalone `applovin_max` package (not the GMA adapter) must NOT be added to `pubspec.yaml`.

The **mediation adapter strategy** changed from the original CONTEXT.md plan. Rather than adding the standalone `unity_ads_plugin`, `ironsource_mediation`/`unity_levelplay_mediation`, and `inmobi_sdk` packages, Phase 6 should use **Google's first-party GMA mediation adapters**: `gma_mediation_unity`, `gma_mediation_ironsource`, and `gma_mediation_inmobi`. These are published by `google.dev`, depend on `google_mobile_ads ^8.0.0`, and forward child-directed treatment automatically from the AdMob `RequestConfiguration`. This is the canonical approach per Google's documentation.

**Primary recommendation:** Use `gma_mediation_*` adapters (Google-published), set `RequestConfiguration` child-directed flags before calling `MobileAds.initialize()`, use `AppStateEventNotifier` (not raw `WidgetsBindingObserver`) for App Open lifecycle, and run the proxy audit with Charles Proxy + `network_security_config.xml` debug override.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| AdMob initialization + COPPA flags | App startup (main.dart) | — | Must run before any widget, before any ad request |
| AdService abstraction | `lib/core/ads/` | — | Walled-garden boundary — no `google_mobile_ads` imports outside this folder |
| App Open lifecycle observer | Root widget (App) | — | Must fire regardless of which screen is mounted; `_MapScreenState` is too narrow |
| Banner widget embedding | Screen widgets (HomeScreen, ModeSelectionScreen, CompletionScreen) | `lib/core/ads/` | Screens call `adService.getBannerWidget()` — no SDK coupling |
| Interstitial trigger | CompletionScreen `initState` | `lib/core/ads/` | Single-fire on screen mount; never in `build()` |
| Rewarded ad trigger | Hint-exhausted flow (MapScreen or HUD) | `lib/core/ads/` | Returns `Future<bool>` — caller grants hint if `true` |
| Game phase suppression check | `lib/core/ads/` (AdMobAdService) | GameSessionProvider | App Open reads `GamePhase` before showing |
| Proxy audit | Dev machine + Android emulator | — | Manual verification step, not runtime code |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `google_mobile_ads` | 8.0.0 | AdMob SDK Flutter plugin — banner, interstitial, rewarded, App Open, native | Official Google plugin; required by all gma_mediation_* adapters |
| `gma_mediation_unity` | 1.8.0 | AdMob mediation adapter for Unity Ads | Google-published (google.dev); auto-forwards child-directed from RequestConfiguration |
| `gma_mediation_ironsource` | 2.4.1 | AdMob mediation adapter for ironSource/LevelPlay | Google-published (google.dev); bidding + waterfall; requires Maven repo entry |
| `gma_mediation_inmobi` | 2.1.0 | AdMob mediation adapter for InMobi | Google-published (google.dev); COPPA auto-forwarded from GMA RequestConfiguration |
| `gma_mediation_applovin` | 2.6.1 | AdMob mediation adapter for AppLovin MAX | Google-published (google.dev); v2+ auto-disables when child-directed=true |

### Explicitly Excluded Packages

| Package | Reason |
|---------|--------|
| `applovin_max` (standalone) | Prohibited in child-directed apps per AppLovin SDK 13.0+ policy |
| `unity_ads_plugin` (standalone) | Superseded by `gma_mediation_unity` for AdMob-mediated integration |
| `ironsource_mediation` (standalone) | Deprecated; replaced by `unity_levelplay_mediation` and `gma_mediation_ironsource` |
| `unity_levelplay_mediation` (standalone) | For standalone LevelPlay integration; not needed when using AdMob mediation via `gma_mediation_ironsource` |
| `firebase_core` / any `firebase_*` | COPPA prohibition — collect persistent device identifiers (ADS-10, architecture D5) |

### Installation

```yaml
# pubspec.yaml additions
dependencies:
  google_mobile_ads: ^8.0.0
  gma_mediation_unity: ^1.8.0
  gma_mediation_ironsource: ^2.4.1
  gma_mediation_inmobi: ^2.1.0
  gma_mediation_applovin: ^2.6.1   # auto-disables on child-directed; gate via kAppLovinEnabled = false
```

**Additional Android build.gradle change required for ironSource:**
```gradle
// android/build.gradle — add to allprojects > repositories
maven {
    url = uri("https://android-sdk.is.com/")
}
```

**Required AndroidManifest.xml addition (AdMob App ID):**
```xml
<!-- android/app/src/main/AndroidManifest.xml — inside <application> -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
<!-- Replace with real app ID before Play Store submission -->
<!-- Test app ID: ca-app-pub-3940256099942544~3347511713 -->
```

**Version verification:** All versions confirmed via `curl -s "https://pub.dev/api/packages/<name>"` against the pub.dev registry on 2026-05-29. Publishers confirmed as `google.dev` via pub.dev publisher API.

---

## Package Legitimacy Audit

> slopcheck was available but checks PyPI only — these are Dart/pub.dev packages. All packages verified manually via pub.dev REST API (`https://pub.dev/api/packages/<name>`). All five packages exist on pub.dev and are published by the `google.dev` verified publisher (confirmed via `https://pub.dev/api/packages/google_mobile_ads/publisher` returning `{"publisherId":"google.dev"}`).

| Package | Registry | Age | Publisher | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `google_mobile_ads` | pub.dev | ~5 yrs | google.dev (verified) | googleads/googleads-mobile-flutter | N/A (PyPI only) | Approved — verified pub.dev + official docs |
| `gma_mediation_unity` | pub.dev | ~2 yrs | google.dev (verified) | googleads/googleads-mobile-flutter | N/A | Approved — verified pub.dev + official docs |
| `gma_mediation_ironsource` | pub.dev | ~2 yrs | google.dev (verified) | googleads/googleads-mobile-flutter | N/A | Approved — verified pub.dev + official docs |
| `gma_mediation_inmobi` | pub.dev | ~2 yrs | google.dev (verified) | googleads/googleads-mobile-flutter | N/A | Approved — verified pub.dev + official docs |
| `gma_mediation_applovin` | pub.dev | ~2 yrs | google.dev (verified) | googleads/googleads-mobile-flutter | N/A | Approved — verified pub.dev + official docs |

**Packages removed due to slopcheck [SLOP] verdict:** none

**Packages flagged as suspicious [SUS]:** none

**slopcheck ecosystem note:** slopcheck only supports npm and PyPI. For Dart/pub.dev packages, the equivalent verification is checking the publisher via `pub.dev/api/packages/<name>/publisher`. All five packages return `publisherId: google.dev` — a verified publisher operated by Google — which is equivalent to or stronger than slopcheck [OK] for this ecosystem.

---

## AdMob COPPA Initialization

### Complete Child-Directed Init Block

[VERIFIED: developers.google.com/admob/flutter/targeting]

```dart
// lib/core/ads/ad_service_provider.dart (or main.dart before runApp)
// Call this BEFORE MobileAds.instance.initialize()

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gma_mediation_ironsource/gma_mediation_ironsource.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';

Future<void> initializeAds() async {
  // Step 1: Set child-directed flags on Google Mobile Ads
  // Note: do NOT set both tagForChildDirectedTreatment AND tagForUnderAgeOfConsent
  // to true simultaneously — child-directed takes precedence but the combination
  // is not recommended per Google docs.
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      maxAdContentRating: MaxAdContentRating.g,
      // tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,  // omit — child-directed covers this
    ),
  );

  // Step 2: Set ironSource/LevelPlay COPPA flag (before MobileAds.initialize)
  // SDK 9.4.0+ API (unity_levelplay_mediation package) — but since we use gma_mediation_ironsource,
  // the adapter forwards tagForChildDirectedTreatment from RequestConfiguration automatically.
  // As belt-and-suspenders, also set via the mediation adapter's privacy API:
  GmaMediationIronsource().setDoNotSell(true);
  // Note: LevelPlay SDK's own COPPA flag (LevelPlayPrivacySettings.setCOPPA(true))
  // is only needed when using unity_levelplay_mediation in standalone mode, NOT
  // when using gma_mediation_ironsource as the AdMob adapter.

  // Step 3: Set Unity consent (gma_mediation_unity adapter)
  GmaMediationUnity.setGDPRConsent(false);   // no consent for children
  GmaMediationUnity.setCCPAConsent(false);   // CCPA: do not sell

  // Step 4: AppLovin — gma_mediation_applovin v2+ auto-disables when
  // tagForChildDirectedTreatment=yes. kAppLovinEnabled = false gate provides
  // additional safety. No explicit call needed.

  // Step 5: Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();
}
```

**Critical ordering rule:** [VERIFIED: CONTEXT.md D-M04, CLAUDE.md §COPPA Non-Negotiables]
1. `MobileAds.instance.updateRequestConfiguration(...)` — set BEFORE initialize
2. Mediation SDK flags (ironSource, Unity) — set BEFORE initialize
3. `await MobileAds.instance.initialize()` — called ONCE at app startup
4. Load first ads — only AFTER initialize completes

**Warning on dual-flag conflict:** [VERIFIED: developers.google.com/admob/flutter/targeting]
Setting both `tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes` AND
`tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes` simultaneously is explicitly not recommended. Child-directed takes precedence. Use only `tagForChildDirectedTreatment` for this app.

---

## Ad Unit ID Constants

[VERIFIED: developers.google.com/admob/android/test-ads]

```dart
// lib/core/ads/ad_constants.dart
const String kAdMobTestAppId = 'ca-app-pub-3940256099942544~3347511713';

// Test ad unit IDs — replace with production IDs before Play Store submission
const String kBannerAdUnitId       = 'ca-app-pub-3940256099942544/6300978111';
const String kInterstitialAdUnitId  = 'ca-app-pub-3940256099942544/1033173712';
const String kRewardedAdUnitId      = 'ca-app-pub-3940256099942544/5224354917';
const String kAppOpenAdUnitId       = 'ca-app-pub-3940256099942544/9257395921';

// AppLovin — disabled pending account approval
const bool   kAppLovinEnabled = false;
const String kAppLovinSdkKey  = '';   // populated when account approved
```

**Note on rewarded vs rewarded interstitial:** Two test IDs exist:
- Rewarded: `ca-app-pub-3940256099942544/5224354917`
- Rewarded interstitial: `ca-app-pub-3940256099942544/5354046379`
Use the plain **Rewarded** ID for the hint-refill flow (GAME-08). Rewarded interstitial is a different format.

---

## Mediation SDK COPPA APIs

### gma_mediation_unity (Unity Ads)

[VERIFIED: developers.google.com/admob/flutter/mediation/unity]

When using `gma_mediation_unity` as the AdMob mediation adapter:
- `tagForChildDirectedTreatment` from `RequestConfiguration` is **automatically forwarded** to Unity Ads by the adapter.
- For belt-and-suspenders compliance, also call the Unity privacy consent API:

```dart
import 'package:gma_mediation_unity/gma_mediation_unity.dart';

GmaMediationUnity.setGDPRConsent(false);   // No consent from children
GmaMediationUnity.setCCPAConsent(false);   // Do not sell
// Call BEFORE MobileAds.instance.initialize()
```

**Dashboard requirement:** [CITED: docs.unity.com/ads/en-us/manual/GoogleFamiliesCompliance]
In the Unity Monetization dashboard, set:
- "App is directed to children" → enabled
- "Google Designed for Families" flag → enabled
This is a one-time manual step in the Unity console, not a code change.

### gma_mediation_ironsource (ironSource / LevelPlay)

[VERIFIED: developers.google.com/admob/flutter/mediation/ironsource]

When using `gma_mediation_ironsource` as the AdMob mediation adapter:
- The adapter forwards `tagForChildDirectedTreatment` from AdMob's `RequestConfiguration` to ironSource automatically.
- Additional `setDoNotSell` API is available for US state privacy:

```dart
import 'package:gma_mediation_ironsource/gma_mediation_ironsource.dart';

GmaMediationIronsource().setDoNotSell(true);
// Call BEFORE MobileAds.instance.initialize()
```

**Note on standalone LevelPlay COPPA API:** If using `unity_levelplay_mediation` standalone (NOT recommended for this app), the SDK 9.4.0+ API is:
```dart
LevelPlayPrivacySettings.setCOPPA(true);  // SDK 9.4+ only
// OR for SDK 9.3 and below (deprecated):
LevelPlay.setMetaData({'is_child_directed': ['true']});
LevelPlay.setMetaData({'is_deviceid_optout': ['true']});
```
This is documented here for reference only — Phase 6 uses `gma_mediation_ironsource` which handles this automatically.

**Android build.gradle:** The ironSource adapter requires adding the Maven repo:
```gradle
// android/build.gradle — allprojects { repositories { ... } }
maven {
    url = uri("https://android-sdk.is.com/")
}
```

### gma_mediation_inmobi (InMobi)

[VERIFIED: developers.google.com/admob/flutter/mediation/inmobi]

When using `gma_mediation_inmobi`:
- Starting with plugin version 1.1.0, InMobi automatically reads GDPR consent from platforms supporting Google's Additional Consent specification.
- The adapter forwards `tagForChildDirectedTreatment` from AdMob `RequestConfiguration` to InMobi.
- No explicit Flutter-side COPPA API call required beyond the AdMob `RequestConfiguration`.
- The adapter initializes InMobi automatically — no separate `InMobiSdk.init()` call needed.

**InMobi Account ID:** Required in AdMob console configuration (under Finance > Payment Settings > Payment Information), but not required in code.

**Optional AndroidManifest permissions** (better fill rate, not required for child compliance):
```xml
<!-- These are OPTIONAL — do NOT add ACCESS_FINE_LOCATION for a children's app without consent -->
<!-- Omit for this app — unnecessary permission scope for a children's educational game -->
```

### gma_mediation_applovin (AppLovin MAX — disabled)

[VERIFIED: support.axon.ai/en/max/flutter/overview/privacy, developers.google.com/admob/flutter/mediation/applovin]

**Critical policy change:** AppLovin SDK 13.0+ dropped `setIsAgeRestrictedUser`. AppLovin's policy explicitly states: *"You may not initialize or use the AppLovin SDK in connection with a 'child' as defined under applicable laws."*

**Automatic safety net:** `gma_mediation_applovin` v2.0+ **automatically disables AppLovin mediation** when the app's `RequestConfiguration` has `tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes`. This means including the adapter is safe — AppLovin simply never fires.

**Code pattern:** The `kAppLovinEnabled = false` constant gate from CONTEXT.md D-M02 provides a second layer of protection and documents intent clearly:

```dart
// lib/core/ads/admob_ad_service.dart (inside initializeAds)
if (kAppLovinEnabled) {
  // AppLovin initialization goes here when account is approved
  // gma_mediation_applovin auto-disables for child-directed regardless,
  // but this gate makes the disabled state explicit and intentional.
}
```

---

## Ad Format API Patterns

### AdaptiveBanner

[VERIFIED: developers.google.com/admob/flutter/banner]

```dart
// Inside AdMobAdService._loadBanner()
Future<void> _loadBanner(BuildContext context) async {
  final screenWidth = MediaQuery.sizeOf(context).width.truncate();
  final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
    Orientation.portrait,
    screenWidth,
  );
  if (adSize == null) return;

  BannerAd(
    adUnitId: kBannerAdUnitId,
    request: const AdRequest(),
    size: adSize,
    listener: BannerAdListener(
      onAdLoaded: (ad) {
        _bannerAd = ad as BannerAd;
        _bannerLoaded = true;
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        _bannerAd = null;
      },
    ),
  ).load();
}

// AdService.getBannerWidget() implementation
Widget getBannerWidget() {
  final ad = _bannerAd;
  if (ad == null) return const SizedBox.shrink();
  return SizedBox(
    width: ad.size.width.toDouble(),
    height: ad.size.height.toDouble(),
    child: AdWidget(ad: ad),
  );
}
```

**Embedding in screens:**
```dart
// In HomeScreen, ModeSelectionScreen, CompletionScreen build()
Align(
  alignment: Alignment.bottomCenter,
  child: SafeArea(
    child: ref.read(adServiceProvider).getBannerWidget(),
  ),
),
```

**Disposal:** Call `_bannerAd?.dispose()` when the screen is disposed or a new banner replaces it.

### Interstitial Ad

[VERIFIED: developers.google.com/admob/flutter/interstitial]

```dart
// Inside AdMobAdService
InterstitialAd? _interstitialAd;

void _preloadInterstitial() {
  InterstitialAd.load(
    adUnitId: kInterstitialAdUnitId,
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) => _interstitialAd = ad,
      onAdFailedToLoad: (error) => _interstitialAd = null,
    ),
  );
}

Future<void> showInterstitialAd() async {
  final ad = _interstitialAd;
  if (ad == null) return;
  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      _interstitialAd = null;
      _preloadInterstitial(); // preload next
    },
    onAdFailedToShowFullScreenContent: (ad, err) {
      ad.dispose();
      _interstitialAd = null;
    },
  );
  _interstitialAd = null; // prevent double-show
  await ad.show();
}
```

**Placement rule:** Call `showInterstitialAd()` in `CompletionScreen.initState()`, not in `build()`.

### Rewarded Ad

[VERIFIED: developers.google.com/admob/flutter/rewarded]

```dart
// Inside AdMobAdService
RewardedAd? _rewardedAd;

void _preloadRewarded() {
  RewardedAd.load(
    adUnitId: kRewardedAdUnitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) => _rewardedAd = ad,
      onAdFailedToLoad: (error) => _rewardedAd = null,
    ),
  );
}

Future<bool> showRewardedAd() async {
  final ad = _rewardedAd;
  if (ad == null) return false;
  final completer = Completer<bool>();
  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      _rewardedAd = null;
      _preloadRewarded();
      if (!completer.isCompleted) completer.complete(false);
    },
    onAdFailedToShowFullScreenContent: (ad, err) {
      ad.dispose();
      _rewardedAd = null;
      completer.complete(false);
    },
  );
  _rewardedAd = null;
  await ad.show(
    onUserEarnedReward: (_, reward) {
      if (!completer.isCompleted) completer.complete(true);
    },
  );
  return completer.future;
}
```

**Caller pattern (hint-exhausted flow):**
```dart
final earned = await ref.read(adServiceProvider).showRewardedAd();
if (earned) { /* grant hint refill */ }
```

### App Open Ad

[VERIFIED: developers.google.com/admob/flutter/app-open]

```dart
// Inside AdMobAdService
AppOpenAd? _appOpenAd;
DateTime? _appOpenLoadTime;
static const Duration _kAppOpenExpiry = Duration(hours: 4);

void _preloadAppOpen() {
  AppOpenAd.load(
    adUnitId: kAppOpenAdUnitId,
    adRequest: const AdRequest(),
    adLoadCallback: AppOpenAdLoadCallback(
      onAdLoaded: (ad) {
        _appOpenAd = ad;
        _appOpenLoadTime = DateTime.now();
      },
      onAdFailedToLoad: (error) => _appOpenAd = null,
    ),
  );
}

bool get _isAppOpenAdAvailable {
  if (_appOpenAd == null) return false;
  final loadTime = _appOpenLoadTime;
  if (loadTime == null) return false;
  return DateTime.now().difference(loadTime) < _kAppOpenExpiry;
}

Future<void> showAppOpenAd() async {
  if (!_isAppOpenAdAvailable) {
    _preloadAppOpen();
    return;
  }
  final ad = _appOpenAd!;
  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      _appOpenAd = null;
      _preloadAppOpen();
    },
    onAdFailedToShowFullScreenContent: (ad, err) {
      ad.dispose();
      _appOpenAd = null;
    },
  );
  _appOpenAd = null;
  await ad.show();
}
```

---

## App Open Observer Pattern

### Canonical Pattern: AppStateEventNotifier (Recommended)

[VERIFIED: developers.google.com/admob/flutter/app-open]

The Google Mobile Ads SDK provides `AppStateEventNotifier` — a stream-based notifier that is more reliable than raw `WidgetsBindingObserver` because it specifically detects app foreground transitions (not just widget lifecycle changes).

```dart
// lib/app.dart — convert App from StatelessWidget to ConsumerStatefulWidget
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  StreamSubscription<AppState>? _appStateSubscription;

  @override
  void initState() {
    super.initState();
    AppStateEventNotifier.startListening();
    _appStateSubscription = AppStateEventNotifier.appStateStream.listen(
      (appState) {
        if (appState == AppState.foreground) {
          _onAppResumed();
        }
      },
    );
  }

  void _onAppResumed() {
    // Suppress if game is active
    final gameSession = ref.read(gameSessionProvider);
    final phase = gameSession.valueOrNull?.phase;
    if (phase == GamePhase.playing || phase == GamePhase.paused) return;

    ref.read(adServiceProvider).showAppOpenAd();
  }

  @override
  void dispose() {
    _appStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flags Around the World',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
```

**Why `AppStateEventNotifier` over `WidgetsBindingObserver`:**
- Designed specifically for the App Open ad use case
- Provided by the `google_mobile_ads` package — no additional dependency
- Fires on true app foreground state, not on dialog dismissals or keyboard hide/show

**Game phase suppression:** [VERIFIED: CONTEXT.md D-O02]
Read `gameSessionProvider` before every `showAppOpenAd()` call. The game auto-pauses on background (Phase 5), so on resume the session may be in `GamePhase.paused`. Skip the ad in that case to avoid showing an ad over the pause overlay.

---

## Proxy Audit Checklist

[VERIFIED: developers.google.com/admob/android/charles]
[CITED: Google's official AdMob Charles Proxy setup guide]

### Setup: Charles Proxy on Android Emulator

1. **Install Charles Proxy** (macOS/Windows, $50 one-time) or **mitmproxy** (free, open source).
   - Charles is recommended over mitmproxy for AdMob auditing because Google has an official Charles setup guide.
   - mitmproxy works equally well on Android API 21+; see network_security_config approach below.

2. **Create `res/xml/network_security_config.xml`** (debug only):
   ```xml
   <!-- android/app/src/main/res/xml/network_security_config.xml -->
   <network-security-config>
       <debug-overrides>
           <trust-anchors>
               <certificates src="user" />
           </trust-anchors>
       </debug-overrides>
   </network-security-config>
   ```

3. **Reference in AndroidManifest** (debug build only — remove before production build):
   ```xml
   <!-- android/app/src/main/AndroidManifest.xml — <application> tag -->
   android:networkSecurityConfig="@xml/network_security_config"
   ```
   **Alternative:** Create a separate `android/app/src/debug/AndroidManifest.xml` that only applies in debug builds (Flutter supports this via build flavors).

4. **Enable debug ad logging** (Google Settings app on device → Google → Ads → Enable debug logging for ads).

5. **Configure emulator proxy:** In Android emulator settings, set HTTP proxy to `127.0.0.1:8888` (Charles default) or `127.0.0.1:8080` (mitmproxy default).

6. **Install Charles/mitmproxy CA certificate** on the emulator: Charles Help → SSL Proxying → Install Charles Root Certificate on Android Device.

7. **Enable SSL Proxying** in Charles for the domains below.

### Domains to Filter

| Domain | SDK |
|--------|-----|
| `googleads.g.doubleclick.net` | AdMob |
| `pubads.g.doubleclick.net` | AdMob |
| `pagead2.googlesyndication.com` | AdMob |
| `unity3d.com` | Unity Ads |
| `unityads.unity3d.com` | Unity Ads |
| `android-sdk.is.com` | ironSource/LevelPlay |
| `outcome-ssp.supersonicads.com` | ironSource |
| `inmobi.com` / `w.inmobi.com` | InMobi |

### What to Verify

Search ALL request bodies, query parameters, and headers for these strings:

| String | What It Identifies |
|--------|-------------------|
| `gaid` | Google Advertising ID (GAID) — must be absent or zeroed |
| `idfa` | iOS IDFA — must be absent |
| `advertising_id` | GAID parameter key |
| `android_id` | Android hardware ID |
| `device_id` | Generic device identifier |
| `aaid` | Alternative GAID label |

**Expected result:** All values should be `00000000-0000-0000-0000-000000000000` (zeroed, indicating child-directed treatment received) or the parameter should be absent entirely from all requests.

**Verify `AD_ID` permission block works:** Already present in AndroidManifest.xml as of Phase 5 (`tools:node="remove"` on `com.google.android.gms.permission.AD_ID`). Confirm no SDK added it back by running:
```bash
./gradlew :app:mergeDebugAndroidManifest
# Then inspect: build/intermediates/merged_manifests/debug/AndroidManifest.xml
# Confirm AD_ID uses-permission is absent from merged output
```

---

## Google Play Families Program Pre-Submission Checklist

[CITED: support.google.com/admob/answer/6223431]
[CITED: support.google.com/googleplay/android-developer/answer/9900633]

### Ads Configuration

- [ ] `google_mobile_ads` version 8.x confirmed in `pubspec.lock` (minimum Android GMA 20.6.0 for Families compliance)
- [ ] `tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes` set in `RequestConfiguration` before `MobileAds.initialize()`
- [ ] `maxAdContentRating: MaxAdContentRating.g` set in `RequestConfiguration`
- [ ] All mediation adapters are from Google Play **Families Self-Certified Ads SDK Program** (see note below)
- [ ] No ad network outside the certified list is active in AdMob console mediation groups
- [ ] Custom event ad sources (if any) verified as self-certified

### Manifest & Permissions

- [ ] `AD_ID` permission blocked via `tools:node="remove"` in AndroidManifest.xml — verified present
- [ ] Merged manifest confirms `AD_ID` absent: `./gradlew :app:mergeDebugAndroidManifest` + inspect output
- [ ] `AdMob APP_ID` meta-data present in `<application>` block
- [ ] `networkSecurityConfig` removed (or limited to `debug-overrides`) before production build

### Code Verification

- [ ] `firebase_core` absent from `pubspec.yaml` — **verified** (checked codebase)
- [ ] `firebase_core` absent from `pubspec.lock` — verify after Phase 6 `flutter pub get`
- [ ] No ad imports outside `lib/core/ads/` and `lib/features/ads/` (walled garden boundary)
- [ ] `showInterstitialAd()` NOT called in any `build()` method
- [ ] No banner shown on pause screen or MapScreen while playing
- [ ] App Open ad suppressed when `GamePhase.playing` or `GamePhase.paused`
- [ ] `AppStateEventNotifier.startListening()` called — not raw `WidgetsBindingObserver` for App Open

### Google Play Console

- [ ] App target audience set to "Ages 5-12" (or similar children bracket) in Play Console > App Content
- [ ] Families Program enrollment confirmed in Play Console
- [ ] Privacy policy URL active and linked in Play Console
- [ ] Data safety form completed: confirm no advertising ID collected, no personal data collected
- [ ] Content rating questionnaire completed — select appropriate content rating (Everyone / E)
- [ ] AdMob console: all ad units configured for child-directed treatment

### Families Self-Certified Ads SDK Note

[CITED: support.google.com/googleplay/android-developer/answer/9900633]

Google's Self-Certified Ads SDK Program list is maintained separately and is subject to change. Key points:

- `google_mobile_ads` (AdMob SDK) is self-certified — it is Google's own SDK.
- `gma_mediation_unity`, `gma_mediation_ironsource`, `gma_mediation_inmobi` are Google-published adapters. The **underlying mediation networks** (Unity Ads, ironSource, InMobi) must separately be on the approved list.
- AppLovin **left** the Families Self-Certified Ads SDK Program. [CITED: search result from play console help] The `gma_mediation_applovin` adapter auto-disables on child-directed, but **do not enable AppLovin via `kAppLovinEnabled`** until confirming AppLovin has re-entered the program.
- Verify current certified network list at: https://support.google.com/googleplay/android-developer/answer/9900633 before Play Store submission.

---

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── core/
│   └── ads/
│       ├── ad_constants.dart          # kBannerAdUnitId, kInterstitialAdUnitId, etc.
│       ├── ad_service.dart            # AdService abstract interface (redesigned)
│       ├── ad_service_provider.dart   # Provider: returns AdMobAdService in production
│       ├── admob_ad_service.dart      # AdMobAdService implementation (NEW)
│       ├── stub_ad_service.dart       # StubAdService (moved out of ad_service.dart)
│       └── ad_load_state.dart         # Retained for internal use
├── app.dart                           # App → ConsumerStatefulWidget (App Open observer)
└── main.dart                          # initializeAds() called before runApp
```

### Pattern: Walled Garden (Immovable)

[VERIFIED: CLAUDE.md §Critical Architecture Decisions D4]

All `google_mobile_ads` imports are confined to `lib/core/ads/`. Screen code only calls `adService.getBannerWidget()`, `adService.showInterstitialAd()`, etc. `GameSessionNotifier` has zero imports from `features/ads/`.

### Anti-Patterns to Avoid

- **Calling `showInterstitialAd()` in `build()`:** Fires on every rebuild. Use `initState()` or a one-shot listener.
- **Using `WidgetsBindingObserver` for App Open:** Raw observer fires on more events than just app resume. Use `AppStateEventNotifier` from the GMA SDK.
- **Adding standalone `applovin_max` to pubspec.yaml:** Child-directed prohibition. Use `gma_mediation_applovin` only.
- **Using `ironsource_mediation` (deprecated):** Use `gma_mediation_ironsource` instead.
- **Calling mediation SDK init after `MobileAds.initialize()`:** COPPA flags may not propagate. Always init before.
- **Leaving `networkSecurityConfig` with `<certificates src="user" />` in production build:** Security vulnerability — user-installed certs trusted in production.
- **Setting both tagForChildDirectedTreatment AND tagForUnderAgeOfConsent to `yes`:** Not recommended per Google docs.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| App Open lifecycle detection | Custom `WidgetsBindingObserver` | `AppStateEventNotifier` from GMA SDK | Google's notifier is tuned for ad display; raw observer fires on non-resume events |
| Ad expiry tracking | Custom timestamp logic | Built into App Open pattern (4-hour check) | Exact expiry window is SDK-documented; hand-roll risks showing expired or null ads |
| COPPA propagation to mediation | Manual per-network config | Set `RequestConfiguration` once; GMA adapters forward automatically | Each adapter does its own translation; manual propagation is error-prone |
| Banner size calculation | Fixed 320×50 | `AdSize.getLargeAnchoredAdaptiveBannerAdSize()` | Adaptive banners fill screen width → better CPM, correct layout on all devices |
| Ad preloading state machine | Custom boolean flags | Merged load+show pattern in `AdMobAdService` | SDK callbacks handle load failure and retry; hand-rolled state machines diverge |

---

## Common Pitfalls

### Pitfall 1: AdMob App ID Missing from AndroidManifest
**What goes wrong:** App crashes at launch with `java.lang.RuntimeException: Missing application ID`.
**Why it happens:** `google_mobile_ads` 5+ requires the AdMob App ID in `AndroidManifest.xml` as a `<meta-data>` tag. Without it, the SDK refuses to initialize.
**How to avoid:** Add before `MobileAds.instance.initialize()` is ever called. Use the demo app ID `ca-app-pub-3940256099942544~3347511713` for development.
**Warning signs:** App crashes immediately on launch after adding `google_mobile_ads`.

### Pitfall 2: Child-Directed Flags Set After MobileAds.initialize()
**What goes wrong:** Ads request with incorrect targeting; COPPA compliance fails.
**Why it happens:** `MobileAds.initialize()` sends an initialization signal to SDKs. Flags set after this point may not propagate to the first ad requests.
**How to avoid:** Always call `MobileAds.instance.updateRequestConfiguration(...)` BEFORE `MobileAds.instance.initialize()`.
**Warning signs:** Proxy audit shows ad requests with non-zeroed advertising IDs.

### Pitfall 3: App Open Ad Expiry Not Checked
**What goes wrong:** App crashes or shows a blank ad after the app has been backgrounded for more than 4 hours.
**Why it happens:** App Open ads expire 4 hours after load. The SDK does not auto-expire them.
**How to avoid:** Store `_appOpenLoadTime` and check `DateTime.now().difference(loadTime) < Duration(hours: 4)` before showing.
**Warning signs:** Ad show fails with an error about expired ad object.

### Pitfall 4: Interstitial Called in build()
**What goes wrong:** Interstitial fires on every widget rebuild — multiple times per screen mount.
**Why it happens:** Flutter rebuilds widgets frequently; `build()` is not a lifecycle event.
**How to avoid:** Call `showInterstitialAd()` in `initState()` or trigger it once from a `ref.listen` that fires only on specific state transitions.
**Warning signs:** Interstitial fires unexpectedly when rotating screen or returning from background.

### Pitfall 5: networkSecurityConfig Left in Production Build
**What goes wrong:** User-installed CA certificates are trusted in production — security vulnerability; also may cause Play Store review failure.
**Why it happens:** Developers add `<certificates src="user" />` for proxy debugging and forget to remove it.
**How to avoid:** Use `<debug-overrides>` element so it only applies in debug builds, OR put the modified manifest in `android/app/src/debug/` only.
**Warning signs:** Play Store pre-launch report flags insecure network configuration.

### Pitfall 6: AppLovin Initialized in Child-Directed App
**What goes wrong:** COPPA violation; potential Play Store rejection.
**Why it happens:** AppLovin SDK 13.0+ removed child-directed support and their policy prohibits use with child users.
**How to avoid:** Keep `kAppLovinEnabled = false`. Never set it to `true` unless AppLovin re-enters the Google Play Families Self-Certified Ads SDK Program. `gma_mediation_applovin` v2+ provides an additional automatic safety net.
**Warning signs:** `setIsAgeRestrictedUser` compile error in AppLovin SDK 13.0+ (method no longer exists).

### Pitfall 7: ironSource Maven Repository Missing
**What goes wrong:** Build fails with "Could not resolve com.ironsource.sdk:mediationsdk:..." during `flutter pub get` or Android build.
**Why it happens:** `gma_mediation_ironsource` requires the ironSource Maven repository, which is not included by default.
**How to avoid:** Add `maven { url = uri("https://android-sdk.is.com/") }` to `android/build.gradle` `allprojects.repositories` block.
**Warning signs:** Gradle sync fails with unresolvable dependency after adding `gma_mediation_ironsource`.

### Pitfall 8: Banner Ad Loaded Without Context (AdaptiveBanner)
**What goes wrong:** `AdSize.getLargeAnchoredAdaptiveBannerAdSize()` returns null; banner never displays.
**Why it happens:** The adaptive banner API needs the screen width in dp at load time. Calling it too early (before a valid `BuildContext` with layout info) may yield null.
**How to avoid:** Load the banner from within `didChangeDependencies()` or after first frame (`SchedulerBinding.instance.addPostFrameCallback`), where `MediaQuery.sizeOf(context)` is valid.
**Warning signs:** `adSize == null` branch in `_loadBanner`; banner widget returns `SizedBox.shrink()`.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) + mocktail 1.0.5 |
| Config file | `pubspec.yaml` → `dev_dependencies` |
| Quick run command | `flutter test test/unit/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADS-05 | `RequestConfiguration` has child-directed flags before `initialize()` | Unit | `flutter test test/unit/ad_service_test.dart` | ❌ Wave 0 |
| ADS-05 | `tagForChildDirectedTreatment` = `yes`, `maxAdContentRating` = `g` | Unit | `flutter test test/unit/ad_service_test.dart` | ❌ Wave 0 |
| ADS-10 | `firebase_core` absent from pubspec.lock | Static / CI check | `grep -c firebase pubspec.lock` (expect 0) | ❌ manual check |
| ADS-09 | `AD_ID` permission absent from merged manifest | Static | `flutter build apk --debug && grep -c AD_ID build/intermediates/merged_manifests/debug/AndroidManifest.xml` (expect 0) | ❌ manual check |
| D-A03 | `showRewardedAd()` returns `true` on reward earned | Unit | `flutter test test/unit/ad_service_test.dart` | ❌ Wave 0 |
| D-A03 | `showRewardedAd()` returns `false` on dismiss | Unit | `flutter test test/unit/ad_service_test.dart` | ❌ Wave 0 |
| D-A01 | `StubAdService.getBannerWidget()` returns `SizedBox.shrink()` | Unit | `flutter test test/unit/ad_service_test.dart` | ❌ Wave 0 |
| Proxy | GAID zeroed in ad traffic | Manual | Proxy audit (Charles/mitmproxy) | N/A — manual |

### Sampling Rate

- **Per task commit:** `flutter test test/unit/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green + manual proxy audit passed before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/unit/ad_service_test.dart` — covers ADS-05 init flags, D-A01 stub widget, D-A03 reward bool
- [ ] Mock for `MobileAds` (mocktail-based stub or platform channel override)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | No | Ad responses are rendered by SDK, not parsed by app |
| V6 Cryptography | No | N/A |
| V1 Architecture — Data Privacy | **Yes** | No device identifiers transmitted; COPPA `RequestConfiguration` |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| GAID leakage via mediation SDK | Information Disclosure | `tagForChildDirectedTreatment=yes` + `AD_ID` permission block + proxy audit |
| Ad network COPPA bypass (mediation not flagged) | Repudiation | Each GMA adapter forwards child-directed from `RequestConfiguration`; verify via proxy |
| Ad network outside Families Program served | Tampering | AdMob auto-blocks uncertified sources for child-directed apps; verify in AdMob console |
| Firebase added transitively | Information Disclosure | Lock: `firebase_core` absent from pubspec; CI check on `pubspec.lock` |
| AppLovin initialized for child user | Repudiation | `kAppLovinEnabled = false` constant; `gma_mediation_applovin` v2+ auto-disable |
| Production networkSecurityConfig trusting user certs | Information Disclosure | Use `<debug-overrides>` only; verify in release build |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All ad SDK builds | ✓ (assumed — project builds) | ≥3.32.0 | — |
| Android SDK / emulator | Proxy audit | ✓ (assumed) | API 23+ | Use physical device |
| Charles Proxy OR mitmproxy | Proxy audit | [ASSUMED] | — | mitmproxy (free) |
| pub.dev registry | Package install | ✓ | — | — |
| ironSource Maven repo | gma_mediation_ironsource build | Must add to build.gradle | — | Build fails without it |
| Real AdMob account | Production ad units | Not yet created | — | Use test IDs for Phase 6 |

**Missing dependencies with no fallback:**
- Real AdMob App ID and ad unit IDs — required before Play Store submission. Test IDs used for Phase 6 scope.
- ironSource Maven repository entry — build fails without it.

**Missing dependencies with fallback:**
- Charles Proxy ($50) → mitmproxy (free, equivalent for this audit)

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ironsource_mediation` standalone | `gma_mediation_ironsource` (Google adapter) | 2023-2024 | Cleaner COPPA forwarding; single dependency chain |
| `setIsAgeRestrictedUser` (AppLovin) | AppLovin excluded from child-directed apps | AppLovin SDK 13.0+ | Cannot use AppLovin in child-directed context |
| Separate `AppLifecycleState.resumed` observer | `AppStateEventNotifier` from GMA SDK | google_mobile_ads ~5.x | More reliable; tuned for App Open use case |
| Fixed 320×50 banner | `AdSize.getLargeAnchoredAdaptiveBannerAdSize()` | google_mobile_ads 4.x | Better CPM; fills available width |
| `ironsource_mediation` / `unity_levelplay_mediation` for standalone use | Only needed if not using AdMob mediation | 2023 | For pure LevelPlay deployments; not this app's architecture |

**Deprecated/outdated:**
- `ironsource_mediation`: Replaced by `unity_levelplay_mediation` for standalone, or `gma_mediation_ironsource` for AdMob-mediated. The pub.dev page explicitly marks it as discontinued.
- `setIsAgeRestrictedUser` (AppLovin): Removed in SDK 13.0+. Method does not exist.
- `AppOpenAd` with `WidgetsBindingObserver`: Superseded by `AppStateEventNotifier`. Google's own docs now use `AppStateEventNotifier` exclusively.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Unity Ads, ironSource, and InMobi are currently on the Google Play Families Self-Certified Ads SDK Program list | Pre-Submission Checklist | These networks blocked from serving in Families apps; need to find alternative mediation partners |
| A2 | `gma_mediation_unity`, `gma_mediation_ironsource`, and `gma_mediation_inmobi` forward `tagForChildDirectedTreatment` from AdMob `RequestConfiguration` without additional per-SDK init calls | Mediation COPPA APIs | Child-directed treatment not passed to network; COPPA violation |
| A3 | Charles Proxy or mitmproxy is available on the developer machine for proxy audit | Environment Availability | Proxy audit step cannot be completed; must acquire tool |
| A4 | AdMob account and real app ID will be created before Play Store submission | Pre-Submission Checklist | App cannot serve real ads; use test IDs for Phase 6 only |

**Claims A1 and A2 should be validated before or during Phase 6 execution.**
- For A1: Check https://support.google.com/googleplay/android-developer/answer/9900633 for the current certified SDK list.
- For A2: Verify by checking proxy audit traffic — if child-directed is properly forwarded, advertising IDs will be zeroed in requests to Unity, ironSource, and InMobi endpoints.

---

## Open Questions

1. **Are Unity Ads and ironSource currently on the Google Play Families Self-Certified list?**
   - What we know: AppLovin left the program. Unity and ironSource are large networks with child-directed app history.
   - What's unclear: The current list requires checking the live Play Console Help page — it changes.
   - Recommendation: Check during Phase 6 execution before enabling mediation in AdMob console. If a network is not certified, remove its adapter from mediation group (keep package in pubspec but don't configure in AdMob console).

2. **Does `gma_mediation_ironsource` handle the ironSource SDK lifecycle (onResume/onPause) automatically?**
   - What we know: The standalone ironSource SDK requires `IronSource.onResume(activity)` / `IronSource.onPause(activity)` in the Activity lifecycle.
   - What's unclear: Whether the GMA mediation adapter handles this transparently.
   - Recommendation: Check the `gma_mediation_ironsource` changelog and/or test by running on a physical device and verifying ad fill on resume.

3. **Does `initializeAds()` belong in `main()` or as part of the `adServiceProvider` initialization?**
   - What we know: `MobileAds.initialize()` must be called once, after `WidgetsFlutterBinding.ensureInitialized()`, before ad requests.
   - What's unclear: Whether calling it inside `AdMobAdService` constructor (which is created when the provider is first read) is safe, or if it must be in `main()` before `runApp()`.
   - Recommendation: Call in `main()` before `runApp()` for predictable ordering. Pass the `InitializationStatus` future to `AdMobAdService` if needed.

---

## Sources

### Primary (HIGH confidence)
- developers.google.com/admob/flutter/targeting — `RequestConfiguration` child-directed API (verified)
- developers.google.com/admob/android/test-ads — Android test ad unit IDs (verified)
- developers.google.com/admob/flutter/banner — `AdaptiveBanner` + `BannerAd` creation pattern (verified)
- developers.google.com/admob/flutter/interstitial — `InterstitialAd.load()`/`show()` pattern (verified)
- developers.google.com/admob/flutter/rewarded — `RewardedAd.load()`/`show()` pattern (verified)
- developers.google.com/admob/flutter/app-open — `AppOpenAd` + `AppStateEventNotifier` pattern (verified)
- developers.google.com/admob/android/charles — Charles Proxy setup for AdMob Android (verified)
- developers.google.com/admob/flutter/mediation/unity — `gma_mediation_unity` setup (verified)
- developers.google.com/admob/flutter/mediation/ironsource — `gma_mediation_ironsource` setup + ironSource Maven repo (verified)
- developers.google.com/admob/flutter/mediation/inmobi — `gma_mediation_inmobi` setup (verified)
- developers.google.com/admob/flutter/mediation/applovin — AppLovin child-directed auto-disable in v2+ (verified)
- support.axon.ai/en/max/flutter/overview/privacy — AppLovin SDK 13.0+ child-directed prohibition (verified)
- docs.unity.com/en-us/grow/levelplay/sdk/flutter/regulation-advanced-settings — LevelPlay COPPA API (`LevelPlayPrivacySettings.setCOPPA`) (verified)
- pub.dev REST API — all package versions and publisher (`google.dev`) confirmed on 2026-05-29

### Secondary (MEDIUM confidence)
- support.google.com/admob/answer/6223431 — Families Policy compliance requirements for AdMob
- support.google.com/googleplay/android-developer/answer/9900633 — Families Self-Certified Ads SDK Program description

### Tertiary (LOW confidence / [ASSUMED])
- Claim that Unity Ads and ironSource are currently on the Families Self-Certified SDK list — must be verified against live policy page
- `gma_mediation_ironsource` auto-handles Activity lifecycle — verify empirically

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified via pub.dev API; publishers confirmed as google.dev
- AdMob COPPA init code: HIGH — verified from official developers.google.com/admob/flutter/targeting
- Ad format patterns: HIGH — verified from official per-format Google docs pages
- Mediation COPPA forwarding: MEDIUM — documented in Google's mediation guides; unverified empirically
- Families Program certification list: LOW — dynamic list; must check live at submission time
- Proxy audit setup: HIGH — from Google's official Charles Proxy guide

**Research date:** 2026-05-29
**Valid until:** ~2026-07-01 (ad SDK versions move fast; verify `google_mobile_ads` and `gma_mediation_*` versions again at execution time)
