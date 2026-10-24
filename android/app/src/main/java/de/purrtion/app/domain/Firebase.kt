package de.purrtion.app.domain

import de.purrtion.app.App
import de.purrtion.app.BuildConfig
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import java.net.URLEncoder
import java.time.Instant

/**
 * Server of the friends page. Comes from a pasted server code (Einstellungen → Freunde) or, in older or private
 * builds, from the Firebase.plist built into the app. A built-in config is copied to the settings on first start, so it
 * survives updates to APKs without one (the public APKs on GitHub carry no server data).
 */
object FirebaseConfig {
    private const val KEY = "friends.server"
    private const val PREFIX = "purrtion-server:"
    /** Stored after "Freunde-Server trennen", so a built-in config does not reconnect by itself. */
    private const val OFF = "off"

    @kotlinx.serialization.Serializable
    data class Server(val k: String, val p: String, val i: String = "") {
        val isValid: Boolean get() = k.length > 20 && !k.startsWith("<") && p.isNotBlank()
    }

    private val bundled: Server? = Server(BuildConfig.FIREBASE_API_KEY, BuildConfig.FIREBASE_PROJECT_ID, BuildConfig.FIREBASE_INVITE_URL)
        .takeIf { it.isValid }

    private val raw: String? get() = App.prefs.optString(KEY)
    private val stored: Server? get() = raw?.let(::decode)

    /** Keeps a built-in config for later versions without one. Called on every start (cheap). */
    fun persistBundled() {
        if (raw == null && bundled != null) App.prefs.set(KEY, encode(bundled))
    }

    val server: Server? get() = if (raw == OFF) null else stored ?: bundled
    val apiKey: String get() = server?.k ?: ""
    val projectId: String get() = server?.p ?: ""
    val inviteUrl: String get() = server?.i ?: ""
    val isAvailable: Boolean get() = server?.isValid == true

    /** The code to share with friends ("purrtion-server:…"), null when not connected. */
    val code: String? get() = server?.let(::encode)

    fun encode(s: Server): String = PREFIX + android.util.Base64.encodeToString(
        de.purrtion.app.model.AppJson.encodeToString(Server.serializer(), s).toByteArray(),
        android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING)

    /** Reads a pasted code; whitespace, line breaks and quotes from chats are ignored. */
    fun decode(raw: String): Server? = runCatching {
        val t = raw.trim().trim('"', '\'', '„', '“').filterNot { it.isWhitespace() }
        val body = if (t.startsWith(PREFIX)) t.removePrefix(PREFIX) else return null
        val json = String(android.util.Base64.decode(body, android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP))
        de.purrtion.app.model.AppJson.decodeFromString(Server.serializer(), json).takeIf { it.isValid }
    }.getOrNull()

    /** Saves a pasted code; false when it is not a valid server code. */
    fun connect(raw: String): Boolean {
        val s = decode(raw) ?: return false
        App.prefs.set(KEY, encode(s))
        return true
    }

    /**
     * Asks the server whether a pasted code works, before saving it. Null when it does, otherwise what is wrong.
     * Creates nothing on the server: Firebase Auth names the domains of the key's project (so key and project must
     * belong together), and Firestore answers whether the project has a database.
     */
    suspend fun verify(raw: String): String? {
        val s = decode(raw) ?: return "Das ist kein gültiger Server-Code. Er beginnt mit „purrtion-server:“."
        fun json(text: String) = runCatching { kotlinx.serialization.json.Json.parseToJsonElement(text) as? JsonObject }.getOrNull()
        return try {
            val (status, authText) = Http.request("https://identitytoolkit.googleapis.com/v1/projects?key=${s.k}", "GET")
            if (status != 200) return "Der Server-Code stimmt nicht. Der Schlüssel wird vom Server abgelehnt."
            val domains = (json(authText)?.get("authorizedDomains") as? JsonArray)?.mapNotNull { it.jsonPrimitive.contentOrNull } ?: emptyList()
            if (domains.none { it.startsWith(s.p + ".") }) return "Der Server-Code stimmt nicht. Schlüssel und Projekt passen nicht zusammen."
            val (_, storeText) = Http.request("https://firestore.googleapis.com/v1/projects/${s.p}/databases/(default)/documents/codes/AAAAAAAA?key=${s.k}", "GET")
            val message = ((json(storeText)?.get("error") as? JsonObject)?.get("message"))?.jsonPrimitive?.contentOrNull ?: ""
            if ("resource project" in message || "does not exist" in message) "Der Server-Code stimmt nicht. Zu diesem Projekt gibt es keinen Freunde-Server."
            else null
        } catch (e: java.io.IOException) {
            "Keine Verbindung. Prüf dein Internet und versuch es nochmal."
        }
    }

