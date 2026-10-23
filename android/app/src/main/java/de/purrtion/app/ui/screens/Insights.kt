package de.purrtion.app.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Spa
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.data.DayReview
import de.purrtion.app.domain.DayCloser
import de.purrtion.app.domain.HealthScore
import de.purrtion.app.model.fullTitle
import de.purrtion.app.ui.Bar
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.ScoreRing
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.card
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.pixel.WalkingCatLoader
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.roundToInt

/** Detailed health score breakdown. */
@Composable
fun HealthScoreSheet(score: HealthScore, baseline: HealthScore?) {
    val color = scoreColor(score)
    Screen("Health Score", leading = "Fertig") {
        Column(Modifier.fillMaxWidth().card(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ScoreRing(score.score / 100.0, color, 14.dp, Modifier.size(150.dp), baseline?.let { it.score / 100.0 }) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("${score.score}", style = font(44, FontWeight.ExtraBold), color = C.textPrimary)
                    Text("von 100", style = font(12, FontWeight.Medium), color = C.textSecondary)
                }
            }
            Text(score.rating, style = font(20, FontWeight.Bold), color = color)
            if (baseline != null) AIComparison(baseline.score, score.score, color)
            if (score.isPreliminary) Text("Vorläufig: du hast erst ${(score.completeness * 100).toInt()} % deines Kalorienziels gegessen. Der Score wird im Laufe des Tages aussagekräftiger.",
                style = font(13), color = C.textSecondary, textAlign = TextAlign.Center)
        }
        val top = score.components.filter { it.tip != null }.maxByOrNull { it.maxPoints - it.points }
        if (top?.tip != null) {
            Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.Top) {
                CatMascot(CatMood.idle, 2.6.dp)
                Spacer(Modifier.width(12.dp))
                Column {
                    Text("Größter Hebel heute: ${top.title}", style = font(14, FontWeight.Bold), color = C.textPrimary)
                    Text(top.tip, style = font(13), color = C.textSecondary)
                }
            }
        }
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            for (c in score.components) ComponentRow(c, color, baseline?.components?.firstOrNull { it.id == c.id })
        }
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("So wird der Score berechnet", style = font(15, FontWeight.Bold), color = C.textPrimary)
            Text("""Acht Bereiche mit zusammen 100 Punkten, basierend auf:
• WHO „Healthy Diet“ (2020): Zucker < 10 % und gesättigte Fette < 10 % der Energie, Salz < 5 g, ≥ 400 g Obst & Gemüse
• DGE-Referenzwerte: ≥ 30 g Ballaststoffe, ausreichend Protein
• GBD 2017 Diet Collaborators (The Lancet, 2019): Salz, zu wenig Vollkorn/Ballaststoffe und Obst sind die größten ernährungsbedingten Risiken
• Reynolds et al. (The Lancet, 2019): Ballaststoffe und Herz-Kreislauf-Gesundheit
• EU-Referenzmengen (NRV) für 17 Vitamine & Mineralstoffe
• Alkohol gibt einen Abzug (WHO 2023, DGE 2024)
Der Score ersetzt keine medizinische Beratung.""", style = font(12), color = C.textSecondary)
        }
    }
}


@Composable
private fun ComponentRow(c: HealthScore.Component, color: Color, before: HealthScore.Component?) {
    var expanded by remember { mutableStateOf(false) }
    val rot by animateFloatAsState(if (expanded) 180f else 0f, label = "row")
    val delta = before?.let { c.points.roundToInt() - it.points.roundToInt() }?.takeIf { it != 0 }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(Modifier.clickable { expanded = !expanded }, verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(28.dp).clip(RoundedCornerShape(8.dp)).background(color.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                Text(c.title.take(1), style = font(13, FontWeight.Bold), color = color)
            }
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(c.title, style = font(15, FontWeight.SemiBold), color = C.textPrimary)
                Text("${c.valueText} · ${c.targetText}", style = font(12), color = C.textSecondary)
            }
            if (delta != null) { AIDeltaBadge(delta); Spacer(Modifier.width(6.dp)) }
            Text(c.pointsText, style = font(15, FontWeight.Bold), color = if (c.isPenalty) Palette.danger else C.textPrimary)
            Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(16.dp).rotate(rot), tint = C.textSecondary)
        }
        Box {
            if (before != null && before.ratio < c.ratio) {
                Bar(c.ratio, color.copy(alpha = 0.4f), track = C.track(color))
                Bar(before.ratio, color, track = Color.Transparent)
            } else Bar(c.ratio, color, track = C.track(color))
        }
        AnimatedVisibility(expanded) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                if (before != null && delta != null) Text("Ohne KI-Ergänzung: ${before.pointsText} · ${before.valueText}", style = font(12), color = C.textSecondary)
                Text(c.explanation, style = font(12), color = C.textSecondary)
                c.tip?.let {
                    Row(verticalAlignment = Alignment.Top) {
                        Icon(Icons.Rounded.Lightbulb, null, Modifier.size(14.dp), tint = Palette.accentText)
                        Spacer(Modifier.width(4.dp))
                        Text(it, style = font(12, FontWeight.Medium), color = Palette.accentText)
                    }
                }
            }
        }
    }
}

