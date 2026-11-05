package com.enesseval.kilitkelime.ui.today

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.content.CourseState
import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.crossword.DailyPuzzleSummary
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.UserLists
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.ExamCountdown
import com.enesseval.kilitkelime.core.model.ExamPlan
import com.enesseval.kilitkelime.core.model.ExamPlanStatus
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.WidgetMode
import com.enesseval.kilitkelime.core.queries.DeckQueries
import com.enesseval.kilitkelime.core.queries.StatsQueries
import com.enesseval.kilitkelime.core.queries.WeekStats
import com.enesseval.kilitkelime.core.queries.WeeklySummary
import com.enesseval.kilitkelime.core.queries.WordItem
import com.enesseval.kilitkelime.core.queries.WordQueries
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.LevelChip
import com.enesseval.kilitkelime.ui.components.OutlineButton
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.ProCorner
import com.enesseval.kilitkelime.ui.components.ScreenTitle
import com.enesseval.kilitkelime.ui.components.StateDot
import com.enesseval.kilitkelime.ui.components.SurfaceCard
import com.enesseval.kilitkelime.ui.components.ThinProgressBar
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.components.TurkishDate
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import kotlinx.coroutines.launch

/** Today's crossword progress, for cards and thumbnails. */
data class DailyPuzzleInfo(val level: CEFRLevel, val solved: Int, val total: Int, val completed: Boolean, val thumbnail: Map<Int, Boolean>)

fun dailyPuzzleInfo(db: com.enesseval.kilitkelime.core.db.SqlDb, clock: com.enesseval.kilitkelime.core.dates.AppClock): DailyPuzzleInfo? {
    val context = com.enesseval.kilitkelime.KilitKelimeApp.instance
    val (level, puzzle) = com.enesseval.kilitkelime.ui.puzzle.PuzzleLibrary.daily(context, Preferences.load(db).level, clock.today, db) ?: return null
    val saved = com.enesseval.kilitkelime.core.crossword.PuzzleStore.load(com.enesseval.kilitkelime.core.crossword.DailyPuzzle.key(level, clock.today), puzzle, db)
    return DailyPuzzleInfo(level, saved.game.solvedCount, puzzle.entries.size, saved.completedAt != null, DailyPuzzleSummary.thumbnail(saved.game))
}

/** Everything Bugün shows, read in one go (TodayData). */
data class TodayData(
    val hero: WordItem?,
    val previous: Card?,
    val mode: WidgetMode,
    val strugglingCount: Int,
    val stats: WeekStats,
    val examCountdown: String?,
    val widgetSources: String,
    val level: CEFRLevel,
    val puzzle: DailyPuzzleInfo?,
    val course: CourseState?,
    val examPlan: ExamPlanStatus?,
    val lastWeek: WeeklySummary,
    val streak: com.enesseval.kilitkelime.core.games.StreakStatus,
    val bannerDismissed: Boolean,
)

private fun loadToday(db: com.enesseval.kilitkelime.core.db.SqlDb, clock: com.enesseval.kilitkelime.core.dates.AppClock, pro: Boolean): TodayData {
    val prefs = Preferences.load(db)
    val current = WidgetQueue.current(db, clock)
    val heroID = current?.cardID ?: CardQueries.candidates(prefs.entitledDecks, db).firstOrNull()?.cardID
    val stats = StatsQueries.week(db, clock, pro)
    val exam = ExamCountdown.daysLeft(db, clock)
    val courses = Curriculum.levels(db)
    val lists = UserLists.summaries(db).filter { it.list.enabled && it.total > 0 }.map { it.list.title }
    val decks = if (prefs.enabledDecks.isEmpty() && lists.isNotEmpty()) emptyList() else prefs.entitledDecks
    val sources = decks.map { d -> d.level?.let { if (it in courses) "${it.raw} kursu" else it.raw } ?: d.raw } + lists
    return TodayData(
        hero = heroID?.let { WordQueries.item(it, db) },
        previous = current?.let { WidgetQueue.previous(it.slotStart, db) }?.let { CardQueries.card(it.cardID, db) },
        mode = prefs.defaultWidgetMode,
        strugglingCount = stats.strugglingNow,
        stats = stats,
        examCountdown = exam?.let { (e, days) -> "${e.raw}${if (e == DeckID.YDS) "'ye" else "'e"} $days gün" },
        widgetSources = sources.joinToString(" · "),
        level = prefs.level,
        puzzle = dailyPuzzleInfo(db, clock),
        course = Curriculum.state(db),
        examPlan = ExamPlan.status(db, clock),
        lastWeek = StatsQueries.lastWeek(db, clock, pro),
        streak = com.enesseval.kilitkelime.core.games.Streak.status(db, clock, pro),
        bannerDismissed = com.enesseval.kilitkelime.core.model.Settings.bool(db, com.enesseval.kilitkelime.core.model.SettingKey.WIDGET_BANNER_DISMISSED),
    )
}

