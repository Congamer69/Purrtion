package de.purrtion.app.domain

import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class HttpException(val status: Int, val body: String) : IOException("HTTP $status")

/** Small coroutine wrapper around OkHttp. */
object Http {
    /**
     * System DNS first. When it cannot resolve a name ("Unable to resolve host", seen with some emulators, VPNs and private
     * DNS setups although other apps work), the name is asked from Cloudflare over HTTPS by IP address and cached.
     */
    private object FallbackDns : okhttp3.Dns {
        private val cache = java.util.concurrent.ConcurrentHashMap<String, Pair<Long, List<java.net.InetAddress>>>()
        private val bootstrap = OkHttpClient.Builder().connectTimeout(6, TimeUnit.SECONDS).readTimeout(6, TimeUnit.SECONDS).build()

        override fun lookup(hostname: String): List<java.net.InetAddress> {
            try { return okhttp3.Dns.SYSTEM.lookup(hostname) } catch (e: java.net.UnknownHostException) {
                cache[hostname]?.let { (at, list) -> if (System.currentTimeMillis() - at < 10 * 60_000) return list }
                val list = runCatching { overHttps(hostname) }.getOrDefault(emptyList())
                if (list.isEmpty()) throw e
                cache[hostname] = System.currentTimeMillis() to list
                return list
            }
        }

        private fun overHttps(host: String): List<java.net.InetAddress> {
            val req = Request.Builder().url("https://1.1.1.1/dns-query?name=$host&type=A").header("accept", "application/dns-json").build()
            val text = bootstrap.newCall(req).execute().use { it.body?.string() ?: "" }
            val answers = (Json.parseToJsonElement(text) as? JsonObject)?.get("Answer") as? kotlinx.serialization.json.JsonArray ?: return emptyList()
            return answers.mapNotNull { a ->
                val o = a as? JsonObject ?: return@mapNotNull null
                if ((o["type"] as? kotlinx.serialization.json.JsonPrimitive)?.content != "1") return@mapNotNull null
                val ip = (o["data"] as? kotlinx.serialization.json.JsonPrimitive)?.content ?: return@mapNotNull null
                // The literal address is parsed without another lookup; the host name is kept for TLS.
                runCatching { java.net.InetAddress.getByAddress(host, java.net.InetAddress.getByName(ip).address) }.getOrNull()
            }
        }
    }

    val client: OkHttpClient = OkHttpClient.Builder()
        .dns(FallbackDns)
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    private val jsonType = "application/json; charset=utf-8".toMediaType()

    suspend fun execute(request: Request): Pair<Int, String> = suspendCancellableCoroutine { cont ->
        val call = client.newCall(request)
        cont.invokeOnCancellation { call.cancel() }
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) { if (cont.isActive) cont.resumeWithException(e) }
            override fun onResponse(call: Call, response: Response) {
                response.use { cont.resume(it.code to (it.body?.string() ?: "")) }
            }
        })
    }

    suspend fun getJson(url: String, headers: Map<String, String> = emptyMap()): JsonElement? {
        val b = Request.Builder().url(url)
        headers.forEach { (k, v) -> b.header(k, v) }
        val (status, body) = execute(b.build())
        if (status == 404) return null
        if (status !in 200..299) throw HttpException(status, body)
        return runCatching { Json.parseToJsonElement(body) }.getOrNull()
    }

    suspend fun postJson(url: String, body: JsonElement, headers: Map<String, String> = emptyMap(), method: String = "POST"): Pair<Int, String> {
        val b = Request.Builder().url(url).method(method, body.toString().toRequestBody(jsonType))
        headers.forEach { (k, v) -> b.header(k, v) }
        return execute(b.build())
    }

    suspend fun request(url: String, method: String, body: String? = null, contentType: String = "application/json",
                        headers: Map<String, String> = emptyMap()): Pair<Int, String> {
        val rb = body?.toRequestBody(contentType.toMediaType())
        val b = Request.Builder().url(url).method(method, rb ?: if (method == "POST" || method == "PATCH") "".toRequestBody(jsonType) else null)
        headers.forEach { (k, v) -> b.header(k, v) }
        return execute(b.build())
    }

    fun parseObject(text: String): JsonObject? = runCatching { Json.parseToJsonElement(text) as? JsonObject }.getOrNull()
}
