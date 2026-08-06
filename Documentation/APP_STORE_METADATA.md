# Colorvia App Store metadata draft

## Core metadata

- App name: Colorvia
- Japanese subtitle: 訪れた国と地域を彩る旅の地図
- English subtitle: Color your travel map
- Category: Travel (primary), Lifestyle (secondary)
- Copyright: © Colorvia

### Japanese promotional text

訪れた国と地域を選ぶだけ。旅の記憶が、自分だけの色鮮やかな地図になります。

### Japanese description

Colorviaは、訪れた国と地域を地図に残せるシンプルな旅行記録アプリです。
世界地図から国を選び、対応する国では都道府県・州・県などの地域まで記録できます。

地図の拡大・移動、オフライン地名検索、地域別の統計、地図カラーとテーマの変更、
共有用画像、JSON形式の書き出し・読み込みに対応。アカウント登録や位置情報は不要で、
訪問データは端末内に保存されます。

- キーワード: 旅行,地図,訪問国,旅記録,都道府県,世界地図,トラベル,統計

### English promotional text

Pick the countries and regions you have visited and turn your memories into a colorful personal map.

### English description

Colorvia is a simple travel log for coloring the countries and regions you have visited.
Choose countries on the world map, then record states, prefectures, provinces, and other
regions in supported countries.

Zoom and pan maps, search places offline, review travel statistics, choose map colors and
themes, create share images, and export or import your records as JSON. No account or
location access is required, and visit data stays on your device.

- Keywords: travel,map,countries,visited,trip tracker,states,prefectures,world map

## URLs

- Support: https://tmkch.io/support
- Privacy policy: https://colorvia.tmkch.io/privacy
- Terms: https://colorvia.tmkch.io/terms
- Marketing: https://colorvia.tmkch.io

Verify that each URL is publicly reachable before submission.

## Screenshot set

- App Store-ready Japanese 6.9-inch source: `colorvia-home-ja-6.9.jpg`
- Additional Japanese 6.9-inch sources: `colorvia-country-picker-ja-6.9.jpg`,
  `colorvia-statistics-expanded-ja-6.9.jpg`, `colorvia-settings-ja-6.9.jpg`,
  `colorvia-app-information-ja-6.9.jpg`, `colorvia-privacy-ja-6.9.jpg`
- ATT QA evidence (not for the product page): `colorvia-att-ja-6.9.jpg`
- Earlier Japanese source: `colorvia-home.png`, `colorvia-home-bottom-sheet.png`
- App Store-ready English 6.9-inch source: `colorvia-home-en-6.9.jpg`
- Earlier English source: `colorvia-home-en.png`
- Appearance variants: `colorvia-home-dark.png`, `colorvia-map-coral.png`

Version 1 is iPhone-only. Upload a 6.9-inch set captured at an accepted size
(for example, 1320 x 2868 on iPhone 17 Pro Max). Do not show unfinished iCloud,
advertising, or purchase UI in Release screenshots.

## Review notes draft

Colorvia requires no login. On first launch, select visited countries or skip.
Use the plus button to edit countries. Open a supported visited country from the
statistics sheet to record its regions. Search data and maps are bundled and work
offline. Settings → Data Management provides reset and JSON export/import.

The submitted Release build shows a banner ad. On first launch it gathers Google UMP
consent and then requests ATT. Declining either simply leaves the app ad-free; the map,
search, statistics, settings, and export/import all keep working. The app has no iCloud
sync, purchases, account system, location access, or public user-generated content.

## App Privacy draft

- Data used to track you: Device ID (IDFA), via Google Mobile Ads, only after ATT consent
- Data linked to the user: Support email and message only when the user submits the form
- Local visit records: Stored on device; not collected by the developer
- Support form only: name, reply email, message, app/build/OS version, locale,
  timestamp, request ID, and random support client ID; used for support and abuse prevention

In App Store Connect, disclose the optional support submission under Contact Info,
User Content, Identifiers, and other applicable diagnostics/device fields, and disclose
the Google Mobile Ads/UMP practices reported by Xcode's privacy report — answer that the
app uses tracking and mark Device ID as used for Third-Party Advertising.

The App Privacy questionnaire has no App Store Connect API; it must be completed in the
web UI, following Google's AdMob data disclosure guidance.

`Colorvia/PrivacyInfo.xcprivacy` keeps `NSPrivacyTracking` false and omits
`NSPrivacyTrackingDomains`, matching the Google Mobile Ads SDK's own manifest, which
declares `NSPrivacyCollectedDataTypeTracking` false for every type it collects and lists
no tracking domains. Build 4 was rejected as ITMS-91064 for setting `NSPrivacyTracking`
true alongside an empty `NSPrivacyTrackingDomains`; the two keys must agree.

Do not add Google's ad-serving hosts to `NSPrivacyTrackingDomains`. iOS blocks requests
to listed domains whenever ATT permission is absent, which would stop the
non-personalized ads Google still serves to users who decline ATT.

Reconfirm answers after any ad SDK, analytics, or cloud-sync integration.

## Age rating draft

Answer “None” for violence, sexual content, profanity, drugs, gambling, horror,
medical content, and unrestricted web access. The app is a travel-map utility.
Advertising is declared as present because the Release build serves banner ads.
The resulting App Store age rating is 4+.
Re-evaluate the questionnaire against the then-current App Store Connect wording.
