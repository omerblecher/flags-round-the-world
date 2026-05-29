---
phase: "06-admob-coppa-audit"
plan: "03"
subsystem: "ads-screen-wiring"
tags: ["ads", "app-open", "banner", "interstitial", "rewarded", "riverpod", "COPPA"]
dependency_graph:
  requires: ["06-01", "06-02"]
  provides: ["screen-level ad wiring", "app-open lifecycle observer", "hint refill via rewarded"]
  affects: ["lib/app.dart", "lib/features/home/home_screen.dart", "lib/features/map/completion_screen.dart", "lib/features/map/map_screen.dart", "lib/features/game/game_session_notifier.dart"]
tech_stack:
  added: ["lib/core/ads/app_state_observer.dart (re-export shim)"]
  patterns:
    - "ConsumerStatefulWidget lifecycle for AdMob AppStateEventNotifier subscription"
    - "addPostFrameCallback for interstitial trigger (never in build)"
    - "Conditional cast (adService is AdMobAdService) for loadBannerForWidth"
    - "Walled-garden re-export: AppStateEventNotifier exposed via lib/core/ads/ only"
key_files:
  created:
    - "lib/core/ads/app_state_observer.dart"
  modified:
    - "lib/app.dart"
    - "lib/features/game/game_session_notifier.dart"
    - "lib/features/home/home_screen.dart"
    - "lib/features/map/completion_screen.dart"
    - "lib/features/map/map_screen.dart"
decisions:
  - "Use re-export shim (app_state_observer.dart) so app.dart never directly imports google_mobile_ads"
  - "CompletionScreen converted to ConsumerStatefulWidget (not wrapped in Consumer) for consistency with Riverpod patterns"
  - "Banner added below privacy footer in HomeScreen Column (not inside Expanded) so it never competes for scroll space"
  - "Use AsyncValue.value (not .valueOrNull) for Riverpod 3.x compatibility"
metrics:
  duration: "~20 minutes"
  completed: "2026-05-29"
  tasks_completed: 3
  files_modified: 6
requirements_met: ["ADS-01", "ADS-02", "ADS-03", "ADS-04"]
---

# Phase 06 Plan 03: Ad Screen Wiring Summary

**One-liner:** App Open lifecycle observer via ConsumerStatefulWidget, banner+interstitial on HomeScreen/CompletionScreen, rewarded ad wired to GameSessionNotifier.refillHints().

## Tasks Completed

### Task 1: Add refillHints() + convert app.dart to ConsumerStatefulWidget
**Commit:** `0b0641b` + `0fcfa22` (Rule 1 fix)

- Added `refillHints()` to `GameSessionNotifier` — restores `hintsRemaining` to 2; no-ops outside `GamePhase.playing`; zero ad imports in notifier
- Created `lib/core/ads/app_state_observer.dart` as a thin re-export shim exposing `AppStateEventNotifier` and `AppState` from `google_mobile_ads` inside the walled garden
- Rewrote `lib/app.dart`: `App extends ConsumerStatefulWidget`, `_AppState` subscribes to `AppStateEventNotifier.appStateStream` in `initState()`, cancels subscription in `dispose()`
- `_onAppResumed()` reads `gameSessionProvider.value?.phase` and suppresses App Open ad when `playing` or `paused` (D-O02)
- Zero `google_mobile_ads` imports in `app.dart` — SDK reference is in `app_state_observer.dart` only

### Task 2: Banner on HomeScreen + ConsumerStatefulWidget CompletionScreen
**Commit:** `fabc668`

- `HomeScreen`: added `didChangeDependencies()` to call `loadBannerForWidth()` on `AdMobAdService` conditional cast; embedded `getBannerWidget()` in `Align(bottomCenter)` below privacy footer
- `CompletionScreen`: converted from `StatefulWidget` to `ConsumerStatefulWidget` (state class from `State<>` to `ConsumerState<>`); added `flutter_riverpod`, `ad_service_provider.dart`, `admob_ad_service.dart` imports
- `initState()`: added `addPostFrameCallback` to call `showInterstitialAd()` once on mount (D-P02 — never in `build()`)
- `didChangeDependencies()`: calls `loadBannerForWidth()` on `AdMobAdService` conditional cast
- `build()`: added `Positioned(left:0, right:0, bottom:0)` banner widget in Stack body

