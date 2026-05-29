# Phase 6: AdMob & COPPA Audit - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 delivers: the walled-garden ad layer fully wired — `StubAdService` replaced with `AdMobAdService`, Google Mobile Ads SDK initialized with child-directed flags, all four ad formats (banner, interstitial, rewarded, App Open) placed on the correct screens, Unity Ads + ironSource + InMobi mediation SDKs initialized with their own COPPA flags, AppLovin MAX SDK present but disabled pending account approval, a proxy audit confirming zero device identifier leakage, and the app ready for Google Play Families Program review.

**In scope:**
- Add `google_mobile_ads ^5.x` to pubspec.yaml
- Add Unity Ads, ironSource, InMobi, and AppLovin MAX mediation SDK packages to pubspec.yaml
- Redesign `AdService` interface: `getBannerWidget()` + `showInterstitialAd()` + `showRewardedAd()` + `showAppOpenAd()` (merged load+show pattern)
- `AdMobAdService` implementation replacing `StubAdService` as the live provider
- `lib/core/ads/ad_constants.dart` — named test ad unit ID constants for all 4 formats
- Child-directed init block: `tagForChildDirectedTreatment(true)`, `tagForUnderAgeOfConsent(true)`, `maxAdContentRating(G)` before `MobileAds.initialize()`; each mediation SDK initialized with its own COPPA flag
- AppLovin init gated behind `kAppLovinEnabled = false` constant (no API key yet)
- Banner ads placed on HomeScreen, ModeSelectionScreen, CompletionScreen — not on pause screen or during gameplay
- Interstitial ad fires at CompletionScreen (game-complete break point only)
- Rewarded ad triggered when hints exhausted (GAME-08 hint refill flow)
- App Open ad wired to `AppLifecycleState.resumed`; suppressed when GamePhase is playing or paused
- Proxy audit (manual): Charles Proxy / mitmproxy confirms zero GAID / IDFA / advertising_id in outbound ad traffic
- Verify `firebase_core` absent from pubspec.yaml and pubspec.lock (ADS-10)

**Out of scope:**
- Meta Audience Network — excluded entirely (decided in discussion)
- AppLovin live traffic — SDK present but disabled; real activation requires API key from pending account
- Real production ad unit IDs — Phase 6 uses test IDs; production IDs swapped before store submission
- SplashScreen widget — App Open uses app-resume trigger, no new screen needed
- Firebase of any kind (permanently excluded per architecture decision)
- Global leaderboards, IAP, online features

</domain>

<decisions>
## Implementation Decisions

### Mediation Partners

- **D-M01:** Meta Audience Network is **excluded entirely**. AppLovin + Unity Ads + ironSource + InMobi provide sufficient fill rate for a child-directed app. Meta's SDK adds COPPA scrutiny risk with minimal upside given child-directed inventory restrictions.
- **D-M02:** **AppLovin MAX** SDK is added to pubspec and its child-directed init code is written, but the entire init call is gated behind `const kAppLovinEnabled = false` in `lib/core/ads/ad_constants.dart`. When the AdMob account is approved and the API key arrives, flip the flag and add the key — no other code changes needed.
- **D-M03:** **Unity Ads**, **ironSource**, and **InMobi** are active mediation partners. Each must have its own COPPA / child-directed flag set in its initialization block, called before or alongside `MobileAds.initialize()`. These three are scope additions beyond the original ADS-06/07 requirements.
- **D-M04:** Every mediation SDK initialization must be verified in code before calling `MobileAds.initialize()`. AdMob does NOT cascade `tagForChildDirectedTreatment` to mediation partners — each SDK's own flag is mandatory.

### AdService Interface

- **D-A01:** `AdService` is redesigned with a **merged load+show** pattern. The interface exposes: `getBannerWidget()`, `showInterstitialAd()`, `Future<bool> showRewardedAd()`, `showAppOpenAd()`. Callers never think about preloading — `AdMobAdService` handles caching and pre-loading the next ad after each show internally.
- **D-A02:** **Banner ads** are exposed as `Widget getBannerWidget()`. `AdMobAdService` returns a real `AdWidget` wrapping an `AdaptiveBanner`; `StubAdService` returns `SizedBox.shrink()`. Screens embed the widget in their layout — no platform view leaking into screen code, no direct `google_mobile_ads` import outside `features/ads/`.
- **D-A03:** **Rewarded ads** use `Future<bool> showRewardedAd()`. Returns `true` if the user watched to completion and earned the reward; `false` if dismissed or ad failed to load. Caller in MapScreen/hint flow: `if (await adService.showRewardedAd()) { grantHint(); }`. Testable and clean.
- **D-A04:** The existing `AdLoadState` sealed class (`AdLoaded`, `AdFailed`) is retained for internal use inside `AdMobAdService`; it is not part of the public `AdService` interface (callers only see `bool` or `Widget`).

### App Open Ad Flow

