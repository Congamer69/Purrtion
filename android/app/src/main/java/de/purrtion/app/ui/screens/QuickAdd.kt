package de.purrtion.app.ui.screens

import android.app.TimePickerDialog
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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.ListAlt
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.ui.Segmented
import de.purrtion.app.domain.BloodAlcohol
import de.purrtion.app.model.weekdayName
import de.purrtion.app.data.Store
import de.purrtion.app.data.newId
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.ServingOption
import de.purrtion.app.model.clean
import de.purrtion.app.model.format
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.Divider
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.NumberInput
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.TextInput
import de.purrtion.app.ui.card
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

private fun num(s: String): Double = s.replace(",", ".").toDoubleOrNull() ?: 0.0

/**
 * Log just calories (and optionally macros, alcohol and any micronutrient) in two taps.
 * "Pro 100 g" takes the values straight from a nutrition table plus the amount eaten.
 */
@Composable
fun QuickAddSheet(day: LocalDate) {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    var name by remember { mutableStateOf("") }
    var kcal by remember { mutableStateOf("") }
    var protein by remember { mutableStateOf("") }
    var carbs by remember { mutableStateOf("") }
    var fat by remember { mutableStateOf("") }
    var showMore by remember { mutableStateOf(false) }
    var ml by remember { mutableStateOf("") }
    var vol by remember { mutableStateOf("") }
    var alcGrams by remember { mutableStateOf("") }
    var time by remember { mutableStateOf(LocalTime.now().withSecond(0).withNano(0)) }
    val extras = remember { mutableStateMapOf<NutrientKey, String>() }
    // Values per 100 g / ml from the package table, then the amount eaten. Remembered for next time.
    val per100 = App.prefs.bool("quickAdd.per100")
    var amount by remember { mutableStateOf("") }
    // A drink after midnight counts to the night before (switchable).
    var toNight by remember { mutableStateOf(true) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { delay(350); runCatching { focus.requestFocus() } }

    // Grams of alcohol (per 100 in the table mode): typed directly or from amount × % vol (density 0.789 g/ml).
    val alcohol = num(alcGrams).takeIf { it > 0 } ?: ((if (per100) 100.0 else num(ml)) * num(vol) / 100 * 0.789)
    // kcal as entered (total, or per 100 in the table mode); computed from the macros when left empty.
    val enteredKcal = num(kcal).takeIf { it > 0 } ?: (num(protein) * 4 + num(carbs) * 4 + num(fat) * 9 + alcohol * 7)
    // Entered values × factor = what was eaten.
    val factor = if (per100) num(amount) / 100 else 1.0
    val kcalValue = enteredKcal * factor
    // The evening a drink after midnight belongs to, null when the rule does not apply.
    val drinkTime = combine(day, time)
    val nightDay = BloodAlcohol.nightDay(day, alcohol * factor, drinkTime).takeIf { it != day && drinkTime <= System.currentTimeMillis() }
    val extraCount = extras.values.count { num(it) > 0 } + if (alcohol > 0) 1 else 0

    fun save() {
        var n = Nutrients(enteredKcal, num(protein), num(carbs), num(fat))
        for ((k, v) in extras) if (num(v) > 0) n = n.with(k, num(v))
        if (alcohol > 0) n = n.with(NutrientKey.alcohol, Math.round(alcohol * 10) / 10.0)
        n = n.normalized()
        val title = name.trim().ifEmpty { if (alcohol > 0) "Getränk" else "Schnell-Eintrag" }
        // Stored as a "custom" food: total mode as 1 portion = 100 units, table mode with the real per-100 values
        // and the eaten amount as the portion, so the entry stays editable either way.
        val food = FoodItem(id = "custom-${newId()}", name = title, source = FoodSource.custom, per100 = n,
            servings = listOf(ServingOption("Portion", if (per100) num(amount) else 100.0)))
        val created = if (alcohol > 0) combine(day, time) else System.currentTimeMillis()
        scope.launch {
            Store.log(food, 1.0, food.servings[0], day, created, toNight = toNight)
            h.success()
            Nav.pop()
        }
    }

    Screen("Schnell eintragen", bottom = {
        PillButton(if (kcalValue > 0) "Eintragen · ${kcalValue.kcalString} kcal" else "Eintragen", icon = Icons.Rounded.Bolt, enabled = kcalValue > 0) { save() }
    }) {
        Segmented(listOf(false, true), per100, { if (it) "Pro 100 g" else "Gesamt" }) { h.tap(); App.prefs.set("quickAdd.per100", it) }
        Row(Modifier.fillMaxWidth().card(20.dp), verticalAlignment = Alignment.Bottom) {
            CatMascot(if (alcohol > 0) CatMood.tipsy else CatMood.eating, 4.dp)
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End) {
                NumberInput(kcal, { kcal = it }, Modifier.width(200.dp).focusRequester(focus), style = font(52, FontWeight.ExtraBold))
                Text(if (per100) "kcal pro 100 g" else "kcal", style = font(16, FontWeight.SemiBold), color = C.textSecondary)
            }
        }
        AnimatedVisibility(per100) {
            // Table mode: how much was eaten, and what that adds up to.
            Column(Modifier.fillMaxWidth().card(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Gegessen", style = font(17), color = C.textPrimary, modifier = Modifier.weight(1f))
                    NumberInput(amount, { amount = it }, Modifier.width(120.dp), style = font(28, FontWeight.ExtraBold), color = Palette.accent)
                    Spacer(Modifier.width(6.dp))
                    Text("g / ml", style = font(15, FontWeight.Medium), color = C.textSecondary)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (g in listOf(30.0, 50.0, 100.0, 150.0, 250.0, 500.0)) {
                        val on = num(amount) == g
                        Box(Modifier.weight(1f).height(32.dp).clip(CircleShape).background(if (on) Palette.accent else C.accentSoft)
                            .squishClick { h.tap(); amount = g.clean }, contentAlignment = Alignment.Center) {
                            Text(g.clean, style = font(13, FontWeight.SemiBold), color = if (on) Color.White else Palette.accent)
                        }
                    }
                }
                if (enteredKcal > 0 && num(amount) > 0) {
                    val macros = listOf("P" to num(protein), "K" to num(carbs), "F" to num(fat)).filter { it.second > 0 }
                        .joinToString("") { " · ${it.first} ${Math.round(it.second * factor)} g" }
                    Text("= ${kcalValue.kcalString} kcal$macros", style = font(14, FontWeight.SemiBold), color = C.textSecondary)
                } else {
                    Text("Werte aus der Nährwerttabelle eintragen, dann die gegessene Menge.", style = font(13), color = C.textSecondary)
                }
            }
        }
        Column(Modifier.fillMaxWidth().card(6.dp)) {
            Field { TextInput(name, { name = it }, "Name (optional)", keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences)) }
            Divider()
            MacroField(if (per100) "Protein pro 100 g" else "Protein (g)", protein, Palette.protein) { protein = it }
            Divider()
            MacroField(if (per100) "Kohlenhydrate pro 100 g" else "Kohlenhydrate (g)", carbs, Palette.carbs) { carbs = it }
            Divider()
            MacroField(if (per100) "Fett pro 100 g" else "Fett (g)", fat, Palette.fat) { fat = it }
        }
        if (num(kcal) == 0.0 && enteredKcal > 0) {
            Text("≈ ${enteredKcal.kcalString} kcal${if (per100) " pro 100 g" else ""} aus ${if (alcohol > 0) "Makros und Alkohol" else "den Makros"} berechnet", style = font(13), color = C.textSecondary)
        }
        val rot by animateFloatAsState(if (showMore) 180f else 0f, label = "more")
        Row(Modifier.fillMaxWidth().height(52.dp).clip(RoundedCornerShape(20.dp)).background(C.card)
            .squishClick { h.tap(); focusManager.clearFocus(); showMore = !showMore }.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.ListAlt, null, Modifier.size(20.dp), tint = Palette.accent)
            Spacer(Modifier.width(10.dp))
            Text("Alkohol & Mikronährstoffe", style = font(15, FontWeight.SemiBold), color = C.textPrimary)
            if (extraCount > 0) {
                Spacer(Modifier.width(8.dp))
                Text("$extraCount", style = font(12, FontWeight.Bold), color = Color.White,
                    modifier = Modifier.clip(CircleShape).background(Palette.accent).padding(horizontal = 7.dp, vertical = 2.dp))
            }
            Spacer(Modifier.weight(1f))
            Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.rotate(rot), tint = C.textSecondary)
        }
        AnimatedVisibility(showMore) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                // Alcohol
                Column(Modifier.fillMaxWidth().card(6.dp)) {
                    Row(Modifier.padding(horizontal = 14.dp, vertical = 8.dp)) {
                        Text("Alkohol", style = font(13, FontWeight.Bold), color = C.textSecondary, modifier = Modifier.weight(1f))
                        if (alcohol > 0) Text("${alcohol.format(1)} g · ${(alcohol * 7).kcalString} kcal", style = font(12, FontWeight.SemiBold), color = Palette.accent)
                    }
                    Row {
                        // In the table mode the amount above is the drink, so only the strength is needed here.
                        if (!per100) Field(Modifier.weight(1f)) { NumberInput(ml, { ml = it; alcGrams = "" }, Modifier.fillMaxWidth(), "Menge (ml)", align = TextAlign.Start) }
                        Field(Modifier.weight(1f)) { NumberInput(vol, { vol = it; alcGrams = "" }, Modifier.fillMaxWidth(), "Vol-%", align = TextAlign.Start) }
                    }
                    Divider()
                    Field { NumberInput(alcGrams, { alcGrams = it }, Modifier.fillMaxWidth(), if (per100) "oder Alkohol pro 100 ml (g)" else "oder Alkohol direkt (g)", align = TextAlign.Start) }
                    Divider()
                    Row(Modifier.fillMaxWidth().height(52.dp).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("Getrunken um", style = font(17), color = C.textPrimary, modifier = Modifier.weight(1f))
                        Text("%02d:%02d".format(time.hour, time.minute), style = font(17, FontWeight.SemiBold), color = Palette.accent,
                            modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(C.cardAlt).clickable {
                                TimePickerDialog(context, { _, hh, mm -> time = LocalTime.of(hh, mm) }, time.hour, time.minute, true).show()
                            }.padding(horizontal = 12.dp, vertical = 6.dp))
                    }
                    nightDay?.let { night ->
                        Divider()
                        Row(Modifier.fillMaxWidth().clickable { toNight = !toNight }.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text("🌙 Zur Nacht von gestern zählen", style = font(16), color = C.textPrimary)
                                Text("Landet bei ${night.weekdayName()} in einer Promille-Kurve mit den Getränken davor.", style = font(12), color = C.textSecondary)
                            }
                            androidx.compose.material3.Switch(toNight, { toNight = it },
                                colors = androidx.compose.material3.SwitchDefaults.colors(checkedTrackColor = Palette.accent, checkedThumbColor = Color.White))
                        }
                    }
                    Row(Modifier.padding(horizontal = 14.dp, vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        for ((label, m, v) in listOf(Triple("Bier 0,5", 500.0, 5.0), Triple("Wein", 200.0, 12.0), Triple("Sekt", 100.0, 11.0), Triple("Shot", 20.0, 40.0))) {
                            Text(label, style = font(12, FontWeight.SemiBold), color = Palette.accent,
                                modifier = Modifier.clip(CircleShape).background(C.accentSoft).squishClick {
                                    h.tap(); ml = m.clean; vol = v.clean; alcGrams = ""; if (name.isEmpty()) name = label; if (per100) amount = m.clean
                                }.padding(horizontal = 10.dp, vertical = 7.dp))
                        }
                    }
                    Text("Wird für die Promille-Schätzung in der Tagesübersicht genutzt.", style = font(12), color = C.textSecondary,
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp))
                }
                for (group in NutrientKey.Group.entries) {
                    val keys = NutrientKey.entries.filter { it.group == group && it != NutrientKey.alcohol }
                    Column(Modifier.fillMaxWidth().card(6.dp)) {
                        Text(group.title, style = font(13, FontWeight.Bold), color = C.textSecondary, modifier = Modifier.padding(start = 14.dp, top = 8.dp, bottom = 2.dp))
                        keys.forEachIndexed { i, key ->
                            if (i > 0) Divider()
                            Row(Modifier.fillMaxWidth().height(44.dp).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text(key.label, style = font(16), color = C.textPrimary, modifier = Modifier.weight(1f), maxLines = 1)
                                NumberInput(extras[key] ?: "", { extras[key] = it }, Modifier.width(90.dp), "–", style = font(16, FontWeight.SemiBold))
                                Spacer(Modifier.width(6.dp))
                                Text(key.unit, style = font(13), color = C.textSecondary, modifier = Modifier.width(24.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Field(modifier: Modifier = Modifier.fillMaxWidth(), content: @Composable () -> Unit) {
    Box(modifier.height(52.dp).padding(horizontal = 14.dp), contentAlignment = Alignment.CenterStart) { content() }
}

@Composable
private fun MacroField(title: String, value: String, color: Color, onChange: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().height(52.dp).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).background(color))
        Spacer(Modifier.width(10.dp))
        NumberInput(value, onChange, Modifier.fillMaxWidth(), title, align = TextAlign.Start)
    }
}

/** The chosen clock time on the logged day; early-morning times after an evening count as the night after. */
fun combine(day: LocalDate, time: LocalTime): Long {
    var dt = LocalDateTime.of(day, time)
    if (time.hour < 6 && day != LocalDate.now() && !dt.plusDays(1).isAfter(LocalDateTime.now())) dt = dt.plusDays(1)
    return dt.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
}

