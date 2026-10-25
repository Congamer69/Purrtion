package de.purrtion.app.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AcUnit
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Undo
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.domain.Diag
import kotlinx.coroutines.flow.catch
import de.purrtion.app.data.FoodEntry
import de.purrtion.app.data.UndoStore
import de.purrtion.app.domain.GoalStatus
import de.purrtion.app.domain.Streak
import de.purrtion.app.domain.Extras
import de.purrtion.app.domain.Shop
import de.purrtion.app.ui.theme.RadiusSmall
import de.purrtion.app.domain.ShopItem
import de.purrtion.app.ui.pixel.CatPalette
import de.purrtion.app.ui.pixel.Outfit
import de.purrtion.app.ui.pixel.PixelSpriteView
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.model.mondayOfWeek
import de.purrtion.app.model.weekdayShort
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.TopTextButton
import de.purrtion.app.ui.card
import de.purrtion.app.ui.goalColor
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.pixel.rememberTime
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import kotlin.math.sin

/** Sits next to the "…" menu while something can still be restored. */
@Composable
fun UndoButton() {
    val label = UndoStore.label
    var last by remember { mutableStateOf("Eintrag") }
    if (label != null) last = label
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    AnimatedVisibility(label != null, enter = scaleIn(spring(0.6f)) + fadeIn(), exit = scaleOut() + fadeOut()) {
        Row(
            Modifier.padding(end = 8.dp).height(34.dp).clip(CircleShape).background(Palette.accent)
                .squishClick { scope.launch { UndoStore.undo(); h.success() } }.padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Rounded.Undo, "$last wiederherstellen", Modifier.size(14.dp), tint = Color.White)
            Spacer(Modifier.width(5.dp))
            Text("$last zurück", style = font(12, FontWeight.Bold), color = Color.White, maxLines = 1)
        }
    }
}

// MARK: Streak chip

/** Flame + count in the Today header. Dim until the first entry of the day, then it hops like a bouncy ball. */
@Composable
fun StreakChip(streak: Streak.State, pop: Int, onClick: () -> Unit) {
    val lit = streak.loggedToday
    val yesterday = LocalDate.now().minusDays(1)
    val iced = !lit && yesterday in streak.frozen
    val tint = if (iced) Palette.water else if (lit) Palette.accent else C.textSecondary
    val bg = if (iced) Palette.water.copy(alpha = 0.16f) else if (lit) C.accentSoft else C.cardAlt

    val sx = remember { Animatable(1f) }
    val sy = remember { Animatable(1f) }
    val y = remember { Animatable(0f) }
    val flame = remember { Animatable(1f) }
    val tilt = remember { Animatable(0f) }
    LaunchedEffect(pop) {
        if (pop == 0) return@LaunchedEffect
        coroutineScope {
            launch { sx.animateTo(1.12f, tween(150)); sx.animateTo(0.9f, tween(260)); sx.animateTo(1.14f, tween(200)); sx.animateTo(1f, spring(0.4f)) }
            launch { sy.animateTo(0.86f, tween(150)); sy.animateTo(1.12f, tween(260)); sy.animateTo(0.84f, tween(200)); sy.animateTo(1f, spring(0.4f)) }
            launch { y.animateTo(0f, tween(150)); y.animateTo(-14f, tween(260)); y.animateTo(0f, tween(200)); y.animateTo(0f, spring(0.4f)) }
            launch {
                delay(150); flame.animateTo(1.6f, spring(0.55f, Spring.StiffnessMedium)); flame.animateTo(1f, spring(0.35f, Spring.StiffnessLow))
            }
            launch {
                delay(300); tilt.animateTo(-16f, tween(150)); tilt.animateTo(14f, tween(180)); tilt.animateTo(-8f, tween(160)); tilt.animateTo(0f, tween(300))
            }
        }
    }

    Row(
        Modifier.graphicsLayer {
            scaleX = sx.value; scaleY = sy.value; translationY = y.value * density
            transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 1f)
        }.height(34.dp).clip(CircleShape).background(bg).clickable(onClick = onClick).padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(if (iced) Icons.Rounded.AcUnit else Icons.Rounded.LocalFireDepartment, "Serie",
            Modifier.size(16.dp).graphicsLayer { scaleX = flame.value; scaleY = flame.value; rotationZ = tilt.value }, tint = tint)
        Spacer(Modifier.width(4.dp))
        Text("${streak.count}", style = font(14, FontWeight.Bold), color = tint)
        if (streak.freezes > 0 && !iced) {
            Spacer(Modifier.width(4.dp))
            Icon(Icons.Rounded.AcUnit, null, Modifier.size(12.dp), tint = Palette.water)
        }
    }
}

