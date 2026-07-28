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
- `FileVisitStateRepository` persists country and region visit states
  atomically as format-version 5 JSON. It backs up and migrates the original
  country-only array and version 2–4 subdivision payloads without changing IDs.
- `WorldMapView` draws normalized bundled geometry with SwiftUI Canvas.
- `JapanMapView` draws the 47 bundled prefecture geometries with SwiftUI Canvas.
- The same subdivision renderer draws the 101 bundled French department
  geometries, including the five overseas departments.
- Spain (52), South Korea (17), Egypt (27), Thailand (77), and Türkiye (81)
  use the same definition-driven detail, map, list, statistics, and poster
  screens as Japan and France.
- The United States (56), Malaysia (16), Belgium (11), and Singapore (8) use
  `CountryRegionScheme`. Source administrative geometry is separate from the
  recordable region model; Singapore validates a complete 55-to-8 assignment.
- Offline place indexes map Japanese municipalities, French communes, common
  names, and selected tourist aliases back to their parent subdivision.
- Feature views contain presentation and interaction only.

No account, backend, location, photo, notification, or third-party runtime
dependency is used.

Visit data is mirrored through the app's iCloud key-value store when iCloud is
available. Local atomic JSON remains the fallback. Country and region records
merge independently by `updatedAt`, including unvisited tombstones, rather
than unioning visited sets. Data Management also supports explicit JSON export
and import; imported country and subdivision IDs are validated against the
bundled catalogs before replacing local state. An import with regions under an
unvisited country asks whether to repair the parent or skip those regions.

## Localization

UI copy and accessibility labels are managed in `Localizable.xcstrings`.
Colorvia currently ships Japanese, English, Spanish, French, German, Italian,
Brazilian Portuguese, Korean, Simplified Chinese, Traditional Chinese, and
Russian. Country names use the system locale.

## Map interaction

The home map supports pinch zoom from 1× to 4×, bounded drag movement while
zoomed, double-tap zoom/reset, explicit zoom controls, and a reset control.

Both world and Japan maps are read-only. The floating plus button keeps the
original country-selection sheet. Rows in the expanded visited-country section
open country detail screens. Japan's detail screen additionally owns the route
to the prefecture map, and France's detail screen owns the route to the
department map. Both subdivision maps mirror the home interaction model with a
floating plus button and expandable statistics sheet. Subdivision changes are
staged in bottom-sheet pickers and committed with the trailing checkmark.

Addition and settings flows use native SwiftUI sheets and navigation toolbars.
On iOS 26 these system controls receive the platform Liquid Glass appearance
without a custom imitation. Addition sheets use a leading close button and
trailing checkmark; settings uses a leading close button.

The home and subdivision statistics sheets update their height only when a drag
ends. This avoids invalidating and redrawing the map Canvas on every drag frame.

France sharing renders dedicated 1080×1080 and 1080×1920 poster views with
`ImageRenderer`; it does not capture the on-screen map UI.

The nine additional countries also render dedicated country-map and map-only
posters at 1080×1080 and 1080×1920. Their search indexes are loaded only when
the corresponding selection sheet opens. Each subdivision includes names for
all 11 Colorvia UI languages; GeoNames alternate names provide multilingual
city and landmark matching without a network request.

Regional selection is available only after the parent country is marked
visited. Editing regions never changes the country state, while removing a
country records unvisited timestamps for all of its child regions.
