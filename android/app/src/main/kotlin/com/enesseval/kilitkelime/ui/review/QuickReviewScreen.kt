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

/** Quick Review: 10 questions, pick the word or type it with the first letter given. */
@Composable
fun QuickReviewScreen(deck: DeckID?) {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    var session by remember { mutableStateOf<ReviewSession?>(null) }
    var loaded by remember { mutableStateOf(false) }
    var tick by remember { mutableIntStateOf(0) } // ReviewSession mutates in place; this redraws
    var chosen by remember { mutableStateOf<String?>(null) }
    var typed by remember { mutableStateOf("") }

    suspend fun start() {
        val questions = app.model.read { db -> QuickReview.makeQuestions(db, SystemRandom(), deck, app.model.clock.today) }
        session = ReviewSession(questions)
        chosen = null
        typed = ""
        loaded = true
        tick++
    }
    LaunchedEffect(Unit) { start() }

    fun answer(question: ReviewQuestion, correct: Boolean, choice: String) {
        val s = session ?: return
        if (s.awaitingContinue) return
        chosen = choice
        scope.launch {
            val (before, after) = app.model.write("review") { db ->
                val before = LearningStore.state(question.card.id, db).state
                val after = LearningStore.record(LearningEvent.Answered(correct), question.card.id, ReviewSource.QUICK_REVIEW, app.model.clock, db, s.id).state
                before to after
            }
            s.record(correct, before, after)
            tick++
        }
    }

    fun advance() {
        val s = session ?: return
        s.advance()
        chosen = null
        typed = ""
        tick++
        // A finished round counts today for the streak (docs/V1_1_PLAN.md §1).
        if (s.isFinished && s.questions.isNotEmpty()) scope.launch {
            app.model.studied("review-finished", com.enesseval.kilitkelime.core.games.StreakSource.QUICK_REVIEW) { db ->
                LearningStore.markStudied(app.model.clock.today, com.enesseval.kilitkelime.core.games.StreakSource.QUICK_REVIEW, db)
            }
        }
    }

    Column(Modifier.fillMaxSize().background(c.background).statusBarsPadding()) {
        val s = session
        @Suppress("UNUSED_EXPRESSION") tick
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { router.back() }) { Icon(Icons.Default.Close, "Kapat", tint = c.ink) }
            if (s != null && !s.isFinished) {
                ThinProgressBar(s.progress, Modifier.weight(1f), c.accent)
                Text("${minOf(s.index + 1, s.questions.size)}/${s.questions.size}", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2, modifier = Modifier.padding(horizontal = 12.dp))
            }
        }
        when {
            !loaded -> {}
            s == null || s.questions.isEmpty() -> Box(Modifier.padding(20.dp)) { EmptyText("Tekrar edilecek kelime yok. Widget'ta bir liste ya da kurs aç.") }
            s.isFinished -> Summary(s, onAgain = { scope.launch { start() } }, onDone = { router.back() })
            else -> {
                val q = s.current!!
                when (val kind = q.kind) {
                    is ReviewQuestion.Kind.Meaning -> MeaningQuestion(q, kind.options, chosen, s.awaitingContinue, onPick = { answer(q, it == q.card.word, it) }, onContinue = ::advance)
                    ReviewQuestion.Kind.Write -> WriteQuestion(
                        q, typed, chosen, s.awaitingContinue,
                        onType = { if (!s.awaitingContinue && typed.length < q.card.word.length) typed += it },
                        onDelete = { if (!s.awaitingContinue && typed.length > 1) typed = typed.dropLast(1) },
                        onCheck = { answer(q, q.isCorrect(typed), typed) },
                        onSkip = { answer(q, false, "") },
                        onContinue = ::advance,
                        onStart = { if (typed.isEmpty()) typed = q.card.word.take(1).lowercase(java.util.Locale.ROOT) },
                    )
                }
            }
        }
    }
}

@Composable
private fun Prompt(q: ReviewQuestion) {
    val c = Palette.current
    Kicker(q.kicker)
    Gap(10.dp)
    Text(q.card.meaning, style = KelimeType.ui(28.sp, FontWeight.SemiBold), color = c.ink)
    Text(q.card.pos.label, style = KelimeType.english(17.sp, italic = true), color = c.ink2)
}

@Composable
private fun MeaningQuestion(q: ReviewQuestion, options: List<String>, chosen: String?, answered: Boolean, onPick: (String) -> Unit, onContinue: () -> Unit) {
    val c = Palette.current
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Prompt(q)
        Gap(14.dp)
        for (option in options) {
            val isAnswer = option == q.card.word
            val (bg, ink, border) = when {
                answered && isAnswer -> Triple(c.greenBackground, c.greenInk, c.green)
                answered && option == chosen -> Triple(c.amberBackground, c.amberInk, c.amber)
                else -> Triple(c.surface, c.ink, c.line)
            }
            Box(
                Modifier.fillMaxWidth().heightIn(min = 58.dp).clip(RoundedCornerShape(14.dp)).background(bg).border(1.dp, border, RoundedCornerShape(14.dp))
                    .clickable(enabled = !answered) { onPick(option) }.padding(horizontal = 18.dp),
                contentAlignment = Alignment.CenterStart,
            ) { Text(option, style = KelimeType.english(22.sp), color = ink) }
        }
        if (answered) {
            Feedback(q, chosen == q.card.word, chosen)
            PrimaryButton("Devam", onClick = onContinue)
        }
    }
}

