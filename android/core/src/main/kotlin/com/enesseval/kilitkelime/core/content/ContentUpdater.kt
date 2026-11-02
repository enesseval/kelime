package com.enesseval.kilitkelime.core.content

import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.model.Json
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.security.MessageDigest
import java.time.Instant

/** What GitHub Pages serves next to `cards.json`. */
@Serializable
data class ContentManifest(val contentVersion: Int, val schema: Int, val sha256: String, val size: Int)

/**
 * Fetches newer content from GitHub Pages (port of `ContentUpdater.swift`). Bundled content always
 * works offline; a newer verified download is kept and preferred at the next launch.
 * Nothing about the learner is sent: two plain GET requests.
 */
object ContentUpdater {
    const val SCHEMA = 3
    const val BASE_URL = "https://enesseval.github.io/kelime/content/"
    const val CHECK_EVERY_SECONDS = 6 * 60 * 60L

    sealed interface Outcome {
        data object Skipped : Outcome
        data class UpToDate(val version: Int) : Outcome
        data class Updated(val version: Int) : Outcome
    }

    class UpdateException(message: String) : Exception(message)

    fun version(text: String): Int? = try {
        Json.parseToJsonElement(text).jsonObject["contentVersion"]?.jsonPrimitive?.int
    } catch (_: Exception) {
        null
    }

    /** The content to import at launch: the download when it is newer than the bundled file. */
    fun newest(bundled: String, downloaded: String?): String {
        if (downloaded == null) return bundled
        val new = version(downloaded) ?: return bundled
        return if (new > (version(bundled) ?: 0)) downloaded else bundled
    }

    fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    /**
     * Asks for the manifest at most every 6 hours, downloads newer content, verifies size and
     * SHA-256, imports it in one transaction and hands the bytes to [keep].
     */
    fun update(
        db: SqlDb,
        now: Instant,
        fetch: (String) -> ByteArray,
        keep: (ByteArray) -> Unit,
    ): Outcome {
        val checked = Settings.int(db, SettingKey.CONTENT_CHECKED_AT)
        if (checked != null && now.epochSecond - checked < CHECK_EVERY_SECONDS) return Outcome.Skipped

        val manifest = Json.decodeFromString(ContentManifest.serializer(), fetch(BASE_URL + "manifest.json").decodeToString())
        Settings.setInt(db, SettingKey.CONTENT_CHECKED_AT, now.epochSecond.toInt())
        val current = Settings.int(db, SettingKey.CONTENT_VERSION) ?: 0
        if (manifest.schema > SCHEMA || manifest.contentVersion <= current) return Outcome.UpToDate(current)

        // The version in the query keeps a cached older file from answering.
        val data = fetch(BASE_URL + "cards.json?v=" + manifest.contentVersion)
        if (data.size != manifest.size || sha256(data) != manifest.sha256) throw UpdateException("checksumMismatch")
        val text = data.decodeToString()
        if (version(text) != manifest.contentVersion) throw UpdateException("versionMismatch")

        ContentImporter.importIfNeeded(text, db)
        keep(data)
        return Outcome.Updated(manifest.contentVersion)
    }
}
