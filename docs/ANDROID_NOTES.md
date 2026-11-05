# Kilit Kelime for Android — notes

Plan, decisions and known gaps for the native Android port in `android/`. The iOS app in this
repository is the reference for behaviour, content and design; this file lists only what differs
from it or from the Android build prompt.

## Layout

```
android/
  settings.gradle.kts      includes :core always, :app unless -PcoreOnly=true
  gradle/libs.versions.toml
  core/                    pure Kotlin (JVM) — every rule of Packages/KelimeCore, ported 1:1
    src/main/kotlin/com/enesseval/kilitkelime/core/…
    src/test/kotlin/…      JUnit ports of Packages/KelimeCore/Tests (+ 1.1 games)
  app/                     Android app (Compose, Glance, WorkManager, DataStore)
    src/main/kotlin/com/enesseval/kilitkelime/…
```

`:core` has no Android dependency, so the learning rules, the scheduler, spaced review, the widget
queue, the crossword generator, Quick Review, list sync and the games run and are tested on any
JVM (`./gradlew -PcoreOnly=true :core:test`). `:app` wires them to Android.

Content is never copied by hand: the `copyContent` Gradle task in `app/build.gradle.kts` copies
`Content/cards.json` (and `Content/puzzles/*.json` when they exist) and `Fonts/*.ttf` into the
generated assets/res folders before every build.

## Order of work (from the prompt) and state

| Step | State |
|---|---|
| 1. Gradle project, tabs shell, tokens, fonts, schema, content import, AppClock, rules/scheduler/spaced review + tests | done; `:core` compiled and **177 JUnit tests pass** here |
| 2. Bugün, word detail (TTS, share card), Kelimelerim, lists, course units and stories | written |
| 3. Quick Review + custom keyboard; crossword (daily + personal) | written; the game logic is in `:core` and tested |
| 4. Widget queue, lock-screen wallpaper, Glance widgets, notification, QS tile | written; **device measurements still to do** (owner) |
| 5. Onboarding, placement test, settings, reminders | written |
| 6. 1.1: streak + weekly summary, Kelime Avı, Eşleştir, share cards | per `docs/V1_1_PLAN.md`; core logic tested (169 tests), screens written |
| 7. Accounts, sync, Keşfet, feedback; Pro and paywall | written; needs the Google OAuth client and Play products (owner) |
| 8. Polish, release AAB with R8, signing from `local.properties` | config in place; not built here |
| 9. `docs/ANDROID_PLAY.md` | done |

"Written" means: the Kotlin is complete and passes the Kotlin parser, but `:app` has never been
compiled against the Android SDK (see "Build environment" below). Plan one session in Android Studio
for compile fixes and a first run before device testing.

## Known gaps and simplifications

