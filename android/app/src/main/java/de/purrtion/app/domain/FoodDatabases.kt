package de.purrtion.app.domain

import de.purrtion.app.App
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.ServingOption
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File

/** Reads a bundled database file – or the newer one downloaded by [DatabaseUpdater]. */
internal fun readDatabase(name: String): String? {
    val local = File(File(App.context.filesDir, "Databases"), "$name.json")
    if (local.exists()) return runCatching { local.readText() }.getOrNull()
    return runCatching { App.context.assets.open("$name.json").bufferedReader().use { it.readText() } }.getOrNull()
}

private fun nutrientsFrom(keys: List<String>, values: List<Double?>): Nutrients {
    var kcal = 0.0; var protein = 0.0; var carbs = 0.0; var fat = 0.0
    val extra = mutableMapOf<String, Double>()
    for ((k, key) in keys.withIndex()) {
        val v = values.getOrNull(k) ?: continue
        when (key) {
            "kcal" -> kcal = v
            "protein" -> protein = v
            "carbs" -> carbs = v
            "fat" -> fat = v
            else -> extra[key] = v
        }
    }
    return Nutrients(kcal, protein, carbs, fat, extra)
}

private fun doubles(arr: JsonArray): List<Double?> = arr.map { if (it is JsonNull) null else (it as? JsonPrimitive)?.doubleOrNull }

/**
 * Bundeslebensmittelschlüssel 4.0 (Max Rubner-Institut, CC BY 4.0) – the official German nutrient database:
 * ~7,100 foods with up to 138 lab-analysed nutrients. Bundled with the app, works offline.
 */
object BlsDatabase {
    const val attribution = "Max Rubner-Institut (2025): Bundeslebensmittelschlüssel (BLS), Version 4.0 – Deutsche Nährstoffdatenbank. Karlsruhe. DOI: 10.25826/Data20251217-134202-0 · Lizenz CC BY 4.0"

    private var codes: List<String> = emptyList()
    private var names: List<String> = emptyList()
    private var folded: List<String> = emptyList()
    private var values: List<List<Double?>> = emptyList()
    private var keys: List<String> = emptyList()
    private var indexByCode: Map<String, Int> = emptyMap()
    @Volatile private var loaded = false
    private val lock = Any()

    fun preload() { App.scope.launch(Dispatchers.IO) { loadIfNeeded() } }

    private fun loadIfNeeded() { synchronized(lock) { loadLocked() } }

    private fun loadLocked() {
        if (loaded) return
        loaded = true
        val text = readDatabase("bls") ?: return
        val json = runCatching { Json.parseToJsonElement(text).jsonObject }.getOrNull() ?: return
        keys = json["keys"]?.jsonArray?.map { it.jsonPrimitive.content } ?: return
        val c = ArrayList<String>(7500); val n = ArrayList<String>(7500); val f = ArrayList<String>(7500); val v = ArrayList<List<Double?>>(7500)
        val idx = HashMap<String, Int>(9000)
        for (food in json["foods"]?.jsonArray ?: return) {
            val a = food.jsonArray
            if (a.size != 3) continue
            val code = a[0].jsonPrimitive.content
            val name = a[1].jsonPrimitive.content
            idx[code] = c.size
            c += code; n += name; f += fold(name); v += doubles(a[2].jsonArray)
        }
        codes = c; names = n; folded = f; values = v; indexByCode = idx
    }

    /** Drops the loaded data so the next search reads the (updated) file again. */
    fun reload() {
        synchronized(lock) { loaded = false; codes = emptyList(); names = emptyList(); folded = emptyList(); values = emptyList() }
        preload()
    }

    fun food(code: String): FoodItem? {
        loadIfNeeded()
        return indexByCode[code]?.let(::food)
    }

    private fun food(i: Int): FoodItem {
        val code = codes[i]
        val popular = PopularFoods.byCode[code]
        val unit = popular?.unit ?: unit(code, names[i])
        return FoodItem(
            id = "bls-$code", name = popular?.name ?: names[i], source = FoodSource.bls,
            per100 = nutrientsFrom(keys, values[i]), unit = unit,
            servings = popular?.servings ?: defaultServings(code, names[i], unit),
            origin = if (popular != null) names[i] else null,
        )
    }