- **D-O01:** App Open ad fires on **app resume from background only** (`AppLifecycleState.resumed`). No cold-launch SplashScreen is needed. This is the canonical App Open pattern — natural break point, user actively chose to return.
- **D-O02:** App Open ad is **suppressed when a game session is active**. Before calling `showAppOpenAd()`, check `gameSessionProvider` state: if `GamePhase.playing` or `GamePhase.paused`, skip the ad entirely. The game already auto-pauses on background (Phase 5); showing an ad over the pause overlay would be jarring.
- **D-O03:** The `WidgetsBindingObserver` in `_MapScreenState` (added in Phase 5 for auto-pause) already detects `AppLifecycleState.resumed`. App Open logic should be placed in a higher-level observer — either `MyApp` level or a dedicated `AppLifecycleService` — so it fires regardless of which screen is active, not only when MapScreen is mounted.

### Ad Unit IDs

- **D-I01:** Phase 6 uses **AdMob test ad unit IDs** for all four formats. Test IDs cause the SDK to make real network requests (sufficient for proxy audit) without serving real inventory. Constants in `lib/core/ads/ad_constants.dart`:
  - `kBannerAdUnitId` — test banner ID
  - `kInterstitialAdUnitId` — test interstitial ID
  - `kRewardedAdUnitId` — test rewarded interstitial ID
  - `kAppOpenAdUnitId` — test app open ID
  - `kAppLovinSdkKey` — empty string (AppLovin disabled)
- **D-I02:** Before Google Play submission, swap the test constants to real production ad unit IDs from the AdMob console. No other code changes needed.

### Ad Placement Rules (from requirements, confirmed in discussion)

- **D-P01:** Banners appear on: HomeScreen, ModeSelectionScreen, CompletionScreen. Never on the pause screen. Never during active gameplay (MapScreen while session is playing).
- **D-P02:** Interstitial fires once at the CompletionScreen (natural game-complete break). Never mid-round, never on app open before first interaction.
- **D-P03:** Rewarded interstitial is offered when hint count reaches zero (GAME-08 hint refill flow). User who watches earns a refill; user who dismisses receives nothing.
- **D-P04:** App Open fires on app resume, suppressed during active gameplay (D-O02).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 6 Requirements & Scope
- `.planning/ROADMAP.md` §Phase 6 — Phase goal, requirements list (ADS-01–ADS-10), 6 success criteria
- `.planning/REQUIREMENTS.md` §Monetization & Compliance (ADS-01–ADS-10) — full requirement text

### Architecture (LOCKED)
- `CLAUDE.md` §Critical Architecture Decisions — D4 (ad walled garden: zero imports from `features/ads/` in `GameSessionNotifier`), D5 (no Firebase, ever)
- `CLAUDE.md` §COPPA / Families Policy Non-Negotiables — `tagForChildDirectedTreatment(true)` on AdMob AND each mediation SDK, `AD_ID` blocked, interstitial placement rules, App Open rules

### Foundation (what Phase 6 builds on)
- `lib/core/ads/ad_service.dart` — current `AdService` abstract interface + `StubAdService`; Phase 6 redesigns this interface and adds `AdMobAdService`
- `lib/core/ads/ad_service_provider.dart` — current provider returning `StubAdService()`; Phase 6 swaps to `AdMobAdService`
- `lib/core/ads/ad_load_state.dart` — `AdLoadState` sealed class; retained for internal use
- `lib/features/map/map_screen.dart` — `_MapScreenState` with `WidgetsBindingObserver` (Phase 5); Phase 6 adds App Open trigger at a higher widget-tree level
- `lib/features/game/game_session_notifier.dart` — `GamePhase` enum; Phase 6 reads phase state to suppress App Open during gameplay
- `lib/features/home/home_screen.dart` — Phase 6 adds `getBannerWidget()` embed
- `lib/features/map/completion_screen.dart` — Phase 6 adds `showInterstitialAd()` call on game-complete
- `android/app/src/main/AndroidManifest.xml` — `AD_ID` already blocked via `tools:remove` (Phase 5); verify still present