- **First compile (2026-11-05, owner's Windows machine):** `:app:installDebug` reached Kotlin
  compilation with five errors (Glance `actionStartActivity` import, `rawQueryWithFactory`
  edit table, `AppRouter.back()` return type); fixed. Gradle's "Kotlin plugin loaded multiple
  times" warning is expected and harmless: putting the Kotlin plugins in a root
  `build.gradle.kts` without the Android Gradle Plugin breaks the build (`BaseExtension` not
  found), and adding the AGP there would make `-PcoreOnly=true` need Google's Maven. Next: run on
  a device.
- **First run crash (fixed):** TelemetryDeck 6.2 calls `kotlinx.datetime.Clock`, which
  kotlinx-datetime 0.7 (pulled in by Supabase 3.2) removed. `app/build.gradle.kts` pins every
  kotlinx-datetime request to `0.7.1-0.6.x-compat`, which has both. Drop it once TelemetryDeck
  moves to 0.7.
- **Not run yet.** No screen has been seen on a device or emulator. Library APIs were
  written from documentation of the versions in `libs.versions.toml` (Glance 1.1, RevenueCat 9,
  supabase-kt 3.2, TelemetryDeck 6, Credential Manager 1.5); small signature differences are likely.
- **Cinematic intro** is one animated scene (words typing onto a lock screen), not the three-scene
  film of `CinematicIntro.swift`.
- **Wallpaper photos**: EXIF orientation is not applied; a portrait photo taken sideways may appear
  rotated. Fix with `ExifInterface` when testing.
- **Widget themes** (Kâğıt, Mürekkep, Cam, Kor, Yalın) are drawn by the Glance widgets, but there is no
  theme picker in Profil (none was found in the iOS settings either).
- **Accessibility and 200 % font scale**: text uses `sp` and key controls have TalkBack labels, but
  no audit was possible. Same for 360 dp layouts and cold-start time (the first launch imports
  2,271 cards in one transaction; later launches skip it).
- **Developer screens**: none in the Android UI (removed at the owner's request). The widget log
  screen still exists in code (`ui/dev/WidgetLogScreen.kt`) but has no entry point.
- **File import** of `.kelimelist` registers for `application/json` and `application/octet-stream`,
  so the app may be offered for unrelated files of those types.
- **Notification after a widget answer** and other rare paths reload all widgets at once rather than
  only the affected one; fine for three widgets.

## Differences from the prompt

1. **Build environment.** The session that wrote this could reach Maven Central and the Gradle
   plugin portal but not Google's Maven repository or SDK downloads (`dl.google.com` is blocked by
   the network policy). So `:core` was compiled and its tests run, but `:app` (Android Gradle
   Plugin, AndroidX, Compose, Glance) was **written but never compiled**. Expect a round of
   compile fixes on the first build in Android Studio. Library versions in
   `gradle/libs.versions.toml` are the latest ones known to exist; bump them in Android Studio.
2. **1.1 features follow `docs/V1_1_PLAN.md`** (added after the first pass, which had to guess).
   Android's first release is 1.1.0 (versionCode 1), the same version and feature set as iOS 1.1.0:
   - *Seri*: a day counts only for a finished Quick Review, a solved word in the daily puzzle or a
     finished Kelime Avı / Eşleştir (`streak_day(day, source)`); widget and word-detail answers do
     not. One automatic freeze per Monday–Sunday week saves a single missed day (two with Pro);
     freezes are spent in calendar order; the longest streak is kept in `settings`. Bugün shows
     "🔒 N gün" (amber while today is open), the streak page shows five weeks (dashed circle =
     saved by a freeze), and the reminder says "N günlük serin bu akşam bitiyor…" when at risk.
     Rules in `core/games/Streak.kt`, tested in `StreakTest`.
   - *Haftalık özet*: opens once on the first Monday visit and from Bugün's Monday card: learned,
     struggling, words the lock screen showed (new `widget_shown` table, filled when a slot is
     counted), Quick Review accuracy, streak, word of the week; Paylaş makes the 9:16 card.
   - *Kelime Avı*: 10×10 (9×9 under 360 dp), 6 words of 3 to (size − 1) letters across, down or
     diagonally, never backwards; letters on one card, found words marked by a round-capped green
     band, the drag by a blue band, a hint by an amber circle; Turkish meanings as clues;
     "İlk harfi göster" counts as a hint (word → zorlanılan); unhinted words count as correct.
   - *Eşleştir*: 60 seconds, 5 + 5 cards, no card starts with both halves on one row. A right pair
     turns green with ✓ and grows 5 % for 0.42 s, then fades out (0.3 s) and leaves its places
     empty; once three places per side are empty the next three cards fade in (0.25 s delay,
     0.45 s) at random places. A wrong pair turns amber with ✕, shakes twice (7 dp, 0.4 s) and is
     back to normal after 0.65 s; the English word becomes zorlanılan. Best score kept.
   - *Share cards*: every card is 1080×1920 in Açık / Koyu / Mavi with "Kilit ekranında İngilizce"
     and no store link: word, puzzle result (unsolved-letter grid, green = unaided, amber = hint),
     game results, weekly summary, streak milestones (7, 30, 100).
   - *Quick Settings tile* is "Hızlı Tekrar" (opens a round; subtitle = the current word).
   - *TelemetryDeck*: `streak.day` (once a day, with `source` = quickReview, puzzle, wordSearch, match), `streak.freezeUsed`, `weekly.opened`, `weekly.shared`,
     `game.wordsearch.finished`, `game.match.finished`, `share.card` (with `type`),
     `tile.quickReview`, `wallpaper.enabled`, alongside the iOS 1.0 `Usage.*` signals.
   - *Reminder ask* (`notifications/ReminderAsk.kt`): onboarding has three steps and no reminder
     step. After a good moment (`AppModel.studied`: a finished Quick Review, a solved puzzle word,
     a finished game) the app marks the ask as pending when POST_NOTIFICATIONS was never granted or
     permanently denied, the card was shown fewer than 2 times and not in the last 3 days. When the
     round's screen closes, a bottom sheet opens 0.6 s later ("Güzel bir tur oldu", time 20:30,
     Hatırlat / Şimdi değil); only Hatırlat opens the system prompt. Signal `reminder.ask` with
     `result` = granted / denied / later. Android cannot report "never asked", so the app remembers
     when it opened the prompt (`notificationsRequested`); asked + no rationale = permanently denied.
     Below Android 13 there is no prompt: the card shows while no reminder is set and Hatırlat sets it.
   - *Pro offer* (`PaywallTrigger.MOMENT`, "Güzel gidiyorsun"): the only paywall that opens on
     its own. After a counted study day, if not Pro, `streak_day` holds at least 3 different days,
     the offer was shown fewer than 2 times and not in the last 14 days, and no paywall opened in
     the last 48 hours, it opens 0.6 s after the round's screen closes. If the reminder card is
     waiting in the same round it goes first and Pro waits for a later good moment. Signal
     `paywall.moment`. Rules in `core/model/Pro.kt` (`PaywallMoment`), tested in `PaywallMomentTest`.
   - The week dots on Bugün show streak days (`streak_day`), like the badge; a day saved by a
     freeze shows empty there (the dashed circle is only on the streak page). The paywall does not
     list the second freeze; the streak page and the Play text do.
