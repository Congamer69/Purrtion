package de.purrtion.app.ui.screens

import de.purrtion.app.domain.FirebaseConfig
import de.purrtion.app.domain.ServerAccount
import android.content.Context
import android.content.ClipboardManager
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Group
import androidx.compose.material.icons.rounded.HourglassEmpty
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.LocalDining
import androidx.compose.material.icons.rounded.ManageAccounts
import androidx.compose.material.icons.rounded.MonitorWeight
import androidx.compose.material.icons.rounded.PersonAdd
import androidx.compose.material.icons.rounded.PersonRemove
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material.icons.rounded.HelpOutline
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.domain.FriendMetric
import de.purrtion.app.domain.FriendStats
import de.purrtion.app.domain.FriendsStore
import de.purrtion.app.domain.GoalStatus
import de.purrtion.app.model.format
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.Bar
import de.purrtion.app.ui.Divider
import de.purrtion.app.ui.FormRow
import de.purrtion.app.ui.FormSection
import de.purrtion.app.ui.FormToggle
import de.purrtion.app.ui.GoalLegend
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.TextInput
import de.purrtion.app.ui.card
import de.purrtion.app.ui.goalColor
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.pixel.AnimatedSprite
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.pixel.CatPalette
import de.purrtion.app.ui.pixel.Outfit
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

private fun relative(millis: Long) = de.purrtion.app.model.relativeTime(millis)

/** Friends: leaderboard over many metrics, week comparison, requests and invites. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendsScreen() {
    val store = FriendsStore
    val scope = rememberCoroutineScope()
    var refreshing by remember { mutableStateOf(false) }
    // My own stats are computed locally (never older than the data on this device).
    val myStats by produceState(FriendStats(), store.lastRefresh, store.people) { value = FriendStats.compute(App.goals, false) }
    LaunchedEffect(Unit) { store.refresh() }
    // While a request is open, look again every 30 seconds so an accepted request shows up by itself.
    LaunchedEffect(store.outgoing.size + store.incoming.size) {
        while (store.outgoing.isNotEmpty() || store.incoming.isNotEmpty()) { delay(30_000); store.refresh() }
    }
    store.incomingCode?.let { code -> LaunchedEffect(code) { Nav.sheet { CodeEntrySheet(code) }; store.incomingCode = null } }

    PullToRefreshBox(refreshing, {
        scope.launch { refreshing = true; store.refresh(force = true); refreshing = false }
    }, Modifier.fillMaxSize().background(C.background).statusBarsPadding()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(Modifier.padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Freunde", style = font(34, FontWeight.Bold), color = C.textPrimary, modifier = Modifier.weight(1f))
                if (store.isSetUp) {
                    val context = LocalContext.current
                    var open by remember { mutableStateOf(false) }
                    Box {
                        Box(Modifier.size(40.dp).clip(CircleShape).background(C.card).squishClick { open = true },
                            contentAlignment = Alignment.Center) { Icon(Icons.Rounded.MoreHoriz, "Mehr", tint = Palette.accentText) }
                        androidx.compose.material3.DropdownMenu(open, { open = false }, containerColor = C.card) {
                            androidx.compose.material3.DropdownMenuItem({ Text("Freund hinzufügen") }, { open = false; Nav.sheet { CodeEntrySheet() } },
                                leadingIcon = { Icon(Icons.Rounded.PersonAdd, null) })
                            if (store.inviteLink != null) androidx.compose.material3.DropdownMenuItem({ Text("Einladungslink teilen") }, { open = false; shareInvite(context) },
                                leadingIcon = { Icon(Icons.Rounded.Share, null) })
                            androidx.compose.material3.HorizontalDivider(color = C.line)
                            androidx.compose.material3.DropdownMenuItem({ Text("Freunde verwalten") }, { open = false; Nav.sheet { FriendsManageSheet() } },
                                leadingIcon = { Icon(Icons.Rounded.ManageAccounts, null) })
                        }
                    }
                }
            }
            when {
                !store.isAvailable -> Info("Nicht eingerichtet", "Freunde gibt es in diesem Build nicht.")
                !store.isSetUp -> FriendsSetupCard()
                else -> {
                    MeCard()
                    if (store.incoming.isNotEmpty()) RequestsCard()
                    if (store.outgoing.isNotEmpty()) OutgoingCard()
                    if (store.friends.isEmpty()) Info("Noch keine Freunde", "Teile deinen Einladungslink oder gib den Code eines Freundes ein. Sobald ihr euch gegenseitig hinzugefügt habt, erscheint hier eure Rangliste.")
                    else {
                        TodayCard(myStats)
                        Leaderboard(myStats)
                        WeekCard(myStats)
                    }
                    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        if (store.busy) CircularProgressIndicator(Modifier.size(18.dp), color = Palette.accentText, strokeWidth = 2.dp)
                        store.lastRefresh?.let { Text("Aktualisiert ${relative(it)} · zum Aktualisieren ziehen", style = font(11), color = C.textSecondary) }
                    }
                }
            }
            Spacer(Modifier.navigationBarsPadding().height(88.dp))
        }
    }
    val error = store.error
    if (error != null && Nav.stack.isEmpty()) AlertDialog({ store.error = null }, title = { Text("Fehler") }, text = { Text(error) },
        confirmButton = { TextButton({ store.error = null }) { Text("OK") } })
}

private fun me(stats: FriendStats) = FriendsStore.Person(FriendsStore.uid ?: "me", FriendsStore.name, App.prefs.string("catPalette", "ginger"), stats, System.currentTimeMillis())

@Composable
private fun Info(title: String, text: String) {
    Column(Modifier.fillMaxWidth().card(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        CatMascot(CatMood.idle, 4.dp)
        Text(title, style = font(17, FontWeight.Bold), color = C.textPrimary)
        Text(text, style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
    }
}

/** A person's cat in their colour and today's mood (sleeping when they haven't been active today). */
@Composable
fun PersonCat(person: FriendsStore.Person, pixel: Float = 2.4f) {
    val mood = if (person.stats.isToday) CatMood.entries.firstOrNull { it.key == person.stats.mood } ?: CatMood.idle else CatMood.sleeping
    Box(Modifier.size((21 * pixel).dp, (16 * pixel).dp), contentAlignment = Alignment.Center) {
        AnimatedSprite(mood.frames, mood.fps, pixel.dp, CatPalette.byId(person.palette), outfit = Outfit.parse(person.stats.outfit))
    }
}

