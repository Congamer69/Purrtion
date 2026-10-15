package de.purrtion.app.domain

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * The "real" daily energy expenditure, measured from what was eaten and how the weight changed – independent of
 * formulas and fitness trackers. Same model as on iOS:
 * 1. Weight trend: robust (Huber-weighted) linear regression over daily mean weights.
 * 2. Energy density of the weight change after Forbes / Hall (body fat estimated from BMI, age, sex).
 * 3. Intake: mean of fully logged days.
 * 4. Inverse-variance blend with a prior (Health Connect resting + active energy, or Mifflin-St Jeor × activity).
 * 5. Split into resting energy, thermic effect of food (≈10 %) and movement (the rest).
 */
data class ExpenditureEstimate(
    val total: Double,
    val basal: Double,
    val basalFromHealth: Boolean,
    val digestion: Double,
    val movement: Double,
    /** Mean active energy measured by Health Connect (+ manual) in the window, 0 when unknown. */
    val trackedActive: Double,
    val measured: Double?,
    val prior: Double,
    val measuredWeight: Double,
    val uncertainty: Double,
    val intake: Double,
    val weightPerWeek: Double?,
    val trendWeight: Double?,
    val energyDensity: Double,
    val windowDays: Int,
    val loggedDays: Int,
    val weighIns: Int,
    val missing: List<String>,
) {
    enum class Confidence(val label: String) { low("niedrig"), medium("mittel"), high("hoch") }

    val isMeasured: Boolean get() = measured != null
    /** movement / trackedActive – how much of the tracker's number is real (null without tracker data). */
    val trackerFactor: Double? get() = if (trackedActive > 50) movement / trackedActive else null
    val confidence: Confidence
        get() = if (!isMeasured) Confidence.low else if (uncertainty < 120) Confidence.high else if (uncertainty < 220) Confidence.medium else Confidence.low
}

object Expenditure {
    const val WINDOW = 28
    private const val MIN_LOGGED = 10
    private const val MIN_WEIGH_INS = 3
    private const val MIN_SPAN = 10

    data class Weight(val time: LocalDateTime, val kg: Double)
    data class Fit(val slope: Double, val intercept: Double, val slopeSE: Double)

    fun estimate(intakeByDay: Map<LocalDate, Double>, weights: List<Weight>, goals: Goals, activityEnabled: Boolean,
                 today: LocalDate = LocalDate.now()): ExpenditureEstimate {
        val end = today   // today is not finished → excluded
        fun weighInsSince(start: LocalDate) = weights.count { !it.time.toLocalDate().isBefore(start) && it.time.toLocalDate().isBefore(end) }
        var days = WINDOW
        while (days < 56 && weighInsSince(end.minusDays(days.toLong())) < 4) days += 7
        val start = end.minusDays(days.toLong())

        // Weight: one mean value per day.
        val perDay = weights.filter { !it.time.toLocalDate().isBefore(start) && it.time.toLocalDate().isBefore(end) }
            .groupBy { it.time.toLocalDate() }
        val points = perDay.map { (d, list) -> ChronoUnit.DAYS.between(start, d).toDouble() to list.map { it.kg }.average() }.sortedBy { it.first }
        val latestWeight = weights.maxByOrNull { it.time }?.kg ?: goals.weightKG

        val formulaBasal = mifflin(latestWeight, goals)
        val intakes = ArrayList<Double>()
        val actives = ArrayList<Double>()
        val basals = ArrayList<Double>()
        for (i in 0 until days) {
            val d = start.plusDays(i.toLong())
            actives += (if (activityEnabled) ActivityStore.kcal(d) else 0.0) + ActivityStore.manual(d)
            val b = if (activityEnabled) ActivityStore.basal(d) else 0.0
            if (b > 0) basals += b
            // Days far below the resting energy are almost always only partly logged.
            intakeByDay[d]?.let { if (it >= formulaBasal * 0.45) intakes += it }
        }
        val intake = if (intakes.isEmpty()) 0.0 else intakes.average()
        val trackedActive = actives.sum() / max(actives.size, 1)
        val healthBasal = if (basals.size >= days / 2) basals.average() else null

        val prior: Double
        val priorSD: Double
        if (healthBasal != null && trackedActive > 0) {
            prior = healthBasal + trackedActive + 0.1 * (if (intake > 0) intake else healthBasal * 1.4)
            priorSD = 260.0
        } else {
            prior = formulaBasal * goals.activity.factor
            priorSD = 330.0
        }

        val fit = if (points.size >= 2) robustSlope(points) else null
        val span = (points.lastOrNull()?.first ?: 0.0) - (points.firstOrNull()?.first ?: 0.0)
        val trendWeight = fit?.let { it.intercept + it.slope * (days - 1) } ?: latestWeight
        val rho = energyDensity(trendWeight, goals)

        val missing = mutableListOf<String>()
        if (intakes.size < MIN_LOGGED) missing += "${MIN_LOGGED - intakes.size} weitere Tage vollständig eintragen"
        if (points.size < MIN_WEIGH_INS) missing += "${MIN_WEIGH_INS - points.size} weitere Wiegungen"
        else if (span < MIN_SPAN) missing += "Wiegungen über mind. $MIN_SPAN Tage verteilt"

        var measured: Double? = null
        var result = prior
        var sd = priorSD
        var weight = 0.0
        if (missing.isEmpty() && fit != null) {
            val stored = fit.slope * rho
            val m = intake - stored
            val intakeSD = standardDeviation(intakes) / sqrt(intakes.size.toDouble())
            val coverage = intakes.size.toDouble() / days
            val missingDaysSD = intake * 0.12 * (1 - coverage)
            val loggingSD = intake * 0.05
            val mSD = sqrt((fit.slopeSE * rho).pow(2) + intakeSD.pow(2) + missingDaysSD.pow(2) + loggingSD.pow(2))
            if (m > 900 && m < 6000) {
                measured = m
                val wm = 1 / (mSD * mSD)
                val wp = 1 / (priorSD * priorSD)
                result = (m * wm + prior * wp) / (wm + wp)
                sd = sqrt(1 / (wm + wp))
                weight = wm / (wm + wp)
            }
        }

        val basal = healthBasal ?: mifflin(trendWeight, goals)
        val digestion = 0.1 * (if (intake > 0) intake else result * 0.9)
        var movement = result - basal - digestion
        var shownBasal = basal
        if (movement < 0) {
            shownBasal = max(0.0, result - digestion)
            movement = 0.0
        }
        return ExpenditureEstimate(
            total = result, basal = shownBasal, basalFromHealth = healthBasal != null, digestion = digestion, movement = movement,
            trackedActive = trackedActive, measured = measured, prior = prior, measuredWeight = weight, uncertainty = sd, intake = intake,
            weightPerWeek = fit?.let { it.slope * 7 }, trendWeight = if (fit != null) trendWeight else null, energyDensity = rho,
            windowDays = days, loggedDays = intakes.size, weighIns = points.size, missing = missing,
        )
    }

