package com.enesseval.kilitkelime.ui.lists

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
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
import androidx.core.content.FileProvider
import com.enesseval.kilitkelime.account.AccountManager
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.learning.ListVisibility
import com.enesseval.kilitkelime.core.learning.SharedList
import com.enesseval.kilitkelime.core.learning.UserListException
import com.enesseval.kilitkelime.core.learning.UserLists
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.queries.WordQueries
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.EmptyText
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.SegmentedPicker
import com.enesseval.kilitkelime.ui.components.SettingsRow
import com.enesseval.kilitkelime.ui.components.SettingsSection
import com.enesseval.kilitkelime.ui.components.StateDot
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.words.NewListDialog
import com.enesseval.kilitkelime.ui.words.SearchField
import com.enesseval.kilitkelime.ui.words.SearchFieldPlain
import com.enesseval.kilitkelime.ui.words.WidgetSwitch
import kotlinx.coroutines.launch
import java.io.File

val ListVisibility.label: String
    get() = when (this) {
        ListVisibility.PRIVATE -> "Sadece ben"
        ListVisibility.LINK -> "Linke sahip olanlar"
        ListVisibility.PUBLIC -> "Herkese açık"
    }

val ListVisibility.detail: String
    get() = when (this) {
        ListVisibility.PRIVATE -> "Liste sadece senin cihazlarında görünür."
        ListVisibility.LINK -> "Linki gönderdiğin kişiler açıp ekleyebilir."
        ListVisibility.PUBLIC -> "Keşfet'te herkes görür ve ekleyebilir."
    }

