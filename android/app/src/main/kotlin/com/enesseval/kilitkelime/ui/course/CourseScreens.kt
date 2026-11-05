package com.enesseval.kilitkelime.ui.course

import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.content.CurriculumUnit
import com.enesseval.kilitkelime.core.queries.WordQueries
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.SettingsSection
import com.enesseval.kilitkelime.ui.components.StateDot
import com.enesseval.kilitkelime.ui.components.SurfaceCard
import com.enesseval.kilitkelime.ui.components.ThinProgressBar
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.word.Speaker
import kotlinx.coroutines.launch

/** Bölümler: the course at the learner's level, in the order they meet the units. */
@Composable
fun UnitListScreen() {
    val course by loadData { db -> Curriculum.state(db) }
    PushedScreen("Bölümler") {
        val state = course ?: return@PushedScreen
        UnitList(state)
    }
}

/** iOS UnitList: the level's units in order; the current one framed in blue. */
@Composable
fun UnitList(state: com.enesseval.kilitkelime.core.content.CourseState) {
    val router = LocalRouter.current
    val c = Palette.current
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Bölümler sırayla açılır; biri bitmeye yakınken sıradaki başlar. İstersen başka bir bölüme geçebilirsin.", style = KelimeType.ui(13.sp), color = c.ink2)
        for (item in state.units) {
            val isCurrent = item.id == state.currentID
            Box(Modifier.then(if (isCurrent) Modifier.border(1.5.dp, c.accent, androidx.compose.foundation.shape.RoundedCornerShape(18.dp)) else Modifier)) {
                SurfaceCard(radius = 18.dp, padding = 16.dp, onClick = { router.openUnit(item.id) }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(item.unit.title, style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink, modifier = Modifier.weight(1f))
                        when {
                            item.isFinished -> Text("Bitti ✓", style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = c.greenInk)
                            isCurrent -> Text("Şu an · ${item.learned}/${item.total}", style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = c.accent)
                            item.started -> Text("${item.learned}/${item.total}", style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = c.ink2)
                            else -> Text("${item.total} kart", style = KelimeType.ui(12.sp), color = c.ink2)
                        }
                    }
                    Gap(6.dp)
                    Text(item.unit.goal, style = KelimeType.ui(13.sp), color = c.ink2, maxLines = 2, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                    if (item.started) {
                        Gap(8.dp)
                        ThinProgressBar(item.fraction)
                    }
                }
            }
        }
    }
}

@Composable
fun UnitScreen(unitID: String) {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    data class Data(val unit: CurriculumUnit, val words: List<com.enesseval.kilitkelime.core.queries.WordItem>, val current: Boolean, val finished: Boolean)
    val data by loadData(unitID) { db ->
        val unit = CurriculumUnit.fetch(db, unitID) ?: return@loadData null
        val state = Curriculum.state(db)
        val progress = state?.units?.firstOrNull { it.id == unitID }
        Data(unit, Curriculum.cards(unitID, db).mapNotNull { WordQueries.item(it.id, db) }, state?.currentID == unitID, progress?.isFinished == true)
    }
    PushedScreen(data?.unit?.title ?: "") {
        val d = data ?: return@PushedScreen
        Text(d.unit.title, style = KelimeType.english(34.sp), color = c.ink)
        Text(d.unit.goal, style = KelimeType.ui(15.sp), color = c.ink2)
        Gap(14.dp)
        when {
            d.finished -> Text("Bu bölümü bitirdin", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.greenInk)
            d.current -> Text("Şu an bu bölümdesin, kartları widget'ında", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.accent)
            else -> PrimaryButton("Bu bölüme geç") {
                scope.launch {
                    app.model.writeAndRequeue("unit-current") { db -> Curriculum.makeCurrent(unitID, db) }
                    router.toast = "Kelimeler widget'ına geliyor"
                }
            }
        }
        if (d.unit.stories.isNotEmpty()) {
            Gap(20.dp)
            SettingsSection("HİKÂYELER") {
                d.unit.stories.forEachIndexed { i, story ->
                    if (i > 0) Divider()
                    Column(Modifier.fillMaxWidth().clickable { router.openStory(unitID, story.id) }.padding(horizontal = 16.dp, vertical = 12.dp)) {
                        Text(story.title, style = KelimeType.english(19.sp), color = c.ink)
                        Text("${story.lines.size} satır", style = KelimeType.ui(12.sp), color = c.ink2)
                    }
                }
            }
        }
        Gap(20.dp)
        SettingsSection("KELİMELER") {
            d.words.forEachIndexed { i, item ->
                if (i > 0) Divider()
                Row(
                    Modifier.fillMaxWidth().clickable { router.openWord(item.id) }.padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    StateDot(item.state)
                    Column(Modifier.weight(1f)) {
                        Text(item.card.word, style = KelimeType.english(19.sp), color = c.ink)
                        Text(item.card.meaning, style = KelimeType.ui(13.sp), color = c.ink2)
                    }
                }
            }
        }
    }
}

/** A unit story: English lines, tap to listen, Turkish on demand. */
@Composable
fun StoryScreen(unitID: String, storyID: String) {
    val c = Palette.current
    val context = LocalContext.current
    val speaker = remember { Speaker(context) }
    DisposableEffect(Unit) { onDispose { speaker.shutdown() } }
    var showTurkish by remember { mutableStateOf(false) }
    val story by loadData(unitID, storyID) { db -> CurriculumUnit.fetch(db, unitID)?.stories?.firstOrNull { it.id == storyID } }
    PushedScreen {
        val s = story ?: return@PushedScreen
        Text(s.title, style = KelimeType.english(32.sp), color = c.ink)
        s.titleTR?.let { Text(it, style = KelimeType.ui(15.sp), color = c.ink2) }
        Gap(8.dp)
        Kicker("Satıra dokun, dinle.".uppercase(com.enesseval.kilitkelime.ui.components.TR))
        Gap(12.dp)
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            for (line in s.lines) {
                Column(Modifier.fillMaxWidth().clickable { speaker.speak(line.en) }.semantics { contentDescription = "Dinlemek için dokun: ${line.en}" }) {
                    Text(line.en, style = KelimeType.english(20.sp), color = c.ink)
                    if (showTurkish) Text(line.tr, style = KelimeType.ui(14.sp), color = c.ink2)
                }
            }
        }
        Gap(20.dp)
        TintedButton(if (showTurkish) "Türkçesini gizle" else "Türkçesini göster", height = 50.dp) { showTurkish = !showTurkish }
    }
}
