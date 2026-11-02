# Android change log (iOS → Android)

Every fix or feature made on iOS after the Android prompt (docs/ANDROID_PROMPT.md) is written
here, newest first. The Android session reads this file and ports each entry. An entry names the
behaviour, the rule, the timings and the tests to port; the iOS commit is given for reference.

Status: `[ ]` not ported yet, `[x]` ported on Android.

---

## 2026-11-02 · Eşleştir: matched slots refill in batches of three `[ ]`

**Bug on iOS 1.1 (build 29):** After a match, both freed slots were refilled at once, and the
two new tiles were often each other's pair. Tapping the same two rows (e.g. Turkish row 2,
English row 4) matched again and again.

**New behaviour (replaces "doğru çift kaybolur, yerine yenisi gelir" in V1_1_PLAN.md §2b):**
1. The board has 5 English (left) and 5 Turkish (right) slots. At the start the two columns are
   shuffled separately, and **no card has its halves on the same row**.
2. A matched pair fades out and its two slots **stay empty**.
3. When **3 slots per side** are empty (`refillAt = 3`), the next 3 cards from the queue are
   dealt at once: English halves into the empty left slots, Turkish halves into the empty right
   slots, in a random order. Again, no new card gets both halves on the same row (reshuffle up
   to 20 times).
4. If the board becomes completely empty (fewer cards than usual), the refill happens then.
   If the queue has fewer cards than empty slots, deal what is left. When the queue is empty no
   refill happens; the round ends when the board is empty or time runs out.
5. Synonym match (two different cards, same Turkish meaning): the matched English tile and the
   matched Turkish tile leave. The other halves of those two cards stay; they share the meaning,
   so they still match each other. No extra bookkeeping.
6. Randomness comes from a seeded generator so tests are deterministic.

**Animation:**
- Matched tile: fade out, 0.3 s ease-out.
- New tile: fade in, 0.45 s ease-in after a 0.25 s delay.
- Slots have a fixed height (68 dp) so empty slots keep the layout; an empty slot is just blank.
- In Compose: `AnimatedVisibility`/`AnimatedContent` keyed by tile id (`cardId + "-en"` /
  `"-tr"`), `fadeOut(tween(300))`, `fadeIn(tween(450, delayMillis = 250))`.

**Unchanged:** 60 s round, score = matches, wrong pair shakes both tiles and marks the English
card missed (once), first-try matches count as correct, best score stored.

**Tests to port (KelimeCore V11Tests):**
- `noPairStartsOnTheSameRow`: 200 seeds, 10 cards; no row has both halves of one card.
- `matchedSlotsRefillInBatches`: 50 seeds, 30 cards. Always match a visible pair. After every
  match, fewer than 3 slots per side are empty (except at the very end); any newly dealt card is
  not on the same row on both sides; the round ends with score 30 and an empty board.
- `matchGameScoresAndMisses`: a miss then a match; firstTry and missed lists.

**iOS files:** `Packages/KelimeCore/Sources/KelimeCore/Games/MatchGame.swift`,
`App/Games/GameViews.swift` (MatchView `column`).
