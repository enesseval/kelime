package com.enesseval.kilitkelime.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.learning.SystemRandom
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.LevelSamples
import com.enesseval.kilitkelime.core.model.OnboardingChoices
import com.enesseval.kilitkelime.core.review.PlacementQuestion
import com.enesseval.kilitkelime.core.review.PlacementTest
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.ThinProgressBar
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.profile.LockSetupContent
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private enum class Step { INTRO, LEVEL, PLACEMENT, LOCK }

/**
 * First launch: intro, level (or the placement test), the lock-screen choices. The daily reminder
 * is asked after the first good moment instead (`ReminderAsk`).
 */
@Composable
fun OnboardingFlow() {
    val app = LocalApp.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    var step by remember { mutableStateOf(Step.INTRO) }
    var level by remember { mutableStateOf(CEFRLevel.A1) }
    var finishing by remember { mutableStateOf(false) }

    BackHandler(enabled = step != Step.INTRO) {
        step = when (step) {
            Step.LEVEL -> Step.INTRO
            Step.PLACEMENT -> Step.LEVEL
            Step.LOCK -> Step.LEVEL
            Step.INTRO -> Step.INTRO
        }
    }

    fun finish() {
        if (finishing) return
        finishing = true
        scope.launch {
            app.model.write("onboarding") { db ->
                OnboardingChoices(level, null).save(db)
                Curriculum.switchLevel(level, db)
                WidgetQueue.clearCurrentAndFuture(db, app.model.clock)
                WidgetQueue.refill(db, app.model.clock, SystemRandom())
            }
            app.model.prefs.update { it.copy(onboardingLockAsked = true) }
            Analytics.send(Analytics.Event.onboardingDone)
        }
    }

    Box(Modifier.fillMaxSize().background(c.background)) {
        AnimatedContent(step, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "onboarding") { s ->
            when (s) {
                Step.INTRO -> Intro { step = Step.LEVEL }
                Step.LEVEL -> LevelStep(level, onPick = { level = it }, onTest = { step = Step.PLACEMENT }) { step = Step.LOCK }
                Step.PLACEMENT -> PlacementStep(onDone = { level = it; step = Step.LOCK }, onCancel = { step = Step.LEVEL })
                Step.LOCK -> StepFrame(3, "Kilit ekranı", "En önemli adım bu: kelimeler kilit ekranında görünsün. 30 saniye sürer.", if (finishing) "…" else "Başla", onNext = ::finish, nextEnabled = !finishing) {
                    LockSetupContent(showTitle = false, onboarding = true)
                }
            }
        }
    }
}

/** The cinematic intro, simplified: words land on a lock screen, one after another. */
@Composable
private fun Intro(onStart: () -> Unit) {
    val c = Palette.current
    val words = listOf("serendipity" to "mutlu tesadüf", "brave" to "cesur", "journey" to "yolculuk", "curious" to "meraklı", "dream" to "hayal", "kind" to "nazik")
    var index by remember { mutableIntStateOf(0) }
    var typed by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            val word = words[index % words.size].first
            for (i in 1..word.length) { typed = i; delay(70) }
            delay(1400)
            index++
            typed = 0
        }
    }
    val (word, meaning) = words[index % words.size]
    val meaningAlpha by animateFloatAsState(if (typed == word.length) 1f else 0f, tween(300), label = "meaning")
    Column(
        Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0xFF1B2942), Color(0xFF121110)))).statusBarsPadding().navigationBarsPadding().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("KİLİT KELİME", style = KelimeType.ui(12.sp, FontWeight.Bold).copy(letterSpacing = 1.4.sp), color = Color(0xFF8BB1F7), modifier = Modifier.padding(top = 24.dp))
        Gap(36.dp)
        Text("09:41", style = KelimeType.ui(64.sp, FontWeight.Light), color = Color(0xFFF2EEE7))
        Gap(28.dp)
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.10f)).padding(18.dp)) {
            Text(word.take(typed), style = KelimeType.english(34.sp), color = Color(0xFFF2EEE7))
            Text(meaning, style = KelimeType.ui(15.sp), color = Color(0xFFD8D2C8), modifier = Modifier.alpha(meaningAlpha))
        }
        Box(Modifier.weight(1f))
        Text("Telefonuna her baktığında…\n…bir kelime.", style = KelimeType.english(30.sp), color = Color(0xFFF2EEE7), textAlign = TextAlign.Center)
        Gap(10.dp)
        Text("Kilit ekranında öğren. Oyunla pekiştir.", style = KelimeType.ui(15.sp), color = Color(0xFFD8D2C8), textAlign = TextAlign.Center)
        Gap(24.dp)
        PrimaryButton("Başla", height = 54.dp, onClick = onStart)
    }
}

