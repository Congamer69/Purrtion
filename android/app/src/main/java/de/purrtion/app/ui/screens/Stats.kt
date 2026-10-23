package de.purrtion.app.ui.screens

import android.graphics.Paint
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.rounded.List
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.MonitorWeight
import androidx.compose.material.icons.rounded.TrackChanges
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.data.FoodEntry
import de.purrtion.app.data.WeightLog
import de.purrtion.app.domain.ActivityStore
import de.purrtion.app.domain.Expenditure
import de.purrtion.app.domain.ExpenditureEstimate
import de.purrtion.app.domain.GoalStatus
import de.purrtion.app.domain.HealthConnect
import de.purrtion.app.domain.HealthScore
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.clean
import de.purrtion.app.model.format
import de.purrtion.app.model.fullTitle
import de.purrtion.app.model.kcalString
import de.purrtion.app.model.mondayOfWeek
import de.purrtion.app.model.shortDayMonth
import de.purrtion.app.model.weekdayName
import de.purrtion.app.model.weekdayNarrow
import de.purrtion.app.model.weekdayShort
import de.purrtion.app.ui.Bar
import de.purrtion.app.ui.GoalLegend
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.Segmented
import de.purrtion.app.ui.SliderField
import de.purrtion.app.ui.card
import de.purrtion.app.ui.goalColor
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** One day in the history with its goal and energy numbers. */
data class DayStat(
    val day: LocalDate,
    val entries: List<FoodEntry>,
    val kcal: Double, val protein: Double, val carbs: Double, val fat: Double,
    val goal: Double, val goalProtein: Double,
    /** Goal without the activity bonus (weekday goal). */
    val baseGoal: Double,
    val active: Double, val bonus: Double,
    /** Resting energy: Health Connect, otherwise estimated (Mifflin-St Jeor). */
    val basal: Double, val basalFromHealth: Boolean,
) {
    val burned: Double get() = basal + active
}

private fun stat(d: LocalDate, es: List<FoodEntry>): DayStat {
    val goals = App.goals
    val t = goals.target(d)
    val b = ActivityStore.basal(d)
    return DayStat(d, es, es.sumOf { it.kcal }, es.sumOf { it.protein }, es.sumOf { it.carbs }, es.sumOf { it.fat },
        t.kcal, t.protein, t.baseKcal, t.activeKcal, t.activityBonus, if (b > 0) b else goals.bmr, b > 0)
}

private fun signedKcal(v: Double) = (if (v > 0) "−" else "+") + abs(v).kcalString

private val zone: ZoneId get() = ZoneId.systemDefault()
private fun Long.localDateTime(): LocalDateTime = Instant.ofEpochMilli(this).atZone(zone).toLocalDateTime()
private fun Long.localDate(): LocalDate = localDateTime().toLocalDate()

@Composable
fun StatsScreen() {
    val goals = App.goals
    var range by rememberSaveable { mutableStateOf(7) }
    val today = LocalDate.now()
    // Enough history for the expenditure window (up to 8 weeks) and the 90-day range.
    val from = today.minusDays(120)
    val entries by remember { App.db.entries().observeRange(from.toEpochDay(), today.plusDays(7).toEpochDay()) }.collectAsState(emptyList())
    val weights by remember { App.db.weights().observeAll() }.collectAsState(emptyList())
    LaunchedEffect(Unit) { HealthConnect.importWeights() }

    val grouped = remember(entries) { entries.groupBy { it.day } }
    val days = remember(grouped, range) {
        val start = if (range == 7) today.mondayOfWeek() else today.minusDays((range - 1).toLong())
        (0 until range).map { i -> val d = start.plusDays(i.toLong()); stat(d, grouped[d.toEpochDay()] ?: emptyList()) }
    }
    val logged = days.filter { it.kcal > 0 }
    val expenditure = remember(grouped, weights) {
        Expenditure.estimate(grouped.entries.associate { LocalDate.ofEpochDay(it.key) to it.value.sumOf { e -> e.kcal } },
            weights.map { Expenditure.Weight(it.date.localDateTime(), it.kg) }, goals, goals.activityEnabled)
    }
    val streak = remember(grouped) {
        var d = today
        if (d.toEpochDay() !in grouped) d = d.minusDays(1)
        var n = 0
        while (d.toEpochDay() in grouped) { n++; d = d.minusDays(1) }
        n
    }

    Column(Modifier.fillMaxSize().background(C.background).statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(Modifier.fillMaxWidth().padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Verlauf", style = font(34, FontWeight.Bold), color = C.textPrimary, modifier = Modifier.weight(1f))
            de.purrtion.app.ui.RoundIconButton(androidx.compose.material.icons.Icons.Rounded.Tune, size = 40.dp, description = "Anpassen") { Nav.sheet { StatsLayoutEditor() } }
        }
        Segmented(listOf(7, 30, 90), range, { when (it) { 7 -> "Woche"; 30 -> "30 Tage"; else -> "90 Tage" } }) { range = it }
        val layout = StatsLayout.load()
        for (card in layout.visible) {
            when (card) {
                StatsCardId.kcal -> KcalCard(days, logged, range)
                StatsCardId.overview -> OverviewCard(logged, streak)
                StatsCardId.expenditure -> Box(Modifier.squishClick { Nav.sheet { ExpenditureSheet(expenditure) } }) { ExpenditureCard(expenditure) }
                StatsCardId.goal -> GoalCard(days, range)
                StatsCardId.score -> if (goals.healthScoreEnabled) ScoreCard(days, logged, range)
                StatsCardId.weight -> WeightCard(weights, range)
                StatsCardId.activity -> if (days.any { it.active > 0 }) ActivityCard(days, range)
                StatsCardId.macro -> MacroCard(logged)
                // Per-weekday averages only make sense over several weeks.
                StatsCardId.weekday -> if (range > 7) WeekdayCard(logged)
                StatsCardId.topFoods -> TopFoodsCard(logged)
                StatsCardId.micro -> MicroCard(logged)
            }
        }
        if (layout.visible.isEmpty()) {
            Text("Alle Karten sind ausgeblendet. Über „Anpassen“ holst du sie zurück.", style = font(14), color = C.textSecondary,
                modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        }
        Spacer(Modifier.navigationBarsPadding().height(88.dp))
    }
}

// MARK: Chart helpers

/** Long press and drag to inspect single values (like the iOS chart scrub). */
private fun Modifier.scrub(count: Int, onIndex: (Int?) -> Unit): Modifier = pointerInput(count) {
    fun index(x: Float) = if (count <= 0) null else (x / size.width * count).toInt().coerceIn(0, count - 1)
    detectDragGesturesAfterLongPress(
        onDragStart = { onIndex(index(it.x)) },
        onDrag = { change, _ -> onIndex(index(change.position.x)) },
        onDragEnd = { onIndex(null) },
        onDragCancel = { onIndex(null) },
    )
}

private data class ScrubItem(val label: String, val value: String, val color: Color? = null)

/** Replaces a card header while scrubbing. */
@Composable
private fun ScrubHeader(title: String, items: List<ScrubItem>) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(C.cardAlt).padding(horizontal = 12.dp, vertical = 8.dp)) {
        Text(title, style = font(12, FontWeight.SemiBold), color = C.textSecondary)
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            for (i in items) Column {
                Text(i.value, style = font(17, FontWeight.ExtraBold), color = i.color ?: C.textPrimary, maxLines = 1)
                Text(i.label, style = font(11), color = C.textSecondary, maxLines = 1)
            }
        }
    }
}

