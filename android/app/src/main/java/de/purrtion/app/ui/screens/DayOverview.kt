package de.purrtion.app.ui.screens

import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material.icons.rounded.WineBar
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import de.purrtion.app.App
import de.purrtion.app.data.FoodEntry
import de.purrtion.app.data.Store
import de.purrtion.app.domain.ActivityStore
import de.purrtion.app.domain.BloodAlcohol
import de.purrtion.app.domain.DayTarget
import de.purrtion.app.domain.GoalStatus
import de.purrtion.app.domain.HealthScore
import de.purrtion.app.domain.promilleString
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.format
import de.purrtion.app.model.fullTitle
import de.purrtion.app.model.kcalString
import de.purrtion.app.model.weekdayName
import de.purrtion.app.model.weekdayNarrow
import de.purrtion.app.ui.Bar
import de.purrtion.app.ui.CalorieRing
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.ScoreRing
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.card
import de.purrtion.app.ui.goalColor
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.pixel.CatPalette
import de.purrtion.app.ui.pixel.PixelSpriteView
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Larger view behind the summary card: goal make-up, alcohol, activity (incl. manual), macros, score, share. */
@Composable
fun DayOverviewSheet(day: LocalDate) {
    val goals = App.goals
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val entries by remember { App.db.entries().observeDay(day.toEpochDay()) }.collectAsState(emptyList())
    val water by remember { App.db.water().observeDay(day.toEpochDay()) }.collectAsState(emptyList())
    val review by remember { App.db.reviews().observeDay(day.toEpochDay()) }.collectAsState(null)
    var manual by remember { mutableStateOf(ActivityStore.manual(day)) }
    val total = Nutrients.sum(entries.map { it.nutrients })
    val target = goals.target(day)
    val waterML = water.sumOf { it.ml }
    val score = if (goals.healthScoreEnabled && entries.isNotEmpty()) HealthScore.of(entries, target.kcal, target.protein) else null

    Screen(day.fullTitle(), leading = "Fertig") {
        // Goal breakdown
        val remaining = target.kcal - total.kcal
        Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(112.dp), contentAlignment = Alignment.Center) {
                CalorieRing(total.kcal / max(target.kcal, 1.0), 11.dp, Modifier.fillMaxSize())
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(abs(remaining).kcalString, style = font(24, FontWeight.ExtraBold), color = if (remaining >= 0) C.textPrimary else Palette.danger)
                    Text(if (remaining >= 0) "übrig" else "drüber", style = font(12, FontWeight.Medium), color = C.textSecondary)
                }
            }
            Spacer(Modifier.width(16.dp))
            Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Line("Grundziel", target.baseKcal, note = if (goals.weekdayEnabled) day.weekdayName() else null)
                if (target.activityBonus > 0) Line("Aktivität", target.activityBonus, "+", Palette.accent)
                Box(Modifier.fillMaxWidth().height(0.5.dp).background(C.line))
                Line("Tagesziel", target.kcal, bold = true)
                Line("Gegessen", total.kcal, "−")
            }
        }
        AlcoholCard(day)
        // Activity
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.LocalFireDepartment, null, tint = Palette.accent)
                Spacer(Modifier.width(6.dp))
                Text("Aktivität", style = font(17, FontWeight.Bold), color = C.textPrimary, modifier = Modifier.weight(1f))
                Text("${(target.healthKcal + manual).kcalString} kcal", style = font(17, FontWeight.ExtraBold), color = Palette.accent)
            }
            if (goals.activityEnabled) Row {
                Text("Health Connect", style = font(14), color = C.textSecondary, modifier = Modifier.weight(1f))
                Text("${target.healthKcal.kcalString} kcal · ${target.activityPercent.toInt()} % angerechnet", style = font(13, FontWeight.Medium), color = C.textSecondary)
            }
            Row {
                Text("Selbst eingetragen", style = font(14), color = C.textSecondary, modifier = Modifier.weight(1f))
                Text("${manual.kcalString} kcal", style = font(15, FontWeight.Bold), color = C.textPrimary)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                fun change(d: Double) {
                    h.tap()
                    manual = max(0.0, min(5000.0, manual + d))
                    ActivityStore.setManual(manual, day)
                    Store.changed(day)
                }
                for (step in listOf(50.0, 100.0, 250.0, 500.0)) {
                    Box(Modifier.weight(1f).height(36.dp).clip(CircleShape).background(C.accentSoft).squishClick { change(step) }, contentAlignment = Alignment.Center) {
                        Text("+${step.toInt()}", style = font(14, FontWeight.Bold), color = Palette.accent)
                    }
                }
                Box(Modifier.width(44.dp).height(36.dp).clip(CircleShape).background(C.cardAlt).squishClick(manual > 0) { change(-manual) }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Refresh, "Zurücksetzen", Modifier.size(16.dp), tint = C.textSecondary)
                }
            }
            Text(if (goals.activityEnabled) "Selbst eingetragene Aktivität (z. B. Training ohne Uhr) wird wie Health Connect zu ${target.activityPercent.toInt()} % aufs Ziel angerechnet."
                else "Selbst eingetragene Aktivität wird voll aufs Ziel angerechnet. Health Connect kannst du unter Einstellungen → Kalorien & Makros verbinden.",
                style = font(12), color = C.textSecondary)
        }
        // Macros
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            MacroLine("Protein", total.protein, target.protein, Palette.protein)
            MacroLine("Kohlenhydrate", total.carbs, target.carbs, Palette.carbs)
            MacroLine("Fett", total.fat, target.fat, Palette.fat)
            if (goals.waterEnabled) MacroLine("Wasser", waterML / 1000.0, goals.waterML / 1000.0, Palette.water, "l")
        }
        if (score != null) {
            Row(Modifier.fillMaxWidth().card(14.dp), verticalAlignment = Alignment.CenterVertically) {
                ScoreRing(score.score / 100.0, scoreColor(score), 6.dp, Modifier.size(50.dp)) {
                    Text("${score.score}", style = font(17, FontWeight.ExtraBold), color = C.textPrimary)
                }
                Spacer(Modifier.width(14.dp))
                Column {
                    Text("Health Score · ${score.rating}", style = font(15, FontWeight.Bold), color = C.textPrimary)
                    review?.let { Text("Tagesfazit: ${it.rating}", style = font(13), color = reviewColor(it)) }
                }
            }
        }
        // Suggestions
        Row(Modifier.fillMaxWidth().card(14.dp).squishClick { Nav.push { SuggestionsList(day, back = true) } }, verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(40.dp).clip(CircleShape).background(C.accentSoft), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.AutoAwesome, null, tint = Palette.accent)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text("Was passt noch?", style = font(15, FontWeight.Bold), color = C.textPrimary)
                Text("Favoriten & Rezepte für die restlichen ${max(0.0, target.kcal - total.kcal).kcalString} kcal", style = font(12), color = C.textSecondary, maxLines = 1)
            }
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = C.textSecondary)
        }
        ShareCard(day, entries, total, target, score, review?.rating, review?.points ?: emptyList(), waterML)
    }
}