@Composable
private fun StepFrame(number: Int, title: String, subtitle: String, next: String, onNext: () -> Unit, nextEnabled: Boolean = true, secondary: (@Composable () -> Unit)? = null, content: @Composable () -> Unit) {
    val c = Palette.current
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp)) {
            Text("Adım $number / 3", style = KelimeType.ui(13.sp, FontWeight.Medium), color = c.ink2)
            Gap(6.dp)
            Text(title, style = KelimeType.ui(30.sp, FontWeight.Bold), color = c.ink)
            Gap(6.dp)
            Text(subtitle, style = KelimeType.ui(15.sp), color = c.ink2)
            Gap(18.dp)
            content()
        }
        Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            PrimaryButton(next, height = 54.dp, enabled = nextEnabled, onClick = onNext)
            secondary?.invoke()
        }
    }
}

@Composable
private fun LevelStep(level: CEFRLevel, onPick: (CEFRLevel) -> Unit, onTest: () -> Unit, onNext: () -> Unit) {
    val c = Palette.current
    val levels by loadData { db -> Curriculum.levels(db) }
    StepFrame(
        2, "Seviyen hangisi?", "Emin değilsen 2 dakikalık testle bulalım; seviyeni sonra Ayarlar'dan da değiştirebilirsin.", "Devam", onNext,
        secondary = { TintedButton("Seviyemi bilmiyorum · 2 dk test", onClick = onTest) },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            for (l in CEFRLevel.entries) {
                val available = levels?.contains(l) != false
                val selected = l == level
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(16.dp)).background(if (selected) c.accentSoft else c.surface)
                        .border(if (selected) 2.dp else 1.dp, if (selected) c.accent else c.line, RoundedCornerShape(16.dp))
                        .clickable(enabled = available) { onPick(l) }.padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(l.raw, style = KelimeType.ui(20.sp, FontWeight.Bold), color = if (available) c.ink else c.ink2, modifier = Modifier.padding(end = 16.dp))
                    Text(if (available) LevelSamples.words(l).joinToString(", ") else "Yakında", style = KelimeType.english(18.sp, italic = true), color = c.ink2)
                }
            }
        }
    }
}

@Composable
private fun PlacementStep(onDone: (CEFRLevel) -> Unit, onCancel: () -> Unit) {
    val c = Palette.current
    val data by loadData { db -> PlacementTest.questions(db, SystemRandom()) to Curriculum.levels(db) }
    val scores = remember { mutableStateListOf<Pair<CEFRLevel, Int>>() }
    var asked by remember { mutableIntStateOf(0) }
    var correctThisLevel by remember { mutableIntStateOf(0) }
    var indexInLevel by remember { mutableIntStateOf(0) }
    var current by remember { mutableStateOf<CEFRLevel?>(null) }
    var result by remember { mutableStateOf<CEFRLevel?>(null) }
    val (questions, levels) = data ?: return
    val available = levels.filter { questions.containsKey(it) }
    LaunchedEffect(available) { if (current == null && result == null) current = PlacementTest.nextLevel(scores, available) }

    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        val r = result
        if (r != null) {
            Kicker("ÖNERİLEN SEVİYEN")
            Text(r.raw, style = KelimeType.english(72.sp), color = c.ink)
            Text(LevelSamples.words(r).joinToString(", "), style = KelimeType.english(20.sp, italic = true), color = c.ink2)
            Text("Kolay ya da zor gelirse seviyeni istediğin zaman Ayarlar'dan değiştirebilirsin.", style = KelimeType.ui(14.sp), color = c.ink2)
            Box(Modifier.weight(1f))
            PrimaryButton("${r.raw} ile başla", height = 54.dp) { onDone(r) }
            TintedButton("Kendim seçeyim", onClick = onCancel)
            return@Column
        }
        val level = current ?: return@Column
        val question: PlacementQuestion = questions[level]?.getOrNull(indexInLevel) ?: return@Column
        ThinProgressBar(asked / 12.0, color = c.accent)
        Text("${asked + 1}. soru", style = KelimeType.ui(13.sp, FontWeight.Medium), color = c.ink2)
        Text("Bu kelimenin anlamı ne?", style = KelimeType.ui(15.sp), color = c.ink2)
        Text(question.card.word, style = KelimeType.english(44.sp), color = c.ink)
        fun answer(correct: Boolean) {
            asked++
            if (correct) correctThisLevel++
            if (indexInLevel + 1 < PlacementTest.PER_LEVEL) {
                indexInLevel++
            } else {
                scores += level to correctThisLevel
                correctThisLevel = 0
                indexInLevel = 0
                val next = PlacementTest.nextLevel(scores, available)
                if (next == null) {
                    result = PlacementTest.result(scores, available)
                    Analytics.send(Analytics.Event.placementTest)
                } else current = next
            }
        }
        for (option in question.options) {
            Box(
                Modifier.fillMaxWidth().heightIn(min = 54.dp).clip(RoundedCornerShape(14.dp)).background(c.surface).border(1.dp, c.line, RoundedCornerShape(14.dp))
                    .clickable { answer(option == question.answer) }.padding(horizontal = 16.dp),
                contentAlignment = Alignment.CenterStart,
            ) { Text(option, style = KelimeType.ui(16.sp), color = c.ink) }
        }
        TintedButton("Bilmiyorum") { answer(false) }
        Box(Modifier.weight(1f))
        Text("Vazgeç", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.ink2, modifier = Modifier.align(Alignment.CenterHorizontally).clickable(onClick = onCancel).padding(10.dp))
    }
}