/** Header that switches to the scrub details while a value is selected. */
@Composable
private fun ChartHeader(scrubbing: Boolean, scrub: @Composable () -> Unit, normal: @Composable () -> Unit) {
    Box {
        Box(Modifier.alpha(if (scrubbing) 0f else 1f)) { normal() }
        if (scrubbing) scrub()
    }
}

private fun DrawScope.label(text: String, x: Float, y: Float, color: Color, sizePx: Float, align: Paint.Align = Paint.Align.CENTER) {
    drawContext.canvas.nativeCanvas.drawText(text, x, y, Paint().apply {
        this.color = color.toArgb(); textSize = sizePx; textAlign = align; isAntiAlias = true
        typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
    })
}

/** X-axis label for a day index: weekday letters for a week, otherwise every 7th/30th day. */
private fun axisLabel(days: List<DayStat>, i: Int, range: Int): String? = when {
    range == 7 -> days[i].day.weekdayNarrow()
    i % (if (range == 30) 7 else 30) == 0 -> "${days[i].day.dayOfMonth}.${days[i].day.monthValue}."
    else -> null
}

private const val AXIS = 18f   // dp reserved for the axis labels

// MARK: Cards

@Composable
private fun MiniStat(value: String, label: String) {
    Column {
        Text(value, style = font(16, FontWeight.Bold), color = C.textPrimary)
        Text(label, style = font(11), color = C.textSecondary)
    }
}

@Composable
private fun CardTitle(text: String, modifier: Modifier = Modifier) {
    Text(text, style = font(17, FontWeight.Bold), color = C.textPrimary, modifier = modifier)
}

@Composable
private fun OverviewCard(logged: List<DayStat>, streak: Int) {
    val within = logged.count { it.kcal <= it.goal }
    Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically) {
        CatMascot(if (streak > 0) CatMood.happy else CatMood.sleeping, 3.5.dp)
        Spacer(Modifier.width(14.dp))
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("$streak ${if (streak == 1) "Tag" else "Tage"} in Folge", style = font(19, FontWeight.Bold), color = C.textPrimary)
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                MiniStat("$within/${logged.size}", "im Ziel")
                MiniStat(if (logged.isEmpty()) "–" else "${within * 100 / logged.size} %", "Zieltreue")
                MiniStat("${logged.size}", "Tage erfasst")
            }
        }
    }
}

@Composable
private fun GoalCard(days: List<DayStat>, range: Int) {
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CardTitle("Ziel eingehalten", Modifier.weight(1f))
            Row(Modifier.clip(CircleShape).background(C.accentSoft).squishClick {
                Nav.sheet { CalendarSheet("Monatsübersicht") { picked -> Nav.sheet { DaySummarySheet(picked) } } }
            }.padding(horizontal = 10.dp, vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.CalendarMonth, null, Modifier.size(15.dp), tint = Palette.accentText)
                Spacer(Modifier.width(4.dp))
                Text("Monat", style = font(13, FontWeight.SemiBold), color = Palette.accentText)
            }
        }
        RangeGoalGrid(days, range) { Nav.sheet { DaySummarySheet(it) } }
        GoalLegend()
    }
}

/** Coloured day cells for the selected range (7 → one week row, 30/90 → weekday-aligned grid). */
@Composable
private fun RangeGoalGrid(days: List<DayStat>, range: Int, onSelect: (LocalDate) -> Unit) {
    val h = rememberHaptics()
    val today = LocalDate.now()
    if (range == 7) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (d in days) {
                val future = d.day.isAfter(today)
                Column(Modifier.weight(1f).alpha(if (future) 0.4f else 1f).squishClick(!future) { h.tap(); onSelect(d.day) },
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(d.day.weekdayShort(), style = font(11, FontWeight.SemiBold), color = C.textSecondary)
                    Box(Modifier.fillMaxWidth().height(42.dp).clip(RoundedCornerShape(11.dp)).background(goalColor(GoalStatus.of(d.kcal, d.goal)))
                        .then(if (d.day == today) Modifier.border(2.dp, C.textPrimary, RoundedCornerShape(11.dp)) else Modifier),
                        contentAlignment = Alignment.Center) {
                        Text("${d.day.dayOfMonth}", style = font(15, FontWeight.Bold), color = if (d.kcal > 0) Color.White else C.textPrimary)
                    }
                    Text(if (d.kcal > 0) d.kcal.kcalString else "–", style = font(10, FontWeight.Medium), color = C.textSecondary, maxLines = 1)
                }
            }
        }
    } else {
        val offset = (days.first().day.dayOfWeek.value - 1)
        val cells: List<DayStat?> = List(offset) { null } + days
        val size = if (range == 30) 34.dp else 18.dp
        val gap = if (range == 30) 6.dp else 3.dp
        val radius = if (range == 30) 8.dp else 4.dp
        Column(verticalArrangement = Arrangement.spacedBy(gap)) {
            Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                for (s in listOf("M", "D", "M", "D", "F", "S", "S"))
                    Text(s, style = font(10, FontWeight.SemiBold), color = C.textSecondary, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
            for (week in cells.chunked(7)) Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                for (i in 0 until 7) {
                    val d = week.getOrNull(i)
                    if (d == null) Spacer(Modifier.weight(1f).height(size))
                    else Box(Modifier.weight(1f).height(size).clip(RoundedCornerShape(radius)).background(goalColor(GoalStatus.of(d.kcal, d.goal)))
                        .then(if (d.day == today) Modifier.border(2.dp, C.textPrimary, RoundedCornerShape(radius)) else Modifier)
                        .squishClick { h.tap(); onSelect(d.day) }, contentAlignment = Alignment.Center) {
                        if (range == 30) Text("${d.day.dayOfMonth}", style = font(12, FontWeight.SemiBold), color = if (d.kcal > 0) Color.White else C.textSecondary)
                    }
                }
            }
            Row {
                Text(days.first().day.shortDayMonth(), style = font(11), color = C.textSecondary, modifier = Modifier.weight(1f))
                Text(days.last().day.shortDayMonth(), style = font(11), color = C.textSecondary)
            }
        }
    }
}