### Prior Context
- `.planning/phases/05-session-polish-accessibility/05-CONTEXT.md` — D-P04 (auto-pause on background), `WidgetsBindingObserver` placement, `AppLifecycleState.paused` wiring

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/core/ads/ad_service.dart` — `AdService` abstract interface is already the right abstraction boundary. Phase 6 extends its method signatures rather than replacing the file wholesale.
- `lib/core/ads/ad_service_provider.dart` — Single provider swap: change `const StubAdService()` to `AdMobAdService()`. All consumer screens already read from `adServiceProvider` — no screen-level changes for the wiring.
- `lib/features/game/game_session_notifier.dart` — `GamePhase` is already accessible via Riverpod. App Open suppression just reads `ref.read(gameSessionProvider).value?.phase`.
- `lib/core/constants.dart` — Established pattern for app-wide constants (e.g., `kPrivacyPolicyUrl` from Phase 5). `lib/core/ads/ad_constants.dart` follows the same convention.

### Established Patterns
- Abstract interface + stub: `AdService`/`StubAdService` pattern is already in place and followed by `AudioService`/`StubAudioService`. `AdMobAdService` is a third implementation of the same pattern.
- Walled garden: zero imports of `google_mobile_ads` outside `lib/core/ads/` and `lib/features/ads/`. All screen code calls `AdService` methods only.
- `WidgetsBindingObserver` in `_MapScreenState` (Phase 5): App Open observer should live higher in the tree (e.g., `MyApp` or a root-level `ConsumerStatefulWidget`) so it fires regardless of active screen.

### Integration Points
- `adServiceProvider` swap in `lib/core/ads/ad_service_provider.dart` — one line change, all consumers updated automatically.
- `showInterstitialAd()` call in `completion_screen.dart` — call once when the screen first mounts (game-complete event). Not on every rebuild.
- `getBannerWidget()` in HomeScreen, ModeSelectionScreen, CompletionScreen — embed as a `SizedBox`-constrained bottom widget (e.g., `ConstrainedBox(constraints: BoxConstraints(maxHeight: 60), child: adService.getBannerWidget())`).
- `showRewardedAd()` in the hint-exhausted flow — already has a call site from Phase 4's hint button; Phase 6 replaces the stub no-op with the real call.
- App Open observer at `MyApp` / root level — listen to `AppLifecycleState.resumed`, check `GamePhase`, call `adService.showAppOpenAd()`.

</code_context>

<specifics>
## Specific Ideas

- **AppLovin disable flag:** `const kAppLovinEnabled = false` in `lib/core/ads/ad_constants.dart`. The entire AppLovin init block is wrapped in `if (kAppLovinEnabled) { ... }`. When account is approved: set to `true`, add the real SDK key to `kAppLovinSdkKey`.
- **Proxy audit instructions:** The plan should include a short checklist: (1) Install mitmproxy or Charles Proxy on the dev machine, (2) Configure Android emulator/device HTTP proxy, (3) Install the proxy CA cert on the device, (4) Launch the app and play through a session, (5) Filter traffic for the domains `googleads.g.doubleclick.net`, `pubads.g.doubleclick.net`, `unity3d.com`, `ironsrc.com`, `inmobi.com` and confirm no request body or query param contains `gaid`, `idfa`, `advertising_id`, `device_id`, or `android_id`.
- **COPPA init order:** Init sequence must be: set child-directed flags on each SDK → call `MobileAds.initialize()` → load first ads. If any SDK is initialized after `MobileAds.initialize()`, child-directed treatment may not propagate correctly.
- **Interstitial on CompletionScreen:** Call `showInterstitialAd()` in `initState` or via a `ref.listenSelf` that fires once when the screen mounts. Do NOT call it in `build()` — that would fire on every rebuild.
- **Banner size:** Use `AdaptiveBanner` (width = screen width) rather than fixed 320×50. Adapts to different screen sizes and generally yields better CPM for a child-directed app.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

## Plans

**Planned:** 2026-05-29
**Wave structure:** 3 waves, 4 plans total

| Wave | Plan | Objective | Autonomous |
|------|------|-----------|------------|
| 1 | 06-01-PLAN.md | pubspec packages + ironSource Maven repo + AndroidManifest + network_security_config + ad_constants.dart + initializeAds() + RED test stubs | yes |
| 2 | 06-02-PLAN.md | AdService interface redesign + AdMobAdService implementation + StubAdService extracted + provider swap | yes |
| 2 | 06-03-PLAN.md | app.dart ConsumerStatefulWidget + App Open observer + banner/interstitial/rewarded screen wiring + GameSessionNotifier.refillHints() | yes |
| 3 | 06-04-PLAN.md | GREEN tests + manifest checks + firebase absence check + proxy audit checkpoint + ADS requirements sign-off | no (human checkpoint) |

**Key files created:**
- `lib/core/ads/ad_constants.dart` — ad unit ID constants + kAppLovinEnabled gate (06-01)
- `lib/core/ads/admob_ad_service.dart` — live AdMobAdService (06-02)
- `lib/core/ads/stub_ad_service.dart` — extracted StubAdService (06-02)
- `lib/core/ads/app_state_observer.dart` — AppStateEventNotifier re-export (06-03)
- `android/app/src/main/res/xml/network_security_config.xml` — debug CA trust (06-01)
- `test/unit/ad_service_test.dart` — RED stubs → GREEN after 06-02 (06-01)

**Key files modified:**
- `pubspec.yaml` — 5 new packages (06-01)
- `android/build.gradle.kts` — ironSource Maven repo (06-01)
- `android/app/src/main/AndroidManifest.xml` — AdMob App ID + networkSecurityConfig (06-01)
- `lib/main.dart` — initializeAds() before runApp() (06-01)
- `lib/core/ads/ad_service.dart` — redesigned interface (06-02)
- `lib/core/ads/ad_service_provider.dart` — AdMobAdService (06-02)
- `lib/app.dart` — ConsumerStatefulWidget + App Open observer (06-03)
- `lib/features/home/home_screen.dart` — banner (06-03)
- `lib/features/map/completion_screen.dart` — ConsumerStatefulWidget + banner + interstitial (06-03)
- `lib/features/map/map_screen.dart` — rewarded ad wiring (06-03)
- `lib/features/game/game_session_notifier.dart` — refillHints() (06-03)

---

*Phase: 6-AdMob & COPPA Audit*
*Context gathered: 2026-05-29*
