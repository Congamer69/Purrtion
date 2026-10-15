package de.purrtion.app.data

import android.util.LruCache
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import de.purrtion.app.model.AppJson
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.RecipeIngredient
import de.purrtion.app.model.ServingOption
import de.purrtion.app.model.clean
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import java.time.LocalDate
import java.util.UUID

/** Decoded JSON is cached: entries are rendered often, decoding them each time would be wasteful. */
object JsonCache {
    private val foods = LruCache<String, FoodItem>(600)
    private val lists = LruCache<String, List<RecipeIngredient>>(300)

    fun food(json: String?): FoodItem? {
        if (json.isNullOrEmpty()) return null
        foods.get(json)?.let { return it }
        val f = runCatching { AppJson.decodeFromString(FoodItem.serializer(), json) }.getOrNull() ?: return null
        foods.put(json, f)
        return f
    }

    fun ingredients(json: String?): List<RecipeIngredient> {
        if (json.isNullOrEmpty()) return emptyList()
        lists.get(json)?.let { return it }
        val l = runCatching { AppJson.decodeFromString(ListSerializer(RecipeIngredient.serializer()), json) }.getOrNull() ?: emptyList()
        lists.put(json, l)
        return l
    }

    fun encode(food: FoodItem): String = AppJson.encodeToString(FoodItem.serializer(), food)
    fun encode(list: List<RecipeIngredient>): String = AppJson.encodeToString(ListSerializer(RecipeIngredient.serializer()), list)
    fun encodeStrings(list: List<String>): String = AppJson.encodeToString(ListSerializer(String.serializer()), list)
    fun strings(json: String?): List<String> =
        if (json.isNullOrEmpty()) emptyList() else runCatching { AppJson.decodeFromString(ListSerializer(String.serializer()), json) }.getOrDefault(emptyList())
}

fun newId(): String = UUID.randomUUID().toString().uppercase()

