package de.purrtion.app.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.CameraAlt
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.QrCodeScanner
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Restaurant
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Undo
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.MainActivity
import de.purrtion.app.data.CustomFood
import de.purrtion.app.data.DayReview
import de.purrtion.app.data.FoodEntry
import de.purrtion.app.data.Store
import de.purrtion.app.data.UndoStore
import de.purrtion.app.domain.Streak
import de.purrtion.app.data.WaterLog
import de.purrtion.app.domain.BloodAlcohol
import de.purrtion.app.domain.DayCloser
import de.purrtion.app.domain.DayTarget
import de.purrtion.app.domain.HealthScore
import de.purrtion.app.domain.catMood
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.RecipeIngredient
import de.purrtion.app.model.clean
import de.purrtion.app.model.dayMonth
import de.purrtion.app.model.dayMonthYear
import de.purrtion.app.model.format
import de.purrtion.app.model.kcalString
import de.purrtion.app.model.weekdayName
import de.purrtion.app.ui.AIBadge
import de.purrtion.app.ui.Bar
import de.purrtion.app.ui.CalorieRing
import de.purrtion.app.ui.CheckCircle
import de.purrtion.app.ui.MacroDot
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.card
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.pixel.AnimatedSprite
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.pixel.HeartBurst
import de.purrtion.app.ui.pixel.PixelSpriteView
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.ui.pixel.WalkingCatLoader
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.RadiusSmall
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import kotlin.math.abs
import kotlin.math.min
import de.purrtion.app.domain.Diag
import kotlinx.coroutines.flow.catch

@Composable
fun TodayScreen(activity: MainActivity) {
    var day by remember { mutableStateOf(LocalDate.now()) }
    var anchor by remember { mutableStateOf(LocalDate.now()) }
    var selection by remember { mutableStateOf<Set<String>?>(null) }
    var askRecipe by remember { mutableStateOf<Boolean?>(null) }   // true = from selection
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    // Which week the strip shows (0 = this week). Kept here because the day list below is rebuilt for every day.
    val weekPager = androidx.compose.foundation.pager.rememberPagerState(initialPage = weekPage(0)) { 104 }
    var streak by remember { mutableStateOf(Streak.State()) }
    var pop by remember { mutableIntStateOf(0) }
    var streakLoaded by remember { mutableStateOf(false) }
    val todayEntries by remember { App.db.entries().observeDay(LocalDate.now().toEpochDay()).catch { Diag.warn("Einträge von heute", it); emit(emptyList()) } }.collectAsState(emptyList())
    // Streak: refresh when today's entries change; the first entry of the day lights the flame (and hops the chip).
    LaunchedEffect(todayEntries.size, day) {
        val new = Diag.safe("Serie berechnen", streak) { Streak.refresh() }
        if (streakLoaded && new.loggedToday && !streak.loggedToday && day == LocalDate.now()) { pop++; h.tap() }
        streak = new
        streakLoaded = true
    }
    // Another way of changing the day (calendar, swipe, "Zu Heute"): bring that week into view.
    LaunchedEffect(day) {
        val page = weekPage(weekOffset(day))
        if (weekPager.currentPage != page) weekPager.animateScrollToPage(page)
    }

    // Midnight: "Heute" moves on to the new day (unless another day is looked at on purpose).
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            val now = LocalDate.now()
            if (now != anchor) { if (day == anchor) day = now; anchor = now }
        }
    }
    // Notification tap: open that day's verdict.
    LaunchedEffect(activity.reviewDay) {
        val d = activity.reviewDay ?: return@LaunchedEffect
        activity.reviewDay = null
        day = LocalDate.ofEpochDay(d)
        delay(450)
        App.db.reviews().day(d)?.let { r -> Nav.sheet { DayReviewSheet(r) } }
    }

    Box(Modifier.fillMaxSize().background(C.background)) {
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        DayHeader(day, streak, pop,
            onCalendar = { Nav.sheet { CalendarSheet("Tag wählen") { day = it; selection = null } } },
            onToday = { h.tap(); day = LocalDate.now(); selection = null },
            onStreak = { Nav.sheet { StreakSheet() } })
        Box(Modifier.weight(1f).pointerInput(selection) {
            var total = 0f
            detectHorizontalDragGestures(onDragStart = { total = 0f }, onDragEnd = {
                if (selection == null && abs(total) > 120) {
                    val next = day.plusDays(if (total < 0) 1 else -1)
                    if (!next.isAfter(LocalDate.now())) { h.tap(); day = next }
                }
            }) { _, d -> total += d }
        }) {
            AnimatedContent(day, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "day") { d ->
                DayContent(d, selection, { selection = it }, onSaveRecipe = { askRecipe = it }, weekPager = weekPager,
                    onSelectDay = { h.tap(); day = it; selection = null })
            }
        }
    }
    // The bars float over the list: no hard band, the content just fades out behind them.
    // One continuous fade from above the add pill down behind the tab bar (the root screen skips its own fade on this tab).
    Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(de.purrtion.app.ui.bottomFade()).padding(top = 110.dp)) {
        Column(Modifier.fillMaxWidth()) {
        if (selection != null) {
            SelectionBar(selection!!.size,
                onDelete = { scope.launch { h.warning(); Store.deleteIds(selection!!, day); selection = null } },
                onCopy = {
                    val ids = selection!!
                    Nav.sheet { CalendarSheet("Kopieren nach …", allowFuture = true) { target ->
                        scope.launch {
                            Store.copy(App.db.entries().day(day.toEpochDay()).filter { it.id in ids }, target)
                            selection = null
                        }
                    } }
                },
                onRecipe = { askRecipe = true },
                onDone = { selection = null })
        } else {
            QuickAddBar(day)
        }
        }
        // Room for the floating tab bar.
        Spacer(Modifier.navigationBarsPadding().height(80.dp))
    }
    }

    askRecipe?.let { fromSelection ->
        var name by remember { mutableStateOf(if (fromSelection) "Meine Mahlzeit" else "Mahlzeit ${day.dayMonth()}") }
        AlertDialog(
            onDismissRequest = { askRecipe = null },
            title = { Text("Als Rezept speichern") },
            text = {
                Column {
                    Text(if (fromSelection) "Die ausgewählten Einträge werden zu einem Rezept." else "Alle Einträge dieses Tages werden zu einem Rezept.", style = font(14))
                    Spacer(Modifier.height(12.dp))
                    de.purrtion.app.ui.TextInput(name, { name = it }, "Name", Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(C.cardAlt).padding(12.dp))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    val ids = selection
                    askRecipe = null
                    scope.launch {
                        val entries = App.db.entries().day(day.toEpochDay()).filter { ids == null || !fromSelection || it.id in ids }
                        val ingredients = entries.mapNotNull { e -> e.food?.let { RecipeIngredient(food = it, quantity = e.quantity, serving = e.serving) } }
                        if (ingredients.isNotEmpty()) {
                            App.db.custom().upsert(CustomFood.recipe(name.trim().ifEmpty { "Meine Mahlzeit" }, ingredients, 1))
                            h.success()
                        }
                        selection = null
                    }
                }) { Text("Speichern", color = Palette.accentText) }
            },
            dismissButton = { TextButton(onClick = { askRecipe = null }) { Text("Abbrechen", color = Palette.accentText) } },
        )
    }
}

