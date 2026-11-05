package com.enesseval.kilitkelime.ui.profile

import android.Manifest
import android.app.TimePickerDialog
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.BuildConfig
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.learning.ProgressReset
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.ExamCountdown
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.model.WidgetContent
import com.enesseval.kilitkelime.core.model.WidgetMode
import com.enesseval.kilitkelime.notifications.Reminder
import com.enesseval.kilitkelime.ui.AVATARS
import com.enesseval.kilitkelime.ui.Avatar
import com.enesseval.kilitkelime.ui.LocalActivity
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.ScreenTitle
import com.enesseval.kilitkelime.ui.components.SettingsRow
import com.enesseval.kilitkelime.ui.components.SettingsSection
import com.enesseval.kilitkelime.ui.components.SettingsToggle
import com.enesseval.kilitkelime.ui.components.SurfaceCard
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.components.TurkishDate
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.words.SearchFieldPlain
import android.app.DatePickerDialog
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.PanTool
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.layout.heightIn
import com.enesseval.kilitkelime.data.DevTools
import com.enesseval.kilitkelime.notifications.ReminderAsk
import com.enesseval.kilitkelime.ui.word.Speaker
import kotlinx.coroutines.launch
import java.time.LocalDate

const val TERMS_URL = "https://enesseval.github.io/kelime/kosullar.html"
const val PRIVACY_URL = "https://enesseval.github.io/kelime/gizlilik.html"