@Composable
private fun KcalCard(days: List<DayStat>, logged: List<DayStat>, range: Int) {
    var sel by remember { mutableStateOf<Int?>(null) }
    val muted = C.textSecondary
    val accent = Palette.accent
    val colors = days.map { goalColor(GoalStatus.of(it.kcal, it.goal)) }
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ChartHeader(sel != null, scrub = {
            val d = days[sel!!]
            ScrubHeader(d.day.fullTitle(), listOf(
                ScrubItem("gegessen", d.kcal.kcalString, if (d.kcal > 0) colors[sel!!] else C.textSecondary),
                ScrubItem(if (d.bonus > 0) "Ziel (+${d.bonus.kcalString} aktiv)" else "Ziel", d.goal.kcalString),
                ScrubItem(if (d.kcal <= d.goal) "übrig" else "drüber", abs(d.goal - d.kcal).kcalString, if (d.kcal <= d.goal) Palette.fiber else Palette.danger),
            ))
        }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CardTitle("Kalorien", Modifier.weight(1f))
                Text("Ø ${(if (logged.isEmpty()) 0.0 else logged.sumOf { it.kcal } / logged.size).kcalString} kcal", style = font(15, FontWeight.SemiBold), color = accent)
            }
        }
        Canvas(Modifier.fillMaxWidth().height(190.dp).scrub(days.size) { sel = it }) {
            val axis = AXIS.dp.toPx()
            val h = size.height - axis
            val maxV = max(days.maxOf { max(it.kcal, it.goal) } * 1.08, 1.0)
            val slot = size.width / days.size
            val wide = range > 30
            val goalW = slot * 0.82f
            val eatW = slot * (if (wide) 0.82f else 0.5f)
            val r = CornerRadius(if (wide) 1.dp.toPx() else 6.dp.toPx())
            fun y(v: Double) = h - (v / maxV).toFloat() * h
            days.forEachIndexed { i, d ->
                val cx = slot * i + slot / 2
                drawRoundRect(muted.copy(alpha = 0.16f), Offset(cx - goalW / 2, y(d.baseGoal)), Size(goalW, h - y(d.baseGoal)), r)
                if (d.bonus > 0) drawRoundRect(accent.copy(alpha = 0.28f), Offset(cx - goalW / 2, y(d.goal)), Size(goalW, y(d.baseGoal) - y(d.goal)), r)
            }
            days.forEachIndexed { i, d ->
                if (d.kcal <= 0) return@forEachIndexed
                val cx = slot * i + slot / 2
                drawRoundRect(colors[i].copy(alpha = if (sel == null || sel == i) 1f else 0.3f), Offset(cx - eatW / 2, y(d.kcal)), Size(eatW, h - y(d.kcal)), r)
            }
            for (i in days.indices) axisLabel(days, i, range)?.let { label(it, slot * i + slot / 2, size.height - 3.dp.toPx(), muted, 11.dp.toPx()) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Legend(muted.copy(alpha = 0.16f), 12.dp, "Tagesziel")
            if (days.any { it.bonus > 0 }) Legend(accent.copy(alpha = 0.28f), 12.dp, "+ Aktivität")
            Legend(Palette.fiber, 6.dp, "gegessen")
        }
        if (logged.isNotEmpty()) {
            val balance = logged.sumOf { it.kcal - it.goal }
            Text(if (balance <= 0) "Insgesamt ${abs(balance).kcalString} kcal unter dem Ziel (≈ ${(abs(balance) / 7700).format(1, 1)} kg Fett)."
                else "Insgesamt ${balance.kcalString} kcal über dem Ziel (≈ ${(balance / 7700).format(1, 1)} kg).", style = font(12), color = C.textSecondary)
        }
    }
}

@Composable
private fun Legend(color: Color, width: Dp, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(width, 12.dp).clip(RoundedCornerShape(2.dp)).background(color))
        Spacer(Modifier.width(4.dp))
        Text(text, style = font(11, FontWeight.Medium), color = C.textSecondary)
    }
}

