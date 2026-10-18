package de.purrtion.app.domain

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Volume
import de.purrtion.app.App
import de.purrtion.app.data.WeightLog
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.Nutrients
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.security.MessageDigest
import java.time.Instant
import java.time.LocalDate
import java.time.Period
import java.time.ZoneId

/** Health Connect: weight both ways, active + resting energy, and (optionally) nutrition and water. */
object HealthConnect {
    const val WEIGHT_KEY = "health.weightSync"
    const val NUTRITION_KEY = "health.nutritionSync"

    val readPermissions = setOf(
        HealthPermission.getReadPermission(WeightRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(BasalMetabolicRateRecord::class),
    )
    val weightPermissions = setOf(HealthPermission.getReadPermission(WeightRecord::class), HealthPermission.getWritePermission(WeightRecord::class))
    val activityPermissions = setOf(
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(BasalMetabolicRateRecord::class),
    )
    val nutritionPermissions = setOf(
        HealthPermission.getWritePermission(NutritionRecord::class), HealthPermission.getReadPermission(NutritionRecord::class),
        HealthPermission.getWritePermission(HydrationRecord::class), HealthPermission.getReadPermission(HydrationRecord::class),
    )

    fun isAvailable(context: Context = App.context): Boolean =
        HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE

    private val client: HealthConnectClient? get() = if (isAvailable()) HealthConnectClient.getOrCreate(App.context) else null

    suspend fun granted(): Set<String> = runCatching { client?.permissionController?.getGrantedPermissions() ?: emptySet() }.getOrDefault(emptySet())

    private val zone: ZoneId get() = ZoneId.systemDefault()

    // MARK: Weight

    /** Imports weights that aren't in the app yet (one per day). */
    suspend fun importWeights() {
        if (!App.prefs.bool(WEIGHT_KEY)) return
        val c = client ?: return
        val start = Instant.now().minus(Period.ofDays(730))
        val records = runCatching {
            c.readRecords(ReadRecordsRequest(WeightRecord::class, TimeRangeFilter.after(start))).records
        }.getOrNull() ?: return
        val existing = App.db.weights().all().map { Instant.ofEpochMilli(it.date).atZone(zone).toLocalDate() }.toMutableSet()
        val new = mutableListOf<WeightLog>()
        for (r in records) {
            if (r.metadata.dataOrigin.packageName == App.context.packageName) continue
            val day = r.time.atZone(zone).toLocalDate()
            if (!existing.add(day)) continue
            new += WeightLog(date = r.time.toEpochMilli(), kg = Math.round(r.weight.inKilograms * 10) / 10.0)
        }
        if (new.isNotEmpty()) App.db.weights().insertAll(new)
    }

    suspend fun saveWeight(kg: Double, time: Instant) {
        if (!App.prefs.bool(WEIGHT_KEY)) return
        val c = client ?: return
        runCatching {
            c.insertRecords(listOf(WeightRecord(time = time, zoneOffset = zone.rules.getOffset(time), weight = Mass.kilograms(kg),
                metadata = Metadata())))
        }
    }

    // MARK: Activity

    /** Loads daily sums of active and resting energy for the last [days] days into [ActivityStore]. */
    suspend fun refreshActivity(days: Long = 120): Boolean {
        val c = client ?: return false
        val end = LocalDate.now().plusDays(1).atStartOfDay()
        val start = end.minusDays(days)
        return runCatching {
            val active = c.aggregateGroupByPeriod(AggregateGroupByPeriodRequest(
                metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(start, end), timeRangeSlicer = Period.ofDays(1)))
                .associate { it.startTime.toLocalDate() to Math.round(it.result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0).toDouble() }
            val basal = runCatching {
                c.aggregateGroupByPeriod(AggregateGroupByPeriodRequest(
                    metrics = setOf(BasalMetabolicRateRecord.BASAL_CALORIES_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(start, end), timeRangeSlicer = Period.ofDays(1)))
                    .associate { it.startTime.toLocalDate() to Math.round(it.result[BasalMetabolicRateRecord.BASAL_CALORIES_TOTAL]?.inKilocalories ?: 0.0).toDouble() }
            }.getOrDefault(emptyMap())
            ActivityStore.store(active, basal.filterValues { it > 0 })
            true
        }.getOrDefault(false)
    }

    // MARK: Nutrition

    internal suspend fun writeNutrition(records: List<NutritionRecord>, water: HydrationRecord?, deleteIds: List<String>) {
        val c = client ?: return
        if (deleteIds.isNotEmpty()) runCatching { c.deleteRecords(NutritionRecord::class, emptyList(), deleteIds) }
        val all = records + listOfNotNull(water)
        if (all.isNotEmpty()) runCatching { c.insertRecords(all) }
    }

    internal suspend fun ownNutrition(day: LocalDate): List<NutritionRecord> {
        val c = client ?: return emptyList()
        val start = day.atStartOfDay(zone).toInstant()
        val end = day.plusDays(1).atStartOfDay(zone).toInstant()
        return runCatching {
            c.readRecords(ReadRecordsRequest(NutritionRecord::class, TimeRangeFilter.between(start, end))).records
                .filter { it.metadata.dataOrigin.packageName == App.context.packageName }
        }.getOrDefault(emptyList())
    }

    internal fun nutritionRecord(n: Nutrients, name: String, time: Instant, clientId: String, version: Long): NutritionRecord {
        fun g(k: NutrientKey) = n[k]?.takeIf { it > 0 }?.let { Mass.grams(it) }
        fun mg(k: NutrientKey) = n[k]?.takeIf { it > 0 }?.let { Mass.milligrams(it) }
        fun ug(k: NutrientKey) = n[k]?.takeIf { it > 0 }?.let { Mass.micrograms(it) }
        val offset = zone.rules.getOffset(time)
        return NutritionRecord(
            startTime = time, startZoneOffset = offset, endTime = time.plusSeconds(60), endZoneOffset = offset,
            name = name, energy = Energy.kilocalories(n.kcal), protein = Mass.grams(n.protein),
            totalCarbohydrate = Mass.grams(n.carbs), totalFat = Mass.grams(n.fat),
            sugar = g(NutrientKey.sugar), dietaryFiber = g(NutrientKey.fiber), saturatedFat = g(NutrientKey.saturatedFat),
            monounsaturatedFat = g(NutrientKey.monoFat), polyunsaturatedFat = g(NutrientKey.polyFat), transFat = g(NutrientKey.transFat),
            cholesterol = mg(NutrientKey.cholesterol), sodium = mg(NutrientKey.sodium), potassium = mg(NutrientKey.potassium),
            calcium = mg(NutrientKey.calcium), magnesium = mg(NutrientKey.magnesium), iron = mg(NutrientKey.iron), zinc = mg(NutrientKey.zinc),
            phosphorus = mg(NutrientKey.phosphorus), iodine = ug(NutrientKey.iodine), selenium = ug(NutrientKey.selenium),
            copper = mg(NutrientKey.copper), manganese = mg(NutrientKey.manganese),
            vitaminA = ug(NutrientKey.vitaminA), vitaminC = mg(NutrientKey.vitaminC), vitaminD = ug(NutrientKey.vitaminD),
            vitaminE = mg(NutrientKey.vitaminE), vitaminK = ug(NutrientKey.vitaminK), thiamin = mg(NutrientKey.vitaminB1),
            riboflavin = mg(NutrientKey.vitaminB2), niacin = mg(NutrientKey.vitaminB3), pantothenicAcid = mg(NutrientKey.vitaminB5),
            vitaminB6 = mg(NutrientKey.vitaminB6), biotin = ug(NutrientKey.biotin), vitaminB12 = ug(NutrientKey.vitaminB12),
            folate = ug(NutrientKey.folate), caffeine = mg(NutrientKey.caffeine),
            metadata = Metadata(clientRecordId = clientId, clientRecordVersion = version),
        )
    }

    internal fun waterRecord(day: LocalDate, ml: Int, clientId: String, version: Long): HydrationRecord {
        val t = day.atTime(12, 0).atZone(zone).toInstant()
        val offset = zone.rules.getOffset(t)
        return HydrationRecord(startTime = t, startZoneOffset = offset, endTime = t.plusSeconds(60), endZoneOffset = offset,
            volume = Volume.milliliters(ml.toDouble()), metadata = Metadata(clientRecordId = clientId, clientRecordVersion = version))
    }
}

/**
 * Writes every logged entry as a nutrition record (energy, macros, micronutrients) and the daily water to Health Connect.
 * Each entry has a stable client record id, so edits replace the record and deleted entries are removed again.
 */
object NutritionSync {
    private val pending = mutableSetOf<LocalDate>()
    private var job: Job? = null

    val isEnabled: Boolean get() = App.prefs.bool(HealthConnect.NUTRITION_KEY) && HealthConnect.isAvailable()

    /** Debounced sync of one day (called whenever the entries of a day change). */
    fun schedule(day: LocalDate) {
        if (!isEnabled) return
        synchronized(pending) { pending += day }
        job?.cancel()
        job = App.scope.launch {
            delay(2000)
            val days = synchronized(pending) { pending.toList().also { pending.clear() } }
            days.forEach { sync(it) }
        }
    }

    suspend fun syncRecent(days: Int) {
        if (!isEnabled) return
        val today = LocalDate.now()
        for (i in 0 until days) sync(today.minusDays(i.toLong()))
    }

    private fun hash(s: String): Long {
        val d = MessageDigest.getInstance("SHA-256").digest(s.toByteArray())
        return d.take(7).fold(0L) { acc, b -> (acc shl 8) or (b.toLong() and 0xff) }
    }

    suspend fun sync(day: LocalDate) {
        if (!isEnabled) return
        val zone = ZoneId.systemDefault()
        val entries = App.db.entries().day(day.toEpochDay())
        val water = App.db.water().day(day.toEpochDay()).sumOf { it.ml }
        val existing = HealthConnect.ownNutrition(day)
        val dayStart = day.atStartOfDay(zone).toInstant().toEpochMilli()
        val dayEnd = day.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
        val keep = HashSet<String>()
        val records = mutableListOf<androidx.health.connect.client.records.NutritionRecord>()
        for (e in entries) {
            val id = "purrtion-${e.id}"
            keep += id
            val n = e.nutrients
            val time = if (e.createdAt in dayStart until dayEnd) e.createdAt else dayStart + 12 * 3_600_000L
            // Unchanged entries are skipped. Changed ones get a newer version: Health Connect only replaces a record
            // when the version is higher (a content hash as version could be lower and was then silently ignored).
            val content = hash("${e.name}|$time|${n.kcal}|${n.protein}|${n.carbs}|${n.fat}|${n.extra.toSortedMap()}")
            val same = existing.filter { it.metadata.clientRecordId == id }
            if (same.size == 1 && App.prefs.double("hc.n.$id", 0.0).toLong() == content) continue
            records += HealthConnect.nutritionRecord(n, e.name, Instant.ofEpochMilli(time), id, System.currentTimeMillis())
            App.prefs.set("hc.n.$id", content.toDouble())
        }
        val waterRecord = if (water > 0) HealthConnect.waterRecord(day, water, "purrtion-water-$day", System.currentTimeMillis()) else null
        val orphans = existing.mapNotNull { r -> r.metadata.clientRecordId?.takeIf { it !in keep } }
        HealthConnect.writeNutrition(records, waterRecord, orphans)
    }
}

