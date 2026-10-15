package de.purrtion.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.AddCircle
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.data.Store
import de.purrtion.app.domain.GoalStatus
import de.purrtion.app.domain.HealthScore
import de.purrtion.app.model.German
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.fullTitle
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.CheckCircle
import de.purrtion.app.ui.Divider
import de.purrtion.app.ui.GoalLegend
import de.purrtion.app.ui.MacroDot
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.Screen
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
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle

/** Month grid: green = within the calorie goal, orange = up to 5 % over, red = more, grey = nothing logged. */
@Composable
fun CalendarMonth(month: YearMonth, onMonth: (YearMonth) -> Unit, selected: LocalDate? = null, allowFuture: Boolean = false, onSelect: (LocalDate) -> Unit) {
    val goals = App.goals
    val h = rememberHaptics()
    val start = month.atDay(1)
    val end = month.atEndOfMonth()
    val entries by remember(month) { App.db.entries().observeRange(start.toEpochDay(), end.toEpochDay()) }.collectAsState(emptyList())
    val kcal = entries.groupBy { it.day }.mapValues { e -> e.value.sumOf { it.kcal } }
    val today = LocalDate.now()
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowLeft, "Voriger Monat", Modifier.clickable { h.tap(); onMonth(month.minusMonths(1)) }, tint = C.textPrimary)
            Text(month.format(DateTimeFormatter.ofPattern("LLLL yyyy", German)), style = font(17, FontWeight.Bold), color = C.textPrimary,
                modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            val atCurrent = !allowFuture && month == YearMonth.now()
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, "Nächster Monat",
                Modifier.clickable(enabled = !atCurrent) { h.tap(); onMonth(month.plusMonths(1)) }, tint = C.textPrimary.copy(alpha = if (atCurrent) 0.3f else 1f))
        }
        Row {
            for (i in 0 until 7) Text(java.time.DayOfWeek.of(i + 1).getDisplayName(TextStyle.NARROW, German), style = font(11, FontWeight.SemiBold),
                color = C.textSecondary, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        }
        val offset = start.dayOfWeek.value - 1
        val cells: List<LocalDate?> = List(offset) { null } + (0 until month.lengthOfMonth()).map { start.plusDays(it.toLong()) }
        for (week in cells.chunked(7)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (i in 0 until 7) {
                    val d = week.getOrNull(i)
                    Box(Modifier.weight(1f).height(38.dp)) {
                        if (d != null) {
                            val k = kcal[d.toEpochDay()] ?: 0.0
                            val future = !allowFuture && d.isAfter(today)
                            val color = goalColor(GoalStatus.of(k, goals.target(d).kcal))
                            Box(Modifier.fillMaxWidth().height(38.dp).clip(RoundedCornerShape(10.dp)).background(color)
                                .then(if (d == selected) Modifier.border(2.dp, Palette.accent, RoundedCornerShape(10.dp))
                                    else if (d == today) Modifier.border(2.dp, C.textSecondary, RoundedCornerShape(10.dp)) else Modifier)
                                .squishClick(!future) { h.tap(); onSelect(d) }, contentAlignment = Alignment.Center) {
                                Text("${d.dayOfMonth}", style = font(14, if (d == today) FontWeight.ExtraBold else FontWeight.SemiBold),
                                    color = (if (k > 0) Color.White else C.textPrimary).copy(alpha = if (future) 0.35f else 1f))
                            }
                        }
                    }
                }
            }
        }
        GoalLegend()
    }
}


/** Calendar in a sheet to pick a day. */
@Composable
fun CalendarSheet(title: String, allowFuture: Boolean = false, onPick: (LocalDate) -> Unit) {
    var month by remember { mutableStateOf(YearMonth.now()) }
    Screen(title) {
        Box(Modifier.fillMaxWidth().card()) {
            CalendarMonth(month, { month = it }, allowFuture = allowFuture) { Nav.pop(); onPick(it) }
        }
    }
}

