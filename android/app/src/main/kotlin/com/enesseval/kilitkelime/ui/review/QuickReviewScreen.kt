package com.enesseval.kilitkelime.ui.review

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.SystemRandom
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.core.review.QuickReview
import com.enesseval.kilitkelime.core.review.ReviewQuestion
import com.enesseval.kilitkelime.core.review.ReviewSession
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.EmptyText
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.LetterKeyboard
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.StateDot
import com.enesseval.kilitkelime.ui.components.ThinProgressBar
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import com.enesseval.kilitkelime.ui.components.OutlineButton
import com.enesseval.kilitkelime.ui.components.TR

/**
 * Quick Review (port of `QuickReviewView.swift`): 10 questions, pick the word or type it with the
 * first letter given; the answer panel slides up from the bottom; then the summary.
 */
@Composable
fun QuickReviewScreen(deck: DeckID?) {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    var session by remember { mutableStateOf<ReviewSession?>(null) }
    var tick by remember { mutableIntStateOf(0) } // ReviewSession mutates in place; this redraws
    var picked by remember { mutableStateOf<String?>(null) }
    /** Letters typed after the given first letter. */
    var typed by remember { mutableStateOf("") }
    var lastCorrect by remember { mutableStateOf<Boolean?>(null) }
    var lastAnswer by remember { mutableStateOf("") }
    var saving by remember { mutableStateOf(false) }

    suspend fun start() {
        val questions = app.model.read { db -> QuickReview.makeQuestions(db, SystemRandom(), deck, app.model.clock.today) }
        if (questions.isEmpty()) { router.back(); return }
        session = ReviewSession(questions)
        picked = null; typed = ""; lastCorrect = null
        tick++
    }
    LaunchedEffect(Unit) { start() }

    fun submit(question: ReviewQuestion, answer: String) {
        val s = session ?: return
        if (s.awaitingContinue || saving) return
        saving = true
        val correct = question.isCorrect(answer)
        scope.launch {
            val (before, after) = app.model.write("review") { db ->
                val before = LearningStore.state(question.card.id, db).state
                val after = LearningStore.record(LearningEvent.Answered(correct), question.card.id, ReviewSource.QUICK_REVIEW, app.model.clock, db, s.id).state
                before to after
            }
            s.record(correct, before, after)
            lastCorrect = correct
            lastAnswer = answer
            saving = false
            tick++
        }
    }

    fun next() {
        val s = session ?: return
        s.advance()
        picked = null; typed = ""; lastCorrect = null
        tick++
        // A finished round counts today for the streak (docs/V1_1_PLAN.md §1).
        if (s.isFinished && s.questions.isNotEmpty()) scope.launch {
            app.model.studied("review-finished", com.enesseval.kilitkelime.core.games.StreakSource.QUICK_REVIEW) { db ->
                LearningStore.markStudied(app.model.clock.today, com.enesseval.kilitkelime.core.games.StreakSource.QUICK_REVIEW, db)
            }
        }
    }

    Column(Modifier.fillMaxSize().background(c.background).statusBarsPadding().navigationBarsPadding()) {
        val s = session ?: return@Column
        @Suppress("UNUSED_EXPRESSION") tick
        if (s.isFinished) {
            Summary(s, onDone = { router.back() }, onMore = { scope.launch { start() } })
            return@Column
        }
        val q = s.current ?: return@Column
        // Top bar: ✕, progress, "3/10".
        Row(Modifier.fillMaxWidth().padding(start = 8.dp, end = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(44.dp).clip(CircleShape).clickable { router.back() }.semantics { contentDescription = "Kapat" }, contentAlignment = Alignment.Center) {
                Icon(Icons.Default.Close, null, tint = c.ink2)
            }
            ThinProgressBar(s.progress, Modifier.weight(1f), c.accent)
            Text("${minOf(s.index + 1, s.questions.size)}/${s.questions.size}", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2, textAlign = TextAlign.End, modifier = Modifier.width(40.dp))
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 28.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(q.kicker, style = KelimeType.ui(12.sp, FontWeight.SemiBold).copy(letterSpacing = 1.sp), color = c.ink2)
            Text(q.card.meaning, style = KelimeType.ui(30.sp, FontWeight.SemiBold).copy(letterSpacing = (-0.4).sp), color = c.ink)
            when (val kind = q.kind) {
                is ReviewQuestion.Kind.Meaning -> {
                    Gap(8.dp)
                    Options(kind.options, q, picked) { option ->
                        if (picked == null && !saving) { picked = option; submit(q, option) }
                    }
                    if (!s.awaitingContinue) {
                        Text(
                            "Bilmiyorum", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.ink2, textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(enabled = !saving) { submit(q, "") }.wrapContentHeight(),
                        )
                    }
                }
                ReviewQuestion.Kind.Write -> {
                    Gap(4.dp)
                    WriteArea(q, typed, lastCorrect)
                }
            }
        }
        val correct = lastCorrect
        if (s.awaitingContinue && correct != null) {
            Feedback(q, correct, lastAnswer, onNext = ::next)
        } else if (q.kind == ReviewQuestion.Kind.Write) {
            val word = q.card.word
            val ready = typed.length == word.length - 1
            Row(Modifier.padding(horizontal = 12.dp).padding(bottom = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlineButton("Bilmiyorum") { if (!saving) submit(q, "") }
                PrimaryButton("Kontrol et", Modifier.weight(1f), enabled = ready && !saving) { submit(q, word.take(1) + typed) }
            }
            LetterKeyboard(onLetter = { if (typed.length < word.length - 1) typed += it }, onDelete = { if (typed.isNotEmpty()) typed = typed.dropLast(1) })
        }
    }
}

@Composable
private fun Options(options: List<String>, q: ReviewQuestion, picked: String?, onPick: (String) -> Unit) {
    val c = Palette.current
    val answered = picked != null
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (option in options) {
            val right = option == q.card.word
            val chosen = option == picked
            val (bg, border) = when {
                answered && right -> c.greenBackground to c.green
                answered && chosen -> c.amberBackground to c.amber
                else -> c.surface to c.line
            }
            Row(
                Modifier.fillMaxWidth().heightIn(min = 60.dp).alpha(if (answered && !right && !chosen) 0.45f else 1f)
                    .clip(RoundedCornerShape(16.dp)).background(bg).border(1.5.dp, border, RoundedCornerShape(16.dp))
                    .clickable(enabled = !answered) { onPick(option) }.padding(horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(option, style = KelimeType.english(24.sp), color = c.ink, modifier = Modifier.weight(1f))
                if (answered && right) Text("✓", style = KelimeType.ui(16.sp, FontWeight.Bold), color = c.greenInk)
            }
        }
    }
}

/** The blanked sentence and one box per letter; the first is given, the cursor box is blue. */
@Composable
private fun WriteArea(q: ReviewQuestion, typed: String, lastCorrect: Boolean?) {
    val c = Palette.current
    val word = q.card.word
    val answered = lastCorrect != null
    Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
        Text(q.blankedSentence, style = KelimeType.english(22.sp, italic = true), color = c.ink2)
        Row(
            horizontalArrangement = Arrangement.spacedBy(5.dp),
            modifier = Modifier.clearAndSetSemantics {
                contentDescription = "${word.length} harf, ilk harf ${word.first().uppercase(TR)}. Yazılan: $typed"
            },
        ) {
            for (i in word.indices) {
                val letter = when {
                    i == 0 -> word.substring(0, 1).uppercase(TR)
                    lastCorrect == false -> ReviewQuestion.asciiUpper(word.substring(i, i + 1))
                    else -> typed.getOrNull(i - 1)?.toString()?.uppercase(TR) ?: ""
                }
                val cursor = !answered && i == typed.length + 1
                val fill = when {
                    i == 0 -> c.surface2
                    lastCorrect == true -> c.greenBackground
                    lastCorrect == false -> c.amberBackground
                    else -> c.surface
                }
                Box(
                    Modifier.size(width = 34.dp, height = 46.dp).clip(RoundedCornerShape(10.dp)).background(fill)
                        .border(1.5.dp, if (cursor) c.accent else c.line, RoundedCornerShape(10.dp)),
                    contentAlignment = Alignment.Center,
                ) { Text(letter, style = KelimeType.ui(22.sp, FontWeight.SemiBold), color = if (i == 0) c.ink2 else c.ink) }
            }
        }
    }
}