@Composable
private fun CardLabel(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, Modifier.size(20.dp), tint = C.textPrimary)
        Spacer(Modifier.width(6.dp))
        Text(text, style = font(17, FontWeight.Bold), color = C.textPrimary)
    }
}

private fun shareInvite(context: android.content.Context) {
    val store = FriendsStore
    val link = store.inviteLink ?: return
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, "Purrtion")
        putExtra(Intent.EXTRA_TEXT, "Lass uns auf Purrtion vergleichen! 🐾 Mein Code: ${store.me?.code ?: ""}\n$link")
    }
    context.startActivity(Intent.createChooser(send, "Einladen"))
}

/** Compact profile strip: who you are, your code (tap to copy) and the invite button. */
@Composable
private fun MeCard() {
    val store = FriendsStore
    val context = LocalContext.current
    val h = rememberHaptics()
    var copied by remember { mutableStateOf(false) }
    LaunchedEffect(copied) { if (copied) { delay(1600); copied = false } }
    Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(64.dp).clip(CircleShape).background(C.accentSoft), contentAlignment = Alignment.Center) { CatMascot(CatMood.happy, 2.4.dp) }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(store.name, style = font(20, FontWeight.Bold), color = C.textPrimary, maxLines = 1)
            Row(Modifier.clip(CircleShape).background(C.accentSoft).squishClick {
                val cm = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                cm.setPrimaryClip(android.content.ClipData.newPlainText("Purrtion-Code", store.me?.code ?: ""))
                h.success(); copied = true
            }.padding(horizontal = 10.dp, vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(store.me?.code ?: "–", style = font(14, FontWeight.Bold).copy(fontFamily = FontFamily.Monospace), color = Palette.accentText)
                Spacer(Modifier.width(6.dp))
                Icon(if (copied) Icons.Rounded.Check else Icons.Rounded.ContentCopy, "Code kopieren", Modifier.size(12.dp), tint = Palette.accentText)
            }
        }
        if (store.inviteLink != null) {
            Box(Modifier.size(46.dp).clip(CircleShape).background(Palette.accent).squishClick { shareInvite(context) }, contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Share, "Einladen", Modifier.size(20.dp), tint = Color.White)
            }
        }
    }
}

