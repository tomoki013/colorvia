/// The Privacy Policy and Terms of Service bundled with the app.
///
/// These are a word-for-word copy of what is published at
/// colorvia.tmkch.io/privacy and /terms, kept here so the documents stay
/// readable with no network. The website remains the authoritative version:
/// `LegalDocumentView` loads it whenever it can and falls back to this copy
/// only when it cannot, and the offline notice says so.
///
/// Japanese and English only, matching the website. Legal text is not worth
/// machine-translating into the app's other interface languages, and a
/// translation that drifts from the published document would be worse than no
/// translation at all.
enum BundledLegalDocument {
  case privacy
  case terms

  var sections: [(title: String, body: String)] {
    switch self {
    case .privacy: Self.privacySections
    case .terms: Self.termsSections
    }
  }

  private static var privacySections: [(title: String, body: String)] {
    [
      (
        localizedLegalText(
          english: "1. Introduction",
          japanese: "1. はじめに"
        ),
        localizedLegalText(
          english: "This policy explains how Tomokichi (the “Operator”) handles user information for the iOS app “Colorvia” (the “App”) and the official brand website (together, the “Service”). The website is authoritative; the App refers to it. When offline, a bundled reference copy may be shown.",
          japanese: "本ポリシーは、Tomokichi（以下「運営者」）が提供するiOSアプリケーション「Colorvia」（以下「本アプリ」）および公式ブランドサイト（以下あわせて「本サービス」）における利用者情報の取扱いを定めるものです。公式Webサイトに掲載する内容を正本とし、本アプリ内からはWebサイトを参照します。オフライン時にはアプリ内の参照用コピーが表示される場合があります。"
        )
      ),
      (
        localizedLegalText(
          english: "2. Operator",
          japanese: "2. 運営者情報"
        ),
        localizedLegalText(
          english: "Operator: Tomokichi (individual developer)\nContact: in-app support form, or the shared form at https://tmkch.io\nEmail: support@tmkch.io",
          japanese: "運営者：Tomokichi（個人開発者）\nお問い合わせ：アプリ内お問い合わせフォーム、または https://tmkch.io の共通サポートフォーム\nメール：support@tmkch.io"
        )
      ),
      (
        localizedLegalText(
          english: "3. Scope",
          japanese: "3. 適用範囲"
        ),
        localizedLegalText(
          english: "This policy applies to use of the App and browsing of the official brand website.",
          japanese: "本ポリシーは、本アプリの利用および公式ブランドサイトの閲覧に適用されます。"
        )
      ),
      (
        localizedLegalText(
          english: "4. Basic policy",
          japanese: "4. 基本方針"
        ),
        localizedLegalText(
          english: "The App does not require an account. Visited countries and regional records are stored on your device in principle. The Operator does not run a server that can view those records from ordinary use alone. The App uses the Google Mobile Ads SDK to show ads. Support details are sent only when you explicitly submit a support form.",
          japanese: "本アプリはアカウント登録を必要としません。訪問国および地域の記録は原則として利用者の端末内に保存されます。運営者は、通常のアプリ利用だけではこれらの記録内容を閲覧できるサーバーを運用していません。本アプリは広告表示のためGoogle Mobile Ads SDKを使用します。問い合わせフォームを明示的に送信した場合に限り、利用者が入力した情報と技術情報を送信します。"
        )
      ),
      (
        localizedLegalText(
          english: "5. Information stored on your device",
          japanese: "5. 端末内に保存する情報"
        ),
        localizedLegalText(
          english: "The App stores:\n\n・Visited-country state and update times\n・Regional visit state and update times\n・Onboarding completion\n・Appearance theme (system / light / dark)\n・Map color\n・Ad-consent related state (including values kept on device by the OS or ads SDK)\n・A random client identifier for support\n・Other local settings needed for the App",
          japanese: "本アプリは、次の情報を端末内に保存します。\n\n・訪問国の状態および更新日時\n・地域の訪問状態および更新日時\n・オンボーディング完了状態\n・表示テーマ（システム／ライト／ダーク）\n・地図色\n・広告同意に関する状態（OSおよび広告SDKが端末上で保持する情報を含む）\n・問い合わせ用のランダムなクライアント識別子\n・その他、アプリの動作に必要なローカル設定"
        )
      ),
      (
        localizedLegalText(
          english: "6. Data export and import",
          japanese: "6. データの書き出し・読み込み"
        ),
        localizedLegalText(
          english: "From Settings → Data management you can export visited countries and regional records as JSON, and import them into Colorvia on another device or after reinstall.\n\nYou manage exported files yourself. The Operator cannot control sharing, loss or alteration by others. Compatibility with invalid, corrupted or future-format JSON is not fully guaranteed.",
          japanese: "利用者は、設定の「データ管理」から、訪問国および地域の記録をJSON形式で書き出し、別の端末または再インストール後のColorviaへ読み込むことができます。\n\n書き出したファイルは利用者自身が管理し、第三者への共有、紛失、改変等について運営者は管理できません。不正または破損したJSON、将来の仕様変更後の互換性を完全には保証しません。"
        )
      ),
      (
        localizedLegalText(
          english: "7. Advertising",
          japanese: "7. 広告配信"
        ),
        localizedLegalText(
          english: "The App uses the Google Mobile Ads SDK and User Messaging Platform (UMP) for consent.\n\n・A fixed 320×50 banner may appear at the bottom of the home screen\n・On devices shorter than 700pt, ads may be hidden to protect map space\n・If an ad fails to load, no empty ad gap is left\n・No interstitial, rewarded, app-open or native ads\n・No Firebase Analytics\n・After UMP, the App requests App Tracking Transparency (ATT). Declining ATT does not lock core features\n・After purchasing the non-consumable “Remove Ads” product, you are not ad-supported\n\nAdvertising partners may process device information, IP address, ad interaction data, diagnostics and consent status for delivery, measurement, fraud prevention and consent. Handling follows Google’s policies and your choices. The Operator does not send visit history, map activity or search terms to ad partners for advertising.\n\nWhere required, UMP shows a consent form, and Settings may offer ad privacy choices.",
          japanese: "本アプリは広告表示のためGoogle Mobile Ads SDKおよび同意管理のためUser Messaging Platform（UMP）を使用します。\n\n・ホーム画面下部に固定サイズ（320×50）のバナー広告を表示する場合があります\n・画面高が700pt未満の端末では、地図操作領域を確保するため広告を表示しない場合があります\n・広告の取得に失敗した場合、空白の広告領域を残しません\n・インタースティシャル、リワード、アプリ起動、ネイティブ広告は使用しません\n・Firebase Analyticsは使用しません\n・起動時にUMPのあと、App Tracking Transparency（ATT）の許可を求めます。許可しなくても基本機能は利用できます\n・非消耗型の一回払い商品「広告を削除」を購入済みの場合は広告配信の対象外となります\n\n広告配信事業者は、広告の配信、効果測定、不正防止、同意管理のため、端末情報、IPアドレス、広告操作情報、診断情報、同意状況などを取り扱う場合があります。取扱いはGoogleのプライバシーポリシーおよび利用者の同意設定に従います。運営者は、訪問履歴、地図操作、検索語を広告目的で広告配信事業者へ提供しません。\n\n必要な地域ではUMPによる同意画面を表示し、設定に広告のプライバシー設定が表示される場合があります。"
        )
      ),
      (
        localizedLegalText(
          english: "8. Support",
          japanese: "8. お問い合わせ"
        ),
        localizedLegalText(
          english: "Only when you submit in-app or web support may the following be sent to the support API and email provider:\n\n・Enquiry id, random client id, source, target app\n・Category, name, email, message\n・App version, build number, OS name/version, locale, submission time\n・Details needed to prevent abuse\n\nVisit records are never attached automatically.",
          japanese: "アプリ内または公式サポートフォームを明示的に送信した場合に限り、次の情報がサポートAPIおよびメール配信事業者へ送信されることがあります。\n\n・問い合わせID、ランダムなクライアントID、送信元、対象アプリ\n・カテゴリ、名前、メールアドレス、本文\n・アプリバージョン、ビルド番号、OS名、OSバージョン、ロケール、送信日時\n・不正利用防止に必要な情報\n\n訪問国や地域の記録は自動添付されません。"
        )
      ),
      (
        localizedLegalText(
          english: "9. Loading legal documents",
          japanese: "9. 法務文書の取得"
        ),
        localizedLegalText(
          english: "The App loads the latest Privacy Policy and Terms from the official website. When offline, a bundled reference copy is shown. The website version is authoritative.",
          japanese: "本アプリは、最新のプライバシーポリシーおよび利用規約を公式Webサイトから取得して表示します。通信できない場合は、アプリに同梱した参照用文書を表示します。Web版を正本として扱います。"
        )
      ),
      (
        localizedLegalText(
          english: "10. Service providers",
          japanese: "10. 外部サービス"
        ),
        localizedLegalText(
          english: "Where needed, the Service uses:\n\n・Google Mobile Ads\n・Google User Messaging Platform\n・Apple (StoreKit and system frameworks)\n・Cloudflare Workers (support API)\n・Resend (support email)\n・Website hosting\n\nWorld and regional map geometry is bundled from open data such as Natural Earth. Bundled map data itself does not send user information abroad.",
          japanese: "本サービスは、提供に必要な範囲で次を利用します。\n\n・Google Mobile Ads（広告配信）\n・Google User Messaging Platform（同意管理）\n・Apple（StoreKit、システム機能）\n・Cloudflare Workers（お問い合わせAPI）\n・Resend（お問い合わせメール配送）\n・公式Webサイトの配信基盤\n\n世界地図および地域の地理データは、Natural Earth等のオープンデータを基にアプリ内へ同梱しています。これらの同梱データ自体は、利用者情報を外部へ送信しません。"
        )
      ),
      (
        localizedLegalText(
          english: "11. Disclosure",
          japanese: "11. 第三者提供"
        ),
        localizedLegalText(
          english: "Except where required by law, the Operator does not improperly disclose personal information. Processing by providers is limited to what the Service needs.",
          japanese: "運営者は、法令に基づく場合を除き、利用者の個人情報を不当に第三者へ提供しません。外部サービスへの委託処理は、本ポリシーに記載したサービス提供に必要な範囲で行われます。"
        )
      ),
      (
        localizedLegalText(
          english: "12. Retention and deletion",
          japanese: "12. 保存期間と削除"
        ),
        localizedLegalText(
          english: "On-device records remain until you delete them. You can clear data in Settings. Uninstalling removes on-device data; the Operator cannot restore it. Support information is kept as needed for response, law, security and abuse prevention. Information held by ad partners follows their policies.",
          japanese: "端末内の記録は、利用者が削除するまで保存されます。設定から個別またはすべてのデータを削除できます。本アプリをアンインストールすると端末内データは削除され、運営者が復旧することはできません。サポート情報は対応、法令、セキュリティ、不正防止に必要な期間保存します。広告事業者が扱う情報は各事業者の方針に従います。"
        )
      ),
      (
        localizedLegalText(
          english: "13. Security",
          japanese: "13. 安全管理措置"
        ),
        localizedLegalText(
          english: "The Operator takes reasonable security measures. On-device data is protected by standard iOS mechanisms.",
          japanese: "運営者は、取り扱う情報について合理的な安全管理措置を講じます。端末内の情報は、iOSの標準的なセキュリティ機構のもとで保護されます。"
        )
      ),
      (
        localizedLegalText(
          english: "14. Minors",
          japanese: "14. 未成年者"
        ),
        localizedLegalText(
          english: "If a minor uses the App, please do so with a parent or guardian’s consent.",
          japanese: "未成年の方が本アプリを利用する場合は、保護者の同意を得たうえでご利用ください。"
        )
      ),
      (
        localizedLegalText(
          english: "15. Changes",
          japanese: "15. ポリシーの変更"
        ),
        localizedLegalText(
          english: "This policy may change with law or product updates. Material changes update the last-updated date and may be announced on the site or in the App.",
          japanese: "法令または機能の変更に応じて本ポリシーを改定することがあります。重要な変更がある場合は、最終更新日を更新し、公式サイトまたはアプリ内で周知します。"
        )
      ),
      (
        localizedLegalText(
          english: "16. Contact",
          japanese: "16. お問い合わせ先"
        ),
        localizedLegalText(
          english: "Questions: in-app support, the shared support form, or support@tmkch.io.",
          japanese: "本ポリシーに関するお問い合わせは、アプリ内お問い合わせフォーム、共通サポートフォーム、または support@tmkch.io までご連絡ください。"
        )
      ),
    ]
  }

