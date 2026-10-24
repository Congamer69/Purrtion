package de.purrtion.app.domain

import de.purrtion.app.App
import de.purrtion.app.data.DayReview
import de.purrtion.app.data.FoodEntry
import de.purrtion.app.data.JsonCache
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.clean
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import java.time.LocalDate

/**
 * "Tag abschließen": the AI fills in missing micronutrients for every logged food and then writes a short verdict
 * on the day. Uses the provider chosen for the day analysis. Same flow and prompts as on iOS.
 */
object DayCloser {
    private const val COMPLETE_THRESHOLD = 10

    fun needsMicros(food: FoodItem): Boolean {
        if (food.microsEstimated == true) return false
        return HealthScore.microKeys.count { food.per100[it] != null } < COMPLETE_THRESHOLD
    }

    /** Foods the databases cannot classify get an AI estimate of their fruit and vegetable share. */
    fun needsFruitVeg(food: FoodItem): Boolean = food.fruitVegShare == null && !HealthScore.isClassifiedByDatabase(food)

    private fun needsEstimate(food: FoodItem) = needsMicros(food) || needsFruitVeg(food)

    /** What the AI returned for one food: micronutrients per 100 g and the fruit and vegetable share. */
    private data class Estimate(val micros: Map<String, Double>?, val share: Double?)

    suspend fun close(day: LocalDate, goals: Goals, automatic: Boolean = false): DayReview {
        var entries = App.db.entries().day(day.toEpochDay())
        if (entries.isEmpty()) throw VisionException("Für diesen Tag gibt es noch keine Einträge.")
        val provider = AITask.day.provider
        if (provider == VisionProvider.offline) {
            throw VisionException("Für „Tag abschließen“ brauchst du einen KI-Anbieter. Wähle unter Einstellungen → KI-Modelle → Tagesanalyse Gemini, Claude oder OpenAI.")
        }

        // 1) Fill in missing micronutrients and estimate the fruit and vegetable share of foods without a database category.
        val missing = LinkedHashMap<String, FoodItem>()
        for (e in entries) {
            if (e.isComposite) e.ingredients.filter { needsEstimate(it.food) }.forEach { missing[it.food.id] = it.food }
            else e.food?.takeIf(::needsEstimate)?.let { missing[it.id] = it }
        }
        if (missing.isNotEmpty()) {
            val estimates = estimate(missing.values.toList(), provider)
            entries = entries.map { apply(estimates, it) }
            App.db.entries().upsertAll(entries)
        }

        // 2) Verdict, based on the now complete numbers.
        val target = goals.target(day)
        val score = HealthScore.of(entries, target.kcal, target.protein)
        val before = HealthScore.of(entries, target.kcal, target.protein, withoutAI = true)
        val verdict = judge(entries, score, target, provider)

        val review = DayReview(
            day = day.toEpochDay(), rating = verdict.rating, tone = verdict.tone, pointsJson = JsonCache.encodeStrings(verdict.points),
            signature = DayReview.signature(entries), enrichedCount = estimatedFoodCount(entries),
            providerName = "${provider.title} (${AITask.day.model(provider)})", score = score.score, scoreBefore = before.score,
            automatic = automatic,
        )
        App.db.reviews().put(review)
        WidgetBridge.update()
        return review
    }

    // MARK: Applying estimates

    /** Adds only values that are still missing – label and database values always win. */
    private fun merge(food: FoodItem, estimate: Estimate?): FoodItem? {
        if (estimate == null) return null
        var result = food
        val micros = estimate.micros
        if (micros != null && needsMicros(food)) {
            val added = (food.aiNutrientKeys ?: emptyList()).toMutableSet()
            val extra = food.per100.extra.toMutableMap()
            for ((k, v) in micros) if (extra[k] == null && v.isFinite() && v >= 0) { extra[k] = v; added += k }
            val before = extra.keys.toSet()
            val normalized = food.per100.copy(extra = extra).normalized()
            added += normalized.extra.keys - before
            result = result.copy(per100 = normalized, aiNutrientKeys = added.sorted(), microsEstimated = true)
        }
        val share = estimate.share
        if (share != null && needsFruitVeg(food)) result = result.copy(fruitVegShare = share)
        return result.takeIf { it != food }
    }

    private fun apply(estimates: Map<String, Estimate>, entry: FoodEntry): FoodEntry {
        if (entry.isComposite) {
            var changed = false
            var microsChanged = false
            val list = entry.ingredients.map { ing ->
                val f = merge(ing.food, estimates[ing.food.id]) ?: return@map ing
                changed = true
                if (f.microsEstimated == true && ing.food.microsEstimated != true) microsChanged = true
                ing.copy(food = f)
            }
            if (!changed) return entry
            val updated = entry.withIngredients(list)
            val meal = updated.food ?: return updated
            return updated.copy(foodJson = JsonCache.encode(if (microsChanged) meal.copy(microsEstimated = true) else meal))
        }
        val food = entry.food ?: return entry
        val f = merge(food, estimates[food.id]) ?: return entry
        return entry.copy(foodJson = JsonCache.encode(f))
    }

