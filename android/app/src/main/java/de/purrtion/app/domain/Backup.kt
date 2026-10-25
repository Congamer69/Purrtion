package de.purrtion.app.domain

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Base64
import androidx.documentfile.provider.DocumentFile
import de.purrtion.app.App
import de.purrtion.app.data.CustomFood
import de.purrtion.app.data.DayReview
import de.purrtion.app.data.FoodEntry
import de.purrtion.app.data.JsonCache
import de.purrtion.app.data.SavedFood
import de.purrtion.app.data.WaterLog
import de.purrtion.app.data.WeightLog
import de.purrtion.app.data.newId
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.format
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Full JSON backup of all data + settings – the same format as the iOS app, so a backup can move between
 * iPhone and Android. Written automatically (about once a day) into a folder the user picked once.
 */
object Backup {
    const val FILE_NAME = "Purrtion-Backup.json"
    private const val PREVIOUS_NAME = "Purrtion-Backup-Vorher.json"
    const val AUTO_KEY = "backup.auto"
    private const val FOLDER_KEY = "backup.folderUri"
    private const val LAST_KEY = "backup.lastMillis"
    private val settingPrefixes = listOf("goal.", "profile.", "vision.", "source.", "activity.", "catPalette", "dogUnlocked", "theme.", "startTab", "haptics", "stats.layout", "profile.", "appearance", "onboarded", "health.", "friends.", "extras.", "weight.", "shop.")

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; explicitNulls = false; prettyPrint = false }

    @Serializable
    data class Payload(
        val version: Int = 1,
        val createdAt: String = iso(System.currentTimeMillis()),
        val entries: List<Entry> = emptyList(),
        val saved: List<Saved> = emptyList(),
        val custom: List<Custom> = emptyList(),
        val water: List<Water> = emptyList(),
        val weights: List<Weight> = emptyList(),
        val reviews: List<Review>? = null,
        val settings: Map<String, String> = emptyMap(),
        /** The friends login, encrypted with the backup password (see [BackupVault]). Absent without a password. */
        val friendsAccount: String? = null,
    )

    @Serializable data class Entry(val day: String, val createdAt: String, val name: String, val brand: String? = null,
        val quantity: Double, val servingName: String, val servingGrams: Double, val kcal: Double, val protein: Double,
        val carbs: Double, val fat: Double, val foodData: String? = null, val ingredientsData: String? = null)
    @Serializable data class Saved(val key: String, val name: String, val brand: String? = null, val kcalPer100: Double,
        val foodData: String? = null, val lastUsed: String, val useCount: Int, val isFavorite: Boolean, val lastQuantity: Double,
        val lastServingName: String)
    @Serializable data class Custom(val id: String, val name: String, val brand: String? = null, val isRecipe: Boolean,
        val createdAt: String, val foodData: String? = null, val ingredientsData: String? = null, val portions: Int)
    @Serializable data class Water(val day: String, val ml: Int)
    @Serializable data class Weight(val date: String, val kg: Double)
    @Serializable data class Review(val day: String, val createdAt: String, val rating: String, val tone: String,
        val pointsData: String? = null, val signature: String, val enrichedCount: Int, val providerName: String,
        val score: Int? = null, val scoreBefore: Int? = null, val automatic: Boolean? = null)

    // MARK: Conversions (iOS writes Dates as ISO-8601 and Data as base64)

    private val zone get() = ZoneId.systemDefault()
    fun iso(millis: Long): String = Instant.ofEpochMilli(millis).truncatedTo(ChronoUnit.SECONDS).toString()
    private fun isoDay(epochDay: Long): String = iso(LocalDate.ofEpochDay(epochDay).atStartOfDay(zone).toInstant().toEpochMilli())
    private fun millis(iso: String): Long = runCatching { Instant.parse(iso).toEpochMilli() }.getOrDefault(System.currentTimeMillis())
    private fun epochDay(iso: String): Long = Instant.ofEpochMilli(millis(iso)).atZone(zone).toLocalDate().toEpochDay()
    private fun b64(text: String?): String? = text?.let { Base64.encodeToString(it.toByteArray(), Base64.NO_WRAP) }
    private fun unb64(data: String?): String? = data?.let { runCatching { String(Base64.decode(it, Base64.DEFAULT)) }.getOrNull() }

    suspend fun makePayload(): Payload {
        val db = App.db
        return Payload(
            entries = db.entries().all().map {
                Entry(isoDay(it.day), iso(it.createdAt), it.name, it.brand, it.quantity, it.servingName, it.servingGrams,
                    it.kcal, it.protein, it.carbs, it.fat, b64(it.foodJson), b64(it.ingredientsJson))
            },
            saved = db.saved().all().map {
                Saved(it.key, it.name, it.brand, it.kcalPer100, b64(it.foodJson), iso(it.lastUsed), it.useCount, it.isFavorite, it.lastQuantity, it.lastServingName)
            },
            custom = db.custom().all().map {
                Custom(it.id, it.name, it.brand, it.isRecipe, iso(it.createdAt), b64(it.foodJson), b64(it.ingredientsJson), it.portions)
            },
            water = db.water().all().map { Water(isoDay(it.day), it.ml) },
            weights = db.weights().all().map { Weight(iso(it.date), it.kg) },
            reviews = db.reviews().all().map {
                Review(isoDay(it.day), iso(it.createdAt), it.rating, it.tone, b64(it.pointsJson), it.signature, it.enrichedCount,
                    it.providerName, it.score, it.scoreBefore, it.automatic)
            },
            settings = App.prefs.export(settingPrefixes).filterKeys { it != FOLDER_KEY && it != "friends.server" },
            friendsAccount = BackupVault.password?.let { password ->
                val uid = Secrets.get("fb.uid"); val refresh = Secrets.get("fb.refresh")
                if (uid != null && refresh != null) runCatching { BackupVault.seal(BackupVault.Account(uid, refresh), password) }.getOrNull() else null
            },
        )
    }

    /** True when the backup file holds an encrypted friends login (the restore then asks for the password). */
    fun hasFriendsAccount(text: String): Boolean = runCatching { json.decodeFromString(Payload.serializer(), text).friendsAccount != null }.getOrDefault(false)

    suspend fun data(): String = encode(makePayload())

    fun encode(p: Payload): String = json.encodeToString(Payload.serializer(), p)

    /** Replaces all local data with the backup. With a [password] the friends login is restored too; a wrong one throws before anything is replaced. */
    suspend fun restore(text: String, password: String? = null): Payload {
        val p = json.decodeFromString(Payload.serializer(), text)
        val account = p.friendsAccount?.let { sealed -> password?.takeIf { it.isNotEmpty() }?.let { BackupVault.open(sealed, it) } }
        val db = App.db
        db.entries().deleteAll(); db.saved().deleteAll(); db.custom().deleteAll(); db.water().deleteAll(); db.weights().deleteAll(); db.reviews().deleteAll()
        db.entries().upsertAll(p.entries.map {
            FoodEntry(id = newId(), day = epochDay(it.day), createdAt = millis(it.createdAt), name = it.name, brand = it.brand,
                quantity = it.quantity, servingName = it.servingName, servingGrams = it.servingGrams, kcal = it.kcal,
                protein = it.protein, carbs = it.carbs, fat = it.fat, foodJson = unb64(it.foodData), ingredientsJson = unb64(it.ingredientsData))
        })
        p.saved.forEach {
            db.saved().upsert(SavedFood(it.key, it.name, it.brand, it.kcalPer100, unb64(it.foodData), millis(it.lastUsed), it.useCount,
                it.isFavorite, it.lastQuantity, it.lastServingName))
        }
        p.custom.forEach {
            db.custom().upsert(CustomFood(it.id, it.name, it.brand, it.isRecipe, millis(it.createdAt), unb64(it.foodData),
                unb64(it.ingredientsData), it.portions))
        }
        p.water.forEach { db.water().insert(WaterLog(day = epochDay(it.day), ml = it.ml)) }
        db.weights().insertAll(p.weights.map { WeightLog(date = millis(it.date), kg = it.kg) })
        p.reviews?.forEach {
            db.reviews().put(DayReview(epochDay(it.day), millis(it.createdAt), it.rating, it.tone, unb64(it.pointsData), it.signature,
                it.enrichedCount, it.providerName, it.score, it.scoreBefore, it.automatic ?: false))
        }
        App.prefs.import(p.settings)
        if (account != null) {
            // The old account's cached friends are not this account's.
            listOf("friends.cache", "friends.me", "friends.lastRefresh", "friends.lastHash", "friends.lastUpload").forEach { App.prefs.remove(it) }
            FirebaseAuth.adopt(account.uid, account.refresh)
        }
        return p
    }

    // MARK: Backup folder (Storage Access Framework)

    val lastBackup: Long? get() = App.prefs.double(LAST_KEY, 0.0).toLong().takeIf { it > 0 }
    val folderUri: Uri? get() = App.prefs.optString(FOLDER_KEY)?.let(Uri::parse)
    fun folderName(context: Context): String? = folderUri?.let { DocumentFile.fromTreeUri(context, it)?.name }

    fun setFolder(context: Context, uri: Uri) {
        context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        App.prefs.set(FOLDER_KEY, uri.toString())
    }

    fun clearFolder() = App.prefs.remove(FOLDER_KEY)

    suspend fun writeToFolder(context: Context) {
        val tree = DocumentFile.fromTreeUri(context, folderUri ?: throw IllegalStateException("Kein Ordner")) ?: throw IllegalStateException()
        val existing = tree.findFile(FILE_NAME)
        val file = existing ?: tree.createFile("application/json", FILE_NAME) ?: throw IllegalStateException()
        val text = data()
        // A fresh app pointed at the old backup folder would overwrite the good backup with its almost empty data.
        // If the new backup holds much less than the one in the folder, the old file is kept as "Purrtion-Backup-Vorher.json".
        if (existing != null) runCatching {
            val old = context.contentResolver.openInputStream(existing.uri)?.use { it.readBytes().decodeToString() } ?: return@runCatching
            val oldCount = json.decodeFromString(Payload.serializer(), old).entries.size
            val newCount = json.decodeFromString(Payload.serializer(), text).entries.size
            if (oldCount > 0 && newCount < oldCount / 2) {
                val keep = tree.findFile(PREVIOUS_NAME) ?: tree.createFile("application/json", PREVIOUS_NAME)
                keep?.let { k -> context.contentResolver.openOutputStream(k.uri, "wt")?.use { it.write(old.toByteArray()) } }
            }
        }
        context.contentResolver.openOutputStream(file.uri, "wt")?.use { it.write(text.toByteArray()) } ?: throw IllegalStateException()
        App.prefs.set(LAST_KEY, System.currentTimeMillis().toDouble())
    }

    /** Called when the app becomes active: backs up if the last backup is older than ~a day. */
    suspend fun autoBackupIfNeeded(context: Context) {
        if (!App.prefs.bool(AUTO_KEY) || folderUri == null) return
        val last = lastBackup
        if (last != null && System.currentTimeMillis() - last < 20 * 3600 * 1000L) return
        runCatching { writeToFolder(context) }
    }
}