### Task 3: Wire rewarded ad in MapScreen hint-exhausted flow
**Commit:** `d0b129b`

- Replaced placeholder comment in `_useHint()` with live `refillHints()` call
- `earned == true` path now calls `ref.read(gameSessionProvider.notifier).refillHints()`
- `earned == false` path shows `hintAdFailed` snackbar unchanged
- No banner added to `MapScreen` (D-P01 — banners excluded during gameplay and pause)
- `ad_load_state.dart` import already removed by 06-02 (no further action needed)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Riverpod 3.x lacks `valueOrNull` getter**
- **Found during:** Overall verification (`flutter analyze` after all tasks)
- **Issue:** Plan specified `ref.read(gameSessionProvider).valueOrNull?.phase` in `_onAppResumed()`. Riverpod 3.x `AsyncValue` does not expose `.valueOrNull` — the correct getter is `.value` (returns `T?`)
- **Fix:** Changed `gameSessionProvider).valueOrNull?.phase` to `gameSessionProvider).value?.phase` in `lib/app.dart`
- **Files modified:** `lib/app.dart`
- **Commit:** `0fcfa22`

## Verification Results

```
flutter analyze lib/app.dart lib/features/home/home_screen.dart lib/features/map/completion_screen.dart lib/features/map/map_screen.dart lib/features/game/game_session_notifier.dart lib/core/ads/app_state_observer.dart
→ No issues found!

grep -rn "google_mobile_ads" lib/features/ lib/app.dart --include="*.dart"
→ (no output — PASS)

flutter test test/architecture/ads_isolation_test.dart
→ All tests passed!

grep -c "refillHints" lib/features/game/game_session_notifier.dart → 1
grep -c "showRewardedAd" lib/features/map/map_screen.dart → 1
grep -c "showInterstitialAd" lib/features/map/completion_screen.dart → 1
```

## Known Stubs

None — all ad method calls are wired through the real `AdService` interface. `StubAdService` is used at runtime until 06-02's `adServiceProvider` wires `AdMobAdService`, which is transparent to these screens.

## Threat Flags

No new threat surface introduced. All four STRIDE mitigations from the plan's threat register are implemented:
- T-06-09: `_onAppResumed()` checks phase before `showAppOpenAd()` — D-O02 enforced
- T-06-10: `showInterstitialAd()` via `addPostFrameCallback` in `initState()` — D-P02 enforced
- T-06-11: Banner only on HomeScreen and CompletionScreen bottom; MapScreen has no banner — D-P01 enforced
- T-06-12: `refillHints()` called only when `showRewardedAd()` returns `true`

## Commits

| Hash | Message |
|------|---------|
| `0b0641b` | feat(ads): add refillHints(), App Open observer in ConsumerStatefulWidget app.dart |
| `fabc668` | feat(ads): banner + interstitial on HomeScreen and CompletionScreen |
| `d0b129b` | feat(ads): wire showRewardedAd() + refillHints() in hint-exhausted flow |
| `0fcfa22` | fix(ads): use AsyncValue.value instead of .valueOrNull in _onAppResumed |

## Self-Check: PASSED

- `lib/core/ads/app_state_observer.dart` — created, verified exists
- `lib/app.dart` — ConsumerStatefulWidget, AppStateEventNotifier subscribed, zero google_mobile_ads
- `lib/features/game/game_session_notifier.dart` — refillHints() method present, zero ad imports
- `lib/features/home/home_screen.dart` — getBannerWidget + loadBannerForWidth present
- `lib/features/map/completion_screen.dart` — ConsumerStatefulWidget, showInterstitialAd in initState, getBannerWidget in Stack
- `lib/features/map/map_screen.dart` — showRewardedAd + refillHints wired, no banner
- Commits `0b0641b`, `fabc668`, `d0b129b`, `0fcfa22` verified in git log
- Architecture test passes
- `flutter analyze` zero issues on all 6 files