@Composable
private fun ActivityCard(days: List<DayStat>, range: Int) {
    var sel by remember { mutableStateOf<Int?>(null) }
    val today = LocalDate.now()
    val past = days.filter { !it.day.isAfter(today) }
    val active = past.filter { it.active > 0 }
    val avgActive = if (active.isEmpty()) 0.0 else active.sumOf { it.active } / active.size
    val credited = past.sumOf { it.bonus }
    // Deficit only for finished days with food logged. Today isn't over yet.
    val finished = past.filter { it.day.isBefore(today) && it.kcal > 0 }
    val deficit = finished.sumOf { it.burned - it.kcal }
    val estimated = finished.any { !it.basalFromHealth }
    val accent = Palette.accent
    val muted = C.textSecondary
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ChartHeader(sel?.let { it < past.size } == true, scrub = {
            val d = past[sel!!]
            ScrubHeader(d.day.fullTitle(), listOf(
                ScrubItem("aktiv", d.active.kcalString, accent),
                ScrubItem("Verbrauch gesamt", d.burned.kcalString),
                ScrubItem(if (d.kcal == 0.0) "nichts erfasst" else if (d.burned >= d.kcal) "Defizit" else "Überschuss",
                    if (d.kcal == 0.0) "–" else signedKcal(d.burned - d.kcal),
                    if (d.kcal == 0.0) C.textSecondary else if (d.burned >= d.kcal) Palette.fiber else Palette.danger),
            ))
        }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.LocalFireDepartment, null, tint = C.textPrimary)
                Spacer(Modifier.width(6.dp))
                CardTitle("Aktivität", Modifier.weight(1f))
                Text("Ø ${avgActive.kcalString} kcal", style = font(15, FontWeight.SemiBold), color = accent)
            }
        }
        // Always the whole range on the x axis, also when only a few days have passed.
        Canvas(Modifier.fillMaxWidth().height(120.dp).scrub(days.size) { sel = it }) {
            val axis = AXIS.dp.toPx()
            val h = size.height - axis
            val maxV = max(past.maxOfOrNull { it.active } ?: 0.0, 1.0) * 1.1
            val slot = size.width / days.size
            val r = CornerRadius(if (range > 30) 1.dp.toPx() else 4.dp.toPx())
            fun y(v: Double) = h - (v / maxV).toFloat() * h
            past.forEachIndexed { i, d ->
                val cx = slot * i + slot / 2
                val a = if (sel == null || sel == i) 1f else 0.35f
                val w = slot * 0.82f
                if (d.active > 0) drawRoundRect(accent.copy(alpha = 0.35f * a), Offset(cx - w / 2, y(d.active)), Size(w, h - y(d.active)), r)
                // Overlay, not stacked: the credited part sits inside the activity bar.
                if (d.bonus > 0) {
                    val v = min(d.bonus, d.active)
                    drawRoundRect(accent.copy(alpha = a), Offset(cx - w * 0.3f, y(v)), Size(w * 0.6f, h - y(v)), r)
                }
            }
            for (i in days.indices) axisLabel(days, i, range)?.let { label(it, slot * i + slot / 2, size.height - 3.dp.toPx(), muted, 11.dp.toPx()) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Column {
                Text(if (finished.isEmpty()) "–" else signedKcal(deficit), style = font(16, FontWeight.Bold), color = if (deficit >= 0) Palette.fiber else Palette.danger)
                Text(if (deficit >= 0) "Kaloriendefizit" else "Überschuss", style = font(11), color = C.textSecondary)
                if (finished.isNotEmpty()) Text("≈ ${(abs(deficit) / 7700).format(1, 1)} kg Fett", style = font(11, FontWeight.SemiBold), color = C.textSecondary)
            }
            MiniStat(credited.kcalString, "aufs Ziel angerechnet")
            past.maxByOrNull { it.active }?.takeIf { it.active > 0 }?.let { MiniStat(it.active.kcalString, "aktivster Tag · ${it.day.weekdayShort()}") }
        }
        Text("Defizit = Gesamtverbrauch (Grundumsatz + Aktivität${if (estimated) ", Grundumsatz teils geschätzt" else " aus Health Connect"}) minus gegessen, für abgeschlossene Tage. Halte einen Balken gedrückt für Details.",
            style = font(11), color = C.textSecondary)
    }
}

@Composable
private fun ScoreCard(days: List<DayStat>, logged: List<DayStat>, range: Int) {
    var sel by remember { mutableStateOf<Int?>(null) }
    val points = remember(logged) { logged.map { d -> days.indexOf(d) to HealthScore.of(d.entries, d.goal, d.goalProtein).score } }
    val average = if (points.isEmpty()) 0 else points.sumOf { it.second } / points.size
    val fiber = Palette.fiber
    val muted = C.textSecondary
    // Nearest logged day to the finger.
    val selected = sel?.let { s -> points.minByOrNull { abs(it.first - s) } }
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ChartHeader(selected != null, scrub = {
            val d = days[selected!!.first]
            ScrubHeader(d.day.fullTitle(), listOf(
                ScrubItem("Health Score", "${selected.second}", fiber),
                ScrubItem("gegessen", d.kcal.kcalString),
                ScrubItem("Protein", "${d.protein.roundToInt()} g", Palette.protein),
            ))
        }) {
            Row {
                CardTitle("Health Score", Modifier.weight(1f))
                Text("Ø $average", style = font(15, FontWeight.SemiBold), color = fiber)
            }
        }
        if (points.size >= 2) {
            Canvas(Modifier.fillMaxWidth().height(140.dp).scrub(days.size) { sel = it }) {
                val axis = AXIS.dp.toPx()
                val h = size.height - axis
                val slot = size.width / days.size
                fun x(i: Int) = slot * i + slot / 2
                fun y(v: Int) = h - v / 100f * h
                for (g in listOf(0, 50, 100)) drawLine(muted.copy(alpha = 0.15f), Offset(0f, y(g)), Offset(size.width, y(g)))
                val pts = points.map { Offset(x(it.first), y(it.second)) }
                val line = smoothPath(pts)
                val area = Path().apply { addPath(line); lineTo(pts.last().x, h); lineTo(pts.first().x, h); close() }
                drawPath(area, Brush.verticalGradient(listOf(fiber.copy(alpha = 0.35f), fiber.copy(alpha = 0.02f)), 0f, h))
                drawPath(line, fiber, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round))
                selected?.let {
                    drawLine(muted.copy(alpha = 0.4f), Offset(x(it.first), 0f), Offset(x(it.first), h))
                    drawCircle(fiber, 6.dp.toPx(), Offset(x(it.first), y(it.second)))
                }
                for (i in days.indices) axisLabel(days, i, range)?.let { label(it, x(i), size.height - 3.dp.toPx(), muted, 11.dp.toPx()) }
            }
        } else {
            Text("Ab zwei erfassten Tagen siehst du hier deinen Verlauf.", style = font(13), color = C.textSecondary)
        }
    }
}

