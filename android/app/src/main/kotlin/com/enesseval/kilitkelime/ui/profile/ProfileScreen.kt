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
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDatePickerState
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
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

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
    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}

    fun open(url: String) = context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))

    Column(
        Modifier.fillMaxSize().background(c.background).statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp).padding(top = 6.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        ScreenTitle("Profil")
        val d = data ?: return@Column

        // Account (optional).
        SurfaceCard {
            if (account.isSignedIn) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Avatar(account.profile?.avatar ?: "", account.profile?.name ?: "", 52)
                    Column(Modifier.weight(1f).padding(start = 14.dp)) {
                        Text(account.profile?.name ?: "Hesap yükleniyor", style = KelimeType.ui(18.sp, FontWeight.SemiBold), color = c.ink)
                        account.profile?.username?.let { Text("@$it", style = KelimeType.ui(13.sp), color = c.ink2) }
                    }
                    Text("Düzenle ›", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.accent, modifier = Modifier.clickable { editing = true }.padding(8.dp))
                }
                Gap(10.dp)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        when {
                            account.syncing -> "Eşitleniyor…"
                            account.error != null -> account.error!!
                            account.lastSync != null -> "Eşitlendi · " + TurkishDate.header(LocalDate.now())
                            else -> ""
                        },
                        style = KelimeType.ui(13.sp), color = c.ink2, modifier = Modifier.weight(1f),
                    )
                    Text("Eşitle", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.accent, modifier = Modifier.clickable { scope.launch { app.account.sync() } }.padding(8.dp))
                }
            } else {
                Text("Hesabını bağla", style = KelimeType.ui(18.sp, FontWeight.SemiBold), color = c.ink)
                Gap(6.dp)
                Text("Listelerin yedeklenir ve cihazlarında eşitlenir. Listelerini linkle paylaşabilir ya da Keşfet'te herkese açabilirsin. Pro'n da hesabına bağlanır.", style = KelimeType.ui(14.sp), color = c.ink2)
                Gap(12.dp)
                PrimaryButton("Google ile giriş yap") { scope.launch { app.account.signInWithGoogle(activity) } }
                account.error?.let { Gap(6.dp); Text(it, style = KelimeType.ui(13.sp), color = c.amberInk) }
            }
        }

        // Pro: an entry that is always there (store review must find the purchases), or the membership.
        if (pro) {
            SettingsSection("ÜYELİK") {
                SettingsRow("Kilit Kelime Pro") {
                    Icon(Icons.Filled.Verified, null, tint = c.greenInk, modifier = Modifier.size(18.dp))
                    Text(" Pro", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.greenInk)
                }
                Divider()
                SettingsRow("Aboneliği yönet", onClick = { open("https://play.google.com/store/account/subscriptions") })
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

        // Lock screen.
        SettingsSection("KİLİT EKRANI") {
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
            SettingsRow("Kilit ekranı görünümü", d.prefs.defaultWidgetMode.label, onClick = { picker = "mode" })
            Divider()
            SettingsRow("Gösterilecekler", d.prefs.widgetContent.label, onClick = { picker = "content" })
            Divider()
            SettingsRow("Değişim sıklığı", rotationTitle(d.prefs.effectiveRotation), onClick = router::openRotation)
        }

        SettingsSection("SEVİYE VE SINAV") {
            SettingsRow("Seviye", d.prefs.level.raw, onClick = { picker = "level" })
            Divider()
            SettingsRow("Sınav geri sayımı", d.exam?.let { (exam, date) -> "${exam.raw} · ${TurkishDate.long(date)}" } ?: "Kapalı", onClick = { picker = "exam"; Analytics.send(Analytics.Event.examCountdown) })
        }

        SettingsSection("HATIRLATMA VE TELAFFUZ") {
            SettingsToggle("Günlük hatırlatma", d.reminder != null, detail = d.reminder?.let(Reminder::label)) { on ->
                if (on && Build.VERSION.SDK_INT >= 33) {
                    notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                    scope.launch { app.model.prefs.update { it.copy(notificationsRequested = true) } }
                }
                val minutes = if (on) 20 * 60 else null
                scope.launch {
                    app.model.write("reminder") { db -> Settings.setInt(db, SettingKey.REMINDER_TIME, minutes) }
                    Reminder.schedule(context, minutes)
                }
            }
            d.reminder?.let { minutes ->
                Divider()
                SettingsRow("Saat", Reminder.label(minutes), onClick = {
                    TimePickerDialog(context, { _, h, m ->
                        scope.launch {
                            app.model.write("reminder") { db -> Settings.setInt(db, SettingKey.REMINDER_TIME, h * 60 + m) }
                            Reminder.schedule(context, h * 60 + m)
                        }
                    }, minutes / 60, minutes % 60, true).show()
                })
            }
            Divider()
            SettingsRow("Ses ve hız", "en-US · %.1f×".format(d.speechRate), onClick = {
                val next = when {
                    d.speechRate < 0.8f -> 0.9f
                    d.speechRate < 1.0f -> 1.0f
                    else -> 0.7f
                }
                scope.launch { app.model.write("speech") { db -> Settings.set(db, SettingKey.SPEECH_RATE, next.toString()) } }
            })
        }

        SettingsSection("DESTEK") {
            SettingsRow("Öneri gönder", onClick = { router.openFeedback() })
            Divider()
            SettingsRow("Satın alımları geri yükle", onClick = {
                scope.launch { router.toast = if (app.purchases.restore()) "Pro geri yüklendi" else "Geri yüklenecek satın alma bulunamadı" }
            })
            Divider()
            SettingsRow("Kullanım koşulları", onClick = { open(TERMS_URL) })
            Divider()
            SettingsRow("Gizlilik politikası", onClick = { open(PRIVACY_URL) })
        }

        SettingsSection("BAŞTAN BAŞLA") {
            SettingsRow("İlerlemeyi sıfırla", onClick = { confirm = "reset" })
        }

        if (account.isSignedIn) {
            SettingsSection("HESAP") {
                SettingsRow("Çıkış yap", onClick = { confirm = "signout" })
                Divider()
                SettingsRow("Hesabı sil", onClick = { confirm = "delete" })
            }
        }

        if (BuildConfig.DEV_TOOLS) {
            SettingsSection("GELİŞTİRİCİ") {
                SettingsToggle("Pro'yu aç (satın almadan)", pro) { on -> scope.launch { app.model.setPro(on) } }
                Divider()
                SettingsRow("Widget günlüğü ve ölçüm modu", onClick = router::openWidgetLog)
                Divider()
                SettingsRow("Bugünün bulmacalarını sıfırla", onClick = {
                    scope.launch {
                        app.model.write("dev-puzzles") { db -> db.execute("DELETE FROM puzzle_progress WHERE puzzle_key LIKE ?", listOf("%-${app.model.clock.today}%")) }
                        router.toast = "Bulmacalar sıfırlandı"
                    }
                })
                Divider()
                SettingsRow("Tanıtımı yeniden göster", onClick = {
                    scope.launch { app.model.write("dev-onboarding") { db -> Settings.setBool(db, SettingKey.ONBOARDING_DONE, false) } }
                })
            }
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(top = 8.dp)) {
            Text("Kilit Kelime v${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", style = KelimeType.ui(12.sp), color = c.ink2)
            Text("Kelime listesi: New General Service List, CC BY-SA 4.0", style = KelimeType.ui(12.sp), color = c.ink2)
            Text("İçerik yapay zekâ ile üretildi ve kontrol edildi", style = KelimeType.ui(12.sp), color = c.ink2)
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
                    "level" -> Choice("Seviye", d.levels, d.prefs.level, { it.raw }, { null }) { level ->
                        picker = null
                        scope.launch { app.model.writeAndRequeue("level", keepCurrent = false) { db -> Curriculum.switchLevel(level, db) } }
                    }
                    "exam" -> ExamPicker(d.exam) { exam, date ->
                        picker = null
                        scope.launch {
                            app.model.write("exam") { db -> if (exam == null || date == null) ExamCountdown.clear(db) else ExamCountdown.set(exam, date, db) }
                        }
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ExamPicker(current: Pair<DeckID, LocalDate>?, onDone: (DeckID?, LocalDate?) -> Unit) {
    val c = Palette.current
    var exam by remember { mutableStateOf(current?.first ?: DeckID.YDS) }
    var choosingDate by remember { mutableStateOf(false) }
    val state = rememberDatePickerState(
        initialSelectedDateMillis = (current?.second ?: LocalDate.now().plusMonths(2)).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
    )
    Text("Sınav geri sayımı", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
    com.enesseval.kilitkelime.ui.components.SegmentedPicker(ExamCountdown.exams, exam, { it.raw }) { exam = it }
    TintedButton("Sınav tarihi: " + (state.selectedDateMillis?.let { TurkishDate.long(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) } ?: "seç")) { choosingDate = true }
    PrimaryButton("Kaydet") { onDone(exam, state.selectedDateMillis?.let { Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }) }
    if (current != null) TintedButton("Geri sayımı kapat") { onDone(null, null) }
    if (choosingDate) {
        DatePickerDialog(onDismissRequest = { choosingDate = false }, confirmButton = { Text("Tamam", modifier = Modifier.clickable { choosingDate = false }.padding(12.dp), color = c.accent) }) {
            DatePicker(state)
        }
    }
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
