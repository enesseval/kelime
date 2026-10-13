# Build prompt: Kelime Widget, native iOS (Swift / SwiftUI)

You are building **Kelime Widget**, a native iPhone app plus a widget extension. The working title may change, so keep the display name in one place.

Read these before writing code:

- `design/`: final screen and widget designs. **This is the visual source of truth.** Match layout, typography, spacing and colors exactly. If a design and this prompt disagree on visuals, the design wins. If they disagree on behavior, this prompt wins; flag the conflict in your summary.
- `docs/design-prompt.md`: the brief the designs were made from. Use it for screen names, states, free/Pro rules, sample content and Turkish copy.
- `docs/PRD.md` (if present): product background.

All UI copy is **Turkish** and comes from the designs and the design brief. Code, comments, identifiers and commit messages are English.

---

## 1. Product in one paragraph

The widget is the product. It shows one English word, its Turkish meaning, and an example sentence with its Turkish translation, on the lock screen and home screen. Around the widget sits a learning loop:

1. The user plays a **Quick Review** ("Hızlı Tekrar") or a **crossword** ("Günün Bulmacası" / "Kişisel Bulmaca").
2. A word they miss, or need a hint for, becomes **struggling**.
3. The widget shows struggling words more often.
4. When the user later answers a word correctly, it becomes **learned** and is shown less.

Everything runs offline. There is no account, no backend, no ads and no analytics SDK in v1.

## 2. Fixed technical decisions

| Area | Decision |
|---|---|
| Toolchain | **Xcode 26.3** (the version on the build Mac). Do not use APIs that need a newer SDK. Swift 6 language mode. |
| Deployment target | **iOS 17.0**, for both app and widget. iOS 17 gives interactive widgets (`Button(intent:)`), `@Observable`, and `containerBackground`. Use iOS 18-only APIs behind `if #available`. |
| Devices | **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`), portrait. |
| UI | SwiftUI. Use `@Observable` models, `NavigationStack`, and a `TabView` with 4 tabs: Bugün, Oyna, Kelimelerim, Ayarlar. No UIKit unless SwiftUI can't do it (mail composer, share sheet). |
| Persistence | **SQLite via GRDB** (SPM). The database lives in the **App Group container**, uses WAL mode, and is opened with `DatabasePool` by both the app and the widget extension. Do not use SwiftData or Core Data: the app and the widget's App Intents both write to the same store. |
| Purchases | **StoreKit 2, no third-party SDK.** One non-consumable `pro.lifetime` and one auto-renewable `pro.yearly` (in group "Pro", with a 7-day free-trial introductory offer). Entitlement comes from `Transaction.currentEntitlements` plus `Transaction.updates`. Cache `isPro` in the shared database so the widget can read it. Include a `.storekit` configuration file for local testing. |
| Widgets | WidgetKit plus App Intents. Use `AppIntentConfiguration` so each widget instance can pick its display mode (Kart / Cümle / Kendini sına), with the app's setting as the default. |
| Speech | `AVSpeechSynthesizer`, en-US voice. No network, no audio files. |
| Notifications | Local `UNUserNotificationCenter` only: one daily reminder at a user-chosen time. |
| Tests | Swift Testing (`import Testing`) for all logic in the core package. |
| Dependencies | GRDB only. Ask before adding anything else. |

## 3. Project structure

Create the Xcode project with **folder-synchronized groups** (the Xcode 16+ default). Adding a Swift file inside a target folder must not require editing `project.pbxproj`. Keep project-file edits to target and capability changes.

```
KelimeWidget.xcodeproj
App/                      # app target (synchronized folder)
Widget/                   # widget extension target (synchronized folder)
Packages/KelimeCore/      # local Swift package, linked by BOTH targets
  Sources/KelimeCore/     #   models, DB, migrations, scheduler, dates, crossword, content import, entitlement cache
  Sources/KelimeUI/       #   design tokens, fonts, shared views (WordCardView etc.) used by app AND widget
  Tests/KelimeCoreTests/
Content/                  # bundled data (app target resources)
  cards.json
  puzzles/<level>.json
