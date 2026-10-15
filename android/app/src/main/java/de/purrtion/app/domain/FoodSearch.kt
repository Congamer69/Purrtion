package de.purrtion.app.domain

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import de.purrtion.app.App
import de.purrtion.app.model.FoodItem
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Which databases the food search uses (Einstellungen → Datenquellen). */
enum class SearchSource(val title: String, val detail: String) {
    bls("Bundeslebensmittelschlüssel 4.0", "7.140 Lebensmittel und Gerichte, bis zu 138 Nährstoffe, im Labor analysiert. Offline."),
    swiss("Schweizer Nährwertdatenbank", "1.216 Lebensmittel, darunter 150 fertige Gerichte wie Burger, Kebab, Pizza oder Gratins. Offline."),
    restaurants("Restaurantketten", "McDonald's und Burger King mit den offiziellen Nährwerten der Ketten, inklusive Portionsgröße. Offline."),
    openFoodFacts("Open Food Facts", "Barcodes und Markenprodukte, deutsche Produkte bevorzugt. Braucht Internet."),
    ai("KI-Schätzung", "Für alles, was keine Datenbank kennt: Restaurantgerichte oder ganze Sätze wie „2 Eier und ein Toast“. Nutzt den Anbieter der Foto-Erkennung.");

    val storageKey: String get() = "source.$name"
    var isEnabled: Boolean
        get() = App.prefs.bool(storageKey, true)
        set(v) = App.prefs.set(storageKey, v)
}

/** Searches the bundled BLS, Swiss and restaurant chain databases instantly and Open Food Facts (products) over the network. */
class FoodSearch(private val scope: CoroutineScope) {
    var query by mutableStateOf("")
    var foods by mutableStateOf<List<FoodItem>>(emptyList()); private set
    var swiss by mutableStateOf<List<FoodItem>>(emptyList()); private set
    var restaurants by mutableStateOf<List<FoodItem>>(emptyList()); private set
    var products by mutableStateOf<List<FoodItem>>(emptyList()); private set
    var isLoading by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null); private set

    private var job: Job? = null

    val isEmpty: Boolean get() = foods.isEmpty() && swiss.isEmpty() && restaurants.isEmpty() && products.isEmpty()

    fun update(q: String) {
        query = q
        job?.cancel()
        val t = q.trim()
        if (t.isEmpty()) {
            foods = emptyList(); swiss = emptyList(); restaurants = emptyList(); products = emptyList(); isLoading = false; error = null
            return
        }
        isLoading = t.length >= 2
        job = scope.launch {
            val useBls = SearchSource.bls.isEnabled
            val useSwiss = SearchSource.swiss.isEnabled
            val useChains = SearchSource.restaurants.isEnabled
            val (local, ch, chains) = withContext(Dispatchers.Default) {
                Triple(if (useBls) BlsDatabase.search(t) else emptyList(), if (useSwiss) SwissDatabase.search(t) else emptyList(),
                    if (useChains) RestaurantDatabase.search(t) else emptyList())
            }
            foods = local
            swiss = ch
            restaurants = chains
            if (t.length < 2 || !SearchSource.openFoodFacts.isEnabled) { products = emptyList(); isLoading = false; return@launch }
            delay(350)   // debounce network
            try {
                products = OpenFoodFacts.search(productQuery(t))
                error = null
            } catch (e: Exception) {
                if (e is kotlinx.coroutines.CancellationException) throw e
                products = emptyList()
                error = "Produktsuche offline. Lebensmittel funktionieren trotzdem."
            }
            isLoading = false
        }
    }

    companion object {
        /** Products are searched with the meaningful words only ("2 Eier und ein Toast" → "Eier Toast"). */
        fun productQuery(q: String): String {
            val kept = q.split(' ', ',').filter { w ->
                val f = fold(w)
                f.isNotEmpty() && f !in SearchMatcher.stopwords && !f.all(Char::isDigit) && f.length > 1
            }
            return if (kept.isEmpty()) q else kept.joinToString(" ")
        }
    }
}
