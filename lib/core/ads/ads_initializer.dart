import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gma_mediation_ironsource/gma_mediation_ironsource.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';
import 'ad_constants.dart';

/// Initializes the AdMob SDK and all mediation adapters with child-directed flags.
///
/// Must be called before [runApp] in main(). The mandatory COPPA init sequence
/// (per RESEARCH.md §AdMob COPPA Initialization and CONTEXT.md D-M04) is:
///   1. updateRequestConfiguration (child-directed flags) — BEFORE initialize()
///   2. Mediation SDK COPPA flags — BEFORE initialize()
///   3. MobileAds.instance.initialize() — LAST
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

  // Step 2: ironSource/LevelPlay — setDoNotSell before initialize().
  // gma_mediation_ironsource auto-forwards tagForChildDirectedTreatment
  // from RequestConfiguration; setDoNotSell provides belt-and-suspenders
  // US state privacy coverage.
  GmaMediationIronsource().setDoNotSell(true);

  // Step 3: Unity consent (no consent for children; no selling of data).
  // setGDPRConsent and setCCPAConsent are instance methods on GmaMediationUnity.
  await GmaMediationUnity().setGDPRConsent(false);
  await GmaMediationUnity().setCCPAConsent(false);

  // Step 4: AppLovin — gma_mediation_applovin v2+ auto-disables when
  // tagForChildDirectedTreatment=yes. kAppLovinEnabled = false gate
  // documents intent explicitly. No init call needed.
  if (kAppLovinEnabled) {
    // Populate when AppLovin account is approved and Families Program
    // re-entry is confirmed. Do not remove this block — it documents
    // the activation path.
  }

  // Step 5: Initialize Google Mobile Ads SDK — AFTER all SDK flags above.
  await MobileAds.instance.initialize();
}