    fun search(query: String, limit: Int = 40): List<FoodItem> {
        loadIfNeeded()
        val tokens = SearchMatcher.tokens(fold(query).trim())
        if (tokens.isEmpty()) return emptyList()
        val phrase = tokens.joinToString(" ")
        val scored = ArrayList<Pair<Int, Int>>()
        val strictHits = HashSet<Int>()
        for (i in folded.indices) {
            val name = folded[i]
            val popular = PopularFoods.byCode[codes[i]]
            val haystack = if (popular != null) name + " " + popular.searchText else name
            if (!tokens.all { haystack.contains(it) }) continue
            var score = 0
            val nameWords = words(name)
            val popularWords = popular?.searchTerms?.flatMap { it.split(" ") } ?: emptyList()
            val allWords = nameWords + popularWords
            // A token must start a word or a part of a German compound, not hide inside a syllable.
            if (!tokens.all { t -> allWords.any { SearchMatcher.strict(it, t) } }) continue
            val prefixHit = tokens.all { t -> allWords.any { it.startsWith(t) } }
            if (!prefixHit) score -= 150
            if (popular != null && prefixHit) {
                score += 600
                if (phrase in popular.searchTerms) score += 2000
                else if (popular.searchTerms.any { it.startsWith(phrase) }) score += 800
            }
            if (nameWords.firstOrNull()?.startsWith(tokens[0]) == true) score += 300
            if (name.startsWith(phrase)) score += 150
            for (t in tokens) if (nameWords.any { it == t }) score += 60
            if (name.contains(" roh")) score += 25
            if (codes[i].firstOrNull()?.let { it in "XY" } == true && tokens.size == 1) score -= 30
            score -= name.length * 2
            scored += i to score
            strictHits += i
        }
        // Second, forgiving pass: typos, plurals and split compounds ("Käsespätzle" → "Spätzle mit Käse").
        if (scored.size < 8) {
            for (i in folded.indices) {
                if (i in strictHits) continue
                val name = folded[i]
                if (!tokens.all { SearchMatcher.mayMatch(name, it) }) continue
                val w = words(name)
                if (!tokens.all { t -> w.any { SearchMatcher.relaxed(it, t) } || SearchMatcher.compound(t, name, w) }) continue
                scored += i to (-400 - name.length * 2)
            }
        }
        return scored.sortedByDescending { it.second }.take(limit).map { food(it.first) }
    }

    // MARK: Units & portions

    private fun unit(code: String, name: String): String {
        val n = name.lowercase()
        val c = code.firstOrNull() ?: return "g"
        if (c == 'N' || c == 'P') return "ml"
        if (n.contains("saft") || n.contains("nektar") || n.contains("smoothie") || n.endsWith("drink") ||
            n.contains("drink ") || n.contains("schorle")) return "ml"
        if (code.startsWith("M11") || code.startsWith("M13") || code.startsWith("M12")) return "ml"
        if (code.startsWith("Q1") || code.startsWith("Q2") || code.startsWith("Q3")) return "ml"
        return "g"
    }

    private fun s(vararg list: Pair<String, Double>) = list.map { ServingOption(it.first, it.second) }

