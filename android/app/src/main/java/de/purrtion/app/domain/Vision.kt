package de.purrtion.app.domain

import android.graphics.Bitmap
import android.util.Base64
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import de.purrtion.app.App
import de.purrtion.app.data.newId
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.Nutrients
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import java.io.ByteArrayOutputStream
import java.net.URLEncoder
import kotlin.coroutines.resume
import kotlin.math.max
import kotlin.math.min

/** Which engine analyses meal photos. "Offline" uses ML Kit on the phone; the others use your own API key. */
enum class VisionProvider(val title: String, val shortName: String, val costNote: String, val defaultModel: String, val keyUrl: String?) {
    offline("Offline (ML Kit)", "Offline", "Kostenlos · auf dem Gerät · erkennt Lebensmittel, Mengen sind typische Portionen", "", null),
    gemini("Google Gemini", "Gemini", "Kostenloses Kontingent mit eigenem Schlüssel · Daten können im Gratis-Tarif zum Training genutzt werden",
        "gemini-3.8-flash", "https://aistudio.google.com/apikey"),
    claude("Claude (Anthropic)", "Claude", "Sehr genau · kostet pro Foto ein paar Cent", "claude-opus-5-5", "https://console.anthropic.com/settings/keys"),
    openai("OpenAI", "OpenAI", "Kostet pro Foto ca. 1 Cent oder weniger", "gpt-5.4-mini", "https://platform.openai.com/api-keys");

    val needsKey: Boolean get() = this != offline
    val secretKey: String get() = "apiKey.$name"
    /** Pasted keys often carry a stray space or line break – trim them. */
    val apiKey: String get() = Secrets.get(secretKey)?.trim() ?: ""

    val suggestedModels: List<String>
        get() = when (this) {
            offline -> emptyList()
            claude -> listOf("claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5")
            gemini -> listOf("gemini-3.8-flash")
            openai -> listOf("gpt-5.4-mini")
        }

    companion object {
        /** iOS backups store "apple" – that maps to the free on-device option here. */
        fun parse(raw: String?): VisionProvider? = when (raw) {
            null, "" -> null
            "apple" -> offline
            else -> entries.firstOrNull { it.name == raw }
        }
    }
}

/** What the AI is used for – each task can use its own provider and model. */
enum class AITask(val title: String) {
    photo("Foto-Erkennung"), day("Tagesanalyse");

    /** Photo keeps the original keys so settings from iOS backups stay valid. */
    val providerKey: String get() = if (this == photo) "vision.provider" else "vision.day.provider"
    fun modelKey(p: VisionProvider): String = if (this == photo) "vision.model.${p.name}" else "vision.day.model.${p.name}"

    /** The day analysis follows the photo provider until one is chosen explicitly. */
    var provider: VisionProvider
        get() = VisionProvider.parse(App.prefs.optString(providerKey)) ?: if (this == day) photo.provider else VisionProvider.offline
        set(v) = App.prefs.set(providerKey, v.name)

    val followsPhoto: Boolean get() = this == day && VisionProvider.parse(App.prefs.optString(providerKey)) == null

    fun model(p: VisionProvider): String {
        val own = App.prefs.string(modelKey(p), "").trim()
        if (own.isNotEmpty()) return own
        return if (this == day) photo.model(p) else p.defaultModel
    }

    val model: String get() = model(provider)
}

class VisionException(message: String) : Exception(message)

/** Recognises the components of a meal and asks the selected model for a nutrition estimate. */
object MealVision {
    data class Result(val dish: String, val items: List<Item>)
    data class Item(val name: String, val grams: Double, val confidence: String, val food: FoodItem, val isAIEstimate: Boolean)

    suspend fun analyze(image: Bitmap, hint: String?): Result {
        val provider = AITask.photo.provider
        if (provider != VisionProvider.offline) return CloudVision.analyze(provider, image, hint)
        return OfflineVision.analyze(image)
    }