// MARK: Week strip

private const val WEEK_PAGES = 104

/** Page of the pager that shows the week `offset` weeks away from this one (0 = this week). */
fun weekPage(offset: Int) = WEEK_PAGES - 1 + offset

fun weekOffset(date: LocalDate): Int {
    val thisMonday = LocalDate.now().mondayOfWeek()
    return (java.time.temporal.ChronoUnit.DAYS.between(thisMonday, date.mondayOfWeek()) / 7).toInt()
}

/** Swipeable weeks (Mo–So) with goal status, back two years. */
@Composable
fun WeekStrip(day: LocalDate, pager: PagerState, onSelect: (LocalDate) -> Unit) {
    HorizontalPager(pager, Modifier.fillMaxWidth().height(92.dp), beyondViewportPageCount = 0) { page ->
        WeekPage(LocalDate.now().mondayOfWeek().plusWeeks((page - (WEEK_PAGES - 1)).toLong()), day, onSelect)
    }
}

@Composable
private fun WeekPage(weekStart: LocalDate, day: LocalDate, onSelect: (LocalDate) -> Unit) {
    val entries by remember(weekStart) { App.db.entries().observeRange(weekStart.toEpochDay(), weekStart.plusDays(6).toEpochDay()).catch { Diag.warn("Wochenleiste", it); emit(emptyList()) } }.collectAsState(emptyList())
    val byDay = entries.groupBy { it.day }.mapValues { (_, l) -> l.sumOf { it.kcal } }
    val frozen = Diag.safe("Eistage", emptySet()) { Streak.frozenDays() }
    Row(Modifier.fillMaxSize().padding(horizontal = 4.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        for (i in 0 until 7) {
            val d = weekStart.plusDays(i.toLong())
            WeekCell(d, byDay[d.toEpochDay()] ?: 0.0, d in frozen, d == day, onSelect, Modifier.weight(1f))
        }
    }
}

@Composable
private fun WeekCell(d: LocalDate, kcal: Double, frozen: Boolean, selected: Boolean, onSelect: (LocalDate) -> Unit, modifier: Modifier) {
    val h = rememberHaptics()
    val today = LocalDate.now()
    val future = d.isAfter(today)
    val isToday = d == today
    val status = GoalStatus.of(kcal, App.goals.target(d).kcal)
    val showFreeze = frozen && kcal == 0.0
    // Today sits on the accent pill; any other day on an inverted (text-coloured) pill, so looking back is obvious.
    val pill = if (isToday) Palette.accent else C.textPrimary
    val onPill = if (isToday) Color.White else C.background
    Column(
        modifier.fillMaxSize().padding(vertical = 4.dp).clip(RoundedCornerShape(18.dp))
            .background(if (selected) pill else Color.Transparent)
            .clickable(enabled = !future) { h.tap(); onSelect(d) }
            .graphicsLayer { alpha = if (future) 0.35f else 1f },
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
    ) {
        Text(d.weekdayShort().take(2), style = font(12, FontWeight.Medium),
            color = if (selected) onPill.copy(alpha = 0.75f) else if (isToday) Palette.accent else C.textSecondary)
        Spacer(Modifier.height(5.dp))
        Text("${d.dayOfMonth}", style = font(17, FontWeight.Bold), color = if (selected) onPill else C.textPrimary)
        Spacer(Modifier.height(5.dp))
        Box(Modifier.height(9.dp), contentAlignment = Alignment.Center) {
            if (showFreeze) {
                Icon(Icons.Rounded.AcUnit, null, Modifier.size(11.dp), tint = if (selected) onPill else Palette.water)
            } else {
                Box(Modifier.size(7.dp).clip(CircleShape)
                    .background(if (status == GoalStatus.none) (if (selected) onPill.copy(alpha = 0.35f) else C.line) else goalColor(status)))
            }
        }
    }
}

// MARK: Streak sheet

private val milestones = listOf(3, 7, 14, 30, 60, 100, 200, 365)

/** Streak overview: count, freezes, milestones and the last five weeks. */
@Composable
fun StreakSheet() {
    var state by remember { mutableStateOf(Streak.State()) }
    val today = LocalDate.now()
    val gridStart = today.mondayOfWeek().minusDays(28)
    var logged by remember { mutableStateOf(emptySet<LocalDate>()) }
    LaunchedEffect(Unit) {
        state = Diag.safe("Serie berechnen", state) { Streak.refresh() }
        logged = App.db.entries().loggedDays(gridStart.toEpochDay()).map(LocalDate::ofEpochDay).toSet()
    }
    Screen("Serie", leading = null, trailing = { TopTextButton("Fertig") { Nav.pop() } }) {
        StreakHero(state)
        StreakStats(state, logged.count { !it.isAfter(today) })
        if (App.prefs.bool(Extras.SHOP, true)) ShopCard(state)
        MilestonesCard(state)
        FreezeCard(state)
        StreakCalendar(state, logged, gridStart)
        Text(
            "Eine Serie zählt jeden Tag, an dem du etwas einträgst. Fehlt ein Tag, rettet ein Streak-Freeze deine Serie automatisch. " +
                "Der Tag zählt dann nicht mit, bricht sie aber nicht ab. Nach jeweils 7 Tagen in Folge bekommst du einen neuen Freeze, du kannst höchstens ${Streak.MAX_FREEZES} sammeln.",
            style = font(12), color = C.textSecondary, modifier = Modifier.padding(horizontal = 8.dp),
        )
    }
}

@Composable
private fun StreakHero(state: Streak.State) {
    val active = state.loggedToday
    val t = if (active) rememberTime() / 1000.0 else 0.0
    val pulse = if (active) ((sin(t * 2.2) + 1) / 2).toFloat() else 0f
    Column(Modifier.fillMaxWidth().card(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        CatMascot(if (state.loggedToday) CatMood.proud else if (state.count > 0) CatMood.idle else CatMood.sleeping, 5.dp)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(56.dp, 68.dp), contentAlignment = Alignment.Center) {
                // A small soft halo behind the flame only.
                if (active) Canvas(Modifier.size(68.dp).graphicsLayer { scaleX = 1 + pulse * 0.12f; scaleY = 1 + pulse * 0.12f }) {
                    drawCircle(Brush.radialGradient(listOf(Palette.accent.copy(alpha = 0.30f), Color.Transparent), center = center, radius = size.minDimension / 2))
                }
                Icon(Icons.Rounded.LocalFireDepartment, null, Modifier.size(44.dp), tint = if (active) Palette.accent else C.textSecondary.copy(alpha = 0.5f))
            }
            Text("${state.count}", style = font(56, FontWeight.ExtraBold), color = C.textPrimary)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(if (state.count == 1) "Tag in Folge" else "Tage in Folge", style = font(17, FontWeight.Bold), color = C.textPrimary)
            Text(
                if (state.loggedToday) "Heute ist erledigt." else if (state.count > 0) "Trag heute etwas ein, um die Serie zu halten." else "Trag etwas ein, um eine neue Serie zu starten.",
                style = font(14), color = C.textSecondary, textAlign = TextAlign.Center,
            )
        }
        NextFreezeBar(state)
    }
}

