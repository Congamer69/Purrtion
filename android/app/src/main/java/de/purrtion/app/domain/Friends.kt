package de.purrtion.app.domain

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import de.purrtion.app.App
import de.purrtion.app.data.FoodEntry
import de.purrtion.app.model.AppJson
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.Nutrients
import de.purrtion.app.ui.pixel.CatMood
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import java.net.URLEncoder
import java.security.MessageDigest
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.math.min

/** The small snapshot of one user's stats that friends get to see. Same fields as on iOS. */
@Serializable
data class FriendStats(
    val streak: Double = 0.0,
    val goal7: Double = 0.0,
    val goal30: Double = 0.0,
    val score7: Double = 0.0,
    val protein7: Double = 0.0,
    val water7: Double = -1.0,
    val active7: Double = -1.0,
    val fiber7: Double = 0.0,
    val fruitveg7: Double = 0.0,
    val logged30: Double = 0.0,
    val weightTrend: Double? = null,
    val todayPct: Double = 0.0,
    val todayScore: Double = -1.0,
    val todayEntries: Double = 0.0,
    val todayKcal: Double = -1.0,
    val todayGoal: Double = -1.0,
    /** Last 7 days incl. today: 0 nothing, 1 in goal, 2 up to +5 %, 3 over. */
    val week: List<Double> = emptyList(),
    val mood: String = "idle",
    val day: String = "",
    /** Today's protein / carbs / fat in g and the matching goals, -1 = unknown (older app version). */
    val todayProtein: Double = -1.0,
    val todayCarbs: Double = -1.0,
    val todayFat: Double = -1.0,
    val goalProtein: Double = -1.0,
    val goalCarbs: Double = -1.0,
    val goalFat: Double = -1.0,
    /** What the cat wears ("hat,glasses,scarf"); older app versions ignore it. */
    val outfit: String? = null,
) {
    val isToday: Boolean get() = day == LocalDate.now().toString()
    val hasMacros: Boolean get() = todayProtein >= 0 && goalProtein > 0

    fun toMap(): Map<String, Any?> {
        val m = mutableMapOf<String, Any?>(
            "streak" to streak, "goal7" to goal7, "goal30" to goal30, "score7" to score7, "protein7" to protein7,
            "water7" to water7, "active7" to active7, "fiber7" to fiber7, "fruitveg7" to fruitveg7, "logged30" to logged30,
            "todayPct" to todayPct, "todayScore" to todayScore, "todayEntries" to todayEntries, "todayKcal" to todayKcal, "todayGoal" to todayGoal,
            "week" to week, "mood" to mood, "day" to day,
            "todayProtein" to todayProtein, "todayCarbs" to todayCarbs, "todayFat" to todayFat,
            "goalProtein" to goalProtein, "goalCarbs" to goalCarbs, "goalFat" to goalFat,
        )
        weightTrend?.let { m["weightTrend"] = it }
        outfit?.takeIf { it.isNotEmpty() }?.let { m["outfit"] = it }
        return m
    }

    companion object {
        fun from(d: Map<String, Any?>): FriendStats {
            fun n(k: String, def: Double = 0.0) = (d[k] as? Double) ?: def
            return FriendStats(n("streak"), n("goal7"), n("goal30"), n("score7"), n("protein7"), n("water7", -1.0), n("active7", -1.0),
                n("fiber7"), n("fruitveg7"), n("logged30"), d["weightTrend"] as? Double, n("todayPct"), n("todayScore", -1.0),
                n("todayEntries"), n("todayKcal", -1.0), n("todayGoal", -1.0),
                (d["week"] as? List<*>)?.mapNotNull { it as? Double } ?: emptyList(), d["mood"] as? String ?: "idle", d["day"] as? String ?: "",
                n("todayProtein", -1.0), n("todayCarbs", -1.0), n("todayFat", -1.0), n("goalProtein", -1.0), n("goalCarbs", -1.0), n("goalFat", -1.0), d["outfit"] as? String)
        }

        /** Computes my own stats from the local data. */
        suspend fun compute(goals: Goals, shareWeight: Boolean): FriendStats {
            val db = App.db
            val today = LocalDate.now()
            val start = today.minusDays(30)
            val entries = db.entries().range(start.toEpochDay(), today.toEpochDay())
            val byDay = entries.groupBy { it.day }
            val water = db.water().range(start.toEpochDay(), today.toEpochDay()).groupBy { it.day }.mapValues { it.value.sumOf { w -> w.ml } }
            fun day(offset: Int): LocalDate = today.minusDays(offset.toLong())
            fun status(d: LocalDate): Double {
                val es = byDay[d.toEpochDay()] ?: return 0.0
                return when (GoalStatus.of(es.sumOf { it.kcal }, goals.target(d).kcal)) {
                    GoalStatus.none -> 0.0
                    GoalStatus.within -> 1.0
                    GoalStatus.slightlyOver -> 2.0
                    GoalStatus.over -> 3.0
                }
            }
            val logged = db.entries().loggedDays(today.minusDays(400).toEpochDay()).toSet()
            var d = if (byDay[today.toEpochDay()] == null) day(1) else today
            var streak = 0
            while (d.toEpochDay() in logged) { streak++; d = d.minusDays(1) }

            val last7 = (1..7).map(::day)
            val last30 = (1..30).map(::day)
            val inGoal = { x: LocalDate -> status(x) in listOf(1.0, 2.0) }
            var s = FriendStats(
                streak = streak.toDouble(),
                goal7 = last7.count(inGoal).toDouble(),
                goal30 = Math.round(last30.count(inGoal) / 30.0 * 100).toDouble(),
                logged30 = last30.count { byDay[it.toEpochDay()] != null }.toDouble(),
                day = today.toString(),
            )
            val logged7 = last7.filter { byDay[it.toEpochDay()] != null }
            if (logged7.isNotEmpty()) {
                var score = 0.0; var protein = 0.0; var fiber = 0.0; var fv = 0.0
                for (x in logged7) {
                    val es = byDay[x.toEpochDay()] ?: emptyList()
                    val t = goals.target(x)
                    score += HealthScore.of(es, t.kcal, t.protein).score
                    val n = Nutrients.sum(es.map { it.nutrients })
                    protein += min(150.0, n.protein / maxOf(t.protein, 1.0) * 100)
                    fiber += n[NutrientKey.fiber] ?: 0.0
                    fv += es.sumOf { HealthScore.fruitVegGrams(it) }
                }
                val c = logged7.size.toDouble()
                s = s.copy(score7 = Math.round(score / c).toDouble(), protein7 = Math.round(protein / c).toDouble(),
                    fiber7 = Math.round(fiber / c).toDouble(), fruitveg7 = Math.round(fv / c).toDouble())
            }
            if (goals.waterEnabled) {
                val pct = last7.map { min(150.0, (water[it.toEpochDay()] ?: 0) / maxOf(goals.waterML, 1).toDouble() * 100) }
                s = s.copy(water7 = Math.round(pct.sum() / 7).toDouble())
            }
            val actives = last7.map { (if (goals.activityEnabled) ActivityStore.kcal(it) else 0.0) + ActivityStore.manual(it) }
            if (goals.activityEnabled || actives.any { it > 0 }) s = s.copy(active7 = Math.round(actives.sum() / 7).toDouble())
            if (shareWeight) {
                val wStart = today.minusDays(28)
                val zone = ZoneId.systemDefault()
                val startMillis = wStart.atStartOfDay(zone).toInstant().toEpochMilli()
                val pts = db.weights().all().filter { it.date >= startMillis }.map { (it.date - startMillis) / 86_400_000.0 to it.kg }
                if (pts.size >= 3) Expenditure.robustSlope(pts)?.let { s = s.copy(weightTrend = Math.round(it.slope * 7 * 100) / 100.0) }
            }
            val todays = byDay[today.toEpochDay()] ?: emptyList()
            val t = goals.target(today)
            val kcal = todays.sumOf { it.kcal }
            s = s.copy(
                todayPct = Math.round(kcal / maxOf(t.kcal, 1.0) * 100).toDouble(),
                todayKcal = Math.round(kcal).toDouble(), todayGoal = Math.round(t.kcal).toDouble(),
                todayEntries = todays.size.toDouble(),
                todayProtein = Math.round(todays.sumOf { it.protein }).toDouble(), todayCarbs = Math.round(todays.sumOf { it.carbs }).toDouble(),
                todayFat = Math.round(todays.sumOf { it.fat }).toDouble(),
                goalProtein = Math.round(t.protein).toDouble(), goalCarbs = Math.round(t.carbs).toDouble(), goalFat = Math.round(t.fat).toDouble(),
                todayScore = if (todays.isEmpty()) -1.0 else HealthScore.of(todays, t.kcal, t.protein).score.toDouble(),
                week = (6 downTo 0).map { status(day(it)) },
                mood = catMood(todays, t, water[today.toEpochDay()] ?: 0, goals, today,
                    BloodAlcohol.make(todays + (byDay[today.minusDays(1).toEpochDay()] ?: emptyList()), goals, null).value(System.currentTimeMillis())).key,
                outfit = Shop.currentOutfit.encoded,
            )
            return s
        }
    }
}