@Composable
private fun Line(title: String, value: Double, sign: String = "", color: Color = C.textPrimary, bold: Boolean = false, note: String? = null) {
    Row(verticalAlignment = Alignment.Bottom) {
        Text(title, style = font(14, if (bold) FontWeight.Bold else FontWeight.Normal), color = C.textSecondary)
        if (note != null) { Spacer(Modifier.width(4.dp)); Text(note, style = font(11), color = C.textSecondary.copy(alpha = 0.7f)) }
        Spacer(Modifier.weight(1f))
        Text("$sign${value.kcalString} kcal", style = font(15, if (bold) FontWeight.ExtraBold else FontWeight.SemiBold), color = color)
    }
}

@Composable
private fun MacroLine(name: String, value: Double, goal: Double, color: Color, unit: String = "g") {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Row {
            Text(name, style = font(14, FontWeight.SemiBold), color = C.textPrimary, modifier = Modifier.weight(1f))
            Text("${value.format(1)} / ${goal.format(1)} $unit", style = font(13, FontWeight.Medium), color = C.textSecondary)
        }
        Bar(value / max(goal, 0.01), color, height = 8.dp, minWidth = 6.dp)
    }
}

// MARK: Alcohol

/** Blood alcohol estimate of a day (for today also the drinks of the night before). */
@Composable
fun AlcoholCard(day: LocalDate) {
    val goals = App.goals
    val entries by remember { App.db.entries().observeRange(day.minusDays(1).toEpochDay(), day.toEpochDay()) }.collectAsState(emptyList())
    val weights by remember { App.db.weights().observeAll() }.collectAsState(emptyList())
    var editing by remember { mutableStateOf(false) }
    val isToday = day == LocalDate.now()
    val relevant = if (isToday) entries else entries.filter { it.day == day.toEpochDay() }
    val m = BloodAlcohol.make(relevant, goals, weights.lastOrNull()?.kg)
    val now = System.currentTimeMillis()
    val current = if (isToday) m.value(now) else 0.0
    val own = m.drinks.filter { d -> entries.firstOrNull { it.id == d.id }?.day == day.toEpochDay() }
    if (own.isEmpty() && current <= 0) return
    fun color(v: Double) = if (v >= 0.5) Palette.danger else if (v >= 0.3) Palette.carbs else null
    val timeFmt = DateTimeFormatter.ofPattern("HH:mm")
    fun hm(t: Long) = Instant.ofEpochMilli(t).atZone(ZoneId.systemDefault()).format(timeFmt)
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.WineBar, null, tint = C.textPrimary)
            Spacer(Modifier.width(6.dp))
            Text("Promille", style = font(17, FontWeight.Bold), color = C.textPrimary, modifier = Modifier.weight(1f))
            if (isToday) Text(current.promilleString, style = font(17, FontWeight.ExtraBold), color = color(current) ?: C.textPrimary)
            else m.peak?.let { Text("max. ${it.promille.promilleString}", style = font(15, FontWeight.Bold), color = color(it.promille) ?: C.textPrimary) }
        }
        AlcoholChart(m, isToday, now)
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            m.peak?.let { Stat(it.promille.promilleString, "Höchstwert · ${hm(it.time)}") }
            if (isToday && current > 0) {
                m.timeBelow(0.5, now)?.let { Stat("ab ${hm(it)}", "unter 0,5 ‰") }
                m.timeBelow(0.01, now)?.let { Stat("ab ${hm(it)}", "nüchtern") }
            }
            Stat("${Math.round(m.totalGrams)} g", "Alkohol · ${m.drinks.size} ${if (m.drinks.size == 1) "Getränk" else "Getränke"}")
        }
        val rot by animateFloatAsState(if (editing) 180f else 0f, label = "drinks")
        Row(Modifier.clickable { editing = !editing }, verticalAlignment = Alignment.CenterVertically) {
            Text("Getränke & Uhrzeiten", style = font(14, FontWeight.SemiBold), color = Palette.accent, modifier = Modifier.weight(1f))
            Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.rotate(rot), tint = Palette.accent)
        }
        AnimatedVisibility(editing) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (d in m.drinks) entries.firstOrNull { it.id == d.id }?.let { DrinkTimeRow(it, d.grams, d.time) }
            }
        }
        Text("Schätzung nach Körperwasser (Watson) aus Geschlecht, Alter, Größe und Gewicht, Abbau 0,1 ‰ pro Stunde wie bei üblichen Promillerechnern. Tatsächliche Werte schwanken stark. Nicht geeignet, um die Fahrtüchtigkeit zu beurteilen.",
            style = font(11), color = C.textSecondary)
    }
}

