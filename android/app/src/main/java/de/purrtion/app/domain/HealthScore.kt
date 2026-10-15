package de.purrtion.app.domain

import de.purrtion.app.data.FoodEntry
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.format
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Daily diet quality score 0–100, built from evidence-based targets (WHO Healthy Diet 2020, DGE reference values,
 * GBD 2017 / The Lancet 2019, EU NRVs). Alcohol is deducted on top (WHO 2023, DGE 2024). Same rules as on iOS.
 */
class HealthScore private constructor(val components: List<Component>, val completeness: Double) {
    data class Component(
        val id: String, val title: String, val icon: String, val points: Double, val maxPoints: Double,
        val valueText: String, val targetText: String, val explanation: String, val tip: String?,
    ) {
        /** Deductions (alcohol) have no maximum; their bar shows how much is left of a 20-point range. */
        val isPenalty: Boolean get() = maxPoints == 0.0
        val ratio: Double get() = if (isPenalty) 1 - min(1.0, -points / 20) else points / maxPoints
        val pointsText: String get() = if (isPenalty) "−${(-points).roundToInt()}" else "${points.roundToInt()}/${maxPoints.roundToInt()}"
    }

    val score: Int get() = max(0, components.sumOf { it.points }.roundToInt())
    val isPreliminary: Boolean get() = completeness < 0.4

    val rating: String
        get() = when {
            score >= 85 -> "Ausgezeichnet"
            score >= 70 -> "Gut"
            score >= 50 -> "Okay"
            else -> "Ausbaufähig"
        }

    override fun equals(other: Any?) = other is HealthScore && other.score == score && other.completeness == completeness
    override fun hashCode() = score * 31 + completeness.hashCode()

