package de.purrtion.app.data

import de.purrtion.app.App
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.ServingOption
import java.time.LocalDate
import java.time.ZoneId
import kotlin.random.Random

/** Debug builds only: fills the last weeks with plausible entries, water and weights (`adb shell am start ... --ez seedDemo true`). */
object DemoData {
    private fun food(id: String, name: String, kcal: Double, p: Double, c: Double, f: Double, fiber: Double, serving: Pair<String, Double>, alcohol: Double = 0.0) =
        FoodItem(id = "demo-$id", name = name, source = FoodSource.bls,
            per100 = Nutrients(kcal, p, c, f).with(NutrientKey.fiber, fiber).with(NutrientKey.vitaminC, 8.0).with(NutrientKey.magnesium, 30.0)
                .let { if (alcohol > 0) it.with(NutrientKey.alcohol, alcohol) else it },
            servings = listOf(ServingOption(serving.first, serving.second)))

    private val foods = listOf(
        food("oats", "Haferflocken", 370.0, 13.5, 58.7, 7.0, 10.0, "1 Portion" to 60.0),
        food("banana", "Banane", 93.0, 1.2, 20.0, 0.2, 2.0, "1 Stück" to 120.0),
        food("bread", "Vollkornbrot", 220.0, 7.0, 40.0, 1.5, 7.0, "1 Scheibe" to 50.0),
        food("cheese", "Gouda", 360.0, 25.0, 0.0, 29.0, 0.0, "1 Scheibe" to 30.0),
        food("pasta", "Spaghetti Bolognese", 150.0, 7.0, 18.0, 5.0, 1.5, "1 Teller" to 400.0),
        food("salad", "Gemischter Salat", 25.0, 1.3, 3.0, 0.3, 1.8, "1 Schüssel" to 200.0),
        food("chicken", "Hähnchenbrust", 110.0, 23.0, 0.0, 1.5, 0.0, "1 Stück" to 180.0),
        food("rice", "Reis gekocht", 130.0, 2.7, 28.0, 0.3, 0.4, "1 Portion" to 200.0),
        food("yogurt", "Joghurt 1,5 %", 50.0, 3.5, 4.5, 1.5, 0.0, "1 Becher" to 150.0),
        food("chocolate", "Vollmilchschokolade", 535.0, 7.5, 57.0, 30.0, 2.0, "1 Riegel" to 25.0),
        food("beer", "Bier", 42.0, 0.4, 3.0, 0.0, 0.0, "0,5 l" to 500.0, alcohol = 3.9),
    )

    suspend fun seed(days: Int = 45) {
        val db = App.db
        val zone = ZoneId.systemDefault()
        val rnd = Random(7)
        val today = LocalDate.now()
        for (i in days downTo 0) {
            val day = today.minusDays(i.toLong())
            if (i > 0 && rnd.nextInt(10) == 0) continue   // some gaps
            val meals = listOf(8 to listOf(0, 1), 12 to listOf(4, 5, 6, 7).shuffled(rnd).take(2), 19 to listOf(2, 3, 8).shuffled(rnd).take(2))
            for ((hour, idx) in meals) {
                if (i == 0 && hour > java.time.LocalTime.now().hour) continue
                for (k in idx) {
                    val f = foods[k]
                    val q = listOf(0.8, 1.0, 1.0, 1.25, 1.5).random(rnd)
                    db.entries().upsert(FoodEntry.of(f, q, f.servings.first(), day, day.atTime(hour, rnd.nextInt(50)).atZone(zone).toInstant().toEpochMilli()))
                }
            }
            if (rnd.nextInt(4) == 0) db.entries().upsert(FoodEntry.of(foods[9], 1.0, foods[9].servings.first(), day, day.atTime(15, 30).atZone(zone).toInstant().toEpochMilli()))
            if (day.dayOfWeek.value == 6) db.entries().upsert(FoodEntry.of(foods[10], 2.0, foods[10].servings.first(), day, day.atTime(21, 0).atZone(zone).toInstant().toEpochMilli()))
            repeat(rnd.nextInt(4, 10)) { db.water().insert(WaterLog(day = day.toEpochDay(), ml = 250)) }
            if (rnd.nextInt(3) != 0) db.weights().insert(WeightLog(date = day.atTime(7, 30).atZone(zone).toInstant().toEpochMilli(),
                kg = Math.round((74.0 - (days - i) * 0.04 + rnd.nextDouble(-0.4, 0.4)) * 10) / 10.0))
        }
    }
}