    /** Sensible default portions by BLS food group when no curated portion exists. */
    private fun defaultServings(code: String, name: String, unit: String): List<ServingOption> {
        val n = name.lowercase()
        if (unit == "ml") {
            if (code.startsWith("P2") || code.startsWith("P3")) return s("1 Glas" to 200.0, "1 kleines Glas" to 125.0)
            if (code.startsWith("P1")) return s("1 Flasche" to 500.0, "1 kleine Flasche" to 330.0)
            if (code.startsWith("P")) return s("1 Glas" to 40.0, "1 Schnapsglas" to 20.0)
            if (code.startsWith("N4") || code.startsWith("N5") || code.startsWith("N6") || code.startsWith("N7")) return s("1 Tasse" to 150.0, "1 Becher" to 250.0)
            if (code.startsWith("Q")) return s("1 EL" to 10.0, "1 TL" to 4.0)
            return s("1 Glas" to 200.0, "1 Flasche" to 500.0)
        }
        return when (code.firstOrNull()) {
            'B' -> when {
                n.contains("brötchen") || n.contains("semmel") || n.contains("laugen") || n.contains("baguette-brötchen") -> s("1 Stück" to 60.0)
                n.contains("toast") -> s("1 Scheibe" to 25.0)
                n.contains("knäcke") -> s("1 Scheibe" to 10.0)
                else -> s("1 Scheibe" to 45.0, "1 dicke Scheibe" to 60.0)
            }
            'C' -> when {
                n.contains("gekocht") -> s("1 Portion" to 180.0)
                n.contains("flocken") || n.contains("müsli") -> s("1 Portion" to 50.0, "1 EL" to 10.0)
                else -> s("1 Portion" to 70.0, "1 EL" to 12.0)
            }
            'D' -> s("1 Stück" to 100.0, "1 Keks" to 10.0)
            'E' -> when {
                n.contains("hühnerei") -> s("1 Ei (M)" to 58.0, "1 Ei (L)" to 65.0)
                n.contains("gekocht") -> s("1 Portion" to 250.0)
                else -> s("1 Portion" to 100.0)
            }
            'F' -> if (n.contains("getrocknet")) s("1 Handvoll" to 30.0) else s("1 Portion" to 125.0, "1 Handvoll" to 80.0)
            'G' -> s("1 Portion" to 150.0, "1 Handvoll" to 40.0)
            'H' -> when {
                n.contains("tofu") -> s("1 Portion" to 150.0)
                n.contains("mus") || n.contains("creme") -> s("1 EL" to 15.0, "1 TL" to 6.0)
                n.contains("gekocht") || n.contains("konserve") -> s("1 Portion" to 150.0)
                else -> s("1 Handvoll" to 30.0, "1 EL" to 10.0)
            }
            'K' -> when {
                n.contains("chips") -> s("1 Handvoll" to 25.0, "1 Tüte" to 175.0)
                n.contains("pilz") || n.contains("champignon") -> s("1 Portion" to 150.0)
                else -> s("1 Portion" to 200.0, "1 Stück" to 80.0)
            }
            'M' -> when {
                n.contains("joghurt") || n.contains("quark") || n.contains("skyr") || n.contains("frischkäse") -> s("1 Becher" to 150.0, "1 EL" to 20.0)
                n.contains("sahne") || n.contains("rahm") || n.contains("schmand") -> s("1 EL" to 15.0, "1 Becher" to 200.0)
                else -> s("1 Scheibe" to 25.0, "1 Portion" to 30.0)
            }
            'Q' -> s("1 TL" to 5.0, "1 EL" to 12.0)
            'R' -> s("1 TL" to 5.0, "1 EL" to 15.0)
            'S' -> when {
                n.contains("schokolade") -> s("1 Riegel" to 25.0, "1 Tafel" to 100.0)
                n.contains("eis") -> s("1 Kugel" to 60.0)
                n.contains("honig") || n.contains("konfitüre") || n.contains("creme") -> s("1 TL" to 8.0, "1 EL" to 20.0)
                else -> s("1 Stück" to 10.0, "1 Handvoll" to 25.0)
            }
            'T' -> s("1 Filet" to 125.0, "1 Portion" to 150.0)
            'U', 'V' -> s("1 Portion" to 150.0, "1 kleine Portion" to 100.0)
            'W' -> if (n.contains("würstchen") || n.contains("wurst") && (n.contains("brat") || n.contains("bock") || n.contains("wiener")))
                s("1 Stück" to 100.0) else s("1 Scheibe" to 15.0, "1 Portion" to 50.0)
            'X', 'Y' -> when {
                n.contains("suppe") || n.contains("eintopf") -> s("1 Teller" to 300.0, "1 Tasse" to 150.0)
                n.contains("sauce") || n.contains("dressing") || n.contains("dip") -> s("1 EL" to 15.0, "1 Portion" to 60.0)
                else -> s("1 Portion" to 300.0, "1 kleine Portion" to 200.0)
            }
            else -> emptyList()
        }
    }
}