@Composable
private fun RequestsCard() {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        CardLabel(Icons.Rounded.HelpOutline, "Anfragen")
        for (p in FriendsStore.incoming) Row(verticalAlignment = Alignment.CenterVertically) {
            PersonCat(p)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(p.name, style = font(16, FontWeight.SemiBold), color = C.textPrimary)
                Text("möchte mit dir vergleichen", style = font(12), color = C.textSecondary)
            }
            Box(Modifier.size(38.dp).clip(CircleShape).background(C.cardAlt).squishClick { h.tap(); scope.launch { FriendsStore.decline(p.id) } },
                contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Close, "Ablehnen", Modifier.size(18.dp), tint = C.textSecondary) }
            Spacer(Modifier.width(8.dp))
            Box(Modifier.size(38.dp).clip(CircleShape).background(Palette.accent).squishClick { h.success(); scope.launch { FriendsStore.accept(p.id) } },
                contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Check, "Annehmen", Modifier.size(18.dp), tint = Color.White) }
        }
    }
}

@Composable
private fun OutgoingCard() {
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Gesendet", style = font(15, FontWeight.Bold), color = C.textSecondary)
        Text("Sobald die Anfrage angenommen ist, erscheint ihr hier automatisch in der Rangliste.", style = font(12), color = C.textSecondary)
        for ((id, label) in FriendsStore.outgoing) Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.HourglassEmpty, null, Modifier.size(18.dp), tint = C.textSecondary)
            Spacer(Modifier.width(6.dp))
            Column(Modifier.weight(1f)) {
                Text(label, style = font(15), color = C.textPrimary, maxLines = 1)
                Text("wartet auf Bestätigung", style = font(12), color = C.textSecondary)
            }
            TextButton({ scope.launch { FriendsStore.remove(id) } }) { Text("Zurückziehen", style = font(13, FontWeight.SemiBold), color = Palette.accentText) }
        }
    }
}

/** Everyone's day so far: eaten / goal. */
@Composable
private fun TodayCard(myStats: FriendStats) {
    val rows = listOf(me(myStats) to true) + FriendsStore.friends.map { it to false }
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        CardLabel(Icons.Rounded.LocalDining, "Heute")
        for ((p, isMe) in rows) {
            val s = p.stats
            val known = s.isToday && s.todayGoal > 0
            val color = goalColor(GoalStatus.of(s.todayKcal, s.todayGoal))
            Row(Modifier.fillMaxWidth().clickable { Nav.sheet { FriendTodaySheet(p, isMe) } }, verticalAlignment = Alignment.CenterVertically) {
                PersonCat(p, 2f)
                Spacer(Modifier.width(10.dp))
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(if (isMe) "${p.name} (du)" else p.name, style = font(15, if (isMe) FontWeight.Bold else FontWeight.SemiBold), color = C.textPrimary,
                            maxLines = 1, modifier = Modifier.weight(1f))
                        if (known) {
                            Text(s.todayKcal.kcalString, style = font(15, FontWeight.Bold), color = color)
                            Text(" / ${s.todayGoal.kcalString} kcal", style = font(13), color = C.textSecondary)
                        } else Text(if (s.isToday) "–" else "heute noch nichts", style = font(13), color = C.textSecondary)
                    }
                    Bar(if (known) s.todayKcal / s.todayGoal else 0.0, if (known) color else Color.Transparent, track = C.cardAlt, minWidth = if (known) 4.dp else 0.dp)
                }
                Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = C.textSecondary)
            }
        }
        Text("Ziel inklusive angerechneter Aktivität. Antippen zeigt die Makros.", style = font(11), color = C.textSecondary)
    }
}

