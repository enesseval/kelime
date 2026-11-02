package com.enesseval.kilitkelime.ui.discover

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.account.AccountManager
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.learning.SharedList
import com.enesseval.kilitkelime.core.learning.UserLists
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.ui.Avatar
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.ScreenTitle
import com.enesseval.kilitkelime.ui.components.SegmentedPicker
import com.enesseval.kilitkelime.ui.components.SettingsRow
import com.enesseval.kilitkelime.ui.components.SettingsSection
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.words.SearchField
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Keşfet: public lists by others, popular or new, with search and paging. Browsing is free. */
@Composable
fun DiscoverScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    var search by remember { mutableStateOf("") }
    var sort by remember { mutableStateOf(AccountManager.DiscoverSort.POPULAR) }
    val items = remember { mutableStateListOf<AccountManager.DiscoverItem>() }
    var page by remember { mutableIntStateOf(0) }
    var more by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(false) }

    suspend fun load(reset: Boolean) {
        if (loading) return
        loading = true
        try {
            val next = if (reset) 0 else page + 1
            val result = app.account.discover(search.trim(), sort, next)
            if (reset) items.clear()
            items.addAll(result)
            page = next
            more = result.size == 30
            error = false
        } catch (e: Exception) {
            error = true
        } finally {
            loading = false
        }
    }
    LaunchedEffect(search, sort) {
        delay(300) // typing settles before searching
        load(reset = true)
    }

    Column(Modifier.fillMaxSize().background(c.background).statusBarsPadding()) {
        Column(Modifier.padding(horizontal = 20.dp).padding(top = 6.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ScreenTitle("Keşfet")
            SearchField(search, "Liste ara") { search = it }
            SegmentedPicker(AccountManager.DiscoverSort.entries, sort, { it.label }) { sort = it }
        }
        Gap(8.dp)
        when {
            error && items.isEmpty() -> Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Keşfet'e ulaşılamadı", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                Text("İnternet bağlantını kontrol edip tekrar dene.", style = KelimeType.ui(14.sp), color = c.ink2)
                TintedButton("Tekrar dene", fullWidth = false) { scope.launch { load(true) } }
            }
            !loading && items.isEmpty() -> Column(Modifier.padding(20.dp)) {
                Text(if (search.isBlank()) "Henüz herkese açık liste yok" else "Bu aramayla liste bulunamadı", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                Text("Kendi listeni Kelimelerim › Listeler'den herkese açabilirsin.", style = KelimeType.ui(14.sp), color = c.ink2)
            }
            else -> LazyColumn(contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp)) {
                itemsIndexed(items, key = { _, it -> it.id }) { index, item ->
                    if (index > 0) Divider()
                    Row(Modifier.fillMaxWidth().clickable { router.openSharedList(item.id) }.padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Avatar(item.avatar, item.ownerName, 36)
                        Column(Modifier.weight(1f).padding(start = 12.dp)) {
                            Text(item.title, style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.ink)
                            Text("${item.ownerName} · ${item.wordCount} kelime" + if (item.saves > 0) " · ${item.saves} kayıt" else "", style = KelimeType.ui(13.sp), color = c.ink2)
                        }
                    }
                    if (index == items.lastIndex && more) LaunchedEffect(index) { load(false) }
                }
            }
        }
    }
}

