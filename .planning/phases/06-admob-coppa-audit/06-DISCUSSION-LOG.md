# Phase 6: AdMob & COPPA Audit - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-29
**Phase:** 6-AdMob & COPPA Audit
**Areas discussed:** Meta Audience Network, AdService interface shape, App Open ad flow, Ad unit IDs

---

## Meta Audience Network

| Option | Description | Selected |
|--------|-------------|----------|
| Exclude Meta entirely | Simplest path — AppLovin + Unity Ads still provide solid fill rate for a children's app. Meta's SDK has a history of COPPA scrutiny and child-directed mode disables most inventory. | ✓ |
| Include Meta with child-directed flags | Adds a third mediation partner. Requires AudienceNetworkAds.isChildDirected = true before loading ads. More moving parts to audit. | |
| Include as stub/placeholder only | Wire init code but no real ad unit IDs. Keeps door open without active traffic. | |

**User's choice:** Exclude Meta entirely

---

## AppLovin vs. Unity (follow-up)

| Option | Description | Selected |
|--------|-------------|----------|
| AppLovin — SDK present, init skipped entirely | Gated behind kAppLovinEnabled = false constant. Flip flag when API key arrives. | ✓ |
| AppLovin — SDK present, init runs with placeholder key | Silently fails. Easier to activate but may log errors. | |

**User's choice:** SDK present, init skipped entirely (kAppLovinEnabled = false)

**Notes (freeform user input):** User specified the full mediation lineup — AppLovin (disabled, pending account approval), Unity Ads, ironSource, InMobi. ironSource and InMobi are scope additions beyond original ADS-06/07 requirements. All active SDKs require their own COPPA/child-directed flags at init.

---

## AdService Interface Shape

### Banner ads

| Option | Description | Selected |
|--------|-------------|----------|
| Widget method on AdService — getBannerWidget() | AdMobAdService returns real AdWidget; StubAdService returns SizedBox.shrink(). Clean walled-garden separation. | ✓ |
| Screens use BannerAd directly | Breaks walled-garden pattern — screen code would import google_mobile_ads. | |

**User's choice:** getBannerWidget() returning Widget (Recommended)

### Rewarded ads

| Option | Description | Selected |
|--------|-------------|----------|
| Future<bool> showRewardedAd() | true = watched to completion, false = dismissed. Simple and testable. | ✓ |
| showRewardedAd({required VoidCallback onRewarded}) | Callback-based, mirrors native SDK pattern. Harder to test. | |
| Future<AdRewardResult> showRewardedAd() | Typed enum result (rewarded/dismissed/failed). Most explicit. | |

**User's choice:** Future<bool> showRewardedAd() (Recommended)

### Load vs. show pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Merged: showX() handles loading internally | No caller preloading burden. AdMobAdService pre-loads next ad after each show. | ✓ |
| Separate: loadX() + showX() | Explicit preload control. More burden on screen code to track load state. | |

**User's choice:** Merged load+show (Recommended)

---

## App Open Ad Flow

### Trigger mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| App resume only (AppLifecycleState.resumed) | No SplashScreen needed. Canonical App Open pattern. | ✓ |
| New SplashScreen on cold launch | Explicit cold-launch ad placement. Adds a new screen. | |
| Both: cold launch splash + app resume | Maximum impressions, maximum complexity. | |

**User's choice:** App resume only (Recommended)

### Gameplay suppression

| Option | Description | Selected |
|--------|-------------|----------|
| Suppress during active gameplay (GamePhase.playing or .paused) | Avoids ad over pause overlay. Check gameSessionProvider before showing. | ✓ |
| Always show on resume | Simpler. Ad may appear over pause overlay. | |

**User's choice:** Suppress during active gameplay (Recommended)

---

## Ad Unit IDs

### Test vs. production

| Option | Description | Selected |
|--------|-------------|----------|
| Test IDs only for now | SDK makes real network calls (sufficient for proxy audit). Production IDs swapped before submission. | ✓ |
| Real production IDs from AdMob console | Requires app registered in AdMob and ad units created. | |

**User's choice:** Test IDs only (Recommended)

### ID location

| Option | Description | Selected |
|--------|-------------|----------|
| lib/core/ads/ad_constants.dart | Named constants per format. Easy audit of test vs. production. Matches existing constants.dart pattern. | ✓ |
| Inline in AdMobAdService | Less indirection, harder to audit. | |

**User's choice:** lib/core/ads/ad_constants.dart (Recommended)

---

## Bonus Input: UX Recommendations Review

**User shared three UX recommendations received from an advisor:**
1. Zoom-dependent label culling for micro-states
2. Proximity snapping / 48dp hit targets for small countries
3. Ocean backfill to eliminate black letterboxing

**Outcome:** All three were already implemented in Phase 5 (D-V01, D-V02, D-V03). No action needed in Phase 6. The recommendations served as confirmation that Phase 5's canvas polish decisions were correct.

---

## Claude's Discretion

- Banner widget sizing: use `AdaptiveBanner` (width = screen width) rather than fixed 320×50
- COPPA init order: child-directed flags on all SDKs → `MobileAds.initialize()` → first ad loads
- App Open observer placement: root-level `WidgetsBindingObserver` (MyApp or root ConsumerStatefulWidget), not inside MapScreen
- Proxy audit checklist format: step-by-step mitmproxy/Charles instructions in the plan

## Deferred Ideas

None — discussion stayed within phase scope.
