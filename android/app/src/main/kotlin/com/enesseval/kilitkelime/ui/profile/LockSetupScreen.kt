package com.enesseval.kilitkelime.ui.profile

import android.Manifest
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.provider.Settings as AndroidSettings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.R
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.learning.SystemRandom
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.WidgetMode
import com.enesseval.kilitkelime.core.widgets.SampleContent
import com.enesseval.kilitkelime.core.widgets.WidgetTimelineBuilder
import com.enesseval.kilitkelime.data.WallpaperBackground
import com.enesseval.kilitkelime.lock.RotationScheduler
import com.enesseval.kilitkelime.lock.WallpaperRenderer
import com.enesseval.kilitkelime.lock.WordNotification
import com.enesseval.kilitkelime.lock.WordTileService
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.SegmentedPicker
import com.enesseval.kilitkelime.ui.components.SettingsRow
import com.enesseval.kilitkelime.ui.components.SettingsSection
import com.enesseval.kilitkelime.ui.components.SettingsToggle
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Kilit ekranı: the three ways the word reaches the lock screen on Android. The wallpaper word
 * (the headline), the home/hub widgets, and the silent notification. With a live preview.
 */
@Composable
fun LockSetupScreen() {
    LockSetupContent(showTitle = true)
}

/** Shared by Profil › Kilit ekranı and the onboarding step. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LockSetupContent(showTitle: Boolean, onboarding: Boolean = false) {
    val app = LocalApp.current
    val router = com.enesseval.kilitkelime.ui.LocalRouterOrNull.current
    val context = LocalContext.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val lock by app.model.prefs.flow.collectAsState(initial = null)
    val supported = remember { app.lockScreen.wallpaperSupported() }
    val mode by loadData { db -> Preferences.load(db).defaultWidgetMode }
    val current by loadData { db -> WidgetTimelineBuilder.current(db, app.model.clock, SystemRandom()) }
    var position by remember { mutableFloatStateOf(0.72f) }
    LaunchedEffect(lock?.position) { lock?.position?.let { position = it } }
    var preview by remember { mutableStateOf<ImageBitmap?>(null) }
    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) scope.launch {
            app.model.prefs.update { it.copy(notificationEnabled = true) }
            app.lockScreen.refresh("notification-on")
        }
    }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch {
            withContext(Dispatchers.IO) { savePhoto(context, uri, app.lockScreen.renderer.photoFile) }
            app.model.prefs.update { it.copy(background = WallpaperBackground.PHOTO) }
            app.lockScreen.redrawWallpaper()
        }
    }

    // Live preview at a phone-like size, re-rendered when anything changes.
    LaunchedEffect(lock?.background, position, mode, current?.card?.id) {
        val settings = lock ?: return@LaunchedEffect
        val card = current?.card ?: SampleContent.happy
        preview = withContext(Dispatchers.Default) {
            app.lockScreen.renderer.render(
                WallpaperRenderer.Spec(card, current?.previousCard, mode ?: WidgetMode.CARD, settings.background, position),
                android.util.Size(540, 1170),
            ).asImageBitmap()
        }
    }

    val settings = lock ?: return
    val body: @Composable () -> Unit = {
        Text(
            "Android'de iOS gibi kilit ekranı widget'ı yok. Kelimeyi kilit ekranına üç yolla getiriyoruz; istediğini aç.",
            style = KelimeType.ui(14.sp), color = c.ink2,
        )
        Gap(16.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.Top) {
            Box(
                Modifier.width(150.dp).aspectRatio(540f / 1170f).clip(RoundedCornerShape(22.dp)).border(1.dp, c.line, RoundedCornerShape(22.dp))
                    .semantics { contentDescription = "Kilit ekranı önizlemesi" },
            ) {
                preview?.let { Image(it, null, Modifier.fillMaxWidth()) }
                Text("09:41", style = KelimeType.ui(28.sp, FontWeight.Light), color = Color.White.copy(alpha = 0.85f), modifier = Modifier.align(Alignment.TopCenter).padding(top = 26.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Kicker("KONUM")
                Text("Saat ve bildirimler her telefonda başka yerde; kelimeyi boş kalan yere taşı.", style = KelimeType.ui(13.sp), color = c.ink2)
                Slider(
                    value = position, onValueChange = { position = it }, valueRange = 0.12f..0.88f,
                    onValueChangeFinished = { scope.launch { app.model.prefs.update { it.copy(position = position) }; app.lockScreen.redrawWallpaper() } },
                    colors = SliderDefaults.colors(thumbColor = c.accent, activeTrackColor = c.accent, inactiveTrackColor = c.surface2),
                )
                Row {
                    Text("Üst", style = KelimeType.ui(11.sp), color = c.ink2, modifier = Modifier.weight(1f))
                    Text("Orta", style = KelimeType.ui(11.sp), color = c.ink2, modifier = Modifier.weight(1f))
                    Text("Alt", style = KelimeType.ui(11.sp), color = c.ink2)
                }
            }
        }
        Gap(18.dp)
        SettingsSection("1 · KİLİT EKRANI DUVAR KÂĞIDI") {
            SettingsToggle(
                "Kelimeyi duvar kâğıdına yaz", settings.wallpaperEnabled && supported,
                detail = if (supported) "Ana ekranın duvar kâğıdı değişmez." else "Bu telefon ayrı bir kilit ekranı duvar kâğıdına izin vermiyor. Bildirimi açabilirsin.",
                enabled = supported,
            ) { on ->
                scope.launch {
                    app.model.prefs.update { it.copy(wallpaperEnabled = on, lastWallpaperKey = "") }
                    if (on) Analytics.signal(Analytics.Signal.WALLPAPER_ENABLED)
                    app.lockScreen.refresh("wallpaper-$on")
                }
            }
        }
        Gap(10.dp)
        Kicker("ARKA PLAN")
        Gap(8.dp)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            for (bg in WallpaperBackground.entries) {
                val selected = settings.background == bg
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        Modifier.size(54.dp).clip(CircleShape)
                            .background(if (bg == WallpaperBackground.PHOTO) Brush.linearGradient(listOf(c.surface2, c.surface2)) else Brush.verticalGradient(listOf(Color(bg.top), Color(bg.bottom))))
                            .border(if (selected) 3.dp else 1.dp, if (selected) c.accent else c.line, CircleShape)
                            .clickable {
                                if (bg == WallpaperBackground.PHOTO) {
                                    photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                                } else scope.launch {
                                    app.model.prefs.update { it.copy(background = bg) }
                                    app.lockScreen.redrawWallpaper()
                                }
                            },
                        contentAlignment = Alignment.Center,
                    ) { if (bg == WallpaperBackground.PHOTO) Text("+", style = KelimeType.ui(22.sp), color = c.ink) }
                    Text(bg.title, style = KelimeType.ui(11.sp), color = c.ink2)
                }
            }
        }
        Text("Fotoğrafın yalnızca bu telefonda kalır; hiçbir yere yüklenmez.", style = KelimeType.ui(12.sp), color = c.ink2, modifier = Modifier.padding(top = 6.dp))
        Gap(10.dp)
        Kicker("STİL")
        Gap(6.dp)
        SegmentedPicker(listOf(WidgetMode.CARD, WidgetMode.DICTIONARY, WidgetMode.SENTENCE, WidgetMode.SELF_TEST), mode ?: WidgetMode.CARD, { it.label }) { m ->
            scope.launch {
                app.model.write("mode") { db -> Preferences.load(db).copy(defaultWidgetMode = m).save(db) }
                app.lockScreen.redrawWallpaper()
            }
        }
        if (mode == WidgetMode.SELF_TEST) {
            Text("Anlam ve ilk harf görünür; cevabı bir sonraki kelimede ve Bugün'de görürsün.", style = KelimeType.ui(12.sp), color = c.ink2, modifier = Modifier.padding(top = 6.dp))
        }
        if (!RotationScheduler.canScheduleExact(context) && Build.VERSION.SDK_INT >= 31) {
            Gap(10.dp)
            SettingsSection("ZAMANINDA DEĞİŞSİN") {
                SettingsRow("Tam zamanında değiştir", "İzin verirsen kelime saat başında değişir; vermezsen birkaç dakika gecikebilir.", onClick = {
                    context.startActivity(Intent(AndroidSettings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}")))
                })
            }
        }
        Gap(18.dp)
        SettingsSection("2 · WIDGET'LAR") {
            SettingsRow("Kart, Hangisi? ve Büyük", "Ana ekranda boş bir yere uzun bas › Widget'lar › Kilit Kelime. Android 16'da şarj ekranı hub'ına da eklenir.")
            if (Build.VERSION.SDK_INT >= 33) {
                Divider()
                SettingsRow("Hızlı Ayarlar kutucuğu", "Bildirim panelinden tek dokunuşla Hızlı Tekrar.", onClick = {
                    val sbm = context.getSystemService(StatusBarManager::class.java)
                    sbm.requestAddTileService(
                        ComponentName(context, WordTileService::class.java), context.getString(R.string.tile_quick_review),
                        Icon.createWithResource(context, R.drawable.ic_tile), context.mainExecutor,
                    ) { Analytics.send(Analytics.Event.tileAdded) }
                })
            }
        }
        Gap(18.dp)
        SettingsSection("3 · BİLDİRİM") {
            SettingsToggle("Kilit ekranında bildirim olarak göster", settings.notificationEnabled, detail = "Sessiz; her yeni kelimede güncellenir. Biliyorum / Zorlanıyorum düğmeleriyle.") { on ->
                if (on && Build.VERSION.SDK_INT >= 33 && !WordNotification.canPost(context)) {
                    notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                    scope.launch { app.model.prefs.update { it.copy(notificationsRequested = true) } }
                } else scope.launch {
                    app.model.prefs.update { it.copy(notificationEnabled = on) }
                    if (on) Analytics.send(Analytics.Event.notificationOn)
                    app.lockScreen.refresh("notification-$on")
                }
            }
        }
        if (!onboarding && router != null) {
            Gap(18.dp)
            SettingsSection("GELİŞMİŞ") {
                SettingsRow("Değişim sıklığı", onClick = router::openRotation)
            }
        }
    }
    if (showTitle) PushedScreen("Kilit ekranı") { body() } else Column { body() }
}

/** Copies a picked photo into app storage, downscaled to at most 2× the screen's long side. */
private fun savePhoto(context: android.content.Context, uri: Uri, target: File) {
    target.parentFile?.mkdirs()
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
    val maxSide = 3200
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSide) sample *= 2
    val bitmap = context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) } ?: return
    target.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 92, it) }
    bitmap.recycle()
}