@Composable
private fun WriteQuestion(
    q: ReviewQuestion, typed: String, chosen: String?, answered: Boolean,
    onType: (Char) -> Unit, onDelete: () -> Unit, onCheck: () -> Unit, onSkip: () -> Unit, onContinue: () -> Unit, onStart: () -> Unit,
) {
    val c = Palette.current
    val word = q.card.word
    LaunchedEffect(q.id) { onStart() }
    val wrong = if (answered && chosen != null) ReviewQuestion.wrongPositions(chosen, word).toSet() else emptySet()
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Prompt(q)
            if (q.card.exampleEN.isNotEmpty()) Text(q.blankedSentence, style = KelimeType.english(19.sp, italic = true), color = c.ink)
            Gap(10.dp)
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.semantics { contentDescription = "${word.length} harf, ilk harf ${word.first().uppercaseChar()}. Yazılan: $typed" },
            ) {
                for (i in word.indices) {
                    val letter = typed.getOrNull(i)?.uppercaseChar()?.toString() ?: ""
                    val color = when {
                        !answered -> c.line
                        i in wrong -> c.amber
                        else -> c.green
                    }
                    Box(Modifier.size(width = 30.dp, height = 40.dp).clip(RoundedCornerShape(8.dp)).background(c.surface).border(1.5.dp, color, RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
                        Text(letter, style = KelimeType.mono(20.sp), color = c.ink)
                    }
                }
            }
            if (answered) {
                Feedback(q, chosen?.let { q.isCorrect(it) } == true, chosen?.ifEmpty { null })
                PrimaryButton("Devam", onClick = onContinue)
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    TintedButton("Bilmiyorum", Modifier.weight(1f), onClick = onSkip)
                    PrimaryButton("Kontrol et", Modifier.weight(1f), height = 44.dp, enabled = typed.length == word.length, onClick = onCheck)
                }
            }
        }
        if (!answered) LetterKeyboard(onLetter = onType, onDelete = onDelete)
    }
}

@Composable
private fun Feedback(q: ReviewQuestion, correct: Boolean, chosen: String?) {
    val c = Palette.current
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(if (correct) c.greenBackground else c.amberBackground).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (correct) {
            Text("Doğru", style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.greenInk)
        } else {
            Text("Doğru cevap: ${q.card.word}", style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.amberInk)
            if (q.kind == ReviewQuestion.Kind.Write && chosen != null) q.mistakeHint(chosen)?.let { Text(it, style = KelimeType.ui(14.sp), color = c.amberInk) }
            Text("Bu kelimeyi widget'ında daha sık göreceksin", style = KelimeType.ui(13.sp), color = c.amberInk)
        }
        if (q.card.exampleEN.isNotEmpty()) {
            Text(q.card.exampleEN, style = KelimeType.english(16.sp, italic = true), color = c.ink)
            Text(q.card.exampleTR, style = KelimeType.ui(13.sp), color = c.ink2)
        }
    }
}

@Composable
private fun Summary(s: ReviewSession, onAgain: () -> Unit, onDone: () -> Unit) {
    val c = Palette.current
    val router = LocalRouter.current
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Kicker("TUR BİTTİ")
        Row(verticalAlignment = Alignment.Bottom) {
            Text("${s.score}", style = KelimeType.english(72.sp), color = c.ink)
            Text(" / ${s.questions.size}", style = KelimeType.ui(22.sp), color = c.ink2, modifier = Modifier.padding(bottom = 14.dp))
        }
        if (s.newlyLearned.isNotEmpty()) WordGroup("Öğrenildi", LearningState.LEARNED, s.newlyLearned) { router.openWord(it) }
        if (s.newlyStruggling.isNotEmpty()) {
            WordGroup("Zorlanılan", LearningState.STRUGGLING, s.newlyStruggling) { router.openWord(it) }
            Text("Bunlar gün boyu kilit ekranında", style = KelimeType.ui(13.sp), color = c.ink2)
        }
        Gap(8.dp)
        PrimaryButton("Bir tur daha", onClick = onAgain)
        TintedButton("Bitti", onClick = onDone)
    }
}

@Composable
private fun WordGroup(title: String, state: LearningState, cards: List<Card>, onOpen: (String) -> Unit) {
    val c = Palette.current
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            StateDot(state)
            Text(title, style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.ink)
        }
        for (card in cards) {
            Row(Modifier.fillMaxWidth().clickable { onOpen(card.id) }.padding(vertical = 4.dp)) {
                Text(card.word, style = KelimeType.english(19.sp), color = c.ink, modifier = Modifier.weight(1f))
                Text(card.meaning, style = KelimeType.ui(14.sp), color = c.ink2)
            }
        }
    }
}