// MARK: Header

/** Title row: day, "Zu Heute", streak and calendar. The week strip lives in the list so it scrolls away. */
@Composable
private fun DayHeader(day: LocalDate, streak: Streak.State, pop: Int, onCalendar: () -> Unit, onToday: () -> Unit, onStreak: () -> Unit) {
    val today = LocalDate.now()
    val isToday = day == today
    val title = when (day) {
        today -> "Heute"
        today.minusDays(1) -> "Gestern"
        else -> day.weekdayName()
    }
    val name = App.prefs.string("profile.name", "").trim()
    val subtitle = when {
        !isToday -> "Rückblick · ${day.dayMonth()}"
        name.isEmpty() -> day.dayMonthYear()
        else -> {
            val hour = java.time.LocalTime.now().hour
            val greeting = if (hour < 5) "Gute Nacht" else if (hour < 11) "Guten Morgen" else if (hour < 17) "Hallo" else if (hour < 22) "Guten Abend" else "Gute Nacht"
            "$greeting, $name · ${day.dayMonth()}"
        }
    }
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = font(22, FontWeight.Bold), color = C.textPrimary)
            Text(subtitle, style = font(13), color = C.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        AnimatedVisibility(!isToday) {
            Row(Modifier.padding(end = 8.dp).height(34.dp).clip(CircleShape).background(C.accentSoft).squishClick(onClick = onToday).padding(horizontal = 10.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Undo, null, Modifier.size(13.dp), tint = Palette.accentText)
                Spacer(Modifier.width(4.dp))
                Text("Zu Heute", style = font(12, FontWeight.Bold), color = Palette.accentText)
            }
        }
        StreakChip(streak, pop, onStreak)
        Spacer(Modifier.width(8.dp))
        de.purrtion.app.ui.RoundIconButton(Icons.Rounded.CalendarMonth, description = "Kalender", onClick = onCalendar)
    }
}

// MARK: Day content

