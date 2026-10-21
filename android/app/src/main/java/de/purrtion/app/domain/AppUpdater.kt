package de.purrtion.app.domain

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import de.purrtion.app.App
import de.purrtion.app.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import okhttp3.Request
import java.io.File

/**
 * Updates the Android app from the GitHub releases, inside the app.
 *
 * Nothing can get lost on the way:
 * - Android keeps all app data on an update (same package, same signing key). Before installing, the downloaded APK is
 *   checked: same app, newer version, same signature. An APK that would not install as an update is never offered.
 * - A complete backup (entries, recipes, weights, settings incl. the friends server) is written to the app's own storage
 *   first, and to the backup folder if one is set up.
 * - The friends server lives in the settings (see [FirebaseConfig.persistBundled]), so it stays after the update too.
 */
object AppUpdater {
    private const val LATEST = "https://api.github.com/repos/Congamer69/Purrtion/releases/latest"
    private const val LAST_CHECK = "update.lastCheckMillis"
    const val ACTION_STATUS = "de.purrtion.app.UPDATE_STATUS"

    data class Release(val version: String, val notes: String, val apkUrl: String, val size: Long)

    var available by mutableStateOf<Release?>(null); private set
    var status by mutableStateOf<String?>(null)
    var progress by mutableStateOf<Float?>(null); private set
    var isChecking by mutableStateOf(false); private set

    val currentVersion: String get() = BuildConfig.VERSION_NAME

    /** "1.7.10" > "1.7.9" */
    fun isNewer(remote: String, local: String = currentVersion): Boolean {
        val a = remote.trimStart('v').split('.').map { it.toIntOrNull() ?: 0 }
        val b = local.trimStart('v').split('.').map { it.toIntOrNull() ?: 0 }
        for (i in 0 until maxOf(a.size, b.size)) {
            val x = a.getOrElse(i) { 0 }; val y = b.getOrElse(i) { 0 }
            if (x != y) return x > y
        }
        return false
    }

    /** Quiet check at most once a day (on app start), so the settings can show "Update verfügbar". */
    fun checkDaily() {
        val last = App.prefs.double(LAST_CHECK, 0.0).toLong()
        if (System.currentTimeMillis() - last < 24 * 3_600_000L) return
        App.scope.launch { check(silent = true) }
    }

    suspend fun check(silent: Boolean = false) {
        if (isChecking) return
        isChecking = true
        if (!silent) status = "Suche nach Updates …"
        try {
            val json = Http.getJson(LATEST, mapOf("Accept" to "application/vnd.github+json", "User-Agent" to "Purrtion")) as? JsonObject
                ?: throw IllegalStateException()
            val tag = json["tag_name"]?.jsonPrimitive?.contentOrNull ?: throw IllegalStateException()
            val asset = (json["assets"] as? JsonArray)?.mapNotNull { it as? JsonObject }
                ?.firstOrNull { it["name"]?.jsonPrimitive?.contentOrNull?.endsWith(".apk") == true }
            App.prefs.set(LAST_CHECK, System.currentTimeMillis().toDouble())
            val version = tag.trimStart('v')
            available = if (asset != null && isNewer(version)) Release(
                version, json["body"]?.jsonPrimitive?.contentOrNull ?: "",
                asset["browser_download_url"]?.jsonPrimitive?.contentOrNull ?: throw IllegalStateException(),
                asset["size"]?.jsonPrimitive?.longOrNull ?: 0,
            ) else null
            status = if (silent) null else if (available == null) "Du hast die neueste Version ($currentVersion)." else null
        } catch (e: Exception) {
            if (!silent) status = "Keine Verbindung zu GitHub. Versuch es gleich nochmal."
        } finally {
            isChecking = false
        }
    }

