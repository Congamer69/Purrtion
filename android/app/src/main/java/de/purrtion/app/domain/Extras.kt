package de.purrtion.app.domain

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import de.purrtion.app.App
import de.purrtion.app.MainActivity
import de.purrtion.app.R
import de.purrtion.app.data.WeightLog
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.ServingOption
import java.time.DayOfWeek
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Optional extras from 2.6. Every one has its own switch under Profil → Funktionen (same keys as the iPhone app). */
object Extras {
    const val WEEK_BUDGET = "extras.weekBudget"
    const val WEEK_BUDGET_PCT = "extras.weekBudgetPct"
    const val TIME_SUGGEST = "extras.timeSuggestions"
    const val MULTI_SCAN = "extras.multiScan"
    const val FORECAST = "extras.weightForecast"
    const val GOAL_WEIGHT = "weight.goal"
    const val REMINDER = "extras.reminder"
    const val REMINDER_MINUTES = "extras.reminderMinutes"
    const val SHOP = "extras.shop"
}

// MARK: Weekly budget

/** A day that went over or under the goal is spread over the rest of the week, at most ±pct % per day. Past days keep their goal. */
object WeekBudget {
    private const val TOTALS = "extras.dayTotals"
    private const val ADJUST = "extras.weekAdjust"

    val enabled: Boolean get() = App.prefs.bool(Extras.WEEK_BUDGET, false)
    val pct: Double get() = App.prefs.double(Extras.WEEK_BUDGET_PCT, 15.0).coerceIn(5.0, 30.0)

    private fun read(key: String): Map<Long, Double> = App.prefs.string(key, "").split(",").mapNotNull {
        val p = it.split(":"); if (p.size == 2) p[0].toLongOrNull()?.let { d -> p[1].toDoubleOrNull()?.let { v -> d to v } } else null
    }.toMap()

    private fun write(key: String, map: Map<Long, Double>) = App.prefs.set(key, map.entries.joinToString(",") { "${it.key}:${it.value}" })

    /** Eaten kcal per day of the last two weeks (called whenever data changes). */
    fun record(totals: Map<LocalDate, Double>) {
        val old = read(TOTALS).toMutableMap()
        var changed = false
        for ((d, v) in totals) if (abs((old[d.toEpochDay()] ?: -1.0) - v) > 0.5) { old[d.toEpochDay()] = v; changed = true }
        if (changed) write(TOTALS, old.filterKeys { it > LocalDate.now().toEpochDay() - 60 })
    }

    /** kcal added (+) or taken (−) on [day]. [coreKcal] is the goal of a day without the budget. */
    fun adjustment(day: LocalDate, coreKcal: (LocalDate) -> Double): Double {
        if (!enabled) return 0.0
        val recorded = read(ADJUST)
        val today = LocalDate.now()
        if (day.isBefore(today)) return recorded[day.toEpochDay()] ?: 0.0
        val weekStart = today.with(DayOfWeek.MONDAY)
        val weekEnd = weekStart.plusDays(7)
        if (!day.isBefore(weekEnd)) return 0.0
        val totals = read(TOTALS)
        var surplus = 0.0
        var d = weekStart
        while (d.isBefore(today)) {
            val eaten = totals[d.toEpochDay()]
            if (eaten != null && eaten > 0) surplus += eaten - (coreKcal(d) + (recorded[d.toEpochDay()] ?: 0.0))
            d = d.plusDays(1)
        }
        val daysLeft = max(1, (weekEnd.toEpochDay() - today.toEpochDay()).toInt())
        val limit = coreKcal(day) * pct / 100
        val adj = Math.round(min(max(-surplus / daysLeft, -limit), limit) / 5).toDouble() * 5
        if (day == today && abs((recorded[today.toEpochDay()] ?: 0.0) - adj) > 0.5) write(ADJUST, recorded + (today.toEpochDay() to adj))
        return adj
    }
}

// MARK: Suggestions for this time of day

object TimeSuggestions {
    data class Suggestion(val name: String, val food: FoodItem, val quantity: Double, val serving: ServingOption, val kcal: Double, val days: Int)

    val enabled: Boolean get() = App.prefs.bool(Extras.TIME_SUGGEST, true)