    fun mifflin(weight: Double, goals: Goals): Double =
        10 * weight + 6.25 * goals.heightCM - 5 * goals.age + if (goals.sex == Goals.Sex.male) 5 else -161

    /** kcal per kg of body weight change (Forbes partitioning, Hall energy contents). */
    fun energyDensity(weight: Double, goals: Goals): Double {
        val h = goals.heightCM / 100
        val bmi = weight / max(h * h, 0.5)
        val bodyFat = min(max(1.2 * bmi + 0.23 * goals.age - 10.8 * (if (goals.sex == Goals.Sex.male) 1 else 0) - 5.4, 5.0), 55.0) / 100
        val fatMass = weight * bodyFat
        val fatShare = fatMass / (fatMass + 10.4)
        return fatShare * 9440 + (1 - fatShare) * 1816
    }

    /** Linear regression with Huber weights (iteratively reweighted) – robust against water-weight outliers. */
    fun robustSlope(pts: List<Pair<Double, Double>>): Fit? {
        if (pts.size < 2) return null
        var w = DoubleArray(pts.size) { 1.0 }
        var fit = weightedFit(pts, w)
        repeat(4) {
            val f = fit ?: return null
            val residuals = pts.map { it.second - (f.intercept + f.slope * it.first) }
            val mad = median(residuals.map(::abs)) * 1.4826
            val k = 1.345 * max(mad, 0.25)
            w = DoubleArray(pts.size) { i -> if (abs(residuals[i]) <= k) 1.0 else k / abs(residuals[i]) }
            fit = weightedFit(pts, w)
        }
        return fit
    }

    private fun weightedFit(pts: List<Pair<Double, Double>>, w: DoubleArray): Fit? {
        val sw = w.sum()
        val mx = pts.indices.sumOf { pts[it].first * w[it] } / sw
        val my = pts.indices.sumOf { pts[it].second * w[it] } / sw
        val sxx = pts.indices.sumOf { w[it] * (pts[it].first - mx).pow(2) }
        if (sxx <= 0) return null
        val sxy = pts.indices.sumOf { w[it] * (pts[it].first - mx) * (pts[it].second - my) }
        val slope = sxy / sxx
        val intercept = my - slope * mx
        val n = pts.size.toDouble()
        val sse = pts.indices.sumOf { w[it] * (pts[it].second - (intercept + slope * pts[it].first)).pow(2) }
        val sigma2 = max(if (n > 2) sse / (sw * (n - 2) / n) else 0.25, 0.16)
        return Fit(slope, intercept, sqrt(sigma2 / sxx))
    }

    private fun median(v: List<Double>): Double {
        if (v.isEmpty()) return 0.0
        val s = v.sorted()
        return if (s.size % 2 == 1) s[s.size / 2] else (s[s.size / 2 - 1] + s[s.size / 2]) / 2
    }

    private fun standardDeviation(v: List<Double>): Double {
        if (v.size <= 1) return 400.0
        val m = v.average()
        return sqrt(v.sumOf { (it - m).pow(2) } / (v.size - 1))
    }
}
