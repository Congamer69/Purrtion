package de.purrtion.app.model

import kotlinx.serialization.json.Json
import java.text.NumberFormat
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToLong

val German: Locale = Locale.GERMANY

/** JSON shared with the iOS app: unknown keys are ignored, defaults are always written. */
val AppJson = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
    explicitNulls = false
    coerceInputValues = true
}

private val intFormat: NumberFormat = NumberFormat.getIntegerInstance(German)

private fun fractionFormat(min: Int, max: Int): NumberFormat = NumberFormat.getNumberInstance(German).apply {
    minimumFractionDigits = min
    maximumFractionDigits = max
}

/** "2", "2,5" – up to one decimal, German comma. */
val Double.clean: String
    get() = if (this == Math.rint(this) && abs(this) < 1e15) roundToLong().toString() else fractionFormat(0, 1).format(this)

/** "1.234" – rounded kcal with German grouping. */
val Double.kcalString: String get() = intFormat.format(roundToLong())

fun Double.format(maxFraction: Int, minFraction: Int = 0, grouping: Boolean = true): String =
    fractionFormat(minFraction, maxFraction).apply { isGroupingUsed = grouping }.format(this)

fun Int.grouped(): String = intFormat.format(this)

// MARK: Dates

private val dayMonthFormatter = DateTimeFormatter.ofPattern("d. MMMM", German)
private val dayMonthYearFormatter = DateTimeFormatter.ofPattern("d. MMMM yyyy", German)
private val shortDayMonth = DateTimeFormatter.ofPattern("d. MMM", German)

fun LocalDate.weekdayName(): String = dayOfWeek.getDisplayName(TextStyle.FULL, German)
fun LocalDate.weekdayShort(): String = dayOfWeek.getDisplayName(TextStyle.SHORT, German).removeSuffix(".")
fun LocalDate.weekdayNarrow(): String = dayOfWeek.getDisplayName(TextStyle.NARROW, German)
fun LocalDate.dayMonth(): String = format(dayMonthFormatter)
fun LocalDate.dayMonthYear(): String = format(dayMonthYearFormatter)
fun LocalDate.shortDayMonth(): String = format(shortDayMonth)
fun LocalDate.fullTitle(): String = "${weekdayName()}, ${dayMonth()}"

/** "gerade eben", "vor 5 Minuten", "vor 2 Stunden", "gestern", "vor 3 Tagen", always German (like iOS' named relative format). */
fun relativeTime(millis: Long, now: Long = System.currentTimeMillis()): String {
    val minutes = (now - millis) / 60_000
    return when {
        minutes < 1 -> "gerade eben"
        minutes < 60 -> if (minutes == 1L) "vor 1 Minute" else "vor $minutes Minuten"
        minutes < 24 * 60 -> (minutes / 60).let { if (it == 1L) "vor 1 Stunde" else "vor $it Stunden" }
        minutes < 48 * 60 -> "gestern"
        else -> "vor ${minutes / (24 * 60)} Tagen"
    }
}

/** Monday of the week containing this date. */
fun LocalDate.mondayOfWeek(): LocalDate = minusDays((dayOfWeek.value - DayOfWeek.MONDAY.value).toLong())

/** iOS weekday numbering (1 = Sunday … 7 = Saturday), used in the shared goal settings. */
val LocalDate.iosWeekday: Int get() = dayOfWeek.value % 7 + 1