/** A shared list (Keşfet or a link): its words, "Listelerime ekle" (Pro), report and block. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SharedListScreen(listID: String) {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val pro by app.model.isPro.collectAsState()
    val account by app.account.state.collectAsState()
    var item by remember { mutableStateOf<AccountManager.SharedItem?>(null) }
    var state by remember { mutableIntStateOf(0) } // 0 loading, 1 loaded, 2 hidden, 3 error
    var menu by remember { mutableStateOf(false) }
    var reporting by remember { mutableStateOf(false) }
    var blocking by remember { mutableStateOf(false) }
    val saved by loadData(listID) { db -> UserLists.savedCopy(listID, db) }

    LaunchedEffect(listID) {
        state = try {
            item = app.account.sharedList(listID)
            if (item == null) 2 else 1
        } catch (e: Exception) {
            3
        }
    }

    PushedScreen(
        item?.title ?: "",
        actions = {
            if (item != null && item?.owner != account.userID) {
                Box {
                    IconButton(onClick = { menu = true }) { Icon(Icons.Default.MoreVert, "Liste seçenekleri", tint = c.ink) }
                    DropdownMenu(menu, { menu = false }) {
                        DropdownMenuItem(text = { Text("Şikayet et") }, onClick = {
                            menu = false
                            if (account.isSignedIn) reporting = true else router.toast = "Bunun için Profil'den giriş yap"
                        })
                        DropdownMenuItem(text = { Text("Kullanıcıyı engelle") }, onClick = {
                            menu = false
                            if (account.isSignedIn) blocking = true else router.toast = "Bunun için Profil'den giriş yap"
                        })
                    }
                }
            }
        },
    ) {
        when (state) {
            0 -> return@PushedScreen
            2 -> {
                Text("Bu liste paylaşılmıyor", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                Text("Sahibi listeyi gizlemiş ya da silmiş olabilir.", style = KelimeType.ui(14.sp), color = c.ink2)
                return@PushedScreen
            }
            3 -> {
                Text("Liste açılamadı", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                Text("İnternet bağlantını kontrol edip tekrar dene.", style = KelimeType.ui(14.sp), color = c.ink2)
                return@PushedScreen
            }
        }
        val shared = item ?: return@PushedScreen
        Row(verticalAlignment = Alignment.CenterVertically) {
            Avatar(shared.avatar, shared.ownerName, 40)
            Column(Modifier.padding(start = 12.dp)) {
                Text(shared.title, style = KelimeType.ui(24.sp, FontWeight.Bold), color = c.ink)
                Text("${shared.ownerName} · ${shared.cards.size} kelime", style = KelimeType.ui(14.sp), color = c.ink2)
            }
        }
        Gap(16.dp)
        val copy = saved
        when {
            shared.owner == account.userID -> Text("Bu senin listen.", style = KelimeType.ui(14.sp), color = c.ink2)
            copy != null -> TintedButton("Listelerinde · aç") { router.openList(copy.id) }
            else -> {
                PrimaryButton("Listelerime ekle") {
                    if (!pro) {
                        router.showPaywall(PaywallTrigger.DISCOVER)
                        return@PrimaryButton
                    }
                    scope.launch {
                        try {
                            val list = app.model.writeAndRequeue("discover-save") { db -> UserLists.import(SharedList(title = shared.title, cards = shared.cards), db, sourceID = shared.id) }
                            app.account.recordSave(shared.id)
                            Analytics.send(Analytics.Event.listImported)
                            router.toast = "${list.title} listelerine eklendi"
                        } catch (e: Exception) {
                            router.toast = "Liste eklenemedi"
                        }
                    }
                }
                Gap(6.dp)
                Text("Liste widget'ına ve Hızlı Tekrar'a eklenir. Bildiğin kelimeler ilerlemeni korur.", style = KelimeType.ui(13.sp), color = c.ink2)
            }
        }
        Gap(16.dp)
        SettingsSection("KELİMELER") {
            shared.cards.forEachIndexed { i, card ->
                if (i > 0) Divider()
                SettingsRow(card.word, card.meaning)
            }
        }
    }

    if (reporting) {
        ModalBottomSheet(onDismissRequest = { reporting = false }, containerColor = c.background) {
            Column(Modifier.padding(horizontal = 20.dp).navigationBarsPadding().padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Neden şikayet ediyorsun?", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                SettingsSection("SEBEP") {
                    listOf("Uygunsuz ya da saldırgan içerik", "Spam ya da reklam", "Yanlış ya da yanıltıcı içerik", "Başka bir sebep").forEachIndexed { i, reason ->
                        if (i > 0) Divider()
                        SettingsRow(reason, onClick = {
                            reporting = false
                            scope.launch { router.toast = if (app.account.report(listID, reason)) "Teşekkürler, inceleyeceğiz" else "Gönderilemedi" }
                        })
                    }
                }
            }
        }
    }
    if (blocking) {
        AlertDialog(
            onDismissRequest = { blocking = false },
            containerColor = c.surface,
            title = { Text("Kullanıcı engellensin mi?") },
            text = { Text("Bu kişinin listeleri artık Keşfet'te sana görünmez.") },
            confirmButton = {
                Text("Engelle", color = c.amberInk, style = KelimeType.ui(15.sp, FontWeight.SemiBold), modifier = Modifier.clickable {
                    blocking = false
                    val owner = item?.owner ?: return@clickable
                    scope.launch {
                        val ok = app.account.block(owner)
                        router.toast = if (ok) "Engellendi" else "Engellenemedi"
                        if (ok) router.back()
                    }
                }.padding(12.dp))
            },
            dismissButton = { Text("Vazgeç", color = c.ink2, modifier = Modifier.clickable { blocking = false }.padding(12.dp)) },
        )
    }
}