    /** Forgets the server (also a built-in one) until a new code is pasted. */
    fun disconnect() = App.prefs.set(KEY, OFF)
}

class FirebaseException(message: String) : Exception(message) {
    companion object {
        val notConfigured = FirebaseException("Die Freunde-Funktion ist in diesem Build nicht eingerichtet.")
        val offline = FirebaseException("Keine Verbindung. Versuch es gleich nochmal.")
        val notFound = FirebaseException("Nicht gefunden.")
        val conflict = FirebaseException("Existiert schon.")
        val denied = FirebaseException("Keine Berechtigung.")
    }
}

/** Anonymous account: refresh token + uid encrypted on the device, ID token in memory. */
object FirebaseAuth {
    private var idToken: String? = null
    private var expires = 0L
    private val mutex = Mutex()

    val uid: String? get() = Secrets.get("fb.uid")
    val hasAccount: Boolean get() = uid != null && Secrets.get("fb.refresh") != null

    suspend fun token(): String { mutex.withLock {
        idToken?.let { if (expires > System.currentTimeMillis() + 60_000) return it }
        if (!FirebaseConfig.isAvailable) throw FirebaseException.notConfigured
        val key = FirebaseConfig.apiKey
        Secrets.get("fb.refresh")?.let { refresh ->
            val (status, body) = send {
                Http.request("https://securetoken.googleapis.com/v1/token?key=$key", "POST",
                    "grant_type=refresh_token&refresh_token=${URLEncoder.encode(refresh, "UTF-8")}", "application/x-www-form-urlencoded")
            }
            val json = Http.parseObject(body)
            val t = json?.str("id_token")
            if (status in 200..299 && t != null) {
                store(t, json.str("refresh_token"), json.str("user_id"), json.str("expires_in"))
                return t
            }
        }
        val (status, body) = send {
            Http.request("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$key", "POST", "{\"returnSecureToken\":true}")
        }
        val json = Http.parseObject(body)
        val t = json?.str("idToken")
        if (status !in 200..299 || t == null) throw FirebaseException("Serverfehler: Anmeldung fehlgeschlagen")
        store(t, json.str("refreshToken"), json.str("localId"), json.str("expiresIn"))
        return t
    } }

    private fun store(token: String, refresh: String?, uid: String?, expiresIn: String?) {
        idToken = token
        expires = System.currentTimeMillis() + (expiresIn?.toLongOrNull() ?: 3600) * 1000
        refresh?.let { Secrets.set("fb.refresh", it) }
        uid?.let { Secrets.set("fb.uid", it) }
    }

    /** Deletes the anonymous account itself (before signing out). */
    suspend fun deleteAccount() {
        val t = runCatching { token() }.getOrNull() ?: return
        runCatching {
            Http.request("https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${FirebaseConfig.apiKey}", "POST",
                buildJsonObject { put("idToken", t) }.toString())
        }
    }

    /** Takes over an account from a backup: the next request refreshes its token. */
    fun adopt(uid: String, refresh: String) {
        idToken = null; expires = 0
        Secrets.set("fb.uid", uid); Secrets.set("fb.refresh", refresh)
    }

    fun signOut() {
        idToken = null; expires = 0
        Secrets.set("fb.refresh", null); Secrets.set("fb.uid", null)
    }
}

internal suspend fun send(block: suspend () -> Pair<Int, String>): Pair<Int, String> =
    try { block() } catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (e: Exception) { throw FirebaseException.offline }

internal fun JsonObject.str(key: String): String? = (this[key] as? JsonPrimitive)?.contentOrNull

/** Firestore REST calls with plain Kotlin values (String, Double, Int, Boolean, Instant, lists, maps). */
object FirebaseREST {
    private val base: String get() = "https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents"

    private suspend fun request(path: String, method: String, body: JsonElement? = null): JsonElement {
        val token = FirebaseAuth.token()
        val (status, text) = send {
            Http.request(base + path, method, body?.toString(), headers = mapOf("Authorization" to "Bearer $token"))
        }
        val json = runCatching { kotlinx.serialization.json.Json.parseToJsonElement(text) }.getOrDefault(JsonObject(emptyMap()))
        when (status) {
            in 200..299 -> return json
            404 -> throw FirebaseException.notFound
            409 -> throw FirebaseException.conflict
            401, 403 -> throw FirebaseException.denied
            else -> {
                val msg = ((json as? JsonObject)?.get("error") as? JsonObject)?.str("message") ?: "HTTP $status"
                throw FirebaseException("Serverfehler: $msg")
            }
        }
    }