@Composable
private fun DayContent(day: LocalDate, selection: Set<String>?, setSelection: (Set<String>?) -> Unit, onSaveRecipe: (Boolean) -> Unit,
                       weekPager: androidx.compose.foundation.pager.PagerState, onSelectDay: (LocalDate) -> Unit) {
    val goals = App.goals
    val entries by remember(day) { App.db.entries().observeDay(day.toEpochDay()) }.collectAsState(emptyList())
    val water by remember(day) { App.db.water().observeDay(day.toEpochDay()) }.collectAsState(emptyList())
    // The day before: last night's drinks may still be in the blood (cat mood).
    val previous by remember(day) { App.db.entries().observeDay(day.minusDays(1).toEpochDay()) }.collectAsState(emptyList())
    val review by remember(day) { App.db.reviews().observeDay(day.toEpochDay()) }.collectAsState(null)
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    var expanded by remember(day) { mutableStateOf(setOf<String>()) }
    var justAte by remember { mutableStateOf(false) }
    var burst by remember { mutableIntStateOf(0) }
    var lastCount by remember(day) { mutableIntStateOf(-1) }
    var closing by remember { mutableStateOf(false) }
    var closeError by remember { mutableStateOf<String?>(null) }

    val total = Nutrients.sum(entries.map { it.nutrients })
    val target = goals.target(day)
    val selecting = selection != null

    LaunchedEffect(entries.size) {
        if (lastCount >= 0 && entries.size > lastCount) {
            h.success(); burst++; justAte = true; delay(2200); justAte = false
        }
        lastCount = entries.size
    }

    val mood = if (justAte) CatMood.eating else {
        val promille = if (day == LocalDate.now()) BloodAlcohol.make(entries + previous, goals, null).value(System.currentTimeMillis()) else 0.0
        catMood(entries, target, water.sumOf { it.ml }, goals, day, promille)
    }
    val outdated = review?.let { it.signature != DayReview.signature(entries) } ?: false

    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item(key = "week") { WeekStrip(day, weekPager, onSelectDay) }
        // One card: calories on top, macros below (like on iOS).
        item(key = "summary") {
            Column(Modifier.fillMaxWidth().card(18.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                SummaryCard(total, mood, burst, target, Modifier.squishClick { Nav.sheet { DayOverviewSheet(day) } })
                HorizontalDivider(color = C.line)
                MacroCard(total, target, Modifier.squishClick { Nav.sheet { NutrientsDaySheet(total, "Nährstoffe") } })
            }
        }
        if (goals.healthScoreEnabled && entries.isNotEmpty()) {
            item(key = "score") {
                val score = HealthScore.of(entries, target.kcal, target.protein)
                val baseline = aiBaseline(entries, score, target)
                HealthScoreCard(score, baseline, Modifier.squishClick { Nav.sheet { HealthScoreSheet(score, baseline) } })
            }
        }
        val r = review
        if (r != null && entries.isNotEmpty()) {
            item(key = "review") { DayReviewCard(r, outdated, Modifier.squishClick { Nav.sheet { DayReviewSheet(r) } }) }
        }
        if (goals.waterEnabled) {
            item(key = "water") { WaterCard(day, water) }
        }
        item(key = "header") {
            Row(Modifier.fillMaxWidth().padding(top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Gegessen", style = font(18, FontWeight.Bold), color = C.textPrimary)
                if (entries.isNotEmpty()) {
                    Spacer(Modifier.width(8.dp))
                    Text("${entries.size}", style = font(12, FontWeight.Bold), color = C.textSecondary,
                        modifier = Modifier.clip(CircleShape).background(C.cardAlt).padding(horizontal = 7.dp, vertical = 2.dp))
                }
                Spacer(Modifier.weight(1f))
                if (selecting) {
                    val all = entries.isNotEmpty() && selection?.size == entries.size
                    Text(if (all) "Keine" else "Alle", style = font(14, FontWeight.SemiBold), color = Palette.accentText,
                        modifier = Modifier.clickable { h.tap(); setSelection(if (all) emptySet() else entries.map { it.id }.toSet()) })
                } else {
                    UndoButton()
                    OptionsMenu(day, entries, total, setSelection, onSaveRecipe)
                }
            }
        }
        if (entries.isEmpty()) {
            item(key = "empty") { EmptyDay() }
        } else {
            for (entry in entries) {
                item(key = entry.id) {
                    val isExpanded = entry.isComposite && entry.id in expanded && !selecting
                    Column(Modifier.animateItem()) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            AnimatedVisibility(selecting) {
                                CheckCircle(selection?.contains(entry.id) == true, Modifier.padding(end = 10.dp).clickable {
                                    h.tap()
                                    val s = selection ?: emptySet()
                                    setSelection(if (entry.id in s) s - entry.id else s + entry.id)
                                })
                            }
                            SwipeRow(
                                enabled = !selecting,
                                onDelete = { scope.launch { h.warning(); Store.delete(entry) } },
                                onDuplicate = { scope.launch { h.tap(); Store.duplicate(entry, day) } },
                                modifier = Modifier.weight(1f),
                            ) {
                                EntryRow(entry, expanded = if (entry.isComposite && !selecting) isExpanded else null,
                                    onToggle = { h.tap(); expanded = if (entry.id in expanded) expanded - entry.id else expanded + entry.id },
                                    onClick = {
                                        if (selecting) {
                                            h.tap()
                                            val s = selection ?: emptySet()
                                            setSelection(if (entry.id in s) s - entry.id else s + entry.id)
                                        } else if (entry.isComposite) Nav.sheet { MealEntrySheet(entry.id) }
                                        else Nav.sheet { EditEntrySheet(entry.id) }
                                    },
                                    onLongClick = { if (!selecting) { h.tap(); setSelection(setOf(entry.id)) } })
                            }
                        }
                        AnimatedVisibility(isExpanded, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
                            Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                val ings = entry.ingredients
                                ings.forEachIndexed { i, ing ->
                                    Row(Modifier.height(androidx.compose.foundation.layout.IntrinsicSize.Min)) {
                                        IngredientRail(isLast = i == ings.size - 1)
                                        SwipeRow(enabled = true,
                                            onDelete = { scope.launch {
                                                h.warning()
                                                val updated = entry.removingIngredient(ing.id)
                                                if (updated == null) Store.delete(entry) else { UndoStore.recordIngredientRemoval(entry); Store.update(updated) }
                                            } },
                                            onDuplicate = { scope.launch { h.tap(); Store.update(entry.duplicatingIngredient(ing.id)) } },
                                            modifier = Modifier.weight(1f)) {
                                            IngredientRow(ing, compact = true, onClick = { Nav.sheet { IngredientEditSheet(entry.id, ing.id) } })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if (!selecting) {
                item(key = "close") {
                    DayCloseRow(hasReview = review != null, outdated = outdated, running = closing) {
                        h.tap()
                        closing = true
                        scope.launch {
                            try { DayCloser.close(day, goals); h.success() } catch (e: Exception) { closeError = e.message }
                            closing = false
                        }
                    }
                }
            }
        }
        // Room to scroll the last entry above the floating bars.
        item(key = "bottom") { Spacer(Modifier.height(190.dp)) }
    }

    closeError?.let {
        AlertDialog(onDismissRequest = { closeError = null }, confirmButton = { TextButton({ closeError = null }) { Text("OK", color = Palette.accentText) } },
            title = { Text("Tag abschließen fehlgeschlagen") }, text = { Text(it) })
    }
}

/** Score without AI-added micronutrients – null when the AI did not change anything. */
private fun aiBaseline(entries: List<FoodEntry>, score: HealthScore, target: DayTarget): HealthScore? {
    val anyAI = entries.any { e ->
        if (e.isComposite) e.ingredients.any { !it.food.aiNutrientKeys.isNullOrEmpty() } else !e.food?.aiNutrientKeys.isNullOrEmpty()
    }
    if (!anyAI) return null
    val before = HealthScore.of(entries, target.kcal, target.protein, withoutAI = true)
    return if (before.score == score.score) null else before
}

@Composable
private fun OptionsMenu(day: LocalDate, entries: List<FoodEntry>, total: Nutrients, setSelection: (Set<String>?) -> Unit, onSaveRecipe: (Boolean) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    Box {
        de.purrtion.app.ui.RoundIconButton(Icons.Rounded.MoreHoriz, description = "Optionen") { open = true }
        DropdownMenu(open, { open = false }, containerColor = C.card) {
            DropdownMenuItem({ Text("Was passt noch?") }, { open = false; Nav.sheet { SuggestionsSheet(day) } }, leadingIcon = { Icon(Icons.Rounded.AutoAwesome, null) })
            HorizontalDivider(color = C.line)
            DropdownMenuItem({ Text("Von gestern …") }, { open = false; Nav.sheet { CopyPickerSheet(day.minusDays(1), day) } }, leadingIcon = { Icon(Icons.Rounded.Undo, null) })
            DropdownMenuItem({ Text("Von anderem Tag …") }, {
                open = false
                Nav.sheet { CalendarSheet("Übernehmen von …") { picked -> Nav.sheet { CopyPickerSheet(picked, day) } } }
            }, leadingIcon = { Icon(Icons.Rounded.CalendarMonth, null) })
            if (entries.isNotEmpty()) {
                HorizontalDivider(color = C.line)
                DropdownMenuItem({ Text("Auswählen …") }, { open = false; setSelection(emptySet()) }, leadingIcon = { Icon(Icons.Rounded.CheckCircle, null) })
                DropdownMenuItem({ Text("Tag als Rezept speichern") }, { open = false; onSaveRecipe(false) }, leadingIcon = { Icon(Icons.Rounded.Restaurant, null) })
                DropdownMenuItem({ Text("Alle zu Favoriten") }, {
                    open = false
                    scope.launch {
                        for (e in entries) { val f = e.food ?: continue; Store.remember(f, e.quantity, e.serving); Store.setFavorite(f, true) }
                        h.success()
                    }
                }, leadingIcon = { Icon(Icons.Rounded.Star, null) })
                DropdownMenuItem({ Text("Nährstoffe des Tages") }, { open = false; Nav.sheet { NutrientsDaySheet(total, "Nährstoffe") } },
                    leadingIcon = { Icon(Icons.Rounded.Verified, null) })
            }
        }
    }
}

@Composable
private fun EmptyDay() {
    Column(Modifier.fillMaxWidth().padding(vertical = 28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        AnimatedSprite(listOf(Sprites.bowl), pixel = 4.dp)
        Spacer(Modifier.height(10.dp))
        Text("Der Napf ist noch leer", style = font(16, FontWeight.SemiBold), color = C.textPrimary)
        Text("Tippe unten auf eine Option, um dein erstes Essen einzutragen.", style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
    }
}

// MARK: Swipe row (left: Nochmal, right: Löschen)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SwipeRow(enabled: Boolean, onDelete: (() -> Unit)?, onDuplicate: () -> Unit, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val state = rememberSwipeToDismissBoxState(confirmValueChange = { v ->
        when (v) {
            SwipeToDismissBoxValue.EndToStart -> { onDelete?.invoke(); onDelete != null }
            SwipeToDismissBoxValue.StartToEnd -> { onDuplicate(); false }
            else -> false
        }
    }, positionalThreshold = { it * 0.35f })
    SwipeToDismissBox(state = state, modifier = modifier, enableDismissFromStartToEnd = enabled, enableDismissFromEndToStart = enabled && onDelete != null, backgroundContent = {
        val toStart = state.dismissDirection == SwipeToDismissBoxValue.EndToStart
        Box(Modifier.fillMaxSize().clip(RoundedCornerShape(RadiusSmall + 4.dp)).background(if (toStart) Palette.danger else Palette.accent).padding(horizontal = 20.dp),
            contentAlignment = if (toStart) Alignment.CenterEnd else Alignment.CenterStart) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(if (toStart) Icons.Rounded.Delete else Icons.Rounded.ContentCopy, null, tint = Color.White)
                Spacer(Modifier.width(6.dp))
                Text(if (toStart) "Löschen" else "Nochmal", color = Color.White, style = font(14, FontWeight.Bold))
            }
        }
    }) { content() }
}

// MARK: Cards

@Composable
fun SummaryCard(total: Nutrients, mood: CatMood, burst: Int, target: DayTarget, modifier: Modifier = Modifier) {
    val goals = App.goals
    val remaining = target.kcal - total.kcal
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(136.dp), contentAlignment = Alignment.Center) {
            CalorieRing(total.kcal / maxOf(target.kcal, 1.0), 14.dp, Modifier.fillMaxSize())
            CatMascot(mood, 4.2.dp, modifier = Modifier.offset(y = if (mood == CatMood.sleeping) 4.dp else 2.dp))
            HeartBurst(burst)
        }
        Spacer(Modifier.width(18.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Column {
                Text(if (remaining >= 0) "Übrig" else "Drüber", style = font(14, FontWeight.Medium), color = C.textSecondary)
                Text(abs(remaining).kcalString, style = font(38, FontWeight.ExtraBold), color = if (remaining >= 0) C.textPrimary else Palette.danger)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("kcal", style = font(13, FontWeight.SemiBold), color = C.textSecondary)
                    if (target.activityBonus > 0) {
                        Spacer(Modifier.width(6.dp))
                        Row(Modifier.clip(CircleShape).background(C.accentSoft).padding(horizontal = 7.dp, vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Rounded.LocalFireDepartment, null, Modifier.size(10.dp), tint = Palette.accentText)
                            Spacer(Modifier.width(3.dp))
                            Text("+${target.activityBonus.kcalString} durch Aktivität", style = font(11, FontWeight.Bold), color = Palette.accentText, maxLines = 1)
                        }
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Stat("Gegessen", total.kcal.kcalString)
                Stat("Ziel", target.kcal.kcalString)
                if (goals.activityEnabled || target.manualKcal > 0) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Rounded.LocalFireDepartment, null, Modifier.size(12.dp), tint = Palette.accentText)
                            Text(target.activeKcal.kcalString, style = font(16, FontWeight.Bold), color = C.textPrimary)
                        }
                        Row {
                            Text("Aktiv", style = font(12), color = C.textSecondary)
                            if (target.activityPercent > 0 && target.activeKcal > 0) {
                                Spacer(Modifier.width(3.dp))
                                Text("${target.activityPercent.toInt()} %", style = font(11, FontWeight.Bold), color = Palette.accentText)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Stat(title: String, value: String) {
    Column {
        Text(value, style = font(16, FontWeight.Bold), color = C.textPrimary, maxLines = 1)
        Text(title, style = font(12), color = C.textSecondary, maxLines = 1)
    }
}

@Composable
fun MacroCard(total: Nutrients, target: DayTarget, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        MacroBar("Protein", total.protein, target.protein, Palette.protein, Modifier.weight(1f))
        MacroBar("Kohlenh.", total.carbs, target.carbs, Palette.carbs, Modifier.weight(1f))
        MacroBar("Fett", total.fat, target.fat, Palette.fat, Modifier.weight(1f))
    }
}

@Composable
private fun MacroBar(name: String, value: Double, goal: Double, color: Color, modifier: Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(name, style = font(13, FontWeight.SemiBold), color = C.textSecondary)
        Bar(value / maxOf(goal, 1.0), color, height = 8.dp, minWidth = 8.dp)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(Math.round(value).toDouble().clean, style = font(16, FontWeight.Bold), color = C.textPrimary)
            Text(" / ${goal.clean} g", style = font(12), color = C.textSecondary)
        }
    }
}

@Composable
private fun WaterCard(day: LocalDate, logs: List<WaterLog>) {
    val goals = App.goals
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val ml = logs.sumOf { it.ml }
    val step = maxOf(goals.waterStep, 1)
    val glasses = maxOf(1, goals.waterML / step)
    val filled = ml / step
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row {
            Text("Wasser", style = font(15, FontWeight.Bold), color = C.textPrimary, modifier = Modifier.weight(1f))
            Text("${(ml / 1000.0).format(2)} / ${(goals.waterML / 1000.0).format(1)} l", style = font(14, FontWeight.SemiBold), color = Palette.water)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (i in 0 until min(glasses, 12)) {
                val full = i < filled
                val s by animateFloatAsState(if (full) 1f else 0.92f, label = "glass")
                Box(Modifier.squishClick {
                    h.tap()
                    scope.launch { Store.addWater(day, if (full) -step else step) }
                }) {
                    PixelSpriteView(if (full) Sprites.glassFull else Sprites.glassEmpty, (3.4f * s).dp)
                }
            }
        }
    }
}

@Composable
fun EntryRow(entry: FoodEntry, expanded: Boolean?, onToggle: () -> Unit, onClick: () -> Unit, onLongClick: () -> Unit = {}) {
    @OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(RadiusSmall + 4.dp)).background(C.card)
        .combinedClickable(onLongClick = onLongClick, onClick = onClick).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(entry.name, style = font(16, FontWeight.SemiBold), color = C.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false))
                if (entry.food?.source == FoodSource.ai) { Spacer(Modifier.width(6.dp)); AIBadge() }
            }
            val sub = listOfNotNull(entry.brand?.takeIf { it.isNotEmpty() }, entry.amountText).joinToString(" · ")
            Text(sub, style = font(13), color = C.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MacroDot(Palette.protein, entry.protein); MacroDot(Palette.carbs, entry.carbs); MacroDot(Palette.fat, entry.fat)
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(entry.kcal.kcalString, style = font(18, FontWeight.Bold), color = C.textPrimary)
            Text("kcal", style = font(11, FontWeight.Medium), color = C.textSecondary)
        }
        if (expanded != null) {
            val rot by animateFloatAsState(if (expanded) 180f else 0f, label = "chevron")
            Spacer(Modifier.width(8.dp))
            Box(Modifier.size(30.dp).clip(CircleShape).background(if (expanded) Palette.accent else C.accentSoft).clickable(onClick = onToggle),
                contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.KeyboardArrowDown, if (expanded) "Zutaten einklappen" else "Zutaten ausklappen",
                    Modifier.rotate(rot), tint = if (expanded) Color.White else Palette.accent)
            }
        }
    }
}