    /** Same estimate from a description instead of a photo: "Käsespätzle vom Restaurant", "2 Eier und ein Toast". */
    suspend fun analyze(text: String): Result {
        val provider = AITask.photo.provider
        if (provider == VisionProvider.offline) {
            throw VisionException("Für Schätzungen aus Text brauchst du einen KI-Anbieter. Wähle unter Einstellungen → KI-Modelle Gemini, Claude oder OpenAI.")
        }
        return CloudVision.analyze(provider, text)
    }

    const val textPrompt = """Die Person beschreibt in eigenen Worten, was sie gegessen hat: ein einzelnes Lebensmittel, ein Gericht (z. B. aus dem Restaurant oder vom Imbiss) oder mehrere Dinge mit Mengenangaben.
Gibt es nur ein Lebensmittel oder ein typisches Gericht, liefere genau einen Eintrag für das ganze Gericht mit einer üblichen Portionsgröße (bzw. der genannten Menge) und den Nährwerten pro 100 g.
Werden mehrere Lebensmittel genannt, liefere je Lebensmittel einen Eintrag mit der genannten oder einer typischen Menge.
Nenne die Einträge mit kurzen deutschen Namen. Berücksichtige typische Zubereitung (Öl, Butter, Soße, Käse)."""

    const val prompt = """Du bist eine erfahrene Ernährungsberaterin und analysierst ein Foto einer Mahlzeit, oft im Restaurant.
Zerlege das Essen in seine einzelnen sichtbaren Bestandteile (inklusive Soßen, Dressing, Beilagen, Getränke) und schätze für jeden die Menge in Gramm (Getränke in ml) anhand von Tellergröße, Besteck und typischen Portionsgrößen. Denk an versteckte Komponenten wie Öl, Butter oder Panade. Restaurantportionen sind meist größer.
Benenne jeden Bestandteil mit einem einfachen deutschen Lebensmittelnamen wie in einer deutschen Nährwerttabelle (z. B. "Pommes frites", "Schwein Schnitzel paniert", "Eisbergsalat", "Remoulade", "Reis gekocht").
Schätze für jeden Bestandteil außerdem die Nährwerte pro 100 g. Die Werte werden direkt in ein Ernährungstagebuch übernommen: Kalorien sowie Protein, Kohlenhydrate und Fett müssen daher immer angegeben werden. Mikronährstoffe nur dann angeben, wenn sie für das konkrete Lebensmittel sinnvoll geschätzt werden können.
Wichtig: Schätze zuerst die gesamte essbare Mahlzeit und zerlege sie danach in sich nicht überschneidende Bestandteile. Die Summe aller ausgegebenen Gramm, Kalorien und Makronährstoffe muss zu deiner Schätzung für die gesamte Portion passen. Gib niemals zusätzlich das ganze Gericht und gleichzeitig dessen einzelne Zutaten aus; jede Zutat darf nur genau einmal vorkommen."""

    fun aiItem(name: String, grams: Double, confidence: String, per100: Nutrients, fruitVegShare: Double? = null): Item? {
        if (grams <= 0 || !grams.isFinite()) return null
        if (per100.kcal <= 0 && per100.protein + per100.carbs + per100.fat <= 0) return null
        val clean = name.trim()
        if (clean.isEmpty()) return null
        val food = FoodItem(id = "ai-${newId()}", name = clean, source = FoodSource.ai, per100 = per100.normalized(),
            unit = "g", origin = "KI-Schätzung · pro 100 g", fruitVegShare = fruitVegShare?.takeIf { it.isFinite() }?.coerceIn(0.0, 1.0))
        return Item(clean, min(grams, 3000.0), confidence, food, true)
    }
}

/** Cloud models with the user's own API key – meal photos and, text-only, closing a day. */
object CloudVision {
    val micronutrientHelp: String = NutrientKey.entries.joinToString(", ") { "${it.key} (${it.unit})" }