/** The answer panel at the bottom: green or amber, the example, and the dark Devam button. */
@Composable
private fun Feedback(q: ReviewQuestion, correct: Boolean, answer: String, onNext: () -> Unit) {
    val c = Palette.current
    Column(
        Modifier.padding(horizontal = 12.dp).padding(bottom = 12.dp).fillMaxWidth().clip(RoundedCornerShape(22.dp))
            .background(if (correct) c.greenBackground else c.amberBackground).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(if (correct) "Doğru" else "Doğru cevap: ${q.card.word}", style = KelimeType.ui(20.sp, FontWeight.Bold), color = if (correct) c.greenInk else c.amberInk)
        val hint = if (!correct) q.mistakeHint(answer) else null
        if (hint != null) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                // "wom[e]n → woman": wrong letters underlined in amber.
                val wrong = ReviewQuestion.wrongPositions(answer, q.card.word).toSet()
                Text(
                    buildAnnotatedString {
                        answer.lowercase(TR).forEachIndexed { i, ch ->
                            if (i in wrong) withStyle(SpanStyle(color = c.amberInk, textDecoration = TextDecoration.Underline)) { append(ch) }
                            else withStyle(SpanStyle(color = c.ink)) { append(ch) }
                        }
                        withStyle(SpanStyle(color = c.ink2)) { append("  →  ") }
                        withStyle(SpanStyle(color = c.greenInk)) { append(q.card.word) }
                    },
                    style = KelimeType.english(24.sp),
                    modifier = Modifier.semantics { contentDescription = "Yazdığın $answer, doğrusu ${q.card.word}" },
                )
                Text(hint, style = KelimeType.ui(15.sp, FontWeight.Medium), color = c.amberInk)
            }
        } else if (!correct && answer.isNotEmpty() && q.kind is ReviewQuestion.Kind.Meaning) {
            Text("Seçtiğin: $answer", style = KelimeType.ui(15.sp).copy(textDecoration = TextDecoration.LineThrough), color = c.amberInk)
        }
        if (q.card.exampleEN.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(q.card.exampleEN, style = KelimeType.english(23.sp, italic = true), color = c.ink)
                Text(q.card.exampleTR, style = KelimeType.ui(17.sp), color = c.ink.copy(alpha = 0.75f))
            }
        }
        if (!correct) Text("Bu kelimeyi widget'ında daha sık göreceksin", style = KelimeType.ui(16.sp, FontWeight.Medium), color = c.amberInk)
        // iOS InkButtonStyle: ink background, page-coloured text.
        Box(
            Modifier.padding(top = 4.dp).fillMaxWidth().heightIn(min = 50.dp).clip(RoundedCornerShape(14.dp)).background(c.ink).clickable(onClick = onNext),
            contentAlignment = Alignment.Center,
        ) { Text("Devam", style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.background) }
    }
}