@Composable
fun IngredientRow(ingredient: RecipeIngredient, compact: Boolean = false, onClick: () -> Unit) {
    val n = ingredient.nutrients
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(RadiusSmall + 4.dp)).background(C.card).clickable(onClick = onClick)
        .padding(if (compact) 12.dp else 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(if (compact) 2.dp else 3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(ingredient.food.displayName, style = font(if (compact) 15 else 16, FontWeight.SemiBold), color = C.textPrimary, maxLines = 1,
                    overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                if (ingredient.food.source == FoodSource.ai) { Spacer(Modifier.width(5.dp)); Icon(Icons.Rounded.AutoAwesome, null, Modifier.size(11.dp), tint = Palette.accentText) }
            }
            Text(ingredient.amountText, style = font(if (compact) 12 else 13), color = C.textSecondary, maxLines = 1)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MacroDot(Palette.protein, n.protein); MacroDot(Palette.carbs, n.carbs); MacroDot(Palette.fat, n.fat) }
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(n.kcal.kcalString, style = font(if (compact) 16 else 18, FontWeight.Bold), color = C.textPrimary)
            Text("kcal", style = font(11, FontWeight.Medium), color = C.textSecondary)
        }
    }
}

/** Accent line + branch connecting nested ingredient rows to their meal above. */
@Composable
private fun IngredientRail(isLast: Boolean) {
    val color = C.rail
    Canvas(Modifier.width(24.dp).fillMaxHeight()) {
        val x = 10.dp.toPx()
        val w = 2.5.dp.toPx()
        val mid = size.height / 2
        val path = Path().apply {
            moveTo(x, -8.dp.toPx())
            if (isLast) {
                lineTo(x, mid - 8.dp.toPx())
                quadraticTo(x, mid, x + 8.dp.toPx(), mid)
            } else {
                lineTo(x, size.height + 8.dp.toPx())
                moveTo(x, mid)
            }
            lineTo(22.dp.toPx(), mid)
        }
        drawPath(path, color, style = Stroke(w, cap = StrokeCap.Round))
    }
}


