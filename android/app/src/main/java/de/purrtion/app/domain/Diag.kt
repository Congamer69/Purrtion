package de.purrtion.app.domain

import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import de.purrtion.app.BuildConfig
import de.purrtion.app.CrashActivity
import kotlinx.coroutines.CancellationException
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.system.exitProcess

/**
 * Crash and error diagnostics. A crash is written to a report file and shown on a plain screen ([CrashActivity]) that
 * works without the rest of the app, so it can be copied and shared. Errors that were caught and survived are kept too.
 */
object Diag {
    private const val MAX_EVENTS = 80
    private const val MAX_ERRORS = 25
    private val events = ArrayDeque<String>()
    private val errors = ArrayDeque<String>()
    private val clock = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)
    private var appContext: Context? = null

    /** Single prefs keys that are safe to put into a report (no keys, tokens or personal data). */
    private val reportPrefs = listOf("theme.accent", "theme.corners", "theme.cards", "theme.bg", "theme.font", "catPalette", "appearance", "startTab", "haptics", "stats.layout")

    // MARK: Breadcrumbs

    /** A short note about what the app is doing. The last ones go into every report. */
    fun log(message: String) = synchronized(events) {
        events.addLast("${clock.format(Date())} $message")
        while (events.size > MAX_EVENTS) events.removeFirst()
    }

    /** Something failed but the app carries on with a fallback. */
    fun warn(where: String, t: Throwable) = synchronized(errors) {
        errors.addLast("${clock.format(Date())} $where: ${t.javaClass.simpleName}: ${t.message}\n${t.stackTraceToString().lines().drop(1).take(6).joinToString("\n")}")
        while (errors.size > MAX_ERRORS) errors.removeFirst()
        log("FEHLER in $where: ${t.javaClass.simpleName}")
    }

    /** Runs [block]; on any failure the error is recorded and [fallback] is returned instead of crashing. */
    inline fun <T> safe(where: String, fallback: T, block: () -> T): T = try { block() } catch (e: CancellationException) { throw e } catch (t: Throwable) { warn(where, t); fallback }

    /** Like [safe] for work without a result. */
    inline fun guard(where: String, block: () -> Unit) = safe(where, Unit, block)

    // MARK: Crash handling

    fun install(app: Application) {
        appContext = app.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                File(app.filesDir, "crash-report.txt").writeText(report(error, thread))
                File(app.filesDir, "crash-pending").writeText("1")
                val intent = Intent(app, CrashActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                app.startActivity(intent)
                // The report screen runs in its own process, so this one can end quietly (no system "wurde beendet" box).
                Process.killProcess(Process.myPid())
                exitProcess(10)
            } catch (_: Throwable) {
                previous?.uncaughtException(thread, error)
            }
        }
        log("Start ${BuildConfig.VERSION_NAME}")
    }

    fun lastCrash(context: Context): String? = runCatching { File(context.filesDir, "crash-report.txt").takeIf { it.exists() }?.readText() }.getOrNull()
    fun hasPendingCrash(context: Context): Boolean = File(context.filesDir, "crash-pending").exists()
    fun clearPending(context: Context) { File(context.filesDir, "crash-pending").delete() }

    // MARK: Report

    /** The text people can copy: app and device, the error, what happened before and which errors were survived. */
    fun report(error: Throwable? = null, thread: Thread? = null): String {
        val ctx = appContext
        val sb = StringBuilder()
        sb.appendLine("Purrtion ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})${if (BuildConfig.DEBUG) " debug" else ""}")
        sb.appendLine("Zeit: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())}")
        sb.appendLine("Gerät: ${Build.MANUFACTURER} ${Build.MODEL} (${Build.DEVICE})")
        sb.appendLine("Android: ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}), ${Build.SUPPORTED_ABIS.firstOrNull()}")
        sb.appendLine("Sprache: ${Locale.getDefault()}")
        sb.appendLine("Abgesicherter Modus: ${if (SafeMode.active) "ja" else "nein"}")
        if (ctx != null) {
            val sp = runCatching { ctx.getSharedPreferences("purrtion", Context.MODE_PRIVATE).all }.getOrNull()
            if (sp != null) {
                sb.appendLine("Freunde-Server: ${if (sp["friends.server"] != null) "verbunden" else "nein"}")
                for (k in reportPrefs) sp[k]?.let { sb.appendLine("$k = ${it.toString().take(120)}") }
            }
        }
        if (error != null) {
            sb.appendLine()
            sb.appendLine("ABSTURZ${thread?.let { " in Thread \"${it.name}\"" } ?: ""}")
            val w = StringWriter(); error.printStackTrace(PrintWriter(w)); sb.appendLine(w.toString().take(6000))
        }
        synchronized(errors) { if (errors.isNotEmpty()) { sb.appendLine(); sb.appendLine("ABGEFANGENE FEHLER"); errors.forEach { sb.appendLine(it) } } }
        synchronized(events) { if (events.isNotEmpty()) { sb.appendLine(); sb.appendLine("VERLAUF"); events.forEach { sb.appendLine(it) } } }
        return sb.toString()
    }
}

/**
 * Abgesicherter Modus: one start with the plain look, no background work and no friends page. It is set on the crash
 * screen and used up by the next start, so a crash caused by a setting or the server still leaves a working app.
 */
object SafeMode {
    @Volatile var active = false
        private set

    private fun marker(context: Context) = File(context.filesDir, "safe-mode")

    /** Called once per process start. */
    fun consume(context: Context) { active = runCatching { marker(context).delete() }.getOrDefault(false) }

    fun requestNextStart(context: Context) { runCatching { marker(context).writeText("1") } }
}
