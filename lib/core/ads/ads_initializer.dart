import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';

/// Initializes the AdMob SDK and all mediation adapters with child-directed flags.
///
/// Must be called before [runApp] in main(). The mandatory COPPA init sequence:
///   1. updateRequestConfiguration (child-directed flags) — BEFORE initialize()
///   2. Mediation SDK COPPA/privacy flags — BEFORE initialize()
///   3. MobileAds.instance.initialize() — LAST
///
/// Only SDKs on the Google Play Families Self-Certified Ads SDK Program list are
/// included (Unity, InMobi). IronSource and AppLovin were removed — both are
/// absent from the certified list and their presence violates the Families Policy.
Future<void> initializeAds() async {
  // Step 1: Set child-directed flags on AdMob BEFORE initialize().
  // Do NOT set both tagForChildDirectedTreatment AND tagForUnderAgeOfConsent
  // to yes simultaneously — child-directed covers UCPA; dual-flag is not
  // recommended per Google docs.
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      maxAdContentRating: MaxAdContentRating.g,
    ),
  );

  // Step 2: Unity consent (no consent for children; no selling of data).
  // setGDPRConsent and setCCPAConsent are instance methods on GmaMediationUnity.
  await GmaMediationUnity().setGDPRConsent(false);
  await GmaMediationUnity().setCCPAConsent(false);

  // Step 3: InMobi — the gma_mediation_inmobi adapter auto-forwards
  // tagForChildDirectedTreatment from GMA RequestConfiguration. No explicit
  // COPPA call needed; the GMA mediation layer handles it.

  // Step 4: Initialize Google Mobile Ads SDK — AFTER all SDK flags above.
  await MobileAds.instance.initialize();
}