/**
 * Schweizer Nährwertdatenbank (BLV) – ~1,200 generic foods incl. ~150 ready dishes (burgers, kebab, pizzas …).
 * Free for diary apps with source attribution. Bundled, works offline.
 */
object SwissDatabase {
    const val attribution = "Schweizer Nährwertdatenbank V 7.1, Bundesamt für Lebensmittelsicherheit und Veterinärwesen BLV, naehrwertdaten.ch"

    private class Entry(val code: String, val name: String, val folded: String, val words: List<String>,
                        val category: String, val values: List<Double?>)

    private var entries: List<Entry> = emptyList()
    private var keys: List<String> = emptyList()
    private var indexByCode: Map<String, Int> = emptyMap()
    @Volatile private var loaded = false
    private val lock = Any()

    fun preload() { App.scope.launch(Dispatchers.IO) { loadIfNeeded() } }

    private fun loadIfNeeded() { synchronized(lock) { loadLocked() } }

    private fun loadLocked() {
        if (loaded) return
        loaded = true
        val text = readDatabase("swiss") ?: return
        val json = runCatching { Json.parseToJsonElement(text).jsonObject }.getOrNull() ?: return
        keys = json["keys"]?.jsonArray?.map { it.jsonPrimitive.content } ?: return
        val list = ArrayList<Entry>(1300)
        val idx = HashMap<String, Int>()
        for (food in json["foods"]?.jsonArray ?: return) {
            val a = food.jsonArray
            if (a.size < 5) continue
            val code = a[0].jsonPrimitive.content
            val name = a[1].jsonPrimitive.content
            val synonyms = a[4].jsonPrimitive.content.replace(";", " ")
            val f = fold("$name $synonyms")
            idx[code] = list.size
            list += Entry(code, name, f, words(f), a[3].jsonPrimitive.content, doubles(a[2].jsonArray))
        }
        entries = list; indexByCode = idx
    }

    fun reload() {
        synchronized(lock) { loaded = false; entries = emptyList() }
        preload()
    }

    fun food(code: String): FoodItem? { loadIfNeeded(); return indexByCode[code]?.let { food(entries[it]) } }

    fun category(code: String): String? { loadIfNeeded(); return indexByCode[code]?.let { entries[it].category } }

    private fun food(e: Entry): FoodItem {
        val drink = e.category.startsWith("Alkoholfreie Getränke") || e.category.startsWith("Alkoholhaltige Getränke") ||
            e.name.lowercase().startsWith("milch")
        val unit = if (drink) "ml" else "g"
        // Name without trailing preparation details: "Fleischlasagne, zubereitet" → "Fleischlasagne"
        var display = e.name.trim()
        for (suffix in listOf(", zubereitet", ", gebacken", ", hausgemacht")) if (display.endsWith(suffix)) display = display.dropLast(suffix.length)
        return FoodItem(
            id = "ch-${e.code}", name = display, source = FoodSource.swiss, per100 = nutrientsFrom(keys, e.values), unit = unit,
            servings = servings(e.category, e.name, unit), origin = if (display != e.name) e.name else null,
        )
    }

    fun search(query: String, limit: Int = 25): List<FoodItem> {
        loadIfNeeded()
        val tokens = SearchMatcher.tokens(fold(query).trim())
        if (tokens.isEmpty()) return emptyList()
        val scored = ArrayList<Pair<Int, Int>>()
        for ((i, e) in entries.withIndex()) {
            var score: Int
            if (tokens.all { t -> e.words.any { SearchMatcher.strict(it, t) } }) {
                score = 0
                if (e.words.firstOrNull()?.startsWith(tokens[0]) == true) score += 300
                for (t in tokens) if (e.words.any { it == t }) score += 60
                if (e.category.startsWith("Gerichte")) score += 40
            } else if (tokens.all { SearchMatcher.mayMatch(e.folded, it) } &&
                tokens.all { t -> e.words.any { SearchMatcher.relaxed(it, t) } || SearchMatcher.compound(t, e.folded, e.words) }) {
                score = -400
            } else continue
            score -= e.name.length * 2
            scored += i to score
        }
        return scored.sortedByDescending { it.second }.take(limit).map { food(entries[it.first]) }
    }

