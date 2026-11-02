# Kilit Kelime

One app on two platforms, built in separate Claude sessions:
- iOS (Swift/SwiftUI): `App/`, `Widget/`, `Packages/KelimeCore/`
- Android (native Kotlin): `android/`
- Shared: `docs/`, `Content/`, `Fonts/`

## Platform parity: do this at the start of every session

1. Run `git fetch origin` and `git pull --rebase origin v1.1`. 1.1 work happens on `v1.1` for both
   platforms. `main` is the 1.0 in App Store review; touch it only for a rejection fix.
2. Read `docs/SYNC.md`:
   - Compare the version table with your platform's config.
   - Port every change-log entry still marked `[ ]` for your platform, then tick it.
3. Tell the user in one line: "Bekleyen eşitleme: N madde" or "Eşit".

## On every user-visible change

In the same commit:
- Add an entry to `docs/SYNC.md`: newest first, your platform `[x]`, the other `[ ]`.
- Update `docs/V1_1_PLAN.md` if the change contradicts it.

Version names move together on both platforms. Build numbers do not.

## Working rules

- Only build or archive when the user asks.
- iOS builds are exported as IPA to `~/Desktop/kelime-ipa`, and the user uploads them with
  Transporter. Never upload from xcodebuild.
- Before pushing, run `git pull --rebase`.
- The user writes in Turkish; answer in Turkish.