    /** What you usually log around now (last 60 days, within ±90 minutes), most frequent first; already logged today is left out. */
    suspend fun suggestions(now: LocalDateTime = LocalDateTime.now(), limit: Int = 4): List<Suggestion> {
        val today = now.toLocalDate()
        val entries = App.db.entries().range(today.minusDays(60).toEpochDay(), today.toEpochDay())
        val zone = ZoneId.systemDefault()
        val nowMin = now.hour * 60 + now.minute
        val loggedToday = entries.filter { it.day == today.toEpochDay() }.map { it.name }.toSet()
        class Group(var latest: de.purrtion.app.data.FoodEntry, val days: MutableSet<Long> = mutableSetOf())
        val groups = mutableMapOf<String, Group>()
        for (e in entries) {
            if (e.day == today.toEpochDay() || e.name in loggedToday) continue
            val t = Instant.ofEpochMilli(e.createdAt).atZone(zone)
            var diff = abs(t.hour * 60 + t.minute - nowMin)
            diff = min(diff, 1440 - diff)
            if (diff > 90) continue
            val g = groups.getOrPut(e.name) { Group(e) }
            g.days += e.day
            if (e.createdAt > g.latest.createdAt) g.latest = e
        }
        val ranked = groups.values.sortedWith(compareByDescending<Group> { it.days.size }.thenByDescending { it.latest.createdAt })
        val frequent = ranked.filter { it.days.size >= 2 }
        return (frequent.ifEmpty { ranked }).take(limit).mapNotNull { g ->
            val food = g.latest.food ?: return@mapNotNull null
            Suggestion(g.latest.name, food, g.latest.quantity, ServingOption(g.latest.servingName, g.latest.servingGrams), g.latest.kcal, g.days.size)
        }
    }
}

// MARK: Weight forecast

object WeightForecast {
    val enabled: Boolean get() = App.prefs.bool(Extras.FORECAST, true)
    val goalWeight: Double get() = App.prefs.double(Extras.GOAL_WEIGHT, 0.0)

    sealed class Outcome {
        object Reached : Outcome()
        data class OnTrack(val date: LocalDate, val earliest: LocalDate, val latest: LocalDate?) : Outcome()
        object WrongDirection : Outcome()
        object Flat : Outcome()
        object NeedsData : Outcome()
    }
    data class Result(val outcome: Outcome, val trendKg: Double? = null, val perWeek: Double? = null)

    /** Robust fit through the last six weeks; needs three weigh-ins over at least ten days. The range comes from the slope's standard error. */
    fun forecast(weights: List<WeightLog>, goal: Double, now: LocalDate = LocalDate.now()): Result {
        val zone = ZoneId.systemDefault()
        val start = now.minusDays(42)
        val recent = weights.map { Instant.ofEpochMilli(it.date).atZone(zone).toLocalDate() to it.kg }.filter { !it.first.isBefore(start) }.sortedBy { it.first }
        if (goal <= 0 || recent.size < 3 || now.toEpochDay() - recent.first().first.toEpochDay() < 10) return Result(Outcome.NeedsData)
        val pts = recent.map { (it.first.toEpochDay() - start.toEpochDay()).toDouble() to it.second }
        val fit = Expenditure.robustSlope(pts) ?: return Result(Outcome.NeedsData)
        val xNow = (now.toEpochDay() - start.toEpochDay()).toDouble()
        val trend = fit.intercept + fit.slope * xNow
        val perWeek = fit.slope * 7
        if ((goal <= trend && fit.slope <= 0 && trend - goal < 0.2) || (goal >= trend && fit.slope >= 0 && goal - trend < 0.2)) return Result(Outcome.Reached, trend, perWeek)
        if (abs(perWeek) < 0.05) return Result(Outcome.Flat, trend, perWeek)
        val needed = goal - trend
        if (needed * fit.slope <= 0) return Result(Outcome.WrongDirection, trend, perWeek)
        fun date(slope: Double): LocalDate? = if (slope != 0.0 && needed / slope > 0 && needed / slope < 3 * 365) now.plusDays(Math.round(needed / slope)) else null
        val dir = if (fit.slope > 0) 1 else -1
        val central = date(fit.slope) ?: return Result(Outcome.Flat, trend, perWeek)
        return Result(Outcome.OnTrack(central, date(fit.slope + dir * fit.slopeSE) ?: central, date(fit.slope - dir * fit.slopeSE)), trend, perWeek)
    }
}

