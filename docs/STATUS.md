# Durum — v1.0 build

All 9 milestones of `docs/BUILD_PROMPT.md` are implemented on `main`. This file lists how each was
verified and what still needs a human, a device or an account.

## Verified on the build Mac (Intel iMac, Xcode 26.3, iPhone 17 simulator, iOS 26.3)

| Check | Result |
|---|---|
| `python3 tools/validate_cards.py` | 202 cards, 0 errors |
| `swift test --package-path Packages/KelimeCore` | 105 tests pass (incl. 10,000 personal crosswords: 99 % place all 4 seeds, all succeed with fallback, ~8 ms each in a debug build) |
| `xcodebuild … build test` (simulator) | build + 102 package tests pass |
| `xcodebuild -configuration Release -destination generic/platform=iOS … CODE_SIGNING_ALLOWED=NO` | succeeds |
| Release build on the simulator, clean install | launches, imports content, shows onboarding |
| Manual pass in the simulator | onboarding, Bugün, Word Detail, Kelimelerim/Desteler, Quick Review (both question types, summary, daily limit), crossword (typing, hints, completion), paywall, Ayarlar, theme picker, deep links, dark mode, Dynamic Type XXL |
| Widget layouts | every family, mode and state rendered to PNG by `WidgetRenderTests` (see `docs/widgets-preview.png`) |

## Needs you (account, device or decision)

1. **Team ID and App Group.** Set `DEVELOPMENT_TEAM` in `Config/Shared.xcconfig`, then let Xcode register
   `group.com.enesseval.kelime` for both targets (Signing & Capabilities).
2. **Widgets on a real device.** The iOS 26 widget gallery doesn't render on the Intel simulator, so these were
   checked only through renders and tests: adding each widget, the Biliyorum/Zorlanıyorum and quiz buttons,
   the self-test A→B switch, lock-screen vibrant and iOS 18 tinted rendering.
3. **StoreKit.** Run from Xcode to use `Config/KelimeWidget.storekit` (the scheme references it; if Xcode
   doesn't pick it up, set it under Edit Scheme › Run › Options). Create `pro.lifetime` and `pro.yearly`
   (group "Pro", 7-day free trial) in App Store Connect. Prices come from `displayPrice`.
4. **Placeholders.** `AppConfig.reportEmail` (Hata bildir) and `Legal.termsURL` / `Legal.privacyURL`.
5. **Content.** Replace `Content/cards.json` with the 3–5k set (bump `contentVersion`), then run
   `python3 tools/validate_cards.py` and `python3 tools/build_puzzles.py`. A1 has no cards yet, so the A1 deck
   shows "Yakında" and A1 users get the A2 puzzle.

## Decisions and known deviations

- **Flat tab bar:** the app opts out of Liquid Glass (`UIDesignRequiresCompatibility`) to match the design.
  Apple will remove this key in a future iOS; the tab bar would then need a restyle.
- **Crossword cells** are 34–40 pt to fit 10 columns as designed, below the 44 pt tap-target guideline. The
  clue bar, toolbar and keyboard keys are 44 pt.
- **Widget themes** apply to home-screen widgets; lock-screen widgets are always vibrant as iOS requires.
  "Cam" is a frosted color, not live translucency (widgets can't blur the wallpaper).
- **Privacy manifests** declare no required-reason APIs because the app and widget use none (no
  UserDefaults); GRDB ships its own manifest. `NSPhotoLibraryAddUsageDescription` is set because the share
  sheet offers "Save Image".
- **Android widgets** from the design brief are out of scope for this iOS build.