@Composable
fun TodayScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val pro by app.model.isPro.collectAsState()
    val data by loadData(pro) { db -> loadToday(db, app.model.clock, pro) }
    val lock by app.model.prefs.flow.collectAsState(initial = null)
    val scope = rememberCoroutineScope()
    val monday = StatsQueries.weekStart(app.model.clock.today) == app.model.clock.today

    // Every Monday the weekly summary opens once, on the first visit (docs/V1_1_PLAN.md §1).
    LaunchedEffect(data?.lastWeek?.weekStart, lock?.lastWeeklySummary) {
        val week = data?.lastWeek ?: return@LaunchedEffect
        val seen = lock?.lastWeeklySummary ?: return@LaunchedEffect
        if (monday && seen != week.weekStart.toString() && week.hasContent) {
            app.model.prefs.update { it.copy(lastWeeklySummary = week.weekStart.toString()) }
            router.openWeekly()
        }
    }

    Column(
        Modifier.fillMaxSize().background(c.background).statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp).padding(top = 6.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.Bottom) {
            Box(Modifier.weight(1f)) { ScreenTitle("Bugün", TurkishDate.header(app.model.clock.today)) }
            data?.streak?.takeIf { it.current > 0 || it.longest > 0 }?.let { streak ->
                Box(Modifier.padding(bottom = 4.dp, end = 6.dp)) { StreakBadge(streak, onClick = router::openStreak) }
            }
            data?.examCountdown?.let {
                Text(
                    it, style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = c.ink2,
                    modifier = Modifier.padding(bottom = 4.dp).clip(CircleShape).border(1.dp, c.line, CircleShape).padding(vertical = 7.dp, horizontal = 11.dp),
                )
            }
        }
        val d = data ?: return@Column
        val l = lock
        if (l != null && !l.wallpaperEnabled && !l.notificationEnabled && !d.bannerDismissed) {
            LockBanner(onOpen = router::openLockSetup) {
                scope.launch {
                    app.model.write("banner") { db ->
                        com.enesseval.kilitkelime.core.model.Settings.setBool(db, com.enesseval.kilitkelime.core.model.SettingKey.WIDGET_BANNER_DISMISSED, true)
                    }
                }
            }
        }
        if (monday && d.lastWeek.hasContent) WeeklySummaryCard(d.lastWeek) { router.openWeekly() }
        d.hero?.let { hero -> HeroCard(hero, d.previous.takeIf { d.mode == WidgetMode.SELF_TEST }) { router.openWord(hero.id) } }
        Row(
            Modifier.fillMaxWidth().heightIn(min = 32.dp).clickable { router.openLists() }.padding(horizontal = 4.dp)
                .semantics { contentDescription = "Widget'ında ${d.widgetSources}. Listeleri değiştir" },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                buildAnnotatedString {
                    withStyle(SpanStyle(color = c.ink2)) { append("Widget'ında: ") }
                    withStyle(SpanStyle(color = c.ink, fontWeight = FontWeight.SemiBold)) { append(d.widgetSources) }
                },
                style = KelimeType.ui(13.sp), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
            )
            Text("Değiştir", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.accent)
        }
        d.course?.let { CurrentUnitCard(it) }
        d.examPlan?.let { ExamPlanCard(it) }
        WeekStatsRow(d.stats)
    }
}

@Composable
private fun LockBanner(onOpen: () -> Unit, onDismiss: () -> Unit) {
    val c = Palette.current
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(c.accentSoft).padding(start = 16.dp, top = 6.dp, bottom = 6.dp, end = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(fontWeight = FontWeight.SemiBold)) { append("Kilit ekranını henüz ayarlamadın.") }
                append(" 30 saniye sürer.")
            },
            style = KelimeType.ui(14.sp), color = c.ink, modifier = Modifier.weight(1f).clickable(onClick = onOpen).padding(vertical = 6.dp),
        )
        IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, contentDescription = "Kapat", tint = c.ink2) }
    }
}

