package com.enesseval.kilitkelime.ui.words

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.UserListException
import com.enesseval.kilitkelime.core.learning.UserListSummary
import com.enesseval.kilitkelime.core.learning.UserLists
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.core.queries.DeckProgress
import com.enesseval.kilitkelime.core.queries.DeckQueries
import com.enesseval.kilitkelime.core.queries.WordFilter
import com.enesseval.kilitkelime.core.queries.WordItem
import com.enesseval.kilitkelime.core.queries.WordKind
import com.enesseval.kilitkelime.core.queries.WordQueries
import com.enesseval.kilitkelime.core.queries.WordSegment
import com.enesseval.kilitkelime.core.queries.WordSort
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.EmptyText
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.LevelChip
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.ScreenTitle
import com.enesseval.kilitkelime.ui.components.SegmentedPicker
import com.enesseval.kilitkelime.ui.components.StateDot
import com.enesseval.kilitkelime.ui.components.SurfaceCard
import com.enesseval.kilitkelime.ui.components.ThinProgressBar
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.launch

private enum class Mode(val label: String) { WORDS("Kelimeler"), LISTS("Listeler") }

@Composable
fun WordsScreen() {
    val router = LocalRouter.current
    val c = Palette.current
    var mode by rememberSaveable { mutableStateOf(Mode.LISTS) }
    LaunchedEffect(router.listsRequested) {
        if (router.listsRequested) {
            mode = Mode.LISTS
            router.listsRequested = false
        }
    }
    Column(Modifier.fillMaxSize().background(c.background).statusBarsPadding()) {
        Column(Modifier.padding(horizontal = 20.dp).padding(top = 6.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ScreenTitle("Kelimelerim")
            SegmentedPicker(Mode.entries, mode, { it.label }) { mode = it }
        }
        Gap(12.dp)
        when (mode) {
            Mode.WORDS -> WordsList()
            Mode.LISTS -> ListsView()
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Kelimeler

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun WordsList() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    var segment by rememberSaveable { mutableStateOf(WordSegment.STRUGGLING) }
    var search by rememberSaveable { mutableStateOf("") }
    var sort by remember { mutableStateOf(WordSort.ALPHABETICAL) }
    var filter by remember { mutableStateOf(WordFilter()) }
    var showFilter by remember { mutableStateOf(false) }
    var showSort by remember { mutableStateOf(false) }
    val items by loadData(segment, search, sort, filter) { db -> WordQueries.list(segment, db, search, filter, sort) }
    val listState = rememberLazyListState()

    Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (s in WordSegment.entries) {
                val selected = s == segment
                Text(
                    s.label, style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = if (selected) c.onAccent else c.ink,
                    modifier = Modifier.clip(CircleShape).background(if (selected) c.ink else c.surface2).clickable { segment = s }.padding(horizontal = 12.dp, vertical = 8.dp),
                )
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            SearchField(search, "Kelime ya da anlam ara", Modifier.weight(1f)) { search = it }
            Box {
                IconButton(onClick = { showSort = true }) { Icon(Icons.Default.SwapVert, contentDescription = "Sırala: ${sort.label}", tint = c.ink) }
                DropdownMenu(expanded = showSort, onDismissRequest = { showSort = false }) {
                    for (s in WordSort.entries) {
                        DropdownMenuItem(text = { Text((if (s == sort) "✓ " else "") + s.label) }, onClick = {
                            sort = s; showSort = false; Analytics.send(Analytics.Event.sort)
                        })
                    }
                }
            }
            IconButton(onClick = { showFilter = true }) {
                Icon(Icons.Default.FilterList, contentDescription = if (filter.isEmpty) "Filtrele" else "Filtrele, ${filter.count} filtre açık", tint = if (filter.isEmpty) c.ink else c.accent)
            }
        }
    }
    val list = items ?: return
    Box(Modifier.fillMaxSize()) {
        if (list.isEmpty()) {
            Box(Modifier.padding(horizontal = 20.dp)) { EmptyText(segment.emptyText) }
        } else {
            LazyColumn(state = listState, contentPadding = PaddingValues(start = 20.dp, end = 36.dp, bottom = 24.dp)) {
                items(list, key = { it.id }) { item ->
                    SwipeRow(
                        item,
                        onClick = { router.openWord(item.id) },
                        onKnown = { scope.launch { app.model.write("swipe-known") { db -> LearningStore.record(LearningEvent.MarkedKnown, item.id, ReviewSource.WORD_DETAIL, app.model.clock, db) } } },
                        onStruggling = { scope.launch { app.model.write("swipe-struggling") { db -> LearningStore.record(LearningEvent.MarkedStruggling, item.id, ReviewSource.WORD_DETAIL, app.model.clock, db) } } },
                    )
                }
            }
            if ((sort == WordSort.ALPHABETICAL || sort == WordSort.REVERSE_ALPHABETICAL) && list.size > 20) {
                IndexStrip(list, Modifier.align(Alignment.CenterEnd)) { index ->
                    scope.launch { listState.scrollToItem(index) }
                }
            }
        }
    }

    if (showFilter) {
        ModalBottomSheet(onDismissRequest = { showFilter = false }, containerColor = c.background) {
            Column(Modifier.padding(horizontal = 20.dp).navigationBarsPadding().padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Filtrele", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink, modifier = Modifier.weight(1f))
                    Text("Temizle", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.accent, modifier = Modifier.clickable { filter = WordFilter() }.padding(8.dp))
                }
                Kicker("SEVİYE")
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (level in CEFRLevel.entries) FilterChip(level.raw, level in filter.levels) {
                        filter = filter.copy(levels = filter.levels.toggle(level)); Analytics.send(Analytics.Event.filter)
                    }
                }
                Kicker("DURUM")
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (state in LearningState.entries) FilterChip(state.label, state in filter.states) { filter = filter.copy(states = filter.states.toggle(state)) }
                }
                Kicker("TÜR")
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (kind in WordKind.entries) FilterChip(kind.label, kind in filter.kinds) { filter = filter.copy(kinds = filter.kinds.toggle(kind)) }
                }
                PrimaryButton("Bitti") { showFilter = false }
            }
        }
    }
}