@Composable
private fun RowScope.Stat(value: String, label: String) {
    Column(Modifier.weight(1f, fill = false)) {
        Text(value, style = font(15, FontWeight.Bold), color = C.textPrimary, maxLines = 1)
        Text(label, style = font(11), color = C.textSecondary, maxLines = 2)
    }
}

@Composable
private fun AlcoholChart(m: BloodAlcohol, isToday: Boolean, now: Long) {
    val pts = m.points
    if (pts.size < 2) return
    val first = pts.first().time
    val last = pts.last().time
    val maxY = max(0.6, (m.peak?.promille ?: 0.0) * 1.15)
    val line = Palette.accent
    val danger = Palette.danger
    val grid = C.line
    val label = C.textSecondary
    Column {
        Canvas(Modifier.fillMaxWidth().height(120.dp)) {
            fun x(t: Long) = ((t - first).toFloat() / (last - first)) * size.width
            fun y(v: Double) = size.height - (v / maxY).toFloat() * size.height
            drawLine(grid, Offset(0f, y(0.0)), Offset(size.width, y(0.0)))
            drawLine(danger.copy(alpha = 0.5f), Offset(0f, y(0.5)), Offset(size.width, y(0.5)), 2f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(12f, 9f)))
            val area = Path().apply {
                moveTo(x(pts[0].time), y(0.0))
                for (p in pts) lineTo(x(p.time), y(p.promille))
                lineTo(x(pts.last().time), y(0.0)); close()
            }
            drawPath(area, Brush.verticalGradient(listOf(line.copy(alpha = 0.45f), line.copy(alpha = 0.05f))))
            val path = Path().apply { pts.forEachIndexed { i, p -> if (i == 0) moveTo(x(p.time), y(p.promille)) else lineTo(x(p.time), y(p.promille)) } }
            drawPath(path, line, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round))
            if (isToday && now in first..last) {
                drawLine(label.copy(alpha = 0.6f), Offset(x(now), 0f), Offset(x(now), size.height))
                drawCircle(line, 5.dp.toPx(), Offset(x(now), y(m.value(now))))
            }
            for (d in m.drinks) drawCircle(label, 3.dp.toPx(), Offset(x(d.time), size.height - 3.dp.toPx()))
        }
        Row(Modifier.fillMaxWidth()) {
            val fmt = DateTimeFormatter.ofPattern("HH 'Uhr'")
            Text(Instant.ofEpochMilli(first).atZone(ZoneId.systemDefault()).format(fmt), style = font(11), color = label, modifier = Modifier.weight(1f))
            Text(Instant.ofEpochMilli(last).atZone(ZoneId.systemDefault()).format(fmt), style = font(11), color = label)
        }
    }
}

