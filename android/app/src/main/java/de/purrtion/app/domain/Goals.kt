package de.purrtion.app.domain

import android.os.Handler
import android.os.Looper
import de.purrtion.app.data.Prefs
import de.purrtion.app.model.AppJson
import de.purrtion.app.model.iosWeekday
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.listSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonPrimitive
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Swift encodes `[Int: Double]` as an alternating array `[key, value, …]`; this reads both that and an object. */
object WeekdayMapSerializer : KSerializer<Map<Int, Double>> {
    override val descriptor: SerialDescriptor = listSerialDescriptor<Double>()
    override fun serialize(encoder: Encoder, value: Map<Int, Double>) {
        val arr = JsonArray(value.flatMap { listOf(JsonPrimitive(it.key), JsonPrimitive(it.value)) })
        (encoder as JsonEncoder).encodeJsonElement(arr)
    }
    override fun deserialize(decoder: Decoder): Map<Int, Double> {
        return when (val el = (decoder as JsonDecoder).decodeJsonElement()) {
            is JsonArray -> el.chunked(2).filter { it.size == 2 }.associate { it[0].jsonPrimitive.int to it[1].jsonPrimitive.double }
            is JsonObject -> el.entries.mapNotNull { (k, v) -> k.toIntOrNull()?.let { it to v.jsonPrimitive.double } }.toMap()
            else -> emptyMap()
        }
    }
}

/** Targets valid from a certain day on – changing the goal never rewrites past days. */
@Serializable
data class GoalPlan(
    /** ISO-8601 instant of the start of the day (as written by iOS). */
    val from: String,
    val kcal: Double,
    val protein: Double,
    val carbs: Double,
    val fat: Double,
    @Serializable(with = WeekdayMapSerializer::class) val weekdayKcal: Map<Int, Double> = emptyMap(),
    val activityPercent: Double = 0.0,
) {
    val fromDate: LocalDate
        get() = runCatching { Instant.parse(from).atZone(ZoneId.systemDefault()).toLocalDate() }.getOrDefault(LocalDate.MIN)

    fun sameTargets(o: GoalPlan) = kcal == o.kcal && protein == o.protein && carbs == o.carbs && fat == o.fat &&
        weekdayKcal == o.weekdayKcal && activityPercent == o.activityPercent

    companion object {
        fun startOf(day: LocalDate): String = if (day == LocalDate.MIN) "2001-01-01T00:00:00Z"
            else day.atStartOfDay(ZoneId.systemDefault()).toInstant().toString()
    }
}

/** The resolved goal of one day (weekday goal + activity bonus applied). */
data class DayTarget(
    val kcal: Double,
    val protein: Double,
    val carbs: Double,
    val fat: Double,
    /** Goal before the activity bonus. */
    val baseKcal: Double,
    /** Health Connect + manually added activity. */
    val activeKcal: Double,
    val healthKcal: Double,
    val manualKcal: Double,
    val activityBonus: Double,
    /** Share of tracked activity credited on that day (the setting valid back then). */
    val activityPercent: Double = 0.0,
    /** Weekly budget: kcal moved to or from this day because earlier days of the week went over or under. */
    val weekAdjust: Double = 0.0,
)

/** Daily targets + body profile, persisted in the shared settings. */
class Goals(private val prefs: Prefs) {
    enum class Sex(val label: String) { female("Weiblich"), male("Männlich") }

    enum class Activity(val factor: Double, val label: String, val detail: String) {
        sedentary(1.2, "Kaum aktiv", "Bürojob, wenig Bewegung"),
        light(1.375, "Leicht aktiv", "1–3× Sport pro Woche"),
        moderate(1.55, "Mäßig aktiv", "3–5× Sport pro Woche"),
        active(1.725, "Sehr aktiv", "6–7× Sport pro Woche"),
        veryActive(1.9, "Extrem aktiv", "Körperliche Arbeit + Sport"),
    }

    enum class Target(val delta: Double, val label: String) {
        lose(-500.0, "Abnehmen"), loseSlow(-250.0, "Sanft abnehmen"), maintain(0.0, "Gewicht halten"), gain(300.0, "Zunehmen")
    }

    enum class MacroMode(val label: String) { percent("Prozent"), grams("Gramm") }

    private val handler = Handler(Looper.getMainLooper())
    private val record = Runnable { recordPlan() }

    /** Goal changes are recorded (debounced) so they apply from today on. */
    private fun changed() {
        handler.removeCallbacks(record)
        handler.postDelayed(record, 700)
    }