@Composable
fun HealthScoreCard(score: HealthScore, baseline: HealthScore?, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth().card(14.dp), verticalAlignment = Alignment.CenterVertically) {
        de.purrtion.app.ui.ScoreRing(score.score / 100.0, scoreColor(score), 6.dp, Modifier.size(54.dp), baseline?.let { it.score / 100.0 }) {
            Text("${score.score}", style = font(18, FontWeight.ExtraBold), color = C.textPrimary)
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Health Score", style = font(15, FontWeight.Bold), color = C.textPrimary)
                Spacer(Modifier.width(6.dp))
                val c = if (score.isPreliminary) C.textSecondary else scoreColor(score)
                Text(if (score.isPreliminary) "vorläufig" else score.rating, style = font(11, FontWeight.Bold), color = c,
                    modifier = Modifier.clip(CircleShape).background(c.copy(alpha = 0.15f)).padding(horizontal = 7.dp, vertical = 2.dp))
                if (baseline != null) { Spacer(Modifier.width(6.dp)); AIDeltaBadge(score.score - baseline.score) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                for (c in score.components) Bar(c.ratio, scoreColor(score), Modifier.weight(1f), height = 5.dp, minWidth = 0.dp)
            }
            Text(score.components.firstNotNullOfOrNull { it.tip } ?: "Super ausgewogen heute. Weiter so!", style = font(12), color = C.textSecondary,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = C.textSecondary)
    }
}