    /** Fruit and vegetables for the health score (no juices, dried fruit or jam). */
    fun isFruitOrVegetable(category: String, name: String): Boolean {
        val n = name.lowercase()
        if (n.contains("saft") || n.contains("getrocknet") || n.contains("konfitüre") || n.contains("sirup")) return false
        return category.startsWith("Früchte") || category.startsWith("Gemüse")
    }

    private fun s(vararg list: Pair<String, Double>) = list.map { ServingOption(it.first, it.second) }

    private fun servings(category: String, name: String, unit: String): List<ServingOption> {
        val n = name.lowercase()
        if (unit == "ml") {
            if (category.startsWith("Alkoholhaltige")) return if (n.contains("bier")) s("1 Flasche" to 330.0, "1 Stange" to 300.0) else s("1 Glas" to 150.0)
            return s("1 Glas" to 200.0, "1 Tasse" to 150.0)
        }
        return when {
            category.startsWith("Gerichte") -> when {
                n.contains("burger") || n.contains("kebab") || n.contains("hot dog") || n.contains("sandwich") ->
                    s("1 Stück" to if (n.contains("doppelt")) 260.0 else 200.0)
                n.contains("pizza") -> s("1 Pizza" to 400.0, "1 Stück" to 100.0)
                n.contains("suppe") || n.contains("bouillon") || n.contains("minestrone") || n.contains("gazpacho") -> s("1 Teller" to 300.0, "1 Tasse" to 200.0)
                n.contains("crêpe") || n.contains("omelette") -> s("1 Stück" to 120.0, "1 Portion" to 250.0)
                else -> s("1 Portion" to 350.0, "1 kleine Portion" to 250.0)
            }
            category.startsWith("Brote") -> s("1 Scheibe" to 50.0, "1 Portion" to 60.0)
            category.startsWith("Früchte") -> s("1 Stück" to 150.0, "1 Handvoll" to 80.0)
            category.startsWith("Gemüse") -> s("1 Portion" to 150.0)
            category.startsWith("Fleisch") || category.startsWith("Fisch") -> s("1 Portion" to 150.0)
            category.startsWith("Milch") -> if (n.contains("käse")) s("1 Scheibe" to 25.0, "1 Portion" to 40.0) else s("1 Becher" to 150.0)
            category.startsWith("Süssigkeiten") -> s("1 Stück" to 30.0, "1 Portion" to 60.0)
            category.startsWith("Fette") -> s("1 TL" to 5.0, "1 EL" to 12.0)
            category.startsWith("Nüsse") || category.startsWith("Salzige Snacks") -> s("1 Handvoll" to 30.0)
            else -> s("1 Portion" to 100.0)
        }
    }
}

/**
 * Large restaurant chains (McDonald's, Burger King …) with the chains' own published nutrition values.
 * Built by tools/restaurants/build_restaurants.py, bundled, works offline and is updated like BLS and the Swiss database.
 */
object RestaurantDatabase {
    const val attribution = "Restaurantketten: offizielle Nährwertangaben von McDonald's Deutschland und Burger King Deutschland."

    private class Entry(val code: String, val chain: String, val name: String, val category: String, val serving: Double,
                        val unit: String, val words: List<String>, val values: List<Double?>)

    /** Ways people write the chain names in a search ("mcdonalds", "mäcces", "bk" …), already folded. */
    private val aliases = mapOf(
        "mcdonalds" to listOf("mcdonalds", "mcdonald", "mcd", "mces", "maces", "macces", "mecces", "mcdoof"),
        "burgerking" to listOf("burgerking", "bk"),
    )

    private var entries: List<Entry> = emptyList()
    private var keys: List<String> = emptyList()
    private var chains: Map<String, String> = emptyMap()
    private var indexByCode: Map<String, Int> = emptyMap()
    @Volatile private var loaded = false
    private val lock = Any()

    fun preload() { App.scope.launch(Dispatchers.IO) { loadIfNeeded() } }

    private fun loadIfNeeded() { synchronized(lock) { loadLocked() } }