@Composable
private fun NextFreezeBar(state: Streak.State) {
    val full = state.freezes >= Streak.MAX_FREEZES
    val into = state.count % Streak.DAYS_PER_FREEZE
    val progress = if (full) 1f else into.toFloat() / Streak.DAYS_PER_FREEZE
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.fillMaxWidth().height(10.dp).clip(CircleShape).background(C.track(Palette.water))) {
            Box(Modifier.fillMaxWidth(maxOf(progress, 0.04f)).height(10.dp).clip(CircleShape)
                .background(Brush.horizontalGradient(listOf(Palette.water, Palette.accent))))
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.AcUnit, null, Modifier.size(12.dp), tint = Palette.water)
            Spacer(Modifier.width(4.dp))
            val left = Streak.DAYS_PER_FREEZE - into
            Text(if (full) "Alle Freezes gefüllt" else "Noch $left ${if (left == 1) "Tag" else "Tage"} bis zum nächsten Freeze",
                style = font(12, FontWeight.Bold), color = Palette.water)
        }
    }
}

@Composable
private fun StreakStats(state: Streak.State, activeDays: Int) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        StatTile(Icons.Rounded.EmojiEvents, "${maxOf(state.best, state.count)}", "Rekord", Palette.carbs, Modifier.weight(1f))
        StatTile(Icons.Rounded.CalendarMonth, "$activeDays", "Tage in 5 Wochen", Palette.accent, Modifier.weight(1f))
        StatTile(Icons.Rounded.AcUnit, "${state.frozen.size}", "Freezes genutzt", Palette.water, Modifier.weight(1f))
    }
}