@Composable
private fun Leaderboard(myStats: FriendStats) {
    val h = rememberHaptics()
    val metric = runCatching { FriendMetric.valueOf(App.prefs.string("friends.metric", "streak")) }.getOrDefault(FriendMetric.streak)
    val rows = (listOf(Triple(me(myStats), metric.value(myStats), true)) + FriendsStore.friends.map { Triple(it, metric.value(it.stats), false) })
        .sortedByDescending { it.second ?: -1.0 }
    val best = rows.mapNotNull { it.second }.maxOrNull() ?: 1.0
    val scale = if (metric.scale > 0) metric.scale else max(best, 1.0)
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        CardLabel(Icons.Rounded.EmojiEvents, "Rangliste")
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (m in FriendMetric.entries) {
                val on = m == metric
                Text(m.short, style = font(13, FontWeight.SemiBold), color = if (on) Color.White else C.textSecondary,
                    modifier = Modifier.clip(CircleShape).background(if (on) Palette.accent else C.cardAlt)
                        .squishClick { h.tap(); App.prefs.set("friends.metric", m.name) }.padding(horizontal = 12.dp, vertical = 8.dp))
            }
        }
        Text(metric.explanation, style = font(12), color = C.textSecondary)
        rows.forEachIndexed { i, (person, value, isMe) ->
            // Same value = same place (1, 2, 2, 4).
            val place = rows.indexOfFirst { it.second == value }.takeIf { it >= 0 } ?: i
            Row(Modifier.fillMaxWidth().clickable(enabled = !isMe) { Nav.sheet { FriendDetailSheet(person) } }, verticalAlignment = Alignment.CenterVertically) {
                Text(if (value == null) "–" else if (place < 3) listOf("🥇", "🥈", "🥉")[place] else "${place + 1}", style = font(17, FontWeight.Bold),
                    color = C.textSecondary, modifier = Modifier.width(30.dp), textAlign = TextAlign.Center)
                Spacer(Modifier.width(10.dp))
                PersonCat(person, 2.2f)
                Spacer(Modifier.width(10.dp))
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row {
                        Text(if (isMe) "${person.name} (du)" else person.name, style = font(15, if (isMe) FontWeight.Bold else FontWeight.SemiBold),
                            color = C.textPrimary, maxLines = 1, modifier = Modifier.weight(1f))
                        Text(value?.let(metric::format) ?: "–", style = font(15, FontWeight.Bold), color = if (isMe) Palette.accent else C.textPrimary)
                    }
                    Bar((value ?: 0.0) / scale, if (isMe) Palette.accent else Palette.fiber, track = C.cardAlt)
                }
            }
        }
    }
}

@Composable
private fun WeekCard(myStats: FriendStats) {
    val rows = listOf("Du" to myStats.week) + FriendsStore.friends.map { it.name to (if (it.stats.isToday) it.stats.week else shifted(it.stats)) }
    val today = LocalDate.now()
    val palette = listOf(C.cardAlt, goalColor(GoalStatus.within), goalColor(GoalStatus.slightlyOver), goalColor(GoalStatus.over))
    fun color(v: Double): Color = palette.getOrElse(v.toInt()) { palette[0] }
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        CardLabel(Icons.Rounded.CalendarMonth, "Diese Woche")
        Row {
            Spacer(Modifier.width(90.dp))
            for (i in 0 until 7) Text(today.plusDays(i - 6L).dayOfWeek.getDisplayName(java.time.format.TextStyle.NARROW, java.util.Locale.GERMAN),
                style = font(11, FontWeight.SemiBold), color = C.textSecondary, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
        }
        for ((name, week) in rows) Row(verticalAlignment = Alignment.CenterVertically) {
            Text(name, style = font(14, FontWeight.SemiBold), color = C.textPrimary, maxLines = 1, modifier = Modifier.width(90.dp))
            for (i in 0 until 7) Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                Box(Modifier.size(20.dp).clip(CircleShape).background(color(week.getOrElse(i) { 0.0 })))
            }
        }
        GoalLegend()
    }
}

/** A friend who hasn't opened the app today: their week ends earlier. Move it so the days line up. */
private fun shifted(s: FriendStats): List<Double> {
    val date = runCatching { LocalDate.parse(s.day) }.getOrNull() ?: return s.week
    val days = ChronoUnit.DAYS.between(date, LocalDate.now()).toInt()
    if (days <= 0) return s.week
    return (s.week + List(min(days, 7)) { 0.0 }).takeLast(7)
}

/** Name + start (first visit of the page). */
@Composable
fun FriendsSetupCard() {
    val store = FriendsStore
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(store.name) }
    Column(Modifier.fillMaxWidth().card(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        CatMascot(CatMood.proud, 5.dp)
        Text("Mit Freunden vergleichen", style = font(20, FontWeight.Bold), color = C.textPrimary)
        Text("Wer hält die längste Serie, trinkt am meisten Wasser, isst am meisten Gemüse? Geteilt werden nur Kennzahlen wie Serie, Zieltreue, Health Score und deine Tageskalorien und Makros mit Ziel. Keine einzelnen Mahlzeiten und kein Gewicht.",
            style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
        TextInput(draft, { draft = it }, "Dein Name", Modifier.fillMaxWidth().height(50.dp).clip(RoundedCornerShape(14.dp)).background(C.cardAlt).padding(horizontal = 14.dp),
            keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Words))
        PillButton(if (store.busy) "Einen Moment…" else "Los geht’s", enabled = draft.isNotBlank() && !store.busy) {
            App.prefs.set(FriendsStore.NAME_KEY, draft.trim().take(30))
            scope.launch { store.setUp() }
        }
        store.error?.let { Text(it, style = font(13), color = Palette.danger, textAlign = TextAlign.Center) }
    }
}

