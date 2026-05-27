# Domain Pitfalls

**Domain:** Flutter cross-platform educational mobile game (kids, COPPA + Google Play Families)
**Researched:** 2026-05-27
**Confidence note:** WebSearch and WebFetch were unavailable in this research session. All findings are drawn from training knowledge (cutoff August 2025) cross-referenced against known official policy documents, AdMob SDK documentation, Flutter framework internals, and Flutter community post-mortems. Confidence levels are assigned per finding. Flag items marked LOW for independent verification before implementation.

---

## Critical Pitfalls

Mistakes that cause store rejections, FTC violations, or complete rewrites.

---

### Pitfall C-1: tagForChildDirectedTreatment Does NOT Cascade to All Mediation Networks Automatically

**Confidence:** HIGH

**What goes wrong:**
Setting `RequestConfiguration.Builder().setTagForChildDirectedTreatment(TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE)` at AdMob initialization only signals child-directed treatment to Google's own ad serving. Each third-party mediation adapter (AppLovin, Unity Ads, Meta Audience Network) has its own SDK initialization path and its own child-directed flag. If those flags are not set independently, the mediated SDKs may serve behaviorally targeted, non-COPPA-compliant ads to children regardless of the AdMob-level flag.

**Why it happens:**
Developers read AdMob's initialization guide, set the single global flag, and assume mediation inherits it. The AdMob mediation architecture passes a "hints" object to adapters, but adapter compliance is not guaranteed — each adapter vendor is independently responsible for honoring it, and several historically did not until forced by policy updates.

**Consequences:**
- FTC COPPA violation: potential civil penalties up to $51,744 per violation per child (as of 2024 FTC schedule)
- Google Play Families Policy violation: immediate app suspension from the Families program
- App removal from Play Store with no grace period on first offense in severe cases

**Prevention:**
1. AppLovin MAX: Set `AppLovinPrivacySettings.setIsAgeRestrictedUser(true)` before `AppLovinSdk.getInstance(context).initialize(...)`. This is separate from the AdMob flag.
2. Unity Ads: Call `UnityAds.setPrivacyConsent(...)` with the COPPA/COPPA_APPLIES metadata before initialization.
3. Meta Audience Network: Call `AdSettings.setDataProcessingOptions(new String[]{}, 0, 0)` to opt out of all data processing AND explicitly set `AdSettings.setMixedAudience(true)` for mixed-audience apps, or restrict the audience. As of Meta AN SDK 6.x, for apps directed at children, you must pass an empty data processing options array AND set mixed audience. Do NOT rely on AdMob passing this through.
4. Verify each adapter's COPPA/child-directed API in their respective documentation at integration time — these APIs change between major SDK versions.
5. Test using the AdMob test suite and network-level traffic inspection (Charles Proxy / mitmproxy) to verify no GAID or IDFA is transmitted in ad request payloads.

**Detection:**
- Intercept ad request traffic with a proxy. Any request containing `gaid`, `idfa`, `advertising_id`, or behavioral targeting parameters is a red flag.
- AdMob's Ad Inspector tool (accessible via `MobileAds.openAdInspector(context)`) shows which network served each ad but does not verify child-directed compliance at the network level.

**Phase:** Must be addressed in the AdMob integration phase. Do not ship to any test track without verifying all three mediation networks separately.

---

### Pitfall C-2: Meta Audience Network SDK Is Not Safe for Child-Directed Apps Without Explicit Configuration

**Confidence:** HIGH

**What goes wrong:**
Meta Audience Network (MAN) SDK by default collects device identifiers, app event data, and behavioral signals. Including it in a COPPA-covered app without disabling all data collection causes violations. Even in "child-directed mode," older versions of the MAN SDK had known issues where limited data processing was not fully enforced.

**Why it happens:**
Meta's SDK auto-initializes and starts data collection at app startup before your code runs, unless explicitly disabled.

**Consequences:**
- FTC COPPA violation
- Google Play Families Policy rejection: Google audits whether included SDKs are on the approved-for-families list. Meta Audience Network has had periods of being conditionally approved/disapproved. Verify current status before submission.

**Prevention:**
- Call `AdSettings.setDataProcessingOptions(new String[]{})` before ANY other Meta SDK call or AdMob initialization
- Set `AdSettings.setMixedAudience(true)` if your app has both child and adult users (which "ages 8+" qualifies as)
- Audit Meta AN SDK version: use the latest stable release that explicitly lists COPPA support in its changelog
- Consider whether Meta AN is worth the compliance risk vs. the revenue benefit for a children's app. Many compliant kids apps drop Meta AN and substitute ironSource or InMobi (which have explicit COPPA-safe modes)

**Detection:**
- Meta SDK emits log warnings about "Limited Data Use" mode if set correctly — check logcat for `FacebookSdk` or `AudienceNetwork` log tags
- Network traffic inspection: Meta's servers are `graph.facebook.com` and `an.facebook.com`; verify no PII or GAID in request bodies