fun scoreColor(score: HealthScore): Color = when {
    score.score >= 80 -> Palette.fiber
    score.score >= 60 -> Palette.carbs
    else -> Palette.accent
}

@Composable
fun AIDeltaBadge(delta: Int) {
    Row(Modifier.clip(CircleShape).background(C.accentSoft).padding(horizontal = 6.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Rounded.AutoAwesome, null, Modifier.size(8.dp), tint = Palette.accentText)
        Spacer(Modifier.width(2.dp))
        Text("${if (delta >= 0) "+" else "−"}${abs(delta)} KI", style = font(10, FontWeight.Bold), color = Palette.accentText)
    }
}

@Composable
private fun DayReviewCard(review: DayReview, outdated: Boolean, modifier: Modifier) {
    val color = reviewColor(review)
    Row(modifier.fillMaxWidth().card(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(46.dp).clip(CircleShape).background(color.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.AutoAwesome, null, tint = color)
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Tagesfazit", style = font(13, FontWeight.SemiBold), color = C.textSecondary)
                if (outdated) {
                    Spacer(Modifier.width(6.dp))
                    Text("veraltet", style = font(10, FontWeight.Bold), color = C.textSecondary,
                        modifier = Modifier.clip(CircleShape).background(C.cardAlt).padding(horizontal = 6.dp, vertical = 2.dp))
                }
            }
            Text(review.rating, style = font(20, FontWeight.ExtraBold), color = color, maxLines = 1)
            review.points.firstOrNull()?.let { Text(it, style = font(12), color = C.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        }
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = C.textSecondary)
    }
}

