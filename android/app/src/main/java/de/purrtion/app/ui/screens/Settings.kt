package de.purrtion.app.ui.screens

import de.purrtion.app.domain.AppUpdater
import androidx.compose.material.icons.rounded.SystemUpdate
import de.purrtion.app.domain.RestaurantDatabase
import androidx.compose.material.icons.rounded.Fastfood
import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.rounded.OpenInNew
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Group
import androidx.compose.material.icons.rounded.Storage
import androidx.compose.material.icons.rounded.LibraryBooks
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Backup
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.CloudDownload
import androidx.compose.material.icons.rounded.CloudUpload
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.EventRepeat
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Folder
import androidx.compose.material.icons.rounded.HealthAndSafety
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.LocalDining
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.QrCodeScanner
import androidx.compose.material.icons.rounded.Restaurant
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.TableChart
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.CameraAlt
import androidx.compose.material.icons.rounded.HowToReg
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.health.connect.client.PermissionController
import de.purrtion.app.App
import de.purrtion.app.BuildConfig
import de.purrtion.app.domain.AITask
import de.purrtion.app.domain.ActivityStore
import de.purrtion.app.domain.AutoClose
import de.purrtion.app.domain.Backup
import de.purrtion.app.domain.BlsDatabase
import de.purrtion.app.domain.CsvExport
import de.purrtion.app.domain.DatabaseUpdater
import de.purrtion.app.domain.Goals
import de.purrtion.app.domain.HealthConnect
import de.purrtion.app.domain.NutritionSync
import de.purrtion.app.domain.SearchSource
import de.purrtion.app.domain.Secrets
import de.purrtion.app.domain.SwissDatabase
import de.purrtion.app.domain.VisionProvider
import de.purrtion.app.domain.WidgetBridge
import de.purrtion.app.model.clean
import de.purrtion.app.model.format
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.Divider
import de.purrtion.app.ui.FormRow
import de.purrtion.app.ui.FormSection
import de.purrtion.app.ui.FormToggle
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.Segmented
import de.purrtion.app.ui.SliderField
import de.purrtion.app.ui.TextInput
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.pixel.CatPalette
import de.purrtion.app.ui.pixel.PixelSpriteView
import de.purrtion.app.ui.pixel.PixelText
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.ui.pixel.WalkingCatLoader
import de.purrtion.app.ui.theme.Appearance
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.DateFormat
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.min

@Composable
fun SettingsScreen() {
    val goals = App.goals
    val prefs = App.prefs
    val h = rememberHaptics()
    val name = prefs.string("profile.name", "")
    var logoTaps by remember { mutableIntStateOf(0) }
    var lastLogoTap by remember { androidx.compose.runtime.mutableLongStateOf(0L) }
    var toast by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val photo = AITask.photo.provider
    val day = AITask.day.provider
    val aiSummary = if (photo == day) photo.shortName else "${photo.shortName} · ${day.shortName}"

    fun showToast(text: String) {
        toast = text
        scope.launch { kotlinx.coroutines.delay(2400); if (toast == text) toast = null }
    }

    /** Five taps in a row (each within 1.5 s of the last) switch to the dog; the unlock stays for good. */
    fun logoTapped() {
        val now = System.currentTimeMillis()
        logoTaps = if (now - lastLogoTap < 1500) logoTaps + 1 else 1
        lastLogoTap = now
        if (logoTaps < 5) return
        logoTaps = 0
        if (prefs.string("catPalette", "ginger") == CatPalette.dog.id) { showToast("${CatPalette.dog.name} ist schon bei dir 🐶"); return }
        h.success()
        prefs.set("dogUnlocked", true)
        prefs.set("catPalette", CatPalette.dog.id)
        showToast("${CatPalette.dog.name} ist eingezogen 🐶")
    }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().background(C.background).statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp)) {
            Text("Profil", style = font(34, FontWeight.Bold), color = C.textPrimary, modifier = Modifier.padding(top = 12.dp))

            FormSection(footer = "Geschlecht, Alter, Größe, Gewicht und Aktivität. Grundlage für Bedarf, echten Verbrauch und Promille.") {
                Row(Modifier.fillMaxWidth().clickable { Nav.push { ProfileCalculator() } }.padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    CatMascot(CatMood.happy, 2.4.dp, modifier = Modifier.width(44.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(if (name.isBlank()) "Dein Profil" else name, style = font(16, FontWeight.SemiBold), color = C.textPrimary)
                        Text("${goals.sex.label} · ${goals.age} Jahre · ${goals.heightCM.toInt()} cm · ${goals.weightKG.format(1)} kg", style = font(13), color = C.textSecondary, maxLines = 1)
                    }
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = C.textSecondary)
                }
            }

            FormSection("Ziele") {
                FormRow("Kalorien & Makros", value = "${goals.kcal.kcalString} kcal", chevron = true, onClick = { Nav.push { GoalsEditor() } })
            }

            FormSection {
                FormRow("Darstellung", icon = Icons.Rounded.Palette, chevron = true, onClick = { Nav.push { AppearanceScreen() } })
                Divider()
                FormRow("Funktionen", icon = Icons.Rounded.Tune, chevron = true, onClick = { Nav.push { FunctionsPage() } })
                Divider()
                FormRow("Health Connect", icon = Icons.Rounded.Favorite, chevron = true, onClick = { Nav.push { Screen("Health Connect", back = true) { HealthConnectSection() } } })
                Divider()
                FormRow("Eigene Lebensmittel & Rezepte", icon = Icons.Rounded.LocalDining, chevron = true, onClick = { Nav.push { MyFoodsScreen() } })
            }

            FormSection {
                FormRow("Freunde", icon = Icons.Rounded.Group, chevron = true, onClick = { Nav.push { Screen("Freunde", back = true) { FriendsSettingsSection() } } })
                Divider()
                FormRow("Daten & Backup", icon = Icons.Rounded.Storage, chevron = true, onClick = { Nav.push { DataPage() } })
                Divider()
                FormRow("Datenquellen", icon = Icons.Rounded.LibraryBooks, chevron = true, onClick = { Nav.push { SourcesPage() } })
                Divider()
                FormRow("KI-Modelle", icon = Icons.Rounded.AutoAwesome, value = aiSummary, chevron = true, onClick = { Nav.push { VisionSettingsScreen() } })
                Divider()
                FormRow("App-Update", icon = Icons.Rounded.SystemUpdate, chevron = true, onClick = { Nav.push { Screen("App-Update", back = true) { AppUpdateSection() } } })
            }

            Column(Modifier.fillMaxWidth().padding(vertical = 8.dp).clickable(remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, null) { logoTapped() },
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                WalkingCatLoader(2.dp, 160.dp)
                PixelText("PURRTION", 3.dp, Palette.accent)
                Text("Version ${BuildConfig.VERSION_NAME} · mit 🧡 und Pixeln", style = font(12), color = C.textSecondary)
            }
            Spacer(Modifier.navigationBarsPadding().height(88.dp))
        }
        // Above the list so nothing can clip it.
        de.purrtion.app.ui.Toast(toast, Modifier.align(Alignment.BottomCenter).padding(bottom = 110.dp))
    }
}