/** Opens the share sheet for a list file (.kelimelist). */
fun shareListFile(context: Context, shared: SharedList) {
    val dir = File(context.cacheDir, "share").apply { mkdirs() }
    val file = File(dir, "${shared.title.filter { it.isLetterOrDigit() || it == ' ' }.ifBlank { "liste" }}.${SharedList.FILE_EXTENSION}")
    file.writeText(shared.encoded())
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
    val send = Intent(Intent.ACTION_SEND).setType("application/json").putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    context.startActivity(Intent.createChooser(send, shared.title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

fun shareText(context: Context, title: String, text: String) {
    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_SUBJECT, title).putExtra(Intent.EXTRA_TEXT, text)
    context.startActivity(Intent.createChooser(send, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserListScreen(listID: String) {
    val app = LocalApp.current
    val router = LocalRouter.current
    val context = LocalContext.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val pro by app.model.isPro.collectAsState()
    val account by app.account.state.collectAsState()
    val list by loadData(listID) { db -> UserLists.list(listID, db) }
    val words by loadData(listID) { db -> UserLists.cards(listID, db).mapNotNull { WordQueries.item(it.id, db) } }
    var menu by remember { mutableStateOf(false) }
    var renaming by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }
    var adding by remember { mutableStateOf(false) }
    var visibility by remember { mutableStateOf(false) }

    fun edit(reason: String, block: (com.enesseval.kilitkelime.core.db.SqlDb) -> Unit) = scope.launch {
        app.model.writeAndRequeue(reason) { db -> block(db) }
        app.account.sync()
    }

    val current = list
    PushedScreen(
        current?.title ?: "",
        actions = {
            if (current != null) {
                IconButton(onClick = { adding = true }) { Icon(Icons.Default.Add, "Kelime ekle", tint = c.accent) }
                Box {
                    IconButton(onClick = { menu = true }) { Icon(Icons.Default.MoreVert, "Liste seçenekleri", tint = c.ink) }
                    DropdownMenu(menu, { menu = false }) {
                        DropdownMenuItem(text = { Text("Adını değiştir") }, onClick = { menu = false; renaming = true })
                        if (!current.imported) {
                            DropdownMenuItem(text = { Text("Paylaşım: ${current.visibility.label}") }, onClick = {
                                menu = false
                                if (!account.isSignedIn) router.toast = "Paylaşmak için Profil'den Google ile giriş yap" else visibility = true
                            })
                        }
                        DropdownMenuItem(text = { Text("Dosya olarak gönder") }, onClick = {
                            menu = false
                            if (!pro) router.showPaywall(PaywallTrigger.SHARE) else scope.launch {
                                app.model.read { db -> UserLists.export(listID, db) }?.let { shareListFile(context, it); Analytics.send(Analytics.Event.listShared) }
                            }
                        })
                        DropdownMenuItem(text = { Text("Listeyi sil", color = c.amberInk) }, onClick = { menu = false; deleting = true })
                    }
                }
            }
        },
    ) {
        if (current == null) return@PushedScreen
        val items = words ?: emptyList()
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(current.title, style = KelimeType.ui(28.sp, FontWeight.Bold), color = c.ink)
                Text("${items.size} kelime", style = KelimeType.ui(14.sp), color = c.ink2)
            }
            WidgetSwitch(current.enabled) { on -> edit("list-enabled") { db -> UserLists.setEnabled(on, listID, db) } }
        }
        Gap(16.dp)
        if (items.isEmpty()) {
            EmptyText("Kelime ekle; listeyi açınca widget'ta ve Hızlı Tekrar'da görünür.")
            TintedButton("Kelime ekle") { adding = true }
        } else {
            Text("Bir kelimeyi listeden çıkarmak için sola kaydır.", style = KelimeType.ui(12.sp), color = c.ink2)
            Gap(6.dp)
            for (item in items) {
                androidx.compose.runtime.key(item.id) {
                    val state = rememberSwipeToDismissBoxState(confirmValueChange = {
                        if (it == SwipeToDismissBoxValue.EndToStart) edit("list-remove") { db -> UserLists.remove(item.id, listID, db) }
                        it == SwipeToDismissBoxValue.EndToStart
                    })
                    SwipeToDismissBox(
                        state, enableDismissFromStartToEnd = false,
                        backgroundContent = {
                            Box(Modifier.fillMaxSize().background(c.amberBackground).padding(horizontal = 16.dp), contentAlignment = Alignment.CenterEnd) {
                                Text("Listeden çıkar", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.amberInk)
                            }
                        },
                    ) {
                        Row(
                            Modifier.fillMaxWidth().background(c.background).clickable { router.openWord(item.id) }.padding(vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            StateDot(item.state)
                            Column(Modifier.weight(1f)) {
                                Text(item.card.word, style = KelimeType.english(20.sp), color = c.ink)
                                Text(item.card.meaning, style = KelimeType.ui(14.sp), color = c.ink2)
                            }
                            if (item.card.id.startsWith(UserLists.CUSTOM_PREFIX)) Text("Kendi kelimen", style = KelimeType.ui(11.sp), color = c.ink2)
                        }
                    }
                }
            }
        }
    }

    if (renaming && current != null) {
        NewListDialog(onDismiss = { renaming = false }, initial = current.title, title = "Adını değiştir", confirm = "Kaydet") { title ->
            renaming = false
            edit("list-rename") { db -> UserLists.rename(listID, title, db) }
        }
    }
    if (deleting && current != null) {
        AlertDialog(
            onDismissRequest = { deleting = false },
            containerColor = c.surface,
            title = { Text("Liste silinsin mi?") },
            text = { Text("Kendi yazdığın kelimeler de silinir. Uygulamanın kelimeleri ve ilerlemen yerinde kalır.") },
            confirmButton = {
                Text("Sil", color = c.amberInk, style = KelimeType.ui(15.sp, FontWeight.SemiBold), modifier = Modifier.clickable {
                    deleting = false
                    scope.launch {
                        app.model.writeAndRequeue("list-delete") { db -> UserLists.delete(listID, db) }
                        app.account.sync()
                        router.back()
                    }
                }.padding(12.dp))
            },
            dismissButton = { Text("Vazgeç", color = c.ink2, modifier = Modifier.clickable { deleting = false }.padding(12.dp)) },
        )
    }
    if (adding) {
        ModalBottomSheet(onDismissRequest = { adding = false }, containerColor = c.background) {
            AddWordSheet(listID) { message -> router.toast = message }
        }
    }
    if (visibility && current != null) {
        ModalBottomSheet(onDismissRequest = { visibility = false }, containerColor = c.background) {
            Column(Modifier.padding(horizontal = 20.dp).navigationBarsPadding().padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Paylaşım", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
                SettingsSection("KİMLER GÖREBİLİR") {
                    ListVisibility.entries.forEachIndexed { i, option ->
                        if (i > 0) Divider()
                        SettingsRow(option.label, option.detail, onClick = {
                            if (option != ListVisibility.PRIVATE && !pro) {
                                visibility = false
                                router.showPaywall(PaywallTrigger.SHARE)
                            } else {
                                edit("list-visibility") { db -> UserLists.setVisibility(option, listID, db) }
                            }
                        }) { if (option == current.visibility) Text("✓", color = c.accent, style = KelimeType.ui(16.sp, FontWeight.Bold)) }
                    }
                }
                Text("Liste hesabınla eşitlenir; değişikliklerin paylaştığın herkeste güncellenir.", style = KelimeType.ui(13.sp), color = c.ink2)
                if (current.visibility != ListVisibility.PRIVATE) {
                    PrimaryButton("Linki paylaş") {
                        shareText(context, current.title, AccountManager.link(current.id))
                        Analytics.send(Analytics.Event.listShared)
                    }
                }
            }
        }
    }
}

/** Search the app's words, or type your own (word, meaning, part of speech, example). */
@Composable
private fun AddWordSheet(listID: String, onMessage: (String) -> Unit) {
    val app = LocalApp.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    var search by remember { mutableStateOf("") }
    var custom by remember { mutableStateOf(false) }
    val suggestions by loadData(search) { db -> UserLists.suggestions(search, db) }
    var word by remember { mutableStateOf("") }
    var meaning by remember { mutableStateOf("") }
    var pos by remember { mutableStateOf(PartOfSpeech.NOUN) }
    var example by remember { mutableStateOf("") }
    var exampleTR by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    fun add(block: (com.enesseval.kilitkelime.core.db.SqlDb) -> String) = scope.launch {
        try {
            val added = app.model.writeAndRequeue("list-add") { db -> block(db) }
            onMessage("$added eklendi")
            app.account.sync()
        } catch (e: UserListException) {
            error = when (e.reason) {
                UserListException.Reason.DUPLICATE_WORD -> "Bu kelime listede var."
                UserListException.Reason.EMPTY_WORD -> "Kelime ve anlam gerekli."
                else -> null
            }
        }
    }

    Column(
        Modifier.padding(horizontal = 20.dp).navigationBarsPadding().padding(bottom = 16.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Kelime ekle", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
        if (!custom) {
            SearchField(search, "Kelime ya da anlam ara") { search = it }
            if (search.isNotBlank()) {
                SettingsSection("UYGULAMADAKİ KELİMELER") {
                    (suggestions ?: emptyList()).take(12).forEachIndexed { i, card ->
                        if (i > 0) Divider()
                        SettingsRow(card.word, card.meaning, onClick = {
                            add { db -> UserLists.add(card.id, listID, db); card.word }
                        })
                    }
                }
                TintedButton("“$search” kelimesini kendin ekle") { word = search; custom = true }
            } else {
                Text("Uygulamada olmayan bir kelimeyi anlamıyla birlikte ekleyebilirsin.", style = KelimeType.ui(13.sp), color = c.ink2)
                TintedButton("Kendi kelimeni yaz") { custom = true }
            }
        } else {
            Kicker("KENDİ KELİMEN")
            SearchFieldPlain(word, "Kelime (İngilizce)") { word = it }
            SearchFieldPlain(meaning, "Anlamı (Türkçe; birden çoksa virgülle)") { meaning = it }
            SegmentedPicker(
                listOf(PartOfSpeech.NOUN, PartOfSpeech.VERB, PartOfSpeech.ADJECTIVE, PartOfSpeech.ADVERB, PartOfSpeech.PHRASE), pos,
                { it.label.replaceFirstChar { ch -> ch.titlecase(com.enesseval.kilitkelime.ui.components.TR) } },
            ) { pos = it }
            SearchFieldPlain(example, "Örnek cümle (İngilizce) · İsteğe bağlı") { example = it }
            SearchFieldPlain(exampleTR, "Örneğin Türkçesi · İsteğe bağlı") { exampleTR = it }
            error?.let { Text(it, style = KelimeType.ui(13.sp), color = c.amberInk) }
            PrimaryButton("Ekle") {
                add { db ->
                    val level = Preferences.load(db).level
                    UserLists.addCustom(word, meaning, pos, level, listID, db, example, exampleTR).word
                }
                word = ""; meaning = ""; example = ""; exampleTR = ""
            }
        }
    }
}
