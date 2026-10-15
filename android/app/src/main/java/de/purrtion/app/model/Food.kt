package de.purrtion.app.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
enum class FoodSource {
    bls, openFoodFacts, ai, custom, swiss, restaurant,
    // legacy sources from earlier iOS versions, kept so old entries still decode
    basic, usda;

    val label: String
        get() = when (this) {
            bls -> "Bundeslebensmittelschlüssel 4.0"
            swiss -> "Schweizer Nährwertdatenbank"
            restaurant -> "Restaurantkette (offizielle Angaben)"
            basic -> "Basis"
            openFoodFacts -> "Open Food Facts"
            usda -> "USDA"
            ai -> "KI-Schätzung"
            custom -> "Eigene"
        }
}

/** A selectable amount, e.g. "1 Scheibe" = 30 g. */
@Serializable
data class ServingOption(val name: String, val grams: Double) {
    val id: String get() = "$name-$grams"

    companion object {
        fun base(unit: String) = ServingOption(unit, 1.0)
    }
}

/** A food as delivered by a database. Nutrients are always per 100 g (or 100 ml). Same JSON as on iOS. */
@Serializable
data class FoodItem(
    val id: String,
    val name: String,
    val brand: String? = null,
    val source: FoodSource,
    val barcode: String? = null,
    val imageURL: String? = null,
    val per100: Nutrients,
    /** "g" or "ml" */
    val unit: String = "g",
    val servings: List<ServingOption> = emptyList(),
    val usdaID: Int? = null,
    /** Original database name when a friendlier display name is used. */
    val origin: String? = null,
    /** Set when the data looks implausible (crowd-sourced databases). */
    val warning: String? = null,
    /** Present for logged recipes and AI meals so their components remain editable after logging. */
    val recipeIngredients: List<RecipeIngredient>? = null,
    /** Missing micronutrients were filled in by the AI when the day was closed. */
    val microsEstimated: Boolean? = null,
    /** Which nutrient keys in [per100] were added by the AI. */
    val aiNutrientKeys: List<String>? = null,
) {
    /** Nutrients per 100 g as they came from label / database, without AI-added values. */
    val per100WithoutAI: Nutrients
        get() {
            val keys = aiNutrientKeys
            if (keys.isNullOrEmpty()) return per100
            return per100.copy(extra = per100.extra - keys.toSet())
        }

    val displayName: String get() = name.ifEmpty { "Unbenannt" }

    /** Base unit + servings, deduplicated. */
    val allServings: List<ServingOption>
        get() {
            val out = mutableListOf(ServingOption.base(unit))
            for (s in servings) if (s.grams > 0 && out.none { it.name == s.name }) out += s
            return out
        }

    val defaultServing: ServingOption get() = servings.firstOrNull() ?: ServingOption.base(unit)
    val defaultQuantity: Double get() = if (servings.isEmpty()) 100.0 else 1.0

    fun nutrients(grams: Double): Nutrients = per100.scaled(grams / 100)
}

/** One ingredient of a recipe: a food plus the amount used. */
@Serializable
data class RecipeIngredient(
    val id: String = UUID.randomUUID().toString().uppercase(),
    val food: FoodItem,
    val quantity: Double,
    val serving: ServingOption,
) {
    val grams: Double get() = quantity * serving.grams
    val nutrients: Nutrients get() = food.nutrients(grams)

    /** Same wording as a normal log entry, e.g. "2 × Scheibe · 60 g". */
    val amountText: String
        get() {
            if (serving.grams == 1.0) return "${quantity.clean} ${serving.name}"
            val single = if (serving.name.startsWith("1 ")) serving.name.drop(2) else serving.name
            val amount = if (quantity == 1.0) serving.name else "${quantity.clean} × $single"
            return "$amount · ${grams.clean} ${food.unit}"
        }
}
