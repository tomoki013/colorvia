# AdMob integration

Debug builds use Google's official demo App ID and banner unit ID through
`TestAdMobService`. The banner collapses until it loads and is safe to click in
test mode.

Release builds use `ProductionAdMobService` with the production identifiers in
`Config/Release.xcconfig`:

```text
ADS_ENABLED = YES
ADMOB_APP_ID = ca-app-pub-8687520805381056~7543227876
ADMOB_BANNER_AD_UNIT_ID = ca-app-pub-8687520805381056/8545318350
```

## Startup order

`AdServiceController.prepare()` runs once per active scene and never blocks app
startup or local data loading:

1. UMP consent info update, then `ConsentForm.loadAndPresentIfRequired`.
2. ATT (`ATTrackingManager.requestTrackingAuthorization`) once UMP has had its
   chance to explain tracking.
3. Only when `ConsentInformation.shared.canRequestAds` is true does the Mobile
   Ads SDK start and `canShowAds` become true.

Any failure — consent update error, form load error, refused consent — leaves
`canShowAds` false, so the app simply runs without ads. Consent rejection never
blocks the map, search, local persistence, settings, or export/import.

Where UMP reports `privacyOptionsRequirementStatus == .required` (EEA/UK),
Settings → Information shows an "Ad privacy options" row that reopens the
consent form.

`setPublisherFirstPartyIDEnabled(false)` is set before the SDK starts. Never
attach visit history, map activity, or search terms to ad requests.

## Privacy manifest

`Colorvia/PrivacyInfo.xcprivacy` keeps `NSPrivacyTracking` false and omits the
`NSPrivacyTrackingDomains` key, matching the Google Mobile Ads SDK manifest. The
two keys must stay consistent — build 4 was rejected as ITMS-91064 for declaring
`NSPrivacyTracking` true with an empty domain list. Listing Google's ad-serving
hosts would also make iOS block ad requests for every user who declines ATT.

## Remaining verification

- `Documentation/app-ads.txt` must be published at `https://tmkch.io/app-ads.txt`
  and verified in the AdMob console.
- Banner fill cannot be verified in the Simulator. Check banner display, failed
  ad loading, keyboard display, compact screens, and dark mode on a real device.
- Recheck Google's current SKAdNetwork entries in `Info.plist` against the
  official integration guide before each release.
