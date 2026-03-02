# Ad monetization setup (iOS / SwiftUI)

This project now includes AdMob SDK wiring and a banner placement in `StoresView` for non-subscribed users.

## 1) Configure your ad IDs

1. Copy `Secrets.xcconfig.template` to `Secrets.xcconfig` (if not already present).
2. Replace test values with your own AdMob IDs:
   - `GAD_APPLICATION_ID` (app ID)
   - `ADMOB_BANNER_AD_UNIT_ID`
   - `ADMOB_INTERSTITIAL_AD_UNIT_ID` (reserved for next placement)

> Keep Google test IDs during development. Use production IDs only for App Store builds.

## 2) What is already integrated

- Google Mobile Ads SDK via Swift Package Manager (`GoogleMobileAds`).
- SDK startup in app launch (`Geolocation_v1_0_0App`).
- Banner slot shown at the bottom of `StoresView` for users where `isSubscribed != true`.
- Automatic disable behavior when ad config values are missing or unresolved.

## 3) Profitability strategy (recommended rollout)

### Phase 1 (now): Banner only
- Keep one persistent banner on the primary engagement screen (Stores).
- Track baseline:
  - ARPDAU
  - session length
  - D1/D7 retention
  - ad impressions / DAU

### Phase 2: Add interstitial carefully
- Show interstitial only at natural breaks (not mid-task), e.g. after completing 3-5 meaningful actions.
- Cap frequency (example: max 1 interstitial per 4-6 minutes/session).
- Never show interstitial immediately on app open.

### Phase 3: Rewarded ads
- Use rewarded ads for optional value exchange:
  - temporary premium feature unlock
  - bonus AI usage credits
- Rewarded usually monetizes better than interstitial when value is clear.

### Phase 4: Segment monetization
- Keep ad-free experience for subscribed users.
- A/B test:
  - banner only vs banner + capped interstitial
  - different placement density
  - frequency caps

## 4) Compliance and fill-rate checklist

- Add App Tracking Transparency prompt flow (if you plan personalized ads).
- Integrate Google UMP consent flow for EEA/UK privacy compliance.
- Keep `SKAdNetworkItems` in `Info.plist` updated from Google docs.

## 5) Success criteria

Target improvements while preserving retention:
- +20% to +40% ad ARPDAU (without >2% D7 retention drop)
- stable crash-free rate and no navigation friction increase