/** CSV export for Excel & co (semicolon separated, German decimal comma). */
object CsvExport {
    suspend fun files(context: Context): List<File> {
        val dir = File(context.cacheDir, "Purrtion-Export").apply { deleteRecursively(); mkdirs() }
        val df = DateTimeFormatter.ofPattern("yyyy-MM-dd")
        val tf = DateTimeFormatter.ofPattern("HH:mm")
        val zone = ZoneId.systemDefault()
        fun num(v: Double?) = v?.format(2, grouping = false) ?: ""
        fun esc(s: String?): String {
            val t = s ?: ""
            return if (t.contains(";") || t.contains("\"") || t.contains("\n")) "\"${t.replace("\"", "\"\"")}\"" else t
        }
        val extraKeys = listOf(NutrientKey.fiber, NutrientKey.sugar, NutrientKey.saturatedFat, NutrientKey.salt, NutrientKey.potassium,
            NutrientKey.calcium, NutrientKey.magnesium, NutrientKey.iron, NutrientKey.zinc, NutrientKey.vitaminC, NutrientKey.vitaminD,
            NutrientKey.vitaminB12, NutrientKey.folate)
        val entries = App.db.entries().all()
        val rows = mutableListOf((listOf("Datum", "Uhrzeit", "Lebensmittel", "Marke", "Menge", "Portion", "Gramm/ml", "kcal", "Protein g",
            "Kohlenhydrate g", "Fett g") + extraKeys.map { "${it.label} ${it.unit}" }).joinToString(";"))
        for (e in entries) {
            val n = e.nutrients
            val time = Instant.ofEpochMilli(e.createdAt).atZone(zone)
            rows += (listOf(e.date.format(df), time.format(tf), esc(e.name), esc(e.brand), num(e.quantity), esc(e.servingName),
                num(e.grams), num(e.kcal), num(e.protein), num(e.carbs), num(e.fat)) + extraKeys.map { num(n[it]) }).joinToString(";")
        }
        val food = File(dir, "Purrtion-Essen.csv").apply { writeText("﻿" + rows.joinToString("\n")) }

        val water = App.db.water().all().groupBy { it.day }.mapValues { it.value.sumOf { w -> w.ml } }
        val days = mutableListOf("Datum;kcal;Protein g;Kohlenhydrate g;Fett g;Wasser ml")
        for ((day, list) in entries.groupBy { it.day }.toSortedMap()) {
            days += listOf(LocalDate.ofEpochDay(day).format(df), num(list.sumOf { it.kcal }), num(list.sumOf { it.protein }),
                num(list.sumOf { it.carbs }), num(list.sumOf { it.fat }), "${water[day] ?: 0}").joinToString(";")
        }
        val dayFile = File(dir, "Purrtion-Tage.csv").apply { writeText("﻿" + days.joinToString("\n")) }

        val weights = mutableListOf("Datum;Gewicht kg")
        for (w in App.db.weights().all()) weights += "${Instant.ofEpochMilli(w.date).atZone(zone).toLocalDate().format(df)};${num(w.kg)}"
        val weightFile = File(dir, "Purrtion-Gewicht.csv").apply { writeText("﻿" + weights.joinToString("\n")) }
        return listOf(food, dayFile, weightFile)
    }
}