private data class SettingsData(
    val prefs: Preferences,
    val levels: List<CEFRLevel>,
    val exam: Pair<DeckID, LocalDate>?,
    val reminder: Int?,
    val speechRate: Float,
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ProfileScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val activity = LocalActivity.current
    val context = LocalContext.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val pro by app.model.isPro.collectAsState()
    val account by app.account.state.collectAsState()
    val lock by app.model.prefs.flow.collectAsState(initial = null)
    val data by loadData { db ->
        SettingsData(
            Preferences.load(db), Curriculum.levels(db), ExamCountdown.load(db), Settings.int(db, SettingKey.REMINDER_TIME),
            Settings.string(db, SettingKey.SPEECH_RATE)?.toFloatOrNull() ?: 0.9f,
        )
    }
    var picker by remember { mutableStateOf<String?>(null) }
    var confirm by remember { mutableStateOf<String?>(null) }
    var editing by remember { mutableStateOf(false) }
    val speaker = remember { Speaker(context) }
    DisposableEffect(Unit) { onDispose { speaker.shutdown() } }
    var pendingReminder by remember { mutableStateOf<Int?>(null) }
    var forcePro by remember { mutableStateOf(DevTools.forcePro) }

    fun open(url: String) = context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))

    suspend fun setReminder(minutes: Int) {
        app.model.write("reminder") { db -> Settings.setInt(db, SettingKey.REMINDER_TIME, minutes) }
        Reminder.schedule(context, minutes)
    }

    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val minutes = pendingReminder
        pendingReminder = null
        if (granted && minutes != null) scope.launch { setReminder(minutes) }
        else if (!granted) router.toast = "Bildirim izni Ayarlar'dan açılabilir"
    }

    Column(
        Modifier.fillMaxSize().background(c.background).statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp).padding(top = 6.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        ScreenTitle("Profil")
        val d = data ?: return@Column

        // Same sections and order as iOS SettingsView: Hesap, Pro, Seviye ve sınav, Widget,
        // Hatırlatma ve telaffuz, Baştan başla, Uygulama, Geliştirici (debug only), about.
        SettingsSection("HESAP") {
            val profile = account.profile
            if (account.isSignedIn && profile != null) {
                Row(
                    Modifier.fillMaxWidth().clickable { editing = true }.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Avatar(profile.avatar, profile.name, 52)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(profile.name, style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                        Text(
                            profile.username?.let { "@$it" } ?: "Kullanıcı adı seç",
                            style = KelimeType.ui(13.sp), color = if (profile.username == null) c.accent else c.ink2,
                        )
                    }
                    Text("Düzenle ›", style = KelimeType.ui(14.sp), color = c.ink2)
                }
                Divider()
                SettingsRow("Listelerim") {
                    Text(
                        when {
                            account.syncing -> "Eşitleniyor…"
                            account.error != null -> "Tekrar dene"
                            account.lastSync != null -> "Eşitlendi · " + TurkishDate.header(LocalDate.now())
                            else -> "Eşitle"
                        },
                        style = KelimeType.ui(14.sp), color = if (account.error == null) c.ink2 else c.amberInk,
                        modifier = Modifier.clickable(enabled = !account.syncing) { scope.launch { app.account.sync() } }.padding(vertical = 8.dp),
                    )
                }
                Divider()
                RowText("Çıkış yap", c.ink) { confirm = "signout" }
                Divider()
                RowText("Hesabı sil", c.amberInk) { confirm = "delete" }
            } else if (account.isSignedIn) {
                SettingsRow("Hesap yükleniyor")
            } else {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Hesabını bağla", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                    Text(
                        "Listelerin yedeklenir ve cihazlarında eşitlenir. Listelerini linkle paylaşabilir ya da Keşfet'te herkese açabilirsin. Pro'n da hesabına bağlanır.",
                        style = KelimeType.ui(13.sp), color = c.ink2,
                    )
                    PrimaryButton("Google ile devam et", height = 48.dp) { scope.launch { app.account.signInWithGoogle(activity) } }
                    account.error?.let { Text(it, style = KelimeType.ui(12.sp), color = c.amberInk) }
                }
            }
        }

        // Pro: an entry that is always there (store review must find the purchases), or the membership.
        if (pro) {
            SettingsSection("ÜYELİK") {
                SettingsRow("Kilit Kelime Pro") {
                    Icon(Icons.Filled.Verified, null, tint = c.greenInk, modifier = Modifier.size(18.dp))
                    Text(" " + (if (DevTools.forcePro) "Pro (geliştirici)" else "Pro"), style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.greenInk)
                }
                Divider()
                LinkRow("Aboneliği yönet", Icons.Outlined.CreditCard) { open("https://play.google.com/store/account/subscriptions") }
            }
        } else {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(c.accentSoft)
                    .clickable { router.showPaywall(PaywallTrigger.BASE) }.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(c.accent), contentAlignment = Alignment.Center) {
                    Text("✦", style = KelimeType.ui(20.sp, FontWeight.SemiBold), color = c.onAccent)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text("Kilit Kelime Pro", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                    Text("Sınırsız liste, sınav planı, sana özel bulmaca ve daha fazlası", style = KelimeType.ui(13.sp), color = c.ink2)
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2.copy(alpha = 0.6f))
            }
        }

        SettingsSection("SEVİYE VE SINAV") {
            SettingsRow("Seviye", d.prefs.level.raw, onClick = { picker = "level" })
            Divider()
            SettingsToggle("Sınav geri sayımı", d.exam != null) { on ->
                if (on) Analytics.send(Analytics.Event.examCountdown)
                scope.launch {
                    app.model.write("exam") { db ->
                        if (on) ExamCountdown.set(DeckID.YDS, LocalDate.now().plusMonths(2), db) else ExamCountdown.clear(db)
                    }
                }
            }
            d.exam?.let { (exam, date) ->
                Divider()
                SettingsRow("Sınav", exam.raw, onClick = { picker = "exam" })
                Divider()
                SettingsRow("Sınav tarihi", TurkishDate.long(date), onClick = {
                    DatePickerDialog(context, { _, y, m, day ->
                        scope.launch { app.model.write("exam") { db -> ExamCountdown.set(exam, LocalDate.of(y, m + 1, day), db) } }
                    }, date.year, date.monthValue - 1, date.dayOfMonth).apply { datePicker.minDate = System.currentTimeMillis() }.show()
                })
            }
        }

        // iOS: Değişim sıklığı, Kilit ekranı görünümü, Gösterilecekler, Widget nasıl eklenir?
        // Android adds the lock-screen word (wallpaper / notification), its widget equivalent.
        SettingsSection("WIDGET") {
            SettingsRow("Değişim sıklığı", rotationTitle(d.prefs.effectiveRotation), onClick = router::openRotation)
            Divider()
            SettingsRow("Kilit ekranı görünümü", d.prefs.defaultWidgetMode.label, onClick = { picker = "mode" })
            Divider()
            SettingsRow("Gösterilecekler", d.prefs.widgetContent.label, onClick = { picker = "content" })
            Divider()
            SettingsRow(
                "Kilit ekranı kelimesi",
                when {
                    lock?.wallpaperEnabled == true && lock?.notificationEnabled == true -> "Duvar kâğıdı · bildirim"
                    lock?.wallpaperEnabled == true -> "Duvar kâğıdı"
                    lock?.notificationEnabled == true -> "Bildirim"
                    else -> "Kapalı"
                },
                onClick = router::openLockSetup,
            )
            Divider()
            RowText("Widget nasıl eklenir?", c.accent, onClick = router::openLockSetup)
        }

        SettingsSection("HATIRLATMA VE TELAFFUZ") {
            SettingsToggle("Günlük hatırlatma", d.reminder != null) { on ->
                if (!on) {
                    scope.launch {
                        app.model.write("reminder") { db -> Settings.setInt(db, SettingKey.REMINDER_TIME, null) }
                        Reminder.schedule(context, null)
                    }
                } else if (Build.VERSION.SDK_INT >= 33 && !notificationsAllowed(context)) {
                    pendingReminder = d.reminder ?: ReminderAsk.DEFAULT_MINUTES
                    scope.launch { app.model.prefs.update { it.copy(notificationsRequested = true) } }
                    notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    scope.launch { setReminder(d.reminder ?: ReminderAsk.DEFAULT_MINUTES) }
                }
            }
            d.reminder?.let { minutes ->
                Divider()
                SettingsRow("Saat", Reminder.label(minutes), onClick = {
                    TimePickerDialog(context, { _, h, m -> scope.launch { setReminder(h * 60 + m) } }, minutes / 60, minutes % 60, true).show()
                })
            }
            Divider()
            SettingsRow("Ses ve hız", "en-US · %.1f×".format(d.speechRate), onClick = { picker = "speech" })
        }

        SettingsSection("BAŞTAN BAŞLA") {
            RowText("İlerlemeyi sıfırla", c.amberInk) { confirm = "reset" }
        }

        SettingsSection("UYGULAMA") {
            AppIconRow()
            Divider()
            LinkRow("Öneri gönder", Icons.Outlined.ChatBubbleOutline) { router.openFeedback() }
            Divider()
            LinkRow("Gizlilik politikası", Icons.Outlined.PanTool) { open(PRIVACY_URL) }
            Divider()
            LinkRow("Kullanım koşulları", Icons.Outlined.Description) { open(TERMS_URL) }
            Divider()
            LinkRow("Satın alımları geri yükle", Icons.Outlined.Refresh) {
                scope.launch {
                    router.toast = if (app.purchases.restore()) "Pro geri yüklendi" else (app.purchases.state.value.error ?: "Geri yüklenecek satın alma bulunamadı")
                }
            }
        }

        if (DevTools.isAvailable) {
            val diagnostics by app.purchases.diagnostics.collectAsState()
            SettingsSection("GELİŞTİRİCİ") {
                SettingsToggle("Pro'yu aç (satın almadan)", forcePro) { on ->
                    DevTools.forcePro = on
                    forcePro = on
                    scope.launch {
                        app.purchases.refreshEntitlement()
                        router.toast = if (on) "Tüm Pro özellikleri açık" else "Ücretsiz sürüm gibi davranıyor"
                    }
                }
                Divider()
                RowText("Örnek listeler oluştur", c.accent) { scope.launch { router.toast = createSampleLists(app) } }
                Divider()
                Column(
                    Modifier.fillMaxWidth().clickable { scope.launch { app.purchases.refreshEntitlement() } }.padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Text("RevenueCat durumu · yenile", style = KelimeType.ui(15.sp), color = c.ink)
                    Text(diagnostics, style = KelimeType.ui(12.sp), color = c.ink2)
                }
                Divider()
                SettingsRow("Widget günlüğü ve ölçüm modu", onClick = router::openWidgetLog)
                Divider()
                RowText("Bugünün bulmacalarını sıfırla", c.accent) {
                    scope.launch {
                        app.model.write("dev-puzzles") { db ->
                            db.execute("DELETE FROM puzzle_progress WHERE puzzle_key LIKE ?", listOf("%-${app.model.clock.today}%"))
                            Settings.set(db, SettingKey.DAILY_PUZZLE_SUMMARY, null)
                        }
                        router.toast = "Bulmacalar sıfırlandı"
                    }
                }
                Divider()
                RowText("Tanıtımı yeniden göster", c.accent) {
                    scope.launch { app.model.write("dev-onboarding") { db -> Settings.setBool(db, SettingKey.ONBOARDING_DONE, false) } }
                }
            }
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth().padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Kilit Kelime v${BuildConfig.VERSION_NAME}", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2)
            Text("Kelime listesi: New General Service List, CC BY-SA 4.0", style = KelimeType.ui(12.sp), color = c.ink2, textAlign = TextAlign.Center)
            Text("İçerik yapay zekâ ile üretildi ve kontrol edildi", style = KelimeType.ui(12.sp), color = c.ink2, textAlign = TextAlign.Center)
        }
    }

    // Pickers.
    val d = data
    if (picker != null && d != null) {
        ModalBottomSheet(onDismissRequest = { picker = null }, containerColor = c.background) {
            Column(Modifier.padding(horizontal = 20.dp).navigationBarsPadding().padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                when (picker) {
                    "mode" -> Choice("Kilit ekranı görünümü", WidgetMode.entries, d.prefs.defaultWidgetMode, { it.label }, { it.detail }) { mode ->
                        picker = null
                        scope.launch {
                            app.model.write("mode") { db -> Preferences.load(db).copy(defaultWidgetMode = mode).save(db) }
                            app.lockScreen.redrawWallpaper()
                        }
                    }
                    "content" -> Choice("Gösterilecekler", WidgetContent.entries, d.prefs.widgetContent, { it.label }, { null }) { content ->
                        picker = null
                        scope.launch { app.model.writeAndRequeue("content") { db -> Preferences.load(db).copy(widgetContent = content).save(db) } }
                    }
                    "level" -> Choice("Seviye", CEFRLevel.entries.toList(), d.prefs.level, { if (it in d.levels) it.raw else "${it.raw} · yakında" }, { null }) { level ->
                        if (level !in d.levels) return@Choice
                        picker = null
                        scope.launch { app.model.writeAndRequeue("level", keepCurrent = false) { db -> Curriculum.switchLevel(level, db) } }
                    }
                    "exam" -> Choice("Sınav", ExamCountdown.exams, d.exam?.first ?: DeckID.YDS, { it.raw }, { null }) { exam ->
                        picker = null
                        val date = d.exam?.second ?: LocalDate.now().plusMonths(2)
                        scope.launch { app.model.write("exam") { db -> ExamCountdown.set(exam, date, db) } }
                    }
                    "speech" -> Choice("Ses ve hız", listOf(0.8f, 0.9f, 1.0f), d.speechRate, { "%.1f×".format(it) }, { null }) { rate ->
                        picker = null
                        speaker.rate = rate
                        speaker.speak("reluctant")
                        scope.launch { app.model.write("speech") { db -> Settings.set(db, SettingKey.SPEECH_RATE, rate.toString()) } }
                    }
                }
            }
        }
    }

    if (editing) {
        ModalBottomSheet(onDismissRequest = { editing = false }, containerColor = c.background) {
            var name by remember { mutableStateOf(account.profile?.displayName ?: "") }
            var username by remember { mutableStateOf(account.profile?.username ?: "") }
            var avatar by remember { mutableStateOf(account.profile?.avatar ?: "letter") }
            var error by remember { mutableStateOf<String?>(null) }
            Column(Modifier.padding(horizontal = 20.dp).navigationBarsPadding().padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Profil", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                Text("Herkese açık listelerinin yanında adın ve avatarın görünür.", style = KelimeType.ui(13.sp), color = c.ink2)
                SearchFieldPlain(name, "Adın") { name = it.take(40) }
                SearchFieldPlain(username, "kullanici_adi") { username = it.take(20) }
                Text("Avatar", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    for ((key, _) in AVATARS) {
                        Column(Modifier.clickable { avatar = key }.background(if (avatar == key) c.accentSoft else c.background).padding(4.dp)) {
                            Avatar(key, name.ifEmpty { username }, 40)
                        }
                    }
                }
                error?.let { Text(it, style = KelimeType.ui(13.sp), color = c.amberInk) }
                PrimaryButton("Kaydet") {
                    scope.launch {
                        error = app.account.updateProfile(name, username.ifBlank { null }, avatar)
                        if (error == null) editing = false
                    }
                }
            }
        }
    }

    when (confirm) {
        "reset" -> ConfirmDialog(
            "İlerlemen sıfırlansın mı?",
            "Öğrendiğin ve zorlandığın kelimeler, bölümler, bulmacalar ve seçimlerin silinir; seviyeni yeniden seçersin.",
            "Sıfırla ve baştan başla", onDismiss = { confirm = null },
        ) {
            confirm = null
            scope.launch { app.model.writeAndRequeue("reset", keepCurrent = false) { db -> ProgressReset.reset(db) } }
        }
        "signout" -> ConfirmDialog("Çıkış yapılsın mı?", "Listelerin bu cihazda kalır; paylaşımları kapanır.", "Çıkış yap", onDismiss = { confirm = null }) {
            confirm = null
            scope.launch { app.account.signOut() }
        }
        "delete" -> ConfirmDialog(
            "Hesabın silinsin mi?",
            "Hesabın, profilin ve sunucudaki listelerin silinir. Bu cihazdaki listeler ve ilerlemen kalır. Pro aboneliğini iptal etmek için Google Play › Ödemeler ve abonelikler'i kullan.",
            "Hesabı kalıcı olarak sil", onDismiss = { confirm = null },
        ) {
            confirm = null
            scope.launch { app.account.deleteAccount() }
        }
    }
}

