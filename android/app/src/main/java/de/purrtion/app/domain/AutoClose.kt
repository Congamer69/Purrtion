package de.purrtion.app.domain

import de.purrtion.app.model.NutrientKey
import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import de.purrtion.app.App
import de.purrtion.app.MainActivity
import de.purrtion.app.R
import de.purrtion.app.data.DayReview
import de.purrtion.app.model.weekdayName
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.concurrent.TimeUnit
import kotlin.math.abs

object Notifications {
    const val REVIEW_CHANNEL = "review"
    const val EXTRA_REVIEW_DAY = "reviewDay"

    fun createChannels(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(REVIEW_CHANNEL, "Tagesfazit", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Mitteilung, wenn die KI deinen Vortag analysiert hat"
        })
    }

    fun canPost(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun review(context: Context, review: DayReview) {
        if (!canPost(context)) return
        val day = LocalDate.ofEpochDay(review.day)
        var body = "${day.weekdayName()}: ${review.rating}"
        review.score?.let { score ->
            body += " · Health Score $score"
            val before = review.scoreBefore
            if (before != null && before != score) body += " (${if (score > before) "+" else "−"}${abs(score - before)} durch KI)"
        }
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_REVIEW_DAY, review.day)
        }
        val pi = PendingIntent.getActivity(context, review.day.toInt(), intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(context, REVIEW_CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Dein Vortag ist analysiert 🐾")
            .setContentText(body)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(review.day.toInt(), n) }
    }
}

/**
 * Nightly "Tag abschließen" for the previous day: scheduled for ~0:30 via WorkManager (with network) and caught up
 * when the app is opened.
 */
object AutoClose {
    const val ENABLED_KEY = "vision.autoCloseDay"
    private const val LAST_DAY_KEY = "vision.autoCloseLastDayEpoch"
    private const val LAST_ATTEMPT_KEY = "autoClose.lastAttemptMillis"
    private const val WORK = "closeday"

    val isEnabled: Boolean get() = App.prefs.bool(ENABLED_KEY)

    /** After a night out the next run waits for its end (set by [runIfNeeded], used by [schedule]). */
    private var deferredUntil: LocalDateTime? = null

    /** Next run at 0:30, or later the same night when a night out is still going on. */
    fun schedule(context: Context = App.context) {
        val wm = WorkManager.getInstance(context)
        if (!isEnabled) { wm.cancelUniqueWork(WORK); return }
        val now = LocalDateTime.now()
        var start = deferredUntil?.takeIf { it.isAfter(now) } ?: LocalDate.now().atTime(LocalTime.of(0, 30))
        if (!start.isAfter(now)) start = start.plusDays(1)
        val request = OneTimeWorkRequestBuilder<CloseDayWorker>()
            .setInitialDelay(Duration.between(now, start).toMillis(), TimeUnit.MILLISECONDS)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        wm.enqueueUniqueWork(WORK, ExistingWorkPolicy.REPLACE, request)
    }

    /** Analyses yesterday when enabled, after 0:30 (after a night out 5:00), not done yet and there is something to analyse. */
    suspend fun runIfNeeded(context: Context = App.context): Boolean {
        if (!isEnabled) return true
        val now = LocalDateTime.now()
        if (now.toLocalTime().isBefore(LocalTime.of(0, 30))) return true
        val yesterday = LocalDate.now().minusDays(1)
        val prefs = App.prefs
        if (prefs.double(LAST_DAY_KEY, -1.0) >= yesterday.toEpochDay()) return true
        val lastAttempt = prefs.double(LAST_ATTEMPT_KEY, 0.0)
        if (System.currentTimeMillis() - lastAttempt < 20 * 60_000) return false

        val entries = App.db.entries().day(yesterday.toEpochDay())
        val review = App.db.reviews().day(yesterday.toEpochDay())
        if (entries.isEmpty() || review != null) {
            prefs.set(LAST_DAY_KEY, yesterday.toEpochDay().toDouble())
            return true
        }
        // A night out may still be going on: drinks after midnight count to yesterday until 5:00, so wait for them.
        val nightEnd = LocalDate.now().atTime(BloodAlcohol.NIGHT_END_HOUR, 0)
        if (now.isBefore(nightEnd) && entries.any { (it.nutrients[NutrientKey.alcohol] ?: 0.0) >= 1 }) {
            deferredUntil = nightEnd
            schedule(context)
            return true
        }
        prefs.set(LAST_ATTEMPT_KEY, System.currentTimeMillis().toDouble())
        if (App.goals.activityEnabled) HealthConnect.refreshActivity(3)
        return try {
            val r = DayCloser.close(yesterday, App.goals, automatic = true)
            prefs.set(LAST_DAY_KEY, yesterday.toEpochDay().toDouble())
            prefs.remove(LAST_ATTEMPT_KEY)
            Notifications.review(context, r)
            true
        } catch (e: Exception) {
            false
        }
    }
}

class CloseDayWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        App.init(applicationContext)
        val ok = AutoClose.runIfNeeded(applicationContext)
        AutoClose.schedule(applicationContext)   // next night
        return if (ok) Result.success() else Result.retry()
    }
}