    val jsonInstruction = """Antworte ausschließlich mit JSON in genau diesem Format:
{"dish": "kurzer deutscher Name des Gerichts", "items": [{"name": "Lebensmittel", "grams": 150, "confidence": "hoch|mittel|niedrig", "fruit_veg_share": 0.0, "nutrients_per_100g": {"kcal": 180, "protein": 12, "carbs": 8, "fat": 9, "micronutrients": [{"key": "fiber", "value": 2}]}}]}
Alle Nährwerte gelten pro 100 g (bei Getränken pro 100 ml). `micronutrients` ist eine Liste aus key/value-Paaren und enthält nur Werte, die du plausibel schätzen kannst; die gültigen Schlüssel mit ihrer Einheit sind: $micronutrientHelp.
`fruit_veg_share` ist der Anteil des Gewichts (0 bis 1), der Obst, Gemüse, Pilze oder Hülsenfrüchte ist, frisch, gegart oder tiefgekühlt (Salat 1, Gemüsesuppe etwa 0,6, Pommes, Kartoffeln, Säfte, Trockenobst, Nüsse, Fleisch, Brot und Soßen 0). Gib ihn für jeden Bestandteil an.
Wenn kein Essen zu sehen ist, gib eine leere items-Liste zurück."""

    /** Micronutrients as key/value list: stays within the structured-output limits of all providers. */
    val micronutrientListSchema: JsonObject = buildJsonObject {
        put("type", "array")
        putJsonObject("items") {
            put("type", "object")
            putJsonObject("properties") {
                putJsonObject("key") { put("type", "string"); putJsonArray("enum") { NutrientKey.entries.forEach { add(JsonPrimitive(it.key)) } } }
                putJsonObject("value") { put("type", "number") }
            }
            putJsonArray("required") { add(JsonPrimitive("key")); add(JsonPrimitive("value")) }
            put("additionalProperties", false)
        }
    }

    private val nutritionSchema = buildJsonObject {
        put("type", "object")
        putJsonObject("properties") {
            for (k in listOf("kcal", "protein", "carbs", "fat")) putJsonObject(k) { put("type", "number") }
            put("micronutrients", micronutrientListSchema)
        }
        putJsonArray("required") { listOf("kcal", "protein", "carbs", "fat", "micronutrients").forEach { add(JsonPrimitive(it)) } }
        put("additionalProperties", false)
    }

    val schema: JsonObject = buildJsonObject {
        put("type", "object")
        putJsonObject("properties") {
            putJsonObject("dish") { put("type", "string") }
            putJsonObject("items") {
                put("type", "array")
                putJsonObject("items") {
                    put("type", "object")
                    putJsonObject("properties") {
                        putJsonObject("name") { put("type", "string") }
                        putJsonObject("grams") { put("type", "number") }
                        putJsonObject("fruit_veg_share") { put("type", "number") }
                        putJsonObject("confidence") { put("type", "string"); putJsonArray("enum") { listOf("hoch", "mittel", "niedrig").forEach { add(JsonPrimitive(it)) } } }
                        put("nutrients_per_100g", nutritionSchema)
                    }
                    putJsonArray("required") { listOf("name", "grams", "confidence", "fruit_veg_share", "nutrients_per_100g").forEach { add(JsonPrimitive(it)) } }
                    put("additionalProperties", false)
                }
            }
        }
        putJsonArray("required") { add(JsonPrimitive("dish")); add(JsonPrimitive("items")) }
        put("additionalProperties", false)
    }

