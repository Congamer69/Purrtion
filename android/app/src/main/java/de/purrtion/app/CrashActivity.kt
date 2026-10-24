package de.purrtion.app

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import de.purrtion.app.domain.Diag
import de.purrtion.app.domain.SafeMode

/**
 * Shown after a crash. Plain Android views and its own process (see the manifest): it needs nothing from the app, the
 * database or the theme, so it works even when those are the reason for the crash.
 */
class CrashActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val report = Diag.lastCrash(this) ?: "Kein Bericht gefunden."
        val dp = resources.displayMetrics.density
        fun px(v: Int) = (v * dp).toInt()
        val accent = Color.parseColor("#E8733A")

        fun button(text: String, filled: Boolean, onClick: () -> Unit) = Button(this).apply {
            this.text = text
            isAllCaps = false
            textSize = 16f
            setTextColor(if (filled) Color.WHITE else accent)
            background = GradientDrawable().apply {
                cornerRadius = px(26).toFloat()
                if (filled) setColor(accent) else { setColor(Color.TRANSPARENT); setStroke(px(2), accent) }
            }
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, px(52)).apply { topMargin = px(10) }
            setOnClickListener { onClick() }
        }

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(px(20), px(24), px(20), px(24))
        }
        column.addView(TextView(this).apply { text = "Purrtion ist abgestürzt"; textSize = 24f; setTypeface(typeface, Typeface.BOLD); setTextColor(Color.parseColor("#2B2530")) })
        column.addView(TextView(this).apply {
            text = "Das tut uns leid. Deine Daten sind sicher. Kopiere den Bericht unten und schicke ihn weiter, damit der Fehler behoben werden kann."
            textSize = 15f; setTextColor(Color.parseColor("#655D6D")); setPadding(0, px(8), 0, px(12))
        })
        column.addView(button("Bericht kopieren", true) {
            (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Purrtion-Absturzbericht", report))
            Toast.makeText(this, "Bericht kopiert", Toast.LENGTH_SHORT).show()
        })
        column.addView(button("Bericht teilen", false) {
            val send = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_SUBJECT, "Purrtion Absturzbericht"); putExtra(Intent.EXTRA_TEXT, report) }
            startActivity(Intent.createChooser(send, "Bericht teilen"))
        })
        column.addView(button("Abgesichert öffnen", false) { openApp(safe = true) })
        column.addView(button("Normal öffnen", false) { openApp(safe = false) })
        column.addView(TextView(this).apply {
            text = "Abgesichert startet die App einmal mit Standardlook und ohne Hintergrundaufgaben und Freunde-Seite."
            textSize = 13f; setTextColor(Color.parseColor("#655D6D")); setPadding(0, px(8), 0, px(16))
        })
        column.addView(TextView(this).apply {
            text = report
            textSize = 11f; typeface = Typeface.MONOSPACE; setTextIsSelectable(true); setTextColor(Color.parseColor("#2B2530"))
            setBackgroundColor(Color.parseColor("#F3EDE6")); setPadding(px(12), px(12), px(12), px(12))
        })

        val scroll = ScrollView(this).apply {
            setBackgroundColor(Color.parseColor("#FFF8F1"))
            addView(column)
            // Edge to edge: keep the content clear of the system bars.
            setOnApplyWindowInsetsListener { v, insets ->
                v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
                insets
            }
        }
        setContentView(scroll)
        // Dark status bar icons on the light page.
        if (android.os.Build.VERSION.SDK_INT >= 30) window.insetsController?.setSystemBarsAppearance(
            android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
            android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS)
        else @Suppress("DEPRECATION") scroll.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
    }

    private fun openApp(safe: Boolean) {
        Diag.clearPending(this)
        if (safe) SafeMode.requestNextStart(this)
        startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        finishAndRemoveTask()
        // This process is only for the report; the app starts fresh in its own.
        android.os.Process.killProcess(android.os.Process.myPid())
    }

    @Deprecated("Back leaves without starting the app; the report stays available in Einstellungen → Diagnose.")
    override fun onBackPressed() { Diag.clearPending(this); finishAndRemoveTask() }
}