tools/                    # Python scripts: validate cards, build daily puzzles (run on any OS)
Config/Shared.xcconfig    # MARKETING_VERSION, CURRENT_PROJECT_VERSION, bundle id prefix, team
design/  docs/
```

**Rule: one definition per type.** Anything the app and the widget both use lives in `KelimeCore` or `KelimeUI`, never duplicated in each target. This includes the snapshot and entry types, intents' shared logic, and colors.

Commit the `.xcodeproj` and its **shared scheme** (`xcshareddata/xcschemes`). Use a standard Xcode `.gitignore`: `xcuserdata/`, `DerivedData/`, `*.xcuserstate`, `.build/`. **Do not ignore any folder named `ios` or `Widget`.**

## 4. Data model

### Content (read-only, from `Content/cards.json`)

```json
{ "id": "b2-reluctant", "word": "reluctant", "pos": "adj", "level": "B2",
  "tr": ["isteksiz", "gönülsüz"], "example_en": "She was reluctant to leave.",
  "example_tr": "Ayrılmaya gönülsüzdü.", "decks": ["general", "yds"] }
```

- The file carries a top-level `contentVersion`.
- On first launch, and whenever `contentVersion` changes, the app imports the cards into the shared database. The import runs in one transaction, off the main actor, with a visible progress state.
- On a version change, upsert by `id` and keep user progress. Never wipe user progress.
- Ship a ~200-card sample `cards.json` until the real 3–5k set arrives. Code must not assume a card count.

### User state (shared DB)

| Table | Columns / purpose |
|---|---|
| `card_state` | `card_id`, `state` (new / struggling / learned), `correct_streak`, `last_shown_at`, `last_answered_on` (LocalDate), `times_shown`, `favorite` |
| `widget_queue` | `slot_start`, `card_id`, `quiz_options` (JSON), `quiz_answer` (nullable), for the next 24h |
| `settings` | Key-value: level, goal, exam date, enabled decks, rotation interval, default widget mode, theme, reminder time, `is_pro`, `onboarding_done` |
| `review_log` | One row per answered question, used for "this week" stats and the free daily limit |
| `puzzle_progress` | `puzzle_key`, `cells` (JSON), `hints_used`, `completed_at`, `seconds` |

Schema changes are **numbered GRDB migrations** (`DatabaseMigrator`). Never edit a migration that has shipped.

### Learning-state rules (pure functions in KelimeCore, fully unit-tested)

- Wrong answer, or any crossword hint ("Harf aç", "Kelimeyi kontrol et" showing an error, "Kelimeyi göster") → **struggling**, and `correct_streak` resets to 0.
- A correct answer on a **new** word → **learned**.
- A correct answer on a **struggling** word increments `correct_streak`. Two correct answers on **different local days** → **learned**.
- "Biliyorum" (widget or app) → **learned**. "Zorlanıyorum" → **struggling**.

### Widget selection weights

| State | Weight |
|---|---|
| struggling | 3 |
| new | 1 |
| learned | 0.2, and only if last shown more than 14 days ago |

- Never repeat a card within the last 20 slots.
- Only use cards from enabled decks the user is entitled to.

## 5. Dates (this caused real bugs in the previous app)

- Every "day" concept uses the **device's local calendar day**: the daily puzzle, the free-session reset, "different days" for learning, and weekly stats.
- Represent a day as a `LocalDate` value type (`YYYY-MM-DD`), built from `Calendar.current` date components.
- **Never** derive a day from UTC. `ISO8601DateFormatter` and `Date.description` are UTC by default, so they are banned for day keys.
- Inject a `Clock`/`now` provider so tests can cross midnight and DST boundaries.

## 6. Widgets

Implement every family and state in the designs:

- **Lock screen:** `accessoryInline`, `accessoryRectangular` (3 modes) and `accessoryCircular` (today's review ring).
- **Home screen:** `systemSmall`, `systemMedium` (card + actions, and quiz) and `systemLarge`.

How they work:

- **Timeline.** Each reload, build entries for the next 24 hours from `widget_queue` (refilling it if short), one entry per rotation slot, with policy `.atEnd`. The widget never touches the network.
  - The budget is roughly 40–70 reloads a day, so put many entries in one timeline. Do not reload often.
- **Self-test mode** (rectangular). Each slot has two entries: the question (`isteksiz → r _ _ _ _ _ _ _ _`) at the slot start, and the answer at `start + min(interval / 2, 30 min)`.
- **Interactive intents.** Three intents: `MarkKnownIntent`, `MarkStrugglingIntent`, `AnswerQuizIntent(cardID, option)`.
  - They write to the shared DB through KelimeCore, then call `WidgetCenter.shared.reloadAllTimelines()`.
  - The quiz's answered state persists in `widget_queue.quiz_answer` until the next slot.
  - Interactivity on the lock screen may be limited, so design the rectangular modes to work with no taps.
- **Reload from the app** after every state, settings, purchase or content change.
- **Rendering modes.** Support `widgetRenderingMode`:
  - `.vibrant` on the lock screen: no color, use opacity and shape; the state dot is hollow, half or full.
  - `.accented` (iOS 18 tinted): mark accent parts with `widgetAccentable()`.
  - `.fullColor`.
- **Memory.** Widget extensions have a tight memory limit (~30 MB). Query only the rows needed. Never load all cards in the extension.
- **Empty state.** If the shared DB isn't populated yet (the app was never opened), show "Kelimelerini görmek için uygulamayı bir kez aç".
- **Fonts.** Custom fonts must be bundled in **both** targets and listed under `UIAppFonts` in **both** Info.plists. Otherwise the widget silently falls back to the system font.
- **Previews.** Write `#Preview(as:)` for every family × mode × state, using sample entries.
- The app detects whether any widget is installed with `WidgetCenter.shared.getCurrentConfigurations`. This drives the "Widget'ı henüz eklemedin" banner on Bugün.