/** iOS ReviewSummaryView: "TUR BİTTİ", the score, the words as chips, Bitti and Bir tur daha. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Summary(s: ReviewSession, onDone: () -> Unit, onMore: () -> Unit) {
    val c = Palette.current
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 30.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
        Text("TUR BİTTİ", style = KelimeType.ui(13.sp, FontWeight.SemiBold).copy(letterSpacing = 1.sp), color = c.ink2)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("${s.score}", style = KelimeType.english(96.sp).copy(letterSpacing = (-2.5).sp), color = c.ink)
            Text("/ ${s.questions.size}", style = KelimeType.ui(20.sp), color = c.ink2, modifier = Modifier.padding(bottom = 20.dp))
        }
        if (s.newlyLearned.isNotEmpty()) Chips("Öğrenildi", s.newlyLearned, c.greenInk, c.greenBackground)
        if (s.newlyStruggling.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Chips("Zorlanılan", s.newlyStruggling, c.amberInk, c.amberBackground)
                Text("Bunlar gün boyu kilit ekranında", style = KelimeType.ui(13.sp), color = c.ink2)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            PrimaryButton("Bitti", height = 52.dp, onClick = onDone)
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { OutlineButton("Bir tur daha", onClick = onMore) }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Chips(title: String, words: List<Card>, ink: androidx.compose.ui.graphics.Color, background: androidx.compose.ui.graphics.Color) {
    val c = Palette.current
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(title, style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = ink)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            for (card in words) {
                Text(card.word, style = KelimeType.english(18.sp), color = c.ink, modifier = Modifier.clip(CircleShape).background(background).padding(vertical = 6.dp, horizontal = 12.dp))
            }
        }
    }
}