@Composable
private fun FunctionsPage() {
    val goals = App.goals
    val prefs = App.prefs
    var notificationsDenied by remember { mutableStateOf(false) }
    val notificationLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { notificationsDenied = !it }
    Screen("Funktionen", back = true) {
        FormSection("Funktionen", "Der Health Score bewertet jeden Tag von 0 bis 100 nach Empfehlungen von WHO und DGE. Bei der automatischen Analyse schließt die KI ab etwa 0:30 Uhr den Vortag ab (Anbieter unter „KI-Modelle“ → Tagesanalyse) und du bekommst eine Mitteilung. Android bestimmt den genauen Zeitpunkt. Sonst passiert es beim nächsten Öffnen der App.") {
            FormToggle("Wasser tracken", goals.waterEnabled, { goals.waterEnabled = it }, Icons.Rounded.WaterDrop)
            AnimatedVisibility(goals.waterEnabled) {
                Column {
                    SliderField("Wasserziel", goals.waterML / 1000.0, 0.5..6.0, { goals.waterML = (Math.round(it * 1000 / 50) * 50).toInt() },
                        step = 0.25, unit = "l", decimals = 2, tint = Palette.water)
                    var open by remember { mutableStateOf(false) }
                    Box {
                        FormRow("Glasgröße", value = "${goals.waterStep} ml", onClick = { open = true }, trailing = {
                            Icon(Icons.Rounded.UnfoldMore, null, Modifier.size(18.dp), tint = C.textSecondary)
                        })
                        DropdownMenu(open, { open = false }) {
                            for (ml in listOf(150, 200, 250, 330, 500)) DropdownMenuItem({ Text("$ml ml") }, { goals.waterStep = ml; open = false },
                                trailingIcon = { if (goals.waterStep == ml) Icon(Icons.Rounded.Check, null) })
                        }
                    }
                }
            }
            Divider()
            FormToggle("Health Score", goals.healthScoreEnabled, { goals.healthScoreEnabled = it }, Icons.Rounded.Favorite)
            Divider()
            FormToggle("Vortag nachts analysieren", prefs.bool(AutoClose.ENABLED_KEY), { on ->
                prefs.set(AutoClose.ENABLED_KEY, on)
                AutoClose.schedule()
                if (!on) notificationsDenied = false
                else if (Build.VERSION.SDK_INT >= 33) notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }, Icons.Rounded.Bedtime, subtitle = if (notificationsDenied) "Mitteilungen sind aus. In den Android-Einstellungen erlauben." else null)
        }
    }
}

@Composable
private fun SourcesPage() {
    Screen("Datenquellen", back = true) {
        FormSection(null, "Ausgeschaltete Quellen erscheinen nicht mehr in der Suche. Barcodes nutzen immer Open Food Facts (immer live). Neue Versionen von BLS und Schweizer Datenbank werden über GitHub verteilt und bleiben danach offline nutzbar.\n\n${BlsDatabase.attribution}\n\n${SwissDatabase.attribution}\n\n${RestaurantDatabase.attribution}") {
            SearchSource.entries.forEachIndexed { i, s ->
                if (i > 0) Divider()
                SourceToggle(s)
            }
            Divider()
            DatabaseUpdateRow()
        }
    }
}

