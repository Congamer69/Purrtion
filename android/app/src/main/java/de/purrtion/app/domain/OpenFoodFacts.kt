package de.purrtion.app.domain

import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.ServingOption
import de.purrtion.app.model.clean
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import java.net.URLEncoder
import java.util.UUID
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max

/** Open Food Facts – the largest open product database (barcodes, brands, serving sizes, micronutrients). */
object OpenFoodFacts {
    private const val USER_AGENT = "Purrtion/1.0 (Android; calorie tracker)"
    private const val FIELDS = "code,product_name,product_name_de,generic_name_de,brands,nutriments,serving_size,serving_quantity,product_quantity,quantity,image_front_small_url,nutrition_data_per"
    private val headers = mapOf("User-Agent" to USER_AGENT)

    private fun enc(s: String) = URLEncoder.encode(s, "UTF-8")

    suspend fun product(barcode: String): FoodItem? {
        val code = barcode.trim()
        val json = Http.getJson("https://world.openfoodfacts.org/api/v2/product/$code.json?fields=$FIELDS&lc=de", headers) as? JsonObject ?: return null
        if ((json["status"] as? JsonPrimitive)?.intOrNull != 1) return null
        val p = json["product"] as? JsonObject ?: return null
        val food = parse(p, code) ?: return null
        return food.copy(warning = plausibilityWarning(food.per100))
    }

    /** Searches products sold in Germany first (falls back to worldwide), then re-ranks by relevance,
     *  popularity (scan count), completeness and data plausibility. */
    suspend fun search(query: String): List<FoodItem> = coroutineScope {
        val german = async { hits("$query countries_tags:\"en:germany\"") }
        val world = async { runCatching { hits(query) }.getOrDefault(emptyList()) }
        var all = german.await()
        if (all.size < 10) all = all + world.await() else world.cancel()

        val seen = HashSet<String>()
        val ranked = ArrayList<Pair<FoodItem, Double>>()
        for ((index, hit) in all.withIndex()) {
            val parsed = parse(hit, null) ?: continue
            val key = "${parsed.name.lowercase()}|${(parsed.brand ?: "").lowercase()}"
            if (!seen.add(parsed.id) || !seen.add(key)) continue
            val food = parsed.copy(warning = plausibilityWarning(parsed.per100))
            val scans = number(hit["unique_scans_n"]) ?: 0.0
            val completeness = number(hit["completeness"]) ?: 0.5
            val germanHit = (hit["countries_tags"] as? JsonArray)?.any { (it as? JsonPrimitive)?.contentOrNull == "en:germany" } ?: false
            var score = -index * 2.0 + ln(scans + 1) / ln(2.0) * 3 + completeness * 8 + if (germanHit) 15 else 0
            if (food.warning != null) score -= 40
            ranked += food to score
        }
        ranked.sortedByDescending { it.second }.map { it.first }
    }

    private suspend fun hits(q: String): List<JsonObject> {
        val url = "https://search.openfoodfacts.org/search?q=${enc(q)}&page_size=40&langs=de,en&fields=${enc("$FIELDS,unique_scans_n,completeness,countries_tags")}"
        val json = Http.getJson(url, headers) as? JsonObject ?: return emptyList()
        return (json["hits"] as? JsonArray)?.mapNotNull { it as? JsonObject } ?: emptyList()
    }

    /** Crowd-sourced data can be wrong – flag values that don't add up. */
    fun plausibilityWarning(n: Nutrients): String? {
        val macros = n.protein + n.carbs + n.fat
        if (n.kcal <= 0 && macros <= 0) return "Keine Nährwerte hinterlegt"
        if (macros > 102 || n.kcal > 920) return "Werte unplausibel"
        val computed = n.protein * 4 + n.carbs * 4 + n.fat * 9 + (n[NutrientKey.fiber] ?: 0.0) * 2 + (n[NutrientKey.alcohol] ?: 0.0) * 7
        if (n.kcal > 0 && computed > 0 && abs(computed - n.kcal) > max(35.0, n.kcal * 0.25)) return "Kalorien passen nicht zu den Makros"
        return null
    }

