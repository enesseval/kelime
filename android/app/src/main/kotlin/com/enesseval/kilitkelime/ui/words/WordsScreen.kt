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
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.foundation.layout.size
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.combinedClickable
import androidx.compose.ui.draw.drawBehind
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.height
import com.enesseval.kilitkelime.ui.components.ProCorner
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
    val items by loadData(segment, search, sort, filter) { db -> WordQueries.list(segment, db, search, if (segment == WordSegment.ALL) filter else WordFilter(), sort) }
    val listState = rememberLazyListState()

    val stats by loadData { db -> com.enesseval.kilitkelime.core.queries.StatsQueries.week(db, app.model.clock) }

    // iOS listControls: the week line, search with sort (and filter on Tümü), then the segments
    // across the full width.
    Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        stats?.let { st ->
            Text(
                buildAnnotatedString {
                    append("Bu hafta ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = c.greenInk)) { append("${st.learnedThisWeek} öğrenildi") }
                    append(" · şu an ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = c.amberInk)) { append("${st.strugglingNow} zorlanılan") }
                },
                style = KelimeType.ui(13.sp), color = c.ink2,
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SearchField(search, "Kelime ya da anlam ara", Modifier.weight(1f)) { search = it }
            Box {
                ControlIcon(Icons.Default.SwapVert, "Sırala: ${sort.label}") { showSort = true }
                DropdownMenu(expanded = showSort, onDismissRequest = { showSort = false }) {
                    for (s in WordSort.entries) {
                        DropdownMenuItem(text = { Text((if (s == sort) "✓ " else "") + s.label) }, onClick = {
                            sort = s; showSort = false; Analytics.send(Analytics.Event.sort)
                        })
                    }
                }
            }
            if (segment == WordSegment.ALL) {
                ControlIcon(
                    Icons.Default.FilterList, if (filter.isEmpty) "Filtrele" else "Filtrele, ${filter.count} filtre açık", active = !filter.isEmpty,
                ) { showFilter = true }
            }
        }
        SegmentedPicker(WordSegment.entries, segment, { it.label }, Modifier.fillMaxWidth()) { segment = it }
    }
    Gap(8.dp)
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

/** A 44 dp square control next to the search field (iOS controlIcon). */
@Composable
private fun ControlIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, description: String, active: Boolean = false, onClick: () -> Unit) {
    val c = Palette.current
    Box(
        Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(if (active) c.accent else c.surface2).clickable(onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = if (active) c.onAccent else c.ink, modifier = Modifier.size(20.dp)) }
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
    val course: com.enesseval.kilitkelime.core.content.CourseState?,
    val courseOn: Boolean,
    val decks: List<DeckProgress>,
    val lists: List<UserListSummary>,
)

/**
 * Listeler (iOS WordsView.lists): KENDİ LİSTELERİM first, then KURS (the course card, a note and
 * the units) and SINAV LİSTELERİ in two columns. The last source that is on can't be switched off.
 */
@Composable
private fun ListsView() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val pro by app.model.isPro.collectAsState()
    var creating by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<UserListSummary?>(null) }
    val data by loadData { db ->
        ListsData(Curriculum.state(db), DeckQueries.courseEnabled(db), DeckQueries.progress(db), UserLists.summaries(db))
    }
    val d = data ?: return
    val examsOn = d.decks.count { it.deck.tag != null && it.enabled }
    val listsOn = d.lists.count { it.list.enabled && it.total > 0 }
    val onCount = if (d.course != null) (if (d.courseOn) 1 else 0) + examsOn + listsOn else d.decks.count { it.enabled } + listsOn
    fun setDeck(deck: DeckProgress, on: Boolean) {
        scope.launch { app.model.writeAndRequeue("deck-${deck.deck.raw}") { db -> DeckQueries.setEnabled(on, deck.deck, db) } }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        val course = d.course
        if (course != null) {
            Caption("KENDİ LİSTELERİM")
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                for (summary in d.lists) {
                    UserListCard(
                        summary, keepOn = summary.list.enabled && summary.total > 0 && onCount == 1,
                        onOpen = { router.openList(summary.id) }, onDelete = { deleting = summary },
                    ) { on -> scope.launch { app.model.writeAndRequeue("list-$on") { db -> UserLists.setEnabled(on, summary.id, db) } } }
                }
                val ownCount = d.lists.count { !it.list.imported }
                ProCorner(!pro && ownCount > 0) {
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(18.dp))
                            .drawBehind {
                                drawRoundRect(
                                    c.line, cornerRadius = androidx.compose.ui.geometry.CornerRadius(18.dp.toPx()),
                                    style = androidx.compose.ui.graphics.drawscope.Stroke(1.dp.toPx(), pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx()))),
                                )
                            }
                            .clickable {
                                scope.launch {
                                    val can = app.model.read { db -> UserLists.canCreate(pro, db) }
                                    if (can) creating = true else router.showPaywall(PaywallTrigger.LISTS)
                                }
                            }.padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(Icons.Default.Add, null, tint = c.accent, modifier = Modifier.size(18.dp))
                        Text(if (d.lists.isEmpty()) "İlk listeni oluştur" else "Yeni liste", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.accent)
                    }
                }
                if (d.lists.isEmpty()) Text("Kendi kelimelerini topla; widget'ta kursla birlikte dönsün.", style = KelimeType.ui(13.sp), color = c.ink2)
            }
            Caption("KURS")
            d.decks.firstOrNull { it.deck.level == course.level }?.let { deck ->
                DeckCard(deck.copy(enabled = d.courseOn), "${course.level.raw} kursu", keepOn = d.courseOn && onCount == 1) { on ->
                    scope.launch { app.model.writeAndRequeue("course-$on") { db -> DeckQueries.setCourse(on, db) } }
                }
            }
            Text(
                if (d.courseOn) "Kapatırsan widget'ta sadece açtığın sınav listeleri ve kendi listelerin döner." else "Kurs widget'ta kapalı; widget açtığın listelerden kelime gösteriyor.",
                style = KelimeType.ui(12.sp), color = c.ink2,
            )
            com.enesseval.kilitkelime.ui.course.UnitList(course)
            val exams = d.decks.filter { it.deck.tag != null }
            if (exams.isNotEmpty()) {
                Caption("SINAV LİSTELERİ")
                DecksGrid(exams, keepOn = { it.enabled && onCount == 1 }, onToggle = ::setDeck)
            }
        } else {
            DecksGrid(d.decks, keepOn = { it.enabled && onCount == 1 }, onToggle = ::setDeck)
        }
    }

    deleting?.let { summary ->
        val last = summary.list.enabled && summary.total > 0 && onCount == 1
        com.enesseval.kilitkelime.ui.profile.ConfirmDialog(
            "Liste silinsin mi?",
            if (last) "Widget'ta açık tek liste bu; silersen widget'ta kurs yeniden açılır." else "Kendi yazdığın kelimeler de silinir. Uygulamanın kelimeleri ve ilerlemen yerinde kalır.",
            "${summary.list.title} listesini sil", onDismiss = { deleting = null },
        ) {
            deleting = null
            scope.launch {
                app.model.writeAndRequeue("list-delete") { db ->
                    UserLists.delete(summary.id, db)
                    // The widget needs a source: the course comes back.
                    if (last) DeckQueries.setCourse(true, db)
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
private fun Caption(text: String) {
    Text(text, style = KelimeType.ui(12.sp, FontWeight.SemiBold).copy(letterSpacing = 0.7.sp), color = Palette.current.ink2)
}

/** iOS UserListCard: title and chevron, count, progress, "Widget'ta" switch. Long press deletes. */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun UserListCard(summary: UserListSummary, keepOn: Boolean, onOpen: () -> Unit, onDelete: () -> Unit, onToggle: (Boolean) -> Unit) {
    val c = Palette.current
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.surface).border(1.dp, c.line, RoundedCornerShape(18.dp))
            .combinedClickable(onClick = onOpen, onLongClick = onDelete, onLongClickLabel = "Listeyi sil").padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(summary.list.title, style = KelimeType.english(22.sp), color = c.ink, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2)
        }
        Text(if (summary.total == 0) "Henüz kelime yok" else "${summary.learned} / ${summary.total} kelime öğrenildi", style = KelimeType.ui(12.sp), color = c.ink2)
        ThinProgressBar(summary.fraction)
        WidgetToggleRow(summary.list.enabled, enabled = summary.total > 0 && !keepOn, onToggle)
    }
}

/** iOS DeckCard: serif title, count (or "Bu listeyi bitirdin 🎉"), progress, "Widget'ta" switch. */
@Composable
private fun DeckCard(deck: DeckProgress, title: String? = null, keepOn: Boolean, modifier: Modifier = Modifier, onToggle: (Boolean) -> Unit) {
    val c = Palette.current
    Column(
        modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.surface).border(1.dp, c.line, RoundedCornerShape(18.dp)).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(title ?: deck.deck.raw, style = KelimeType.english(24.sp), color = c.ink)
        Text(
            when {
                deck.isFinished -> "Bu listeyi bitirdin 🎉"
                deck.total == 0 -> "Yakında"
                else -> "${deck.learned} / ${deck.total} kelime öğrenildi"
            },
            style = KelimeType.ui(12.sp), color = c.ink2, maxLines = 2,
        )
        ThinProgressBar(deck.fraction)
        WidgetToggleRow(deck.enabled, enabled = deck.total > 0 && !keepOn, onToggle)
    }
}

@Composable
private fun DecksGrid(decks: List<DeckProgress>, keepOn: (DeckProgress) -> Boolean, onToggle: (DeckProgress, Boolean) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (pair in decks.chunked(2)) {
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                for (deck in pair) DeckCard(deck, keepOn = keepOn(deck), modifier = Modifier.weight(1f).fillMaxHeight()) { on -> onToggle(deck, on) }
                if (pair.size == 1) Box(Modifier.weight(1f))
            }
        }
    }
}

/** "Widget'ta" with a switch on the right (iOS Toggle). */
@Composable
private fun WidgetToggleRow(checked: Boolean, enabled: Boolean, onChange: (Boolean) -> Unit) {
    val c = Palette.current
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("Widget'ta", style = KelimeType.ui(12.sp), color = c.ink2, modifier = Modifier.weight(1f))
        Switch(
            checked, onChange, enabled = enabled,
            colors = SwitchDefaults.colors(checkedTrackColor = c.green, checkedThumbColor = Color.White, uncheckedTrackColor = c.surface2, uncheckedBorderColor = c.line),
        )
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