@Composable
private fun DataPage() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var exportError by remember { mutableStateOf<String?>(null) }
    Screen("Daten & Backup", back = true) {
        BackupSection()
        FormSection("Daten", exportError) {
            FormRow("Alle Daten als CSV exportieren", icon = Icons.Rounded.TableChart, onClick = {
                scope.launch {
                    runCatching {
                        val files = withContext(Dispatchers.IO) { CsvExport.files(context) }
                        val uris = ArrayList(files.map { FileProvider.getUriForFile(context, "${context.packageName}.files", it) })
                        val send = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                            type = "text/csv"; putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        context.startActivity(Intent.createChooser(send, "Purrtion-Export"))
                        exportError = null
                    }.onFailure { exportError = it.localizedMessage ?: "Export fehlgeschlagen." }
                }
            })
            Divider()
            Row(Modifier.fillMaxWidth().clickable { Nav.sheet { DeleteAllSheet() } }.padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Delete, null, Modifier.size(20.dp), tint = Palette.danger)
                Spacer(Modifier.width(12.dp))
                Text("Alle Einträge löschen", style = font(16), color = Palette.danger)
            }
        }
    }
}

@Composable
private fun IconTile(icon: ImageVector) {
    Box(Modifier.size(32.dp).clip(RoundedCornerShape(9.dp)).background(C.accentSoft), contentAlignment = Alignment.Center) {
        Icon(icon, null, Modifier.size(17.dp), tint = Palette.accentText)
    }
}

@Composable
private fun SourceToggle(source: SearchSource) {
    val on = App.prefs.bool(source.storageKey, true)
    val icon = when (source) {
        SearchSource.bls -> Icons.Rounded.MenuBook
        SearchSource.swiss -> Icons.Rounded.Restaurant
        SearchSource.restaurants -> Icons.Rounded.Fastfood
        SearchSource.openFoodFacts -> Icons.Rounded.QrCodeScanner
        SearchSource.ai -> Icons.Rounded.AutoAwesome
        else -> Icons.Rounded.Search
    }
    Row(Modifier.fillMaxWidth().clickable { source.isEnabled = !on }.padding(vertical = 10.dp), verticalAlignment = Alignment.Top) {
        IconTile(icon)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(source.title, style = font(15, FontWeight.SemiBold), color = C.textPrimary)
            Text(source.detail, style = font(13), color = C.textSecondary)
        }
        androidx.compose.material3.Switch(on, { source.isEnabled = it },
            colors = androidx.compose.material3.SwitchDefaults.colors(checkedTrackColor = Palette.accent, checkedThumbColor = Color.White))
    }
}

/** Versions of the offline databases + manual / automatic update. */
@Composable
private fun DatabaseUpdateRow() {
    val scope = rememberCoroutineScope()
    val u = DatabaseUpdater
    Column(Modifier.padding(vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.Top) {
            IconTile(Icons.Rounded.Sync)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text("Datenbanken aktualisieren", style = font(15, FontWeight.SemiBold), color = C.textPrimary)
                val checked = u.lastCheck?.let { " · geprüft ${de.purrtion.app.model.relativeTime(it)}" } ?: ""
                Text("BLS ${u.version(DatabaseUpdater.Database.bls)} · Schweiz ${u.version(DatabaseUpdater.Database.swiss)} · Ketten ${u.version(DatabaseUpdater.Database.restaurants)}$checked", style = font(12), color = C.textSecondary)
                u.status?.let { Text(it, style = font(12, FontWeight.SemiBold), color = Palette.accentText) }
            }
            if (u.isChecking) CircularProgressIndicator(Modifier.size(20.dp), color = Palette.accentText, strokeWidth = 2.dp)
            else TextButton({ scope.launch { u.update() } }) { Text("Prüfen", style = font(14, FontWeight.Bold), color = Palette.accentText) }
        }
        val auto = App.prefs.bool(DatabaseUpdater.AUTO_KEY, true)
        Row(Modifier.fillMaxWidth().clickable { App.prefs.set(DatabaseUpdater.AUTO_KEY, !auto) }, verticalAlignment = Alignment.CenterVertically) {
            Text("Automatisch (wöchentlich)", style = font(14), color = C.textPrimary, modifier = Modifier.weight(1f))
            androidx.compose.material3.Switch(auto, { App.prefs.set(DatabaseUpdater.AUTO_KEY, it) },
                colors = androidx.compose.material3.SwitchDefaults.colors(checkedTrackColor = Palette.accent, checkedThumbColor = Color.White))
        }
    }
}

// MARK: Health Connect

@Composable
private fun HealthConnectSection() {
    val prefs = App.prefs
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val available = HealthConnect.isAvailable(context)
    var pending by remember { mutableStateOf<String?>(null) }
    var denied by remember { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
        val key = pending ?: return@rememberLauncherForActivityResult
        pending = null
        val needed = if (key == HealthConnect.WEIGHT_KEY) HealthConnect.weightPermissions else HealthConnect.nutritionPermissions
        if (!granted.containsAll(needed)) { denied = true; prefs.set(key, false); return@rememberLauncherForActivityResult }
        denied = false
        scope.launch {
            if (key == HealthConnect.WEIGHT_KEY) HealthConnect.importWeights() else NutritionSync.syncRecent(30)
        }
    }
    fun toggle(key: String, on: Boolean) {
        prefs.set(key, on)
        if (!on) return
        pending = key
        launcher.launch(if (key == HealthConnect.WEIGHT_KEY) HealthConnect.weightPermissions else HealthConnect.nutritionPermissions)
    }
    FormSection("Health Connect", if (!available) "Health Connect ist auf diesem Gerät nicht verfügbar. Ab Android 14 ist es eingebaut, sonst über den Play Store installieren."
        else (if (denied) "Kein Zugriff erteilt. In Health Connect unter App-Berechtigungen → Purrtion erlauben.\n\n" else "") +
        "Liest dein Gewicht aus Health Connect und speichert neue Einträge aus Purrtion dort. „Ernährung“ schreibt jeden Eintrag mit kcal, Makros und Mikronährstoffen sowie dein Wasser in Health Connect. Änderungen und Löschungen werden übernommen.") {
        FormToggle("Gewicht mit Health Connect", available && prefs.bool(HealthConnect.WEIGHT_KEY), { if (available) toggle(HealthConnect.WEIGHT_KEY, it) }, Icons.Rounded.Favorite)
        Divider()
        FormToggle("Ernährung in Health Connect", available && prefs.bool(HealthConnect.NUTRITION_KEY), { if (available) toggle(HealthConnect.NUTRITION_KEY, it) }, Icons.Rounded.HealthAndSafety)
    }
}

