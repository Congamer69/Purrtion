package de.purrtion.app.data

import de.purrtion.app.model.NutrientKey
import de.purrtion.app.domain.BloodAlcohol
import de.purrtion.app.domain.FriendsStore
import de.purrtion.app.App
import de.purrtion.app.domain.NutritionSync
import de.purrtion.app.domain.WidgetBridge
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.ServingOption
import kotlinx.coroutines.launch
import java.time.LocalDate

/** Write operations shared by all screens (log, remember, delete …) – each one keeps widgets and Health in sync. */
object Store {
    private val db get() = App.db

    /** Something on [day] changed: refresh the widget and (debounced) Health Connect and the friends page. */
    fun changed(day: LocalDate) {
        App.scope.launch {
            WidgetBridge.update()
            NutritionSync.schedule(day)
        }
        FriendsStore.uploadSoon()
    }

    /** Records that a food was used so it shows up in "Zuletzt". */
    suspend fun remember(food: FoodItem, quantity: Double, serving: ServingOption) {
        val existing = db.saved().get(food.id)
        val base = existing ?: SavedFood.of(food)
        db.saved().upsert(base.copy(
            name = food.displayName, brand = food.brand, kcalPer100 = food.per100.kcal, foodJson = JsonCache.encode(food),
            lastUsed = System.currentTimeMillis(), useCount = base.useCount + 1, lastQuantity = quantity, lastServingName = serving.name,
        ))
    }

    /** Logs a food. Drinks after midnight go to the night before (see [BloodAlcohol.nightDay]); returns the day used. */
    suspend fun log(food: FoodItem, quantity: Double, serving: ServingOption, day: LocalDate, createdAt: Long = System.currentTimeMillis(),
                    toNight: Boolean = true): LocalDate {
        val entry = FoodEntry.of(food, quantity, serving, day, createdAt)
        val night = if (toNight) BloodAlcohol.nightDay(day, entry.nutrients[NutrientKey.alcohol] ?: 0.0, createdAt) else day
        BloodAlcohol.lastMovedToNight = night != day
        db.entries().upsert(entry.copy(day = night.toEpochDay()))   // createdAt stays: the real time of the drink
        remember(food, quantity, serving)
        changed(night)
        return night
    }

    suspend fun insert(entry: FoodEntry) {
        db.entries().upsert(entry)
        changed(entry.date)
    }

    suspend fun update(entry: FoodEntry) {
        db.entries().upsert(entry)
        changed(entry.date)
    }

    suspend fun delete(entry: FoodEntry) {
        UndoStore.recordDeletion(listOf(entry))
        db.entries().delete(entry)
        changed(entry.date)
    }

    suspend fun deleteIds(ids: Collection<String>, day: LocalDate) {
        UndoStore.recordDeletion(db.entries().day(day.toEpochDay()).filter { it.id in ids })
        db.entries().deleteIds(ids.toList())
        changed(day)
    }

    suspend fun duplicate(entry: FoodEntry, day: LocalDate = entry.date) {
        val food = entry.food ?: return
        log(food, entry.quantity, entry.serving, day)
    }

    suspend fun copy(entries: List<FoodEntry>, to: LocalDate) {
        for (e in entries) {
            val food = e.food ?: continue
            db.entries().upsert(FoodEntry.of(food, e.quantity, e.serving, to))
        }
        changed(to)
    }

    suspend fun setFavorite(food: FoodItem, favorite: Boolean, quantity: Double? = null, serving: ServingOption? = null) {
        val existing = db.saved().get(food.id)
        val base = existing ?: SavedFood.of(food).copy(lastQuantity = quantity ?: food.defaultQuantity, lastServingName = serving?.name ?: food.defaultServing.name)
        db.saved().upsert(base.copy(isFavorite = favorite))
    }

    suspend fun addWater(day: LocalDate, amount: Int) {
        val logs = db.water().day(day.toEpochDay())
        val first = logs.firstOrNull()
        if (first != null) db.water().update(first.copy(ml = maxOf(0, first.ml + amount)))
        else if (amount > 0) db.water().insert(WaterLog(day = day.toEpochDay(), ml = amount))
        changed(day)
    }
}