/** One drink with an editable clock time (the time matters for the curve). */
@Composable
private fun DrinkTimeRow(entry: FoodEntry, grams: Double, time: Long) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val t = Instant.ofEpochMilli(time).atZone(ZoneId.systemDefault()).toLocalTime()
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(C.cardAlt).padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(entry.name, style = font(14, FontWeight.SemiBold), color = C.textPrimary, maxLines = 1)
            Text("${Math.round(grams)} g Alkohol", style = font(11), color = C.textSecondary)
        }
        Text("%02d:%02d".format(t.hour, t.minute), style = font(15, FontWeight.SemiBold), color = Palette.accent,
            modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(C.card).clickable {
                android.app.TimePickerDialog(context, { _, hh, mm ->
                    scope.launch { Store.update(entry.copy(createdAt = combine(entry.date, java.time.LocalTime.of(hh, mm)))) }
                }, t.hour, t.minute, true).show()
            }.padding(horizontal = 12.dp, vertical = 6.dp))
    }
}

// MARK: Share

private enum class ShareStyle(val title: String) { ring("Kalorien"), macros("Makros"), score("Health Score"), week("Woche"), story("Story") }

private data class ShareData(
    val day: LocalDate, val total: Nutrients, val target: DayTarget, val score: HealthScore?, val rating: String?, val points: List<String>,
    val waterL: Double?, val topFoods: List<Pair<String, Double>>, val week: List<Triple<LocalDate, Double, Double>>, val streak: Int, val palette: CatPalette,
) {
    val progress: Double get() = total.kcal / max(target.kcal, 1.0)
    val mood: CatMood get() = when {
        progress > 1.15 -> CatMood.stuffed; progress > 1.05 -> CatMood.full; progress >= 0.95 -> CatMood.content
        progress >= 0.85 -> CatMood.happy; else -> CatMood.idle
    }
}