  private static var termsSections: [(title: String, body: String)] {
    [
      (
        localizedLegalText(
          english: "Article 1 — Application",
          japanese: "第1条（適用）"
        ),
        localizedLegalText(
          english: "These Terms govern the iOS app “Colorvia” and the official brand website (together, the “Service”) provided by Tomokichi. By downloading the App or using the Service, you agree to these Terms.",
          japanese: "本規約は、運営者（Tomokichi）が提供するiOSアプリ「Colorvia」および公式ブランドサイト（あわせて「本サービス」）の利用条件を定めます。利用者は、本アプリをダウンロードまたは本サービスを利用した時点で本規約に同意したものとみなされます。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 2 — The Service",
          japanese: "第2条（サービス内容）"
        ),
        localizedLegalText(
          english: "Colorvia provides visit tracking for countries, a world map, statistics, regional maps in supported countries, place search, sharing, themes and map colors, JSON export/import, data deletion, and in-app support. No account is required.",
          japanese: "Colorviaは、訪れた国の記録、世界地図の表示、訪問統計、対応国における地域マップ、地名検索、訪問記録の共有、テーマ・地図色、JSONによる書き出し・読み込み、データ削除、アプリ内問い合わせなどの機能を提供します。アカウント登録は不要です。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 3 — Fees and advertising",
          japanese: "第3条（利用料金および広告）"
        ),
        localizedLegalText(
          english: "Core features are free. Ads may appear on some screens. Buying the non-consumable one-time product “Remove Ads” hides ads. There is no subscription. Apple’s terms govern purchase, price and refunds. You are responsible for data charges.",
          japanese: "本アプリの基本機能は無料です。一部の画面には広告が表示される場合があります。非消耗型の一回払い商品「広告を削除」を購入すると広告は表示されません。サブスクリプションではありません。購入処理、価格表示、返金その他の取扱いにはAppleの条件が適用されます。通信に必要な費用は利用者の負担とします。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 4 — User responsibility",
          japanese: "第4条（利用者の責任）"
        ),
        localizedLegalText(
          english: "You use the Service at your own responsibility.",
          japanese: "利用者は、自己の責任において本サービスを利用します。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 5 — Prohibited conduct",
          japanese: "第5条（禁止事項）"
        ),
        localizedLegalText(
          english: "You must not break the law, gain unauthorized access, disrupt the Service, manipulate ads fraudulently, unlawfully copy the App, abuse support, or engage in other conduct the Operator reasonably finds inappropriate.",
          japanese: "法令違反、不正アクセス、運営妨害、不正な広告操作、違法な複製・再配布、サポートフォームの荒らし、その他運営者が不適切と合理的に判断する行為を禁止します。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 6 — Intellectual property",
          japanese: "第6条（知的財産権）"
        ),
        localizedLegalText(
          english: "Rights in the Service’s programs, design, text and images belong to the Operator or rights holders. Rights in visit records you create belong to you.",
          japanese: "本サービスに含まれるプログラム、デザイン、文章、画像等の権利は運営者または正当な権利者に帰属します。利用者が作成した訪問記録の権利は利用者に帰属します。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 7 — Data management",
          japanese: "第7条（データの管理）"
        ),
        localizedLegalText(
          english: "Data is stored on your device in principle; there is no automatic iCloud sync. You may migrate manually via JSON export/import and are responsible for exported files. Data may be lost if you uninstall, lose or damage the device; the Operator cannot restore it. Export before uninstalling if needed.",
          japanese: "データは原則として端末内に保存され、iCloud等による自動同期はありません。JSON書き出し・読み込みにより手動で移行できます。書き出したファイルの管理は利用者の責任です。アプリ削除、端末故障、紛失等によりデータが失われる場合があり、運営者は復旧できません。必要に応じて、アプリ削除前に書き出しを行ってください。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 8 — Maps and regions",
          japanese: "第8条（地図・地域区分）"
        ),
        localizedLegalText(
          english: "Maps and regional divisions in Colorvia are simplified for travel logging and do not express a political position.",
          japanese: "Colorviaの地図や地域区分は、旅の記録を目的として簡略化・整理されています。政治的な立場や主張を示すものではありません。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 9 — Ads and third parties",
          japanese: "第9条（広告・外部サービス）"
        ),
        localizedLegalText(
          english: "Ads use Google Mobile Ads. Support uses a support API and email provider. Each provider processes information under its own policies.",
          japanese: "広告配信にはGoogle Mobile Adsを利用します。お問い合わせにはサポートAPIおよびメール配信事業者を利用します。各サービスの取扱いは各事業者の方針に従います。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 10 — Disclaimer and liability",
          japanese: "第10条（保証の否認・責任制限）"
        ),
        localizedLegalText(
          english: "The Service is provided “as is.” Except for willful misconduct, gross negligence or mandatory law, liability is limited to the extent permitted by law.",
          japanese: "本サービスは現状有姿で提供されます。運営者の故意または重過失および強行法規の範囲を除き、法令で認められる範囲で責任を限定します。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 11 — Changes, suspension, termination",
          japanese: "第11条（変更・中断・終了）"
        ),
        localizedLegalText(
          english: "The Operator may change, suspend or end the Service for OS support, law, ads, maintenance, security or similar reasons.",
          japanese: "運営者は、OS対応、法令、広告、保守、セキュリティ等の理由により、本サービスを変更・中断・終了することがあります。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 12 — Changes to these Terms",
          japanese: "第12条（規約変更）"
        ),
        localizedLegalText(
          english: "These Terms may be revised. Revised Terms take effect when posted in the App or on the website.",
          japanese: "本規約は変更されることがあります。変更後の規約は、本アプリまたは公式サイトに掲載された時点から効力を生じます。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 13 — Governing law and jurisdiction",
          japanese: "第13条（準拠法・管轄）"
        ),
        localizedLegalText(
          english: "Japanese law applies. Unless mandatory consumer law provides otherwise, the Tokyo District Court has exclusive first-instance jurisdiction.",
          japanese: "本規約は日本法に準拠します。消費者契約法その他の強行法規に別段の定めがある場合を除き、東京地方裁判所を第一審の専属的合意管轄裁判所とします。"
        )
      ),
      (
        localizedLegalText(
          english: "Article 14 — Contact",
          japanese: "第14条（お問い合わせ）"
        ),
        localizedLegalText(
          english: "In-app support, the shared support form, or support@tmkch.io.",
          japanese: "本規約に関するお問い合わせは、アプリ内フォーム、共通サポートフォーム、または support@tmkch.io までご連絡ください。"
        )
      ),
    ]
  }
}