    private fun loadLocked() {
        if (loaded) return
        loaded = true
        val text = readDatabase("restaurants") ?: return
        val json = runCatching { Json.parseToJsonElement(text).jsonObject }.getOrNull() ?: return
        keys = json["keys"]?.jsonArray?.map { it.jsonPrimitive.content } ?: return
        chains = json["chains"]?.jsonObject?.mapValues { (id, c) -> c.jsonObject["name"]?.jsonPrimitive?.content ?: id } ?: emptyMap()
        val list = ArrayList<Entry>(600)
        val idx = HashMap<String, Int>()
        for (food in json["foods"]?.jsonArray ?: return) {
            val a = food.jsonArray
            if (a.size < 7) continue
            val code = a[0].jsonPrimitive.content
            val name = a[2].jsonPrimitive.content
            idx[code] = list.size
            list += Entry(code, a[1].jsonPrimitive.content, name, a[3].jsonPrimitive.content, a[4].jsonPrimitive.doubleOrNull ?: 100.0,
                a[5].jsonPrimitive.content, words(normalize(name)), doubles(a[6].jsonArray))
        }
        entries = list; indexByCode = idx
    }

    fun reload() {
        synchronized(lock) { loaded = false; entries = emptyList() }
        preload()
    }

    /** Folded text without apostrophes and with the chain names written together ("McDonald's" → "mcdonalds"). */
    private fun normalize(s: String): String = fold(s).replace("'", "").replace("’", "").replace("®", " ")
        .replace("mc donald", "mcdonald").replace("burger king", "burgerking")

    fun food(code: String): FoodItem? { loadIfNeeded(); return indexByCode[code]?.let { food(entries[it]) } }

    private fun food(e: Entry): FoodItem = FoodItem(
        id = "rk-${e.code}", name = e.name, brand = chains[e.chain], source = FoodSource.restaurant,
        per100 = nutrientsFrom(keys, e.values), unit = e.unit,
        servings = listOf(ServingOption(if (e.unit == "ml") "1 Getränk" else "1 Portion", e.serving)),
        origin = e.category.ifEmpty { null },
    )

    /** Products of the chains. A chain name in the query narrows the results, the chain name alone lists its whole menu. */
    fun search(query: String, limit: Int = 25): List<FoodItem> {
        loadIfNeeded()
        val all = SearchMatcher.tokens(normalize(query).trim())
        if (all.isEmpty()) return emptyList()
        var chain: String? = null
        val tokens = all.filter { t ->
            val c = aliases.entries.firstOrNull { t in it.value }?.key
            if (c != null) chain = c
            c == null
        }
        val pool = entries.indices.filter { chain == null || entries[it].chain == chain }
        if (tokens.isEmpty()) {
            if (chain == null) return emptyList()
            // Whole menu: burgers first, then other dishes, sides, desserts and drinks.
            fun rank(e: Entry): Int {
                if (e.unit == "ml") return 4
                val c = e.category.lowercase()
                if (listOf("burger", "beef", "chicken", "mccrispy", "mcwrap", "neu").any { c.startsWith(it) }) return 0
                if ("beilage" in c || "dip" in c || "snack" in c) return 2
                if ("dessert" in c || "frühstück" in c || "mccafé" in c) return 3
                return 1
            }
            return pool.sortedWith(compareBy({ rank(entries[it]) }, { entries[it].name })).take(200).map { food(entries[it]) }
        }
        val scored = ArrayList<Pair<Int, Int>>()
        for (i in pool) {
            val e = entries[i]
            var score: Int
            if (tokens.all { t -> e.words.any { SearchMatcher.strict(it, t) } }) {
                score = 0
                if (e.words.firstOrNull()?.startsWith(tokens[0]) == true) score += 300
                for (t in tokens) if (e.words.any { it == t }) score += 60
            } else if (tokens.all { t -> e.words.any { SearchMatcher.relaxed(it, t) } }) {
                score = -400
            } else continue
            score -= e.name.length * 2
            scored += i to score
        }
        return scored.sortedByDescending { it.second }.take(limit).map { food(entries[it.first]) }
    }

    /** True when the query names a chain, so its results belong at the top. */
    fun mentionsChain(query: String): Boolean = words(normalize(query)).any { t -> aliases.values.any { t in it } }
}
