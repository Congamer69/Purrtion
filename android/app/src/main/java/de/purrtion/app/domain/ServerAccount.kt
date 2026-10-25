package de.purrtion.app.domain

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import de.purrtion.app.App
import java.util.UUID

/**
 * The server account: a Google login linked to the anonymous Firebase account, so friends and the server backup follow the
 * person to a new device. Without a login nothing changes: the local backup keeps working on its own.
 */
object ServerAccount {
    const val EMAIL_KEY = "account.email"
    const val AUTO_KEY = "account.autoBackup"
    private const val LAST_KEY = "account.lastMillis"
    private const val STATE_KEY = "account.pendingState"

    val email: String? get() = App.prefs.optString(EMAIL_KEY)
    val isLinked: Boolean get() = email != null && FirebaseAuth.hasAccount
    var autoEnabled: Boolean
        get() = App.prefs.bool(AUTO_KEY, true)
        set(v) = App.prefs.set(AUTO_KEY, v)
    val lastBackup: Long? get() = App.prefs.double(LAST_KEY, 0.0).toLong().takeIf { it > 0 }

    var busy by mutableStateOf(false); private set
    var status by mutableStateOf<String?>(null)
    /** Server backup as last seen. */
    var remote by mutableStateOf<ServerBackup.Meta?>(null); private set
    /** The Google account already belongs to another uid (often a new device): ask before taking it over. */
    var conflict by mutableStateOf<Conflict?>(null)
    /** Backing up would replace a much bigger server backup: ask first. */
    var shrinkWarning by mutableStateOf<ServerBackup.Shrinks?>(null)

    class Conflict(val backup: ServerBackup.Meta?, val previous: Pair<String, String>?, val hadFriends: Boolean)

    /** Where the login page lives: the hosting site of the server, taken from the invite link. */
    private val origin: String?
        get() {
            val uri = runCatching { Uri.parse(FirebaseConfig.inviteUrl) }.getOrNull()
            if (uri?.scheme != null && uri.host != null) return "${uri.scheme}://${uri.host}"
            return FirebaseConfig.projectId.takeIf { it.isNotEmpty() }?.let { "https://$it.web.app" }
        }

    // MARK: Login