3. **Database: platform SQLite instead of Room.** The schema is owned by `:core`
   (`Migrations.kt`, a 1:1 port of `Migrations.swift` v1–v6 plus v7 for the 1.1 tables) and every
   query is the same SQL as iOS, run through a small `SqlDb` interface. Tests run that exact SQL on
   SQLite (xerial JDBC); the app runs it through `android.database.sqlite`. Room would have meant
   rewriting every query as DAO methods and a schema that could not be verified here. Moving to
   Room later is mechanical (the tables are identical).
4. **Dates in the database** are epoch milliseconds (INTEGER), local days are `YYYY-MM-DD` text as
   on iOS. Android never shares a database file with iOS, so no format compatibility is needed.
5. **DI: a hand-written `AppContainer`** instead of Hilt: the graph is small (database, clock,
   repositories, account, purchases) and an extra annotation processor was one more thing that could
   not be verified here. Swapping in Hilt is a contained change in `KilitKelimeApp`.
6. **Random numbers match iOS.** `SeededGenerator` (SplitMix64) and Swift's `shuffled`,
   `randomElement`, `Int.random(in:)` and `Double.random(in:)` algorithms are reproduced, so seeded
   results (crossword generation, picks in tests) are the same numbers as on iOS.
7. **Apple Watch, Live Activities, App Intents, StoreKit config, the developer
   paywall gallery** have no Android counterpart and are skipped.
8. **Bundled daily puzzle files** (`Content/puzzles`) are not in the repository: every level has
   course units now, so the daily puzzle always comes from `CoursePuzzle`. The asset task copies the
   files if they come back.

## Lock screen on Android

Three delivery paths (prompt §2), all fed by the same `widget_queue` as iOS:

1. **Lock-screen wallpaper** (`app/lock/WallpaperWorker.kt`, `WallpaperRenderer.kt`).
   `WallpaperManager.setBitmap(bitmap, null, true, FLAG_LOCK)`; home wallpaper untouched. Rendered at
   the device's real display size once per slot and cached in `cacheDir/wallpaper/<slot>.png`.
   Scheduling: a 15-minute `PeriodicWorkRequest` as the safety net, plus a one-time work request at
   the next slot boundary (`setInitialDelay`), re-armed by every run. WorkManager may defer it under
   Doze, so a word can change late; every change is logged to `widget_log`
   (kind `timeline`, source `wallpaper`, with expected vs shown slot) and the developer log screen
   shows the lag.
   Unsupported devices (`!isWallpaperSupported || !isSetWallpaperAllowed`) get an explanation and
   the notification option instead.
2. **Glance widgets**: Kart (small/medium), Hangisi? (quiz, result one minute), Büyük. Declared
   `home_screen|keyguard`.
3. **Silent notification** (`IMPORTANCE_LOW`, ongoing, `VISIBILITY_PUBLIC`), off by default.
4. **Quick Settings tile** "Kilit Kelime": shows the current word as its subtitle, tap opens it.

### To measure on devices (owner)

Not measurable from this environment. Fill in after testing:

| Device | Android | Slot | Expected | Changed at | Lag | Notes |
|---|---|---|---|---|---|---|
| Pixel | | 3 h | | | | |
| Samsung | | 3 h | | | | |

Checklist: `docs/ANDROID_PLAY.md` › "Cihaz test listesi".

## Free vs Pro

Identical to iOS (`PaywallTrigger`): Pro adds unlimited own lists, sharing a list, adding lists
from Keşfet, the exam plan, faster rotation (1 h / 30 min), the personal puzzle and the archive.
Everything else is free, including all course content, Quick Review (unlimited), the daily
puzzle, every widget, the lock-screen wallpaper and the 1.1 games. Per the 1.1 plan Pro also gets a
second weekly streak freeze (an addition, nothing is taken from free users).

## Owner to-do

- Supabase: enable the Google provider and add the Android OAuth client id (Credential Manager).
  The **web** client id is set in `app/build.gradle.kts` (override with `google.webClientId` in `local.properties`).
- RevenueCat: create the Android app, add the Play public key, put the key in
  `local.properties` as `revenuecat.androidKey=goog_…`. Create `pro.monthly`, `pro.yearly`
  (7-day trial) and `pro.lifetime` in Play Console when ready.
- Keystore: create it and set `kelime.keystore`, `kelime.keystorePassword`, `kelime.keyAlias`,
  `kelime.keyPassword` in `local.properties`. `./gradlew :app:bundleRelease` then signs the AAB.
- Digital Asset Links: App Links are verified at the domain root, i.e.
  `https://enesseval.github.io/.well-known/assetlinks.json` (the `enesseval.github.io` Pages repo,
  not this one). A template with the package name is in `android/assetlinks.template.json`; add the
  release (Play App Signing) SHA-256 fingerprint. Until then `liste.html` links open in the browser
  and `kelime://list/<uuid>` still opens the app.