**Phase:** Research/decision phase before AdMob integration. Decide whether to include Meta AN at all given compliance complexity.

---

### Pitfall C-3: AppLovin Has Had FTC COPPA Enforcement Actions

**Confidence:** HIGH (FTC action is public record)

**What goes wrong:**
AppLovin was part of a 2022 FTC sweep of mobile ad networks for COPPA violations related to tracking children in apps directed at children. While AppLovin settled and updated its SDK, the enforcement history means their SDK warrants extra scrutiny. AppLovin MAX's COPPA/child-directed mode must be explicitly activated — it is not the default.

**Consequences:**
- Using AppLovin MAX without child-directed mode enabled exposes you to the same violation patterns the FTC already penalized
- Google Play Families Policy requires that ALL ad SDKs in the app are on Google's approved list and are configured correctly

**Prevention:**
- Always call `AppLovinPrivacySettings.setIsAgeRestrictedUser(true)` before SDK init
- Pin to AppLovin MAX SDK versions that explicitly list COPPA compliance in release notes (verify at integration time)
- Review AppLovin's current status on Google Play's [Families Ads Program approved ad SDKs list](https://support.google.com/googleplay/android-developer/answer/9893335) — this list changes

**Detection:**
- AppLovin SDK logs: look for "Age Restricted User" confirmation in logcat
- AppLovin's dashboard shows whether child-directed treatment is active per placement

**Phase:** AdMob/mediation integration phase.

---

### Pitfall C-4: Firebase Analytics Collects Prohibited Data for Children By Default

**Confidence:** HIGH

**What goes wrong:**
Firebase Analytics automatically collects: App Instance ID (a persistent device-linked identifier), GAID/IDFA, device fingerprint data, session data, user properties, and event streams. For COPPA-covered apps (those directed at or mixed audiences including children under 13), collecting any persistent identifier or behavioral data without verifiable parental consent is a violation. Firebase Analytics has no "child-safe mode" — you must either disable it entirely or replace it with a compliant alternative.

**Why it happens:**
Flutter apps commonly add `firebase_analytics` as a default dependency. The `FlutterFire` setup guide does not prominently warn about COPPA implications.

**Consequences:**
- COPPA violation: App Instance IDs are "persistent identifiers" under COPPA's definition, even if not "personal information" in common parlance
- Google Play Families Policy: apps in the Families program that include data-collecting SDKs not on the approved list are rejected

**Prevention:**
- Do NOT include `firebase_analytics` or `firebase_core` in your Flutter project unless you disable all data collection at init: `await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false)` — but note this still initializes the SDK and may still generate an App Instance ID
- The safest approach: do not include Firebase Analytics at all. Use a privacy-first alternative like [Countly](https://countly.com) with local-only mode, or no analytics at all (this project is offline-first anyway)
- If you need crash reporting, Crashlytics also uses Firebase and shares the same concerns — see Pitfall C-5

**Detection:**
- Search your `pubspec.yaml` for `firebase_analytics`, `firebase_core`, `firebase_crashlytics`
- Check Flutter's generated `android/app/google-services.json` — its presence means Firebase is initialized

**Phase:** Foundation/project setup phase. Exclude Firebase from the dependency list from day one.

---

### Pitfall C-5: Crashlytics Is Not COPPA-Safe Without Configuration

**Confidence:** HIGH

**What goes wrong:**
Firebase Crashlytics collects: device model, OS version, crash stack traces, custom log messages, and crucially — a Crashlytics Installation UUID that is a persistent identifier. Under COPPA, persistent identifiers tied to devices used by children require parental consent before collection. Crashlytics does not have a "child-directed mode."

**Prevention:**
- Either exclude Crashlytics entirely, or use a COPPA-compliant crash reporting alternative
- Sentry has a "data scrubbing" mode but still collects device identifiers by default — requires custom configuration
- For a game this simple, structured logcat output reviewed via Play Console's Android Vitals (which is aggregated and not user-linked) may be sufficient for crash monitoring without any SDK

**Detection:**
- `firebase_crashlytics` in `pubspec.yaml`

**Phase:** Foundation phase. Decision must be made before any SDK is added.

---

### Pitfall C-6: Google Play Families Program Review Takes 2–4+ Weeks and Can Reject for Non-Obvious Reasons

**Confidence:** MEDIUM (timeline varies; process is documented)

**What goes wrong:**
The Google Play Families program has a separate review process beyond standard app review. Apps are evaluated against the Families Policy by a dedicated team. Common rejection reasons that surprise developers:

1. **Ad network not on the approved list** — even if AdMob itself is approved, a mediation adapter whose SDK is not on Google's Families-approved SDK list causes rejection
2. **Interstitial ad timing** — interstitials shown "unexpectedly" during gameplay (not at natural pause points) violate Families Policy. For a flag-matching game, showing an interstitial while a drag is in progress or immediately when the game loads would be rejected
3. **App Open Ads** — App Open ads shown immediately on launch without a "splash/loading" context are under heightened scrutiny for kids apps. The policy states ads must not be shown "before the user can interact with the app." An App Open Ad that covers the first screen before any game content loads is a common rejection cause
4. **Content rating mismatch** — IARC rating must be "Everyone" or "Everyone 10+" to qualify for Families. If any content (including ad content if it slips through) triggers a higher rating, rejection occurs
5. **Missing privacy policy** — a publicly accessible privacy policy URL is mandatory and must accurately describe data practices

**Consequences:**
- 2–4 week delay per rejection cycle
- Multiple rejections can push launch dates significantly

**Prevention:**
- Submit to the Families program only after testing ad timing against the policy
- Interstitials: only show at level-complete screens, never during active gameplay
- App Open Ads: show only after a genuine loading/splash period, never instantly on cold start
- Get a legal review of the privacy policy before submission
- Check the current approved ad SDK list the week before submission (it is a living document)

**Phase:** Pre-launch / store submission phase. The review process itself is the pitfall — build ad timing logic correctly from the start.

---

### Pitfall C-7: GAID Collection by Any SDK Violates COPPA Even Without "Intentional" Use

**Confidence:** HIGH

**What goes wrong:**
The Google Advertising ID (GAID) is a "persistent identifier" under COPPA's definition. Any SDK that reads `AdvertisingIdClient.getAdvertisingIdInfo()` — even for crash deduplication or analytics, not advertising — is collecting a prohibited identifier from children without consent.

**Why it happens:**
Many utility SDKs (analytics, attribution, A/B testing frameworks) read the GAID as a matter of routine even when not explicitly configured for advertising.

**Prevention:**
- Audit every SDK added to the project with `grep -r "getAdvertisingIdInfo\|AdvertisingIdClient" android/` after adding dependencies
- Use `android.permission.AD_ID` permission (required since Android 13) — if this permission is NOT in your manifest, the GAID is not accessible to your app or any SDK. For a Families app, explicitly add `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:remove="true"/>` to block it from merged manifests
- Review all transitive dependencies: `./gradlew dependencies` to see what your dependencies depend on

**Detection:**
- `aapt dump permissions your.apk | grep AD_ID` — if this appears, some dependency declared it
- Network traffic inspection for `advertising_id` fields in outbound requests

**Phase:** Foundation phase and every phase where new SDKs are added.

---

## Critical Pitfall: Flutter Technical

---

### Pitfall T-1: Draggable + DragTarget Break Under InteractiveViewer Transforms

**Confidence:** HIGH (well-documented Flutter issue)

**What goes wrong:**
Flutter's `Draggable`/`DragTarget` system operates in global screen coordinates. When you wrap your world map in an `InteractiveViewer` (for pinch-zoom and pan), the coordinate system of the transformed canvas diverges from the global screen coordinate system. `DragTarget`'s `onWillAccept`/`onAccept` callbacks receive the drag position in global coordinates, but the map's hit-test regions have been scaled and translated by the `InteractiveViewer`'s transform matrix. The result: a flag dragged over a country visually appears to be "on" it, but the `DragTarget` never fires because the hit-test uses untransformed coordinates.

**Why it happens:**
`Draggable` uses `Overlay` to render the dragged widget at the top of the widget tree, far above the `InteractiveViewer`. The drag feedback renders correctly, but the hit detection does not go through the transform.

**Consequences:**
This is the core gameplay mechanic. If it doesn't work under zoom, the game is unplayable when users zoom into crowded regions (Europe, Southeast Asia).

**Prevention:**
- Do NOT use `Draggable`/`DragTarget` with `InteractiveViewer` for the map targets. This combination is fundamentally broken for transformed canvases.
- **Recommended approach:** Implement drag detection manually using `GestureDetector` with `onPanStart`/`onPanUpdate`/`onPanEnd`, and perform hit-testing manually by applying the inverse of the `InteractiveViewer`'s `TransformationController.value` matrix to the pointer position before checking which country path contains the point.
- The `TransformationController` exposes the current 4x4 transform matrix. Use `Matrix4.inverted(controller.value).transform3(vector)` to convert screen coordinates to canvas coordinates for hit-testing.
- Maintain a separate list of country bounding boxes or path bounds in canvas coordinates; hit-test in canvas space after inverse-transforming the drop point.

**Detection:**
- Test drag-and-drop at 3x zoom immediately after building the first interactive map prototype. This will fail if you used standard Draggable/DragTarget.

**Phase:** Core gameplay mechanic phase. Architecture decision must be made before any drag-drop code is written.

---

### Pitfall T-2: SVG World Map With 195 Paths Causes Frame Drops During Pinch-Zoom

**Confidence:** HIGH

**What goes wrong:**
`flutter_svg` renders SVG by parsing the SVG XML and generating Flutter canvas draw calls (`Path`, `drawPath`, etc.) on every build. With a world map SVG containing 195+ country path elements (each with complex polygon coordinates), re-rendering on every `InteractiveViewer` transform update (every pointer event during pinch-zoom) triggers 195 path rebuilds per frame. On mid-range Android devices, this easily drops below 30fps.

**Why it happens:**
`flutter_svg` does not cache the parsed path objects between renders by default in older versions. Even with caching enabled, `drawPath` calls for 195 complex paths on every frame is expensive.

**Consequences:**
Jank during zoom and pan destroys the UX for Europe/Asia where users need to zoom in to distinguish small countries. A game where the core interaction feels laggy is not commercially viable.

**Prevention:**
1. **Use `flutter_svg` with `SvgPicture` and a `RepaintBoundary` wrapper** to prevent unnecessary repaints from parent rebuilds.
2. **Pre-cache SVG pictures** using `precachePicture` at app startup. `flutter_svg` supports `SvgPicture.asset` which internally caches the parsed `DrawableRoot`.
3. **Separate concerns:** Use two layers. The static world map (country fills, borders) is one cached layer. Interactive overlays (selected state highlight, drop targets) are a second layer. Only the overlay repaints during interaction.
4. **Consider a pre-rasterized tile approach:** Convert the world map SVG to a set of PNG tiles at multiple zoom levels. This is the approach used by mapping apps. SVG is excellent for small-screen assets (flags) but may be wrong for a world map used in a pan-zoom context.
5. **Custom `CustomPainter` with path caching:** Parse the SVG once at init, store `Path` objects in memory, and paint them directly in `CustomPainter.paint()`. `CustomPainter` with `shouldRepaint` returning false for non-interactive frames is much faster than rebuilding SVG trees.

**Detection:**
- Run `flutter run --profile` on a mid-range Android device (not a flagship) and use Flutter DevTools timeline while doing pinch-zoom. Frame time > 16ms signals a problem.
- The Pixel 3a or a Galaxy A-series device is a representative "mid-range" target.

**Phase:** Core map implementation phase. Architecture decision (SVG vs rasterized vs CustomPainter) must be made before map rendering code is written.

---

### Pitfall T-3: Coordinate Space Transformation Errors During Zoom/Pan

**Confidence:** HIGH

**What goes wrong:**
When a user drops a flag, the drop point arrives as a global screen coordinate (from the gesture system). The world map is rendered in a canvas coordinate system that has been scaled and translated. Converting between these coordinate spaces is a source of persistent bugs:

- Off-by-one in the order of operations (scale before translate vs. translate before scale)
- Forgetting that `InteractiveViewer`'s transform includes both the user's zoom/pan AND the initial fit-to-screen scaling
- Using `RenderBox.globalToLocal()` without accounting for the `InteractiveViewer` transform on top of normal widget positioning
- The anchor point for scaling (the focal point of a pinch gesture) changes with each gesture, creating a composed transform that accumulates floating-point drift

**Prevention:**
- Use `TransformationController.toScene(Offset globalPoint)` — this is the correct API for converting a global pointer position to the scene (canvas) coordinate. Using `globalToLocal` on a widget inside `InteractiveViewer` gives the widget-local coordinate, not the scene coordinate — these are NOT the same after a user-initiated zoom.
- Write coordinate space conversion unit tests immediately. Assert that `toScene(controller.toViewport(knownPoint)) == knownPoint` for several known points.
- Store all country boundary data in a consistent canonical coordinate space (e.g., normalized 0–1 coordinates, or the native SVG viewBox coordinate system).

**Detection:**
- The drop lands visibly on the wrong country
- Drop targets near the edges of the visible viewport fail while center targets work
- Behavior is correct at zoom=1 but wrong at zoom=2 or 3

**Phase:** Core map and drag-drop phase.

---

### Pitfall T-4: "Phantom Drag" Artifacts From Overlay Cleanup Failures

**Confidence:** MEDIUM

**What goes wrong:**
If a drag is interrupted by a phone call, screen rotation, or app backgrounding while a drag is in progress, the `Overlay` entry containing the dragged flag widget may not be cleaned up. The phantom flag widget persists on screen until the next full rebuild.

**Prevention:**
- Wrap drag state management in a `StatefulWidget` that implements `dispose()` and cleans up any active `OverlayEntry`
- Handle `AppLifecycleState.paused` and cancel any in-progress drag
- If using a custom drag implementation (recommended per T-1), track drag state in a `ValueNotifier` and ensure a `finally` block in the gesture handler cancels the drag

**Detection:**
- Simulate phone calls/interruptions during drag in emulator
- Test screen rotation mid-drag

**Phase:** Core gameplay phase.

---

### Pitfall T-5: App Open Ads Break Flutter's Navigator / Lifecycle on Android

**Confidence:** MEDIUM

**What goes wrong:**
App Open Ads are displayed using an `Activity`-level overlay. On Android, when the App Open Ad fires on app resume (from background), it can conflict with Flutter's `Navigator` stack restoration. Specifically:
- If the app was in the middle of a modal dialog (parental gate, pause menu), the App Open Ad may appear on top of the dialog and leave the dialog state stuck when the ad is dismissed
- The ad's `Activity` may trigger `onResume` lifecycle callbacks in Flutter, causing double-initialization of state

**Prevention:**
- Maintain a boolean flag `_isShowingAd` and suppress App Open Ads when any modal or overlay is active
- Show App Open Ads only when returning to the game's main menu state, not arbitrary resume events
- Set a cooldown (e.g., minimum 4 hours between App Open Ads to the same user) as both a UX courtesy and a policy signal

**Detection:**
- Test the full lifecycle: app open → game in progress → press Home → return to app. Does the App Open Ad appear over an active game session?

**Phase:** Ad integration phase.

---

## Moderate Pitfalls

---

### Pitfall M-1: SharedPreferences Has No Write Guarantee on Android

**Confidence:** HIGH

**What goes wrong:**
`SharedPreferences` (and Flutter's `shared_preferences` plugin) writes are asynchronous. The `commit()` vs `apply()` distinction on Android means that if the process is killed between a write and the underlying file flush, data is lost. High scores written on the final screen of a completed game round can be lost if the user immediately presses Home.

**Prevention:**
- Call `await prefs.setInt(...)` and await the Future — this uses `commit()` which is synchronous and returns success/failure
- Write the score at the moment it is achieved (on each correct drop), not only at game-end
- Consider using `flutter_secure_storage` or `sqflite` if you later add achievements — but for simple high scores, `shared_preferences` with awaited writes is sufficient

**Detection:**
- Rapid write followed by process kill in instrumented test
- Check `prefs.setInt()` return value

**Phase:** Score persistence phase.

---

### Pitfall M-2: SharedPreferences Data Is NOT Preserved on App Uninstall/Reinstall

**Confidence:** HIGH

**What goes wrong:**
Standard `SharedPreferences` data is stored in the app's private data directory (`/data/data/com.package.name/shared_prefs/`). When the user uninstalls the app, this data is deleted. High scores are lost on reinstall. This is expected behavior, not a bug, but players who uninstall and reinstall (e.g., to free space) will be frustrated.

**Prevention:**
- For v1, document this limitation and accept it (no backend means no cloud save)
- Consider using Android's Auto Backup feature, which can back up `SharedPreferences` to Google Drive for Android 6+ — enable with `android:allowBackup="true"` and a backup rules file that includes SharedPreferences
- Be aware: Auto Backup uploads data to Google account — ensure your privacy policy mentions this

**Detection:**
- Uninstall and reinstall the app; verify high scores are gone (expected) or backed up (if Auto Backup is configured)

**Phase:** Score persistence phase.

---

### Pitfall M-3: i18n Country Name Changes and Political Sensitivity

**Confidence:** HIGH

**What goes wrong:**
Country names change through international renaming events (e.g., Macedonia → North Macedonia, Swaziland → Eswatini, Turkey → Türkiye at the UN level). Using hardcoded country name strings means the game contains outdated or politically sensitive names. For a children's educational app, accuracy matters more than for a utility app.

**Prevention:**
- Use ISO 3166-1 alpha-2 country codes as your internal canonical identifiers, never country name strings
- Source country name translations from a maintained dataset: Unicode CLDR (Common Locale Data Repository) is the authoritative source for localized country names in 100+ languages. Use the `intl` package which wraps CLDR data.
- Separate "display name" (from CLDR, can be updated) from "game data" (SVG path, flag asset, indexed by ISO code)
- Set up a content update mechanism even for an offline app: bundle updated country names in a data file that can be updated via app update without code changes

**Detection:**
- Compare your country name list against the current ISO 3166-1 MA (Maintenance Agency) database before each release
- Check UN official country name list for formal name changes

**Phase:** Data modeling phase (early). Foundation for the entire game's data layer.

---

### Pitfall M-4: RTL Languages Break Custom Map UI Layouts

**Confidence:** MEDIUM

**What goes wrong:**
Arabic, Hebrew, Persian, and Urdu are RTL languages. Flutter's `Directionality` widget handles RTL for standard widgets, but custom-painted widgets (`CustomPainter`) do not automatically flip. Specific issues:
- Flag trays displayed as horizontal scrolling lists will scroll in the wrong direction for RTL users
- Score/timer HUD elements may overlap when mirrored
- Country name labels on the map rendered via `TextPainter` need explicit `TextDirection.rtl` when the locale is RTL

**Prevention:**
- Wrap all custom-painted text with `Directionality.of(context)` checks
- Test with Arabic locale from day one if you plan to support Arabic
- Use `Padding`/`EdgeInsetsDirectional` (not `EdgeInsets`) in all layouts so they flip automatically

**Detection:**
- Set device language to Arabic in emulator and launch the app

**Phase:** i18n implementation phase.

---

### Pitfall M-5: iOS ATT (App Tracking Transparency) — AdMob Requires NSUserTrackingUsageDescription

**Confidence:** HIGH

**What goes wrong:**
On iOS 14.5+, apps must request permission via ATT before accessing the IDFA. AdMob requires you to include `NSUserTrackingUsageDescription` in `Info.plist` even for child-directed apps. Failure to include it causes:
1. App Store rejection ("missing required permission string")
2. AdMob SDK crash/warning on iOS

However, for a fully child-directed app that sets `tagForChildDirectedTreatment=true`, Apple treats the app as subject to COPPA rules: the ATT prompt is automatically suppressed (Apple does not show the ATT dialog to apps marked as directed at children under 13, because they cannot consent). You still need the `Info.plist` entry, but the prompt will not show.

**Prevention:**
- Add `NSUserTrackingUsageDescription` to `ios/Runner/Info.plist` with a meaningful string
- Use `app_tracking_transparency` Flutter plugin to request ATT at the appropriate time (before AdMob initialization) for non-child flows — even though for a child-directed app it won't fire, the plugin call is still required to avoid SDK warnings
- Set `RequestConfiguration.Builder().setTagForUnderAgeOfConsent(TAG_FOR_UNDER_AGE_OF_CONSENT_TRUE)` for iOS (this is separate from `tagForChildDirectedTreatment`)

**Detection:**
- Run on an iOS 14.5+ simulator and check for AdMob initialization warnings about ATT
- App Store Connect rejects builds missing the usage description

**Phase:** iOS parity phase.

---

### Pitfall M-6: Minimum iOS Deployment Target for flutter_google_mobile_ads

**Confidence:** HIGH (based on SDK requirements as of mid-2025)

**What goes wrong:**
`flutter_google_mobile_ads` 5.x requires iOS 14.0 as the minimum deployment target. Setting `IPHONEOS_DEPLOYMENT_TARGET = 12.0` or `13.0` in your Podfile/Xcode project causes compilation errors with the latest AdMob SDK.

**Prevention:**
- Set minimum iOS deployment target to 14.0 in `ios/Podfile`: `platform :ios, '14.0'`
- Set it in Xcode project settings as well (Podfile alone is not sufficient for all build paths)
- This aligns with Flutter's own minimum iOS requirement (as of Flutter 3.16+, minimum iOS is 12, but AdMob raises the effective minimum)

**Detection:**
- First iOS build attempt will fail with linker errors referencing missing symbols if deployment target is too low

**Phase:** iOS setup phase.

---

### Pitfall M-7: Android-Specific Flutter Packages That Break on iOS

**Confidence:** HIGH

**What goes wrong:**
Several commonly-used Flutter packages have Android-only implementations or behave differently on iOS:
- `android_alarm_manager_plus` — Android only, will not compile on iOS
- `flutter_local_notifications` — works on both, but notification channel configuration is Android-specific
- Packages using Android `ContentProvider` or `BroadcastReceiver` constructs have no iOS equivalent
- `shared_preferences` on iOS uses `NSUserDefaults` (not `SharedPreferences`) — behavior is compatible but the storage mechanism is different; data is not guaranteed to be backed up the same way

For this project's specific dependency list:
- `flutter_svg` — cross-platform, no issue
- `google_mobile_ads` — cross-platform, no issue if ATT is handled
- `shared_preferences` — cross-platform, no issue

**Prevention:**
- Before adding any package, check its pub.dev "Platforms" badge — only add packages that show both Android and iOS
- Run `flutter build ios --no-codesign` from the project root after adding any new package to catch iOS build failures early, before the iOS parity phase

**Detection:**
- First iOS build

**Phase:** Foundation (package selection) and iOS parity phase.

---

### Pitfall M-8: Native Share Sheet Does NOT Violate Kids Policy, But Screenshot APIs Do on Android 12+

**Confidence:** MEDIUM

**What goes wrong:**
The native OS share sheet (`Share.share()` via `share_plus`) is fine from a policy perspective — it does not transmit data to a third party directly. The parental gate before triggering it is sufficient compliance.

However, programmatic screenshot capture (capturing the game canvas to a bitmap for sharing as an image) requires different handling on Android 12+:
- The `MediaStore` API for saving images changed in Android 10+
- On Android 12+, foreground service requirements for screen capture changed
- The `flutter_screenshot` or direct `RenderRepaintBoundary.toImage()` approach works without special permissions (it captures only your app's own render tree, not the screen)

**Prevention:**
- Use `RenderRepaintBoundary.toImage()` to capture the game canvas — this is safe on all Android versions and requires no permissions
- Do NOT use screen recording APIs or `MediaProjection` — these are overkill and require dangerous permissions
- Save the screenshot to a temp file, then use `share_plus` to share the file path. Temp file access via `FileProvider` on Android requires the `fileprovider` configuration in `AndroidManifest.xml`

**Detection:**
- Test share flow on Android 12+ emulator
- Test that the FileProvider authority in `AndroidManifest.xml` matches the one used in the share intent

**Phase:** Social sharing phase.

---

### Pitfall M-9: APK Size With 195 SVG Flags + World Map SVG

**Confidence:** MEDIUM

**What goes wrong:**
195 SVG flag files + 1 world map SVG + Flutter engine + AdMob SDK + mediation SDKs produces a larger APK than expected:
- Flutter engine baseline: ~5–7 MB (arm64)
- AdMob SDK: ~3 MB
- AppLovin MAX: ~4–6 MB
- Unity Ads: ~4–5 MB
- Meta Audience Network: ~3–4 MB
- 195 SVG flags at ~5–20 KB each: ~1–4 MB total (most flag SVGs are simple shapes, well under 10 KB)
- World map SVG: 200 KB–2 MB depending on path complexity and simplification level

Realistic uncompressed APK: **25–40 MB**. After Play Store compression (`.aab` delivery): **12–20 MB** delivered to devices.

Google Play has no hard size limit for APKs delivered via Play Store (the 100 MB limit applies to APKs uploaded directly; AABs are unlimited). However, size matters for download conversion rates, especially in target markets for an educational app (Southeast Asia, Latin America) where data costs are a concern.

**Prevention:**
- Use Android App Bundle (AAB) format — mandatory for new apps since 2021 anyway, and reduces delivered size by 30–40%
- SVG flags: verify each flag SVG is optimized (SVGO-processed). Raw Wikipedia flag SVGs can be 50–200 KB each; optimized versions are 3–15 KB. This is a significant multiplier.
- World map SVG: use a simplified version. Natural Earth 1:110m scale is sufficient for a game; the 1:10m scale adds massive path complexity with no visible benefit at mobile screen sizes.
- Deferred/lazy loading for mediation SDKs is not possible — they must be present at compile time. However, you can defer adapter initialization until the first ad request.
- Use `flutter build appbundle --split-debug-info` for production builds.

**Detection:**
- Run `flutter build apk --analyze-size` to get a breakdown of what's consuming space

**Phase:** Asset pipeline phase (flag optimization) and app store release phase (AAB build).

---

## Minor Pitfalls

---

### Pitfall m-1: Interstitial Ad Timing in the Families Program

**Confidence:** HIGH

**What goes wrong:**
Google Play Families Policy has explicit rules about interstitial ads:
- Cannot appear before users can interact with the app
- Cannot appear during active gameplay (mid-round)
- Must appear at natural break points (level complete, game over)
- For children's apps, full-screen ads must have a clearly visible close button (no forced-watch minimum below 5 seconds for kids)

**Prevention:**
- Show interstitials only on the "game complete" or "level summary" screen, triggered by user action (tapping "Continue")
- Never auto-show an interstitial; always make it appear at a screen transition the user initiated
- Test with Families Policy ad requirements checklist before submission

**Phase:** Ad integration phase.

---

### Pitfall m-2: The Parental Gate Must Be Genuinely Challenging for Adults

**Confidence:** MEDIUM

**What goes wrong:**
Google Play and Apple both require that a "parental gate" be something a young child cannot guess. Common invalid implementations:
- "Tap to confirm you are a parent" (no challenge)
- Simple addition like "1 + 2 = ?" (too easy; 8-year-olds can do simple addition)
- Date-of-birth entry (children know their parents' birthdays)

**Prevention:**
- Use a math problem that requires two-digit multiplication or division, or an age-verification approach where the answer is non-obvious
- The current design ("simple math challenge") may need to be strengthened — consider `47 × 8 = ?` or a random multi-step calculation
- Apple App Store Review Guidelines explicitly state the gate must be something "a young child could not easily guess or bypass"

**Detection:**
- Have an 8-year-old test the parental gate

**Phase:** Social sharing phase. Review gate implementation against both Apple and Google guidelines.

---

### Pitfall m-3: flutter_svg Version Compatibility With Flutter 3.x

**Confidence:** MEDIUM

**What goes wrong:**
`flutter_svg` has had multiple breaking API changes between major versions. `flutter_svg` 0.x and 1.x had completely different APIs. The 2.x version changed the rendering pipeline. Apps that pin to old versions of `flutter_svg` accumulate technical debt and eventually break on Flutter SDK upgrades.

**Prevention:**
- Use the latest stable `flutter_svg` version at project start
- Do not pin to minor versions in `pubspec.yaml` unless a specific bug requires it — use `^2.x.x` (or current major)
- Check the `flutter_svg` changelog before upgrading Flutter SDK versions

**Phase:** Foundation phase.

---

### Pitfall m-4: Missing `GADApplicationIdentifier` in Info.plist Causes iOS Crash

**Confidence:** HIGH

**What goes wrong:**
On iOS, AdMob requires `GADApplicationIdentifier` in `Info.plist`. If it is missing, the app crashes on launch with `NSInvalidArgumentException`. This is a configuration error that is easy to miss when porting from Android.

**Prevention:**
- Add to `ios/Runner/Info.plist`:
  ```xml
  <key>GADApplicationIdentifier</key>
  <string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
  ```
- Use the test app ID `ca-app-pub-3940256099942544~1458002511` during development

**Phase:** iOS setup phase.

---

### Pitfall m-5: "All Countries" Data Includes Disputed Territories

**Confidence:** MEDIUM

**What goes wrong:**
The definition of "195 countries" is itself contested. The UN recognizes 193 member states plus 2 observers (Vatican, Palestine). Common world maps include Kosovo, Taiwan, and Western Sahara to varying degrees. Including or excluding these can generate user complaints or, in some markets, app store issues (apps mentioning Taiwan as a country have been removed from the China App Store).

**Prevention:**
- Define your dataset explicitly: "UN member states + Vatican + Palestine = 195" is a defensible position
- For Taiwan: show it as a geographic region for map accuracy without labeling it explicitly as an independent state in v1
- Document the data source in your game's about/credits screen
- If targeting China market ever: this becomes a much larger issue

**Phase:** Data modeling phase.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Foundation / project setup | Firebase/Crashlytics added by default; GAID permission in manifest | Audit pubspec.yaml and AndroidManifest before any SDK is added |
| Data modeling (countries, flags) | ISO code vs name confusion; disputed territories | Use ISO 3166-1 alpha-2 as canonical ID; source names from CLDR |
| World map rendering | SVG performance at 195 paths; jank during zoom | CustomPainter with path caching; separate static/interactive layers |
| Drag-drop mechanic | Draggable/DragTarget breaks under InteractiveViewer transform | Manual gesture + inverse-matrix hit-test from day one |
| i18n infrastructure | RTL layout breaks; country name staleness | Use Directionality; source names from intl/CLDR |
| Score persistence | SharedPreferences async write loss | Await all writes; write incrementally not just at game-end |
| AdMob integration | tagForChildDirectedTreatment not cascading; App Open ad lifecycle | Set child-directed flag on each mediation SDK separately |
| AdMob mediation | Meta AN/AppLovin COPPA non-compliance | Explicit child-directed SDK init; proxy test before release |
| Social sharing | Weak parental gate; FileProvider misconfiguration | Use multi-digit math challenge; test FileProvider on Android 12+ |
| iOS parity | Missing GADApplicationIdentifier; wrong deployment target; ATT | Checklist: Info.plist, Podfile iOS 14+, ATT usage string |
| Store submission | Families Program review delay; ad timing violations | Submit interstitials only at natural breaks; allocate 3–4 week buffer |
| Asset pipeline | Unoptimized SVG flags inflating APK | Run SVGO on all flag assets; use Natural Earth 1:110m for map |

---

## Sources

All findings based on:
- Training knowledge of Google Play Families Policy documentation (support.google.com/googleplay/android-developer/answer/9893335)
- AdMob child-directed treatment documentation (developers.google.com/admob/android/targeting)
- FTC COPPA FAQ and enforcement actions (ftc.gov/business-guidance/resources/complying-coppa)
- FTC 2022 mobile ad network enforcement sweep (public record)
- Flutter framework source code knowledge: InteractiveViewer transform, Draggable overlay mechanics
- flutter_svg package documentation and GitHub issue history
- AppLovin MAX Flutter integration guide (dash.applovin.com)
- Meta Audience Network SDK COPPA documentation
- Flutter community post-mortems and pub.dev issue trackers
- Knowledge cutoff: August 2025

**Note:** The following items require independent verification against current documentation before implementation, as policies are actively maintained and change:
- Current list of approved ad SDKs for Google Play Families Program (MEDIUM confidence — verify at submission time)
- AppLovin's current Families Program approval status (MEDIUM — verify at integration time)
- Meta Audience Network's current child-directed API method names for latest SDK version (MEDIUM — API changes between major versions)
- iOS minimum deployment target for current `flutter_google_mobile_ads` version (HIGH confidence but verify against current pub.dev release notes)
