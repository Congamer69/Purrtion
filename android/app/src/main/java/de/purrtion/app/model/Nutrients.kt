package de.purrtion.app.model

import kotlinx.serialization.Serializable

/** All nutrients beyond energy + the three macros. Amounts are stored in the nutrient's [unit]. */
enum class NutrientKey(val key: String, val label: String, val unit: String, val group: Group, val dailyValue: Double?) {
    sugar("sugar", "Zucker", "g", Group.details, 90.0),
    fiber("fiber", "Ballaststoffe", "g", Group.details, 30.0),
    saturatedFat("saturatedFat", "Gesättigte Fette", "g", Group.details, 20.0),
    monoFat("monoFat", "Einfach unges. Fette", "g", Group.details, null),
    polyFat("polyFat", "Mehrfach unges. Fette", "g", Group.details, null),
    omega3("omega3", "Omega-3-Fettsäuren", "g", Group.details, null),
    transFat("transFat", "Transfette", "g", Group.details, null),
    cholesterol("cholesterol", "Cholesterin", "mg", Group.details, 300.0),
    salt("salt", "Salz", "g", Group.details, 6.0),
    sodium("sodium", "Natrium", "mg", Group.details, 2400.0),
    potassium("potassium", "Kalium", "mg", Group.minerals, 2000.0),
    calcium("calcium", "Calcium", "mg", Group.minerals, 800.0),
    magnesium("magnesium", "Magnesium", "mg", Group.minerals, 375.0),
    iron("iron", "Eisen", "mg", Group.minerals, 14.0),
    zinc("zinc", "Zink", "mg", Group.minerals, 10.0),
    phosphorus("phosphorus", "Phosphor", "mg", Group.minerals, 700.0),
    iodine("iodine", "Jod", "µg", Group.minerals, 150.0),
    selenium("selenium", "Selen", "µg", Group.minerals, 55.0),
    copper("copper", "Kupfer", "mg", Group.minerals, 1.0),
    manganese("manganese", "Mangan", "mg", Group.minerals, 2.0),
    vitaminA("vitaminA", "Vitamin A", "µg", Group.vitamins, 800.0),
    vitaminC("vitaminC", "Vitamin C", "mg", Group.vitamins, 80.0),
    vitaminD("vitaminD", "Vitamin D", "µg", Group.vitamins, 20.0),
    vitaminE("vitaminE", "Vitamin E", "mg", Group.vitamins, 12.0),
    vitaminK("vitaminK", "Vitamin K", "µg", Group.vitamins, 75.0),
    vitaminB1("vitaminB1", "Vitamin B1", "mg", Group.vitamins, 1.1),
    vitaminB2("vitaminB2", "Vitamin B2", "mg", Group.vitamins, 1.4),
    vitaminB3("vitaminB3", "Niacin (B3)", "mg", Group.vitamins, 16.0),
    vitaminB5("vitaminB5", "Pantothensäure (B5)", "mg", Group.vitamins, 6.0),
    vitaminB6("vitaminB6", "Vitamin B6", "mg", Group.vitamins, 1.4),
    biotin("biotin", "Biotin (B7)", "µg", Group.vitamins, 50.0),
    vitaminB12("vitaminB12", "Vitamin B12", "µg", Group.vitamins, 2.5),
    folate("folate", "Folat", "µg", Group.vitamins, 200.0),
    caffeine("caffeine", "Koffein", "mg", Group.other, 400.0),
    alcohol("alcohol", "Alkohol", "g", Group.other, null);

    enum class Group(val title: String) { details("Details"), minerals("Mineralstoffe"), vitamins("Vitamine"), other("Sonstiges") }

    /** For these, staying *below* the daily value is the goal. */
    val isLimit: Boolean get() = this in setOf(sugar, saturatedFat, salt, sodium, cholesterol, caffeine, transFat)

    companion object {
        val byKey: Map<String, NutrientKey> = entries.associateBy { it.key }
    }
}

/** Energy, macros and any number of extra nutrients – same JSON shape as on iOS. */
@Serializable
data class Nutrients(
    val kcal: Double = 0.0,
    val protein: Double = 0.0,
    val carbs: Double = 0.0,
    val fat: Double = 0.0,
    val extra: Map<String, Double> = emptyMap(),
) {
    operator fun get(key: NutrientKey): Double? = extra[key.key]

    fun with(key: NutrientKey, value: Double?): Nutrients =
        copy(extra = if (value == null) extra - key.key else extra + (key.key to value))

    fun scaled(factor: Double) = Nutrients(kcal * factor, protein * factor, carbs * factor, fat * factor,
        extra.mapValues { it.value * factor })

    operator fun plus(b: Nutrients): Nutrients {
        val merged = extra.toMutableMap()
        for ((k, v) in b.extra) merged[k] = (merged[k] ?: 0.0) + v
        return Nutrients(kcal + b.kcal, protein + b.protein, carbs + b.carbs, fat + b.fat, merged)
    }

    /** Fill in salt/sodium from each other and kcal from macros when missing. */
    fun normalized(): Nutrients {
        var n = this
        val salt = n[NutrientKey.salt]
        val sodium = n[NutrientKey.sodium]
        if (salt == null && sodium != null) n = n.with(NutrientKey.salt, sodium * 2.5 / 1000)
        if (sodium == null && salt != null) n = n.with(NutrientKey.sodium, salt / 2.5 * 1000)
        if (n.kcal == 0.0 && n.protein + n.carbs + n.fat > 0) {
            n = n.copy(kcal = n.protein * 4 + n.carbs * 4 + n.fat * 9 + (n[NutrientKey.alcohol] ?: 0.0) * 7)
        }
        return n
    }

    companion object {
        fun sum(list: List<Nutrients>): Nutrients = list.fold(Nutrients()) { a, b -> a + b }
    }
}
