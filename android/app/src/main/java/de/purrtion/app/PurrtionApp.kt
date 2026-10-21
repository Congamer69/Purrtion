package de.purrtion.app

import android.app.Application
import android.content.Context
import de.purrtion.app.data.AppDatabase
import de.purrtion.app.data.Prefs
import de.purrtion.app.domain.BlsDatabase
import de.purrtion.app.domain.RestaurantDatabase
import de.purrtion.app.domain.SwissDatabase
import de.purrtion.app.domain.Goals
import de.purrtion.app.domain.Notifications
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/** Application: holds the few app-wide singletons (database, settings, goals). */
class PurrtionApp : Application() {
    override fun onCreate() {
        super.onCreate()
        App.init(this)
        // A server config built into this APK is kept in the settings, so updates without one stay connected.
        de.purrtion.app.domain.FirebaseConfig.persistBundled()
        // Load the food databases in the background so the first search is instant.
        BlsDatabase.preload()
        SwissDatabase.preload()
        RestaurantDatabase.preload()
        Notifications.createChannels(this)
    }
}

object App {
    lateinit var context: Context
        private set
    lateinit var db: AppDatabase
        private set
    lateinit var prefs: Prefs
        private set
    lateinit var goals: Goals
        private set

    /** For work that must outlive a screen (sync, uploads). */
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun init(context: Context) {
        if (this::context.isInitialized) return
        this.context = context.applicationContext
        db = AppDatabase.create(this.context)
        prefs = Prefs(this.context)
        goals = Goals(prefs)
    }
}