// MARK: Gentle reminder

/** A quiet notification from the cat at a chosen time, only when nothing is logged yet (checked when it fires). */
object GentleReminder {
    private const val CHANNEL = "gentle"
    private const val WORK = "gentle-reminder"
    val enabled: Boolean get() = App.prefs.bool(Extras.REMINDER, false)
    val minutes: Int get() = App.prefs.int(Extras.REMINDER_MINUTES, 12 * 60 + 30)

    fun createChannel(context: Context) {
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Sanfte Erinnerung", NotificationManager.IMPORTANCE_DEFAULT).apply { description = "Kurze Erinnerung, wenn heute noch nichts eingetragen ist" })
    }

    /** Plans the next reminder (or cancels it). Safe to call often. */
    fun schedule(context: Context = App.context) {
        val wm = WorkManager.getInstance(context)
        if (!enabled) { wm.cancelUniqueWork(WORK); return }
        val now = LocalDateTime.now()
        var at = LocalDate.now().atTime(LocalTime.of(minutes / 60, minutes % 60))
        if (!at.isAfter(now)) at = at.plusDays(1)
        wm.enqueueUniqueWork(WORK, ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<ReminderWorker>().setInitialDelay(Duration.between(now, at).toMillis(), TimeUnit.MILLISECONDS).build())
    }

    suspend fun fireIfEmpty(context: Context) {
        if (!enabled || !Notifications.canPost(context)) return
        if (App.db.entries().day(LocalDate.now().toEpochDay()).isNotEmpty()) return
        val lines = listOf("Mochi hat Hunger. Heute ist noch nichts im Napf.", "Der Napf ist noch leer. Magst du etwas eintragen?",
            "Mochi schnurrt dir zu: Was gab es heute zu essen?", "Kleiner Check-in: Trag kurz ein, was du gegessen hast.")
        val body = lines[LocalDate.now().dayOfYear % lines.size].replace("Mochi", if (App.prefs.string("catPalette", "") == "dog") "Buddy" else "Mochi")
        createChannel(context)
        val pi = PendingIntent.getActivity(context, 77, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(context, CHANNEL).setSmallIcon(R.drawable.ic_notification).setContentTitle("Purrtion 🐾")
            .setContentText(body).setContentIntent(pi).setAutoCancel(true).build()
        runCatching { NotificationManagerCompat.from(context).notify(77, n) }
    }
}

class ReminderWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        App.init(applicationContext)
        GentleReminder.fireIfEmpty(applicationContext)
        GentleReminder.schedule(applicationContext)   // tomorrow
        return Result.success()
    }
}

// MARK: Shop

/** Streak shop: points earned by logging buy fur colours, hats, glasses, scarves and an extra freeze. Same items and prices as iOS. */
data class ShopItem(val id: String, val name: String, val kind: Kind, val price: Int) {
    enum class Kind(val title: String) { fur("Fell"), hat("Hüte"), glasses("Brillen"), scarf("Schals"), extra("Extras") }
}

object Shop {
    val enabled: Boolean get() = App.prefs.bool(Extras.SHOP, true)

    val items = listOf(
        ShopItem("moon", "Mondschein", ShopItem.Kind.fur, 150), ShopItem("cinnamon", "Zimt", ShopItem.Kind.fur, 150), ShopItem("mint", "Minze", ShopItem.Kind.fur, 200),
        ShopItem("sakura", "Sakura", ShopItem.Kind.fur, 250), ShopItem("galaxy", "Galaxie", ShopItem.Kind.fur, 400),
        ShopItem("hat.party", "Partyhut", ShopItem.Kind.hat, 60), ShopItem("hat.beanie", "Mütze", ShopItem.Kind.hat, 80), ShopItem("hat.top", "Zylinder", ShopItem.Kind.hat, 120),
        ShopItem("hat.wizard", "Zauberhut", ShopItem.Kind.hat, 200), ShopItem("hat.crown", "Krone", ShopItem.Kind.hat, 300),
        ShopItem("glasses.round", "Brille", ShopItem.Kind.glasses, 90), ShopItem("glasses.sun", "Sonnenbrille", ShopItem.Kind.glasses, 130),
        ShopItem("scarf.red", "Roter Schal", ShopItem.Kind.scarf, 70), ShopItem("scarf.blue", "Blauer Schal", ShopItem.Kind.scarf, 70), ShopItem("scarf.green", "Grüner Schal", ShopItem.Kind.scarf, 70),
        ShopItem("scarf.violet", "Violetter Schal", ShopItem.Kind.scarf, 100), ShopItem("scarf.gold", "Goldschal", ShopItem.Kind.scarf, 180),
        ShopItem("extra.freeze", "Extra-Freeze", ShopItem.Kind.extra, 120),
    )