    var kcal: Double get() = prefs.double("goal.kcal", 2000.0); set(v) { prefs.set("goal.kcal", v); changed() }
    var protein: Double get() = prefs.double("goal.protein", 120.0); set(v) { prefs.set("goal.protein", v); changed() }
    var carbs: Double get() = prefs.double("goal.carbs", 220.0); set(v) { prefs.set("goal.carbs", v); changed() }
    var fat: Double get() = prefs.double("goal.fat", 70.0); set(v) { prefs.set("goal.fat", v); changed() }
    var waterML: Int get() = prefs.int("goal.waterML", 2500); set(v) = prefs.set("goal.waterML", v)
    var waterStep: Int get() = prefs.int("goal.waterStep", 250); set(v) = prefs.set("goal.waterStep", v)
    var waterEnabled: Boolean get() = prefs.bool("goal.waterEnabled", true); set(v) = prefs.set("goal.waterEnabled", v)
    var healthScoreEnabled: Boolean get() = prefs.bool("goal.healthScoreEnabled", true); set(v) = prefs.set("goal.healthScoreEnabled", v)

    var weekdayEnabled: Boolean get() = prefs.bool("goal.weekdayEnabled", false); set(v) { prefs.set("goal.weekdayEnabled", v); changed() }
    var activityPercent: Double get() = prefs.double("goal.activityPercent", 0.0); set(v) { prefs.set("goal.activityPercent", v); changed() }
    /** Show active energy from Health Connect. */
    var activityEnabled: Boolean get() = prefs.bool("activity.enabled", false); set(v) { prefs.set("activity.enabled", v); changed() }

    var macroMode: MacroMode
        get() = runCatching { MacroMode.valueOf(prefs.string("goal.macroMode", "percent")) }.getOrDefault(MacroMode.percent)
        set(v) = prefs.set("goal.macroMode", v.name)
    var proteinPct: Double get() = prefs.double("goal.proteinPct", 25.0); set(v) = prefs.set("goal.proteinPct", v)
    var fatPct: Double get() = prefs.double("goal.fatPct", 30.0); set(v) = prefs.set("goal.fatPct", v)
    val carbsPct: Double get() = max(0.0, 100 - proteinPct - fatPct)

    var sex: Sex get() = runCatching { Sex.valueOf(prefs.string("profile.sex", "female")) }.getOrDefault(Sex.female); set(v) = prefs.set("profile.sex", v.name)
    var age: Int get() = prefs.int("profile.age", 28); set(v) = prefs.set("profile.age", v)
    var heightCM: Double get() = prefs.double("profile.height", 170.0); set(v) = prefs.set("profile.height", v)
    var weightKG: Double get() = prefs.double("profile.weight", 68.0); set(v) = prefs.set("profile.weight", v)
    var activity: Activity get() = runCatching { Activity.valueOf(prefs.string("profile.activity", "light")) }.getOrDefault(Activity.light); set(v) = prefs.set("profile.activity", v.name)
    var target: Target get() = runCatching { Target.valueOf(prefs.string("profile.target", "maintain")) }.getOrDefault(Target.maintain); set(v) = prefs.set("profile.target", v.name)
    var onboarded: Boolean get() = prefs.bool("onboarded", false); set(v) = prefs.set("onboarded", v)

    // MARK: Weekday goals

    var weekdayKcal: Map<Int, Double>
        get() {
            val json = prefs.string("goal.weekdayKcal", "")
            if (json.isEmpty()) return emptyMap()
            return runCatching {
                AppJson.decodeFromString<Map<String, Double>>(json).mapNotNull { (k, v) -> k.toIntOrNull()?.let { it to v } }.toMap()
            }.getOrDefault(emptyMap())
        }
        set(v) {
            prefs.set("goal.weekdayKcal", AppJson.encodeToString(kotlinx.serialization.serializer<Map<String, Double>>(), v.mapKeys { it.key.toString() }))
            changed()
        }

    fun kcal(forWeekday: Int): Double = weekdayKcal[forWeekday] ?: kcal

    fun setKcal(value: Double, forWeekday: Int) { weekdayKcal = weekdayKcal + (forWeekday to value) }

    // MARK: History

    var history: List<GoalPlan>
        get() {
            val json = prefs.string("goal.history", "")
            if (json.isEmpty()) return emptyList()
            return runCatching { AppJson.decodeFromString(ListSerializer(GoalPlan.serializer()), json) }.getOrDefault(emptyList())
        }
        private set(v) = prefs.set("goal.history", AppJson.encodeToString(ListSerializer(GoalPlan.serializer()), v))

    init {
        if (history.isEmpty()) history = listOf(currentPlan(LocalDate.MIN))
    }