fun reviewColor(r: DayReview): Color = when (r.tone) {
    "positiv" -> Palette.fiber
    "kritisch" -> Palette.accent
    else -> Palette.carbs
}

fun reviewMood(r: DayReview): CatMood = when (r.tone) {
    "positiv" -> CatMood.happy
    "kritisch" -> CatMood.full
    else -> CatMood.idle
}

@Composable
private fun DayCloseRow(hasReview: Boolean, outdated: Boolean, running: Boolean, onClick: () -> Unit) {
    when {
        running -> Column(Modifier.fillMaxWidth().padding(vertical = 14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            WalkingCatLoader(2.4.dp, 220.dp, "Rechne den Tag nach …")
            Text("Mikronährstoffe ergänzen und Tag einordnen", style = font(12), color = C.textSecondary)
        }
        hasReview && !outdated -> Row(Modifier.fillMaxWidth().clip(CircleShape).clickable(onClick = onClick).padding(vertical = 10.dp),
            horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Verified, null, Modifier.size(16.dp), tint = C.textSecondary)
            Spacer(Modifier.width(6.dp))
            Text("Tag abgeschlossen · neu bewerten", style = font(13, FontWeight.SemiBold), color = C.textSecondary)
        }
        else -> Row(Modifier.fillMaxWidth().padding(top = 6.dp).clip(RoundedCornerShape(RadiusSmall + 4.dp)).background(C.accentSoft)
            .squishClick(onClick = onClick).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(42.dp).clip(CircleShape).background(Palette.accent), contentAlignment = Alignment.Center) {
                Icon(if (outdated) Icons.Rounded.Refresh else Icons.Rounded.AutoAwesome, null, tint = Color.White)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(if (outdated) "Tag geändert, neu abschließen" else "Tag abschließen", style = font(16, FontWeight.Bold), color = C.textPrimary)
                Text("KI ergänzt fehlende Mikronährstoffe und ordnet deinen Tag ein", style = font(12), color = C.textSecondary)
            }
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Palette.accentText)
        }
    }
}