/** Catmull-Rom spline through the points (like the iOS charts). */
private fun smoothPath(p: List<Offset>): Path = Path().apply {
    if (p.isEmpty()) return@apply
    moveTo(p[0].x, p[0].y)
    for (i in 0 until p.size - 1) {
        val p0 = p[max(i - 1, 0)]; val p1 = p[i]; val p2 = p[i + 1]; val p3 = p[min(i + 2, p.size - 1)]
        cubicTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6, p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y)
    }
}

@Composable
private fun MacroCard(logged: List<DayStat>) {
    val goals = App.goals
    val n = max(logged.size, 1)
    val p = logged.sumOf { it.protein } / n; val c = logged.sumOf { it.carbs } / n; val f = logged.sumOf { it.fat } / n
    val total = max(p * 4 + c * 4 + f * 9, 1.0)
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        CardTitle("Ø Makros pro Tag")
        Row(verticalAlignment = Alignment.CenterVertically) {
            Canvas(Modifier.size(110.dp).alpha(if (logged.isEmpty()) 0.2f else 1f)) {
                val w = size.width * 0.19f
                var start = -90f
                val parts = listOf(max(p * 4, 0.01) to Palette.protein, max(c * 4, 0.01) to Palette.carbs, max(f * 9, 0.01) to Palette.fat)
                val sum = parts.sumOf { it.first }
                for ((v, color) in parts) {
                    val sweep = (v / sum * 360).toFloat()
                    if (sweep > 2.5f) drawArc(color, start + 1.2f, sweep - 2.4f, false, Offset(w / 2, w / 2), Size(size.width - w, size.height - w), style = Stroke(w))
                    start += sweep
                }
            }
            Spacer(Modifier.width(20.dp))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                MacroShare("Protein", p, goals.protein, p * 4 / total, Palette.protein)
                MacroShare("Kohlenhydrate", c, goals.carbs, c * 4 / total, Palette.carbs)
                MacroShare("Fett", f, goals.fat, f * 9 / total, Palette.fat)
            }
        }
    }
}

@Composable
private fun MacroShare(name: String, v: Double, goal: Double, share: Double, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).background(color))
        Spacer(Modifier.width(8.dp))
        Column {
            Text(name, style = font(13, FontWeight.Medium), color = C.textSecondary)
            Text("${Math.round(v)} / ${goal.clean} g · ${(share * 100).roundToInt()} %", style = font(14, FontWeight.SemiBold), color = C.textPrimary)
        }
    }
}

@Composable
private fun WeekdayCard(logged: List<DayStat>) {
    var sel by remember { mutableStateOf<Int?>(null) }
    val goals = App.goals
    val grouped = logged.groupBy { it.day.dayOfWeek.value }   // 1 = Monday
    val data = (1..7).map { wd ->
        val list = grouped[wd] ?: emptyList()
        val avgKcal = if (list.isEmpty()) 0.0 else list.sumOf { it.kcal } / list.size
        // iOS weekday numbering: 1 = Sunday
        val avgGoal = if (list.isEmpty()) goals.kcal(wd % 7 + 1) else list.sumOf { it.goal } / list.size
        Triple(java.time.DayOfWeek.of(wd), avgKcal, avgGoal)
    }
    val top = data.maxByOrNull { it.second }
    val muted = C.textSecondary
    val colors = data.map { goalColor(GoalStatus.of(it.second, it.third)) }
    fun short(d: java.time.DayOfWeek) = d.getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.GERMAN).removeSuffix(".")
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ChartHeader(sel != null, scrub = {
            val (wd, kcal, goal) = data[sel!!]
            ScrubHeader("Ø an allen ${wd.getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.GERMAN)}en", listOf(
                ScrubItem("gegessen", kcal.kcalString, if (kcal > 0) colors[sel!!] else C.textSecondary),
                ScrubItem("Ziel", goal.kcalString),
                ScrubItem("erfasst", "${(grouped[wd.value] ?: emptyList()).size} ×"),
            ))
        }) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row {
                    CardTitle("Ø nach Wochentag", Modifier.weight(1f))
                    if (top != null && top.second > 0) Text("Am meisten: ${short(top.first)}", style = font(13, FontWeight.SemiBold), color = Palette.accentText)
                }
                Text("Durchschnitt aller Montage, Dienstage usw. im gewählten Zeitraum. Zeigt, an welchen Tagen du typischerweise mehr isst.", style = font(12), color = C.textSecondary)
            }
        }
        Canvas(Modifier.fillMaxWidth().height(130.dp).scrub(7) { sel = it }) {
            val axis = AXIS.dp.toPx()
            val h = size.height - axis
            val maxV = max(data.maxOf { max(it.second, it.third) } * 1.1, 1.0)
            val slot = size.width / 7
            fun y(v: Double) = h - (v / maxV).toFloat() * h
            data.forEachIndexed { i, (wd, kcal, goal) ->
                val cx = slot * i + slot / 2
                val w = slot * 0.6f
                if (kcal > 0) drawRoundRect(colors[i].copy(alpha = 0.85f * (if (sel == null || sel == i) 1f else 0.35f)), Offset(cx - w / 2, y(kcal)), Size(w, h - y(kcal)), CornerRadius(5.dp.toPx()))
                drawLine(muted, Offset(slot * i, y(goal)), Offset(slot * (i + 1), y(goal)), 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx())))
                label(short(wd), cx, size.height - 3.dp.toPx(), muted, 11.dp.toPx())
            }
        }
    }
}

