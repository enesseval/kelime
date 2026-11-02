package com.enesseval.kilitkelime.account

import android.app.Activity
import android.content.Context
import android.os.Build
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.enesseval.kilitkelime.BuildConfig
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.learning.ListSync
import com.enesseval.kilitkelime.core.learning.ListVisibility
import com.enesseval.kilitkelime.core.learning.RemoteList
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.data.AppModel
import com.enesseval.kilitkelime.store.PurchaseManager
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.security.MessageDigest
import java.time.Instant
import java.time.OffsetDateTime
import java.util.UUID

/**
 * The optional account (port of `AccountManager.swift`): Google sign-in through Supabase, the
 * profile, two-way sync of own lists, Keşfet, reports, blocks, feedback and account deletion.
 * Nothing else in the app needs it.
 */
class AccountManager(private val context: Context, private val model: AppModel, private val purchases: PurchaseManager) {
    companion object {
        const val URL = "https://elqtyiuvalanlsxuawar.supabase.co"
        /** Publishable key: safe in the app, row level security guards the data. */
        const val KEY = "sb_publishable_kxWgxMCrFmSfJqpxwZOVww_gf_eyWBa"
        fun link(listID: String) = "https://enesseval.github.io/kelime/liste.html?id=$listID"
    }

    val client = createSupabaseClient(URL, KEY) {
        install(Auth)
        install(Postgrest)
    }

    @Serializable
    data class Profile(
        val id: String,
        val username: String? = null,
        @SerialName("display_name") val displayName: String? = null,
        val avatar: String = "",
    ) {
        val name: String get() = displayName?.takeIf { it.isNotEmpty() } ?: username?.let { "@$it" } ?: "Kelime öğrencisi"
    }

    data class State(
        val userID: String? = null,
        val profile: Profile? = null,
        val syncing: Boolean = false,
        val lastSync: Instant? = null,
        val error: String? = null,
    ) {
        val isSignedIn: Boolean get() = userID != null
    }

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    fun start() {
        model.scope.launch {
            client.auth.sessionStatus.collect { status ->
                val id = (status as? SessionStatus.Authenticated)?.session?.user?.id
                sessionChanged(id)
            }
        }
    }

    private suspend fun sessionChanged(id: String?) {
        if (id == _state.value.userID) return
        _state.value = _state.value.copy(userID = id, profile = if (id == null) null else _state.value.profile)
        if (id != null) {
            purchases.logIn(id.lowercase())
            loadProfile()
            sync()
        }
    }

    // MARK: Google sign-in (Credential Manager → ID token → Supabase)