    private val milestoneBonus = listOf(3 to 20, 7 to 50, 14 to 100, 30 to 200, 60 to 400, 100 to 800, 200 to 1500, 365 to 3000)
    private const val OWNED = "shop.owned"
    private const val EXTRAS_SPENT = "shop.extrasSpent"

    /** 5 points for every logged day, 10 more for a day close to the goal, plus a bonus for each streak milestone reached. */
    suspend fun earned(goals: Goals, bestStreak: Int): Int {
        val today = LocalDate.now()
        val entries = App.db.entries().range(today.minusDays(800).toEpochDay(), today.toEpochDay())
        var points = 0
        for ((day, list) in entries.groupBy { it.day }) {
            val date = LocalDate.ofEpochDay(day)
            if (!date.isBefore(today)) continue
            points += 5
            val goal = goals.target(date).kcal
            val kcal = list.sumOf { it.kcal }
            if (kcal >= goal * 0.7 && kcal <= goal * 1.05) points += 10
        }
        return points + milestoneBonus.filter { bestStreak >= it.first }.sumOf { it.second }
    }

    val owned: Set<String> get() = App.prefs.string(OWNED, "").split(",").filter { it.isNotEmpty() }.toSet()
    private fun setOwned(s: Set<String>) = App.prefs.set(OWNED, s.sorted().joinToString(","))
    val spent: Int get() = owned.sumOf { id -> items.firstOrNull { it.id == id }?.price ?: 0 } + App.prefs.int(EXTRAS_SPENT, 0)
    fun balance(earned: Int) = max(0, earned - spent)

    fun key(kind: ShopItem.Kind): String? = when (kind) {
        ShopItem.Kind.fur -> "catPalette"; ShopItem.Kind.hat -> "shop.hat"; ShopItem.Kind.glasses -> "shop.glasses"; ShopItem.Kind.scarf -> "shop.scarf"; ShopItem.Kind.extra -> null
    }
    fun isWorn(item: ShopItem): Boolean = key(item.kind)?.let { App.prefs.string(it, "") == item.id } ?: false

    fun equip(item: ShopItem) {
        val k = key(item.kind) ?: return
        if (item.id !in owned) return
        if (isWorn(item)) App.prefs.set(k, if (item.kind == ShopItem.Kind.fur) "ginger" else "") else App.prefs.set(k, item.id)
    }

    /** What the cat wears now. Friends always see it, whatever the shop switch says. */
    val currentOutfit: de.purrtion.app.ui.pixel.Outfit
        get() = de.purrtion.app.ui.pixel.Outfit(App.prefs.string("shop.hat", ""), App.prefs.string("shop.glasses", ""), App.prefs.string("shop.scarf", ""))

    fun takeOffAll() { listOf("shop.hat", "shop.glasses", "shop.scarf").forEach { App.prefs.set(it, "") } }

    /** True when bought. Fur, hats, glasses and scarves are put on right away. */
    fun buy(item: ShopItem, balance: Int): Boolean {
        if (balance < item.price) return false
        if (item.kind == ShopItem.Kind.extra) {
            val freezes = App.prefs.int("streak.freezes", 1)
            if (freezes >= Streak.MAX_FREEZES) return false
            App.prefs.set("streak.freezes", freezes + 1)
            App.prefs.set(EXTRAS_SPENT, App.prefs.int(EXTRAS_SPENT, 0) + item.price)
            return true
        }
        if (item.id in owned) return false
        setOwned(owned + item.id)
        equip(item)
        return true
    }
}
