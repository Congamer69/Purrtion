package de.purrtion.app.domain

import de.purrtion.app.BuildConfig
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
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

/** Firebase config of the friends page – taken from the (gitignored) iOS Firebase.plist at build time. */
object FirebaseConfig {
    val apiKey: String = BuildConfig.FIREBASE_API_KEY
    val projectId: String = BuildConfig.FIREBASE_PROJECT_ID
    val inviteUrl: String = BuildConfig.FIREBASE_INVITE_URL
    val isAvailable: Boolean get() = apiKey.isNotEmpty() && !apiKey.startsWith("<") && projectId.isNotEmpty()
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
