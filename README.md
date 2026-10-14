# Kelime Widget

Native iPhone app + widget extension for learning English words from the lock screen and home screen.
Swift 6, SwiftUI, iOS 17+, Xcode 26.3. Everything runs offline.

## Layout

| Path | What |
|---|---|
| `KelimeWidget.xcodeproj` | App target `KelimeWidget` and widget target `KelimeWidgetExtension` (folder-synchronized groups) |
| `App/`, `Widget/` | Target sources. Adding a file here needs no project edit. |
| `Packages/KelimeCore/` | Shared package: `KelimeCore` (models, GRDB database, migrations, dates, content import) and `KelimeUI` (design tokens, shared views) |
| `Content/` | Bundled `cards.json` and `puzzles/` |
| `Fonts/` | Newsreader, Hanken Grotesk, JetBrains Mono (OFL), bundled in both targets |
| `Config/` | `Shared.xcconfig` (bundle id, display name, versions, team), Info.plists, entitlements |
| `tools/` | Python content tools (any OS) |
| `design/` | Final designs, the visual source of truth. Open `design/Kelime Widget.dc.html` in a browser. |
| `docs/` | Design brief and build spec |

Bundle id, display name, version and team live only in `Config/Shared.xcconfig`. The App Group is
`group.<bundle id>`; `KelimeCore.AppConfig` holds the same id, and a test keeps them in sync.

## Verify

```bash
python3 tools/validate_cards.py
swift test --package-path Packages/KelimeCore
xcodebuild -scheme KelimeWidget -destination 'platform=iOS Simulator,name=iPhone 17' build test
xcodebuild -scheme KelimeWidget -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

Widget layouts can be reviewed without a device: this renders every family and state to PNG
(`docs/widgets-preview.png` is a contact sheet of them).

```bash
KELIME_RENDER_DIR=/tmp/widgets swift test --package-path Packages/KelimeCore --filter WidgetRenderTests
```

To run on a device, set `DEVELOPMENT_TEAM` in `Config/Shared.xcconfig`.