    suspend fun signInWithGoogle(activity: Activity) {
        _state.value = _state.value.copy(error = null)
        if (BuildConfig.GOOGLE_WEB_CLIENT_ID.isEmpty()) {
            _state.value = _state.value.copy(error = "Google ile giriş henüz ayarlanmadı")
            return
        }
        val raw = UUID.randomUUID().toString()
        val hashed = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray()).joinToString("") { "%02x".format(it) }
        val option = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(BuildConfig.GOOGLE_WEB_CLIENT_ID)
            .setNonce(hashed)
            .build()
        try {
            val result = CredentialManager.create(activity).getCredential(activity, GetCredentialRequest.Builder().addCredentialOption(option).build())
            val credential = GoogleIdTokenCredential.createFrom(result.credential.data)
            client.auth.signInWith(IDToken) {
                idToken = credential.idToken
                provider = Google
                nonce = raw
            }
            val id = client.auth.currentUserOrNull()?.id
            sessionChanged(id)
            val name = credential.displayName.orEmpty()
            if (name.isNotEmpty() && _state.value.profile?.displayName.isNullOrEmpty()) updateProfile(displayName = name)
            Analytics.send(Analytics.Event.signedIn)
        } catch (_: GetCredentialCancellationException) {
        } catch (e: Exception) {
            _state.value = _state.value.copy(error = "Giriş yapılamadı. İnternet bağlantını kontrol et.")
        }
    }

    suspend fun signOut() {
        runCatching { client.auth.signOut() }
        purchases.logOut()
        _state.value = State()
        model.write("sign-out") { db -> ListSync.detach(db) }
    }

    /** Deletes the account and its lists on the server. The lists stay on this device. */
    suspend fun deleteAccount(): Boolean {
        try {
            client.postgrest.rpc("delete_account")
        } catch (e: Exception) {
            _state.value = _state.value.copy(error = "Hesap silinemedi. Tekrar dene.")
            return false
        }
        signOut()
        return true
    }

    // MARK: Profile

    suspend fun loadProfile() {
        val id = _state.value.userID ?: return
        val profile = runCatching {
            client.from("profiles").select { filter { eq("id", id) } }.decodeSingle<Profile>()
        }.getOrNull()
        _state.value = _state.value.copy(profile = profile)
    }

    @Serializable
    private data class ProfileChange(
        @SerialName("display_name") val displayName: String? = null,
        val username: String? = null,
        val avatar: String? = null,
    )

    /** Returns an error message, or null when saved. */
    suspend fun updateProfile(displayName: String? = null, username: String? = null, avatar: String? = null): String? {
        val id = _state.value.userID ?: return "Giriş yapılmadı"
        val name = username?.trim()?.lowercase()
        if (name != null && !Regex("^[a-z0-9_]{3,20}$").matches(name)) return "Kullanıcı adı 3–20 karakter olmalı: harf, rakam ya da _"
        val change = ProfileChange(displayName?.trim()?.take(40), name, avatar)
        return try {
            val profile = client.from("profiles").update(change) {
                select()
                filter { eq("id", id) }
            }.decodeSingle<Profile>()
            _state.value = _state.value.copy(profile = profile)
            null
        } catch (e: Exception) {
            if (e.toString().contains("23505")) "Bu kullanıcı adı alınmış" else "Kaydedilemedi. İnternet bağlantını kontrol et."
        }
    }

    // MARK: Sync (last change wins, tombstones)

    @Serializable
    private data class ListRow(
        val id: String,
        val owner: String? = null,
        val title: String,
        val visibility: String,
        val cards: List<Card>,
        @SerialName("updated_at") val updatedAt: String? = null,
    )

    private fun parse(time: String?): Instant = time?.let { runCatching { OffsetDateTime.parse(it).toInstant() }.getOrNull() } ?: Instant.now()

    /** Sends deletions and changed lists, then applies the account's lists. */
    suspend fun sync() {
        val userID = _state.value.userID ?: return
        if (_state.value.syncing) return
        _state.value = _state.value.copy(syncing = true)
        try {
            for (id in model.read { ListSync.pendingDeletions(it) }) {
                client.from("lists").delete { filter { eq("id", id) } }
                model.read { ListSync.deletionSent(id, it) }
            }
            for (list in model.read { ListSync.pendingUploads(it) }) {
                val row = ListRow(list.id, userID, list.title, list.visibility.raw, list.cards)
                val saved = client.from("lists").upsert(row) { select() }.decodeSingle<ListRow>()
                model.read { ListSync.uploaded(list.id, parse(saved.updatedAt), it) }
            }
            val rows = client.from("lists").select { filter { eq("owner", userID) } }.decodeList<ListRow>()
            val remote = rows.map { RemoteList(it.id, it.title, ListVisibility.fromRaw(it.visibility), it.cards, parse(it.updatedAt)) }
            val changed = model.read { db -> db.transaction { ListSync.merge(remote, db) } }
            _state.value = _state.value.copy(syncing = false, lastSync = Instant.now(), error = null)
            if (changed) model.changed("sync")
        } catch (e: Exception) {
            _state.value = _state.value.copy(syncing = false, error = "Senkronize edilemedi")
        }
    }

    // MARK: Keşfet

    @Serializable
    data class DiscoverItem(
        val id: String,
        val title: String,
        @SerialName("word_count") val wordCount: Int,
        val saves: Int,
        val owner: String,
        val username: String? = null,
        @SerialName("display_name") val displayName: String? = null,
        val avatar: String = "",
    ) {
        val ownerName: String get() = displayName?.takeIf { it.isNotEmpty() } ?: username?.let { "@$it" } ?: "Kelime öğrencisi"
    }

    @Serializable
    data class SharedItem(
        val id: String,
        val title: String,
        val cards: List<Card>,
        @SerialName("word_count") val wordCount: Int,
        val saves: Int,
        val owner: String,
        val username: String? = null,
        @SerialName("display_name") val displayName: String? = null,
        val avatar: String = "",
    ) {
        val ownerName: String get() = displayName?.takeIf { it.isNotEmpty() } ?: username?.let { "@$it" } ?: "Kelime öğrencisi"
    }

    enum class DiscoverSort(val raw: String, val label: String) { POPULAR("popular", "Popüler"), NEW("new", "Yeni") }

    suspend fun discover(search: String, sort: DiscoverSort, page: Int): List<DiscoverItem> =
        client.postgrest.rpc("discover", buildJsonObject {
            put("search", search)
            put("sort", sort.raw)
            put("page_size", 30)
            put("page", page)
        }).decodeList<DiscoverItem>()

    /** A public or link list (or the learner's own); null when private, hidden or gone. */
    suspend fun sharedList(id: String): SharedItem? =
        client.postgrest.rpc("shared_list", buildJsonObject { put("list_id", id) }).decodeList<SharedItem>().firstOrNull()

    @Serializable private data class Save(@SerialName("user_id") val userID: String, @SerialName("list_id") val listID: String)
    @Serializable private data class Report(@SerialName("list_id") val listID: String, val reporter: String, val reason: String)
    @Serializable private data class Block(val blocker: String, val blocked: String)

    suspend fun recordSave(listID: String) {
        val id = _state.value.userID ?: return
        runCatching { client.from("list_saves").upsert(Save(id, listID)) }
    }

    suspend fun report(listID: String, reason: String): Boolean {
        val id = _state.value.userID ?: return false
        return runCatching {
            client.from("reports").upsert(Report(listID, id, reason.take(200))) { onConflict = "list_id,reporter" }
        }.isSuccess
    }

    suspend fun block(owner: String): Boolean {
        val id = _state.value.userID ?: return false
        if (owner == id) return false
        return runCatching { client.from("blocks").upsert(Block(id, owner)) }.isSuccess
    }

    @Serializable
    private data class Feedback(
        val kind: String,
        @SerialName("card_id") val cardID: String?,
        val word: String?,
        val reason: String,
        val note: String,
        @SerialName("app_version") val appVersion: String,
    )

    /** Sends a card error report or a suggestion. Works without an account. */
    suspend fun sendFeedback(kind: String, card: Card?, reason: String, note: String): Boolean {
        val version = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE}) Android ${Build.VERSION.RELEASE}"
        val row = Feedback(kind, card?.id?.take(80), card?.word?.take(120), reason.take(60), note.trim().take(1000), version)
        return runCatching { client.from("feedback").insert(row) }.isSuccess
    }
}