/** "ŞU AN WIDGET'INDA": the current word, large. */
@Composable
fun HeroCard(item: WordItem, previous: Card?, onClick: () -> Unit) {
    val c = Palette.current
    val card = item.card
    SurfaceCard(radius = 26.dp, padding = 21.dp, onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { Kicker("ŞU AN WIDGET'INDA") }
            LevelChip(card.level)
            Spacer(Modifier.width(8.dp))
            StateDot(item.state)
        }
        Gap(12.dp)
        // iOS: 58 pt, one line, scaled down to half for long words and phrases.
        val wordSize = when {
            card.word.length > 16 -> 30.sp
            card.word.length > 11 -> 40.sp
            else -> 58.sp
        }
        Text(card.word, style = KelimeType.english(wordSize).copy(letterSpacing = (-1.4).sp), color = c.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(fontFamily = com.enesseval.kilitkelime.ui.theme.KelimeFonts.english, fontStyle = androidx.compose.ui.text.font.FontStyle.Italic, color = c.ink2)) { append(card.pos.label) }
                append("  ")
                append(card.meaning)
            },
            style = KelimeType.ui(17.sp), color = c.ink,
        )
        Gap(12.dp)
        Box(Modifier.fillMaxWidth().height(1.dp).background(c.line))
        Gap(12.dp)
        if (card.exampleEN.isNotEmpty()) {
            Text(card.exampleEN, style = KelimeType.english(19.sp, italic = true), color = c.ink)
            Text(card.exampleTR, style = KelimeType.ui(14.sp), color = c.ink2)
        }
        previous?.let {
            Gap(10.dp)
            Text("Önceki kelimenin cevabı: ${it.word} · ${it.meaning}", style = KelimeType.ui(13.sp), color = c.ink2)
        }
    }
}

/** "ŞU ANKİ BÖLÜM" (iOS CurrentUnitCard): the unit, its progress, a story once half is learned. */
@Composable
private fun CurrentUnitCard(course: CourseState) {
    val c = Palette.current
    val router = LocalRouter.current
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    val current = course.current
    fun moveOn(next: CEFRLevel) {
        scope.launch { app.model.writeAndRequeue("move-on") { db -> Curriculum.moveOn(next, db) } }
    }
    if (current != null) {
        SurfaceCard(padding = 20.dp) {
            Column(Modifier.fillMaxWidth().clickable { router.openUnit(current.id) }, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("ŞU ANKİ BÖLÜM", style = KelimeType.ui(12.sp, FontWeight.SemiBold).copy(letterSpacing = 0.7.sp), color = c.ink2, modifier = Modifier.weight(1f))
                    Text("${course.level.raw} · ${course.units.indexOfFirst { it.id == current.id } + 1}/${course.units.size}", style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = c.ink2)
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(current.unit.title, style = KelimeType.english(28.sp), color = c.ink, modifier = Modifier.weight(1f))
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2)
                }
                Text(current.unit.goal, style = KelimeType.ui(14.sp), color = c.ink2, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Box(Modifier.padding(top = 2.dp)) { ThinProgressBar(current.fraction) }
                Text("${current.learned}/${current.total} kart öğrenildi", style = KelimeType.ui(12.sp), color = c.ink2)
            }
            // Near the end of the unit the words are known well enough to read a story.
            if (current.fraction >= 0.5 && current.unit.stories.isNotEmpty()) {
                val story = current.unit.stories[current.learned % current.unit.stories.size]
                Gap(10.dp)
                TintedButton("Hikâye oku: ${story.title}") { router.openStory(current.id, story.id) }
            }
            course.nextLevel?.let { next ->
                Gap(10.dp)
                PrimaryButton("${next.raw} seviyesine geç", height = 48.dp) { moveOn(next) }
            }
        }
    } else if (course.isComplete) {
        SurfaceCard(padding = 20.dp) {
            Text("${course.level.raw} bitti 🎉", style = KelimeType.english(28.sp), color = c.ink)
            Gap(6.dp)
            Text(
                course.nextLevel?.let { "${it.raw} bölümleri hazır." } ?: "Sonraki seviyenin bölümleri hazırlanıyor. Zorlandığın kartlar widget'ında kalır.",
                style = KelimeType.ui(14.sp), color = c.ink2,
            )
            course.nextLevel?.let { next ->
                Gap(12.dp)
                PrimaryButton("${next.raw} seviyesine geç", height = 48.dp) { moveOn(next) }
            }
        }
    }
}

