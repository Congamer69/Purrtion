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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.purrtion.app.App

/** Look & feel choices from Einstellungen → Darstellung. The same keys and values as on iOS. */
enum class ThemeAccent(val id: String, val label: String, val hex: Long) {
    orange("orange", "Orange", 0xFFFF8A4A), berry("berry", "Beere", 0xFFFF5D8F), violet("violet", "Violett", 0xFF9B7BFF),
    sky("sky", "Himmel", 0xFF3E9BFF), mint("mint", "Minze", 0xFF2FBF94), graphite("graphite", "Graphit", 0xFF7C7C8A);
    val color: Color get() = Color(hex)
}

enum class ThemeCorners(val id: String, val label: String, val radius: Dp, val small: Dp) {
    compact("compact", "Eckig", 14.dp, 10.dp), normal("normal", "Rund", 22.dp, 14.dp), round("round", "Extra rund", 30.dp, 20.dp)
}

enum class ThemeCards(val id: String, val label: String) { shadow("shadow", "Schatten"), flat("flat", "Flach"), outline("outline", "Rand") }

enum class ThemeBackground(val id: String, val label: String) { warm("warm", "Warm"), neutral("neutral", "Neutral"), black("black", "Schwarz") }

enum class ThemeFont(val id: String, val label: String) { rounded("rounded", "Rund"), standard("standard", "Standard"), serif("serif", "Serif"), mono("mono", "Mono") }

object ThemeSetting {
    const val accentKey = "theme.accent"
    const val cornersKey = "theme.corners"
    const val cardsKey = "theme.cards"
    const val backgroundKey = "theme.bg"
    const val fontKey = "theme.font"

    val accent: ThemeAccent get() = ThemeAccent.entries.firstOrNull { it.id == App.prefs.string(accentKey, "") } ?: ThemeAccent.orange
    val corners: ThemeCorners get() = ThemeCorners.entries.firstOrNull { it.id == App.prefs.string(cornersKey, "") } ?: ThemeCorners.normal
    val cards: ThemeCards get() = ThemeCards.entries.firstOrNull { it.id == App.prefs.string(cardsKey, "") } ?: ThemeCards.shadow
    val background: ThemeBackground get() = ThemeBackground.entries.firstOrNull { it.id == App.prefs.string(backgroundKey, "") } ?: ThemeBackground.warm
    val font: ThemeFont get() = ThemeFont.entries.firstOrNull { it.id == App.prefs.string(fontKey, "") } ?: ThemeFont.rounded
}

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
    fun track(color: Color): Color = if (dark) cardAlt else color.copy(alpha = 0.18f)
}

private fun mix(a: Color, b: Color, t: Float): Color = Color(
    a.red * (1 - t) + b.red * t, a.green * (1 - t) + b.green * t, a.blue * (1 - t) + b.blue * t, 1f,
)

/** The same colours as the iOS app. */
object Palette {
    /** The chosen accent colour (reads the setting, so screens recompose when it changes). */
    val accent: Color get() = ThemeSetting.accent.color

    /** Set by [PurrtionTheme]; picks the readable variant of the semantic colours below. */
    @Volatile var isDark: Boolean = false

    /** The accent for text and thin icons: darker on light backgrounds, where the vivid fill colour is too pale to read. */
    val accentText: Color get() = if (isDark) accent else mix(accent, Color.Black, 0.34f)

    val protein: Color get() = if (isDark) Color(0xFFFF6B8B) else Color(0xFFD93A66)
    val carbs: Color get() = if (isDark) Color(0xFFFFC145) else Color(0xFFC98500)
    val fat: Color get() = if (isDark) Color(0xFF5BB8F0) else Color(0xFF1F86C8)
    val fiber: Color get() = if (isDark) Color(0xFF6BCB77) else Color(0xFF2A9347)
    val water: Color get() = if (isDark) Color(0xFF6EC6FF) else Color(0xFF1C84C4)
    val danger: Color get() = if (isDark) Color(0xFFFF5A5F) else Color(0xFFD92E34)

    private val outlineLight = Color(0xFF3B2F3F)
    private val outlineDark = Color(0xFF0C0A10)

    /** Static copies for places that only need the outline colour of the sprites. */
    val light: Colors get() = build(false)
    val dark: Colors get() = build(true)