enum class GoalStatus {
    none, within, slightlyOver, over;

    companion object {
        fun of(kcal: Double, goal: Double): GoalStatus = when {
            kcal <= 0 -> none
            kcal <= goal -> within
            kcal <= goal * 1.05 -> slightlyOver
            else -> over
        }
    }
}

/** The cat that fits the day best: time of day, share of the goal, protein, water, activity, alcohol. */
fun catMood(entries: List<FoodEntry>, target: DayTarget, waterML: Int, goals: Goals, day: LocalDate,
            promille: Double = 0.0, now: LocalDateTime = LocalDateTime.now()): CatMood {
    val isToday = day == now.toLocalDate()
    val hour = now.hour
    val night = isToday && (hour >= 23 || hour < 5)
    if (isToday && promille >= 0.2) return CatMood.tipsy
    if (entries.isEmpty()) {
        if (!isToday || night) return CatMood.sleeping
        return if (hour < 11) CatMood.yawning else CatMood.hungry
    }
    val kcal = entries.sumOf { it.kcal }
    val protein = entries.sumOf { it.protein }
    val ratio = kcal / maxOf(target.kcal, 1.0)
    val proteinOK = protein >= target.protein * 0.9
    if (ratio > 1.15) return CatMood.stuffed
    if (ratio > 1.05) return CatMood.full
    if (night) return CatMood.sleeping
    if (ratio >= 0.95) return if (proteinOK) CatMood.proud else CatMood.content
    if (ratio >= 0.85) return if (proteinOK) CatMood.proud else CatMood.happy
    if (!isToday) return CatMood.idle
    if (target.activeKcal >= 600) return CatMood.sporty
    if (goals.waterEnabled && hour >= 15 && waterML < goals.waterML * 0.4) return CatMood.thirsty
    if ((hour >= 13 && ratio < 0.35) || (hour >= 18 && ratio < 0.6)) return CatMood.hungry
    return CatMood.idle
}

