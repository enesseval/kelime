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
| 1. Gradle project, tabs shell, tokens, fonts, schema, content import, AppClock, rules/scheduler/spaced review + tests | done; `:core` compiled and **159 JUnit tests pass** here |
| 2. Bugün, word detail (TTS, share card), Kelimelerim, lists, course units and stories | written |
| 3. Quick Review + custom keyboard; crossword (daily + personal) | written; the game logic is in `:core` and tested |
| 4. Widget queue, lock-screen wallpaper, Glance widgets, notification, QS tile | written; **device measurements still to do** (owner) |
| 5. Onboarding, placement test, settings, reminders | written |
| 6. 1.1: streak + weekly summary, Kelime Avı, Eşleştir, share cards | core logic tested, screens written, **interpreted** (see below) |
| 7. Accounts, sync, Keşfet, feedback; Pro and paywall | written; needs the Google OAuth client and Play products (owner) |
| 8. Polish, release AAB with R8, signing from `local.properties` | config in place; not built here |
| 9. `docs/ANDROID_PLAY.md` | done |

"Written" means: the Kotlin is complete and passes the Kotlin parser, but `:app` has never been
compiled against the Android SDK (see "Build environment" below). Plan one session in Android Studio
for compile fixes and a first run before device testing.

## Known gaps and simplifications

- **Not compiled / not run.** No screen has been seen on a device or emulator. Library APIs were
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
- **Developer screens**: the widget log is ported (with wallpaper lag); usage counters and the
  paywall design gallery are not.
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
2. **`docs/V1_1_PLAN.md` does not exist** in the repository (neither on this branch nor `main`).
   The 1.1 features were built from the prompt's one-line descriptions:
   - *Seri (streak)*: `streak_day` table, one row per local day with at least one answer, any game
     counts. Bugün shows "n gün üst üste" from 2 days on; a missed day shows nothing negative (as
     iOS `StatsQueries.streak`). Weekly summary: a card on Bugün every Monday (and in Profil) with
     last week's answers, learned words and days studied.
   - *Kelime Avı*: a word search. 8×8 letter grid hides 6 words of the learner's sources across,
     down or diagonally (never backwards); the clues are the Turkish meanings. Found words count as
     correct answers; "Göster" counts as a hint (word → zorlanılan).
   - *Eşleştir*: 6 English words and 6 Turkish meanings in two columns; tap one of each to pair.
     A wrong pair marks the English word zorlanılan; a round ends when all are paired.
   - Results go to `game_result` (game, day, score, total, seconds).
   - Share cards: the three iOS styles (Kart, Sözlük, Örnek cümle) rendered to a bitmap.
   Replace these with the real plan when it exists; the code is isolated in `core/games` and
   `app/ui/games`.
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
7. **Apple Watch, Live Activities, alternate icons, App Intents, StoreKit config, the developer
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
puzzle, every widget, the lock-screen wallpaper and the 1.1 games.

## Owner to-do

- Supabase: enable the Google provider and add the Android OAuth client id (Credential Manager).
  Put the **web** client id in `android/local.properties` as `google.webClientId=…`.
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