/** "Eigene Daten 82 → mit KI 87" under the big ring. */
@Composable
private fun AIComparison(before: Int, after: Int, color: Color) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(C.cardAlt).padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Stat("$before", "Eigene Daten", C.textPrimary)
            Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, Modifier.size(14.dp), tint = C.textSecondary)
            Stat("$after", "Mit KI-Ergänzung", color)
        }
        Text("Fehlende Vitamine und Mineralstoffe wurden beim Abschließen des Tages von der KI geschätzt.", style = font(12), color = C.textSecondary, textAlign = TextAlign.Center)
    }
}

@Composable
private fun Stat(value: String, label: String, color: Color) {
    Column(Modifier.widthIn(min = 90.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = font(20, FontWeight.ExtraBold), color = color)
        Text(label, style = font(11), color = C.textSecondary)
    }
}

/** Details of the AI verdict on a day, with the option to evaluate again. */
@Composable
fun DayReviewSheet(initial: DayReview) {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val live by remember { App.db.reviews().observeDay(initial.day) }.collectAsState(initial)
    val review = live ?: initial
    var running by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val color = reviewColor(review)
    val day = LocalDate.ofEpochDay(review.day)
    Screen("Tagesfazit", leading = "Fertig") {
        Column(Modifier.fillMaxWidth().card(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            CatMascot(reviewMood(review), 4.dp)
            Text(review.rating, style = font(28, FontWeight.ExtraBold), color = color, textAlign = TextAlign.Center)
            Text(day.fullTitle(), style = font(13), color = C.textSecondary)
        }
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Einordnung", style = font(17, FontWeight.Bold), color = C.textPrimary)
            for (p in review.points) Row(verticalAlignment = Alignment.Top) {
                Box(Modifier.padding(top = 7.dp).size(7.dp).clip(CircleShape).background(color))
                Spacer(Modifier.width(10.dp))
                Text(p, style = font(15), color = C.textPrimary)
            }
        }
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            review.score?.let { s ->
                val b = review.scoreBefore
                Info(Icons.Rounded.Favorite, if (b != null && b != s) "Health Score: $b → $s durch KI-ergänzte Mikronährstoffe" else "Health Score beim Abschluss: $s/100")
            }
            Info(Icons.Rounded.Spa, if (review.enrichedCount == 0) "Alle Lebensmittel hatten bereits vollständige Mikronährstoffe."
                else "${review.enrichedCount} Lebensmittel um fehlende Mikronährstoffe ergänzt (KI-Schätzung).")
            val time = Instant.ofEpochMilli(review.createdAt).atZone(ZoneId.systemDefault())
            Info(if (review.automatic) Icons.Rounded.Bedtime else Icons.Rounded.AutoAwesome,
                "${if (review.automatic) "Automatisch über Nacht bewertet" else "Bewertet"} mit ${review.providerName} · ${time.format(DateTimeFormatter.ofPattern("d. MMM, HH:mm"))} Uhr")
            Text("KI-Einschätzung, ersetzt keine Ernährungsberatung.", style = font(11), color = C.textSecondary)
        }
        if (running) Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { WalkingCatLoader(2.4.dp, 220.dp, "Bewerte neu …") }
        else PillButton("Neu bewerten", icon = Icons.Rounded.Refresh, filled = false) {
            running = true
            scope.launch {
                try { DayCloser.close(day, App.goals); h.success() } catch (e: Exception) { error = e.message }
                running = false
            }
        }
    }
    error?.let {
        AlertDialog({ error = null }, confirmButton = { TextButton({ error = null }) { Text("OK", color = Palette.accentText) } },
            title = { Text("Bewertung fehlgeschlagen") }, text = { Text(it) })
    }
}

@Composable
private fun Info(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(verticalAlignment = Alignment.Top) {
        Icon(icon, null, Modifier.size(16.dp), tint = C.textSecondary)
        Spacer(Modifier.width(8.dp))
        Text(text, style = font(13), color = C.textSecondary)
    }
}