/** Type or confirm an invite code. */
@Composable
fun CodeEntrySheet(prefill: FriendsStore.IncomingCode? = null) {
    val store = FriendsStore
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    var code by remember { mutableStateOf(prefill?.code ?: "") }
    LaunchedEffect(Unit) { store.error = null }
    Screen("") {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
            CatMascot(CatMood.happy, 4.dp)
            Text(prefill?.name?.let { "$it möchte mit dir vergleichen" } ?: "Freund hinzufügen", style = font(20, FontWeight.Bold), color = C.textPrimary, textAlign = TextAlign.Center)
            if (!store.isSetUp) {
                Text("Lege zuerst deinen Namen auf der Freunde-Seite fest, dann kannst du die Anfrage senden.", style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
                FriendsSetupCard()
            } else {
                Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(C.card).padding(vertical = 12.dp), contentAlignment = Alignment.Center) {
                    TextInput(code, { v -> code = v.uppercase().filter { it.isLetterOrDigit() }.take(8) }, "ABCD2345", Modifier.width(200.dp),
                        style = font(28, FontWeight.Bold).copy(fontFamily = FontFamily.Monospace, textAlign = TextAlign.Center),
                        keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, autoCorrectEnabled = false))
                }
                Text("Den Code findet dein Freund auf seiner Freunde-Seite. Ihr seht euch, sobald ihr euch gegenseitig hinzugefügt habt.", style = font(13),
                    color = C.textSecondary, textAlign = TextAlign.Center)
                store.error?.let { Text(it, style = font(13), color = Palette.danger, textAlign = TextAlign.Center) }
                PillButton(if (store.busy) "Wird gesendet…" else "Anfrage senden", enabled = code.length == 8 && !store.busy) {
                    scope.launch {
                        if (store.addFriend(code, prefill?.name)) { h.success(); Nav.dismissSheet() }
                    }
                }
            }
        }
    }
}

/** One friend compared with me, metric by metric. */
@Composable
fun FriendDetailSheet(person: FriendsStore.Person) {
    val scope = rememberCoroutineScope()
    var confirm by remember { mutableStateOf(false) }
    val mine by produceState(FriendStats()) { value = FriendStats.compute(App.goals, false) }
    val theirs = person.stats
    var myWins = 0; var theirWins = 0
    for (m in FriendMetric.entries) {
        val a = m.value(mine); val b = m.value(theirs)
        if (a != null && b != null && a != b) { if (a > b) myWins++ else theirWins++ }
    }
    Screen("Vergleich", leading = "Fertig") {
        Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically) {
            PersonCat(person, 3.6f)
            Spacer(Modifier.width(14.dp))
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(person.name, style = font(22, FontWeight.Bold), color = C.textPrimary)
                Text(when {
                    theirs.isToday && theirs.todayGoal > 0 -> "Heute ${theirs.todayKcal.kcalString} von ${theirs.todayGoal.kcalString} kcal · ${theirs.todayEntries.toInt()} Einträge"
                    theirs.isToday -> "Heute ${theirs.todayPct.toInt()} % vom Ziel · ${theirs.todayEntries.toInt()} Einträge"
                    else -> "Heute noch nicht aktiv"
                }, style = font(13), color = C.textSecondary)
                person.updated?.let { Text("Stand ${relative(it)}", style = font(11), color = C.textSecondary) }
            }
        }
        Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically) {
            Score("Du", myWins, Palette.accent, Modifier.weight(1f))
            Text(":", style = font(28, FontWeight.Black), color = C.textSecondary)
            Score(person.name, theirWins, Palette.fiber, Modifier.weight(1f))
        }
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            for (m in FriendMetric.entries) {
                val a = m.value(mine); val b = m.value(theirs)
                val scale = if (m.scale > 0) m.scale else max(max(a ?: 0.0, b ?: 0.0), 1.0)
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(m.title, style = font(14, FontWeight.SemiBold), color = C.textPrimary)
                    CompareBar("Du", a, scale, m, Palette.accent, (a ?: -1.0) > (b ?: -1.0))
                    CompareBar(person.name, b, scale, m, Palette.fiber, (b ?: -1.0) > (a ?: -1.0))
                }
            }
            theirs.weightTrend?.let { w ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.MonitorWeight, null, Modifier.size(18.dp), tint = C.textPrimary)
                    Spacer(Modifier.width(6.dp))
                    Text("Gewichtstrend", style = font(14, FontWeight.SemiBold), color = C.textPrimary, modifier = Modifier.weight(1f))
                    Text("${if (w >= 0) "+" else "−"}${abs(w).format(2, 2)} kg/Woche", style = font(14, FontWeight.Bold), color = C.textPrimary)
                }
            }
        }
        PillButton("Freund entfernen", icon = Icons.Rounded.PersonRemove, filled = false, color = Palette.danger) { confirm = true }
    }
    if (confirm) AlertDialog({ confirm = false }, title = { Text("${person.name} entfernen?") },
        text = { Text("Ihr seht eure Werte dann nicht mehr. Ihr könnt euch jederzeit neu einladen.") },
        confirmButton = { TextButton({ confirm = false; scope.launch { FriendsStore.remove(person.id); Nav.dismissSheet() } }) { Text("Entfernen", color = Palette.danger) } },
        dismissButton = { TextButton({ confirm = false }) { Text("Abbrechen") } })
}