// MARK: Backup

@Composable
private fun BackupSection() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val prefs = App.prefs
    var status by remember { mutableStateOf<String?>(null) }
    var refresh by remember { mutableIntStateOf(0) }
    var restoreText by remember { mutableStateOf<String?>(null) }
    val folderName = remember(refresh) { Backup.folderName(context) }

    fun backupNow() {
        scope.launch {
            runCatching { Backup.writeToFolder(context) }
                .onSuccess { status = "Gesichert ✓"; h.success() }
                .onFailure { status = "Sicherung fehlgeschlagen: ${it.localizedMessage ?: "unbekannter Fehler"}" }
            refresh++
        }
    }
    val pickFolder = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        runCatching { Backup.setFolder(context, uri) }
            .onSuccess { prefs.set(Backup.AUTO_KEY, true); refresh++; backupNow() }
            .onFailure { status = "Ordner konnte nicht gespeichert werden." }
    }
    val pickRestore = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        restoreText = runCatching { context.contentResolver.openInputStream(uri)?.use { it.readBytes().decodeToString() } }.getOrNull()
        if (restoreText == null) status = "Datei konnte nicht gelesen werden."
    }

    val footer = buildString {
        append("Wähle einen Ordner, zum Beispiel in Google Drive oder auf dem Gerät. Purrtion legt dort etwa einmal täglich „${Backup.FILE_NAME}“ ab, mit Einträgen, Rezepten, eigenen Lebensmitteln, Gewicht und Einstellungen. Die Datei ist mit der iPhone-App kompatibel.")
        Backup.lastBackup?.let { append("\nLetzte Sicherung: ${DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT, Locale.GERMAN).format(Date(it))}") }
        status?.let { append("\n$it") }
    }
    FormSection("Sicherung", footer) {
        FormRow("Sicherungsordner", icon = Icons.Rounded.Folder, value = folderName ?: "Auswählen", onClick = { pickFolder.launch(null) })
        Divider()
        FormToggle("Täglich automatisch sichern", folderName != null && prefs.bool(Backup.AUTO_KEY), { if (folderName != null) prefs.set(Backup.AUTO_KEY, it) }, Icons.Rounded.EventRepeat)
        Divider()
        FormRow("Jetzt sichern", icon = Icons.Rounded.CloudUpload, titleColor = if (folderName == null) C.textSecondary else C.textPrimary,
            onClick = if (folderName == null) null else ({ backupNow() }))
        Divider()
        FormRow("Aus Sicherung wiederherstellen", icon = Icons.Rounded.CloudDownload, onClick = { pickRestore.launch(arrayOf("application/json", "application/octet-stream", "*/*")) })
    }
    restoreText?.let { text ->
        AlertDialog(onDismissRequest = { restoreText = null },
            title = { Text("Sicherung wiederherstellen?") },
            text = { Text("Alle Daten auf diesem Gerät werden durch die Sicherung ersetzt.") },
            confirmButton = {
                TextButton({
                    restoreText = null
                    scope.launch {
                        runCatching { Backup.restore(text) }
                            .onSuccess { status = "Wiederhergestellt: ${it.entries.size} Einträge, ${it.custom.size} eigene Lebensmittel/Rezepte." }
                            .onFailure { status = "Wiederherstellung fehlgeschlagen: ${it.localizedMessage ?: "ungültige Datei"}" }
                    }
                }) { Text("Ersetzen & wiederherstellen", color = Palette.danger) }
            },
            dismissButton = { TextButton({ restoreText = null }) { Text("Abbrechen") } })
    }
}

// MARK: Delete all (protected)

@Composable
fun DeleteAllSheet() {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    var text by remember { mutableStateOf("") }
    val word = "LÖSCHEN"
    val confirmed = text.trim().uppercase() == word
    Screen("", bottom = {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            PillButton("Abbrechen", Modifier.weight(1f), filled = false, color = C.textSecondary) { Nav.dismissSheet() }
            PillButton("Endgültig löschen", Modifier.weight(1f), color = Palette.danger, enabled = confirmed) {
                scope.launch {
                    val db = App.db
                    db.entries().deleteAll(); db.water().deleteAll(); db.weights().deleteAll(); db.saved().deleteAll(); db.custom().deleteAll()
                    WidgetBridge.update()
                }
                h.warning()
                Nav.dismissSheet()
            }
        }
    }) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
            CatMascot(CatMood.full, 6.dp)
            Text("Wirklich alles löschen?", style = font(22, FontWeight.Bold), color = C.textPrimary)
            Text("Alle Einträge, Wasser, Gewicht, Favoriten, eigene Lebensmittel und Rezepte werden von diesem Gerät entfernt. Das kann nicht rückgängig gemacht werden.",
                style = font(15), color = C.textSecondary, textAlign = TextAlign.Center)
        }
        Text("Tippe $word zur Bestätigung", style = font(14), color = C.textSecondary)
        TextInput(text, { text = it }, word, Modifier.fillMaxWidth().height(50.dp).clip(RoundedCornerShape(14.dp)).background(C.card).padding(horizontal = 14.dp), style = font(18, FontWeight.Bold), keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, autoCorrectEnabled = false))
    }
}