private fun <T> Set<T>.toggle(value: T): Set<T> = if (value in this) this - value else this + value

@Composable
private fun FilterChip(title: String, selected: Boolean, onClick: () -> Unit) {
    val c = Palette.current
    Text(
        title, style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = if (selected) c.onAccent else c.ink,
        modifier = Modifier.clip(CircleShape).background(if (selected) c.accent else c.surface2).clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 9.dp),
    )
}

@Composable
fun SearchField(value: String, placeholder: String, modifier: Modifier = Modifier, onChange: (String) -> Unit) {
    val c = Palette.current
    Row(
        modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).background(c.surface2).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.Search, null, tint = c.ink2, modifier = Modifier.padding(end = 8.dp))
        Box(Modifier.weight(1f)) {
            if (value.isEmpty()) Text(placeholder, style = KelimeType.ui(15.sp), color = c.ink2)
            BasicTextField(value, onChange, singleLine = true, textStyle = KelimeType.ui(15.sp).copy(color = c.ink), cursorBrush = SolidColor(c.accent), modifier = Modifier.fillMaxWidth())
        }
    }
}

/** A word row: swipe right for Biliyorum, left for Zorlanıyorum. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeRow(item: WordItem, onClick: () -> Unit, onKnown: () -> Unit, onStruggling: () -> Unit) {
    val c = Palette.current
    val state = rememberSwipeToDismissBoxState(confirmValueChange = { value ->
        when (value) {
            SwipeToDismissBoxValue.StartToEnd -> onKnown()
            SwipeToDismissBoxValue.EndToStart -> onStruggling()
            else -> {}
        }
        false // the row stays; its state dot changes
    })
    SwipeToDismissBox(
        state = state,
        backgroundContent = {
            val toKnown = state.dismissDirection == SwipeToDismissBoxValue.StartToEnd
            Box(
                Modifier.fillMaxSize().background(if (toKnown) c.greenBackground else c.amberBackground).padding(horizontal = 16.dp),
                contentAlignment = if (toKnown) Alignment.CenterStart else Alignment.CenterEnd,
            ) {
                Text(if (toKnown) "Biliyorum" else "Zorlanıyorum", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = if (toKnown) c.greenInk else c.amberInk)
            }
        },
    ) {
        Row(
            Modifier.fillMaxWidth().background(c.background).clickable(onClick = onClick).padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            StateDot(item.state)
            Column(Modifier.weight(1f)) {
                Text(item.card.word, style = KelimeType.english(20.sp), color = c.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(item.card.meaning, style = KelimeType.ui(14.sp), color = c.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            LevelChip(item.card.level)
        }
    }
}

/** A–Z (or Z–A) index strip: drag or tap a letter to jump. */
@Composable
private fun IndexStrip(items: List<WordItem>, modifier: Modifier, onJump: (Int) -> Unit) {
    val c = Palette.current
    val letters = remember(items) {
        items.mapIndexedNotNull { i, item -> item.card.word.firstOrNull()?.uppercaseChar()?.let { it to i } }
            .distinctBy { it.first }
    }
    var height by remember { mutableStateOf(1) }
    Column(
        modifier.width(24.dp).fillMaxHeight().padding(vertical = 8.dp)
            .onSizeChanged { height = maxOf(it.height, 1) }
            .pointerInput(letters) {
                detectVerticalDragGestures { change, _ ->
                    val index = ((change.position.y / height) * letters.size).toInt().coerceIn(0, letters.size - 1)
                    onJump(letters[index].second)
                }
            },
        verticalArrangement = Arrangement.SpaceEvenly,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        for ((letter, index) in letters) {
            Text(letter.toString(), style = KelimeType.ui(10.sp, FontWeight.SemiBold), color = c.accent, modifier = Modifier.clickable { onJump(index) })
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Listeler: the course, exam lists and own lists, each on or off for the lock screen.

private data class ListsData(
    val courseLevel: CEFRLevel?,
    val courseOn: Boolean,
    val courseProgress: Pair<Int, Int>?,
    val exams: List<DeckProgress>,
    val lists: List<UserListSummary>,
)

@Composable
private fun ListsView() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val pro by app.model.isPro.collectAsState()
    var creating by remember { mutableStateOf(false) }
    val data by loadData { db ->
        val course = Curriculum.state(db)
        ListsData(
            courseLevel = course?.level,
            courseOn = DeckQueries.courseEnabled(db),
            courseProgress = course?.let { s -> s.units.sumOf { it.learned } to s.units.sumOf { it.total } },
            exams = DeckQueries.progress(db).filter { it.deck.tag != null },
            lists = UserLists.summaries(db),
        )
    }
    val d = data ?: return
    val onCount = (if (d.courseOn) 1 else 0) + d.exams.count { it.enabled } + d.lists.count { it.list.enabled && it.total > 0 }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        d.courseLevel?.let { level ->
            SurfaceCard(onClick = { router.openUnits() }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("${level.raw} kursu", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                        d.courseProgress?.let { (learned, total) -> Text("$learned / $total kelime öğrenildi", style = KelimeType.ui(13.sp), color = c.ink2) }
                    }
                    WidgetSwitch(d.courseOn, enabled = !(d.courseOn && onCount == 1)) { on ->
                        scope.launch { app.model.writeAndRequeue("course-$on") { db -> DeckQueries.setCourse(on, db) } }
                    }
                }
                if (!d.courseOn) {
                    Gap(6.dp)
                    Text("Kurs widget'ta kapalı; widget açtığın listelerden kelime gösteriyor.", style = KelimeType.ui(13.sp), color = c.ink2)
                }
            }
        }
        Kicker("SINAV LİSTELERİ")
        for (deck in d.exams) {
            SurfaceCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(deck.deck.raw, style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                        Text("${deck.learned} / ${deck.total} kelime öğrenildi", style = KelimeType.ui(13.sp), color = c.ink2)
                    }
                    WidgetSwitch(deck.enabled, enabled = !(deck.enabled && onCount == 1)) { on ->
                        scope.launch { app.model.writeAndRequeue("deck-${deck.deck.raw}") { db -> DeckQueries.setEnabled(on, deck.deck, db) } }
                    }
                }
                Gap(10.dp)
                ThinProgressBar(deck.fraction)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { Kicker("KENDİ LİSTELERİM") }
            Icon(
                Icons.Default.Add, contentDescription = "Yeni liste", tint = c.accent,
                modifier = Modifier.clip(CircleShape).clickable {
                    scope.launch {
                        val can = app.model.read { db -> UserLists.canCreate(pro, db) }
                        if (can) creating = true else router.showPaywall(PaywallTrigger.LISTS)
                    }
                }.padding(6.dp),
            )
        }
        if (d.lists.isEmpty()) {
            SurfaceCard {
                Text("Kendi kelimelerini topla; widget'ta kursla birlikte dönsün.", style = KelimeType.ui(15.sp), color = c.ink2)
                Gap(12.dp)
                TintedButton("İlk listeni oluştur") { creating = true }
            }
        }
        for (summary in d.lists) {
            SurfaceCard(onClick = { router.openList(summary.id) }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(summary.list.title, style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                        Text("${summary.learned} / ${summary.total} kelime öğrenildi", style = KelimeType.ui(13.sp), color = c.ink2)
                    }
                    WidgetSwitch(summary.list.enabled, enabled = !(summary.list.enabled && onCount == 1 && summary.total > 0)) { on ->
                        scope.launch { app.model.writeAndRequeue("list-$on") { db -> UserLists.setEnabled(on, summary.id, db) } }
                    }
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2)
                }
                if (summary.total > 0) {
                    Gap(10.dp)
                    ThinProgressBar(summary.fraction)
                }
            }
        }
    }

    if (creating) {
        NewListDialog(onDismiss = { creating = false }) { title ->
            scope.launch {
                try {
                    val list = app.model.write("list-create") { db -> UserLists.create(title, pro, db) }
                    Analytics.send(Analytics.Event.listCreated)
                    creating = false
                    router.openList(list.id)
                } catch (e: UserListException) {
                    if (e.reason == UserListException.Reason.LIMIT_REACHED) {
                        creating = false
                        router.showPaywall(PaywallTrigger.LISTS)
                    }
                }
            }
        }
    }
}

