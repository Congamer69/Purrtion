package de.purrtion.app.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import de.purrtion.app.App
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Remembers the last deletion for a short while so a false swipe can be taken back. */
object UndoStore {
    private sealed interface Change {
        class Entries(val list: List<FoodEntry>) : Change
        class Meal(val before: FoodEntry) : Change
    }

    /** What can be restored ("Eintrag", "3 Einträge", "Zutat"), null when nothing. */
    var label by mutableStateOf<String?>(null)
        private set
    private var change: Change? = null
    private var expiry: kotlinx.coroutines.Job? = null

    private const val WINDOW_MS = 10_000L

    fun recordDeletion(entries: List<FoodEntry>) {
        if (entries.isEmpty()) return
        arm(Change.Entries(entries), if (entries.size == 1) "Eintrag" else "${entries.size} Einträge")
    }

    /** Call before an ingredient is removed from a meal. */
    fun recordIngredientRemoval(entry: FoodEntry) = arm(Change.Meal(entry), "Zutat")

    suspend fun undo() {
        when (val c = change ?: return) {
            is Change.Entries -> c.list.forEach { Store.insert(it) }
            is Change.Meal -> Store.update(c.before)
        }
        clear()
    }

    fun clear() {
        expiry?.cancel()
        change = null
        label = null
    }

    private fun arm(new: Change, text: String) {
        expiry?.cancel()
        change = new
        label = text
        expiry = App.scope.launch { delay(WINDOW_MS); clear() }
    }
}

