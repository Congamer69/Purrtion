package de.purrtion.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.lifecycleScope
import de.purrtion.app.domain.AutoClose
import de.purrtion.app.domain.Backup
import de.purrtion.app.domain.DatabaseUpdater
import de.purrtion.app.domain.FriendsStore
import de.purrtion.app.domain.HealthConnect
import de.purrtion.app.domain.Notifications
import de.purrtion.app.domain.NutritionSync
import de.purrtion.app.domain.WidgetBridge
import de.purrtion.app.ui.RootScreen
import de.purrtion.app.ui.theme.PurrtionTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    /** Day (epoch day) of a tapped "Vortag analysiert" notification – Today opens that verdict. */
    var reviewDay by mutableStateOf<Long?>(null)
    /** Set when an invite link opened the app – the friends tab is shown. */
    var openFriends by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        App.init(this)
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.auto(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT))
        handle(intent)
        setContent {
            PurrtionTheme {
                RootScreen(this)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        intent ?: return
        val day = intent.getLongExtra(Notifications.EXTRA_REVIEW_DAY, Long.MIN_VALUE)
        if (day != Long.MIN_VALUE) reviewDay = day
        if (BuildConfig.DEBUG && intent.getBooleanExtra("seedDemo", false)) {
            intent.removeExtra("seedDemo")
            lifecycleScope.launch { de.purrtion.app.data.DemoData.seed(); WidgetBridge.update() }
        }
        intent.data?.let { uri ->
            if (FriendsStore.handle(uri)) {
                App.prefs.set(FriendsStore.ENABLED_KEY, true)
                openFriends = true
            }
        }
    }

    override fun onStart() {
        super.onStart()
        // Same work as when the iOS app becomes active.
        // Back in the app: send pending friend changes and pick up answered requests.
        if (App.prefs.bool(FriendsStore.ENABLED_KEY, true)) lifecycleScope.launch { FriendsStore.refresh() }
        lifecycleScope.launch {
            WidgetBridge.update()
            Backup.autoBackupIfNeeded(this@MainActivity)
            HealthConnect.importWeights()
            if (App.goals.activityEnabled && HealthConnect.refreshActivity(14)) App.goals.activityUpdated()
            AutoClose.schedule(this@MainActivity)
            NutritionSync.syncRecent(3)
            DatabaseUpdater.autoUpdateIfNeeded()
            AutoClose.runIfNeeded(this@MainActivity)
        }
    }

    override fun onStop() {
        super.onStop()
        App.scope.launch { WidgetBridge.update() }
        FriendsStore.uploadIfNeeded()
    }
}
