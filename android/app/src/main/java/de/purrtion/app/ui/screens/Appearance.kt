package de.purrtion.app.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.toArgb
import de.purrtion.app.ui.CalorieRing
import de.purrtion.app.ui.Divider
import de.purrtion.app.ui.FormSection
import de.purrtion.app.ui.FormToggle
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.Segmented
import de.purrtion.app.ui.TextInput
import de.purrtion.app.ui.card
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.pixel.CatPalette
import de.purrtion.app.ui.pixel.PixelSpriteView
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.theme.Appearance
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.Radius
import de.purrtion.app.ui.theme.RadiusSmall
import de.purrtion.app.ui.theme.ThemeAccent
import de.purrtion.app.ui.theme.ThemeBackground
import de.purrtion.app.ui.theme.ThemeCards
import de.purrtion.app.ui.theme.ThemeCorners
import de.purrtion.app.ui.theme.ThemeFont
import de.purrtion.app.ui.theme.ThemeSetting
import de.purrtion.app.ui.theme.font

/** Einstellungen → Darstellung: look & feel with a live preview, behaviour and the companion. */
@Composable
fun AppearanceScreen() {
    val prefs = App.prefs
    val h = rememberHaptics()
    val isDark = C.dark
    Screen("Darstellung", back = true) {
        ThemePreview()

        FormSection("Du", "Erscheint in der Begrüßung auf „Heute“ und im Profil.") {
            TextInput(prefs.string("profile.name", ""), { prefs.set("profile.name", it.take(30)) }, "Dein Name (optional)",
                Modifier.fillMaxWidth().padding(vertical = 12.dp))
        }

        var wheelOpen by remember { mutableStateOf(false) }
        FormSection("Akzentfarbe", "Der letzte Kreis öffnet ein Farbrad für eine eigene Farbe.") {
            Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                for (a in ThemeAccent.entries) {
                    val on = ThemeSetting.accent == a
                    val isCustom = a == ThemeAccent.custom
                    Box(Modifier.weight(1f).height(44.dp), contentAlignment = Alignment.Center) {
                        Box(Modifier.size(40.dp).clip(CircleShape)
                            .then(if (isCustom && !on) Modifier.background(Brush.sweepGradient(listOf(Color.Red, Color.Yellow, Color.Green, Color.Cyan, Color.Blue, Color.Magenta, Color.Red)))
                                  else Modifier.background(a.color))
                            .then(if (on) Modifier.border(BorderStroke(2.dp, C.textPrimary), CircleShape) else Modifier)
                            .clickable { h.tap(); prefs.set(ThemeSetting.accentKey, a.id); if (isCustom) wheelOpen = true }, contentAlignment = Alignment.Center) {
                            if (on) Icon(Icons.Rounded.Check, a.label, Modifier.size(18.dp), tint = Color.White)
                        }
                    }
                }
            }
        }
        if (wheelOpen) ColorWheelDialog(ThemeSetting.customColor, onDismiss = { wheelOpen = false }) { picked ->
            val rgb = (picked.toArgb() and 0xFFFFFF).toString(16).padStart(6, '0')
            prefs.set(ThemeSetting.customKey, rgb); prefs.set(ThemeSetting.accentKey, ThemeAccent.custom.id); wheelOpen = false
        }

        val paletteId = prefs.string("catPalette", "ginger")
        FormSection(if (paletteId == CatPalette.dog.id) "Dein Hund & Look" else "Deine Katze & Look") {
            Row(Modifier.fillMaxWidth().padding(vertical = 10.dp)) {
                // The dog is a secret and never listed; while it is active no cat is selected.
                for (p in CatPalette.all) {
                    val selected = paletteId == p.id
                    val scale by animateFloatAsState(if (selected) 1.12f else 1f, label = "palette")
                    Column(Modifier.weight(1f).clickable { h.tap(); prefs.set("catPalette", p.id) }, horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        PixelSpriteView(if (selected) Sprites.happy else Sprites.sit, 3.dp, p, Modifier.scale(scale))
                        Text(p.name, style = font(12, if (selected) FontWeight.Bold else FontWeight.Normal), color = if (selected) Palette.accent else C.textSecondary)
                    }
                }
            }
            val appearance = runCatching { Appearance.valueOf(prefs.string("appearance", "system")) }.getOrDefault(Appearance.system)
            Segmented(Appearance.entries, appearance, { it.label }, Modifier.padding(bottom = 10.dp)) { prefs.set("appearance", it.name) }
        }

        FormSection("Stil") {
            Labeled("Ecken") { Segmented(ThemeCorners.entries, ThemeSetting.corners, { it.label }) { prefs.set(ThemeSetting.cornersKey, it.id) } }
            Divider()
            Labeled("Karten") { Segmented(ThemeCards.entries, ThemeSetting.cards, { it.label }) { prefs.set(ThemeSetting.cardsKey, it.id) } }
            Divider()
            Labeled("Hintergrund") { Segmented(ThemeBackground.entries, ThemeSetting.background, { if (it == ThemeBackground.black) (if (isDark) "Schwarz" else "Weiß") else it.label }) { prefs.set(ThemeSetting.backgroundKey, it.id) } }
            Divider()
            Labeled("Schrift") { Segmented(ThemeFont.entries, ThemeSetting.font, { it.label }) { prefs.set(ThemeSetting.fontKey, it.id) } }
            Divider()
            Text("Auf Standard zurücksetzen", style = font(16), color = Palette.accentText,
                modifier = Modifier.fillMaxWidth().clickable {
                    h.tap()
                    for (k in listOf(ThemeSetting.accentKey, ThemeSetting.cornersKey, ThemeSetting.cardsKey, ThemeSetting.backgroundKey, ThemeSetting.fontKey, ThemeSetting.customKey)) prefs.set(k, "")
                }.padding(vertical = 12.dp))
        }

        FormSection("Verhalten", "Die Startseite gilt beim nächsten Öffnen der App.") {
            Labeled("Startseite") {
                Segmented(listOf(0, 1), prefs.int("startTab", 0), { if (it == 0) "Heute" else "Verlauf" }) { prefs.set("startTab", it) }
            }
            Divider()
            FormToggle("Haptisches Feedback", prefs.bool("haptics", true), { prefs.set("haptics", it) })
        }
    }
}