@Composable
private fun StatTile(icon: androidx.compose.ui.graphics.vector.ImageVector, value: String, label: String, tint: Color, modifier: Modifier) {
    Column(modifier.card(12.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.size(34.dp).clip(CircleShape).background(tint.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(17.dp), tint = tint)
        }
        Text(value, style = font(22, FontWeight.Bold), color = C.textPrimary)
        Text(label, style = font(12), color = C.textSecondary, textAlign = TextAlign.Center, maxLines = 2)
    }
}

/** Badges for streak lengths: reached ones glow in the accent, the next one shows how far you are. */
@Composable
private fun MilestonesCard(state: Streak.State) {
    val reached = maxOf(state.best, state.count)
    val next = milestones.firstOrNull { it > state.count }
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Meilensteine", style = font(17, FontWeight.Bold), color = C.textPrimary)
        // Two rows of four so every badge stays inside the card.
        for (row in milestones.chunked(4)) {
            Row(Modifier.fillMaxWidth()) {
                for (m in row) {
                    val done = reached >= m
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box(Modifier.size(60.dp), contentAlignment = Alignment.Center) {
                            Box(Modifier.size(52.dp).clip(CircleShape)
                                .background(if (done) Brush.verticalGradient(listOf(Palette.carbs, Palette.accent)) else Brush.verticalGradient(listOf(C.cardAlt, C.cardAlt))),
                                contentAlignment = Alignment.Center) {
                                Icon(if (done) Icons.Rounded.LocalFireDepartment else Icons.Rounded.Lock, null,
                                    Modifier.size(if (done) 26.dp else 18.dp), tint = if (done) Color.White else C.textSecondary.copy(alpha = 0.6f))
                            }
                            if (m == next) {
                                val accent = Palette.accent
                                val frac = state.count.toFloat() / m
                                Canvas(Modifier.fillMaxSize()) {
                                    val w = 3.5.dp.toPx()
                                    drawArc(accent, -90f, 360f * frac, false, Offset(w / 2, w / 2),
                                        androidx.compose.ui.geometry.Size(size.width - w, size.height - w), style = Stroke(w, cap = StrokeCap.Round))
                                }
                            }
                        }
                        Text("$m", style = font(14, FontWeight.Bold), color = if (done) C.textPrimary else C.textSecondary)
                    }
                }
            }
        }
        Text(if (next != null) "Noch ${next - state.count} ${if (next - state.count == 1) "Tag" else "Tage"} bis $next in Folge." else "Alle Meilensteine erreicht.",
            style = font(12), color = C.textSecondary)
    }
}