    suspend fun get(path: String): Map<String, Any?> {
        val doc = request("/$path", "GET") as? JsonObject ?: return emptyMap()
        return decodeFields(doc["fields"] as? JsonObject)
    }

    /** Replaces the whole document (creates it if missing). */
    suspend fun set(path: String, fields: Map<String, Any?>) {
        request("/$path", "PATCH", buildJsonObject { put("fields", encodeFields(fields)) })
    }

    /** Creates a document with a fixed id; throws conflict when it exists. */
    suspend fun create(collection: String, id: String, fields: Map<String, Any?>) {
        request("/$collection?documentId=$id", "POST", buildJsonObject { put("fields", encodeFields(fields)) })
    }

    suspend fun delete(path: String) { request("/$path", "DELETE") }

    /** All documents of [collection] whose array [field] contains [value] – one request for any number of documents. */
    suspend fun query(collection: String, field: String, contains: String, limit: Int = 100): List<Pair<String, Map<String, Any?>>> {
        val body = buildJsonObject {
            putJsonObject("structuredQuery") {
                putJsonArray("from") { add(buildJsonObject { put("collectionId", collection) }) }
                putJsonObject("where") {
                    putJsonObject("fieldFilter") {
                        putJsonObject("field") { put("fieldPath", field) }
                        put("op", "ARRAY_CONTAINS")
                        putJsonObject("value") { put("stringValue", contains) }
                    }
                }
                put("limit", limit)
            }
        }
        val rows = request(":runQuery", "POST", body) as? JsonArray ?: return emptyList()
        return rows.mapNotNull { row ->
            val doc = (row as? JsonObject)?.get("document") as? JsonObject ?: return@mapNotNull null
            val name = doc.str("name") ?: return@mapNotNull null
            name.substringAfterLast('/') to decodeFields(doc["fields"] as? JsonObject)
        }
    }

    // MARK: Value conversion

    fun encodeFields(map: Map<String, Any?>): JsonObject = JsonObject(map.mapValues { encode(it.value) })

    fun encode(v: Any?): JsonObject = when (v) {
        null -> buildJsonObject { put("nullValue", JsonNull) }
        is String -> buildJsonObject { put("stringValue", v) }
        is Boolean -> buildJsonObject { put("booleanValue", v) }
        is Int -> buildJsonObject { put("integerValue", v.toString()) }
        is Long -> buildJsonObject { put("integerValue", v.toString()) }
        is Double -> if (v.isFinite()) buildJsonObject { put("doubleValue", v) } else buildJsonObject { put("nullValue", JsonNull) }
        is Instant -> buildJsonObject { put("timestampValue", v.toString()) }
        is List<*> -> buildJsonObject { putJsonObject("arrayValue") { put("values", buildJsonArray { v.forEach { add(encode(it)) } }) } }
        is Map<*, *> -> buildJsonObject {
            putJsonObject("mapValue") { put("fields", JsonObject(v.entries.associate { it.key.toString() to encode(it.value) })) }
        }
        else -> buildJsonObject { put("nullValue", JsonNull) }
    }

    fun decodeFields(fields: JsonObject?): Map<String, Any?> =
        fields?.mapValues { decode(it.value as? JsonObject) }?.filterValues { it != null } ?: emptyMap()

    fun decode(v: JsonObject?): Any? {
        if (v == null) return null
        v.str("stringValue")?.let { return it }
        (v["booleanValue"] as? JsonPrimitive)?.booleanOrNull?.let { return it }
        v.str("integerValue")?.let { return it.toDoubleOrNull() }
        (v["doubleValue"] as? JsonPrimitive)?.doubleOrNull?.let { return it }
        v.str("timestampValue")?.let { return runCatching { Instant.parse(it) }.getOrNull() }
        (v["arrayValue"] as? JsonObject)?.let { a -> return (a["values"] as? JsonArray)?.mapNotNull { decode(it as? JsonObject) } ?: emptyList<Any>() }
        (v["mapValue"] as? JsonObject)?.let { m -> return decodeFields(m["fields"] as? JsonObject) }
        return null
    }
}