@Composable
private fun TopFoodsCard(logged: List<DayStat>) {
    val top = logged.flatMap { it.entries }.groupBy { it.name }.map { Triple(it.key, it.value.sumOf { e -> e.kcal }, it.value.size) }
        .sortedByDescending { it.second }.take(5)
    val total = max(logged.sumOf { it.kcal }, 1.0)
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        CardTitle("Größte Kalorienquellen")
        if (top.isEmpty()) Text("Noch keine Einträge im Zeitraum.", style = font(13), color = C.textSecondary)
        top.forEachIndexed { i, (name, kcal, count) ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("${i + 1}", style = font(13, FontWeight.Black), color = Palette.accentText, modifier = Modifier.width(18.dp))
                Spacer(Modifier.width(10.dp))
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Row {
                        Text(name, style = font(14, FontWeight.SemiBold), color = C.textPrimary, maxLines = 1, modifier = Modifier.weight(1f))
                        Text("${kcal.kcalString} kcal · $count×", style = font(12), color = C.textSecondary)
                    }
                    Bar(kcal / total, Palette.accent, height = 4.dp, track = Color.Transparent)
                }
            }
        }
    }
}

@Composable
private fun MicroCard(logged: List<DayStat>) {
    val count = max(logged.size, 1)
    val total = remember(logged) { Nutrients.sum(logged.flatMap { it.entries }.map { it.nutrients }) }
    val coverage = HealthScore.microKeys.mapNotNull { key -> key.dailyValue?.let { key to (total[key] ?: 0.0) / count / it } }.sortedBy { it.second }
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row {
            CardTitle("Vitamine & Mineralstoffe", Modifier.weight(1f))
            Text("Ø pro Tag", style = font(12), color = C.textSecondary)
        }
        if (logged.isEmpty()) Text("Noch keine Daten im Zeitraum.", style = font(13), color = C.textSecondary)
        else {
            Text("Am wenigsten abgedeckt", style = font(12, FontWeight.SemiBold), color = C.textSecondary)
            for ((key, pct) in coverage.take(5)) Row(verticalAlignment = Alignment.CenterVertically) {
                Text(key.label, style = font(14), color = C.textPrimary, modifier = Modifier.width(110.dp), maxLines = 1)
                Bar(pct, if (pct >= 1) Palette.fiber else if (pct >= 0.6) Palette.carbs else Palette.danger, Modifier.weight(1f), height = 6.dp)
                Text("${(pct * 100).toInt()} %", style = font(12, FontWeight.SemiBold), color = C.textSecondary, modifier = Modifier.width(44.dp),
                    textAlign = androidx.compose.ui.text.style.TextAlign.End)
            }
        }
    }
}

@Composable
private fun WeightCard(weights: List<WeightLog>, range: Int) {
    var sel by remember { mutableStateOf<Int?>(null) }
    val cutoff = System.currentTimeMillis() - max(range, 30) * 86_400_000L
    val shown = weights.filter { it.date >= cutoff }
    val accent = Palette.accent
    val muted = C.textSecondary
    val text = C.textPrimary
    val bubble = C.cardAlt
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CardTitle("Gewicht")
            if (App.prefs.bool(HealthConnect.WEIGHT_KEY)) { Spacer(Modifier.width(4.dp)); Icon(Icons.Rounded.Favorite, null, Modifier.size(12.dp), tint = Palette.protein) }
            Spacer(Modifier.weight(1f))
            weights.lastOrNull()?.let { Text("${it.kg.format(1, 1)} kg", style = font(15, FontWeight.SemiBold), color = accent) }
            Spacer(Modifier.width(10.dp))
            Box(Modifier.size(30.dp).clip(CircleShape).background(accent).squishClick { Nav.sheet { WeightSheet() } }, contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Add, "Gewicht eintragen", Modifier.size(18.dp), tint = Color.White)
            }
        }
        if (shown.size >= 2) {
            val lo = shown.minOf { it.kg } - 1
            val hi = shown.maxOf { it.kg } + 1
            val t0 = shown.first().date
            val t1 = max(shown.last().date, t0 + 1)
            Canvas(Modifier.fillMaxWidth().height(160.dp).pointerInput(shown) {
                fun nearest(x: Float): Int = shown.indices.minBy { abs((shown[it].date - t0).toFloat() / (t1 - t0) * size.width - x) }
                detectDragGesturesAfterLongPress(onDragStart = { sel = nearest(it.x) }, onDrag = { c, _ -> sel = nearest(c.position.x) },
                    onDragEnd = { sel = null }, onDragCancel = { sel = null })
            }) {
                val pad = 8.dp.toPx()
                fun x(t: Long) = pad + (t - t0).toFloat() / (t1 - t0) * (size.width - 2 * pad)
                fun y(kg: Double) = pad + ((hi - kg) / (hi - lo)).toFloat() * (size.height - 2 * pad)
                val pts = shown.map { Offset(x(it.date), y(it.kg)) }
                drawPath(smoothPath(pts), accent, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round))
                pts.forEachIndexed { i, p -> drawCircle(accent, if (sel == i) 6.dp.toPx() else 3.dp.toPx(), p) }
                sel?.let { i ->
                    val p = pts[i]
                    drawLine(muted.copy(alpha = 0.4f), Offset(p.x, 0f), Offset(p.x, size.height))
                    val w = shown[i]
                    val bw = 80.dp.toPx(); val bh = 38.dp.toPx()
                    val bx = (p.x - bw / 2).coerceIn(0f, size.width - bw)
                    val by = if (p.y - bh - 10.dp.toPx() > 0) p.y - bh - 10.dp.toPx() else p.y + 10.dp.toPx()
                    drawRoundRect(bubble, Offset(bx, by), Size(bw, bh), CornerRadius(8.dp.toPx()))
                    label("${w.kg.format(1, 1)} kg", bx + bw / 2, by + 17.dp.toPx(), text, 14.dp.toPx())
                    label(w.date.localDate().shortDayMonth(), bx + bw / 2, by + 31.dp.toPx(), muted, 11.dp.toPx())
                }
            }
            val diff = shown.last().kg - shown.first().kg
            Text("${if (diff <= 0) "−" else "+"}${abs(diff).format(1, 1)} kg seit ${shown.first().date.localDate().shortDayMonth()}",
                style = font(12), color = if (diff <= 0) Palette.fiber else C.textSecondary)
        } else {
            Text("Trag dein Gewicht regelmäßig ein oder verbinde Health Connect in den Einstellungen.", style = font(14), color = C.textSecondary)
        }
        if (weights.isNotEmpty()) Row(Modifier.clickable { Nav.sheet { WeightListSheet() } }, verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.AutoMirrored.Rounded.List, null, Modifier.size(18.dp), tint = accent)
            Spacer(Modifier.width(6.dp))
            Text("Alle Einträge bearbeiten", style = font(14, FontWeight.SemiBold), color = accent)
        }
    }
}