// MARK: AI providers

@Composable
fun VisionSettingsScreen() {
    val prefs = App.prefs
    // Read to recompose on change.
    prefs.optString(AITask.photo.providerKey); prefs.optString(AITask.day.providerKey)
    val used = listOf(AITask.photo.provider, AITask.day.provider)
    Screen("KI-Modelle", back = true) {
        TaskSection(AITask.photo)
        TaskSection(AITask.day)
        for (p in VisionProvider.entries.filter { it.needsKey && it in used }) ProviderKeySection(p)
    }
}

@Composable
private fun TaskSection(task: AITask) {
    val h = rememberHaptics()
    val follows = task.followsPhoto
    val current = task.provider
    FormSection(task.title, if (task == AITask.photo)
        "Erkennt Gerichte auf Fotos und schätzt Mengen und Nährwerte. Offline erkennt ML Kit auf dem Gerät zumindest die Hauptbestandteile."
    else "Ergänzt beim Abschließen eines Tages fehlende Mikronährstoffe und schreibt das Tagesfazit, auch bei der nächtlichen Analyse. Text ohne Bild, daher meist günstiger als die Foto-Erkennung.") {
        if (task == AITask.day) {
            val photo = AITask.photo.provider
            ProviderRow(Icons.Rounded.Link, "Wie Foto-Erkennung", "${photo.title} · ${if (photo == VisionProvider.offline) "auf dem Gerät" else AITask.photo.model(photo)}", follows) {
                h.tap(); App.prefs.remove(task.providerKey)
            }
            Divider()
        }
        VisionProvider.entries.forEachIndexed { i, p ->
            if (i > 0) Divider()
            val icon = when (p) { VisionProvider.offline -> Icons.Rounded.CameraAlt; VisionProvider.gemini -> Icons.Rounded.AutoAwesome
                VisionProvider.claude -> Icons.Rounded.HowToReg; VisionProvider.openai -> Icons.Rounded.Public }
            ProviderRow(icon, p.title, p.costNote, !follows && current == p) { h.tap(); task.provider = p }
        }
        if (!follows && current != VisionProvider.offline) { Divider(); ModelPicker(task, current) }
    }
}

@Composable
private fun ProviderRow(icon: ImageVector, title: String, note: String, selected: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        IconTile(icon)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = font(16, FontWeight.SemiBold), color = C.textPrimary)
            Text(note, style = font(12), color = C.textSecondary)
        }
        Icon(if (selected) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked, null, Modifier.size(22.dp), tint = if (selected) Palette.accent else C.line)
    }
}

/** Model for one task and provider: menu with common models + free text. */
@Composable
private fun ModelPicker(task: AITask, provider: VisionProvider) {
    val key = task.modelKey(provider)
    val model = App.prefs.string(key, "")
    val placeholder = if (task == AITask.day) AITask.photo.model(provider) else provider.defaultModel
    var open by remember { mutableStateOf(false) }
    Row(Modifier.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("Modell", style = font(16), color = C.textPrimary)
        Spacer(Modifier.width(12.dp))
        TextInput(model, { App.prefs.set(key, it.trim()) }, placeholder, Modifier.weight(1f),
            keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false))
        if (provider.suggestedModels.isNotEmpty()) Box {
            Icon(Icons.Rounded.UnfoldMore, "Modelle", Modifier.padding(start = 8.dp).size(22.dp).clickable { open = true }, tint = Palette.accentText)
            DropdownMenu(open, { open = false }) {
                for (m in provider.suggestedModels) DropdownMenuItem({ Text(m) }, { App.prefs.set(key, m); open = false },
                    trailingIcon = { if (task.model(provider) == m) Icon(Icons.Rounded.Check, null) })
                if (model.isNotEmpty()) DropdownMenuItem({ Text("Standard ($placeholder)") }, { App.prefs.remove(key); open = false })
            }
        }
    }
}

@Composable
private fun ProviderKeySection(provider: VisionProvider) {
    val context = LocalContext.current
    var key by remember(provider) { mutableStateOf(provider.apiKey) }
    FormSection("Schlüssel · ${provider.title}", if (key.isEmpty()) "Ohne Schlüssel kann ${provider.title} nicht genutzt werden."
        else "Der Schlüssel liegt verschlüsselt auf diesem Gerät und gilt für alle Aufgaben mit ${provider.title}.") {
        TextInput(key, { key = it; Secrets.set(provider.secretKey, it.trim()) }, "API-Schlüssel", Modifier.fillMaxWidth().padding(vertical = 8.dp),
            keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false,
                keyboardType = androidx.compose.ui.text.input.KeyboardType.Password),
            visualTransformation = PasswordVisualTransformation())
        provider.keyUrl?.let { url ->
            Divider()
            FormRow("Schlüssel erstellen", icon = Icons.AutoMirrored.Rounded.OpenInNew, onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) })
        }
    }
}

// MARK: Goals

