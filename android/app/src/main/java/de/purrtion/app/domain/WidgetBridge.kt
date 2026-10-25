package de.purrtion.app.domain

import androidx.glance.appwidget.updateAll
import de.purrtion.app.App
import de.purrtion.app.widget.TodayWidget
import de.purrtion.app.widget.WidgetSnapshot
import java.time.LocalDate

/** Writes today's summary for the widget and refreshes it. */
object WidgetBridge {
    suspend fun update() {
        val goals = App.goals
        val today = LocalDate.now()
        // The weekly budget looks at what the days of this week added up to.
        runCatching {
            val eaten = App.db.entries().range(today.minusDays(14).toEpochDay(), today.toEpochDay()).groupBy { it.day }
                .mapKeys { LocalDate.ofEpochDay(it.key) }.mapValues { e -> e.value.sumOf { it.kcal } }
            // Days without entries count as 0 (also after deleting them).
            WeekBudget.record((0..14).associate { today.minusDays(it.toLong()) to (eaten[today.minusDays(it.toLong())] ?: 0.0) })
        }
        val entries = App.db.entries().day(today.toEpochDay())
        val water = App.db.water().day(today.toEpochDay()).sumOf { it.ml }
        val target = goals.target(today)
        var score: Int? = null
        if (goals.healthScoreEnabled && entries.isNotEmpty()) {
            val s = HealthScore.of(entries, target.kcal, target.protein)
            score = if (s.isPreliminary) null else s.score
        }
        WidgetSnapshot(
            day = today.toEpochDay(), kcal = entries.sumOf { it.kcal }, kcalGoal = target.kcal,
            protein = entries.sumOf { it.protein }, carbs = entries.sumOf { it.carbs }, fat = entries.sumOf { it.fat },
            proteinGoal = target.protein, carbsGoal = target.carbs, fatGoal = target.fat,
            waterML = water, waterGoal = goals.waterML, waterEnabled = goals.waterEnabled, score = score,
            paletteID = App.prefs.string("catPalette", "ginger"), entryCount = entries.size,
        ).save()
        runCatching { TodayWidget().updateAll(App.context) }
    }
}
