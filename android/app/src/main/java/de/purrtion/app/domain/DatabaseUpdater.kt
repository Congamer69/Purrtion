package de.purrtion.app.domain

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import de.purrtion.app.App
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.Request
import java.io.File

/**
 * Keeps the offline food databases up to date: the manifest in the project's GitHub repository (shared with iOS)
 * says which version of each database file is current; newer files are downloaded once, checked and then used
 * instead of the copy bundled with the app.
 */
object DatabaseUpdater {
    enum class Database(val title: String, val bundledVersion: String) {
        bls("Bundeslebensmittelschlüssel", "4.0"), swiss("Schweizer Nährwertdatenbank", "7.1"), restaurants("Restaurantketten", "2026.10");
        val bundledRevision: Int get() = 1
        /** A downloaded file must have at least this many foods to be accepted. */
        val minimumFoods: Int get() = if (this == restaurants) 100 else 500
    }

    private const val MANIFEST = "https://raw.githubusercontent.com/Congamer69/Purrtion/main/data/manifest.json"
    const val AUTO_KEY = "source.autoUpdate"
    private const val LAST_CHECK = "source.lastUpdateCheckMillis"

    var isChecking by mutableStateOf(false); private set
    var status by mutableStateOf<String?>(null); private set

    val lastCheck: Long? get() = App.prefs.double(LAST_CHECK, 0.0).toLong().takeIf { it > 0 }

    private val folder: File get() = File(App.context.filesDir, "Databases")

    fun version(db: Database): String = App.prefs.string("source.version.${db.name}", db.bundledVersion)
    private fun revision(db: Database): Int = App.prefs.int("source.revision.${db.name}", 0).takeIf { it > 0 } ?: db.bundledRevision

    /** Automatic check, at most once a week. */
    fun autoUpdateIfNeeded() {
        if (!App.prefs.bool(AUTO_KEY, true) || isChecking) return
        val last = lastCheck
        if (last != null && System.currentTimeMillis() - last < 7L * 24 * 3600 * 1000) return
        App.scope.launch { update(silent = true) }
    }

    suspend fun update(silent: Boolean = false) {
        if (isChecking) return
        isChecking = true
        if (!silent) status = "Suche nach Updates …"
        try {
            val manifest = Http.getJson(MANIFEST, mapOf("User-Agent" to "Purrtion", "Cache-Control" to "no-cache")) as? JsonObject
                ?: throw IllegalStateException()
            val dbs = manifest["databases"]?.jsonObject ?: throw IllegalStateException()
            val updated = mutableListOf<String>()
            for (db in Database.entries) {
                val entry = dbs[db.name]?.jsonObject ?: continue
                val rev = entry["revision"]?.jsonPrimitive?.intOrNull ?: continue
                if (rev <= revision(db)) continue
                if (!silent) status = "Lade ${db.title} …"
                install(db, entry)
                updated += "${db.title} ${entry["version"]?.jsonPrimitive?.contentOrNull ?: ""}"
            }
            App.prefs.set(LAST_CHECK, System.currentTimeMillis().toDouble())
            status = if (updated.isEmpty()) (if (silent) null else "Alles aktuell") else "Aktualisiert: " + updated.joinToString(", ")
        } catch (e: Exception) {
            if (!silent) status = "Aktualisierung fehlgeschlagen. Bitte später erneut versuchen."
        } finally {
            isChecking = false
        }
    }

    private suspend fun install(db: Database, entry: JsonObject) {
        val url = entry["url"]?.jsonPrimitive?.contentOrNull ?: throw IllegalStateException()
        val foods = entry["foods"]?.jsonPrimitive?.intOrNull ?: 0
        val (status, text) = Http.execute(Request.Builder().url(url).build())
        if (status != 200) throw IllegalStateException()
        withContext(Dispatchers.Default) {
            // Only accept a plausible, complete database file.
            val json = Json.parseToJsonElement(text).jsonObject
            val list = json["foods"] as? JsonArray ?: throw IllegalStateException()
            if (json["keys"] !is JsonArray || list.size < maxOf(db.minimumFoods, foods * 9 / 10)) throw IllegalStateException()
        }
        withContext(Dispatchers.IO) {
            folder.mkdirs()
            val tmp = File(folder, "${db.name}.json.tmp")
            tmp.writeText(text)
            tmp.renameTo(File(folder, "${db.name}.json"))
        }
        App.prefs.set("source.version.${db.name}", entry["version"]?.jsonPrimitive?.contentOrNull ?: db.bundledVersion)
        App.prefs.set("source.revision.${db.name}", entry["revision"]?.jsonPrimitive?.intOrNull ?: 1)
        when (db) {
            Database.bls -> BlsDatabase.reload()
            Database.swiss -> SwissDatabase.reload()
            Database.restaurants -> RestaurantDatabase.reload()
        }
    }
}