@Composable
fun GoalsEditor() {
    val goals = App.goals
    LaunchedEffect(Unit) { goals.syncMacros() }
    Screen("Ziele", back = true) {
        FormSection(footer = "Änderungen gelten ab heute. Vergangene Tage behalten das Ziel, das damals galt. Tipp: Zahl antippen und direkt eintippen.") {
            SliderField(if (goals.weekdayEnabled) "Standard-Kalorienziel" else "Kalorienziel", goals.kcal, 1000.0..5000.0, { goals.kcal = it; goals.syncMacros() }, step = 10.0, unit = "kcal")
        }
        WeekdayGoalsSection()
        ActivityGoalSection()
        val footer = if (goals.macroMode == Goals.MacroMode.percent)
            "= ${goals.protein.clean} g Protein · ${goals.carbs.clean} g Kohlenhydrate · ${goals.fat.clean} g Fett. Kohlenhydrate füllen automatisch auf 100 % auf."
        else {
            val k = goals.protein * 4 + goals.carbs * 4 + goals.fat * 9
            "Makros ergeben ${k.kcalString} kcal${if (abs(k - goals.kcal) > 50) ". Das weicht vom Kalorienziel ab." else "."}"
        }
        FormSection("Makros", footer) {
            Text("Makros einstellen in", style = font(14), color = C.textSecondary, modifier = Modifier.padding(top = 10.dp, bottom = 6.dp))
            Segmented(Goals.MacroMode.entries, goals.macroMode, { it.label }) { mode ->
                goals.macroMode = mode
                if (mode == Goals.MacroMode.percent) { goals.syncPercentFromGrams(); goals.syncMacros() }
            }
            if (goals.macroMode == Goals.MacroMode.percent) {
                SliderField("Protein", goals.proteinPct, 10.0..50.0, { goals.proteinPct = min(it, 100 - goals.fatPct - 5); goals.syncMacros() }, unit = "%", tint = Palette.protein)
                SliderField("Fett", goals.fatPct, 10.0..60.0, { goals.fatPct = min(it, 100 - goals.proteinPct - 5); goals.syncMacros() }, unit = "%", tint = Palette.fat)
                Row(Modifier.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("Kohlenhydrate", style = font(16), color = C.textPrimary, modifier = Modifier.weight(1f))
                    Text("${goals.carbsPct.toInt()} %", style = font(20, FontWeight.Bold), color = Palette.carbs)
                }
                MacroSplitBar(goals.proteinPct, goals.carbsPct, goals.fatPct)
            } else {
                SliderField("Protein", goals.protein, 20.0..300.0, { goals.protein = it }, step = 5.0, unit = "g", tint = Palette.protein)
                SliderField("Kohlenhydrate", goals.carbs, 0.0..600.0, { goals.carbs = it }, step = 5.0, unit = "g", tint = Palette.carbs)
                SliderField("Fett", goals.fat, 10.0..250.0, { goals.fat = it }, step = 5.0, unit = "g", tint = Palette.fat)
            }
        }
    }
}

/** Own calorie goal per weekday (e.g. more on training days or at the weekend). Keys use the iOS numbering (1 = Sunday). */
@Composable
private fun WeekdayGoalsSection() {
    val goals = App.goals
    val weekdays = listOf(2, 3, 4, 5, 6, 7, 1)
    FormSection(footer = if (goals.weekdayEnabled) "Protein bleibt an jedem Tag gleich, Kohlenhydrate und Fett gleichen den Unterschied aus."
        else "Zum Beispiel mehr an Trainingstagen oder am Wochenende.") {
        FormToggle("Ziel pro Wochentag", goals.weekdayEnabled, { on ->
            if (on) goals.weekdayKcal = weekdays.associateWith { goals.weekdayKcal[it] ?: goals.kcal }
            goals.weekdayEnabled = on
        }, Icons.Rounded.EventRepeat)
        AnimatedVisibility(goals.weekdayEnabled) {
            Column {
                for (wd in weekdays) {
                    val name = DayOfWeek.of(if (wd == 1) 7 else wd - 1).getDisplayName(TextStyle.FULL, Locale.GERMAN)
                    SliderField(name, goals.kcal(wd), 1000.0..5000.0, { goals.setKcal(it, wd) }, step = 10.0, unit = "kcal")
                }
                TextButton({ goals.weekdayKcal = weekdays.associateWith { goals.kcal } }) {
                    Text("Alle auf ${goals.kcal.kcalString} kcal zurücksetzen", style = font(14, FontWeight.SemiBold), color = Palette.accentText)
                }
            }
        }
    }
}

