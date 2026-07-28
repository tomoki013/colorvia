# Colorvia

[![iOS CI](https://github.com/tomoki013/colorvia/actions/workflows/ci.yml/badge.svg)](https://github.com/tomoki013/colorvia/actions/workflows/ci.yml)

訪れた国を選び、自分の世界地図を色づけるシンプルなiOSアプリです。

## Development

- Xcode 26.6+
- iOS 18+
- SwiftUI / Observation
- No external runtime dependencies

```sh
xcodegen generate
xcodebuild -project Colorvia.xcodeproj -scheme Colorvia \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Map geometry is derived from public-domain Natural Earth data. See
`Documentation/MAP_DATA.md`.
