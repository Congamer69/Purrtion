package de.purrtion.app.domain

import de.purrtion.app.App
import de.purrtion.app.model.AppJson
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import java.time.LocalDate

/** Active / resting energy per day from Health Connect (cached, so past days work offline) + manual activity. */
object ActivityStore {
    private const val CACHE = "activity.cacheJson"
    private const val BASAL = "activity.basalCacheJson"
    private const val MANUAL = "activity.manualJson"
    private val mapSerializer = MapSerializer(String.serializer(), Double.serializer())

    private fun read(key: String): Map<String, Double> {
        val json = App.prefs.string(key, "")
        return if (json.isEmpty()) emptyMap() else runCatching { AppJson.decodeFromString(mapSerializer, json) }.getOrDefault(emptyMap())
    }

    private fun write(key: String, map: Map<String, Double>) = App.prefs.set(key, AppJson.encodeToString(mapSerializer, map))

    /** Active energy from Health Connect. */
    fun kcal(day: LocalDate): Double = read(CACHE)[day.toString()] ?: 0.0

    /** Resting energy from Health Connect (0 when unknown). */
    fun basal(day: LocalDate): Double = read(BASAL)[day.toString()] ?: 0.0

    fun manual(day: LocalDate): Double = read(MANUAL)[day.toString()] ?: 0.0

    fun setManual(kcal: Double, day: LocalDate) {
        val m = read(MANUAL).toMutableMap()
        if (kcal > 0) m[day.toString()] = Math.round(kcal).toDouble() else m.remove(day.toString())
        write(MANUAL, m)
    }

    fun store(active: Map<LocalDate, Double>, basal: Map<LocalDate, Double>) {
        if (active.isNotEmpty()) write(CACHE, read(CACHE) + active.mapKeys { it.key.toString() })
        if (basal.isNotEmpty()) write(BASAL, read(BASAL) + basal.mapKeys { it.key.toString() })
    }

    /** Emulator / demo: plausible active energy for the last weeks. */
    fun seedDemo() {
        val today = LocalDate.now()
        val active = (0 until 40).associate { today.minusDays(it.toLong()) to listOf(420.0, 310.0, 650.0, 280.0, 520.0, 380.0, 720.0)[it % 7] }
        val basal = (0 until 40).associate { today.minusDays(it.toLong()) to listOf(1690.0, 1710.0, 1680.0, 1700.0, 1720.0, 1695.0, 1705.0)[it % 7] }
        store(active, basal)
    }
}