@Composable
private fun ShareCard(day: LocalDate, entries: List<FoodEntry>, total: Nutrients, target: DayTarget, score: HealthScore?, rating: String?, points: List<String>, waterML: Int) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val goals = App.goals
    var week by remember { mutableStateOf(emptyList<Triple<LocalDate, Double, Double>>()) }
    var streak by remember { mutableStateOf(0) }
    LaunchedEffect(day, entries.size) {
        val start = day.minusDays(6)
        val list = App.db.entries().range(start.toEpochDay(), day.toEpochDay()).groupBy { it.day }
        week = (0..6).map { i -> val d = start.plusDays(i.toLong()); Triple(d, list[d.toEpochDay()]?.sumOf { it.kcal } ?: 0.0, goals.target(d).kcal) }
        val logged = App.db.entries().loggedDays(day.minusDays(1000).toEpochDay()).toSet()
        var d = day; var n = 0
        while (d.toEpochDay() in logged && n < 1000) { n++; d = d.minusDays(1) }
        streak = n
    }
    val top = entries.groupBy { it.name }.map { it.key to it.value.sumOf { e -> e.kcal } }.sortedByDescending { it.second }.take(4)
    val data = ShareData(day, total, target, score, rating, points, if (goals.waterEnabled) waterML / 1000.0 else null, top, week, streak,
        CatPalette.byId(App.prefs.string("catPalette", "ginger")))
    val pager = rememberPagerState { ShareStyle.entries.size }
    val layers = ShareStyle.entries.map { rememberGraphicsLayer() }
    Column(Modifier.fillMaxWidth().card(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row {
            Text("Teilen", style = font(17, FontWeight.Bold), color = C.textPrimary, modifier = Modifier.weight(1f))
            Text(ShareStyle.entries[pager.currentPage].title, style = font(13, FontWeight.SemiBold), color = Palette.accent)
        }
        HorizontalPager(pager, Modifier.fillMaxWidth().height(460.dp)) { page ->
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                // Rendered at full size (360 dp wide), shown scaled down; the graphics layer is what gets shared.
                Box(Modifier.graphicsLayer { scaleX = 0.7f; scaleY = 0.7f }.wrapContentSize(unbounded = true)) {
                    Box(Modifier.shadow(10.dp, RoundedCornerShape(22.dp)).clip(RoundedCornerShape(22.dp)).drawWithContent {
                        layers[page].record { this@drawWithContent.drawContent() }
                        drawLayer(layers[page])
                    }) { ShareDesign(ShareStyle.entries[page], data) }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            repeat(ShareStyle.entries.size) { i -> Box(Modifier.size(7.dp).clip(CircleShape).background(if (i == pager.currentPage) C.textPrimary else C.textSecondary.copy(alpha = 0.4f))) }
        }
        PillButton("Teilen", icon = Icons.Rounded.Share) {
            scope.launch {
                val bitmap = layers[pager.currentPage].toImageBitmap().asAndroidBitmap()
                val file = withContext(Dispatchers.IO) {
                    File(context.cacheDir, "purrtion-tag.png").apply { outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) } }
                }
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
                val send = Intent(Intent.ACTION_SEND).apply { type = "image/png"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                context.startActivity(Intent.createChooser(send, "Mein Tag mit Purrtion"))
            }
        }
    }
}

private val shareBg = Color(0xFF17151B)
private val shareCard = Color(0xFF24212A)
private val shareText = Color(0xFFF6F0EA)
private val shareMuted = Color(0xFF9E96A6)

/** Fixed-size images for WhatsApp, Instagram & co. Always in the dark look. */
@Composable
private fun ShareDesign(style: ShareStyle, d: ShareData) {
    val end = when (style) {
        ShareStyle.ring, ShareStyle.story -> Color(0xFF2A1E1A)
        ShareStyle.macros -> Color(0xFF1E1A2A)
        ShareStyle.score -> Color(0xFF182A1E)
        ShareStyle.week -> Color(0xFF1A222A)
    }
    Column(Modifier.requiredSize(360.dp, 640.dp).background(Brush.verticalGradient(listOf(shareBg, end))).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("PURRTION", style = font(15, FontWeight.Black).copy(letterSpacing = androidx.compose.ui.unit.TextUnit(2f, androidx.compose.ui.unit.TextUnitType.Sp)), color = Palette.accent)
                Text(d.day.fullTitle(), style = font(13, FontWeight.Medium), color = shareMuted)
            }
            if (d.streak > 1) Text("🔥 ${d.streak} Tage", style = font(13, FontWeight.Bold), color = Palette.accent,
                modifier = Modifier.clip(CircleShape).background(Palette.accent.copy(alpha = 0.15f)).padding(horizontal = 10.dp, vertical = 5.dp))
        }
        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)) {
            when (style) {
                ShareStyle.ring -> RingBody(d)
                ShareStyle.macros -> MacrosBody(d)
                ShareStyle.score -> ScoreBody(d)
                ShareStyle.week -> WeekBody(d)
                ShareStyle.story -> StoryBody(d)
            }
        }
        Text("getrackt mit Purrtion 🐾", style = font(11, FontWeight.SemiBold), color = shareMuted)
    }
}