    private fun jpegBase64(image: Bitmap): String {
        val scale = min(1.0, 1280.0 / max(image.width, image.height))
        val scaled = if (scale < 1) Bitmap.createScaledBitmap(image, (image.width * scale).toInt(), (image.height * scale).toInt(), true) else image
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 75, out)
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }

    suspend fun analyze(provider: VisionProvider, image: Bitmap, hint: String?): MealVision.Result {
        val b64 = withContext(Dispatchers.Default) { jpegBase64(image) }
        var text = MealVision.prompt + "\n" + jsonInstruction
        if (!hint.isNullOrBlank()) text += "\nZusatzinfo vom Nutzer: $hint"
        val raw = request(provider, AITask.photo.model, text, b64, schema)
        return parseResult(raw) ?: throw VisionException("Ich konnte auf dem Foto kein Essen erkennen.")
    }

    suspend fun analyze(provider: VisionProvider, text: String): MealVision.Result {
        val prompt = MealVision.textPrompt + "\n" + jsonInstruction + "\nBeschreibung: $text"
        val raw = request(provider, AITask.photo.model, prompt, null, schema)
        return parseResult(raw) ?: throw VisionException("Dazu konnte ich nichts schätzen.")
    }

    private fun parseResult(raw: String): MealVision.Result? {
        val json = decode(raw) ?: throw VisionException("Analyse fehlgeschlagen: Antwort nicht lesbar")
        val items = (json["items"] as? JsonArray)?.mapNotNull { el ->
            val o = el as? JsonObject ?: return@mapNotNull null
            val n = o["nutrients_per_100g"] as? JsonObject ?: return@mapNotNull null
            MealVision.aiItem(str(o["name"]) ?: "", Math.round(num(o["grams"]) ?: 0.0).toDouble(), str(o["confidence"]) ?: "mittel", nutrients(n), num(o["fruit_veg_share"]))
        } ?: emptyList()
        if (items.isEmpty()) return null
        return MealVision.Result(str(json["dish"]) ?: "Mahlzeit", items)
    }

    private fun nutrients(o: JsonObject): Nutrients {
        val extras = micros(o["micronutrients"]).filter { it.value > 0 }
        return Nutrients(max(0.0, num(o["kcal"]) ?: 0.0), max(0.0, num(o["protein"]) ?: 0.0),
            max(0.0, num(o["carbs"]) ?: 0.0), max(0.0, num(o["fat"]) ?: 0.0), extras)
    }

    /** Accepts a key/value list (structured output) or a plain object (JSON mode). */
    fun micros(e: JsonElement?): Map<String, Double> {
        val raw: Map<String, Double> = when (e) {
            is JsonArray -> e.mapNotNull { (it as? JsonObject)?.let { o -> str(o["key"])?.let { k -> num(o["value"])?.let { v -> k to v } } } }.toMap()
            is JsonObject -> e.mapNotNull { (k, v) -> num(v)?.let { k to it } }.toMap()
            else -> emptyMap()
        }
        return raw.filter { NutrientKey.byKey.containsKey(it.key) && it.value.isFinite() && it.value >= 0 }
    }

    fun str(e: JsonElement?): String? = (e as? JsonPrimitive)?.contentOrNull
    fun num(e: JsonElement?): Double? = (e as? JsonPrimitive)?.let { it.doubleOrNull ?: it.contentOrNull?.toDoubleOrNull() }

    /** Tolerates code fences or text around the JSON object. */
    fun decode(raw: String): JsonObject? {
        val start = raw.indexOf('{'); val end = raw.lastIndexOf('}')
        if (start < 0 || end <= start) return null
        return Http.parseObject(raw.substring(start, end + 1))
    }

    /** Sends one prompt (optionally with a JPEG) to the selected cloud provider and returns the raw JSON text. */
    suspend fun request(provider: VisionProvider, model: String, text: String, b64: String?, schema: JsonObject): String {
        val key = provider.apiKey
        if (key.isEmpty()) throw VisionException("Bitte hinterlege unter Einstellungen → KI-Modelle deinen ${provider.title}-Schlüssel.")
        return when (provider) {
            VisionProvider.claude -> claude(key, model, b64, text, schema)
            VisionProvider.gemini -> gemini(key, model, b64, text)
            VisionProvider.openai -> openai(key, model, b64, text)
            VisionProvider.offline -> throw VisionException("Kein KI-Anbieter gewählt.")
        }
    }

    private suspend fun post(url: String, headers: Map<String, String>, body: JsonObject): JsonObject {
        val (status, text) = try {
            Http.postJson(url, body, headers + ("content-type" to "application/json"))
        } catch (e: java.io.IOException) {
            throw VisionException("Keine Verbindung zum Server der KI. Prüf dein Internet und versuch es nochmal.")
        }
        val json = Http.parseObject(text) ?: JsonObject(emptyMap())
        if (status !in 200..299) {
            val msg = ((json["error"] as? JsonObject)?.get("message") as? JsonPrimitive)?.contentOrNull ?: text.take(200)
            throw VisionException("Analyse fehlgeschlagen: $status: $msg")
        }
        return json
    }

    private suspend fun claude(key: String, model: String, b64: String?, text: String, schema: JsonObject): String {
        val body = buildJsonObject {
            put("model", model)
            put("max_tokens", 16000)
            putJsonObject("output_config") {
                put("effort", "low")
                putJsonObject("format") { put("type", "json_schema"); put("schema", schema) }
            }
            if (model.startsWith("claude-opus") || model.startsWith("claude-fable")) put("fallbacks", "default")
            putJsonArray("messages") {
                addJsonObject {
                    put("role", "user")
                    putJsonArray("content") {
                        if (b64 != null) addJsonObject {
                            put("type", "image")
                            putJsonObject("source") { put("type", "base64"); put("media_type", "image/jpeg"); put("data", b64) }
                        }
                        addJsonObject { put("type", "text"); put("text", text) }
                    }
                }
            }
        }
        val headers = mutableMapOf("x-api-key" to key, "anthropic-version" to "2023-06-01")
        if (model.startsWith("claude-opus") || model.startsWith("claude-fable")) headers["anthropic-beta"] = "server-side-fallback-2026-07-01"
        val json = post("https://api.anthropic.com/v1/messages", headers, body)
        if (str(json["stop_reason"]) == "refusal") throw VisionException("Claude hat die Analyse abgelehnt.")
        return (json["content"] as? JsonArray)?.mapNotNull { b -> (b as? JsonObject)?.takeIf { str(it["type"]) == "text" }?.let { str(it["text"]) } }
            ?.joinToString("") ?: ""
    }

    private suspend fun gemini(key: String, model: String, b64: String?, text: String): String {
        val body = buildJsonObject {
            putJsonArray("contents") {
                addJsonObject {
                    put("role", "user")
                    putJsonArray("parts") {
                        if (b64 != null) addJsonObject { putJsonObject("inline_data") { put("mime_type", "image/jpeg"); put("data", b64) } }
                        addJsonObject { put("text", text) }
                    }
                }
            }
            putJsonObject("generationConfig") { put("responseMimeType", "application/json"); put("temperature", 0.2) }
        }
        val base = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent"
        val json = try {
            post(base, mapOf("x-goog-api-key" to key), body)
        } catch (e: VisionException) {
            // Some key types are only accepted as query parameter.
            if (e.message?.contains(": 401:") == true) post("$base?key=${URLEncoder.encode(key, "UTF-8")}", emptyMap(), body) else throw e
        }
        val parts = ((json["candidates"] as? JsonArray)?.firstOrNull()?.jsonObject?.get("content") as? JsonObject)?.get("parts") as? JsonArray
        return parts?.mapNotNull { str((it as? JsonObject)?.get("text")) }?.joinToString("") ?: ""
    }

    private suspend fun openai(key: String, model: String, b64: String?, text: String): String {
        val body = buildJsonObject {
            put("model", model)
            putJsonObject("response_format") { put("type", "json_object") }
            putJsonArray("messages") {
                addJsonObject {
                    put("role", "user")
                    putJsonArray("content") {
                        addJsonObject { put("type", "text"); put("text", text) }
                        if (b64 != null) addJsonObject { put("type", "image_url"); putJsonObject("image_url") { put("url", "data:image/jpeg;base64,$b64") } }
                    }
                }
            }
        }
        val json = post("https://api.openai.com/v1/chat/completions", mapOf("Authorization" to "Bearer $key"), body)
        val message = (json["choices"] as? JsonArray)?.firstOrNull()?.jsonObject?.get("message") as? JsonObject
        return str(message?.get("content")) ?: ""
    }
}

