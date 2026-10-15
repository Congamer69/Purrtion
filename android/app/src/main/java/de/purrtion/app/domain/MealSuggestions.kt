package de.purrtion.app.domain

import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.ServingOption
import de.purrtion.app.model.clean
import java.time.LocalTime
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * "Was passt noch?" – ranks favourites, recipes and own foods by how well they fit the rest of the day:
 * macro mix vs. what is missing (cosine), protein coverage and calories that fit right now.
 */
object MealSuggestions {
    enum class Kind(val label: String) { favorite("Favorit"), recipe("Rezept"), own("Eigenes") }

    data class Candidate(val food: FoodItem, val quantity: Double, val serving: ServingOption, val kind: Kind)

    data class Suggestion(val food: FoodItem, val quantity: Double, val serving: ServingOption, val kind: Kind,
                          val nutrients: Nutrients, val score: Double, val reason: String) {
        val id: String get() = food.id
        val amountText: String
            get() {
                if (serving.grams == 1.0) return "${quantity.clean} ${serving.name}"
                val single = if (serving.name.startsWith("1 ")) serving.name.drop(2) else serving.name
                val amount = if (quantity == 1.0) serving.name else "${quantity.clean} × $single"
                return "$amount · ${(quantity * serving.grams).clean} ${food.unit}"
            }
    }

    data class Gap(val kcal: Double, val protein: Double, val carbs: Double, val fat: Double, val mealsLeft: Int)

    fun gap(total: Nutrients, target: DayTarget, isToday: Boolean, now: LocalTime = LocalTime.now()): Gap {
        val hour = now.hour
        val meals = if (!isToday) 1 else if (hour < 10) 3 else if (hour < 15) 2 else 1
        return Gap(target.kcal - total.kcal, max(0.0, target.protein - total.protein),
            max(0.0, target.carbs - total.carbs), max(0.0, target.fat - total.fat), meals)
    }

    fun rank(candidates: List<Candidate>, gap: Gap, limit: Int = 30): List<Suggestion> {
        val budget = max(gap.kcal, 0.0)
        val ideal = if (budget < 150) min(budget, 120.0) else budget / gap.mealsLeft
        val gapVec = doubleArrayOf(gap.protein * 4, gap.carbs * 4, gap.fat * 9)
        val best = HashMap<String, Suggestion>()
        for (c in candidates) {
            for (f in listOf(0.5, 1.0, 1.5, 2.0)) {
                val q = c.quantity * f
                val n = c.food.nutrients(q * c.serving.grams)
                if (n.kcal < 20) continue
                if (n.kcal > max(budget * 1.03, 160.0)) continue
                val vec = doubleArrayOf(n.protein * 4, n.carbs * 4, n.fat * 9)
                val macroFit = cosine(vec, gapVec)
                val proteinCover = if (gap.protein > 5) min(n.protein / gap.protein, 1.0) else 0.5
                val fill = if (ideal > 0) 1 - min(abs(n.kcal - ideal) / ideal, 1.0) else 0.0
                var score = 0.42 * macroFit + 0.28 * proteinCover + 0.30 * fill
                if (f != 1.0) score -= 0.06
                if (c.kind == Kind.favorite) score += 0.02
                val s = Suggestion(c.food, q, c.serving, c.kind, n, score, reason(n, gap, fill, macroFit, ideal))
                if ((best[c.food.id]?.score ?: -1.0) < score) best[c.food.id] = s
            }
        }
        return best.values.sortedByDescending { it.score }.take(limit)
    }

    private fun reason(n: Nutrients, gap: Gap, fill: Double, macroFit: Double, ideal: Double): String = when {
        gap.protein > 15 && n.protein >= gap.protein * 0.45 -> "Viel Protein"
        fill > 0.85 && gap.mealsLeft == 1 -> "Füllt den Rest"
        fill > 0.85 -> "Passende Größe"
        n.kcal < ideal * 0.5 -> "Leichter Snack"
        macroFit > 0.95 -> "Passende Makros"
        else -> "Passt ins Budget"
    }

    private fun cosine(a: DoubleArray, b: DoubleArray): Double {
        val dot = a.indices.sumOf { a[it] * b[it] }
        val na = sqrt(a.sumOf { it * it }); val nb = sqrt(b.sumOf { it * it })
        return if (na > 0 && nb > 0) dot / (na * nb) else 0.5
    }
}