/** Active energy from Health Connect, shown on Today and optionally added to the goal. */
@Composable
private fun ActivityGoalSection() {
    val goals = App.goals
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var todayActive by remember { mutableStateOf(ActivityStore.kcal(LocalDate.now())) }
    var failed by remember { mutableStateOf(false) }
    suspend fun reload() {
        HealthConnect.refreshActivity()
        todayActive = ActivityStore.kcal(LocalDate.now())
        goals.activityUpdated()
        WidgetBridge.update()
    }
    val launcher = rememberLauncherForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
        failed = !granted.containsAll(HealthConnect.activityPermissions)
        scope.launch { reload() }
    }
    LaunchedEffect(Unit) { if (goals.activityEnabled) reload() }
    FormSection("Aktivität (Health Connect)", if (goals.activityEnabled)
        "0 % zeigt die Kalorien nur an. Sonst steigt dein Tagesziel um diesen Anteil deiner aktiven Kalorien. Uhren überschätzen den Verbrauch oft, 50 bis 75 % ist ein guter Kompromiss. Dein Grundumsatz ist im Kalorienziel schon enthalten. Manuell eingetragene Aktivität (Heute → oberste Karte antippen) zählt mit demselben Anteil."
    else "Zeigt deine aktiven Kalorien aus Health Connect (z. B. von einer Smartwatch) auf der Heute-Seite. Auf Wunsch werden sie aufs Ziel angerechnet.") {
        FormToggle("Aktivitätskalorien", goals.activityEnabled, { on ->
            goals.activityEnabled = on
            if (on) {
                if (HealthConnect.isAvailable(context)) launcher.launch(HealthConnect.activityPermissions) else failed = true
            }
        }, Icons.Rounded.LocalFireDepartment)
        AnimatedVisibility(goals.activityEnabled) {
            Column {
                FormRow("Heute laut Health Connect", value = "${todayActive.kcalString} kcal")
                SliderField("Aufs Ziel anrechnen", goals.activityPercent, 0.0..100.0, { goals.activityPercent = it }, step = 5.0, unit = "%")
                if (goals.activityPercent > 0) FormRow("Heute dazu", value = "+${(todayActive * goals.activityPercent / 100).kcalString} kcal", titleColor = Palette.accent)
                if (failed) Text("Kein Zugriff auf Health Connect. In Health Connect unter App-Berechtigungen → Purrtion erlauben.",
                    style = font(12), color = Palette.danger, modifier = Modifier.padding(bottom = 8.dp))
            }
        }
    }
}

@Composable
fun MacroSplitBar(p: Double, c: Double, f: Double) {
    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp).height(10.dp), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        for ((v, color) in listOf(p to Palette.protein, c to Palette.carbs, f to Palette.fat))
            Box(Modifier.weight(maxOf(v, 1.0).toFloat()).fillMaxSize().clip(CircleShape).background(color))
    }
}

// MARK: Profile

@Composable
fun ProfileCalculator(onApply: (() -> Unit)? = null, onSkip: (() -> Unit)? = null) {
    val goals = App.goals
    val h = rememberHaptics()
    // Edited as a draft. Nothing changes until "Profil speichern" or "Als Ziel übernehmen".
    var sex by remember { mutableStateOf(goals.sex) }
    var age by remember { mutableStateOf(goals.age.toDouble()) }
    var height by remember { mutableStateOf(goals.heightCM) }
    var weight by remember { mutableStateOf(goals.weightKG) }
    var activity by remember { mutableStateOf(goals.activity) }
    var target by remember { mutableStateOf(goals.target) }
    var saved by remember { mutableStateOf(false) }
    val bmr = 10 * weight + 6.25 * height - 5 * age + if (sex == Goals.Sex.male) 5 else -161
    val tdee = bmr * activity.factor
    val suggested = Math.round(maxOf(1200.0, tdee + target.delta) / 10) * 10.0
    val changed = sex != goals.sex || Math.round(age).toInt() != goals.age || height != goals.heightCM || weight != goals.weightKG ||
        activity != goals.activity || target != goals.target
    fun store() {
        goals.sex = sex; goals.age = Math.round(age).toInt(); goals.heightCM = height; goals.weightKG = weight
        goals.activity = activity; goals.target = target
    }
    Screen("Dein Profil", back = onApply == null, leading = if (onSkip != null) null else "Abbrechen", onLeading = if (onApply == null) ({ Nav.pop() }) else null,
        trailing = onSkip?.let { skip -> { TextButton(skip) { Text("Überspringen", style = font(16, FontWeight.SemiBold), color = Palette.accentText) } } }) {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(C.card).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            CatMascot(CatMood.happy, 3.dp)
            Spacer(Modifier.width(14.dp))
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Profil anlegen", style = font(18, FontWeight.Bold), color = C.textPrimary)
                Text("Hier legst du deine Körperdaten an. Daraus berechnet Purrtion deinen Bedarf. Das Kalorienziel änderst du nur, wenn du es übernimmst.",
                    style = font(13), color = C.textSecondary)
            }
        }
        FormSection("Über dich", "Wird für Grundumsatz, echten Verbrauch und Promille-Schätzung genutzt. Zahl antippen zum direkten Eintippen.") {
            Segmented(Goals.Sex.entries, sex, { it.label }, Modifier.padding(vertical = 10.dp)) { sex = it }
            SliderField("Alter", age, 14.0..90.0, { age = it }, unit = "Jahre")
            SliderField("Größe", height, 140.0..210.0, { height = it }, unit = "cm")
            SliderField("Gewicht", weight, 40.0..180.0, { weight = it }, step = 0.5, unit = "kg", decimals = 1, stepper = true)
        }
        FormSection("Aktivität") {
            Goals.Activity.entries.forEachIndexed { i, a ->
                if (i > 0) Divider()
                Row(Modifier.fillMaxWidth().clickable { h.tap(); activity = a }.padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(a.label, style = font(16), color = C.textPrimary)
                        Text(a.detail, style = font(12), color = C.textSecondary)
                    }
                    if (activity == a) Icon(Icons.Rounded.Check, null, tint = Palette.accentText)
                }
            }
        }
        FormSection("Ziel") {
            var open by remember { mutableStateOf(false) }
            Box {
                FormRow("Ziel", value = target.label, onClick = { open = true }, trailing = { Icon(Icons.Rounded.UnfoldMore, null, Modifier.size(18.dp), tint = C.textSecondary) })
                DropdownMenu(open, { open = false }) {
                    for (t in Goals.Target.entries) DropdownMenuItem({ Text(t.label) }, { target = t; open = false },
                        trailingIcon = { if (target == t) Icon(Icons.Rounded.Check, null) })
                }
            }
        }
        FormSection("Bedarf", if (onApply == null) "„Nur Profil speichern“ übernimmt deine Angaben, ohne das Kalorienziel zu ändern." else null) {
            FormRow("Grundumsatz", value = "${bmr.kcalString} kcal")
            FormRow("Gesamtbedarf", value = "${tdee.kcalString} kcal")
            Row(Modifier.padding(vertical = 10.dp)) {
                Text("Empfohlenes Ziel", style = font(16, FontWeight.Bold), color = C.textPrimary, modifier = Modifier.weight(1f))
                Text("${suggested.kcalString} kcal", style = font(16, FontWeight.Bold), color = C.textPrimary)
            }
            FormRow("Dein aktuelles Ziel", value = "${goals.kcal.kcalString} kcal")
            PillButton("Als Ziel übernehmen", Modifier.padding(vertical = 8.dp)) {
                store(); goals.applySuggestion(); h.success(); saved = true
                onApply?.invoke()
            }
            if (onApply == null) PillButton(if (saved && !changed) "Profil gespeichert" else "Nur Profil speichern", Modifier.padding(bottom = 8.dp),
                icon = if (saved && !changed) Icons.Rounded.Check else Icons.Rounded.HowToReg, filled = false, enabled = changed) {
                store(); h.success(); saved = true
            }
        }
    }
}