/** Bugün's exam plan (Pro). Free users see it with a Pro tag; tapping explains Pro. */
@Composable
private fun ExamPlanCard(plan: ExamPlanStatus) {
    val c = Palette.current
    val app = LocalApp.current
    val router = LocalRouter.current
    val pro by app.model.isPro.collectAsState()
    val scope = rememberCoroutineScope()
    ProCorner(!pro) {
        SurfaceCard(onClick = if (!pro) ({ router.showPaywall(PaywallTrigger.EXAM_PLAN) }) else null) {
            Row {
                Box(Modifier.weight(1f)) { Kicker("SINAV PLANI · ${plan.exam.raw}") }
                if (pro) Text("${plan.daysLeft} gün", style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = c.accent)
            }
            Gap(12.dp)
            if (plan.remaining == 0) {
                Text("Listedeki bütün kelimeleri öğrendin 🎉", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
            } else {
                Text(
                    buildAnnotatedString {
                        withStyle(SpanStyle(color = c.ink2)) { append("Bugün ") }
                        withStyle(SpanStyle(fontWeight = FontWeight.SemiBold)) { append("${minOf(plan.doneToday, plan.dailyTarget)} / ${plan.dailyTarget} kelime") }
                        withStyle(SpanStyle(color = c.ink2)) { append(" · kalan ${plan.remaining}") }
                    },
                    style = KelimeType.ui(16.sp), color = c.ink,
                )
                Gap(12.dp)
                ThinProgressBar(if (pro) plan.fraction else 0.35)
                Gap(12.dp)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PrimaryButton("Sınav tekrarı", Modifier.weight(1f), height = 44.dp) {
                        if (pro) router.startQuickReview(plan.exam) else router.showPaywall(PaywallTrigger.EXAM_PLAN)
                    }
                    if (pro && !plan.listOnWidget) {
                        OutlineButton("Widget'a ekle") {
                            scope.launch { app.model.writeAndRequeue("exam-deck") { db -> DeckQueries.setEnabled(true, plan.exam, db) } }
                        }
                    }
                }
            }
        }
    }
}

val SAMPLE_GRID: Map<Int, Boolean> = buildMap {
    fun word(r: Int, c: Int, length: Int, across: Boolean) {
        for (i in 0 until length) put((if (across) r else r + i) * 8 + (if (across) c + i else c), false)
    }
    word(0, 2, 6, true); word(0, 3, 7, false); word(3, 0, 8, true); word(3, 5, 7, false); word(9, 1, 7, true)
}

/** 8 × 10 crossword thumbnail; letter cells tinted, solved words green. */
@Composable
fun PuzzleThumbnail(cell: Float, gap: Float, cells: Map<Int, Boolean>) {
    val c = Palette.current
    Canvas(Modifier.size(width = (cell * 8 + gap * 7).dp, height = (cell * 10 + gap * 9).dp)) {
        val s = cell.dp.toPx()
        val g = gap.dp.toPx()
        for (row in 0 until 10) for (col in 0 until 8) {
            val solved = cells[row * 8 + col] ?: continue
            drawRoundRect(
                if (solved) c.green else c.surface2,
                topLeft = Offset(col * (s + g), row * (s + g)),
                size = Size(s, s),
                cornerRadius = CornerRadius(s * 0.22f),
            )
        }
    }
}

@Composable
private fun WeekStatsRow(stats: WeekStats) {
    val c = Palette.current
    Row(
        Modifier.fillMaxWidth().height(IntrinsicSize.Min).clip(RoundedCornerShape(18.dp)).background(c.line).border(1.dp, c.line, RoundedCornerShape(18.dp)),
        horizontalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        Stat("${stats.learnedThisWeek}", "öğrenildi", c.ink, Modifier.weight(1f))
        Stat("${stats.strugglingNow}", "zorlanılan", c.amberInk, Modifier.weight(1f))
        Column(
            Modifier.weight(1.4f).fillMaxHeight().background(c.surface).padding(14.dp)
                .semantics { contentDescription = "Bu hafta ${stats.days.count { it.reviewed }} gün tekrar" + if (stats.streak >= 2) ", ${stats.streak} gün üst üste" else "" },
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                for (day in stats.days) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Box(Modifier.size(11.dp).clip(CircleShape).border(1.5.dp, c.green, CircleShape).background(if (day.reviewed) c.green else Color.Transparent))
                        Text(day.initial, style = KelimeType.ui(9.sp), color = c.ink2)
                    }
                }
            }
            Gap(8.dp)
            if (stats.streak >= 2) {
                Text("${stats.streak} gün üst üste", style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = c.greenInk)
            } else {
                Text("bu hafta", style = KelimeType.ui(12.sp), color = c.ink2)
            }
        }
    }
}

@Composable
private fun Stat(value: String, label: String, color: Color, modifier: Modifier) {
    val c = Palette.current
    Column(modifier.fillMaxHeight().background(c.surface).padding(14.dp)) {
        Text(value, style = KelimeType.ui(24.sp, FontWeight.SemiBold), color = color)
        Text(label, style = KelimeType.ui(12.sp), color = c.ink2)
    }
}