@Composable
fun WeightListSheet() {
    val scope = rememberCoroutineScope()
    val weights by remember { App.db.weights().observeAll() }.collectAsState(emptyList())
    Screen("Gewicht", leading = "Fertig") {
        Column(Modifier.fillMaxWidth().card(0.dp)) {
            weights.reversed().forEachIndexed { i, w ->
                if (i > 0) de.purrtion.app.ui.Divider()
                SwipeRow(true, onDelete = { scope.launch { App.db.weights().delete(w) } }, onDuplicate = {}) {
                    Row(Modifier.fillMaxWidth().background(C.card).padding(horizontal = 16.dp, vertical = 14.dp)) {
                        Text(w.date.localDate().let { "${it.dayOfMonth}. ${it.month.getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.GERMAN)} ${it.year}" },
                            style = font(16), color = C.textPrimary, modifier = Modifier.weight(1f))
                        Text("${w.kg.format(1, 1)} kg", style = font(16, FontWeight.SemiBold), color = C.textPrimary)
                    }
                }
            }
        }
        Text("Zum Löschen nach links wischen.", style = font(12), color = C.textSecondary)
    }
}

@Composable
fun WeightSheet() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val goals = App.goals
    var kg by remember { mutableStateOf(goals.weightKG) }
    // Start from the last weigh-in (also ones from Health Connect), so − / + only needs a tap or two.
    LaunchedEffect(Unit) { App.db.weights().all().lastOrNull()?.let { kg = it.kg } }
    var date by remember { mutableStateOf(LocalDate.now()) }
    Screen("Gewicht eintragen", bottom = {
        PillButton("Speichern", Modifier.fillMaxWidth()) {
            val value = Math.round(kg * 10) / 10.0
            val time = if (date == LocalDate.now()) Instant.now() else date.atTime(8, 0).atZone(zone).toInstant()
            scope.launch {
                App.db.weights().insert(WeightLog(date = time.toEpochMilli(), kg = value))
                goals.weightKG = value
                HealthConnect.saveWeight(value, time)
            }
            h.success()
            Nav.dismissSheet()
        }
    }) {
        Column(Modifier.fillMaxWidth().card()) { SliderField("Gewicht", kg, 35.0..200.0, { kg = it }, step = 0.1, unit = "kg", decimals = 1, stepper = true) }
        Row(Modifier.fillMaxWidth().card().clickable {
            android.app.DatePickerDialog(context, { _, y, m, d -> date = LocalDate.of(y, m + 1, d) }, date.year, date.monthValue - 1, date.dayOfMonth).apply {
                datePicker.maxDate = System.currentTimeMillis()
            }.show()
        }, verticalAlignment = Alignment.CenterVertically) {
            Text("Datum", style = font(16), color = C.textPrimary, modifier = Modifier.weight(1f))
            Text(if (date == LocalDate.now()) "Heute" else date.fullTitle(), style = font(16, FontWeight.SemiBold), color = Palette.accentText)
        }
    }
}

// MARK: Expenditure

/** "Echter Verbrauch" in the history: measured daily expenditure split into resting, digestion and movement. */
@Composable
fun ExpenditureCard(e: ExpenditureEstimate) {
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.MonitorWeight, null, tint = C.textPrimary)
            Spacer(Modifier.width(6.dp))
            CardTitle("Echter Verbrauch", Modifier.weight(1f))
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = C.textSecondary)
        }
        Row(verticalAlignment = Alignment.Bottom) {
            Text("Ø ${e.total.kcalString}", style = font(30, FontWeight.Black), color = C.textPrimary)
            Spacer(Modifier.width(6.dp))
            Text("kcal/Tag", style = font(14, FontWeight.SemiBold), color = C.textSecondary, modifier = Modifier.padding(bottom = 5.dp).weight(1f))
            ConfidencePill(e)
        }
        ExpenditureBar(e)
        val f = e.trackerFactor
        if (!e.isMeasured) Text("Noch eine Schätzung. Für den gemessenen Wert fehlen: ${e.missing.joinToString(", ")}.", style = font(12), color = C.textSecondary)
        else if (f != null && abs(f - 1) > 0.1) Text(
            if (f < 1) "Deine Aktivität laut Health Connect ist rund ${((1 - f) * 100).roundToInt()} % höher als das, was dein Gewicht zeigt."
            else "Du bewegst dich rund ${((f - 1) * 100).roundToInt()} % mehr, als Health Connect misst (z. B. Alltag ohne Uhr).",
            style = font(12), color = C.textSecondary)
    }
}

@Composable
fun ExpenditureBar(e: ExpenditureEstimate, showLegend: Boolean = true) {
    val parts = listOf(Triple("Grundumsatz", e.basal, Palette.protein), Triple("Verdauung", e.digestion, Palette.carbs), Triple("Bewegung", e.movement, Palette.accent))
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.fillMaxWidth().height(12.dp).clip(CircleShape), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            for ((_, v, color) in parts) if (v > 0) Box(Modifier.weight(max(v, 1.0).toFloat()).fillMaxSize().background(color))
        }
        if (showLegend) Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            for ((name, v, color) in parts) Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(8.dp).clip(RoundedCornerShape(2.dp)).background(color))
                    Spacer(Modifier.width(4.dp))
                    Text(v.kcalString, style = font(14, FontWeight.Bold), color = C.textPrimary)
                }
                Text(name, style = font(11), color = C.textSecondary, maxLines = 1)
            }
        }
    }
}

