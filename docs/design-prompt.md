# Design brief: "Kelime Widget" — English vocabulary on the lock screen, for Turkish speakers

> Working title: **Kelime Widget**. Keep the wordmark a simple placeholder; naming comes later.
> Platform: **iPhone first (iOS 17+)**, plus two Android home-screen widgets at the end.
> **All UI copy is Turkish** (the users are Turkish). This brief is in English; Turkish strings are given where wording matters.

---

## 1. What the product is

An app whose main surface is the **widget**, not the app. Every time the user glances at their phone, they see one English word, its Turkish meaning, and a short example sentence with its Turkish translation. They don't need to open anything.

The app adds one learning loop around that widget:

1. **Play:** a short quiz ("Hızlı Tekrar") or the daily mini crossword ("Günün Bulmacası").
2. **Miss a word:** answer it wrong, or use a hint, and the word becomes **Zorlanılan** (struggling).
3. **See it again:** the widget shows struggling words more often, all day.
4. **Get tested again:** when the user gets it right later, it becomes **Öğrenildi** (learned) and shows up less.

Positioning line (use as hero copy where it fits):
**"Kelimeyi sadece oyunda öğrenmiyorsun; gün boyu kilit ekranında karşına çıkıyor."**
(You don't just meet the word in the game; it keeps coming back on your lock screen all day.)

**Design the app as a quiet utility, not a game app.** The widget is the product. The app is where you set it up, play for two minutes, and check your words. Everything should feel light enough to finish in under 2 minutes.

## 2. Who it's for

- Turkish iPhone users, aged 18–40, at A2–B2 English. They know their vocabulary is weak but don't make time to study.
- Main groups: university students, early-career office workers, and people preparing for **YDS/YÖKDİL** (Turkish national English exams). The exam group is the most likely to pay.
- They have tried Duolingo or WordBit and dropped them. They dislike subscriptions, ads, and guilt-trip streak mechanics.
- A meaningful slice customize their lock screens and care that widgets **look clean**. Aesthetics are part of the value.

## 3. Design direction

- **Typography is the hero.** The English word is the largest, most beautiful element on every card. Consider a characterful display face (e.g. a refined serif or a distinctive grotesk) for English words, with a highly legible sans for Turkish text and UI.
  - **The fonts must fully support Turkish: ğ ş ı İ ç ö ü.**
- **Calm, editorial, premium.** Think a beautifully typeset dictionary page or a minimal lock-screen setup, not a cartoon mascot. No confetti explosions, no shaming.
- **One accent color** plus three state colors that never mean failure:
  - Yeni (new) = neutral
  - Zorlanılan (struggling) = warm amber. **Never red.** Struggling is good: it means the system is working.
  - Öğrenildi (learned) = calm green
- **Light and dark mode for every screen.** Dark mode matters because many people use dark lock screens.
- **Accessibility:** Dynamic Type up to at least XL without breaking card layouts, WCAG AA contrast, and 44pt minimum tap targets.
- **Frame:** iPhone 16 / 15 at 393 × 852 pt. Use SF Symbols-style icons.
- **Navigation:** a bottom tab bar with 4 tabs:
  - **Bugün** (Today)
  - **Oyna** (Play)
  - **Kelimelerim** (My Words)
  - **Ayarlar** (Settings)

## 4. Sample content (use this, not lorem ipsum)

| Word | Type | Level | Turkish | Example (EN) | Example (TR) |
|---|---|---|---|---|---|
| reluctant | adj. | B2 | isteksiz, gönülsüz | She was reluctant to leave. | Ayrılmaya gönülsüzdü. |
| reliable | adj. | B1 | güvenilir | He is a reliable friend. | O, güvenilir bir arkadaş. |
| borrow | v. | A2 | ödünç almak | Can I borrow your pen? | Kalemini ödünç alabilir miyim? |
| hesitate | v. | B2 | tereddüt etmek | Don't hesitate to ask. | Sormaktan çekinme. |
| obvious | adj. | B1 | açık, belli | The answer was obvious. | Cevap belliydi. |
| achieve | v. | B1 | başarmak | You can achieve your goals. | Hedeflerine ulaşabilirsin. |
| ancient | adj. | B1 | antik, çok eski | We visited an ancient city. | Antik bir şehri ziyaret ettik. |
| significant | adj. | B2 · YDS | önemli, kayda değer | There was a significant increase in prices. | Fiyatlarda kayda değer bir artış oldu. |
| consequence | n. | B2 · YDS | sonuç | Every choice has a consequence. | Her seçimin bir sonucu vardır. |

**Content limits.** Every layout must survive these maximums:

| Field | Limit |
|---|---|
| English word | ≤ 16 characters |
| Turkish meaning | ≤ 28 characters (1–2 meanings) |
| Example sentences | ≤ 55 characters each |

## 5. Free vs Pro (needed for locks and the paywall)

| | Free | Pro |
|---|---|---|
| Word decks | A2 + B1 general | All levels A1–C1, **YDS**, **YÖKDİL**, IELTS |
| Hızlı Tekrar (quick review) | 1 session per day (10 words) | Unlimited |
| Günün Bulmacası (daily crossword) | Today's puzzle | Today's puzzle + full archive |
| Widget rotation | Every 3 hours / once a day | Every 30 min, 1 hour, 3 hours, or once a day |
| Widget themes | 1 | All |
| Ads / account | None, ever | None, ever |

Placeholder prices (not final):

- **Ömür boyu ₺249**: highlighted as the recommended option. Many users hate subscriptions.
- **Yıllık ₺149**: includes a 7-day free trial.

## 6. Widgets (design these first, they are the product)

Each widget must be designed in these renderings:

- **Lock screen:** Apple renders lock-screen widgets as **vibrant, monochrome**. Design with a single tint and opacity levels only, no color.
- **Home screen:** default light, default dark, and iOS 18 **tinted** mode.

Show each widget **on a realistic lock screen or home screen mockup**, with wallpaper, clock, and neighboring widgets, so we can judge it in context.

### 6.1 Lock screen

1. **accessoryInline** (the single line above the clock): `reluctant · isteksiz`
2. **accessoryRectangular** has three display modes. The user picks one in Settings.
   - **Kart (Card):** the word large, then `adj. · isteksiz, gönülsüz`.
   - **Cümle (Sentence):** `She was reluctant to leave.` with `Ayrılmaya gönülsüzdü.` underneath.
   - **Kendini sına (Self-test):** this works as a pair of consecutive widget states. Design both.
     - State A (question): `isteksiz → r _ _ _ _ _ _ _ _`, showing the first letter and the letter count.
     - State B (answer): `reluctant`, with the meaning shown smaller.
     - The widget alternates A → B over time, so the user tries to recall the word before the answer appears. No tap needed.
   - A small dot or mark shows the word's state. It must work in monochrome, so use shape rather than color: for example, a hollow dot = new, a half dot = struggling, a full dot = learned.
3. **accessoryCircular:** today's review ring. Words reviewed today against the daily target, with a small number in the center.

### 6.2 Home screen

1. **Small (~170 × 170):** the word plus its Turkish meaning, a level chip, and a state dot. Tapping it opens the word detail screen.
2. **Medium (~364 × 170).** Two variants:
   - **Card + actions:** the full card (word, type, Turkish meaning, example EN/TR) with two buttons that work without opening the app: **"Biliyorum"** (I know it) and **"Zorlanıyorum"** (I'm struggling).
   - **Quiz:** the Turkish meaning `isteksiz` with two English options, `reluctant` and `reliable`. Design all three states:
     - unanswered
     - correct: check mark, example sentence revealed
     - wrong: amber, the correct answer shown, plus the note "Bu kelime sık gelecek" (this word will come up more often)
3. **Large (~364 × 382):**
   - Top: the current card.
   - Middle: "Bugün zorlandıkların" (today's struggling words), a list of 3 words with their meanings.
   - Bottom: a daily crossword teaser, "Günün Bulmacası · 2/5 kelime", with a mini grid thumbnail.

### 6.3 Widget edge states

Design each of these:

- **First launch / no data:** "Kelimelerini görmek için uygulamayı bir kez aç" (Open the app once to see your words).
- **Pro theme preview in the widget gallery.**
- **Long word plus long meaning:** shows how text truncates or scales.

### 6.4 Android (secondary, two frames only)

- **2×2** small card and **4×2** card with Biliyorum/Zorlanıyorum buttons.
- Use Material You dynamic color: the same structure, adapted to Android's rounded widget shapes.

### 6.5 Widget themes

Design **5 themes** that look good on real wallpapers. Show them on a theme picker screen (section 7.9). One is free; the other four are Pro.

Suggested directions:

1. Paper (warm off-white, serif)
2. Ink (true black, high contrast)
3. Glass (translucent)
4. Ember (one warm accent)
5. Mono (pure typographic)

## 7. App screens

### 7.1 Onboarding (6 screens, skippable where sensible)

1. **Welcome:** a realistic lock-screen mockup showing the widget. Headline "Telefonuna her baktığında bir kelime." Primary button "Başla".
2. **Goal ("Neden İngilizce?"):** single select.
   - Options: Genel İngilizce · YDS / YÖKDİL · İş hayatı · Seyahat ve dizi.
   - If YDS/YÖKDİL is picked, ask for an optional exam date ("Sınav tarihin?") with a date picker and a "Henüz belli değil" (not decided yet) option.
3. **Level:** A2 / B1 / B2 / C1 cards. Each card shows 3 example words so the user can self-assess, for example "B1: reliable, obvious, achieve". Add a small link: "Emin değilim, ortadan başlat" (Not sure, start in the middle).
4. **Widget rhythm:** how often the card changes: 30 dk (Pro badge) / 1 saat (Pro) / 3 saat / Günde bir. Show a live preview of the widget that updates when the user picks.
5. **Add the widget:** the most important onboarding screen. Widget adoption is make-or-break.
   - An illustrated, step-by-step guide with 2 tabs: "Kilit ekranı" (lock screen) and "Ana ekran" (home screen).
   - Steps are 3–4 numbered panels with phone illustrations, for example "Kilit ekranına basılı tut → Özelleştir → Widget ekle → Kelime Widget".
   - Buttons: "Ekledim" (I added it) and "Sonra" (Later).
6. **Notifications (optional):** a pre-permission screen. "Günde bir hatırlatma: tekrar zamanı" (One reminder a day: time to review), with a time picker. Buttons: "İzin ver" (Allow) and "Gerek yok" (No thanks).

**No paywall in onboarding.**

### 7.2 Bugün (Today), the home tab

- **Hero:** the current widget card, large, exactly as the widget shows it. Tapping it opens Word Detail.
- **"Hızlı Tekrar" card:** "5 zorlandığın kelime seni bekliyor" (5 words you struggled with are waiting), with a primary button "Başla · 2 dk" (Start · 2 min). When the free daily session is used up, the card shows "Yarın tekrar · ya da Pro ile sınırsız" (Again tomorrow, or unlimited with Pro).
- **"Günün Bulmacası" card:** mini grid thumbnail, progress, and a "Devam et" (Continue) button.
- **Small stats row:** this week's learned count, the struggling count, and review days this week as 7 small dots.
  - This is gentle tracking, not a streak with punishment. Missing a day shows nothing negative.
- **Widget not added banner:** dismissible. "Widget'ı henüz eklemedin. 30 saniye sürer." (You haven't added the widget yet. It takes 30 seconds.) Tapping it opens the guide.
- **Exam users only:** a quiet countdown chip, "YDS'ye 34 gün" (34 days until YDS).

### 7.3 Word Detail (sheet or full screen)

- **Content:**
  - the word, set large
  - a pronunciation button (device text-to-speech)
  - word type and level chip
  - deck chips (for example "YDS")
  - the Turkish meanings
  - the example sentence EN with its Turkish translation below
  - a state chip: Yeni / Zorlanılan / Öğrenildi
- **Actions:** "Biliyorum" · "Zorlanıyorum" · Favori (star) · Paylaş (share as image) · "Hata bildir" (report an error, kept small and quiet).
- **Report error flow:** a sheet with reasons: Anlam yanlış (wrong meaning) / Cümle yanlış (wrong sentence) / Çeviri doğal değil (unnatural translation) / Diğer (other). It ends with a confirmation toast.
- **Share image:** a 9:16 story card in the current widget theme. The word, meaning, and example sit large, with a small app wordmark at the bottom.

### 7.4 Oyna (Play) tab

A single, calm hub with two entries:

- **Hızlı Tekrar:** shows the free sessions remaining today.
- **Günün Bulmacası:** shows today's puzzle state. Below it, "Arşiv" (Archive) has a Pro lock.

If YDS is the goal, add a third entry: **"Sınav Destesi Tekrarı"** (exam deck review). This is a Pro lock for free users.

### 7.5 Hızlı Tekrar (Quick Review) session

- **Length:** 10 questions. A thin progress bar at the top and a close (X) button.
- **Question types.** Design both:
  1. **Meaning → word:** "isteksiz, gönülsüz" with 4 English options (reluctant, reliable, relevant, remote).
  2. **Write the word:** shows the Turkish meaning and the example sentence with a blank: "She was ________ to leave."
     - Letter boxes show the word's length, with the first letter given.
     - Input uses the **custom English keyboard** (section 7.6).
- **Feedback states:**
  - Correct: subtle green, the full example sentence revealed, and a "Devam" button.
  - Wrong: amber, the correct answer shown with its example, and the line "Bu kelimeyi widget'ında daha sık göreceksin" (You'll see this word more often in your widget).
  - Nothing should feel punishing.
- **Summary screen:**
  - score (7/10)
  - words newly moved to **Öğrenildi** (shown as chips)
  - words moved to **Zorlanılan** (chips, with the caption "Bunlar gün boyu kilit ekranında" — these will be on your lock screen all day)
  - buttons: "Bitti" (Done), plus "Bir tur daha" (one more round, Pro) or "Yarın devam" (continue tomorrow, free)

### 7.6 Günün Bulmacası (daily mini crossword)

Clues are in **Turkish** and answers are **English**. Puzzles are pre-made, one per day per level.

- **Grid:** must fit a phone and handle sizes from 7×7 to 10×10. Visual states for cells:
  - empty and filled
  - active cell and active word highlight
  - hint-revealed letter (a subtle marker)
  - checked-wrong letter
  - completed word
- **Clue bar:** sits above the keyboard. Shows the current clue, "3 Yatay · tereddüt etmek (8)" (3 Across · to hesitate, 8 letters), with prev/next arrows. Tapping it opens the full clue list sheet, split into Yatay (Across) and Dikey (Down).
- **Custom keyboard:** English A–Z QWERTY, no Turkish letters, plus a backspace key.
  - It must be custom so the Turkish system keyboard can't insert "İ/ı".
- **Toolbar** (top, or above the keyboard):
  - **Harf aç** (reveal a letter)
  - **Kelimeyi kontrol et** (check the word)
  - **Kelimeyi göster** (reveal the word)
  - Using any of these marks the word Zorlanılan. Show this with a subtle amber outline on its clue.
- **Completion screen:**
  - time taken and hints used
  - "Widget'ına eklenen kelimeler" (words added to your widget): chips for every word the user needed help with
  - a share button that shares a spoiler-free result grid image
  - a "Yarın yeni bulmaca" (new puzzle tomorrow) note
- **Archive screen (Pro):** a calendar or list of past puzzles with level and completion state. Free users see it blurred, with a paywall entry.

Use this **real, valid sample grid** for the mock (8 columns × 10 rows, coordinates are row, col from 0):

| No. | Direction | Answer | Clue (TR) | Start (row, col) |
|---|---|---|---|---|
| 1 | Yatay (Across) | BORROW | ödünç almak (6) | 0, 2 |
| 2 | Dikey (Down) | OBVIOUS | açık, belli (7) | 0, 3 |
| 3 | Yatay (Across) | HESITATE | tereddüt etmek (8) | 3, 0 |
| 4 | Dikey (Down) | ACHIEVE | başarmak (7) | 3, 5 |
| 5 | Yatay (Across) | ANCIENT | antik, çok eski (7) | 9, 1 |

How the words cross:

- BORROW and OBVIOUS share the O at (0,3).
- HESITATE crosses OBVIOUS at the I at (3,3), and crosses ACHIEVE at the A at (3,5).
- ANCIENT crosses ACHIEVE at the E at (9,5).

All other cells are blocks. Show a mid-game state: BORROW and OBVIOUS solved, HESITATE active with 3 letters typed, and one hint-revealed letter.

### 7.7 Kelimelerim (My Words)

- **Search field** at the top.
- **Segmented control:** Zorlanılan · Öğrenildi · Favoriler · Tümü.
- **Word rows:** each row shows the word, its Turkish meaning, a state chip, and a level chip. Swipe actions: Biliyorum / Zorlanıyorum.
- **Desteler (Decks) section:** reached from a header button or as a second view.
  - Deck cards: A1, A2, B1, B2, C1, YDS, YÖKDİL, IELTS.
  - Each card shows its word count, a progress bar (learned / total), and an on/off toggle for "widget'ta göster" (show in widget).
  - Pro decks show a lock.
- **"Bu hafta" mini summary** at the top: learned this week and struggling now.
- **Empty states:**
  - No struggling words: "Zorlandığın kelime yok. Bir Hızlı Tekrar ile başla." (No struggling words. Start with a Quick Review.)
  - Deck fully learned: "Bu desteyi bitirdin 🎉 Bir üst seviyeyi aç." (You finished this deck. Unlock the next level.)

### 7.8 Ayarlar (Settings)

- **Seviye ve hedef** (level and goal), with the exam date if any.
- **Widget:**
  - Değişim sıklığı (rotation frequency)
  - Görünüm modu: Kart / Cümle / Kendini sına (display mode: Card / Sentence / Self-test)
  - Tema (theme)
  - "Widget nasıl eklenir?" (How to add the widget) — reopens the guide
- **Hatırlatma** (reminder): on/off and time.
- **Telaffuz** (pronunciation): voice and speed.
- **Pro:** current plan, Satın alımları geri yükle (restore purchases).
- **Hakkında** (About):
  - word-list attribution: "Kelime listesi: New General Service List, CC BY-SA 4.0"
  - "İçerik yapay zekâ ile üretildi ve kontrol edildi" (content was AI-generated and reviewed)
  - privacy and terms

### 7.9 Theme picker

- A large live preview of the lock-screen rectangular widget and the home medium widget on a real wallpaper, for each of the 5 themes.
- A "Duvar kağıdını değiştir" (change wallpaper) toggle that switches between 3 sample wallpapers: light photo, dark photo, solid color.
- Pro themes show a lock. Selecting one opens the paywall.

### 7.10 Paywall (soft, contextual, honest)

- **Triggers:**
  - free review limit reached
  - tapping a Pro deck
  - tapping the archive
  - tapping a Pro theme
  - a 30-minute rotation option
- **Never shown on first launch.** The headline adapts to the trigger, for example "YDS destesini aç" (Unlock the YDS deck) or "Sınırsız tekrar" (Unlimited review).
- **Benefits list, 4–5 lines, benefit-first:**
  - Sınırsız Hızlı Tekrar
  - YDS · YÖKDİL · IELTS desteleri
  - B2–C1 kelimeler
  - Bulmaca arşivi
  - Tüm temalar ve 30 dk değişim
- **Plans:** Ömür boyu (lifetime) is visually recommended with a "Tek seferlik ödeme, abonelik yok" (one-time payment, no subscription) label. Yıllık (annual) shows "7 gün ücretsiz dene" (try free for 7 days).
- **Footer:** restore purchases, terms, and a clear close button.
- **Trust line:** "Reklam yok. Hesap yok. İnternetsiz çalışır." (No ads. No account. Works offline.)
- **No dark patterns.** No fake timers, and no hidden close button.

## 8. Components to deliver as a mini design system

- **Typography scale:** an English word display style at 3 sizes (widget, card, hero), Turkish meaning, sentence, UI text, and caption.
- **Color tokens:** light and dark, the 3 learning-state colors, accent, and surfaces. Include the monochrome lock-screen rules.
- **Components:**
  - word card (widget-size and in-app)
  - state chip, level chip, deck chip
  - option button (default, selected, correct, wrong)
  - letter box input
  - crossword cell (all states)
  - clue bar
  - custom keyboard
  - progress bar
  - primary and secondary buttons
  - paywall plan card
  - toast
  - bottom sheet
- **Widget frame templates** for every family above.

## 9. Deliverables checklist

- [ ] All widget families and states (section 6) in lock-screen monochrome, home light, home dark, and home tinted, shown in context on device mockups
- [ ] Android 2×2 and 4×2
- [ ] 5 widget themes
- [ ] Onboarding (6 screens)
- [ ] Bugün, including the widget-not-added and exam-countdown variants
- [ ] Word Detail, the report-error sheet, and the share story image
- [ ] Oyna hub
- [ ] Hızlı Tekrar: both question types, the correct and wrong states, and the summary
- [ ] Günün Bulmacası: mid-game, clue list sheet, completion, and archive (Pro and locked)
- [ ] Kelimelerim: list, decks, and empty states
- [ ] Ayarlar
- [ ] Theme picker
- [ ] Paywall: the base version plus 2 trigger-specific headline variants
- [ ] Component sheet and tokens
- [ ] Every screen in light and dark

## 10. Out of scope (do not design)

Accounts or login, social features, leaderboards, ads, AI chat, grammar lessons, a Scrabble-style game, and long streak or XP gamification.