/** Lists the entries of another day; deselect what you don't want, then add. */
@Composable
fun CopyPickerSheet(source: LocalDate, target: LocalDate) {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val entries by remember { App.db.entries().observeDay(source.toEpochDay()) }.collectAsState(emptyList())
    var selected by remember { mutableStateOf<Set<String>?>(null) }
    LaunchedEffect(entries) { if (selected == null && entries.isNotEmpty()) selected = entries.map { it.id }.toSet() }
    val sel = selected ?: emptySet()
    val chosen = entries.filter { it.id in sel }
    val all = entries.isNotEmpty() && sel.size == entries.size
    Screen("Übernehmen", bottom = if (entries.isEmpty()) null else ({
        PillButton("${chosen.size} Einträge hinzufügen · ${chosen.sumOf { it.kcal }.kcalString} kcal", icon = Icons.Rounded.AddCircle, enabled = chosen.isNotEmpty()) {
            scope.launch { Store.copy(chosen.sortedBy { it.createdAt }, target); h.success(); Nav.pop() }
        }
    })) {
        if (entries.isEmpty()) {
            Column(Modifier.fillMaxWidth().padding(vertical = 30.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                CatMascot(CatMood.sleeping, 4.dp)
                Spacer(Modifier.height(10.dp))
                Text("An diesem Tag gibt es keine Einträge.", style = font(15), color = C.textSecondary)
            }
        } else {
            Row(Modifier.fillMaxWidth().card(14.dp).clickable { h.tap(); selected = if (all) emptySet() else entries.map { it.id }.toSet() },
                verticalAlignment = Alignment.CenterVertically) {
                CheckCircle(all)
                Spacer(Modifier.width(12.dp))
                Text(if (all) "Alle abwählen" else "Alle auswählen", style = font(16, FontWeight.SemiBold), color = C.textPrimary, modifier = Modifier.weight(1f))
                Text("${sel.size}/${entries.size}", style = font(14), color = C.textSecondary)
            }
            Text(source.fullTitle(), style = font(14, FontWeight.SemiBold), color = C.textSecondary, modifier = Modifier.padding(start = 6.dp))
            Column(Modifier.fillMaxWidth().card(0.dp)) {
                entries.forEachIndexed { i, e ->
                    if (i > 0) Divider()
                    Row(Modifier.fillMaxWidth().clickable { h.tap(); selected = if (e.id in sel) sel - e.id else sel + e.id }.padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically) {
                        CheckCircle(e.id in sel)
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(e.name, style = font(15, FontWeight.SemiBold), color = C.textPrimary, maxLines = 1)
                            Text(e.amountText, style = font(12), color = C.textSecondary, maxLines = 1)
                        }
                        Text("${e.kcal.kcalString} kcal", style = font(14, FontWeight.SemiBold), color = C.textPrimary)
                    }
                }
            }
        }
    }
}

/** Summary of a single past day (from the history calendar). */
@Composable
fun DaySummarySheet(day: LocalDate) {
    val goals = App.goals
    val scope = rememberCoroutineScope()
    val entries by remember { App.db.entries().observeDay(day.toEpochDay()) }.collectAsState(emptyList())
    val total = Nutrients.sum(entries.map { it.nutrients })
    val target = goals.target(day)
    Screen(day.fullTitle(), leading = "Fertig") {
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("${total.kcal.kcalString} kcal", style = font(26, FontWeight.ExtraBold), color = C.textPrimary)
                    val status = GoalStatus.of(total.kcal, target.kcal)
                    Text(if (total.kcal <= target.kcal) "Im Ziel (${target.kcal.kcalString})" else "${(total.kcal - target.kcal).kcalString} kcal über dem Ziel",
                        style = font(13), color = if (status == GoalStatus.none) Palette.fiber else goalColor(status))
                }
                if (goals.healthScoreEnabled && entries.isNotEmpty()) {
                    val score = HealthScore.of(entries, target.kcal, target.protein)
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("${score.score}", style = font(22, FontWeight.ExtraBold), color = scoreColor(score))
                        Text("Score", style = font(11), color = C.textSecondary)
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MacroDot(Palette.protein, total.protein); MacroDot(Palette.carbs, total.carbs); MacroDot(Palette.fat, total.fat)
            }
        }
        Text("Einträge", style = font(14, FontWeight.SemiBold), color = C.textSecondary, modifier = Modifier.padding(start = 6.dp))
        if (entries.isEmpty()) Text("Keine Einträge", style = font(15), color = C.textSecondary)
        for (e in entries) {
            SwipeRow(true, onDelete = { scope.launch { Store.delete(e) } }, onDuplicate = { scope.launch { Store.duplicate(e, LocalDate.now()) } }) {
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(C.card).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(e.name, style = font(15, FontWeight.SemiBold), color = C.textPrimary, maxLines = 1)
                        Text(e.amountText, style = font(12), color = C.textSecondary, maxLines = 1)
                    }
                    Text("${e.kcal.kcalString} kcal", style = font(14, FontWeight.SemiBold), color = C.textPrimary)
                }
            }
        }
    }
}