@Composable
private fun ShareRing(d: ShareData, size: Int) {
    Box(Modifier.size(size.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val w = this.size.width * 0.075f
            drawArc(Palette.accent.copy(alpha = 0.18f), 0f, 360f, false, Offset(w / 2, w / 2), Size(this.size.width - w, this.size.height - w), style = Stroke(w))
            drawArc(if (d.progress > 1.08) Palette.danger else Palette.accent, -90f, 360f * min(d.progress, 1.0).toFloat(), false,
                Offset(w / 2, w / 2), Size(this.size.width - w, this.size.height - w), style = Stroke(w, cap = StrokeCap.Round))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            PixelSpriteView(d.mood.frames.first(), (size / 48f).dp, d.palette)
            Text(d.total.kcal.kcalString, style = font((size * 0.16f).toInt(), FontWeight.ExtraBold), color = shareText)
            Text("von ${d.target.kcal.kcalString} kcal", style = font(13, FontWeight.SemiBold), color = shareMuted)
        }
    }
}

@Composable
private fun Tile(value: String, label: String, color: Color, modifier: Modifier) {
    Column(modifier.clip(RoundedCornerShape(14.dp)).background(shareCard).padding(vertical = 10.dp, horizontal = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = font(19, FontWeight.ExtraBold), color = color, maxLines = 1)
        Text(label, style = font(11, FontWeight.Medium), color = shareMuted, textAlign = TextAlign.Center, maxLines = 2)
    }
}

@Composable
private fun ColumnScope.RingBody(d: ShareData) {
    ShareRing(d, 210)
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        for ((name, v, goal, color) in listOf(Quad("Protein", d.total.protein, d.target.protein, Palette.protein),
            Quad("Kohlenh.", d.total.carbs, d.target.carbs, Palette.carbs), Quad("Fett", d.total.fat, d.target.fat, Palette.fat))) {
            Column(Modifier.weight(1f).clip(RoundedCornerShape(14.dp)).background(shareCard).padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(name, style = font(11, FontWeight.SemiBold), color = shareMuted)
                Bar(v / max(goal, 1.0), color, height = 6.dp, track = color.copy(alpha = 0.2f))
                Text("${Math.round(v)} g", style = font(15, FontWeight.Bold), color = shareText)
            }
        }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        d.score?.let { Tile("${it.score}", "Health Score", Palette.fiber, Modifier.weight(1f)) }
        if (d.target.activeKcal > 0) Tile("🔥 ${d.target.activeKcal.kcalString}", if (d.target.activityPercent > 0) "aktiv · ${d.target.activityPercent.toInt()} % aufs Ziel" else "aktiv kcal", Palette.accent, Modifier.weight(1f))
        d.waterL?.takeIf { it > 0 }?.let { Tile("${it.format(1)} l", "Wasser", Palette.water, Modifier.weight(1f)) }
    }
    d.rating?.let { Text("„$it“", style = font(18, FontWeight.Bold), color = shareText) }
}

private data class Quad(val a: String, val b: Double, val c: Double, val d: Color)

@Composable
private fun ColumnScope.MacrosBody(d: ShareData) {
    val p = d.total.protein * 4; val c = d.total.carbs * 4; val f = d.total.fat * 9
    val sum = max(p + c + f, 1.0)
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(150.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize()) {
                val w = 18.dp.toPx()
                var startA = -90f
                for ((share, color) in listOf(p / sum to Palette.protein, c / sum to Palette.carbs, f / sum to Palette.fat)) {
                    val sweep = (share * 360).toFloat()
                    if (sweep > 3) drawArc(color, startA + 1.5f, sweep - 3f, false, Offset(w / 2, w / 2), Size(size.width - w, size.height - w), style = Stroke(w))
                    startA += sweep
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(d.total.kcal.kcalString, style = font(26, FontWeight.ExtraBold), color = shareText)
                Text("kcal", style = font(12, FontWeight.SemiBold), color = shareMuted)
            }
        }
        Spacer(Modifier.width(18.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            for ((name, g, share, color) in listOf(Quad("Protein", d.total.protein, p / sum, Palette.protein), Quad("Kohlenhydrate", d.total.carbs, c / sum, Palette.carbs),
                Quad("Fett", d.total.fat, f / sum, Palette.fat))) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(10.dp).clip(RoundedCornerShape(3.dp)).background(color))
                    Spacer(Modifier.width(8.dp))
                    Column {
                        Text(name, style = font(12, FontWeight.Medium), color = shareMuted)
                        Text("${Math.round(g)} g · ${Math.round(share * 100)} %", style = font(16, FontWeight.Bold), color = shareText)
                    }
                }
            }
        }
    }
    if (d.topFoods.isNotEmpty()) Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(shareCard).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Heute auf dem Teller", style = font(13, FontWeight.Bold), color = shareMuted)
        for ((name, kcal) in d.topFoods) Row {
            Text(name, style = font(15, FontWeight.SemiBold), color = shareText, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            Text("${kcal.kcalString} kcal", style = font(14, FontWeight.Medium), color = shareMuted)
        }
    }
}