@Composable
fun WidgetSwitch(checked: Boolean, enabled: Boolean = true, onChange: (Boolean) -> Unit) {
    val c = Palette.current
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Switch(
            checked, onChange, enabled = enabled,
            colors = SwitchDefaults.colors(checkedTrackColor = c.green, checkedThumbColor = Color.White, uncheckedTrackColor = c.surface2, uncheckedBorderColor = c.line),
        )
        Text("Widget'ta", style = KelimeType.ui(10.sp), color = c.ink2)
    }
}

@Composable
fun NewListDialog(onDismiss: () -> Unit, initial: String = "", title: String = "Yeni liste", confirm: String = "Oluştur", onSave: (String) -> Unit) {
    val c = Palette.current
    var text by remember { mutableStateOf(initial) }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = c.surface,
        title = { Text(title, style = KelimeType.ui(18.sp, FontWeight.SemiBold), color = c.ink) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Listenin adı", style = KelimeType.ui(13.sp), color = c.ink2)
                SearchFieldPlain(text, "Örn. İş toplantısı") { text = it.take(UserLists.MAX_TITLE) }
            }
        },
        confirmButton = { Text(confirm, style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = if (text.isBlank()) c.ink2 else c.accent, modifier = Modifier.clickable(enabled = text.isNotBlank()) { onSave(text) }.padding(12.dp)) },
        dismissButton = { Text("Vazgeç", style = KelimeType.ui(15.sp), color = c.ink2, modifier = Modifier.clickable(onClick = onDismiss).padding(12.dp)) },
    )
}

@Composable
fun SearchFieldPlain(value: String, placeholder: String, onChange: (String) -> Unit) {
    val c = Palette.current
    Box(Modifier.fillMaxWidth().heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).background(c.surface2).padding(horizontal = 12.dp), contentAlignment = Alignment.CenterStart) {
        if (value.isEmpty()) Text(placeholder, style = KelimeType.ui(15.sp), color = c.ink2)
        BasicTextField(value, onChange, singleLine = true, textStyle = KelimeType.ui(15.sp).copy(color = c.ink), cursorBrush = SolidColor(c.accent), modifier = Modifier.fillMaxWidth())
    }
}
