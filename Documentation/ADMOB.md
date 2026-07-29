# AdMob integration notes

Colorvia shows a fixed **320×50** banner on the home screen only (under the map
and statistics sheet). Other formats and screens are intentionally out of scope.

## Production checklist

1. Register **Colorvia** in [AdMob](https://apps.admob.com/) and create a Banner
   unit named `colorvia_ios_banner`.
2. Put the real IDs in `Config/AdMob.xcconfig`:

   ```text
   ADMOB_APP_ID = ca-app-pub-8687520805381056~7543227876
   ADMOB_BANNER_AD_UNIT_ID = ca-app-pub-8687520805381056/8545318350
   ```

   - Values with `~` are the **App ID** (`GADApplicationIdentifier`).
   - Values with `/` are the **banner ad unit ID**.
   - `pub-8687520805381056` is the **Publisher ID** for `app-ads.txt` only.

3. Host `app-ads.txt` at `https://tmkch.io/app-ads.txt` (see
   `Documentation/app-ads.txt`).
4. In App Store Connect, set the developer / marketing URL host to the same
   `tmkch.io` site that serves `app-ads.txt`.
5. Update App Store Connect **App Privacy** for Google Mobile Ads (device IDs,
   diagnostics, advertising data as applicable). Re-check after each SDK update
   with Xcode’s Privacy Report.
6. Confirm the hosted privacy policy matches the in-app copy (Advertising +
   Analytics sections).
7. In AdMob **Privacy & messaging**, configure the GDPR / consent message that
   UMP should present.

## Debug vs Release

| Build | Banner unit ID | App ID |
| --- | --- | --- |
| Debug | Google test unit (hard-coded) | From `ADMOB_APP_ID` (sample OK) |
| Release | `ADMOB_BANNER_AD_UNIT_ID` from Info.plist | From `ADMOB_APP_ID` |

Never tap production ads on a development device. Debug always uses:

```text
ca-app-pub-3940256099942544/2435281174
```

## Runtime behavior

1. App launches and shows Colorvia immediately.
2. `AdMobConsentManager.prepare()` updates UMP consent and presents a form only
   when required. The UI is never blocked on this work.
3. When `canRequestAds` is true and the user is not ad-free, Mobile Ads starts
   once with publisher first-party IDs disabled.
4. `BannerAdContainer` loads a banner; height is 0 until a successful fill so
   failed / no-fill states leave no empty gap.
5. Screens shorter than 700pt hide the home banner so the map stays usable.
6. Settings shows **Privacy choices** only when UMP reports that entry point as
   required.

## Future ad removal

`AdEntitlementStore.isAdFree` is the single gate. When StoreKit 2 is added,
update that store only; banner views already skip requests when `isAdFree` is
true.

## Out of scope (this version)

Interstitial, app open, rewarded, native ads, mediation, Firebase, ATT prompts,
and StoreKit purchase UI.