// MARK: Bottom bars

/** The four ways to log food, always one tap away: one compact pill right above the tab bar (like the iOS accessory). */
@Composable
private fun QuickAddBar(day: LocalDate) {
    val h = rememberHaptics()
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 22.dp).padding(top = 6.dp)
            .shadow(10.dp, CircleShape, clip = false).clip(CircleShape).background(C.card).height(50.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        QuickAction(Icons.Rounded.Search, "Suchen", Modifier.weight(1f)) { h.tap(); Nav.sheet { AddFoodSheet(day) } }
        QuickAction(Icons.Rounded.QrCodeScanner, "Barcode", Modifier.weight(1f)) { h.tap(); Nav.sheet { BarcodeSheet(day) } }
        QuickAction(Icons.Rounded.CameraAlt, "Foto", Modifier.weight(1f)) { h.tap(); Nav.sheet { MealPhotoSheet(day) } }
        QuickAction(Icons.Rounded.Bolt, "Schnell", Modifier.weight(1f)) { h.tap(); Nav.sheet { QuickAddSheet(day) } }
    }
}

@Composable
private fun QuickAction(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, modifier: Modifier, onClick: () -> Unit) {
    Row(modifier.fillMaxHeight().clip(CircleShape).squishClick(onClick = onClick), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, Modifier.size(17.dp), tint = Palette.accent)
        Spacer(Modifier.width(5.dp))
        Text(label, style = font(14, FontWeight.Bold), color = C.textPrimary, maxLines = 1)
    }
}

@Composable
private fun SelectionBar(count: Int, onDelete: () -> Unit, onCopy: () -> Unit, onRecipe: () -> Unit, onDone: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Fertig", style = font(15, FontWeight.Bold), color = C.textPrimary,
            modifier = Modifier.clip(CircleShape).background(C.cardAlt).clickable(onClick = onDone).padding(horizontal = 16.dp, vertical = 15.dp))
        Text("$count ausgewählt", style = font(13, FontWeight.SemiBold), color = C.textSecondary, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
        SelAction(Icons.Rounded.ContentCopy, Palette.accent, count > 0, onCopy)
        SelAction(Icons.Rounded.Restaurant, Palette.fiber, count > 0, onRecipe)
        SelAction(Icons.Rounded.Delete, Palette.danger, count > 0, onDelete)
    }
}

@Composable
private fun SelAction(icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color, enabled: Boolean, onClick: () -> Unit) {
    Box(Modifier.size(50.dp).clip(CircleShape).background(if (enabled) color.copy(alpha = 0.15f) else C.cardAlt).squishClick(enabled, onClick),
        contentAlignment = Alignment.Center) {
        Icon(icon, null, tint = if (enabled) color else C.textSecondary)
    }
}

