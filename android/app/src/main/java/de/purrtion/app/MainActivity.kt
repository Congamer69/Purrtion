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
import de.purrtion.app.domain.GentleReminder
import de.purrtion.app.domain.Backup
import de.purrtion.app.domain.Diag
import de.purrtion.app.domain.SafeMode
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
        // A crash whose report screen did not show (or was not read yet) is shown first.
        if (Diag.hasPendingCrash(this)) {
            startActivity(Intent(this, CrashActivity::class.java))
            finish()
            return
        }
        App.init(this)
        if (SafeMode.active) android.widget.Toast.makeText(this, "Abgesicherter Modus: Standardlook, ohne Hintergrundaufgaben", android.widget.Toast.LENGTH_LONG).show()
        Diag.log("MainActivity erstellt")
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.auto(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT))
        handle(intent)
        // Debug builds only: lets the crash report screen be tried out (adb shell am start ... --ez crashTest true).
        if (BuildConfig.DEBUG && intent.getBooleanExtra("crashTest", false)) throw IllegalStateException("Test-Absturz")
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

    private fun handle(intent: Intent?) = Diag.guard("Intent") { handleIntent(intent) }

    private fun handleIntent(intent: Intent?) {
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
        if (isFinishing || SafeMode.active || !App.isReady) return
        if (App.prefs.bool(FriendsStore.ENABLED_KEY, true)) lifecycleScope.launch { Diag.guard("Freunde aktualisieren") { FriendsStore.refresh() } }
        // Each step on its own: one failing step must not take the others (or the app) down.
        lifecycleScope.launch {
            Diag.guard("Widget") { WidgetBridge.update() }
            Diag.guard("Auto-Backup") { Backup.autoBackupIfNeeded(this@MainActivity) }
            Diag.guard("Health Connect Gewicht") { HealthConnect.importWeights() }
            Diag.guard("Health Connect Aktivität") { if (App.goals.activityEnabled && HealthConnect.refreshActivity(14)) App.goals.activityUpdated() }
            Diag.guard("Tagesabschluss planen") { AutoClose.schedule(this@MainActivity) }
            Diag.guard("Erinnerung planen") { GentleReminder.createChannel(this@MainActivity); GentleReminder.schedule(this@MainActivity) }
            Diag.guard("Ernährung synchronisieren") { NutritionSync.syncRecent(3) }
            Diag.guard("Datenbank-Update") { DatabaseUpdater.autoUpdateIfNeeded() }
            Diag.guard("App-Update prüfen") { de.purrtion.app.domain.AppUpdater.checkDaily() }
            Diag.guard("Tagesabschluss") { AutoClose.runIfNeeded(this@MainActivity) }
        }
    }

    override fun onResume() {
        super.onResume()
        if (!isFinishing && !SafeMode.active && App.isReady) Diag.guard("Update fortsetzen") { de.purrtion.app.domain.AppUpdater.resumeIfAllowed(this) }
    }

    override fun onStop() {
        super.onStop()
        if (isFinishing || SafeMode.active || !App.isReady) return
        App.scope.launch { Diag.guard("Widget") { WidgetBridge.update() } }
        Diag.guard("Freunde hochladen") { FriendsStore.uploadIfNeeded() }
    }
}