@Composable
private fun FreezeCard(state: Streak.State) {
    Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            for (i in 0 until Streak.MAX_FREEZES) {
                val on = i < state.freezes
                Box(Modifier.size(40.dp).clip(CircleShape).background(if (on) Palette.water.copy(alpha = 0.16f) else C.cardAlt), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.AcUnit, null, Modifier.size(20.dp), tint = if (on) Palette.water else C.textSecondary.copy(alpha = 0.35f))
                }
            }
        }
        Column(Modifier.weight(1f)) {
            Text("Streak-Freeze", style = font(17, FontWeight.Bold), color = C.textPrimary)
            Text(if (state.freezes == 0) "Keiner übrig, der nächste kommt nach 7 Tagen in Folge." else "${state.freezes} von ${Streak.MAX_FREEZES} bereit",
                style = font(12), color = C.textSecondary)
        }
    }
}

/** Last five weeks as a chain: neighbouring logged days are joined, so a streak reads as one run. */
@Composable
private fun StreakCalendar(state: Streak.State, logged: Set<LocalDate>, gridStart: LocalDate) {
    val today = LocalDate.now()
    fun counts(d: LocalDate) = d in logged || d in state.frozen
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.fillMaxWidth()) {
            for (d in listOf("Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"))
                Text(d, style = font(12), color = C.textSecondary, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
        }
        for (w in 0 until 5) {
            Row(Modifier.fillMaxWidth()) {
                for (i in 0 until 7) {
                    val d = gridStart.plusDays((w * 7 + i).toLong())
                    val on = counts(d)
                    val isLogged = d in logged
                    val frozen = d in state.frozen && !isLogged
                    val tint = if (frozen) Palette.water else Palette.accent
                    Box(Modifier.weight(1f).height(42.dp).graphicsLayer { alpha = if (d.isAfter(today)) 0.3f else 1f }, contentAlignment = Alignment.Center) {
                        Row(Modifier.fillMaxWidth().height(22.dp)) {
                            Box(Modifier.weight(1f).fillMaxSize().background(if (i > 0 && on && counts(d.minusDays(1))) tint.copy(alpha = 0.32f) else Color.Transparent))
                            Box(Modifier.weight(1f).fillMaxSize().background(if (i < 6 && on && counts(d.plusDays(1))) tint.copy(alpha = 0.32f) else Color.Transparent))
                        }
                        Box(
                            Modifier.size(36.dp).clip(CircleShape).background(if (isLogged || frozen) tint else C.cardAlt),
                            contentAlignment = Alignment.Center,
                        ) {
                            when {
                                frozen -> Icon(Icons.Rounded.AcUnit, null, Modifier.size(15.dp), tint = Color.White)
                                isLogged && d == today -> Icon(Icons.Rounded.LocalFireDepartment, null, Modifier.size(17.dp), tint = Color.White)
                                else -> Text("${d.dayOfMonth}", style = font(12, FontWeight.Bold), color = if (isLogged) Color.White else C.textSecondary)
                            }
                        }
                        if (d == today) Box(Modifier.size(42.dp).border(2.dp, C.textPrimary, CircleShape))
                    }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.padding(top = 4.dp)) {
            Legend(Palette.accent, "eingetragen")
            Legend(Palette.water, "Freeze")
        }
    }
}

@Composable
private fun Legend(color: Color, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(12.dp).clip(CircleShape).background(color))
        Spacer(Modifier.width(6.dp))
        Text(text, style = font(12), color = C.textSecondary)
    }
}

// MARK: Shop