@Composable
private fun Score(who: String, n: Int, color: Color, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text("$n", style = font(34, FontWeight.Black), color = color)
        Text(who, style = font(13, FontWeight.SemiBold), color = C.textSecondary, maxLines = 1)
    }
}

@Composable
private fun CompareBar(who: String, v: Double?, scale: Double, m: FriendMetric, color: Color, win: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(who, style = font(12), color = C.textSecondary, maxLines = 1, modifier = Modifier.width(70.dp))
        Bar((v ?: 0.0) / scale, color, Modifier.weight(1f), height = 8.dp, track = C.cardAlt)
        Text(v?.let(m::format) ?: "–", style = font(13, if (win) FontWeight.Bold else FontWeight.Medium), color = if (win) color else C.textPrimary,
            textAlign = TextAlign.End, maxLines = 1, modifier = Modifier.width(74.dp))
        Icon(Icons.Rounded.WorkspacePremium, null, Modifier.padding(start = 4.dp).size(14.dp).alpha(if (win) 1f else 0f), tint = Palette.carbs)
    }
}

/** Settings: show/hide the page, name, weight trend, delete data. */
@Composable
fun FriendsSettingsSection() {
    val store = FriendsStore
    if (!store.isAvailable) { FormSection("Freunde", "Freunde gibt es in diesem Build nicht.") {}; return }
    val prefs = App.prefs
    val scope = rememberCoroutineScope()
    val enabled = prefs.bool(FriendsStore.ENABLED_KEY, true)
    var draft by remember { mutableStateOf(store.name) }
    var confirmDelete by remember { mutableStateOf(false) }
    fun push() { if (store.isSetUp) scope.launch { runCatching { store.upload(forced = true) } } }
    fun saveName() {
        val clean = draft.trim().take(30)
        if (clean.isEmpty() || clean == store.name) return
        prefs.set(FriendsStore.NAME_KEY, clean)
        push()
    }
    // Save shortly after typing stops.
    LaunchedEffect(draft) { delay(1200); saveName() }
    FormSection("Freunde", if (enabled) "Freunde sehen nur Kennzahlen (Serie, Zieltreue, Score, Protein, Wasser, Aktivität, Obst & Gemüse) und deine Tageskalorien und Makros mit Ziel. Keine Mahlzeiten, kein Gewicht. Den Gewichtstrend (kg pro Woche) nur, wenn du ihn teilst."
        else "Ausgeblendet. Die Seite verschwindet aus der Leiste unten. Deine Freunde bleiben erhalten.") {
        FormToggle("Freunde-Seite anzeigen", enabled, { prefs.set(FriendsStore.ENABLED_KEY, it) }, Icons.Rounded.Group)
        AnimatedVisibility(enabled) {
            Column {
                Divider()
                Row(Modifier.padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("Dein Name", style = font(16), color = C.textPrimary)
                    Spacer(Modifier.width(12.dp))
                    TextInput(draft, { draft = it }, "für Freunde sichtbar", Modifier.weight(1f), style = font(16).copy(textAlign = TextAlign.End),
                        keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Words), onSubmit = { saveName() })
                }
                Divider()
                FormToggle("Gewichtstrend teilen", prefs.bool(FriendsStore.SHARE_WEIGHT_KEY), { prefs.set(FriendsStore.SHARE_WEIGHT_KEY, it); push() })
                if (store.isSetUp) {
                    Divider()
                    FormRow("Freunde verwalten", value = "${store.friends.size}", chevron = true, onClick = { Nav.sheet { FriendsManageSheet() } })
                    Divider()
                    FormRow("Dein Code", value = store.me?.code ?: "–")
                    Divider()
                    FormRow("Freunde-Daten löschen", titleColor = Palette.danger, onClick = { confirmDelete = true })
                }
            }
        }
    }
    if (confirmDelete) AlertDialog({ confirmDelete = false }, title = { Text("Freunde-Daten löschen?") },
        text = { Text("Dein Profil und dein Code werden vom Server gelöscht, deine Freunde sehen dich nicht mehr. Deine Einträge in Purrtion bleiben.") },
        confirmButton = { TextButton({ confirmDelete = false; scope.launch { store.deleteAll() } }) { Text("Löschen", color = Palette.danger) } },
        dismissButton = { TextButton({ confirmDelete = false }) { Text("Abbrechen") } })
}