/** What can be compared on the friends page. */
enum class FriendMetric(val title: String, val short: String, val explanation: String, val scale: Double) {
    streak("Serie", "Serie", "Tage in Folge, an denen etwas eingetragen wurde.", 0.0),
    goal7("Im Ziel (7 Tage)", "Im Ziel", "Tage der letzten Woche im Kalorienziel (bis +5 %).", 7.0),
    score7("Health Score", "Score", "Ø Health Score der letzten 7 Tage.", 100.0),
    protein7("Protein", "Protein", "Ø Anteil des eigenen Proteinziels, letzte 7 Tage.", 100.0),
    water7("Wasser", "Wasser", "Ø Anteil des eigenen Wasserziels, letzte 7 Tage.", 100.0),
    active7("Aktivität", "Aktiv", "Ø Aktivitätskalorien pro Tag, letzte 7 Tage.", 0.0),
    fruitveg7("Obst & Gemüse", "Obst & Gemüse", "Ø Gramm Obst & Gemüse pro Tag, letzte 7 Tage.", 400.0),
    fiber7("Ballaststoffe", "Ballaststoffe", "Ø Gramm Ballaststoffe pro Tag, letzte 7 Tage.", 30.0),
    goal30("Zieltreue (30 Tage)", "Zieltreue", "Anteil der letzten 30 Tage im Kalorienziel.", 100.0),
    logged30("Fleiß (30 Tage)", "Fleiß", "Tage mit Einträgen in den letzten 30 Tagen.", 30.0);