    private fun estimatedFoodCount(entries: List<FoodEntry>): Int = entries.sumOf { e ->
        if (e.isComposite) e.ingredients.count { it.food.microsEstimated == true } else if (e.food?.microsEstimated == true) 1 else 0
    }

    // MARK: Micronutrient estimate

    private val microSchema = buildJsonObject {
        put("type", "object")
        putJsonObject("properties") {
            putJsonObject("items") {
                put("type", "array")
                putJsonObject("items") {
                    put("type", "object")
                    putJsonObject("properties") {
                        putJsonObject("id") { put("type", "string") }
                        put("micronutrients_per_100g", CloudVision.micronutrientListSchema)
                        putJsonObject("fruit_veg_share") { put("type", "number") }
                    }
                    putJsonArray("required") { add(JsonPrimitive("id")); add(JsonPrimitive("micronutrients_per_100g")); add(JsonPrimitive("fruit_veg_share")) }
                    put("additionalProperties", false)
                }
            }
        }
        putJsonArray("required") { add(JsonPrimitive("items")) }
        put("additionalProperties", false)
    }

    private fun describe(food: FoodItem): String {
        val n = food.per100
        val parts = mutableListOf(food.displayName)
        food.brand?.takeIf { it.isNotEmpty() }?.let { parts += "Marke: $it" }
        food.origin?.takeIf { it.isNotEmpty() && it != food.displayName }?.let { parts += it }
        parts += "pro 100 ${food.unit}: ${n.kcal.toInt()} kcal, Protein ${n.protein.clean} g, Kohlenhydrate ${n.carbs.clean} g, Fett ${n.fat.clean} g"
        val known = n.extra.filter { it.value > 0 }.map { "${it.key} ${it.value.clean}" }.sorted()
        if (known.isNotEmpty()) parts += "bereits bekannt: " + known.joinToString(", ")
        return parts.joinToString(" | ")
    }

    /** Returns food id → micronutrients per 100 g and fruit and vegetable share. */
    private suspend fun estimate(foods: List<FoodItem>, provider: VisionProvider): Map<String, Estimate> {
        val result = HashMap<String, Estimate>()
        for (batch in foods.chunked(20)) {
            val idMap = HashMap<String, String>()
            val lines = batch.mapIndexed { i, food ->
                val short = "f${i + 1}"
                idMap[short] = food.id
                "- id $short: ${describe(food)}"
            }
            val text = """Du bist Ernährungswissenschaftlerin. Für die folgenden Lebensmittel aus einem Ernährungstagebuch fehlen Mikronährstoffangaben. Schätze für jedes Lebensmittel realistische Gehalte pro 100 g (bei Getränken pro 100 ml) auf Basis typischer Nährwerttabellen wie dem Bundeslebensmittelschlüssel oder der USDA-Datenbank. Nutze Name, Marke und Makronährstoffe, um das Lebensmittel genau einzuordnen (z. B. Vollkorn oder Weißmehl, angereichert oder nicht). Bereits bekannte Werte musst du nicht wiederholen. Gib nur Werte an, die du plausibel schätzen kannst; ist ein Lebensmittel nicht eindeutig erkennbar (z. B. "Schnell-Eintrag"), gib eine leere Liste zurück.
Gib außerdem für jedes Lebensmittel `fruit_veg_share` an: den Anteil des Gewichts (0 bis 1), der Obst, Gemüse, Pilze oder Hülsenfrüchte ist, frisch, gegart oder tiefgekühlt. Beispiele: Salat oder Gurke 1, Gemüsesuppe etwa 0,6, Tomatensoße etwa 0,5, Gemüsepfanne mit Fleisch etwa 0,4. Kartoffeln, Pommes, Säfte, Trockenobst, Marmelade, Nüsse, Fleisch, Brot, Süßes und Getränke ohne Obst oder Gemüse sind 0. Bist du bei einem Lebensmittel nicht sicher oder es ist nicht erkennbar (z. B. "Schnell-Eintrag"), gib 0 an. Das gilt auch dann, wenn für das Lebensmittel keine Mikronährstoffe fehlen.
Gültige Schlüssel mit Einheit: ${CloudVision.micronutrientHelp}.
Antworte ausschließlich mit JSON: {"items": [{"id": "f1", "fruit_veg_share": 0.4, "micronutrients_per_100g": [{"key": "vitaminC", "value": 12}, {"key": "fiber", "value": 2.5}]}]}

Lebensmittel:
${lines.joinToString("\n")}"""
            val raw = CloudVision.request(provider, AITask.day.model(provider), text, null, microSchema)
            val json = CloudVision.decode(raw) ?: throw VisionException("Analyse fehlgeschlagen: Antwort nicht lesbar")
            for (item in (json["items"] as? JsonArray) ?: JsonArray(emptyList())) {
                val o = item as? JsonObject ?: continue
                val id = idMap[CloudVision.str(o["id"])] ?: continue
                result[id] = Estimate(CloudVision.micros(o["micronutrients_per_100g"]), CloudVision.num(o["fruit_veg_share"])?.takeIf { it.isFinite() }?.coerceIn(0.0, 1.0))
            }
        }
        return result
    }