/** Free, fully offline fallback: ML Kit's image labeler + typical portion sizes, nutrients from the BLS. */
private object OfflineVision {
    /** ML Kit label → (German BLS search term, typical portion in g/ml). */
    private val foods: Map<String, Pair<String, Double>> = mapOf(
        "Bread" to ("Roggenmischbrot" to 90.0), "Pizza" to ("Pizza Margherita" to 350.0), "Hamburger" to ("Hamburger" to 220.0),
        "Hot dog" to ("Bratwurst" to 150.0), "Sandwich" to ("Sandwich" to 200.0), "Salad" to ("Gemischter Salat" to 200.0),
        "Soup" to ("Gemüsesuppe" to 300.0), "Pasta" to ("Teigwaren eifrei, gekocht" to 250.0), "Noodle" to ("Teigwaren eifrei, gekocht" to 250.0),
        "Rice" to ("Reis gekocht" to 200.0), "Sushi" to ("Sushi mit Lachs" to 200.0), "Cake" to ("Rührkuchen" to 100.0),
        "Cookie" to ("Kekse" to 30.0), "Dessert" to ("Pudding" to 150.0), "Ice cream" to ("Cremeeis" to 120.0), "Chocolate" to ("Vollmilchschokolade" to 25.0),
        "Fruit" to ("Apfel" to 150.0), "Apple" to ("Apfel" to 180.0), "Banana" to ("Banane" to 120.0), "Orange" to ("Orange" to 150.0),
        "Strawberry" to ("Erdbeeren" to 150.0), "Vegetable" to ("Gemischtes Gemüse" to 150.0), "Egg" to ("Ei gekocht" to 60.0),
        "Meat" to ("Schweineschnitzel" to 150.0), "Steak" to ("Rindersteak" to 200.0), "Chicken" to ("Hähnchenbrust" to 150.0),
        "Fish" to ("Lachs" to 150.0), "Seafood" to ("Garnele" to 120.0), "Cheese" to ("Gouda" to 40.0), "French fries" to ("Pommes frites" to 150.0),
        "Coffee" to ("Kaffee schwarz" to 200.0), "Tea" to ("Schwarztee" to 250.0), "Juice" to ("Orangensaft" to 250.0), "Wine" to ("Rotwein" to 200.0),
        "Beer" to ("Bier (Pils)" to 500.0), "Cola" to ("Cola" to 330.0), "Pancake" to ("Pfannkuchen" to 150.0), "Waffle" to ("Waffel" to 80.0),
        "Muffin" to ("Muffin" to 80.0), "Doughnut" to ("Berliner" to 70.0), "Croissant" to ("Croissant" to 60.0), "Taco" to ("Weizentortilla" to 80.0),
        "Burrito" to ("Burrito" to 300.0), "Curry" to ("Curry" to 350.0), "Tomato" to ("Tomate" to 120.0), "Potato" to ("Kartoffeln gekocht" to 200.0),
        "Corn" to ("Mais (Dose)" to 150.0), "Cucumber" to ("Gurke" to 100.0), "Carrot" to ("Karotte" to 80.0), "Broccoli" to ("Brokkoli" to 150.0),
        "Mushroom" to ("Champignons" to 100.0), "Yogurt" to ("Joghurt natur 3,5 %" to 150.0), "Milk" to ("Milch 1,5 %" to 200.0),
    )