@Composable
fun ConfirmDialog(title: String, text: String, action: String, onDismiss: () -> Unit, onConfirm: () -> Unit) {
    val c = Palette.current
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = c.surface,
        title = { Text(title) },
        text = { Text(text) },
        confirmButton = { Text(action, color = c.amberInk, style = KelimeType.ui(15.sp, FontWeight.SemiBold), modifier = Modifier.clickable(onClick = onConfirm).padding(12.dp)) },
        dismissButton = { Text("Vazgeç", color = c.ink2, modifier = Modifier.clickable(onClick = onDismiss).padding(12.dp)) },
    )
}

@Composable
private fun <T> Choice(title: String, options: List<T>, selected: T, label: (T) -> String, detail: (T) -> String?, onPick: (T) -> Unit) {
    val c = Palette.current
    Text(title, style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
    SettingsSection("") {
        options.forEachIndexed { i, option ->
            if (i > 0) Divider()
            SettingsRow(label(option), detail(option), onClick = { onPick(option) }) {
                if (option == selected) Text("✓", style = KelimeType.ui(16.sp, FontWeight.Bold), color = c.accent)
            }
        }
    }
}

/** A full-width text row (iOS rowText / devButton). */
@Composable
private fun RowText(title: String, color: androidx.compose.ui.graphics.Color, onClick: () -> Unit) {
    Text(
        title, style = KelimeType.ui(15.sp), color = color,
        modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp).clickable(onClick = onClick).padding(horizontal = 16.dp).wrapContentHeight(Alignment.CenterVertically),
    )
}

