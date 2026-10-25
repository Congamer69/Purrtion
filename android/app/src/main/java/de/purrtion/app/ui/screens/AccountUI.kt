package de.purrtion.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.CloudDownload
import androidx.compose.material.icons.rounded.CloudUpload
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.EventRepeat
import androidx.compose.material.icons.rounded.Login
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import de.purrtion.app.domain.FirebaseConfig
import de.purrtion.app.domain.ServerAccount
import de.purrtion.app.ui.Divider
import de.purrtion.app.ui.FormRow
import de.purrtion.app.ui.FormSection
import de.purrtion.app.ui.FormToggle
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import kotlinx.coroutines.launch
import java.text.DateFormat
import java.util.Date
import java.util.Locale

/** Einstellungen → Konto: the server, the Google login and the server backup in one place. */
@Composable
fun AccountSection() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var confirmRestore by remember { mutableStateOf(false) }
    var confirmSignOut by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val account = ServerAccount
    fun date(millis: Long) = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT, Locale.GERMAN).format(Date(millis))

    LaunchedEffect(account.isLinked) { account.refreshRemote() }

    if (!FirebaseConfig.isAvailable) {
        FormSection("Konto", "Das Konto gibt es in diesem Build nicht.") {}
    } else {
        if (!account.isLinked) {
            FormSection("Google-Konto", "Mit deinem Google-Konto liegen Freunde und Backup auf dem Server. Auf einem neuen Gerät einfach mit dem gleichen Google-Konto anmelden, dann ist alles wieder da. Ohne Anmeldung bleibt alles wie bisher: Die lokale Sicherung unter Daten & Backup funktioniert weiter ohne Google.") {
                FormRow("Mit Google anmelden", icon = Icons.Rounded.Login, onClick = { account.start(context) }, trailing = {
                    if (account.busy) CircularProgressIndicator(Modifier.size(20.dp), color = Palette.accentText, strokeWidth = 2.dp)
                })
            }
        } else {
            FormSection("Google-Konto", "Dein Freunde-Konto gehört zu diesem Google-Konto.") {
                FormRow("Angemeldet als", icon = Icons.Rounded.AccountCircle, value = account.email)
                Divider()
                FormRow("Abmelden", titleColor = Palette.danger, onClick = { confirmSignOut = true })
            }
            val remote = account.remote
            val footer = (if (remote != null) "Auf dem Server: ${remote.entries} Einträge vom ${date(remote.updated)}." else "Noch kein Backup auf dem Server.") +
                "\nGesichert werden Einträge, Rezepte, eigene Lebensmittel, Gewicht und Einstellungen, genau wie im lokalen Backup. Nur dein Google-Konto kommt an die Daten."
            FormSection("Server-Backup", footer) {
                FormToggle("Täglich automatisch sichern", account.autoEnabled, { account.autoEnabled = it }, Icons.Rounded.EventRepeat)
                Divider()
                FormRow("Jetzt sichern", icon = Icons.Rounded.CloudUpload, onClick = if (account.busy) null else ({ scope.launch { account.backupNow() } }), trailing = {
                    if (account.busy) CircularProgressIndicator(Modifier.size(20.dp), color = Palette.accentText, strokeWidth = 2.dp)
                })
                Divider()
                FormRow("Backup laden", icon = Icons.Rounded.CloudDownload,
                    titleColor = if (remote == null) C.textSecondary else C.textPrimary,
                    onClick = if (account.busy || remote == null) null else ({ confirmRestore = true }))
                if (remote != null) {
                    Divider()
                    FormRow("Server-Backup löschen", icon = Icons.Rounded.Delete, titleColor = Palette.danger, onClick = if (account.busy) null else ({ confirmDelete = true }))
                }
            }
        }
    }
    account.status?.let { FormSection { FormRow(it, titleColor = Palette.accentText) } }

    account.conflict?.let { c ->
        AlertDialog(onDismissRequest = {}, title = { Text("Dieses Google-Konto gibt es schon") },
            text = {
                val b = c.backup
                Text(if (b != null) "Auf dem Server liegt ein Backup mit ${b.entries} Einträgen vom ${date(b.updated)}. Wenn du es lädst, werden alle Daten auf diesem Gerät ersetzt" +
                        (if (c.hadFriends) " und das Freunde-Profil von diesem Gerät durch das des Google-Kontos." else ".")
                    else "Das Freunde-Profil von diesem Gerät wird durch das des Google-Kontos ersetzt. Deine Einträge bleiben.")
            },
            confirmButton = { TextButton({ scope.launch { account.resolve(c, load = true) } }) { Text(if (c.backup != null) "Backup laden" else "Weitermachen", color = Palette.danger) } },
            dismissButton = { TextButton({ scope.launch { account.resolve(c, load = false) } }) { Text("Abbrechen") } })
    }
    account.shrinkWarning?.let { s ->
        AlertDialog(onDismissRequest = { account.shrinkWarning = null }, title = { Text("Server-Backup überschreiben?") },
            text = { Text("Auf dem Server liegen ${s.remote} Einträge, auf diesem Gerät nur ${s.local}. Wenn du überschreibst, ist das größere Backup weg. Meinst du eher „Backup laden“?") },
            confirmButton = { TextButton({ account.shrinkWarning = null; scope.launch { account.backupNow(force = true) } }) { Text("Überschreiben", color = Palette.danger) } },
            dismissButton = { TextButton({ account.shrinkWarning = null }) { Text("Abbrechen") } })
    }
    if (confirmRestore) AlertDialog({ confirmRestore = false }, title = { Text("Backup laden?") },
        text = { Text("Alle Daten auf diesem Gerät werden durch das Server-Backup ersetzt.") },
        confirmButton = { TextButton({ confirmRestore = false; scope.launch { account.restore() } }) { Text("Ersetzen und laden", color = Palette.danger) } },
        dismissButton = { TextButton({ confirmRestore = false }) { Text("Abbrechen") } })
    if (confirmSignOut) AlertDialog({ confirmSignOut = false }, title = { Text("Abmelden?") },
        text = { Text("Deine Daten bleiben auf diesem Gerät. Freunde und Server-Backup sind erst nach der nächsten Anmeldung mit Google wieder da.") },
        confirmButton = { TextButton({ confirmSignOut = false; account.signOut() }) { Text("Abmelden", color = Palette.danger) } },
        dismissButton = { TextButton({ confirmSignOut = false }) { Text("Abbrechen") } })
    if (confirmDelete) AlertDialog({ confirmDelete = false }, title = { Text("Server-Backup löschen?") },
        text = { Text("Das Backup wird vom Server entfernt. Deine Daten auf diesem Gerät bleiben.") },
        confirmButton = { TextButton({ confirmDelete = false; scope.launch { account.deleteRemote() } }) { Text("Löschen", color = Palette.danger) } },
        dismissButton = { TextButton({ confirmDelete = false }) { Text("Abbrechen") } })
}