    fun build(dark: Boolean): Colors {
        val tone = ThemeSetting.background
        val acc = accent
        val soft = if (dark) mix(Color(0xFF24212A), acc, 0.16f) else mix(acc, Color.White, 0.84f)
        fun pick(l: Long, d: Long) = Color(if (dark) d else l)
        return when (tone) {
            ThemeBackground.warm -> Colors(soft, pick(0xFFFFF8F1, 0xFF17151B), pick(0xFFFFFFFF, 0xFF24212A), pick(0xFFF6EEE6, 0xFF2E2A35),
                pick(0xFF2B2530, 0xFFF6F0EA), pick(0xFF655D6D, 0xFF9E96A6), pick(0xFFEFE5DB, 0xFF38333F),
                if (dark) outlineDark else outlineLight, if (dark) mix(Color(0xFF24212A), acc, 0.4f) else mix(acc, Color.White, 0.55f), dark)
            ThemeBackground.neutral -> Colors(soft, pick(0xFFF3F4F6, 0xFF121214), pick(0xFFFFFFFF, 0xFF1D1D20), pick(0xFFEBECEF, 0xFF2A2A2E),
                pick(0xFF2B2530, 0xFFF6F0EA), pick(0xFF655D6D, 0xFF9E96A6), pick(0xFFE1E2E6, 0xFF333337),
                if (dark) outlineDark else outlineLight, if (dark) mix(Color(0xFF1D1D20), acc, 0.4f) else mix(acc, Color.White, 0.55f), dark)
            ThemeBackground.black -> Colors(soft, pick(0xFFFFFFFF, 0xFF000000), pick(0xFFF4F4F6, 0xFF121214), pick(0xFFE9E9EC, 0xFF1D1D20),
                pick(0xFF2B2530, 0xFFF6F0EA), pick(0xFF655D6D, 0xFF9E96A6), pick(0xFFE3E3E6, 0xFF2A2A2E),
                if (dark) outlineDark else outlineLight, if (dark) mix(Color(0xFF121214), acc, 0.4f) else mix(acc, Color.White, 0.55f), dark)
        }
    }
}

val LocalColors = staticCompositionLocalOf { Palette.build(false) }

/** Shortcut: `C.card`, `C.textPrimary` … inside composables. */
val C: Colors @Composable get() = LocalColors.current

enum class Appearance(val label: String) { system("System"), light("Hell"), dark("Dunkel") }

/** Type scale of 2.0: caption 12, body 14, title 17, heading 22, display from 28 up. Sizes snap to the nearest step. */
private fun snap(size: Float): Float = when {
    size < 13 -> 12f
    size < 16 -> 14f
    size < 20 -> 17f
    size < 26 -> 22f
    else -> size
}

/** Two weights for text (medium, bold); display numbers (>= 26) may stay heavy. */
private fun snapWeight(size: Float, weight: FontWeight): FontWeight = when {
    weight.weight >= FontWeight.ExtraBold.weight -> if (size >= 26) FontWeight.ExtraBold else FontWeight.Bold
    weight.weight >= FontWeight.SemiBold.weight -> FontWeight.Bold
    else -> FontWeight.Medium
}

private val roundedFamily: FontFamily by lazy {
    runCatching {
        FontFamily(listOf(FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold, FontWeight.Bold, FontWeight.ExtraBold).map {
            androidx.compose.ui.text.font.Font(androidx.compose.ui.text.font.DeviceFontFamilyName("sans-serif-rounded"), it)
        })
    }.getOrDefault(FontFamily.Default)
}

private fun family(): FontFamily = when (ThemeSetting.font) {
    ThemeFont.rounded -> roundedFamily
    ThemeFont.standard -> FontFamily.Default
    ThemeFont.serif -> FontFamily.Serif
    ThemeFont.mono -> FontFamily.Monospace
}

/** Text style helper matching `Theme.font(size, weight)` on iOS. */
fun font(size: Int, weight: FontWeight = FontWeight.Normal): TextStyle {
    val s = snap(size.toFloat())
    return TextStyle(fontSize = s.sp, fontWeight = snapWeight(size.toFloat(), weight), lineHeight = (s * 1.25f).sp, fontFamily = family())
}
fun font(size: TextUnit, weight: FontWeight = FontWeight.Normal): TextStyle {
    val s = snap(size.value)
    return TextStyle(fontSize = s.sp, fontWeight = snapWeight(size.value, weight), fontFamily = family())
}

val Radius: Dp get() = ThemeSetting.corners.radius
val RadiusSmall: Dp get() = ThemeSetting.corners.small

@Composable
fun PurrtionTheme(content: @Composable () -> Unit) {
    val appearance = runCatching { Appearance.valueOf(App.prefs.string("appearance", "system")) }.getOrDefault(Appearance.system)
    val dark = when (appearance) {
        Appearance.system -> isSystemInDarkTheme()
        Appearance.light -> false
        Appearance.dark -> true
    }
    Palette.isDark = dark
    val colors = Palette.build(dark)
    val accent = Palette.accent
    val scheme = if (dark) darkColorScheme(
        primary = accent, onPrimary = Color.White, background = colors.background, surface = colors.card,
        surfaceVariant = colors.cardAlt, onBackground = colors.textPrimary, onSurface = colors.textPrimary,
        onSurfaceVariant = colors.textSecondary, outline = colors.line, secondary = accent, tertiary = Palette.fiber,
        surfaceContainer = colors.card, surfaceContainerHigh = colors.card, surfaceContainerLow = colors.background,
        primaryContainer = colors.accentSoft, onPrimaryContainer = accent, error = Palette.danger,
    ) else lightColorScheme(
        primary = accent, onPrimary = Color.White, background = colors.background, surface = colors.card,
        surfaceVariant = colors.cardAlt, onBackground = colors.textPrimary, onSurface = colors.textPrimary,
        onSurfaceVariant = colors.textSecondary, outline = colors.line, secondary = accent, tertiary = Palette.fiber,
        surfaceContainer = colors.card, surfaceContainerHigh = colors.card, surfaceContainerLow = colors.background,
        primaryContainer = colors.accentSoft, onPrimaryContainer = accent, error = Palette.danger,
    )
    CompositionLocalProvider(LocalColors provides colors) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