    fun value(s: FriendStats): Double? = when (this) {
        streak -> s.streak
        goal7 -> s.goal7
        score7 -> s.score7.takeIf { it > 0 }
        protein7 -> s.protein7.takeIf { it > 0 }
        water7 -> s.water7.takeIf { it >= 0 }
        active7 -> s.active7.takeIf { it >= 0 }
        fruitveg7 -> s.fruitveg7
        fiber7 -> s.fiber7
        goal30 -> s.goal30
        logged30 -> s.logged30
    }

    fun format(v: Double): String = when (this) {
        streak -> "${v.toInt()} ${if (v.toInt() == 1) "Tag" else "Tage"}"
        goal7 -> "${v.toInt()}/7"
        score7 -> "${v.toInt()}"
        protein7, water7, goal30 -> "${v.toInt()} %"
        active7 -> "${v.toInt()} kcal"
        fruitveg7, fiber7 -> "${v.toInt()} g"
        logged30 -> "${v.toInt()}/30"
    }
}

/**
 * Friends page state and sync – same backend and request budget as on iOS: one own document (written only when it
 * changed, stats at most every 15 minutes), one query for all friends (at most every 3 minutes), cached locally.
 */
object FriendsStore {
    const val ENABLED_KEY = "friends.enabled"
    const val NAME_KEY = "friends.name"
    const val SHARE_WEIGHT_KEY = "friends.shareWeight"
    /** Own values are written at most this often (only when they changed). */
    private const val STATS_INTERVAL = 2 * 60_000L

    @Serializable
    data class Person(val id: String, val name: String, val palette: String, val stats: FriendStats, val updated: Long? = null)

    @Serializable
    data class Me(val code: String, val friends: List<String> = emptyList(), val hidden: List<String> = emptyList(),
                  val pendingLabels: Map<String, String> = emptyMap())

    data class IncomingCode(val code: String, val name: String?)

