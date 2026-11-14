package com.enesseval.kilitkelime.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Explore
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.compose.foundation.clickable
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.material3.ripple
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.learning.UserLists
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.core.widgets.WidgetLog
import com.enesseval.kilitkelime.ui.components.Toast
import com.enesseval.kilitkelime.ui.course.StoryScreen
import com.enesseval.kilitkelime.ui.course.UnitListScreen
import com.enesseval.kilitkelime.ui.course.UnitScreen
import com.enesseval.kilitkelime.ui.dev.WidgetLogScreen
import com.enesseval.kilitkelime.ui.discover.DiscoverScreen
import com.enesseval.kilitkelime.ui.discover.SharedListScreen
import com.enesseval.kilitkelime.ui.feedback.FeedbackScreen
import com.enesseval.kilitkelime.ui.games.MatchScreen
import com.enesseval.kilitkelime.ui.games.WordHuntScreen
import com.enesseval.kilitkelime.ui.lists.UserListScreen
import com.enesseval.kilitkelime.ui.paywall.PaywallScreen
import com.enesseval.kilitkelime.ui.play.PlayScreen
import com.enesseval.kilitkelime.ui.play.PuzzleArchiveScreen
import com.enesseval.kilitkelime.ui.profile.LockSetupScreen
import com.enesseval.kilitkelime.ui.profile.ProfileScreen
import com.enesseval.kilitkelime.ui.profile.RotationScreen
import com.enesseval.kilitkelime.ui.puzzle.CrosswordScreen
import com.enesseval.kilitkelime.ui.review.QuickReviewScreen
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.today.TodayScreen
import com.enesseval.kilitkelime.ui.word.WordDetailScreen
import com.enesseval.kilitkelime.ui.words.WordsScreen
import kotlinx.coroutines.launch
import java.time.Instant

enum class Tab(val route: String, val label: String) {
    TODAY("today", "Bugün"), PLAY("play", "Oyna"), WORDS("words", "Kelimelerim"), DISCOVER("discover", "Keşfet"), PROFILE("profile", "Profil")
}

/** Screens shown full screen, without the tab bar. */
private val fullScreen = listOf("review", "puzzle", "paywall", "wordhunt", "match", "sentence", "gapfill", "feedback", "weekly")

/** Full-screen rounds that can count a streak day; the reminder card waits until they close. */
private val rounds = listOf("review", "puzzle", "wordhunt", "match", "sentence", "gapfill")

/** Navigation for the whole app (port of AppRouter). */
class AppRouter(val nav: NavHostController, private val onPaywall: (PaywallTrigger) -> Unit = {}) {
    var toast by mutableStateOf<String?>(null)
    /** Kelimelerim opens on Listeler once (Bugün's "Widget'ında … Değiştir"). */
    var listsRequested by mutableStateOf(false)