/** Streak shop: points buy fur colours, hats, glasses, scarves and an extra freeze. */
@Composable
private fun ShopCard(state: Streak.State) {
    val h = rememberHaptics()
    var earned by remember { mutableStateOf(0) }
    LaunchedEffect(state.best, state.count) { earned = Diag.safe("Punkte berechnen", 0) { Shop.earned(App.goals, maxOf(state.best, state.count)) } }
    var kind by remember { mutableStateOf(ShopItem.Kind.fur) }
    var toast by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(toast) { if (toast != null) { kotlinx.coroutines.delay(1800); toast = null } }
    val owned = Shop.owned
    val balance = Shop.balance(earned)
    val freezes = App.prefs.int("streak.freezes", 1)
    val anyWorn = listOf("shop.hat", "shop.glasses", "shop.scarf").any { App.prefs.string(it, "").isNotEmpty() }
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Shop", style = font(17, FontWeight.Bold), color = C.textPrimary)
            Spacer(Modifier.weight(1f))
            Row(Modifier.clip(CircleShape).background(C.accentSoft).padding(horizontal = 10.dp, vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
                PixelSpriteView(Sprites.paw, 2.dp)
                Spacer(Modifier.width(5.dp))
                Text("$balance", style = font(15, FontWeight.ExtraBold), color = C.textPrimary)
            }
        }
        Text("Punkte gibt es für jeden eingetragenen Tag (10), für Tage nahe am Ziel (+5) und für Meilensteine.", style = font(12), color = C.textSecondary)
        Row(Modifier.fillMaxWidth().clip(CircleShape).background(C.cardAlt).padding(3.dp)) {
            for (k in ShopItem.Kind.entries) {
                val on = kind == k
                Box(Modifier.weight(1f).height(34.dp).clip(CircleShape).background(if (on) Palette.accent else Color.Transparent).clickable { h.tap(); kind = k },
                    contentAlignment = Alignment.Center) {
                    Text(k.title, style = font(12, FontWeight.SemiBold), color = if (on) Color.White else C.textSecondary, maxLines = 1)
                }
            }
        }
        Shop.items.filter { it.kind == kind }.chunked(3).forEach { rowItems ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (item in rowItems) {
                    val has = item.id in owned
                    val worn = Shop.isWorn(item)
                    val affordable = balance >= item.price
                    val freezeFull = item.kind == ShopItem.Kind.extra && freezes >= Streak.MAX_FREEZES
                    var outfit = Outfit.None
                    var palette: CatPalette? = null
                    when (item.kind) {
                        ShopItem.Kind.fur -> palette = CatPalette.byId(item.id)
                        ShopItem.Kind.hat -> outfit = Outfit(hat = item.id)
                        ShopItem.Kind.glasses -> outfit = Outfit(glasses = item.id)
                        ShopItem.Kind.scarf -> outfit = Outfit(scarf = item.id)
                        ShopItem.Kind.extra -> {}
                    }
                    Column(Modifier.weight(1f).clip(RoundedCornerShape(RadiusSmall)).background(if (worn) C.accentSoft else C.cardAlt)
                        .then(if (worn) Modifier.border(2.dp, Palette.accent, RoundedCornerShape(RadiusSmall)) else Modifier)
                        .squishClick {
                            when {
                                has -> { Shop.equip(item); h.tap() }
                                freezeFull -> toast = "Du hast schon alle Freezes."
                                Shop.buy(item, balance) -> { h.success(); toast = if (item.kind == ShopItem.Kind.extra) "Freeze gekauft" else "${item.name} gekauft" }
                                else -> { h.warning(); toast = "Dir fehlen ${item.price - balance} Punkte." }
                            }
                        }.padding(vertical = 10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box(Modifier.height(58.dp), contentAlignment = Alignment.Center) {
                            if (item.kind == ShopItem.Kind.extra) Icon(Icons.Rounded.AcUnit, null, Modifier.size(30.dp), tint = Palette.water)
                            else PixelSpriteView(Sprites.sit, 3.4.dp, palette ?: CatPalette.byId(App.prefs.string("catPalette", "ginger")), outfit = outfit)
                        }
                        Text(item.name, style = font(12, FontWeight.Bold), color = C.textPrimary, maxLines = 1)
                        Text(if (worn) "Getragen" else if (has) "Anziehen" else "${item.price}", style = font(12, FontWeight.ExtraBold),
                            color = if (worn) Palette.accentText else if (has || (affordable && !freezeFull)) C.textPrimary else C.textSecondary.copy(alpha = 0.7f))
                    }
                }
                repeat(3 - rowItems.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        if (anyWorn) Text("Alles ausziehen", style = font(14, FontWeight.SemiBold), color = Palette.accentText, modifier = Modifier.clickable { Shop.takeOffAll(); h.tap() })
        toast?.let { Text(it, style = font(13, FontWeight.Bold), color = Palette.accentText) }
    }
}