@Composable
private fun ConfidencePill(e: ExpenditureEstimate) {
    val color = if (e.isMeasured) Palette.fiber else C.textSecondary
    Text(if (e.isMeasured) "Genauigkeit ${e.confidence.label}" else "Schätzung", style = font(11, FontWeight.Bold), color = color, maxLines = 1,
        modifier = Modifier.clip(CircleShape).background(color.copy(alpha = 0.14f)).padding(horizontal = 8.dp, vertical = 3.dp))
}

@Composable
fun ExpenditureSheet(e: ExpenditureEstimate) {
    val goals = App.goals
    val h = rememberHaptics()
    var applied by remember { mutableStateOf(false) }
    val suggested = Math.round(max(1200.0, e.total + goals.target.delta) / 10) * 10.0
    fun weightText(kg: Double?) = kg?.let { "${it.format(1, 1)} kg" } ?: "deinem Gewicht"
    Screen("Echter Verbrauch", leading = "Fertig") {
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(e.total.kcalString, style = font(40, FontWeight.Black), color = C.textPrimary)
                Spacer(Modifier.width(6.dp))
                Text("kcal pro Tag", style = font(15, FontWeight.SemiBold), color = C.textSecondary, modifier = Modifier.padding(bottom = 7.dp).weight(1f))
                ConfidencePill(e)
            }
            Text(if (e.isMeasured) "± ${e.uncertainty.roundToInt()} kcal · gemessen aus ${e.loggedDays} Tagen Essen und ${e.weighIns} Wiegungen der letzten ${e.windowDays} Tage"
                else "Vorläufige Schätzung aus ${if (e.basalFromHealth) "Health Connect" else "deinem Profil"}", style = font(13), color = C.textSecondary)
            ExpenditureBar(e)
        }
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            CardTitle("Woraus er besteht")
            PartRow("Grundumsatz", e.basal, Palette.protein, if (e.basalFromHealth) "Ruheenergie laut Health Connect" else "Mifflin-St Jeor bei ${weightText(e.trendWeight)}")
            PartRow("Verdauung", e.digestion, Palette.carbs, "≈ 10 % von dem, was du isst")
            PartRow("Bewegung", e.movement, Palette.accent, "Training, Schritte und Alltag. Der Rest.")
            if (e.trackedActive > 0) {
                de.purrtion.app.ui.Divider()
                PartRow("Aktivität laut Health Connect", e.trackedActive, C.textSecondary, "inkl. selbst eingetragener Aktivität")
                val f = e.trackerFactor
                if (f != null && e.isMeasured) Text("Dein Körper bestätigt ${(f * 100).roundToInt()} % davon.", style = font(13, FontWeight.SemiBold),
                    color = if (f < 0.9) Palette.carbs else Palette.fiber)
            }
        }
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            CardTitle("Grundlage")
            Fact("Ø gegessen", if (e.intake > 0) "${e.intake.kcalString} kcal" else "–")
            Fact("Gewichtstrend", e.weightPerWeek?.let { (if (it >= 0) "+" else "−") + abs(it).format(2, 2) + " kg/Woche" } ?: "–")
            e.trendWeight?.let { Fact("Trendgewicht", weightText(it)) }
            Fact("Energie je kg", "${e.energyDensity.kcalString} kcal")
            e.measured?.let {
                Fact("Aus der Energiebilanz", "${it.kcalString} kcal")
                Fact("Vorab-Schätzung", "${e.prior.kcalString} kcal")
                Fact("Gewicht der Messung", "${(e.measuredWeight * 100).roundToInt()} %")
            }
            if (e.missing.isNotEmpty()) Text("Noch nötig: ${e.missing.joinToString(", ")}.", style = font(13, FontWeight.SemiBold), color = Palette.accentText)
        }
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            CardTitle("So wird gerechnet")
            Text("Verbrauch = was du isst minus was dein Körper speichert. Der Gewichtstrend kommt aus einer robusten Regression über alle Wiegungen. Einzelne Ausreißer durch Wasser oder Salz zählen kaum. Wie viele kcal ein Kilo ausmacht, hängt vom Körperfett ab (Forbes/Hall-Modell, ca. 6.000 bis 8.000 kcal). Tage ohne Einträge zählen mit deinem Durchschnitt, unvollständige Tage werden ignoriert. Solange wenig Daten da sind, stützt sich der Wert auf Health Connect bzw. dein Profil. Mit jeder Woche zählt die Messung mehr.",
                style = font(13), color = C.textSecondary)
            Text("Am genauesten wird es, wenn du dich mehrmals pro Woche morgens wiegst und an den meisten Tagen alles einträgst.", style = font(13, FontWeight.SemiBold), color = C.textSecondary)
        }
        if (e.isMeasured && abs(suggested - goals.kcal) >= 50) {
            Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Passendes Ziel für „${goals.target.label}“: ${suggested.kcalString} kcal", style = font(15, FontWeight.Bold), color = C.textPrimary)
                Text("Aktuell ${goals.kcal.kcalString} kcal. Gilt ab heute, vergangene Tage behalten ihr Ziel.", style = font(13), color = C.textSecondary)
                PillButton(if (applied) "Übernommen" else "Ziel übernehmen", Modifier.fillMaxWidth(), icon = if (applied) Icons.Rounded.Check else Icons.Rounded.TrackChanges, enabled = !applied) {
                    h.success()
                    goals.kcal = suggested
                    goals.syncMacros()
                    applied = true
                }
            }
        }
    }
}

@Composable
private fun PartRow(title: String, value: Double, color: Color, note: String) {
    Row(verticalAlignment = Alignment.Top) {
        Box(Modifier.padding(top = 5.dp).size(10.dp).clip(RoundedCornerShape(2.dp)).background(color))
        Spacer(Modifier.width(8.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = font(15, FontWeight.SemiBold), color = C.textPrimary)
            Text(note, style = font(12), color = C.textSecondary)
        }
        Text("${value.kcalString} kcal", style = font(15, FontWeight.Bold), color = C.textPrimary)
    }
}

@Composable
private fun Fact(title: String, value: String) {
    Row {
        Text(title, style = font(14), color = C.textSecondary, modifier = Modifier.weight(1f))
        Text(value, style = font(14, FontWeight.SemiBold), color = C.textPrimary)
    }
}