@Composable
private fun ColumnScope.ScoreBody(d: ShareData) {
    val s = d.score
    if (s == null) { ShareRing(d, 200); Text("Health Score ist ausgeschaltet", style = font(13), color = shareMuted); return }
    val color = scoreColor(s)
    ScoreRing(s.score / 100.0, color, 14.dp, Modifier.size(170.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("${s.score}", style = font(54, FontWeight.ExtraBold), color = shareText)
            Text(s.rating, style = font(15, FontWeight.Bold), color = color)
        }
    }
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(shareCard).padding(14.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
        for (c in s.components) Row(verticalAlignment = Alignment.CenterVertically) {
            Text(c.title, style = font(12, FontWeight.SemiBold), color = shareText, maxLines = 1, modifier = Modifier.width(128.dp))
            Bar(c.ratio, color, Modifier.weight(1f), height = 7.dp, track = color.copy(alpha = 0.18f))
        }
    }
    d.rating?.let { Text("„$it“", style = font(17, FontWeight.Bold), color = shareText) }
}

@Composable
private fun ColumnScope.WeekBody(d: ShareData) {
    val maxV = max(d.week.maxOfOrNull { max(it.second, it.third) } ?: 1.0, 1.0)
    val within = d.week.count { it.second > 0 && it.second <= it.third }
    val logged = d.week.count { it.second > 0 }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text("$within von $logged", style = font(40, FontWeight.ExtraBold), color = shareText)
        Text("Tagen im Ziel", style = font(14, FontWeight.SemiBold), color = shareMuted)
    }
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(shareCard.copy(alpha = 0.5f)).padding(14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Bottom) {
        for ((day, kcal, goal) in d.week) {
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.fillMaxWidth().height(170.dp).clip(RoundedCornerShape(7.dp)).background(shareCard), contentAlignment = Alignment.BottomCenter) {
                    if (kcal > 0) Box(Modifier.fillMaxWidth().height(max(8.0, 170 * kcal / maxV).dp).clip(RoundedCornerShape(7.dp)).background(goalColor(GoalStatus.of(kcal, goal))))
                }
                Text(day.weekdayNarrow(), style = font(12, FontWeight.Bold), color = if (day == d.day) Palette.accent else shareMuted)
            }
        }
    }
    val avg = if (logged == 0) 0.0 else d.week.sumOf { it.second } / logged
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Tile(avg.kcalString, "Ø kcal pro Tag", Palette.accent, Modifier.weight(1f))
        if (d.streak > 1) Tile("${d.streak}", "Tage in Folge", Palette.fiber, Modifier.weight(1f))
    }
}

@Composable
private fun ColumnScope.StoryBody(d: ShareData) {
    PixelSpriteView(d.mood.frames.first(), 9.dp, d.palette)
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(d.total.kcal.kcalString, style = font(64, FontWeight.ExtraBold), color = shareText)
        Text("von ${d.target.kcal.kcalString} kcal", style = font(17, FontWeight.SemiBold), color = shareMuted)
    }
    Bar(d.progress, if (d.progress > 1.08) Palette.danger else Palette.accent, Modifier.padding(horizontal = 20.dp), height = 12.dp, track = Palette.accent.copy(alpha = 0.18f))
    d.rating?.let { Text("„$it“", style = font(24, FontWeight.ExtraBold), color = Palette.accent) }
    d.points.firstOrNull()?.let { Text(it, style = font(14, FontWeight.Medium), color = shareMuted, textAlign = TextAlign.Center) }
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        d.score?.let { Tile("${it.score}", "Score", Palette.fiber, Modifier.weight(1f)) }
        Tile("${Math.round(d.total.protein)} g", "Protein", Palette.protein, Modifier.weight(1f))
        if (d.target.activeKcal > 0) Tile("🔥 ${d.target.activeKcal.kcalString}", "aktiv", Palette.accent, Modifier.weight(1f))
    }
}