    companion object {
        /** The micronutrients used for the coverage part (NRV-based). */
        val microKeys = listOf(NutrientKey.vitaminA, NutrientKey.vitaminC, NutrientKey.vitaminD, NutrientKey.vitaminE, NutrientKey.vitaminK,
            NutrientKey.vitaminB1, NutrientKey.vitaminB2, NutrientKey.vitaminB3, NutrientKey.vitaminB6, NutrientKey.vitaminB12, NutrientKey.folate,
            NutrientKey.calcium, NutrientKey.magnesium, NutrientKey.iron, NutrientKey.zinc, NutrientKey.potassium, NutrientKey.iodine)

        /** `withoutAI`: score as it would be without the micronutrients the AI added on "Tag abschließen". */
        fun of(entries: List<FoodEntry>, goalKcal: Double, goalProtein: Double, withoutAI: Boolean = false): HealthScore {
            var total = Nutrients()
            var fruitVeg = 0.0
            for (e in entries) {
                total += if (withoutAI) e.nutrientsWithoutAI else e.nutrients
                if (isFruitOrVegetable(e.food)) fruitVeg += e.grams
            }
            return of(total, fruitVeg, goalKcal, goalProtein)
        }

        private fun falloff(x: Double, full: Double, zero: Double): Double = when {
            x <= full -> 1.0
            x >= zero -> 0.0
            else -> 1 - (x - full) / (zero - full)
        }

        private fun f1(v: Double) = v.format(1)

        fun of(n: Nutrients, fruitVegGrams: Double, goalKcal: Double, goalProtein: Double): HealthScore {
            val kcal = max(n.kcal, 1.0)
            val c = mutableListOf<Component>()

            // 1) Energy balance – 15
            val dev = abs(n.kcal - goalKcal) / max(goalKcal, 1.0)
            c += Component("energy", "Energiebilanz", "flame", 15 * falloff(dev, 0.10, 0.40), 15.0,
                "${n.kcal.toInt()} kcal", "Ziel ${goalKcal.toInt()} kcal ±10 %",
                "Eine Energiezufuhr nahe deinem Bedarf ist die Grundlage für ein stabiles Gewicht.",
                when {
                    n.kcal < goalKcal * 0.9 -> "Du liegst noch deutlich unter deinem Ziel."
                    n.kcal > goalKcal * 1.1 -> "Heute deutlich über dem Ziel. Morgen etwas leichter essen."
                    else -> null
                })

            // 2) Protein – 10
            val protRatio = n.protein / max(goalProtein, 1.0)
            c += Component("protein", "Protein", "protein", 10 * min(1.0, protRatio / 0.9), 10.0,
                "${n.protein.toInt()} g", "≥ 90 % von ${goalProtein.toInt()} g",
                "Ausreichend Protein erhält Muskulatur und sättigt lange (DGE, ISSN-Positionspapier).",
                if (protRatio < 0.9) "Mehr Protein: Skyr, Hülsenfrüchte, Eier, Fisch oder Tofu." else null)

            // 3) Fibre – 15
            val fiber = n[NutrientKey.fiber] ?: 0.0
            c += Component("fiber", "Ballaststoffe", "leaf", 15 * min(1.0, fiber / 30), 15.0,
                "${f1(fiber)} g", "≥ 30 g (DGE)",
                "Hohe Ballaststoffzufuhr senkt das Risiko für Herz-Kreislauf-Erkrankungen, Typ-2-Diabetes und Darmkrebs um 15–30 % (Reynolds et al., The Lancet 2019).",
                if (fiber < 30) "Vollkorn, Hülsenfrüchte, Gemüse, Nüsse und Haferflocken liefern viele Ballaststoffe." else null)

            // 4) Fruit & vegetables – 10
            c += Component("fruitveg", "Obst & Gemüse", "carrot", 10 * min(1.0, fruitVegGrams / 400), 10.0,
                "${fruitVegGrams.toInt()} g", "≥ 400 g (WHO, „5 am Tag“)",
                "Mindestens 400 g Obst und Gemüse täglich sind mit geringerer Sterblichkeit verbunden (Aune et al., 2017). Gezählt werden Lebensmittel aus dem BLS und der Schweizer Nährwertdatenbank.",
                if (fruitVegGrams < 400) "Noch ${max(0.0, 400 - fruitVegGrams).toInt()} g Obst oder Gemüse bis zum Ziel." else null)

            // 5) Sugar – 10
            val sugar = n[NutrientKey.sugar] ?: 0.0
            val sugarShare = sugar * 4 / kcal
            c += Component("sugar", "Zucker", "cube", 10 * falloff(sugarShare, 0.10, 0.25), 10.0,
                "${sugar.toInt()} g · ${(sugarShare * 100).toInt()} %", "< 10 % der Energie (WHO)",
                "Die WHO empfiehlt, weniger als 10 % der Energie aus Zucker aufzunehmen. Gezählt wird der Gesamtzucker, natürlicher Zucker aus Obst und Milch fließt also mit ein.",
                if (sugarShare > 0.10) "Süßgetränke und Süßigkeiten sind die größten Zuckerquellen." else null)

            // 6) Saturated fat – 10
            val sat = n[NutrientKey.saturatedFat] ?: 0.0
            val satShare = sat * 9 / kcal
            c += Component("satfat", "Gesättigte Fette", "drop", 10 * falloff(satShare, 0.10, 0.20), 10.0,
                "${sat.toInt()} g · ${(satShare * 100).toInt()} %", "< 10 % der Energie (WHO)",
                "Weniger gesättigte Fette, ersetzt durch ungesättigte, senkt das Herz-Kreislauf-Risiko (Cochrane Review 2020).",
                if (satShare > 0.10) "Butter, Käse, Wurst und Gebäck durch Olivenöl, Nüsse oder Fisch ersetzen." else null)

            // 7) Salt – 10
            val salt = n[NutrientKey.salt] ?: 0.0
            c += Component("salt", "Salz", "salt", 10 * falloff(salt, 5.0, 10.0), 10.0,
                "${f1(salt)} g", "≤ 5 g (WHO), max. 6 g (DGE)",
                "Zu viel Natrium ist laut GBD-Studie (The Lancet 2019) das größte ernährungsbedingte Gesundheitsrisiko weltweit.",
                if (salt > 5) "Fertiggerichte, Brot, Wurst und Käse enthalten viel verstecktes Salz." else null)

            // 8) Micronutrients – 20
            val coverages = microKeys.mapNotNull { key -> key.dailyValue?.let { min(1.0, (n[key] ?: 0.0) / it) } }
            val avg = if (coverages.isEmpty()) 0.0 else coverages.average()
            val lowest = microKeys.filter { key -> key.dailyValue?.let { (n[key] ?: 0.0) / it < 0.5 } ?: false }.take(3)
            c += Component("micros", "Vitamine & Mineralstoffe", "sparkles", 20 * avg, 20.0,
                "Ø ${(avg * 100).toInt()} % abgedeckt", "17 Nährstoffe, EU-Referenzwerte",
                "Durchschnittliche Abdeckung von Vitamin A, C, D, E, K, B-Vitaminen, Folat, Calcium, Magnesium, Eisen, Zink, Kalium und Jod (je max. 100 %). Markenprodukte liefern oft nur Pflichtangaben.",
                if (lowest.isEmpty()) null else "Am niedrigsten: " + lowest.joinToString(", ") { it.label })

            // 9) Alcohol – deduction of up to 20 points
            val alcohol = n[NutrientKey.alcohol] ?: 0.0
            if (alcohol >= 1) {
                val penalty = min(20.0, 3 + alcohol * 0.35)
                c += Component("alcohol", "Alkohol", "wine", -penalty, 0.0,
                    "${alcohol.roundToInt()} g", "Abzug, am besten 0 g",
                    "Laut WHO gibt es keine unbedenkliche Menge Alkohol; die DGE rät seit 2024, ganz darauf zu verzichten. Schon kleine Mengen erhöhen das Risiko für mehrere Krebsarten. Deshalb gibt es hier keine Punkte, sondern einen Abzug.",
                    "Alkohol kostet heute ${penalty.roundToInt()} Punkte. Alkoholfreie Alternativen sparen auch Kalorien.")
            }
            return HealthScore(c, n.kcal / max(goalKcal, 1.0))
        }

        /** BLS groups F (fruit), G (vegetables), mushrooms (K7) and legumes (H7) – without juices and dried fruit. */
        fun isFruitOrVegetable(food: FoodItem?): Boolean {
            if (food == null) return false
            if (food.source == FoodSource.swiss && food.id.startsWith("ch-")) {
                val category = SwissDatabase.category(food.id.drop(3)) ?: ""
                return SwissDatabase.isFruitOrVegetable(category, food.origin ?: food.name)
            }
            if (food.source != FoodSource.bls || !food.id.startsWith("bls-")) return false
            val code = food.id.drop(4)
            val name = (food.origin ?: food.name).lowercase()
            if (name.contains("saft") || name.contains("nektar") || name.contains("getrocknet") || name.contains("konfitüre")) return false
            return code.startsWith("F") || code.startsWith("G") || code.startsWith("K7") || code.startsWith("H7")
        }
    }
}
