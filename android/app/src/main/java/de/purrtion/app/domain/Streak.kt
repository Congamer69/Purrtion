package de.purrtion.app.domain

import de.purrtion.app.App
import java.time.LocalDate

/**
 * Day streak with Duolingo-style freezes (same rules and keys as the iOS app).
 * - A day counts when something is logged.
 * - A missed day is bridged automatically by a freeze (if one is left and the streak was alive the day before).
 * - Every 7 logged days in a row earns a freeze; at most [MAX_FREEZES] are kept.
 * - Frozen days keep the streak alive but don't add to the count.
 */
object Streak {
    const val MAX_FREEZES = 2
    const val DAYS_PER_FREEZE = 7

    data class State(
        val count: Int = 0,
        val best: Int = 0,
        val freezes: Int = 0,
        val frozen: Set<LocalDate> = emptySet(),
        val loggedToday: Boolean = false,
    )

    private const val FREEZES = "streak.freezes"
    private const val FROZEN = "streak.frozen"
    private const val EVALUATED = "streak.evaluated"
    private const val MILESTONE = "streak.milestone"
    private const val BEST = "streak.best"

    private fun encode(d: LocalDate) = d.toEpochDay().toString()

    /** Days covered by a freeze (cheap read for the week strip). */
    fun frozenDays(): Set<LocalDate> =
        App.prefs.string(FROZEN, "").split(",").mapNotNull { it.toLongOrNull()?.let(LocalDate::ofEpochDay) }.toSet()

    /** Brings freezes and the count up to date. Safe to call often. */
    suspend fun refresh(): State {
        val today = LocalDate.now()
        val yesterday = today.minusDays(1)
        val logged = App.db.entries().loggedDays(today.minusDays(800).toEpochDay()).map(LocalDate::ofEpochDay).toSet()
        val prefs = App.prefs

        var freezes = if (prefs.has(FREEZES)) prefs.int(FREEZES, 1) else 1
        val frozen = frozenDays().toMutableSet()
        val firstRun = !prefs.has(EVALUATED)
        val evaluated = if (firstRun) yesterday else LocalDate.ofEpochDay(prefs.string(EVALUATED, "0").toLongOrNull() ?: yesterday.toEpochDay())

        // Past days since the last check: freeze what can be saved.
        var d = evaluated.plusDays(1)
        while (!d.isAfter(yesterday)) {
            if (d !in logged && freezes > 0) {
                val before = d.minusDays(1)
                if (before in logged || before in frozen) { frozen += d; freezes -= 1 }
            }
            d = d.plusDays(1)
        }

        // Count back from today (or yesterday while today is still empty).
        val loggedToday = today in logged
        var day = if (loggedToday) today else yesterday
        var count = 0
        while (day in logged || day in frozen) {
            if (day in logged) count++
            day = day.minusDays(1)
        }

        // Earn a freeze for every full week reached since the last milestone.
        val reached = count / DAYS_PER_FREEZE * DAYS_PER_FREEZE
        var milestone = if (prefs.has(MILESTONE)) prefs.int(MILESTONE, reached) else reached
        if (firstRun) milestone = reached
        if (reached > milestone) freezes = minOf(MAX_FREEZES, freezes + (reached - milestone) / DAYS_PER_FREEZE)
        milestone = reached
        freezes = minOf(freezes, MAX_FREEZES)

        val best = maxOf(prefs.int(BEST, 0), count)
        prefs.set(FREEZES, freezes)
        prefs.set(FROZEN, frozen.joinToString(",") { encode(it) })
        prefs.set(EVALUATED, encode(yesterday))
        prefs.set(MILESTONE, milestone)
        prefs.set(BEST, best)
        return State(count, best, freezes, frozen, loggedToday)
    }
}