// MARK: Onboarding

@Composable
fun OnboardingScreen() {
    val goals = App.goals
    var page by remember { mutableIntStateOf(0) }
    Box(Modifier.fillMaxSize().background(C.background).clickable(enabled = false) {}) {
        if (page == 0) {
            Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(bottom = 20.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
                Spacer(Modifier.weight(1f))
                CatMascot(CatMood.happy, 9.dp)
                PixelText("PURRTION", 6.dp, Palette.accent)
                Text("Kalorien zählen. Schnell, einfach und mit einer Katze, die sich mit dir freut.", style = font(18, FontWeight.Medium),
                    color = C.textSecondary, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp))
                Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Feature(Icons.Rounded.Search, "7.100 Lebensmittel + Millionen Produkte")
                    Feature(Icons.Rounded.QrCodeScanner, "Barcode scannen")
                    Feature(Icons.Rounded.CameraAlt, "Gerichte per Foto erkennen")
                    Feature(Icons.Rounded.Favorite, "Health Score, Vitamine & Mineralstoffe")
                }
                Spacer(Modifier.weight(1f))
                PillButton("Los geht's", Modifier.padding(horizontal = 24.dp)) { page = 1 }
            }
        } else {
            ProfileCalculator(onApply = { goals.onboarded = true }, onSkip = { goals.onboarded = true })
        }
    }
}

@Composable
private fun Feature(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)).background(C.accentSoft), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(19.dp), tint = Palette.accentText)
        }
        Spacer(Modifier.width(14.dp))
        Text(text, style = font(16, FontWeight.Medium), color = C.textPrimary)
    }
}

// MARK: App update

/** Search for and install a newer version from GitHub, inside the app. All data stays (see [AppUpdater]). */
@Composable
private fun AppUpdateSection() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val u = AppUpdater
    val release = u.available
    FormSection("App-Update", "Lädt neue Versionen direkt von GitHub. Vor der Installation sichert Purrtion alle Daten. Einträge, Rezepte, Gewicht, Einstellungen und die Verbindung zum Freunde-Server bleiben beim Update erhalten.") {
        Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            IconTile(Icons.Rounded.SystemUpdate)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(if (release != null) "Version ${release.version} verfügbar" else "Purrtion ${u.currentVersion}",
                    style = font(15, FontWeight.SemiBold), color = if (release != null) Palette.accent else C.textPrimary)
                u.status?.let { Text(it, style = font(12), color = C.textSecondary) }
            }
            if (u.isChecking) CircularProgressIndicator(Modifier.size(20.dp), color = Palette.accentText, strokeWidth = 2.dp)
        }
        u.progress?.let { p ->
            de.purrtion.app.ui.Bar(p.toDouble(), Palette.accent, Modifier.padding(bottom = 10.dp), height = 6.dp, track = C.cardAlt)
        }
        if (release != null) {
            if (release.notes.isNotBlank()) Text(release.notes.lines().filter { it.isNotBlank() }.take(6).joinToString("\n")
                .replace("**", "").replace("### ", ""), style = font(12), color = C.textSecondary, maxLines = 5,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis, modifier = Modifier.padding(bottom = 8.dp))
            PillButton(if (u.progress != null) "Wird aktualisiert …" else "Jetzt aktualisieren", Modifier.padding(bottom = 10.dp),
                icon = Icons.Rounded.SystemUpdate, enabled = u.progress == null) {
                if (!u.canInstall(context)) {
                    u.status = "Erlaube Purrtion einmal, Apps zu installieren. Danach geht es automatisch weiter."
                    u.waitForPermission(context, release)
                } else scope.launch { u.install(context, release) }
            }
        } else {
            PillButton("Nach Updates suchen", Modifier.padding(bottom = 10.dp), filled = false, enabled = !u.isChecking) {
                scope.launch { u.check() }
            }
        }
    }
}