    /** Opens the login page in the browser; the answer arrives in [complete] through purrtion://auth. */
    fun start(context: Context) {
        val origin = origin
        if (origin == null || !FirebaseConfig.isAvailable) { status = "Verbinde zuerst den Server."; return }
        val state = UUID.randomUUID().toString()
        App.prefs.set(STATE_KEY, state)
        status = null
        val url = Uri.parse("$origin/auth/").buildUpon()
            .appendQueryParameter("k", FirebaseConfig.apiKey).appendQueryParameter("p", FirebaseConfig.projectId)
            .appendQueryParameter("s", state).build()
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, url).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
            .onFailure { status = "Kein Browser gefunden." }
    }

    suspend fun complete(uri: Uri) {
        val expected = App.prefs.optString(STATE_KEY)
        App.prefs.remove(STATE_KEY)
        if (expected == null || uri.getQueryParameter("s") != expected) { status = "Die Antwort gehört nicht zu einer Anmeldung in dieser App."; return }
        val token = uri.getQueryParameter("id")
        if (token == null) { status = "Google hat die Anmeldung nicht bestätigt."; return }
        busy = true
        try { finish(token) } catch (e: FirebaseException) { status = "Anmeldung fehlgeschlagen. ${e.message}" } finally { busy = false }
    }

    private suspend fun finish(googleToken: String) {
        val previous = if (FirebaseAuth.hasAccount) (FirebaseAuth.uid ?: "") to (Secrets.get("fb.refresh") ?: "") else null
        val hadFriends = FriendsStore.me != null
        var result = try {
            FirebaseAuth.googleSignIn(googleToken, link = previous != null)
        } catch (e: FirebaseException) {
            if (e.message?.contains("ALREADY_LINKED") == true) FirebaseAuth.googleSignIn(googleToken, link = false) else throw e
        }
        FirebaseAuth.use(result)
        // The Google account already had a login on the server, but without any data (for example from an earlier,
        // interrupted sign-in): drop that empty login and link Google to this device's account instead, so nothing is lost.
        if (previous != null && previous.first != result.uid && isEmptyAccount()) {
            FirebaseAuth.deleteAccount()
            FirebaseAuth.adopt(previous.first, previous.second)
            result = FirebaseAuth.googleSignIn(googleToken, link = true)
            FirebaseAuth.use(result)
        }
        App.prefs.set(EMAIL_KEY, result.email.ifEmpty { "Google" })
        if (previous?.first == result.uid) {
            // Linked: same account, friends and code stay.
            autoEnabled = true
            status = "Angemeldet. Dein Konto ist mit Google verknüpft."
            remote = runCatching { ServerBackup.meta() }.getOrNull()
            return
        }
        val backup = runCatching { ServerBackup.meta() }.getOrNull()
        remote = backup
        if (backup != null || (previous != null && hadFriends)) conflict = Conflict(backup, previous, previous != null && hadFriends)
        else takeOver()
    }

    /** True when the signed-in account has neither a friends profile nor a backup on the server. */
    private suspend fun isEmptyAccount(): Boolean {
        try { if (ServerBackup.meta() != null) return false } catch (e: Exception) { return false }
        val uid = FirebaseAuth.uid ?: return false
        return try { FirebaseREST.get("users/$uid"); false } catch (e: FirebaseException) { e === FirebaseException.notFound }
    }

    /** The Google account's data replaces what the old account had on this device (friends are read from the server). */
    private fun takeOver() {
        FriendsStore.reloadAfterAccountChange()
        autoEnabled = true
        status = "Angemeldet."
    }

    /** Answer to the conflict dialog. */
    suspend fun resolve(c: Conflict, load: Boolean) {
        conflict = null
        if (!load) {
            // Back to the account this device had.
            c.previous?.let { FirebaseAuth.adopt(it.first, it.second) } ?: FirebaseAuth.signOut()
            App.prefs.remove(EMAIL_KEY)
            remote = null
            status = "Abgebrochen. Es wurde nichts verändert."
            return
        }
        takeOver()
        if (c.backup != null) restore() else backupNow(force = true)
    }

    fun signOutLocal() {
        FirebaseAuth.signOut()
        App.prefs.remove(EMAIL_KEY)
        remote = null
    }

    fun signOut() {
        signOutLocal()
        FriendsStore.reloadAfterAccountChange()
        status = "Abgemeldet. Deine Daten auf diesem Gerät bleiben."
    }

    // MARK: Backup

    suspend fun refreshRemote() {
        if (isLinked) remote = runCatching { ServerBackup.meta() }.getOrNull()
    }

    suspend fun backupNow(force: Boolean = false, automatic: Boolean = false) {
        if (!isLinked || busy) return
        busy = true
        try {
            remote = ServerBackup.upload(force)
            App.prefs.set(LAST_KEY, System.currentTimeMillis().toDouble())
            status = if (automatic) null else "Gesichert ✓"
        } catch (s: ServerBackup.Shrinks) {
            if (automatic) status = "Automatisch sichern pausiert: Das Server-Backup hat deutlich mehr Einträge (${s.remote}) als dieses Gerät (${s.local})."
            else shrinkWarning = s
        } catch (e: kotlinx.coroutines.CancellationException) { throw e
        } catch (e: Exception) {
            if (!automatic) status = "Sicherung fehlgeschlagen. ${e.message ?: ""}"
        } finally { busy = false }
    }

    /** Replaces the data on this device with the server backup. */
    suspend fun restore() {
        if (!isLinked) return
        busy = true
        try {
            val p = Backup.restore(ServerBackup.download())
            App.prefs.set(LAST_KEY, System.currentTimeMillis().toDouble())
            remote = runCatching { ServerBackup.meta() }.getOrNull()
            status = "Wiederhergestellt: ${p.entries.size} Einträge, ${p.custom.size} eigene Lebensmittel und Rezepte."
        } catch (e: kotlinx.coroutines.CancellationException) { throw e
        } catch (e: Exception) {
            status = "Wiederherstellung fehlgeschlagen. ${e.message ?: ""}"
        } finally { busy = false }
    }

    suspend fun deleteRemote() {
        busy = true
        try {
            ServerBackup.delete(); remote = null; status = "Das Server-Backup ist gelöscht."
        } catch (e: kotlinx.coroutines.CancellationException) { throw e
        } catch (e: Exception) { status = "Löschen fehlgeschlagen. ${e.message ?: ""}" } finally { busy = false }
    }

    /** Called when the app starts: about once a day. */
    suspend fun autoBackupIfNeeded() {
        if (!isLinked || !autoEnabled || busy) return
        val last = lastBackup
        if (last != null && System.currentTimeMillis() - last < 20 * 3600 * 1000L) return
        backupNow(automatic = true)
    }
}