@Composable
private fun Labeled(title: String, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = font(14, FontWeight.SemiBold), color = C.textSecondary)
        content()
    }
}

/** A small Today screen built from the real card styles, so every choice is visible right here. */
@Composable
private fun ThemePreview() {
    val name = App.prefs.string("profile.name", "")
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius + 6.dp)).background(C.background)
        .border(1.dp, C.textSecondary.copy(alpha = 0.25f), RoundedCornerShape(Radius + 6.dp)).padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.fillMaxWidth().card(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(84.dp), contentAlignment = Alignment.Center) {
                    CalorieRing(0.72, 10.dp, Modifier.fillMaxSize())
                    CatMascot(CatMood.happy, 2.4.dp)
                }
                Spacer(Modifier.width(16.dp))
                Column {
                    Text(if (name.isEmpty()) "Heute" else "Hallo, $name", style = font(14), color = C.textSecondary)
                    Text("601", style = font(38, FontWeight.ExtraBold), color = C.textPrimary)
                    Text("kcal übrig", style = font(12), color = C.textSecondary)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.clip(CircleShape).background(C.accentSoft).padding(horizontal = 10.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.LocalFireDepartment, null, Modifier.size(13.dp), tint = Palette.accentText)
                    Spacer(Modifier.width(4.dp))
                    Text("12", style = font(12, FontWeight.Bold), color = Palette.accentText)
                }
                Spacer(Modifier.weight(1f))
                Text("Suchen", style = font(14, FontWeight.Bold), color = Color.White,
                    modifier = Modifier.clip(CircleShape).background(Palette.accent).padding(horizontal = 18.dp, vertical = 8.dp))
            }
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(RadiusSmall + 4.dp)).background(C.card).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Skyr mit Beeren", style = font(16, FontWeight.Bold), color = C.textPrimary)
                Text("250 g · 12:40", style = font(13), color = C.textSecondary)
            }
            Text("210", style = font(18, FontWeight.Bold), color = C.textPrimary)
        }
    }
}

/** A colour wheel: hue around, saturation outwards, brightness below. */
@Composable
private fun ColorWheelDialog(initial: Color, onDismiss: () -> Unit, onPick: (Color) -> Unit) {
    val hsv = remember { FloatArray(3).also { android.graphics.Color.colorToHSV(initial.toArgb(), it) } }
    var hue by remember { mutableFloatStateOf(hsv[0]) }
    var sat by remember { mutableFloatStateOf(hsv[1]) }
    var value by remember { mutableFloatStateOf(maxOf(hsv[2], 0.35f)) }
    val color = Color.hsv(hue, sat, value)
    androidx.compose.material3.AlertDialog(onDismissRequest = onDismiss,
        title = { Text("Eigene Farbe") },
        text = {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.size(240.dp).pointerInput(Unit) {
                    fun update(p: androidx.compose.ui.geometry.Offset) {
                        val c = androidx.compose.ui.geometry.Offset(size.width / 2f, size.height / 2f)
                        val d = p - c
                        val r = size.width / 2f
                        sat = (kotlin.math.hypot(d.x, d.y) / r).coerceIn(0f, 1f)
                        hue = ((Math.toDegrees(kotlin.math.atan2(d.y, d.x).toDouble()).toFloat() + 360f) % 360f)
                    }
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        update(down.position)
                        do {
                            val event = awaitPointerEvent()
                            event.changes.firstOrNull()?.let { update(it.position); it.consume() }
                        } while (event.changes.any { it.pressed })
                    }
                }) {
                    Canvas(Modifier.fillMaxSize()) {
                        val hues = (0..360 step 30).map { Color.hsv(it.toFloat(), 1f, value) }
                        drawCircle(Brush.sweepGradient(hues))
                        drawCircle(Brush.radialGradient(listOf(Color.hsv(0f, 0f, value), Color.Transparent)))
                        // Marker
                        val r = size.minDimension / 2f
                        val ang = Math.toRadians(hue.toDouble())
                        val m = androidx.compose.ui.geometry.Offset(center.x + (kotlin.math.cos(ang) * sat * r).toFloat(), center.y + (kotlin.math.sin(ang) * sat * r).toFloat())
                        drawCircle(Color.White, 11.dp.toPx(), m, style = androidx.compose.ui.graphics.drawscope.Stroke(3.dp.toPx()))
                        drawCircle(color, 8.dp.toPx(), m)
                    }
                }
                androidx.compose.material3.Slider(value, { value = it }, valueRange = 0.25f..1f)
                Box(Modifier.fillMaxWidth().height(36.dp).clip(RoundedCornerShape(10.dp)).background(color))
            }
        },
        confirmButton = { androidx.compose.material3.TextButton({ onPick(color) }) { Text("Übernehmen") } },
        dismissButton = { androidx.compose.material3.TextButton(onDismiss) { Text("Abbrechen") } })
}
