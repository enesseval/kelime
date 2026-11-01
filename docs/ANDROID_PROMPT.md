# Kilit Kelime for Android: build prompt

Copy everything below the line into a new Claude Code session opened in `~/Desktop/kelime`.

---

You are building **Kilit Kelime for Android**: the native Kotlin port of an iOS app that is
already finished and in App Store review. The iOS app in this same repository is the reference
for behaviour, content and design. Read it; do not guess.

## 0. Ground rules

- **Language and stack:** Kotlin 2.x, Jetpack Compose (Material 3, but restyled to our design;
  it must not look like stock Material), Jetpack Glance for widgets, Room for the database,
  WorkManager for background jobs, DataStore for small settings, Hilt for DI, Kotlinx
  Serialization for JSON, Coroutines/Flow. Min SDK 26, target the latest stable SDK.
- **Where:** a new Gradle project in `android/` inside this repo (monorepo). Don't change the
  iOS code. Shared, platform-free assets (`Content/`, `supabase/`, `site/`) are read from their
  existing paths; copy content into Android assets with a Gradle task, never by hand.
- **Language of the app:** Turkish UI, English learning content. Same strings as iOS
  (`App/Localizable.xcstrings` has every Turkish string; reuse the wording).
- **Package name:** `com.enesseval.kilitkelime`. App name: **Kilit Kelime**.
- **Commits:** small, one feature each, message in English, pushed to `main` only when asked.
  End each commit with the attribution line the session's system reminder gives you.
- **Tests:** port the core logic tests from `Packages/KelimeCore/Tests` to JUnit and keep them
  green. Learning rules, scheduler, spaced review, crossword generation and the new games must
  all be unit-tested.
- **Ask before:** creating store listings, entering payment details, anything that publishes.
  The owner (Enes) uploads builds and handles Play Console himself; you prepare the AAB.
- **Before writing code,** read these files in order and write `docs/ANDROID_NOTES.md` with a
  short plan and anything that differs from this prompt:
  1. `docs/V1_1_PLAN.md`: the features that ship in this first Android release, on top of iOS 1.0
  2. `Packages/KelimeCore/Sources/KelimeCore/**`: all app logic (pure Swift, port it 1:1)
  3. `App/**`: screens and flows (SwiftUI). Map each screen to a Compose screen.
  4. `Packages/KelimeCore/Sources/KelimeUI/**`: design tokens, fonts, widget views
  5. `design/App.dc.html` and `docs/store-shots/out/*.png`: how it should look
  6. `supabase/migrations/*.sql`, `App/Account/*`: accounts, list sync, Keşfet, feedback
  7. `App/Store/*`: Pro, paywall, RevenueCat
  8. `docs/APP_STORE.md`: product text; reuse it for the Play listing

## 1. What the app is

The phone shows an English word with its Turkish meaning **every time the user looks at it**,
without opening the app. Around that: an A1–C2 course (units with words, phrases and short
stories), YDS/YÖKDİL/IELTS exam lists, Quick Review (10-question rounds), a daily crossword with
Turkish clues, own word lists, a Discover screen of lists shared by others, and Pro.

## 2. The lock screen on Android (the hard part)

Android phones have no iOS-style lock-screen widgets (Android 16 QPR2 only shows them in the
charging/dock screensaver hub). We deliver the "every glance" promise in three ways:

1. **Lock-screen wallpaper word (headline feature).** With the user's opt-in, a WorkManager job
   renders the current word onto the user's chosen background and sets it with
   `WallpaperManager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_LOCK)` at each rotation
   slot.
   - Backgrounds: our 6 gradients/solids, or the user's own photo (photo picker; crop to the
     screen size; never upload it anywhere).
   - Text card in the lower third by default, with a position slider (top/middle/bottom) and a
     live preview, because OEM clocks and notifications sit in different places.
   - Styles: Kart (word big, "tür · anlam" under it), Sözlük, Örnek cümle, Kendini sına (shows
     the meaning and first letter; the answer appears on the next rotation's wallpaper and on
     the app's "Şu an widget'ında" card).
   - Text colour follows the background's luminance; add a soft shadow for photos.
   - Keep the home-screen wallpaper untouched (FLAG_LOCK only). If the device doesn't support a
     separate lock wallpaper (`isSetWallpaperAllowed` / some OEMs), explain and offer the
     notification instead.
   - Rotation follows the same slot grid as iOS (§4). Minimum WorkManager interval is
     15 minutes; use `PeriodicWorkRequest` plus an exact re-schedule at slot boundaries when
     allowed, and accept drift when not. Log every change (the iOS WidgetLog has the design).
   - Battery: render at device resolution once per slot, cache the bitmap, no animation.
2. **Home-screen widgets (Glance).** Port all three iOS home widgets: Kart (small and medium),
   "Hangisi?" (medium quiz with two buttons, result for a minute, then the next question: see
   `WidgetTimelineBuilder.quiz`), and Büyük (current word, today's struggling words, crossword
   thumbnail). Declare `android:widgetCategory="home_screen|keyguard"` so Android 16 devices can
   also put them on the lock-screen hub.
3. **Optional silent notification.** "Kilit ekranında bildirim olarak göster": a low-importance
   ongoing notification with the word and meaning that updates per slot. Off by default.

Onboarding asks once which of these to turn on, with a preview of the user's own lock screen
(screenshot of the wallpaper preview, not the real lock screen).

## 3. Data and content

- **Content** comes from `Content/cards.json` (cards and course units with stories) and
  `Content/exams/*.json`, bundled into assets at build time. The schema is defined by
  `ContentImporter.swift` and `Curriculum.swift`. Daily puzzles for levels without units come
  from the bundled puzzle files (`build_puzzles.py`); levels with units generate their puzzle
  from started units (`CoursePuzzle.swift`).
- **Content updates:** same as iOS `ContentUpdater.swift`: check
  `https://enesseval.github.io/kelime/content/manifest.json` at most every 6 hours, download
  `cards.json` when `contentVersion` is higher and `schema` is supported, verify size and
  SHA-256, import in one transaction.
- **Database:** Room, same tables as `Migrations.swift` (v1–v6): `card`, `card_deck`,
  `card_state`, `widget_queue`, `settings`, `review_log`, `puzzle_progress`, `widget_log`,
  `unit`, `unit_card`, `user_list`, `user_list_card`, `user_list_deleted`. Add the 1.1 tables
  from `V1_1_PLAN.md` (`streak_day` and the game results).
- **Dates:** everything learning-related uses the device's local day (`LocalDate.swift`), not
  UTC. Port `AppClock` so tests can fix time and zone.

## 4. Learning logic (port 1:1, with tests)

- `LearningRules.swift`: new/struggling/learned transitions, streak, once-per-day rules.
- `SpacedReview`: learned words return after 3, 7, 21, 60, then every 120 days.
- `WidgetScheduler.swift`: weights (struggling 3, due 2, new 1, old learned 0.2 after 14 days),
  no repeat within 20 slots, slots aligned to local midnight, DST-safe.
- `WidgetQueue.swift`: 3 days of slots queued ahead; quiz options stored per slot.
- `CardQueries.swift`: sources = course (started units only) + exam decks + enabled lists;
  words/phrases/both filter (`WidgetContent`).
- `QuickReview.swift`: question mix, write questions with the first letter given, mistake hints
  ("one letter off", "two letters swapped").
- Crossword: `Crossword*.swift`, `DailyPuzzle.swift`, `CoursePuzzle.swift`, play order
  (`playOrder`), crossing selection that prefers the unsolved entry.
- Rotation: Normal (3 h, free), Sık (1 h, Pro), Çok sık (30 min, Pro); "günde X'e kadar" copy.
- Never use the device locale to uppercase answers (Turkish "i" → "İ"); use `Locale.ROOT`.

## 5. Screens

Five bottom tabs, as on iOS: **Bugün, Oyna, Kelimelerim, Keşfet, Profil** (Profil's tab icon is
the user's avatar when signed in). Port every screen in `App/`: onboarding (cinematic intro,
level choice, placement test, widget/wallpaper setup), Bugün (current word, course card,
Quick Review card, puzzle card, week stats, exam plan), word detail (pronunciation with Android
TextToSpeech en-US, share sheet with three card styles, report form), Quick Review, crossword
(custom A–Z keyboard; never the system keyboard), Kelimelerim (Kelimeler / Listeler segmented
switch, filters, A–Z and Z–A index strip, swipe actions), list detail, Keşfet, shared list,
profile, settings, paywall, feedback form. Add the 1.1 screens from `V1_1_PLAN.md`.

## 6. Design

- Colours: `KelimeUI/Palette.swift` (light and dark hex values). Amber means "zorlanılan", green
  means "öğrenildi"; never red.
- Fonts in `Fonts/`: Newsreader (English words and sentences, serif), Hanken Grotesk (UI),
  JetBrains Mono (self-test pattern). Bundle them; use them everywhere the iOS app does.
- Corner radii, spacing, card styles: follow the SwiftUI code (`Components.swift`,
  `surfaceCard`, `SettingsSection`, chips). Edge-to-edge, predictive back, Material You dynamic
  colour **off** (brand colours).
- App icon: adaptive icon from `tools/make_icon.swift` (cream background, serif "k", half-filled
  orange dot); monochrome layer for themed icons. Alternate icons are not a thing on Android;
  skip them.

## 7. Accounts, sync, Keşfet, feedback (Supabase)

- Project URL `https://elqtyiuvalanlsxuawar.supabase.co`, publishable key in
  `App/Account/AccountManager.swift` (safe to ship; RLS guards data). Use supabase-kt.
- Sign-in: **Google** on Android (Credential Manager, ID token → `signInWithIdToken`). Ask the
  owner to add the Google provider in Supabase and create the OAuth client; don't do it
  yourself. Accounts stay optional; nothing else may require them (store policy).
- Port list sync (`ListSync.swift`: last change wins, tombstones), Keşfet (`discover` RPC,
  popular/new, search, paging), shared lists (`shared_list` RPC; deep link
  `https://enesseval.github.io/kelime/liste.html?id=…` and `kelime://list/<uuid>` via App Links),
  report and block, account deletion (`delete_account` RPC), and the feedback form (`feedback`
  table insert).

## 8. Pro and payments

- RevenueCat Android SDK, same entitlement `pro` and products `pro.monthly`, `pro.yearly`
  (7-day free trial), `pro.lifetime`. Create the Play products only when the owner asks; he
  enters prices. A purchase on one platform unlocks the other when signed in (RevenueCat app
  user ID = Supabase user ID, as on iOS).
- Free vs Pro must match iOS exactly (see memory note and `PaywallTrigger.swift`): Pro adds
  unlimited own lists, sharing, adding lists from Keşfet, exam plan, faster rotation, personal
  puzzle and archive. Never lock something that's free on iOS.
- Paywall: port `WidgetPaywall` (the live design in `App/Store/PaywallDesigns.swift`): monthly,
  yearly, lifetime; the legal note under the button; restore, terms, privacy. Follow Google Play
  subscription disclosure rules.

## 9. Analytics and privacy

- TelemetryDeck Android SDK, same app ID as iOS (`App/Settings/Analytics.swift`), same signal
  names plus the 1.1 ones in `V1_1_PLAN.md`. Anonymous, no ads ID.
- Privacy page: `site/gizlilik.html`. Update it (in a separate commit, owner reviews) for the
  wallpaper permission, Google sign-in and Play billing. Prepare the Play Data safety answers
  in `docs/ANDROID_PLAY.md`.

## 10. Order of work (each step ends with a working build and passing tests)

1. Gradle project, Compose shell with five tabs, design tokens, fonts, Room schema, content
   import, `AppClock` and local dates. Port and test learning rules, scheduler, spaced review.
2. Bugün, word detail (TTS, share card), Kelimelerim with lists, course units and stories.
3. Quick Review and the custom keyboard; crossword (daily + personal).
4. Widget queue and **lock-screen wallpaper**, Glance home widgets, optional notification,
   Quick Settings tile. Measure real update times on a device; write findings to the notes.
5. Onboarding, placement test, settings, reminders (notification at a chosen time).
6. 1.1 features: streak and weekly summary, Kelime Avı, Eşleştir, share cards.
7. Accounts, sync, Keşfet, feedback. Pro and paywall.
8. Polish: dark mode, font scale up to 200 %, TalkBack labels, small screens (360 dp wide),
   performance (cold start < 1.5 s on a mid-range phone), release AAB with R8, signing config
   that reads the keystore path from `local.properties` (the owner creates the keystore).
9. `docs/ANDROID_PLAY.md`: listing text (Turkish, from `APP_STORE.md`), screenshots plan,
   content rating answers, data safety, and a test checklist like `docs/TEST_CHECKLIST.md`.

## 11. Definition of done

- Every iOS 1.0 feature and every `V1_1_PLAN.md` feature works, or the gap is written down with
  a reason in `docs/ANDROID_NOTES.md`.
- The lock-screen wallpaper changes on schedule on at least a Pixel and a Samsung device (the
  owner tests; give him a checklist).
- Unit tests green, a release AAB builds, no network calls except Supabase, RevenueCat,
  TelemetryDeck and the content manifest.