    suspend fun analyze(image: Bitmap): MealVision.Result {
        val labeler = ImageLabeling.getClient(ImageLabelerOptions.Builder().setConfidenceThreshold(0.5f).build())
        val labels = suspendCancellableCoroutine { cont ->
            labeler.process(InputImage.fromBitmap(image, 0))
                .addOnSuccessListener { cont.resume(it) }
                .addOnFailureListener { cont.resume(emptyList()) }
        }
        val items = mutableListOf<MealVision.Item>()
        val seen = HashSet<String>()
        for (l in labels.sortedByDescending { it.confidence }) {
            val (term, grams) = foods[l.text] ?: continue
            if (!seen.add(term)) continue
            val food = withContext(Dispatchers.Default) { BlsDatabase.search(term, 6).firstOrNull() } ?: continue
            val confidence = if (l.confidence > 0.8) "hoch" else if (l.confidence > 0.6) "mittel" else "niedrig"
            items += MealVision.Item(food.name, grams, confidence, food, false)
            if (items.size == 4) break
        }
        if (items.isEmpty()) {
            throw VisionException("Offline konnte ich auf dem Foto kein Essen erkennen. Mit Gemini, Claude oder OpenAI (Einstellungen → KI-Modelle) klappt es deutlich besser.")
        }
        return MealVision.Result(items.joinToString(", ") { it.name }, items)
    }
}
