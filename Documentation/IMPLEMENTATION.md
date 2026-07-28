# Implementation notes

## Appearance

Colorvia supports System, Light, and Dark appearance preferences. The selected
preference is stored locally and applied at the app root. Map, card, text,
background, border, and accent tokens all use adaptive light/dark colors.

Visited countries can be displayed in Teal, Ocean, Coral, or Amber. The map
color preference is stored locally and is reused by the home map and country
picker preview.

The main country-add action is a floating circular plus button between the map
and statistics card. This keeps the map prominent and avoids wording that
suggests a painting tool.

## Architecture

- `AppState` owns observable UI state and statistics.
- `FileVisitStateRepository` persists visit states atomically as JSON.
- `WorldMapView` draws normalized bundled geometry with SwiftUI Canvas.
- Feature views contain presentation and interaction only.

No account, backend, location, photo, notification, or third-party runtime
dependency is used.

## Localization

UI copy and accessibility labels are managed in `Localizable.xcstrings`.
Colorvia currently ships Japanese, English, Spanish, French, German, Italian,
Brazilian Portuguese, Korean, Simplified Chinese, Traditional Chinese, and
Russian. Country names use the system locale.

## Map interaction

The home map supports pinch zoom from 1× to 4×, bounded drag movement while
zoomed, double-tap zoom/reset, explicit zoom controls, and a reset control.