/**
 * Everyone in one place: friends (remove), sent requests (withdraw), received requests (accept / decline)
 * and people I declined or removed who still want to connect.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendsManageSheet() {
    val store = FriendsStore
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    var confirmRemove by remember { mutableStateOf<FriendsStore.Person?>(null) }
    var refreshing by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { store.refresh() }
    Screen("Freunde verwalten", leading = "Fertig", scroll = false) {
        PullToRefreshBox(refreshing, { scope.launch { refreshing = true; store.refresh(force = true); refreshing = false } }, Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
                FormSection("Freunde · ${store.friends.size}", "Entfernte Freunde sehen deine Werte nicht mehr. Ihr könnt euch jederzeit neu einladen.") {
                    if (store.friends.isEmpty()) Text("Noch keine Freunde.", style = font(15), color = C.textSecondary, modifier = Modifier.padding(vertical = 12.dp))
                    store.friends.forEachIndexed { i, p ->
                        if (i > 0) Divider()
                        ManageRow(p, p.updated?.let { "aktiv ${relative(it)}" }) {
                            TextButton({ confirmRemove = p }) { Text("Entfernen", style = font(14, FontWeight.SemiBold), color = Palette.danger) }
                        }
                    }
                }
                if (store.incoming.isNotEmpty()) FormSection("Erhaltene Anfragen") {
                    store.incoming.forEachIndexed { i, p ->
                        if (i > 0) Divider()
                        ManageRow(p, null) {
                            TextButton({ scope.launch { store.decline(p.id) } }) { Text("Ablehnen", style = font(14), color = C.textSecondary) }
                            TextButton({ h.success(); scope.launch { store.accept(p.id) } }) { Text("Annehmen", style = font(14, FontWeight.Bold), color = Palette.accentText) }
                        }
                    }
                }
                if (store.outgoing.isNotEmpty()) FormSection("Gesendete Anfragen", "Wartet, bis die andere Person annimmt. Danach steht sie oben bei den Freunden.") {
                    store.outgoing.forEachIndexed { i, (id, label) ->
                        if (i > 0) Divider()
                        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Rounded.HourglassEmpty, null, Modifier.size(18.dp), tint = C.textSecondary)
                            Spacer(Modifier.width(8.dp))
                            Text(label, style = font(16), color = C.textPrimary, maxLines = 1, modifier = Modifier.weight(1f))
                            TextButton({ scope.launch { store.remove(id) } }) { Text("Zurückziehen", style = font(14, FontWeight.SemiBold), color = Palette.accentText) }
                        }
                    }
                }
                if (store.declined.isNotEmpty()) FormSection("Abgelehnt oder entfernt", "Diese Personen möchten weiterhin mit dir vergleichen. Du siehst sie nur hier.") {
                    store.declined.forEachIndexed { i, p ->
                        if (i > 0) Divider()
                        ManageRow(p, null) {
                            TextButton({ scope.launch { store.accept(p.id) } }) { Text("Annehmen", style = font(14, FontWeight.SemiBold), color = Palette.accentText) }
                        }
                    }
                }
                Spacer(Modifier.navigationBarsPadding().height(20.dp))
            }
        }
    }
    confirmRemove?.let { p ->
        AlertDialog({ confirmRemove = null }, title = { Text("${p.name} entfernen?") },
            text = { Text("Ihr seht eure Werte dann nicht mehr. Ihr könnt euch jederzeit neu einladen.") },
            confirmButton = { TextButton({ confirmRemove = null; scope.launch { store.remove(p.id) } }) { Text("Entfernen", color = Palette.danger) } },
            dismissButton = { TextButton({ confirmRemove = null }) { Text("Abbrechen") } })
    }
    store.error?.let { err ->
        AlertDialog({ store.error = null }, title = { Text("Fehler") }, text = { Text(err) }, confirmButton = { TextButton({ store.error = null }) { Text("OK") } })
    }
}

@Composable
private fun ManageRow(p: FriendsStore.Person, subtitle: String?, actions: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        PersonCat(p, 2f)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(p.name, style = font(16, FontWeight.SemiBold), color = C.textPrimary, maxLines = 1)
            subtitle?.let { Text(it, style = font(12), color = C.textSecondary) }
        }
        actions()
    }
}

/** One person's day so far: kcal and protein / carbs / fat, each against their own goal. */
@Composable
fun FriendTodaySheet(person: FriendsStore.Person, isMe: Boolean) {
    val s = person.stats
    Screen("Heute", leading = "Fertig") {
        Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically) {
            PersonCat(person, 3.6f)
            Spacer(Modifier.width(14.dp))
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(if (isMe) "${person.name} (du)" else person.name, style = font(22, FontWeight.Bold), color = C.textPrimary)
                Text(if (!s.isToday) "Heute noch nichts eingetragen"
                    else "${s.todayEntries.toInt()} ${if (s.todayEntries == 1.0) "Eintrag" else "Einträge"}" + if (s.todayScore >= 0) " · Health Score ${s.todayScore.toInt()}" else "",
                    style = font(13), color = C.textSecondary)
                if (!isMe) person.updated?.let { Text("Stand ${relative(it)}", style = font(11), color = C.textSecondary) }
            }
        }
        if (s.isToday && s.todayGoal > 0) {
            Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                MacroLine("Kalorien", s.todayKcal, s.todayGoal, "kcal", goalColor(GoalStatus.of(s.todayKcal, s.todayGoal)))
                if (s.hasMacros) {
                    MacroLine("Protein", s.todayProtein, s.goalProtein, "g", Palette.protein)
                    MacroLine("Kohlenhydrate", s.todayCarbs, s.goalCarbs, "g", Palette.carbs)
                    MacroLine("Fett", s.todayFat, s.goalFat, "g", Palette.fat)
                } else Text("Die Makros erscheinen, sobald ${person.name} Purrtion aktualisiert hat.", style = font(13), color = C.textSecondary)
            }
            if (s.hasMacros && s.todayKcal > 0) {
                val p = s.todayProtein * 4; val c = s.todayCarbs * 4; val f = s.todayFat * 9
                val total = maxOf(p + c + f, 1.0)
                Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("Verteilung", style = font(15, FontWeight.Bold), color = C.textPrimary)
                    Row(Modifier.fillMaxWidth().height(12.dp).clip(CircleShape), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                        for ((v, color) in listOf(p to Palette.protein, c to Palette.carbs, f to Palette.fat))
                            if (v > 0) Box(Modifier.weight(v.toFloat()).fillMaxSize().background(color))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        for ((name, v, color) in listOf(Triple("Protein", p, Palette.protein), Triple("Kohlenh.", c, Palette.carbs), Triple("Fett", f, Palette.fat)))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(Modifier.size(8.dp).clip(RoundedCornerShape(2.dp)).background(color))
                                Spacer(Modifier.width(4.dp))
                                Text("$name ${Math.round(v / total * 100)} %", style = font(12, FontWeight.Medium), color = C.textSecondary)
                            }
                    }
                }
            }
        }
        if (!isMe) PillButton("Vergleich ansehen", filled = false) { Nav.dismissSheet(); Nav.sheet { FriendDetailSheet(person) } }
    }
}

@Composable
private fun MacroLine(title: String, value: Double, goal: Double, unit: String, color: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(title, style = font(15, FontWeight.SemiBold), color = C.textPrimary, modifier = Modifier.weight(1f))
            Text(if (unit == "kcal") value.kcalString else Math.round(value).toString(), style = font(16, FontWeight.Bold), color = color)
            Text(" / ${if (unit == "kcal") goal.kcalString else Math.round(goal).toString()} $unit", style = font(13), color = C.textSecondary)
        }
        Bar(value / maxOf(goal, 1.0), color, height = 8.dp, track = C.cardAlt)
    }
}