    /** Android asks once whether Purrtion may install apps. */
    fun canInstall(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || context.packageManager.canRequestPackageInstalls()

    /** Update that waits for the "install apps" permission; continued in [resumeIfAllowed] when the user is back. */
    private var pending: Release? = null

    fun waitForPermission(context: Context, release: Release) {
        pending = release
        context.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    /** Called when the app comes back to the front (MainActivity.onResume). */
    fun resumeIfAllowed(context: Context) {
        val r = pending ?: return
        if (!canInstall(context)) { status = "Ohne die Erlaubnis kann Purrtion sich nicht selbst aktualisieren."; pending = null; return }
        pending = null
        App.scope.launch { install(context, r) }
    }

    /** Backup → download → check → hand over to the Android installer. */
    suspend fun install(context: Context, release: Release) {
        if (progress != null) return
        progress = 0f
        try {
            status = "Sichere deine Daten …"
            safetyBackup(context, release.version)
            status = "Lade Version ${release.version} …"
            val apk = download(context, release)
            status = "Prüfe das Update …"
            verify(context, apk, release)?.let { throw IllegalStateException(it) }
            status = "Installiere …"
            withContext(Dispatchers.IO) { startInstaller(context, apk) }
            status = "Bitte im Android-Fenster auf „Aktualisieren“ tippen. Deine Daten bleiben erhalten."
        } catch (e: Exception) {
            status = e.message ?: "Update fehlgeschlagen. Deine Daten sind unverändert."
        } finally {
            progress = null
        }
    }

    /** Complete backup into the app's own storage (last three kept), and into the backup folder when set up. */
    private suspend fun safetyBackup(context: Context, toVersion: String) {
        val text = Backup.data()
        withContext(Dispatchers.IO) {
            val dir = File(context.filesDir, "update-backups").apply { mkdirs() }
            File(dir, "vor-update-${currentVersion}-auf-$toVersion-${System.currentTimeMillis()}.json").writeText(text)
            dir.listFiles()?.sortedByDescending { it.lastModified() }?.drop(3)?.forEach { it.delete() }
        }
        if (Backup.folderUri != null) runCatching { Backup.writeToFolder(context) }
    }

    private suspend fun download(context: Context, release: Release): File = withContext(Dispatchers.IO) {
        val dir = File(context.cacheDir, "updates").apply { deleteRecursively(); mkdirs() }
        val file = File(dir, "Purrtion-${release.version}.apk")
        val response = Http.client.newCall(Request.Builder().url(release.apkUrl).header("User-Agent", "Purrtion").build()).execute()
        response.use { r ->
            if (!r.isSuccessful) throw IllegalStateException("Download fehlgeschlagen (${r.code}). Deine Daten sind unverändert.")
            val body = r.body ?: throw IllegalStateException("Download fehlgeschlagen. Deine Daten sind unverändert.")
            val total = body.contentLength().takeIf { it > 0 } ?: release.size
            body.byteStream().use { input ->
                file.outputStream().use { out ->
                    val buf = ByteArray(64 * 1024)
                    var done = 0L
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        done += n
                        if (total > 0) progress = (done.toFloat() / total).coerceIn(0f, 1f)
                    }
                }
            }
        }
        file
    }

    /** Null when the APK installs as a normal update (same app, newer, same signature), otherwise the reason. */
    @Suppress("DEPRECATION")
    private fun verify(context: Context, apk: File, release: Release): String? {
        val pm = context.packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val archive = pm.getPackageArchiveInfo(apk.path, flags) ?: return "Die heruntergeladene Datei ist beschädigt. Deine Daten sind unverändert."
        if (archive.packageName != context.packageName) return "Das ist keine Purrtion-App. Update abgebrochen."
        val installed = pm.getPackageInfo(context.packageName, flags)
        val newCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) archive.longVersionCode else archive.versionCode.toLong()
        val oldCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) installed.longVersionCode else installed.versionCode.toLong()
        if (newCode <= oldCode) return "Version ${release.version} ist nicht neuer als deine. Update abgebrochen."
        fun signers(p: android.content.pm.PackageInfo): Set<String> =
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) p.signingInfo?.apkContentsSigners else p.signatures)
                ?.map { it.toCharsString() }?.toSet() ?: emptySet()
        if (signers(archive).isEmpty() || signers(archive) != signers(installed))
            return "Dieses Update ist anders signiert und würde deine Daten nicht übernehmen. Es wurde deshalb nicht installiert."
        return null
    }

    private fun startInstaller(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val id = installer.createSession(params)
        installer.openSession(id).use { session ->
            session.openWrite("purrtion.apk", 0, apk.length()).use { out -> apk.inputStream().use { it.copyTo(out) }; session.fsync(out) }
            val intent = Intent(context, UpdateReceiver::class.java).setAction(ACTION_STATUS)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            session.commit(PendingIntent.getBroadcast(context, id, intent, flags).intentSender)
        }
    }
}

/** Results of the Android installer: asks the user to confirm, or reports why it did not work. */
class UpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirm = (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                    else intent.getParcelableExtra(Intent.EXTRA_INTENT)) ?: return
                context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            PackageInstaller.STATUS_SUCCESS -> AppUpdater.status = "Aktualisiert."
            PackageInstaller.STATUS_FAILURE_ABORTED -> AppUpdater.status = "Update abgebrochen. Deine Daten sind unverändert."
            else -> AppUpdater.status = "Update nicht installiert: ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "unbekannter Fehler"}. Deine Daten sind unverändert."
        }
    }
}
