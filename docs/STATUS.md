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

1. ~~Team ID and App Group~~ — done: team `82S9ART43D`; a signed device build provisions
   `com.enesseval.kelime` and `.widget` with `group.com.enesseval.kelime` in both profiles.
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

## Developer tools (build 3)

TestFlight and Debug builds show **Ayarlar › Geliştirici**: Pro without purchase (on by default),
reset today's puzzles, reset the free Quick Review limit, show onboarding again.
They come from `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEV_TOOLS` in
`Config/Shared.xcconfig`. **Remove that line before the App Store submission**: App Review also
runs with a sandbox receipt and must see the real paywall.

## Widget log and measurement mode (build 5)

Geliştirici › Widget günlüğü records, in the shared `widget_log` table (migration v3):
- every timeline iOS requests from the extension (`timeline`), and every reload the app triggers
  (`appReload`), so iOS-scheduled reloads can be told apart from ours;
- every tap on the widget: widget links carry `src` and the entry's `slot`, so a tap shows which
  entry iOS had on screen versus the one scheduled for that moment (on time, or how late);
- widget buttons (Biliyorum / Zorlanıyorum / quiz).

Measurement mode (`settings.widget_probe = 1`) gives the widget only the current slot with
`.after(nextSlot)`, so every change needs an iOS reload. Off by default and for everyone else:
normal mode hands iOS 24 hours of entries. Optional :00/:30 reminders ask the tester to tap the widget.

## Apple Watch (build 9)

Targets `KelimeWatch` (watchOS 10+ app, embedded in the iPhone app under `Watch/`) and
`KelimeWatchWidgetsExtension` (complications and Smart Stack).