    /** OFF stores micronutrients in grams; convert to the unit of our catalog. */
    private val nutrientMap: List<Triple<String, NutrientKey, Double>> = listOf(
        Triple("sugars", NutrientKey.sugar, 1.0), Triple("fiber", NutrientKey.fiber, 1.0), Triple("saturated-fat", NutrientKey.saturatedFat, 1.0),
        Triple("monounsaturated-fat", NutrientKey.monoFat, 1.0), Triple("polyunsaturated-fat", NutrientKey.polyFat, 1.0),
        Triple("omega-3-fat", NutrientKey.omega3, 1.0), Triple("trans-fat", NutrientKey.transFat, 1.0),
        Triple("cholesterol", NutrientKey.cholesterol, 1000.0), Triple("salt", NutrientKey.salt, 1.0), Triple("sodium", NutrientKey.sodium, 1000.0),
        Triple("potassium", NutrientKey.potassium, 1000.0), Triple("calcium", NutrientKey.calcium, 1000.0), Triple("magnesium", NutrientKey.magnesium, 1000.0),
        Triple("iron", NutrientKey.iron, 1000.0), Triple("zinc", NutrientKey.zinc, 1000.0), Triple("phosphorus", NutrientKey.phosphorus, 1000.0),
        Triple("iodine", NutrientKey.iodine, 1_000_000.0), Triple("selenium", NutrientKey.selenium, 1_000_000.0),
        Triple("copper", NutrientKey.copper, 1000.0), Triple("manganese", NutrientKey.manganese, 1000.0), Triple("pantothenic-acid", NutrientKey.vitaminB5, 1000.0),
        Triple("biotin", NutrientKey.biotin, 1_000_000.0),
        Triple("vitamin-a", NutrientKey.vitaminA, 1_000_000.0), Triple("vitamin-c", NutrientKey.vitaminC, 1000.0), Triple("vitamin-d", NutrientKey.vitaminD, 1_000_000.0),
        Triple("vitamin-e", NutrientKey.vitaminE, 1000.0), Triple("vitamin-k", NutrientKey.vitaminK, 1_000_000.0), Triple("vitamin-b1", NutrientKey.vitaminB1, 1000.0),
        Triple("vitamin-b2", NutrientKey.vitaminB2, 1000.0), Triple("vitamin-pp", NutrientKey.vitaminB3, 1000.0), Triple("vitamin-b6", NutrientKey.vitaminB6, 1000.0),
        Triple("vitamin-b12", NutrientKey.vitaminB12, 1_000_000.0), Triple("vitamin-b9", NutrientKey.folate, 1_000_000.0), Triple("folates", NutrientKey.folate, 1_000_000.0),
        Triple("caffeine", NutrientKey.caffeine, 1000.0), Triple("alcohol", NutrientKey.alcohol, 0.789), // alcohol is % vol -> g per 100 ml
    )

    fun parse(p: JsonObject, fallbackCode: String?): FoodItem? {
        val code = str(p["code"]) ?: fallbackCode ?: UUID.randomUUID().toString()
        val name = listOf(p["product_name_de"], p["product_name"], p["generic_name_de"])
            .mapNotNull { str(it)?.trim() }.firstOrNull { it.isNotEmpty() } ?: return null
        val brand = when (val b = p["brands"]) {
            is JsonPrimitive -> b.contentOrNull?.split(",")?.firstOrNull()?.trim()
            is JsonArray -> str(b.firstOrNull())?.trim()
            else -> null
        }?.takeIf { it.isNotEmpty() }

        val nm = (p["nutriments"] as? JsonObject) ?: JsonObject(emptyMap())
        fun value(key: String) = number(nm["${key}_100g"])

        var n = Nutrients(
            kcal = value("energy-kcal") ?: value("energy")?.let { it / 4.184 } ?: 0.0,
            protein = value("proteins") ?: 0.0,
            carbs = value("carbohydrates") ?: 0.0,
            fat = value("fat") ?: 0.0,
        )
        for ((key, target, factor) in nutrientMap) {
            val v = value(key)
            if (v != null && v >= 0 && n[target] == null) n = n.with(target, v * factor)
        }
        if ((n[NutrientKey.alcohol] ?: 0.0) == 0.0) n = n.with(NutrientKey.alcohol, null)
        n = n.normalized()

        val quantityString = str(p["quantity"])?.lowercase() ?: ""
        val servingString = str(p["serving_size"])?.lowercase() ?: ""
        val isLiquid = quantityString.contains("ml") || quantityString.contains(" l") || quantityString.endsWith("l") || servingString.contains("ml")
        val unit = if (isLiquid) "ml" else "g"

        val servings = mutableListOf<ServingOption>()
        number(p["serving_quantity"])?.takeIf { it > 0 }?.let { sq ->
            val label = str(p["serving_size"])?.let(::cleanServing) ?: "Portion"
            servings += ServingOption(label.ifEmpty { "Portion" }, sq)
        }
        number(p["product_quantity"])?.takeIf { it > 0 && it < 5000 }?.let { pq ->
            servings += ServingOption("Packung (${pq.clean} $unit)", pq)
        }
        if (n.kcal <= 0 && n.protein + n.carbs + n.fat <= 0) return null
        return FoodItem(id = "off-$code", name = name, brand = brand, source = FoodSource.openFoodFacts, barcode = code,
            imageURL = str(p["image_front_small_url"]), per100 = n, unit = unit, servings = servings)
    }

    private fun cleanServing(s: String): String {
        // "1 Cube (6.52 g)" -> "1 Cube"; the gram weight is shown separately.
        val t = s.replace(Regex("\\s*\\([^)]*\\d[^)]*\\)"), "").trim()
        if (t.isEmpty() || Regex("^[\\d.,]+\\s*(g|ml)$", RegexOption.IGNORE_CASE).matches(t)) return "Portion"
        return if (t.length > 28) t.take(28) + "…" else t
    }

    private fun str(e: JsonElement?): String? = (e as? JsonPrimitive)?.contentOrNull

    fun number(e: JsonElement?): Double? {
        val p = e as? JsonPrimitive ?: return null
        return p.doubleOrNull ?: p.contentOrNull?.replace(",", ".")?.toDoubleOrNull()
    }
}