    // MARK: Verdict

    data class Verdict(val rating: String, val tone: String, val points: List<String>)

    private val verdictSchema = buildJsonObject {
        put("type", "object")
        putJsonObject("properties") {
            putJsonObject("rating") { put("type", "string") }
            putJsonObject("tone") { put("type", "string"); putJsonArray("enum") { listOf("positiv", "neutral", "kritisch").forEach { add(JsonPrimitive(it)) } } }
            putJsonObject("points") { put("type", "array"); putJsonObject("items") { put("type", "string") } }
        }
        putJsonArray("required") { listOf("rating", "tone", "points").forEach { add(JsonPrimitive(it)) } }
        put("additionalProperties", false)
    }

    fun dayDescription(entries: List<FoodEntry>, score: HealthScore, target: DayTarget): String {
        val total = de.purrtion.app.model.Nutrients.sum(entries.map { it.nutrients })
        val foods = entries.map { e ->
            var line = "- ${e.name} (${e.amountText}): ${e.kcal.toInt()} kcal, P ${e.protein.toInt()} g, K ${e.carbs.toInt()} g, F ${e.fat.toInt()} g"
            if (e.isComposite) line += " – Zutaten: " + e.ingredients.joinToString(", ") { "${it.food.displayName} ${it.grams.toInt()} g" }
            line
        }
        val coverage = HealthScore.microKeys.mapNotNull { k -> k.dailyValue?.let { k to (total[k] ?: 0.0) / it } }
        val low = coverage.filter { it.second < 0.5 }.map { "${it.first.label} ${(it.second * 100).toInt()} %" }
        val good = coverage.filter { it.second >= 1 }.map { it.first.label }
        val components = score.components.joinToString("; ") { "${it.title}: ${it.pointsText} (${it.valueText})" }
        return """Ziele: ${target.kcal.toInt()} kcal${if (target.activityBonus > 0) " (inkl. ${target.activityBonus.toInt()} kcal Aktivität)" else ""}, Protein ${target.protein.toInt()} g, Kohlenhydrate ${target.carbs.toInt()} g, Fett ${target.fat.toInt()} g.${if (target.activeKcal > 0) " Aktivitätskalorien: ${target.activeKcal.toInt()} kcal." else ""}
Gegessen:
${foods.joinToString("\n")}
Summe: ${total.kcal.toInt()} kcal, Protein ${total.protein.toInt()} g, Kohlenhydrate ${total.carbs.toInt()} g, Fett ${total.fat.toInt()} g.
Health Score: ${score.score}/100 – $components.
Mikronährstoffe unter 50 % der EU-Referenzmenge: ${if (low.isEmpty()) "keine" else low.joinToString(", ")}.
Mindestens 100 % erreicht: ${if (good.isEmpty()) "keine" else good.joinToString(", ")}."""
    }

    private const val verdictInstructions = """Du bist eine freundliche, ehrliche Ernährungsberaterin und ordnest den Ernährungstag einer Person ein. Beziehe dich auf die konkreten Lebensmittel und Zahlen. Duze die Person, bleib motivierend und stelle keine medizinischen Diagnosen.
rating: Einordnung in 1–2 Wörtern auf Deutsch, z. B. "Ausgewogen", "Sehr gut", "Proteinarm", "Zu süß", "Gemüsearm".
tone: positiv, neutral oder kritisch.
points: 3 bis 6 kurze Stichpunkte mit je höchstens 15 Wörtern: was gut lief, was gefehlt hat und ein bis zwei konkrete Tipps für morgen."""

    private suspend fun judge(entries: List<FoodEntry>, score: HealthScore, target: DayTarget, provider: VisionProvider): Verdict {
        val text = verdictInstructions + "\nAntworte ausschließlich mit JSON: {\"rating\": \"…\", \"tone\": \"positiv|neutral|kritisch\", \"points\": [\"…\"]}\n\n" +
            dayDescription(entries, score, target)
        val raw = CloudVision.request(provider, AITask.day.model(provider), text, null, verdictSchema)
        val json = CloudVision.decode(raw) ?: throw VisionException("Analyse fehlgeschlagen: Antwort nicht lesbar")
        val rating = CloudVision.str(json["rating"]) ?: ""
        val tone = CloudVision.str(json["tone"])?.lowercase() ?: "neutral"
        val points = (json["points"] as? JsonArray)?.mapNotNull { CloudVision.str(it)?.trim() }?.filter { it.isNotEmpty() } ?: emptyList()
        val words = rating.trim().trim('.', ',', '!', '"').split(" ").filter { it.isNotEmpty() }
        return Verdict(words.take(3).joinToString(" "), if (tone in listOf("positiv", "neutral", "kritisch")) tone else "neutral", points.take(6))
    }
}
