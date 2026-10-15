package de.purrtion.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.purrtion.app.App

@Immutable
data class Colors(
    val accentSoft: Color,
    val background: Color,
    val card: Color,
    val cardAlt: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val line: Color,
    val pixelOutline: Color,
    val rail: Color,
    val dark: Boolean,
) {
    /** Background track for progress bars: tinted in light mode, neutral in dark mode. */
    fun track(color: Color): Color = if (dark) Color(0xFF2E2A35) else color.copy(alpha = 0.18f)
}

/** The same colours as the iOS app. */
object Palette {
    val accent = Color(0xFFFF8A4A)
    val protein = Color(0xFFFF6B8B)
    val carbs = Color(0xFFFFC145)
    val fat = Color(0xFF5BB8F0)
    val fiber = Color(0xFF6BCB77)
    val water = Color(0xFF6EC6FF)
    val danger = Color(0xFFFF5A5F)

    val light = Colors(
        accentSoft = Color(0xFFFFE7D6), background = Color(0xFFFFF8F1), card = Color.White, cardAlt = Color(0xFFF6EEE6),
        textPrimary = Color(0xFF2B2530), textSecondary = Color(0xFF8A8190), line = Color(0xFFEFE5DB),
        pixelOutline = Color(0xFF3B2F3F), rail = Color(0xFFFFC6A3), dark = false,
    )
    val dark = Colors(
        accentSoft = Color(0xFF302A35), background = Color(0xFF17151B), card = Color(0xFF24212A), cardAlt = Color(0xFF2E2A35),
        textPrimary = Color(0xFFF6F0EA), textSecondary = Color(0xFF9E96A6), line = Color(0xFF38333F),
        pixelOutline = Color(0xFF0C0A10), rail = Color(0xFF6B4634), dark = true,
    )
}

val LocalColors = staticCompositionLocalOf { Palette.light }

/** Shortcut: `C.card`, `C.textPrimary` … inside composables. */
val C: Colors @Composable get() = LocalColors.current

enum class Appearance(val label: String) { system("System"), light("Hell"), dark("Dunkel") }

/** Text style helper matching `Theme.font(size, weight)` on iOS. */
fun font(size: Int, weight: FontWeight = FontWeight.Normal): TextStyle = TextStyle(fontSize = size.sp, fontWeight = weight, lineHeight = (size * 1.25).sp)
fun font(size: TextUnit, weight: FontWeight = FontWeight.Normal): TextStyle = TextStyle(fontSize = size, fontWeight = weight)

val Radius = 22.dp
val RadiusSmall = 14.dp

@Composable
fun PurrtionTheme(content: @Composable () -> Unit) {
    val appearance = runCatching { Appearance.valueOf(App.prefs.string("appearance", "system")) }.getOrDefault(Appearance.system)
    val dark = when (appearance) {
        Appearance.system -> isSystemInDarkTheme()
        Appearance.light -> false
        Appearance.dark -> true
    }
    val colors = if (dark) Palette.dark else Palette.light
    val scheme = if (dark) darkColorScheme(
        primary = Palette.accent, onPrimary = Color.White, background = colors.background, surface = colors.card,
        surfaceVariant = colors.cardAlt, onBackground = colors.textPrimary, onSurface = colors.textPrimary,
        onSurfaceVariant = colors.textSecondary, outline = colors.line, secondary = Palette.accent, tertiary = Palette.fiber,
        surfaceContainer = colors.card, surfaceContainerHigh = colors.card, surfaceContainerLow = colors.background,
        primaryContainer = colors.accentSoft, onPrimaryContainer = Palette.accent, error = Palette.danger,
    ) else lightColorScheme(
        primary = Palette.accent, onPrimary = Color.White, background = colors.background, surface = colors.card,
        surfaceVariant = colors.cardAlt, onBackground = colors.textPrimary, onSurface = colors.textPrimary,
        onSurfaceVariant = colors.textSecondary, outline = colors.line, secondary = Palette.accent, tertiary = Palette.fiber,
        surfaceContainer = colors.card, surfaceContainerHigh = colors.card, surfaceContainerLow = colors.background,
        primaryContainer = colors.accentSoft, onPrimaryContainer = Palette.accent, error = Palette.danger,
    )
    CompositionLocalProvider(LocalColors provides colors) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