/** Icon, title and a chevron (iOS linkRow). */
@Composable
private fun LinkRow(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    val c = Palette.current
    Row(
        Modifier.fillMaxWidth().heightIn(min = 50.dp).clickable(onClick = onClick).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, tint = c.ink2, modifier = Modifier.size(20.dp))
        Text(title, style = KelimeType.ui(15.sp), color = c.ink, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2.copy(alpha = 0.6f))
    }
}

private fun notificationsAllowed(context: android.content.Context) =
    androidx.core.content.ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED

/** Profil › Geliştirici › Örnek listeler oluştur (port of AppModel.createSampleLists). */
private suspend fun createSampleLists(app: com.enesseval.kilitkelime.KilitKelimeApp): String {
    val samples = listOf(
        "Örnek · Seyahat" to listOf("a1-airport", "a2-passport", "a1-ticket", "a2-luggage", "a1-hotel", "a2-journey", "a2-flight", "a2-delay"),
        "Örnek · İş" to listOf("a2-meeting", "a2-deadline", "a2-colleague", "b1-budget", "b1-contract", "b1-decision"),
        "Örnek · Duygular" to listOf("b2-anxious", "b2-grateful", "b1-jealous", "b1-proud", "b1-lonely", "b1-nervous", "b1-curious"),
    )
    return runCatching {
        app.model.write("sample-lists") { db ->
            for ((title, ids) in samples) {
                val list = com.enesseval.kilitkelime.core.learning.UserLists.create(title, isPro = true, db = db)
                for (id in ids) runCatching { com.enesseval.kilitkelime.core.learning.UserLists.add(id, list.id, db) }
                if (title.endsWith("Seyahat")) {
                    com.enesseval.kilitkelime.core.learning.UserLists.addCustom(
                        "boarding pass", "biniş kartı", com.enesseval.kilitkelime.core.model.PartOfSpeech.PHRASE, CEFRLevel.A2, list.id, db,
                    )
                }
            }
        }
        "3 örnek liste eklendi"
    }.getOrDefault("Örnek listeler eklenemedi")
}

