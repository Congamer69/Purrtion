package de.purrtion.app.domain

import de.purrtion.app.data.FoodEntry
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.format
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.max
import kotlin.math.min

/**
 * Blood alcohol estimate (‰) from the logged drinks. Distribution volume from total body water (Watson formulas),
 * each drink absorbed linearly over 30 minutes (≈10 % never reaches the blood), broken down at 0.1 ‰ per hour
 * like common BAC calculators. Same model as on iOS.
 */
class BloodAlcohol(drinks: List<Drink>, sex: Goals.Sex, age: Int, heightCM: Double, weightKG: Double) {
    data class Drink(val id: String, val name: String, val time: Long, val grams: Double)
    data class Point(val time: Long, val promille: Double)

    val drinks: List<Drink> = drinks.sortedBy { it.time }
    val points: List<Point>
    val peak: Point?
    val bodyWater: Double

    init {
        val tbw = if (sex == Goals.Sex.male) 2.447 - 0.09516 * age + 0.1074 * heightCM + 0.3362 * weightKG
            else -2.097 + 0.1069 * heightCM + 0.2466 * weightKG
        bodyWater = max(tbw, 15.0)
        val first = this.drinks.firstOrNull()
        if (first == null) {
            points = emptyList(); peak = null
        } else {
            val perGram = 0.8 / (bodyWater * 1.055)
            val step = STEP_MS
            val absorb = ABSORPTION_MINUTES * 60_000
            var t = first.time
            var bac = 0.0
            val out = mutableListOf(Point(t, 0.0))
            val lastDrink = this.drinks.last().time
            while (t < first.time + 36 * 3_600_000L) {
                val next = t + step
                var absorbed = 0.0
                for (d in this.drinks) {
                    val overlap = max(0L, min(next, d.time + absorb) - max(t, d.time))
                    absorbed += d.grams * ABSORBED_SHARE * overlap / absorb
                }
                bac += absorbed * perGram
                if (bac > 0) bac = max(0.0, bac - ELIMINATION_PER_HOUR * step / 3_600_000.0)
                t = next
                out += Point(t, bac)
                if (bac <= 0 && t > lastDrink + absorb) break
            }
            points = out
            peak = out.maxByOrNull { it.promille }
        }
    }

    fun value(at: Long): Double {
        val first = points.firstOrNull() ?: return 0.0
        if (at < first.time) return 0.0
        val i = ((at - first.time) / STEP_MS).toInt()
        if (i + 1 >= points.size) return 0.0
        val a = points[i]; val b = points[i + 1]
        val f = (at - a.time).toDouble() / STEP_MS
        return a.promille + (b.promille - a.promille) * f
    }

    /** First moment after [after] at which the value falls below [limit]. */
    fun timeBelow(limit: Double, after: Long): Long? {
        if (value(after) < limit) return null
        val last = drinks.lastOrNull()?.time ?: after
        return points.firstOrNull { it.time > after && it.promille < limit && it.time > last }?.time
    }

    val totalGrams: Double get() = drinks.sumOf { it.grams }
    val isEmpty: Boolean get() = drinks.isEmpty()

    companion object {
        const val ELIMINATION_PER_HOUR = 0.1
        const val ABSORPTION_MINUTES = 30L
        const val ABSORBED_SHARE = 0.9
        private const val STEP_MS = 5 * 60_000L

        /** When the drink was had: the logging time, unless it was logged later for a past day (then 20:00 that day). */
        fun drinkTime(e: FoodEntry): Long {
            val zone = ZoneId.systemDefault()
            val dayStart = LocalDate.ofEpochDay(e.day).atStartOfDay(zone).toInstant().toEpochMilli()
            val nextMorning = dayStart + 30 * 3_600_000L
            if (e.createdAt in dayStart until nextMorning) return e.createdAt
            return dayStart + 20 * 3_600_000L
        }

        fun drinks(entries: List<FoodEntry>): List<Drink> = entries.mapNotNull { e ->
            val g = e.nutrients[NutrientKey.alcohol] ?: 0.0
            if (g >= 1) Drink(e.id, e.name, drinkTime(e), g) else null
        }

        fun make(entries: List<FoodEntry>, goals: Goals, weight: Double?): BloodAlcohol =
            BloodAlcohol(drinks(entries), goals.sex, goals.age, goals.heightCM, weight ?: goals.weightKG)

        fun now(): Long = Instant.now().toEpochMilli()
    }
}

/** "0,42 ‰" */
val Double.promilleString: String get() = format(2, 2) + " ‰"