## 7. App features (screens per `design/`)

- **Onboarding (6 screens).**
  - The goal step includes an optional exam date, plus a "Henüz belli değil" option.
  - The level step has 3 sample words per level.
  - The rhythm step has a live widget preview.
  - The widget-add guide has 2 tabs (Kilit ekranı / Ana ekran).
  - Notification pre-permission is the last step.
  - No paywall during onboarding.
- **Bugün.** Hero card, Quick Review card (free limit state), daily crossword card, "this week" stats with 7 dots (no punishment), widget-not-added banner, exam countdown chip.
- **Word Detail.** Speak button, state/level/deck chips, Biliyorum / Zorlanıyorum / favorite / share.
  - "Hata bildir" opens a reason sheet, then `MFMailComposeViewController` (fall back to `mailto:`) with the card id prefilled. The address is a placeholder in Config.
  - Share renders a 9:16 story image with `ImageRenderer`.
- **Quick Review.**
  - 10 questions. Struggling words come first, then new words the widget has already shown, then other new words.
  - Two question types:
    - Meaning → 4 English options. Distractors come from the same level and part of speech.
    - Write the word, with letter boxes and the first letter given.
  - Correct and wrong feedback states, then a summary screen.
  - **Free: 1 session per local day. Pro: unlimited.**
- **Crossword.** See section 8.
- **Kelimelerim.**
  - Search, segments (Zorlanılan / Öğrenildi / Favoriler / Tümü), swipe actions.
  - A decks view with progress and a "widget'ta göster" toggle. Pro decks are locked.
  - Empty states as designed.
- **Ayarlar.** Level/goal, widget settings, theme, reminder, voice, Pro / restore purchases, About. About shows the NGSL CC BY-SA 4.0 attribution and the AI-content note.
- **Theme picker.** 5 themes, previewed on sample wallpapers. Pro themes are locked.
- **Paywall.**
  - Soft and contextual. The headline is keyed by trigger: review limit, Pro deck, archive, theme, 30-minute rotation, personal puzzle.
  - Lifetime is the recommended plan. Yearly shows the trial.
  - Restore purchases and a clearly visible close button.
  - Prices come from `Product.displayPrice`; never hard-code them.

## 8. Crossword

### Daily puzzle (free)

- Pre-generated and bundled in `Content/puzzles/<level>.json` as an ordered array.
- Today's puzzle is `puzzles[dayIndex % count]`, where `dayIndex` counts local days since a fixed epoch. It must never fail when the content runs out; it wraps.
- Everyone at a level gets the same puzzle each day.
- Clues are the card's `tr` meaning plus the letter count, for example `tereddüt etmek (8)`.

### Personal puzzle (Pro)

- Generated **on device** when opened, using the same screens as the daily puzzle. Its entry point is in the Oyna hub.
- **Generator** (a pure KelimeCore function):
  - It builds a free-form crossword (not a dense grid) that fits within 10×10 and holds at least 6 words, aiming for 7.
  - It must include up to 4 of the user's struggling words as seeds.
  - Filler words come from the user's enabled decks at their level.
  - Placement rules: words cross only on matching letters, no letter cells touch unless they are part of a crossing word, and the cells immediately before and after each word are empty.
  - It retries up to 40 times. If it still fails, it falls back to 3 seeds, then 2.
  - It is deterministic for a given seed and finishes in under 50 ms on device.
- A Python prototype of this algorithm, run against 4,000 words, succeeded 94% of the time at about 0.7 ms per puzzle. Port the idea and test it in Swift.

### Crossword UI

