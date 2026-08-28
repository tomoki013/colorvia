# External-service handoff

Current external values:

```text
ADS_ENABLED=YES            (Release; Debug uses Google demo units)
CLOUD_SYNC_ENABLED=NO
ADMOB_APP_ID=ca-app-pub-8687520805381056~7543227876
ADMOB_BANNER_AD_UNIT_ID=ca-app-pub-8687520805381056/8545318350
ICLOUD_CONTAINER_ID=
SUPPORT_CLIENT_KEY=cec87aa57c013f3749a1bb1a09cbfa3e5e33048c8dd195d0
```

`SUPPORT_CLIENT_KEY` is set in `Config/Debug.xcconfig` and `Config/Release.xcconfig`,
substituted into `Info.plist`, and sent as the `X-Support-Client` header on the
support POST. It ships inside the binary, so it is a filter that lets the API
ignore anything merely claiming `source: "colorvia-ios"` — the web form's
Turnstile check has no meaning without it. It is not a credential and not what
protects the endpoint. Remeet sends the same value, and the API holds it as the
`SUPPORT_CLIENT_KEY` secret; unset there means unenforced, so a new value goes
into the apps first and onto the API second.

## Current composition

- Persistence: `VisitStateRepository` → `FileVisitStateRepository`
- Advertising (Debug): `AdService` → `TestAdMobService` with Google demo IDs
- Advertising (Release): `AdService` → `ProductionAdMobService`, gated on UMP consent
- iCloud entitlement: empty
- Google Mobile Ads / UMP package: linked and active in Release

## Advertising

See `Documentation/ADMOB.md` for the consent and startup order. Consent rejection
must never block Colorvia's map, search, local persistence, settings, or
export/import features.

## iCloud (not yet enabled)

Add a cloud repository/decorator behind `VisitStateRepository`; keep the local
file as the source of offline availability and never erase it after a sync
failure. Enable the capability and `CLOUD_SYNC_ENABLED` only after testing merge
conflicts, tombstones, account changes, and offline recovery.