    fun selectTab(tab: Tab) {
        nav.navigate(tab.route) {
            popUpTo(nav.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }

    fun openWord(id: String) {
        Analytics.send(Analytics.Event.wordDetail)
        nav.navigate("word/${Uri.encode(id)}")
    }

    fun openLists() {
        listsRequested = true
        selectTab(Tab.WORDS)
    }

    fun startQuickReview(deck: DeckID? = null) {
        Analytics.send(Analytics.Event.quickReview)
        nav.navigate("review?deck=${deck?.name ?: ""}")
    }

    fun openPuzzle(day: String? = null) {
        Analytics.send(Analytics.Event.puzzle)
        nav.navigate("puzzle?day=${day ?: ""}&personal=false")
    }

    fun openPersonalPuzzle() = nav.navigate("puzzle?day=&personal=true")
    fun openArchive() = nav.navigate("archive")
    fun openUnit(id: String) = nav.navigate("unit/${Uri.encode(id)}")
    fun openUnits() {
        Analytics.send(Analytics.Event.units)
        nav.navigate("units")
    }
    fun openStory(unit: String, story: String) = nav.navigate("story/${Uri.encode(unit)}/${Uri.encode(story)}")
    fun openList(id: String) = nav.navigate("list/${Uri.encode(id)}")
    fun openSharedList(id: String) = nav.navigate("shared/${Uri.encode(id)}")
    fun openFeedback(cardID: String? = null) = nav.navigate("feedback?card=${cardID?.let(Uri::encode) ?: ""}")
    fun openRotation() = nav.navigate("rotation")
    fun openLockSetup() = nav.navigate("locksetup")
    fun openWidgetLog() = nav.navigate("widgetlog")
    fun openWordHunt() = nav.navigate("wordhunt")
    fun openStreak() = nav.navigate("streak")
    fun openWeekly() {
        Analytics.signal(Analytics.Signal.WEEKLY_OPENED)
        nav.navigate("weekly")
    }
    fun openMatch() = nav.navigate("match")
    fun openSentence() = nav.navigate("sentence")
    fun openGapFill() = nav.navigate("gapfill")

    fun showPaywall(trigger: PaywallTrigger) {
        Analytics.send(Analytics.Event.paywallShown, com.enesseval.kilitkelime.core.model.PaywallSignals.shown(trigger))
        onPaywall(trigger)
        nav.navigate("paywall/${trigger.raw}")
    }

    fun back() {
        nav.popBackStack()
    }
}

val LocalRouter = staticCompositionLocalOf<AppRouter> { error("no router") }

/** The router where one may be absent (screens shared with onboarding). */
val LocalRouterOrNull = staticCompositionLocalOf<AppRouter?> { null }

@Composable
fun MainScaffold() {
    val app = LocalApp.current
    val activity = LocalActivity.current
    val nav = rememberNavController()
    val router = remember(nav) { AppRouter(nav) { trigger -> app.model.scope.launch { com.enesseval.kilitkelime.data.PaywallMomentStore.noteShown(app.model, trigger) } } }
    val c = Palette.current
    val entry by nav.currentBackStackEntryAsState()
    val route = entry?.destination?.route ?: ""
    val showBar = fullScreen.none { route.startsWith(it) }
    val roundOpen = rounds.any { route.startsWith(it) }
    var reminderAsk by remember { mutableStateOf(false) }

    val currentRoute by rememberUpdatedState(route)
    // Good moments only count while a round's screen is open (AppModel.studied checks this).
    SideEffect { app.model.roundOpen.value = roundOpen }

    // After a good moment, the reminder card (or else the Pro offer) opens 0.6 s after the round's
    // screen closes. One ask per round: the reminder first; Pro waits for a later good moment.
    // While another page is up (weekly summary, paywall) nothing shows and the ask waits for the
    // next round.
    LaunchedEffect(roundOpen) {
        if (roundOpen) return@LaunchedEffect
        fun blocked() = fullScreen.any { currentRoute.startsWith(it) }
        val reminder = app.model.reminderAskPending.value
        val offer = app.model.paywallMomentPending.value
        if (!reminder && !offer) return@LaunchedEffect
        kotlinx.coroutines.delay(600)
        if (blocked() || reminderAsk) return@LaunchedEffect
        app.model.reminderAskPending.value = false
        app.model.paywallMomentPending.value = false
        if (reminder) {
            if (com.enesseval.kilitkelime.notifications.ReminderAsk.permanentlyDenied(activity, app.model)) return@LaunchedEffect
            reminderAsk = true
        } else {
            if (app.model.isPro.value) return@LaunchedEffect
            router.showPaywall(PaywallTrigger.MOMENT)
            Analytics.signal(Analytics.Signal.PAYWALL_MOMENT)
        }
    }

    // The free trial ended: its one summary page opens once, when the app is up and no other full-screen page is open
    // (docs/V1_2_PLAN.md §2). Marked shown first, so it never comes twice.
    val summaryPending by app.model.trialSummaryPending.collectAsState()
    LaunchedEffect(summaryPending, route) {
        if (!summaryPending || route.isEmpty() || fullScreen.any { route.startsWith(it) }) return@LaunchedEffect
        kotlinx.coroutines.delay(600)
        app.model.trialSummaryPending.value = false
        val due = app.model.read { db ->
            val now = app.model.clock.now.toEpochMilli()
            (com.enesseval.kilitkelime.core.model.FreeTrial.summaryDue(db, now)).also { if (it) com.enesseval.kilitkelime.core.model.FreeTrial.markSummaryShown(db) }
        }
        if (due) router.showPaywall(PaywallTrigger.TRIAL_ENDED)
    }

    // Deep links: widgets, notification, tile, shared list links.
    val link by activity.links.collectAsState()
    LaunchedEffect(link) {
        val intent = link ?: return@LaunchedEffect
        activity.links.value = null
        handle(intent, router, app)
    }

    CompositionLocalProvider(LocalRouter provides router, LocalRouterOrNull provides router) {
        Box(Modifier.fillMaxSize().background(c.background)) {
            Column(Modifier.fillMaxSize()) {
                Box(Modifier.weight(1f)) {
                    NavHost(nav, startDestination = Tab.TODAY.route) {
                        composable(Tab.TODAY.route) { TodayScreen() }
                        composable(Tab.PLAY.route) { PlayScreen() }
                        composable(Tab.WORDS.route) { WordsScreen() }
                        composable(Tab.DISCOVER.route) { DiscoverScreen() }
                        composable(Tab.PROFILE.route) { ProfileScreen() }
                        composable("word/{id}") { WordDetailScreen(it.arguments?.getString("id") ?: "") }
                        composable("units") { UnitListScreen() }
                        composable("unit/{id}") { UnitScreen(it.arguments?.getString("id") ?: "") }
                        composable("story/{unit}/{story}") { StoryScreen(it.arguments?.getString("unit") ?: "", it.arguments?.getString("story") ?: "") }
                        composable("list/{id}") { UserListScreen(it.arguments?.getString("id") ?: "") }
                        composable("shared/{id}") { SharedListScreen(it.arguments?.getString("id") ?: "") }
                        composable("archive") { PuzzleArchiveScreen() }
                        composable("rotation") { RotationScreen() }
                        composable("locksetup") { LockSetupScreen() }
                        composable("widgetlog") { WidgetLogScreen() }
                        composable(
                            "review?deck={deck}",
                            arguments = listOf(navArgument("deck") { type = NavType.StringType; defaultValue = "" }),
                        ) { QuickReviewScreen(DeckID.entries.firstOrNull { d -> d.name == it.arguments?.getString("deck") }) }
                        composable(
                            "puzzle?day={day}&personal={personal}",
                            arguments = listOf(
                                navArgument("day") { type = NavType.StringType; defaultValue = "" },
                                navArgument("personal") { type = NavType.BoolType; defaultValue = false },
                            ),
                        ) { CrosswordScreen(it.arguments?.getString("day")?.takeIf { d -> d.isNotEmpty() }, it.arguments?.getBoolean("personal") ?: false) }
                        composable("paywall/{trigger}") { PaywallScreen(PaywallTrigger.entries.firstOrNull { t -> t.raw == it.arguments?.getString("trigger") } ?: PaywallTrigger.BASE) }
                        composable(
                            "feedback?card={card}",
                            arguments = listOf(navArgument("card") { type = NavType.StringType; defaultValue = "" }),
                        ) { FeedbackScreen(it.arguments?.getString("card")?.takeIf { id -> id.isNotEmpty() }) }
                        composable("wordhunt") { WordHuntScreen() }
                        composable("streak") { com.enesseval.kilitkelime.ui.today.StreakScreen() }
                        composable("weekly") { com.enesseval.kilitkelime.ui.today.WeeklyScreen() }
                        composable("match") { MatchScreen() }
                        composable("sentence") { com.enesseval.kilitkelime.ui.games.SentenceScreen() }
                        composable("gapfill") { com.enesseval.kilitkelime.ui.games.GapFillScreen() }
                    }
                }
                if (showBar) TabBar(route, router)
            }
            Toast(router.toast) { router.toast = null }
            if (reminderAsk) com.enesseval.kilitkelime.notifications.ReminderAskSheet { reminderAsk = false }
        }
    }
}

@Composable
private fun TabBar(route: String, router: AppRouter) {
    val c = Palette.current
    val app = LocalApp.current
    val account by app.account.state.collectAsState()
    val current = Tab.entries.firstOrNull { route == it.route } ?: when {
        route.startsWith("archive") -> Tab.PLAY
        route.startsWith("list") -> Tab.WORDS
        route.startsWith("shared") -> Tab.DISCOVER
        route.startsWith("rotation") || route.startsWith("locksetup") || route.startsWith("widgetlog") -> Tab.PROFILE
        else -> null
    }
    Column {
        Box(Modifier.fillMaxWidth().height(1.dp).background(c.line))
        // Custom items instead of NavigationBarItem: its pill indicator and wide elliptical ripple
        // don't fit the design; the press effect here is a circle behind the icon.
        Row(Modifier.fillMaxWidth().background(c.background).navigationBarsPadding().height(64.dp), verticalAlignment = Alignment.CenterVertically) {
            for (tab in Tab.entries) {
                val selected = tab == current
                val tint = if (selected) c.accent else c.ink2
                val interaction = remember { MutableInteractionSource() }
                Column(
                    Modifier.weight(1f).fillMaxHeight()
                        .clickable(interactionSource = interaction, indication = null, role = Role.Tab) { router.selectTab(tab) }
                        .semantics { this.selected = selected },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Box(
                        Modifier.size(40.dp).clip(CircleShape).indication(interaction, ripple(bounded = true, color = c.accent)),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (tab == Tab.PROFILE && account.profile != null) {
                            Avatar(account.profile?.avatar ?: "", account.profile?.name ?: "", 24)
                        } else {
                            Icon(
                                when (tab) {
                                    Tab.TODAY -> Icons.Outlined.WbSunny
                                    Tab.PLAY -> Icons.Outlined.GridView
                                    Tab.WORDS -> Icons.AutoMirrored.Outlined.MenuBook
                                    Tab.DISCOVER -> Icons.Outlined.Explore
                                    Tab.PROFILE -> Icons.Outlined.Person
                                },
                                contentDescription = null,
                                tint = tint,
                            )
                        }
                    }
                    Text(tab.label, style = KelimeType.ui(11.sp, FontWeight.Medium), color = tint, maxLines = 1)
                }
            }
        }
    }
}

/** Avatars chosen in Profil. iOS stores SF Symbol names; Android shows the same animal or thing as an emoji. */
val AVATARS: List<Pair<String, String>> = listOf(
    "letter" to "", "cat" to "🐱", "dog" to "🐶", "fox" to "🦊", "bird" to "🐦", "fish" to "🐟", "tortoise" to "🐢",
    "ladybug" to "🐞", "leaf" to "🍃", "flame" to "🔥", "bolt" to "⚡", "star" to "⭐", "moon" to "🌙", "sun" to "☀️",
    "globe" to "🌍", "book" to "📖",
)

/** The profile avatar: the chosen symbol, or the first letter of the name. */
@Composable
fun Avatar(avatar: String, name: String, size: Int) {
    val c = Palette.current
    val emoji = AVATARS.firstOrNull { it.first == avatar }?.second.orEmpty()
    Box(Modifier.size(size.dp).clip(CircleShape).background(c.accentSoft), contentAlignment = Alignment.Center) {
        Text(
            emoji.ifEmpty { name.trimStart('@').take(1).uppercase(com.enesseval.kilitkelime.ui.components.TR) },
            style = KelimeType.ui((size * 0.5).sp, FontWeight.SemiBold), color = c.accent,
        )
    }
}

/** kelime://word/<id>, kelime://puzzle, kelime://review, kelime://list/<uuid>, …/liste.html?id=, .kelimelist files. */
private suspend fun handle(intent: Intent, router: AppRouter, app: com.enesseval.kilitkelime.KilitKelimeApp) {
    val uri = intent.data ?: return
    when {
        uri.scheme == "content" -> {
            val text = runCatching { app.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } }.getOrNull() ?: return
            val shared = runCatching { com.enesseval.kilitkelime.core.learning.SharedList.decode(text) }.getOrNull()
            if (shared == null) {
                router.toast = "Bu dosya okunamadı"
                return
            }
            val list = app.model.write("import") { db -> UserLists.import(shared, db) }
            Analytics.send(Analytics.Event.listImported)
            router.toast = "\"${list.title}\" eklendi"
            router.openList(list.id)
        }
        uri.scheme == "https" && uri.path?.endsWith("liste.html") == true -> uri.getQueryParameter("id")?.let { router.openSharedList(it.lowercase()) }
        uri.scheme == "kelime" -> when (uri.host) {
            "word" -> {
                val id = uri.lastPathSegment ?: return
                if (id.isEmpty()) return
                uri.getQueryParameter("src")?.let { source ->
                    val slot = uri.getQueryParameter("slot")?.toLongOrNull()?.let(Instant::ofEpochSecond)
                    app.model.scope.launch { runCatching { app.model.read { db -> WidgetLog.recordTap(source, id, slot, db, app.model.clock) } } }
                }
                router.selectTab(Tab.TODAY)
                router.openWord(id)
            }
            "list" -> uri.lastPathSegment?.let { id ->
                if (runCatching { java.util.UUID.fromString(id) }.isSuccess) router.openSharedList(id.lowercase())
            }
            "puzzle" -> {
                router.selectTab(Tab.PLAY)
                router.openPuzzle()
            }
            "review" -> router.startQuickReview()
        }
    }
}
