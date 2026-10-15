package de.purrtion.app.widget

import de.purrtion.app.App
import de.purrtion.app.model.AppJson
import kotlinx.serialization.Serializable
import java.time.LocalDate

/** Small summary of today that the app writes and the widget reads. */
@Serializable
data class WidgetSnapshot(
    val day: Long = LocalDate.now().toEpochDay(),
    val kcal: Double = 0.0,
    val kcalGoal: Double = 2000.0,
    val protein: Double = 0.0,
    val carbs: Double = 0.0,
    val fat: Double = 0.0,
    val proteinGoal: Double = 120.0,
    val carbsGoal: Double = 220.0,
    val fatGoal: Double = 70.0,
    val waterML: Int = 0,
    val waterGoal: Int = 2500,
    val waterEnabled: Boolean = true,
    val score: Int? = null,
    val paletteID: String = "ginger",
    val entryCount: Int = 0,
) {
    /** A snapshot from yesterday counts as an empty day. */
    fun forToday(): WidgetSnapshot {
        val today = LocalDate.now().toEpochDay()
        if (day >= today) return this
        return copy(day = today, kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0, waterML = 0, score = null, entryCount = 0)
    }

    val progress: Double get() = kcal / maxOf(kcalGoal, 1.0)

    fun save() = App.prefs.set("widget.snapshot", AppJson.encodeToString(serializer(), this))

    companion object {
        fun load(): WidgetSnapshot = App.prefs.optString("widget.snapshot")
            ?.let { runCatching { AppJson.decodeFromString(serializer(), it) }.getOrNull() } ?: WidgetSnapshot()
    }
}