    var me by mutableStateOf(load(Me.serializer(), "friends.me")); private set
    var people by mutableStateOf(load(ListSerializer(Person.serializer()), "friends.cache") ?: emptyList()); private set
    var lastRefresh by mutableStateOf(App.prefs.double("friends.lastRefreshMillis", 0.0).toLong().takeIf { it > 0 }); private set
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null)
    var incomingCode by mutableStateOf<IncomingCode?>(null)

    private fun <T> load(s: kotlinx.serialization.KSerializer<T>, key: String): T? =
        App.prefs.optString(key)?.let { runCatching { AppJson.decodeFromString(s, it) }.getOrNull() }

    val isAvailable: Boolean get() = FirebaseConfig.isAvailable
    val isSetUp: Boolean get() = me != null && FirebaseAuth.hasAccount
    val uid: String? get() = FirebaseAuth.uid
    val name: String get() = App.prefs.string(NAME_KEY, "")

    val friends: List<Person> get() = people.filter { me?.friends?.contains(it.id) == true }
    val incoming: List<Person> get() = people.filter { me?.friends?.contains(it.id) != true && me?.hidden?.contains(it.id) != true }
    /** Requests I sent myself that were not answered yet. */
    val outgoing: List<Pair<String, String>>
        get() {
            val m = me ?: return emptyList()
            val answered = people.map { it.id }.toSet()
            return m.friends.filter { it !in answered && m.pendingLabels[it] != null }.map { it to (m.pendingLabels[it] ?: "") }
        }

    val inviteLink: String?
        get() {
            val code = me?.code ?: return null
            if (FirebaseConfig.inviteUrl.isEmpty()) return null
            val n = URLEncoder.encode(name, "UTF-8").replace("+", "%20")
            return FirebaseConfig.inviteUrl + code + if (n.isEmpty()) "" else "?n=$n"
        }

    private fun saveLocal() {
        App.prefs.set("friends.me", me?.let { AppJson.encodeToString(Me.serializer(), it) })
        App.prefs.set("friends.cache", AppJson.encodeToString(ListSerializer(Person.serializer()), people))
        App.prefs.set("friends.lastRefreshMillis", (lastRefresh ?: 0L).toDouble())
    }

    private suspend fun run(work: suspend () -> Unit) {
        busy = true
        try { work(); error = null }
        catch (e: kotlinx.coroutines.CancellationException) { }
        catch (e: Exception) { error = e.message }
        finally { busy = false }
    }

    // MARK: Setup

    suspend fun setUp() = run {
        FirebaseAuth.token()
        val uid = uid ?: throw FirebaseException.denied
        if (me == null) {
            val doc = runCatching { FirebaseREST.get("users/$uid") }.getOrNull()
            val code = doc?.get("code") as? String
            me = if (code != null) {
                if (name.isEmpty()) (doc["name"] as? String)?.let { App.prefs.set(NAME_KEY, it) }
                Me(code, (doc["friends"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(), (doc["hidden"] as? List<*>)?.filterIsInstance<String>() ?: emptyList())
            } else Me(createCode(uid))
            saveLocal()
        }
        upload(forced = true)
        fetch()
    }

    private suspend fun createCode(uid: String): String {
        val alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        repeat(5) {
            val code = (1..8).map { alphabet.random() }.joinToString("")
            try {
                FirebaseREST.create("codes", code, mapOf("uid" to uid))
                return code
            } catch (e: FirebaseException) {
                if (e !== FirebaseException.conflict) throw e
            }
        }
        throw FirebaseException("Serverfehler: Kein freier Code gefunden")
    }

    // MARK: Sync

    private var lastUpload: Long
        get() = App.prefs.double("friends.lastUploadMillis", 0.0).toLong()
        set(v) = App.prefs.set("friends.lastUploadMillis", v.toDouble())
    private var lastHash: String
        get() = App.prefs.string("friends.lastHash", "")
        set(v) = App.prefs.set("friends.lastHash", v)
    /**
     * A friend change (request, accept, remove) that has not reached the server yet. Retried on every refresh and
     * app start until it arrives, otherwise the other side keeps seeing "Anfrage gesendet".
     */
    private var needsUpload: Boolean
        get() = App.prefs.bool("friends.needsUpload")
        set(v) = App.prefs.set("friends.needsUpload", v)

    /** Open requests are checked more often, so an accepted request shows up quickly. */
    private val refreshInterval: Long get() = if (outgoing.isEmpty() && incoming.isEmpty() && !needsUpload) 3 * 60_000L else 30_000L
    /** People who still want to connect although I declined or removed them. */
    val declined: List<Person> get() = people.filter { me?.friends?.contains(it.id) != true && me?.hidden?.contains(it.id) == true }

    /** Writes my document if something changed (stats at most every 15 minutes unless forced). */
    suspend fun upload(forced: Boolean = false) {
        val force = forced || needsUpload
        val m = me ?: return
        val uid = uid ?: return
        if (!isAvailable || name.isEmpty()) return
        val sentName = name
        val stats = FriendStats.compute(App.goals, App.prefs.bool(SHARE_WEIGHT_KEY))
        val palette = App.prefs.string("catPalette", "ginger")
        val payload = listOf(name, palette, m.code, m.friends.joinToString(","), m.hidden.joinToString(","),
            AppJson.encodeToString(FriendStats.serializer(), stats)).joinToString("|")
        val hash = MessageDigest.getInstance("SHA-256").digest(payload.toByteArray()).joinToString("") { "%02x".format(it) }
        if (hash == lastHash && !needsUpload) return
        if (!force && System.currentTimeMillis() - lastUpload < STATS_INTERVAL) return
        FirebaseREST.set("users/$uid", mapOf(
            "name" to name, "palette" to palette, "code" to m.code, "friends" to m.friends, "hidden" to m.hidden,
            "stats" to stats.toMap(), "updated" to Instant.now(), "v" to 1,
        ))
        lastUpload = System.currentTimeMillis()
        // Another change (e.g. "Annehmen") may have come in while this was on its way. Then the server could now hold
        // the older list, so send the current one again instead of marking it as done.
        val now = me
        if (now == null || now.friends != m.friends || now.hidden != m.hidden || now.code != m.code || name != sentName) {
            needsUpload = true
            upload(forced = true)
            return
        }
        lastHash = hash
        needsUpload = false
    }

    /** Leaving the app: send the current values if anything changed (no waiting for the interval). */
    fun uploadIfNeeded() {
        if (!isSetUp || !App.prefs.bool(ENABLED_KEY, true)) return
        App.scope.launch { runCatching { upload(forced = true) } }
    }

    private var soon: kotlinx.coroutines.Job? = null

    /**
     * Something was logged, changed or deleted: send the new values a little later, so several quick changes go out
     * as one write and friends see them within a few minutes. Unchanged values never cause a write.
     */
    fun uploadSoon() {
        if (!isSetUp || !App.prefs.bool(ENABLED_KEY, true)) return
        soon?.cancel()
        soon = App.scope.launch {
            kotlinx.coroutines.delay(20_000)
            val wait = lastUpload + STATS_INTERVAL - System.currentTimeMillis()
            if (wait > 0) kotlinx.coroutines.delay(wait)
            runCatching { upload() }
        }
    }

    private suspend fun fetch() {
        val uid = uid ?: return
        val docs = FirebaseREST.query("users", "friends", uid)
        people = docs.map { (id, f) ->
            Person(id, f["name"] as? String ?: "?", f["palette"] as? String ?: "ginger",
                FriendStats.from((f["stats"] as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value } ?: emptyMap()),
                (f["updated"] as? Instant)?.toEpochMilli())
        }
        lastRefresh = System.currentTimeMillis()
        me?.let { m ->
            val answered = people.map { it.id }.toSet()
            me = m.copy(pendingLabels = m.pendingLabels.filterKeys { it !in answered })
        }
        saveLocal()
    }

    suspend fun refresh(force: Boolean = false) {
        if (!isSetUp) return
        val last = lastRefresh
        if (!force && last != null && System.currentTimeMillis() - last < refreshInterval) {
            // A pending friend change still goes out right away, with a visible error if it fails.
            if (needsUpload) run { upload() } else runCatching { upload() }
            return
        }
        // Pulling down also sends my own latest values right away.
        run { upload(forced = force); fetch() }
    }

    // MARK: Friend actions

    private suspend fun changeMe(change: (Me) -> Me) {
        val m = me ?: return
        me = change(m)
        needsUpload = true
        saveLocal()
        run { upload(forced = true) }
    }

    /** Sends a request to the owner of an invite code. */
    suspend fun addFriend(raw: String, label: String? = null): Boolean {
        val code = raw.uppercase().filter { it.isLetterOrDigit() }
        if (code.length != 8) { error = "Ein Code hat 8 Zeichen."; return false }
        if (code == me?.code) { error = "Das ist dein eigener Code. 😺"; return false }
        var ok = false
        run {
            val doc = try { FirebaseREST.get("codes/$code") } catch (e: FirebaseException) {
                if (e === FirebaseException.notFound) throw FirebaseException("Diesen Code gibt es nicht.") else throw e
            }
            val other = doc["uid"] as? String ?: throw FirebaseException.notFound
            val m = me ?: return@run
            if (m.friends.contains(other)) { ok = true; return@run }
            me = m.copy(friends = m.friends + other, hidden = m.hidden - other, pendingLabels = m.pendingLabels + (other to (label ?: "Code $code")))
            needsUpload = true
            saveLocal()
            upload(forced = true)
            fetch()
            ok = true
        }
        return ok
    }

    suspend fun accept(id: String) = changeMe { m -> m.copy(friends = if (id in m.friends) m.friends else m.friends + id, hidden = m.hidden - id) }

    suspend fun decline(id: String) = changeMe { m ->
        m.copy(friends = m.friends - id, hidden = if (id in m.hidden) m.hidden else m.hidden + id, pendingLabels = m.pendingLabels - id)
    }

    /** Removes a friend (or withdraws a request). They can no longer see my data. */
    suspend fun remove(id: String) = decline(id)

    /** Deletes my document, my code and the anonymous account. */
    suspend fun deleteAll() {
        run {
            uid?.let { u ->
                runCatching { FirebaseREST.delete("users/$u") }
                me?.code?.let { runCatching { FirebaseREST.delete("codes/$it") } }
            }
            FirebaseAuth.deleteAccount()
        }
        FirebaseAuth.signOut()
        me = null; people = emptyList(); lastRefresh = null
        lastHash = ""; lastUpload = 0; needsUpload = false
        listOf("friends.me", "friends.cache", "friends.lastRefreshMillis").forEach(App.prefs::remove)
    }

    /** purrtion://friend/ABCDEFGH?n=Name */
    fun handle(uri: android.net.Uri): Boolean {
        if (uri.scheme != "purrtion" || uri.host != "friend") return false
        val code = (uri.lastPathSegment ?: "").uppercase().filter { it.isLetterOrDigit() }
        if (code.length != 8) return false
        incomingCode = IncomingCode(code, uri.getQueryParameter("n"))
        return true
    }
}