    private fun currentPlan(from: LocalDate) = GoalPlan(
        from = GoalPlan.startOf(from), kcal = kcal, protein = protein, carbs = carbs, fat = fat,
        weekdayKcal = if (weekdayEnabled) weekdayKcal else emptyMap(),
        activityPercent = if (activityEnabled) activityPercent else 0.0,
    )

    /** Stores the current targets as valid from today (same-day edits replace each other). */
    fun recordPlan() {
        val today = LocalDate.now()
        val h = history.toMutableList()
        val plan = currentPlan(today)
        val last = h.lastOrNull()
        if (last != null && last.sameTargets(plan)) return
        if (last != null && !last.fromDate.isBefore(today)) h[h.size - 1] = plan else h += plan
        history = h
    }

    // MARK: Goal of a day

    /** The goal of a day including the weekly budget (when switched on). */
    fun target(day: LocalDate): DayTarget {
        val t = coreTarget(day)
        val adj = WeekBudget.adjustment(day) { coreTarget(it).kcal }
        if (adj == 0.0) return t
        // Protein stays; carbs and fat take the difference in their usual ratio.
        val rest = t.kcal - t.protein * 4
        val factor = if (rest > 0) max(0.0, (rest + adj) / rest) else 1.0
        return t.copy(kcal = t.kcal + adj, carbs = Math.round(t.carbs * factor).toDouble(), fat = Math.round(t.fat * factor).toDouble(), weekAdjust = adj)
    }

    /** The goal of a day without the weekly budget. */
    private fun coreTarget(day: LocalDate): DayTarget {
        val plan = if (!day.isBefore(LocalDate.now())) currentPlan(day)
            else history.lastOrNull { !it.fromDate.isAfter(day) } ?: history.firstOrNull() ?: currentPlan(day)
        val base = plan.weekdayKcal[day.iosWeekday] ?: plan.kcal
        val health = if (activityEnabled) ActivityStore.kcal(day) else 0.0
        val manual = ActivityStore.manual(day)
        // Manual activity counts with the same share as tracked activity. Without Health Connect there is no share, so it counts in full.
        val manualPercent = if (activityEnabled || plan.activityPercent > 0) plan.activityPercent else 100.0
        val bonus = Math.round(health * plan.activityPercent / 100 + manual * manualPercent / 100).toDouble()
        val total = base + bonus
        // Protein stays; the extra/missing energy is shared by carbs and fat in their usual ratio.
        val delta = total - plan.kcal
        val carbE = plan.carbs * 4
        val fatE = plan.fat * 9
        val share = if (carbE + fatE > 0) carbE / (carbE + fatE) else 0.6
        return DayTarget(
            kcal = total, protein = plan.protein,
            carbs = max(0.0, Math.round(plan.carbs + delta * share / 4).toDouble()),
            fat = max(0.0, Math.round(plan.fat + delta * (1 - share) / 9).toDouble()),
            baseKcal = base, activeKcal = health + manual, healthKcal = health, manualKcal = manual, activityBonus = bonus,
            activityPercent = plan.activityPercent,
        )
    }

    /** Activity data arrived – targets read it from the observable settings, so screens update on their own. */
    fun activityUpdated() = Unit

    /** Recomputes the gram targets from the percentages (percent mode only). */
    fun syncMacros() {
        if (macroMode != MacroMode.percent) return
        protein = Math.round(kcal * proteinPct / 100 / 4).toDouble()
        fat = Math.round(kcal * fatPct / 100 / 9).toDouble()
        carbs = Math.round(kcal * carbsPct / 100 / 4).toDouble()
    }

    /** Keeps percentages in sync when grams were edited directly. */
    fun syncPercentFromGrams() {
        val total = max(protein * 4 + carbs * 4 + fat * 9, 1.0)
        proteinPct = Math.round(protein * 4 / total * 100).toDouble()
        fatPct = Math.round(fat * 9 / total * 100).toDouble()
    }

    /** Mifflin-St Jeor */
    val bmr: Double get() = 10 * weightKG + 6.25 * heightCM - 5 * age + if (sex == Sex.male) 5 else -161
    val tdee: Double get() = bmr * activity.factor
    val suggestedKcal: Double get() = Math.round(max(1200.0, tdee + target.delta) / 10).toDouble() * 10

    fun applySuggestion() {
        kcal = suggestedKcal
        // protein ~1.8 g/kg (max 35 %), fat 28 %, rest carbs
        proteinPct = Math.round(min(weightKG * 1.8 * 4 / kcal * 100, 35.0)).toDouble()
        fatPct = 28.0
        val mode = macroMode
        macroMode = MacroMode.percent
        syncMacros()
        macroMode = mode
        waterML = (weightKG * 35 / 250).roundToInt() * 250
    }
}