/** One logged food. Days are stored as epoch days (local calendar), times as epoch millis. */
@Entity(tableName = "entries", indices = [Index("day")])
data class FoodEntry(
    @PrimaryKey val id: String = newId(),
    val day: Long,
    val createdAt: Long = System.currentTimeMillis(),
    val name: String,
    val brand: String? = null,
    val quantity: Double = 1.0,
    val servingName: String = "g",
    val servingGrams: Double = 1.0,
    val kcal: Double = 0.0,
    val protein: Double = 0.0,
    val carbs: Double = 0.0,
    val fat: Double = 0.0,
    val foodJson: String? = null,
    /** Ingredients of a logged recipe / AI meal, independent from later recipe edits. */
    val ingredientsJson: String? = null,
) {
    val date: LocalDate get() = LocalDate.ofEpochDay(day)
    val food: FoodItem? get() = JsonCache.food(foodJson)
    val ingredients: List<RecipeIngredient> get() = JsonCache.ingredients(ingredientsJson)
    val isComposite: Boolean get() = ingredients.isNotEmpty()
    val grams: Double get() = quantity * servingGrams
    val serving: ServingOption get() = ServingOption(servingName, servingGrams)

    val nutrients: Nutrients get() = food?.nutrients(grams) ?: Nutrients(kcal, protein, carbs, fat)

    /** Same as [nutrients], but without micronutrients the AI filled in when the day was closed. */
    val nutrientsWithoutAI: Nutrients
        get() {
            if (isComposite) {
                val list = ingredients
                val total = Nutrients.sum(list.map { it.food.per100WithoutAI.scaled(it.grams / 100) })
                val ingredientGrams = list.sumOf { it.grams }
                return if (ingredientGrams > 0) total.scaled(grams / ingredientGrams) else total
            }
            val f = food ?: return nutrients
            return f.per100WithoutAI.scaled(grams / 100)
        }

    fun updated(quantity: Double, serving: ServingOption, food: FoodItem): FoodEntry {
        val n = food.nutrients(quantity * serving.grams)
        return copy(quantity = quantity, servingName = serving.name, servingGrams = serving.grams,
            kcal = n.kcal, protein = n.protein, carbs = n.carbs, fat = n.fat, foodJson = JsonCache.encode(food))
    }

    fun withIngredients(newIngredients: List<RecipeIngredient>): FoodEntry {
        val meal = food ?: return this
        if (newIngredients.isEmpty()) return this
        val total = Nutrients.sum(newIngredients.map { it.nutrients })
        val g = maxOf(newIngredients.sumOf { it.grams }, 1.0)
        val updatedMeal = meal.copy(
            per100 = total.scaled(100 / g),
            servings = listOf(ServingOption("1 Portion", g)),
            recipeIngredients = newIngredients,
            origin = if (meal.source == FoodSource.ai) "KI-Scan · ${newIngredients.size} Zutaten" else "Rezept · ${newIngredients.size} Zutaten",
        )
        return copy(ingredientsJson = JsonCache.encode(newIngredients)).updated(1.0, updatedMeal.defaultServing, updatedMeal)
    }

    fun replacingIngredient(id: String, food: FoodItem, quantity: Double, serving: ServingOption): FoodEntry =
        withIngredients(ingredients.map { if (it.id == id) it.copy(food = food, quantity = quantity, serving = serving) else it })

    fun addingIngredient(ingredient: RecipeIngredient) = withIngredients(ingredients + ingredient)

    fun duplicatingIngredient(id: String): FoodEntry {
        val list = ingredients.toMutableList()
        val i = list.indexOfFirst { it.id == id }
        if (i < 0) return this
        list.add(i + 1, list[i].copy(id = newId()))
        return withIngredients(list)
    }

    /** Null when it was the last ingredient – the caller deletes the whole entry then. */
    fun removingIngredient(id: String): FoodEntry? {
        val list = ingredients.filter { it.id != id }
        return if (list.isEmpty()) null else withIngredients(list)
    }

    val amountText: String
        get() {
            if (isComposite) return "${ingredients.size} Zutaten · ${grams.clean} g"
            val f = food
            if (f?.source == FoodSource.custom) {
                val portions = if (quantity == 1.0) "1 Portion" else "${quantity.clean} Portionen"
                // Quick entries from a nutrition table: the portion is the amount eaten.
                return if (servingName == "Portion" && servingGrams != 100.0) "$portions · ${grams.clean} ${f.unit}" else portions
            }
            if (servingGrams == 1.0) return "${quantity.clean} $servingName"
            val unit = f?.unit ?: "g"
            val single = if (servingName.startsWith("1 ")) servingName.drop(2) else servingName
            val amount = if (quantity == 1.0) servingName else "${quantity.clean} × $single"
            return "$amount · ${grams.clean} $unit"
        }

    companion object {
        fun of(food: FoodItem, quantity: Double, serving: ServingOption, day: LocalDate, createdAt: Long = System.currentTimeMillis()): FoodEntry {
            var ingredientsJson: String? = null
            val ingredients = food.recipeIngredients
            if (!ingredients.isNullOrEmpty()) {
                val originalGrams = ingredients.sumOf { it.grams }
                val factor = if (originalGrams > 0) quantity * serving.grams / originalGrams else 1.0
                ingredientsJson = JsonCache.encode(ingredients.map { it.copy(quantity = it.quantity * factor) })
            }
            return FoodEntry(day = day.toEpochDay(), createdAt = createdAt, name = food.displayName, brand = food.brand,
                ingredientsJson = ingredientsJson).updated(quantity, serving, food)
        }

        /** One scanned meal as one entry that keeps all of its editable ingredients. */
        fun meal(name: String, ingredients: List<RecipeIngredient>, source: FoodSource, day: LocalDate): FoodEntry {
            val total = Nutrients.sum(ingredients.map { it.nutrients })
            val g = maxOf(ingredients.sumOf { it.grams }, 1.0)
            val meal = FoodItem(
                id = "meal-${newId()}", name = name, source = source, per100 = total.scaled(100 / g), unit = "g",
                servings = listOf(ServingOption("1 Portion", g)),
                origin = if (source == FoodSource.ai) "KI-Scan · ${ingredients.size} Zutaten" else "Rezept · ${ingredients.size} Zutaten",
                recipeIngredients = ingredients,
            )
            return FoodEntry(day = day.toEpochDay(), name = meal.displayName, ingredientsJson = JsonCache.encode(ingredients))
                .updated(1.0, meal.defaultServing, meal)
        }
    }
}