/** Turkish label; no exact interval is promised (WorkManager and Doze decide the real moment). */
fun rotationTitle(interval: com.enesseval.kilitkelime.core.model.RotationInterval) = when (interval) {
    com.enesseval.kilitkelime.core.model.RotationInterval.THIRTY_MINUTES -> "Çok sık"
    com.enesseval.kilitkelime.core.model.RotationInterval.ONE_HOUR -> "Sık"
    com.enesseval.kilitkelime.core.model.RotationInterval.THREE_HOURS -> "Normal"
    com.enesseval.kilitkelime.core.model.RotationInterval.DAILY -> "Günde bir"
}

/** "Günde 4'e kadar yeni kelime": an upper bound, never a promise. */
fun rotationDetail(interval: com.enesseval.kilitkelime.core.model.RotationInterval) = when (interval) {
    com.enesseval.kilitkelime.core.model.RotationInterval.THREE_HOURS -> "Günde 4'e kadar yeni kelime"
    com.enesseval.kilitkelime.core.model.RotationInterval.ONE_HOUR -> "Günde 12'ye kadar yeni kelime"
    com.enesseval.kilitkelime.core.model.RotationInterval.THIRTY_MINUTES -> "Günde 24'e kadar yeni kelime"
    com.enesseval.kilitkelime.core.model.RotationInterval.DAILY -> "Günde bir yeni kelime"
}