- Grid cell states, active word highlight, a clue bar with previous/next, and a full clue list sheet (Yatay / Dikey).
- A **custom A–Z keyboard view.** Never use the system keyboard: Turkish locale input turns `i` into `İ`.
- Compare letters with **ASCII uppercasing** (`uppercased(with: Locale(identifier: "en_US_POSIX"))`), never the device locale.
- Toolbar: Harf aç, Kelimeyi kontrol et, Kelimeyi göster. Using any of them marks that word struggling.
- Progress persists in `puzzle_progress`.
- Completion screen, plus a spoiler-free share image.
- The archive is Pro.

### Tests (both kinds of puzzle)

- **Every bundled daily puzzle** is loaded and checked: crossings consistent, no illegal adjacency, every answer exists in `cards.json`, and clue = card meaning.
- **10,000 randomized personal generations:** all valid, at least 90% succeed with 4 seeds, and all succeed with the fallback.

## 9. Known pitfalls from our previous apps (do not repeat)

1. **Release-only launch failures.** A missing Info.plist usage key crashed the previous app at launch only in TestFlight builds.
   - Every framework that touches a protected resource needs its usage description, so audit Info.plist for both targets.
   - Before declaring done, build the **Release** configuration and confirm it launches cleanly.
2. **Frozen launch with no visible error.**
   - No heavy work on the main actor before the first frame. The content import and migrations run async.
   - Any startup failure shows a readable error screen with the step name. Never leave a blank or frozen screen.
3. **Duplicated cross-target types drifting apart.** The shared package is the only place shared types live.
4. **App Group mismatches.** The group is `group.<app bundle id>`, set in **both** targets' entitlements. Read the group id from one constant in KelimeCore. The widget bundle id is `<app bundle id>.widget`.
5. **Version mismatch between app and extension.** `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` come from `Config/Shared.xcconfig` for both targets. Uploads fail when they differ.
6. **Notification tap handled repeatedly.** Handle a notification response once, route it, then clear it. Ignore duplicate deliveries of the same response.
7. **Toolchain drift.** The build Mac runs Xcode 26.3. Don't adopt Swift or SDK features from newer Xcode versions.
8. **gitignore swallowing source.** Never use broad ignore patterns. After the first commit, verify that `git ls-files` contains the widget sources, the package, the `.xcodeproj` and the shared scheme.
9. **iPhone only.** `supportsTablet` is off, so there are no iPad layouts or screenshots to worry about.

## 10. Release requirements

- `ITSAppUsesNonExemptEncryption = NO` in the app's Info.plist.
- `PrivacyInfo.xcprivacy` in both targets. Declare the required-reason APIs you actually use: UserDefaults with `CA92.1`, and `1C8F.1` if App Group defaults are used. Declare no tracking and no collected data. GRDB ships its own manifest.
- App icon, launch screen (theme background, no logo animation) and the display name in one place.
- `CFBundleDevelopmentRegion = tr`, and a String Catalog with Turkish only.
- Accessibility: Dynamic Type up to XL without broken layouts, VoiceOver labels on the widget, the card and the crossword cells, and 44 pt tap targets.

## 11. Build order

This all ships in **one v1.0 release**. The milestones are only the build order. **Every milestone must compile and pass tests before you start the next one.**

1. Project, both targets, App Group, shared xcconfig, KelimeCore/KelimeUI packages, GRDB, migrations, `LocalDate`/clock, content import, and the first tests.
2. Scheduler, learning-state rules and the widget queue, with tests.
3. All widgets, intents and previews.
4. Bugün, Word Detail and Kelimelerim/decks.
5. Quick Review.
6. The crossword: daily puzzle, personal generator, UI and tests.
7. StoreKit 2, the paywall and gating everywhere.
8. Onboarding, settings, theme picker and notifications.
9. Accessibility, privacy manifest, a Release-build check and a final pass against `design/`.

## 12. How to verify

Find an available simulator with `xcrun simctl list devices available`, then:

```bash
swift test --package-path Packages/KelimeCore
xcodebuild -scheme KelimeWidget -destination 'platform=iOS Simulator,name=<available iPhone>' build test
xcodebuild -scheme KelimeWidget -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

If you are running somewhere without Xcode, say so clearly at the end of each milestone. Never claim the code compiles when you could not build it.

## 13. Tools (Python, runs on Windows too)

- `tools/validate_cards.py`: checks the schema, the limits (word ≤16, tr ≤28, sentences ≤55 chars), that the word appears in `example_en`, unique ids, and that every card has a level and decks.
- `tools/build_puzzles.py`: generates the daily puzzles per level from `cards.json` (default 400 per level) with a fixed seed, and validates them. The Swift test above re-validates the output.