/** Recently used + favourite foods for one-tap logging. */
@Entity(tableName = "saved")
data class SavedFood(
    @PrimaryKey val key: String,
    val name: String,
    val brand: String? = null,
    val kcalPer100: Double = 0.0,
    val foodJson: String? = null,
    val lastUsed: Long = System.currentTimeMillis(),
    val useCount: Int = 0,
    val isFavorite: Boolean = false,
    val lastQuantity: Double = 1.0,
    val lastServingName: String = "g",
) {
    val food: FoodItem? get() = JsonCache.food(foodJson)
    val lastServing: ServingOption? get() = food?.allServings?.firstOrNull { it.name == lastServingName }

    companion object {
        fun of(food: FoodItem) = SavedFood(key = food.id, name = food.displayName, brand = food.brand,
            kcalPer100 = food.per100.kcal, foodJson = JsonCache.encode(food))
    }
}

@Entity(tableName = "water", indices = [Index("day")])
data class WaterLog(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val day: Long,
    val ml: Int,
)

@Entity(tableName = "weights")
data class WeightLog(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val date: Long,
    val kg: Double,
)

/** A food or recipe created by the user. */
@Entity(tableName = "custom")
data class CustomFood(
    @PrimaryKey val id: String = newId(),
    val name: String,
    val brand: String? = null,
    val isRecipe: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val foodJson: String? = null,
    val ingredientsJson: String? = null,
    val portions: Int = 1,
) {
    val ingredients: List<RecipeIngredient> get() = JsonCache.ingredients(ingredientsJson)
    val totalGrams: Double get() = ingredients.sumOf { it.grams }

    /** Loggable food item. */
    val food: FoodItem
        get() {
            if (!isRecipe) {
                JsonCache.food(foodJson)?.let { return it.copy(id = "custom-$id", name = name) }
            }
            val list = ingredients
            val total = Nutrients.sum(list.map { it.nutrients })
            val grams = maxOf(totalGrams, 1.0)
            val p = maxOf(portions, 1)
            val portionGrams = Math.round(grams / p * 10) / 10.0
            return FoodItem(
                id = "recipe-$id", name = name, source = FoodSource.custom, per100 = total.scaled(100 / grams), unit = "g",
                servings = listOf(ServingOption("1 Portion", portionGrams), ServingOption("Ganzes Rezept ($p Port.)", Math.round(grams).toDouble())),
                origin = "Rezept · ${list.size} Zutaten", recipeIngredients = list,
            )
        }

    companion object {
        fun simple(name: String, food: FoodItem) = CustomFood(name = name, brand = food.brand, foodJson = JsonCache.encode(food))
        fun recipe(name: String, ingredients: List<RecipeIngredient>, portions: Int) =
            CustomFood(name = name, isRecipe = true, portions = maxOf(1, portions), ingredientsJson = JsonCache.encode(ingredients))
    }
}

/** Result of "Tag abschließen": the AI's short verdict on one day. */
@Entity(tableName = "reviews")
data class DayReview(
    @PrimaryKey val day: Long,
    val createdAt: Long = System.currentTimeMillis(),
    val rating: String = "",
    /** "positiv", "neutral" or "kritisch". */
    val tone: String = "neutral",
    val pointsJson: String? = null,
    val signature: String = "",
    val enrichedCount: Int = 0,
    val providerName: String = "",
    val score: Int? = null,
    val scoreBefore: Int? = null,
    val automatic: Boolean = false,
) {
    val points: List<String> get() = JsonCache.strings(pointsJson)

    companion object {
        fun signature(entries: List<FoodEntry>): String =
            entries.map { "${it.id}:${Math.round(it.kcal)}" }.sorted().joinToString("|")
    }
}