- The watch has no database. The iPhone sends a `WatchPayload` (the widget queue's next
  24 hours, card data, today's review count, widget mode) over WatchConnectivity after every
  change: `updateApplicationContext` always, and `transferCurrentComplicationUserInfo` (about
  50 a day, spaced 25 min) when a Kelime complication is on the face. `PhoneWatchSync`.
- The watch stores it in its own App Group container (`watch-payload.json`); the app and the
  complications read it. `WatchSession`, `WatchPayloadStore`.
- Taps on the watch (Biliyorum, Zorlanıyorum, mini review answers) apply locally at once and
  go to the phone with `transferUserInfo`, recorded like widget buttons (`WatchAction`).
- If the phone app is not opened for a day, the watch repeats the last day's words rather
  than going blank. The iPhone widget extension cannot use WatchConnectivity.
- Complications reuse the lock-screen views: rectangular (also Smart Stack), inline,
  corner, and the circular review ring.
- Not tested on a simulator (no watchOS simulator verification on this Mac); verify on device.

## A1 course (build 11)

Content/curriculum/A1/ holds the course: a core everyone studies first, eight units in any
order, and a bridge unit to A2 last; 285 cards (228 words, 57 phrases) and 44 stories.
tools/check_unit.py enforces that each unit's examples and stories use only the grammar words,
the core and the unit itself; tools/build_curriculum.py merges the course into
Content/cards.json (cards with optional `note` and extra `senses`, pos `phrase`/`prep`, and a
top-level `units` list with card ids and stories).

In the app: migration v4 adds card notes/senses, `unit` and `unit_card`. A1 cards reach the
widget and Quick Review only from started units (`units_started`; the core counts as started).
A1 is free; A2/B1 stay the default decks for everyone else (`DeckID.basicDecks`). Phrases are
never write questions or crossword words, and only compete with phrases as quiz options.
Units have stories (Turkish on demand, tap to hear), phrases and words. Word detail shows
extra senses and the note.

## B2 course (content v7, build 17)

Content/curriculum/B2/: core (36 words, 7 phrases), ten units and a bridge to C1 (mixed
conditionals, cleft sentences, not only… but also); 323 cards. About 40 checker problems and a
round of translation fixes; four idioms shortened to the 28-character lock-screen limit. The old
B2 deck and puzzles are gone. Exam decks keep every word: build_curriculum.py carries YDS/YÖKDİL/
IELTS tags onto course cards (and onto the same word at another level, e.g. b1-claim), and exam
decks take tagged words whether or not their unit is started. The YDS goal orders units by
science, academic, society and work topics. Onboarding and Ayarlar offer A1-B2; C1 is "Yakında".

## B1 course (content v5)

Content/curriculum/B1/: core (43 words, 7 phrases, 3 stories), ten units and a bridge to B2
(If I were…, I wish…, reported speech, it is said that); 337 cards. With the "read every line
word by word" rule in the prompt, Gemini's first pass had 24 checker problems (A2: 140). Six
basic cards were added to the core by hand (interesting, favourite, true, keep, past, hard).
The old B1 deck and its bundled puzzles are gone; Onboarding and Ayarlar now offer A1-B1.

## A2 course (build 16, content v3)

Content/curriculum/A2/: core (52 words, 7 phrases, 3 stories), ten units in any order and a
bridge to B1; 356 cards, 58 stories. Learners at A2 may use all of A1, so check_unit.py and
unit_prompt.py take every earlier level's vocabulary and A2 grammar words, and flag words that
already have an A1 card. Gemini wrote the units; the checker plus review fixed ~140 out-of-list
words and translation slips, and 19 basic cards were added by hand (long, short, fast, ready,
problem, talk, food, life, plane, tree…). The old A2 deck and its bundled puzzles are gone.
pos "conj" is new, so content schema is 2: older builds skip downloaded content. Onboarding at a
level with units enables only that course (plus an exam deck).

## Units replace decks (build 13)

Where the learner's level has units, they are the content: no separate "A1 yolu" entry.
Bugün shows "Şu anki bölüm" (progress, a story once half the unit is learned, and "A2
seviyesine geç" once the bridge is nearly done and A2 has units). Kelimelerim's "Bölümler"
lists the units in the learner's order plus the exam decks; levels without units still show
the old deck cards. `Curriculum.advance` runs with every widget refresh: at 80% learned the
next unit starts and becomes current (a started, mostly unlearned unit first, then the next
in order). The goal orders the any-order units (`Curriculum.goalTopics`: travel puts café,
city, shopping first; work puts day, city, café first). "Bu bölüme geç" lets the learner pick.
Moving to the next level keeps earlier units started, so their struggling cards stay.

## Start over and A1 only (build 14)

`ProgressReset` clears progress, reviews, puzzles, the widget queue and onboarding choices,
keeping content, the purchase and the widget log, and sets A1 until onboarding picks a level.
It runs once per `ProgressReset.epoch` at launch (epoch 1: everyone starts over for the unit
model) and from Ayarlar › Baştan başla › İlerlemeyi sıfırla. Onboarding and Ayarlar offer only
levels with units (`Curriculum.levels`; now A1), the others show "Yakında". Samples in
onboarding, settings previews and the widget gallery are A1 words.

Daily puzzles at a level with units come from `CoursePuzzle` (build 15): single words of the
started units, with up to four struggling ones placed first, one grid per day seeded by the
date. Today's grid is kept at the first widget refresh (`<daily key>-grid` in
puzzle_progress), and an archive day's grid is kept when it is opened, so a grid never changes
under saved progress. Levels without units keep the bundled Content/puzzles files.

## Content updates (build 13)

Content is bundled and works offline. The Pages workflow also publishes
`content/manifest.json` and `content/cards.json` (tools/publish_content.py) whenever
Content/cards.json changes on main. The app checks the manifest at most every six hours
(launch and foreground), downloads newer content, checks size and sha256, imports it and keeps
it in the App Group; at launch the newer of bundled and downloaded content is used, and content
never steps back to an older version. Bump `schema` in both the script and
`ContentUpdater.schema` if cards.json changes shape in a way older apps cannot read. Pushing a
new contentVersion to main ships it to every user: run the checks first. The privacy and terms
pages now say the app fetches this file and sends nothing about the learner.
