package de.purrtion.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Pets
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.data.FoodEntry
import de.purrtion.app.data.Store
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.RecipeIngredient
import de.purrtion.app.model.ServingOption
import de.purrtion.app.model.clean
import de.purrtion.app.model.format
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.AIBadge
import de.purrtion.app.ui.Bar
import de.purrtion.app.ui.FoodThumb
import de.purrtion.app.ui.MacroDot
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.NumberInput
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.RoundIconButton
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.TopTextButton
import de.purrtion.app.ui.card
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.launch
import java.time.LocalDate
import kotlin.math.max

sealed interface DetailMode {
    data class Add(val day: LocalDate) : DetailMode
    data class Edit(val entry: FoodEntry) : DetailMode
    /** One ingredient of a logged recipe / AI meal. */
    data class Ingredient(val entry: FoodEntry, val id: String) : DetailMode
    /** Returns the chosen amount instead of logging (recipe ingredients). */
    data class Pick(val onPick: (FoodItem, Double, ServingOption) -> Unit) : DetailMode
}

/** Amount picker + nutrients of one food. Used to log, edit an entry or pick an ingredient. */
@Composable
fun FoodDetailScreen(food: FoodItem, mode: DetailMode, preset: Pair<Double, ServingOption>? = null, back: Boolean = true,
                     onDone: ((String) -> Unit)? = null) {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val initial = remember {
        when (mode) {
            is DetailMode.Edit -> (food.allServings.firstOrNull { it.name == mode.entry.servingName } ?: mode.entry.serving) to mode.entry.quantity
            is DetailMode.Ingredient -> mode.entry.ingredients.firstOrNull { it.id == mode.id }?.let { ing ->
                (food.allServings.firstOrNull { it.name == ing.serving.name } ?: ing.serving) to ing.quantity
            } ?: (food.defaultServing to food.defaultQuantity)
            else -> preset?.let { (q, s) -> (food.allServings.firstOrNull { it.name == s.name } ?: s) to q } ?: (food.defaultServing to food.defaultQuantity)
        }
    }
    var serving by remember { mutableStateOf(initial.first) }
    var quantity by remember { mutableStateOf(initial.second) }
    var quantityText by remember { mutableStateOf(initial.second.clean) }
    val saved by remember { App.db.saved().observe(food.id) }.collectAsState(null)
    val isFavorite = saved?.isFavorite == true

    val grams = quantity * serving.grams
    val n = food.nutrients(grams)
    val step = if (serving.grams == 1.0) (if (food.unit == "ml") 50.0 else 10.0) else 0.5
    fun setQuantity(v: Double) { quantity = max(0.0, Math.round(v * 100) / 100.0); quantityText = quantity.clean }

    fun commit() {
        scope.launch {
            when (mode) {
                is DetailMode.Add -> Store.log(food, quantity, serving, mode.day)
                is DetailMode.Edit -> Store.update(mode.entry.updated(quantity, serving, food))
                is DetailMode.Ingredient -> App.db.entries().get(mode.entry.id)?.let { Store.update(it.replacingIngredient(mode.id, food, quantity, serving)) }
                is DetailMode.Pick -> { mode.onPick(food, quantity, serving); return@launch }
            }
            h.success()
            if (onDone != null) onDone(food.displayName) else Nav.pop()
        }
    }

    val buttonTitle = when (mode) {
        is DetailMode.Add -> "Eintragen · ${n.kcal.kcalString} kcal"
        is DetailMode.Edit, is DetailMode.Ingredient -> "Speichern"
        is DetailMode.Pick -> "Als Zutat hinzufügen · ${n.kcal.kcalString} kcal"
    }

    Screen(
        title = "", back = back, leading = if (back) null else "Abbrechen",
        trailing = {
            IconButton(onClick = {
                h.tap()
                scope.launch { Store.setFavorite(food, !isFavorite, quantity, serving) }
            }) {
                Icon(if (isFavorite) Icons.Rounded.Star else Icons.Rounded.StarBorder, "Favorit", tint = if (isFavorite) Palette.carbs else C.textSecondary)
            }
        },
        bottom = {
            PillButton(buttonTitle, icon = if (mode is DetailMode.Edit || mode is DetailMode.Ingredient) Icons.Rounded.Check else Icons.Rounded.Pets,
                enabled = grams > 0) { commit() }
        },
    ) {
        // Header
        Row(verticalAlignment = Alignment.CenterVertically) {
            FoodThumb(food, 64.dp)
            Spacer(Modifier.width(14.dp))
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(food.displayName, style = font(22, FontWeight.Bold), color = C.textPrimary, maxLines = 3)
                (food.brand ?: food.origin)?.takeIf { it.isNotEmpty() }?.let { Text(it, style = font(15), color = C.textSecondary) }
                food.warning?.let {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Warning, null, Modifier.size(14.dp), tint = Palette.carbs)
                        Spacer(Modifier.width(4.dp))
                        Text(it, style = font(13, FontWeight.SemiBold), color = Palette.carbs)
                    }
                }
            }
        }
        // Amount
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                StepButton(Icons.Rounded.Remove) { h.tap(); setQuantity(quantity - step) }
                NumberInput(quantityText, { t ->
                    quantityText = t
                    t.replace(",", ".").toDoubleOrNull()?.let { quantity = it }
                }, Modifier.weight(1f).height(56.dp).clip(RoundedCornerShape(16.dp)).background(C.cardAlt).padding(horizontal = 8.dp),
                    style = font(30, FontWeight.ExtraBold), align = TextAlign.Center)
                StepButton(Icons.Rounded.Add) { h.tap(); setQuantity(quantity + step) }
            }
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (s in food.allServings) {
                    val selected = s == serving
                    Column(Modifier.clip(CircleShape).background(if (selected) Palette.accent else C.cardAlt)
                        .squishClick { h.tap(); serving = s; setQuantity(if (s.grams == 1.0) Math.round(food.servings.firstOrNull()?.grams ?: 100.0).toDouble() else 1.0) }
                        .padding(horizontal = 14.dp, vertical = 9.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(s.name, style = font(14, FontWeight.SemiBold), color = if (selected) Color.White else C.textPrimary, maxLines = 1)
                        if (s.grams != 1.0) Text("${s.grams.clean} ${food.unit}", style = font(11), color = (if (selected) Color.White else C.textPrimary).copy(alpha = 0.75f))
                    }
                }
            }
            if (serving.grams != 1.0) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (m in listOf(0.5, 1.0, 1.5, 2.0, 3.0)) {
                        val on = quantity == m
                        Box(Modifier.weight(1f).height(36.dp).clip(RoundedCornerShape(10.dp)).background(if (on) C.accentSoft else Color.Transparent)
                            .squishClick { h.tap(); setQuantity(m) }, contentAlignment = Alignment.Center) {
                            Text(when (m) { 0.5 -> "½"; 1.5 -> "1½"; else -> m.clean }, style = font(15, FontWeight.Bold), color = if (on) Palette.accent else C.textSecondary)
                        }
                    }
                }
                Text("= ${grams.clean} ${food.unit}", style = font(14, FontWeight.Medium), color = C.textSecondary)
            }
        }
        // Nutrition
        Row(Modifier.fillMaxWidth().card(14.dp)) {
            BigStat(n.kcal.kcalString, "kcal", Palette.accent, Modifier.weight(1f))
            BigStat("${n.protein.clean} g", "Protein", Palette.protein, Modifier.weight(1f))
            BigStat("${n.carbs.clean} g", "Kohlenh.", Palette.carbs, Modifier.weight(1f))
            BigStat("${n.fat.clean} g", "Fett", Palette.fat, Modifier.weight(1f))
        }
        NutrientList(n, Modifier.fillMaxWidth().card())
        val source = buildString {
            append("Quelle: ${food.source.label}")
            food.barcode?.let { append(" · EAN $it") }
            if (food.source == FoodSource.bls) append(" · Max Rubner-Institut, CC BY 4.0")
            if (food.microsEstimated == true) append(" · fehlende Mikronährstoffe KI-geschätzt")
        }
        Text(source, style = font(12), color = C.textSecondary)
    }
}

@Composable
private fun StepButton(icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Box(Modifier.size(52.dp, 56.dp).clip(RoundedCornerShape(16.dp)).background(C.accentSoft).squishClick(onClick = onClick), contentAlignment = Alignment.Center) {
        Icon(icon, null, tint = Palette.accent)
    }
}

@Composable
private fun BigStat(value: String, label: String, color: Color, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(value, style = font(18, FontWeight.ExtraBold), color = C.textPrimary, maxLines = 1)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(6.dp).background(color))
            Spacer(Modifier.width(4.dp))
            Text(label, style = font(12, FontWeight.Medium), color = C.textSecondary)
        }
    }
}

/** Lists all micronutrients grouped, with % of the daily value. */
@Composable
fun NutrientList(n: Nutrients, modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        for (group in NutrientKey.Group.entries) {
            val keys = NutrientKey.entries.filter { it.group == group && n[it] != null }
            if (keys.isEmpty()) continue
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(group.title, style = font(15, FontWeight.Bold), color = C.textPrimary)
                for (k in keys) NutrientRow(k, n[k] ?: 0.0)
            }
        }
        if (n.extra.isEmpty()) Text("Für dieses Lebensmittel sind keine weiteren Nährstoffe hinterlegt.", style = font(14), color = C.textSecondary)
    }
}

@Composable
private fun NutrientRow(key: NutrientKey, value: Double) {
    val pct = key.dailyValue?.let { value / it }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row {
            Text(key.label, style = font(14), color = C.textPrimary, modifier = Modifier.weight(1f))
            Text("${if (value >= 10) Math.round(value).toDouble().clean else value.format(2)} ${key.unit}", style = font(14, FontWeight.SemiBold), color = C.textPrimary)
            if (pct != null) Text("${Math.round(pct * 100)} %", style = font(12, FontWeight.SemiBold), color = C.textSecondary,
                modifier = Modifier.width(46.dp), textAlign = TextAlign.End)
        }
        if (pct != null) {
            val color = if (key.isLimit) (if (pct > 1) Palette.danger else Palette.carbs) else if (pct >= 1) Palette.fiber else Palette.fiber.copy(alpha = 0.7f)
            Bar(pct, color, height = 4.dp, track = C.cardAlt, minWidth = 0.dp)
        }
    }
}

@Composable
fun NutrientsDaySheet(total: Nutrients, title: String) {
    Screen(title, leading = "Fertig") {
        Row(Modifier.fillMaxWidth().card(14.dp)) {
            for ((v, l) in listOf(total.kcal.kcalString to "kcal", "${Math.round(total.protein)} g" to "Protein",
                "${Math.round(total.carbs)} g" to "Kohlenh.", "${Math.round(total.fat)} g" to "Fett")) {
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(v, style = font(17, FontWeight.ExtraBold), color = C.textPrimary)
                    Text(l, style = font(12), color = C.textSecondary)
                }
            }
        }
        NutrientList(total, Modifier.fillMaxWidth().card())
        Text("Prozentwerte beziehen sich auf die Referenzmengen der EU (NRV). Lebensmittel aus dem BLS liefern fast alle Mikronährstoffe, Markenprodukte oft nur die Pflichtangaben. Die Summen sind daher Mindestwerte.",
            style = font(12), color = C.textSecondary, modifier = Modifier.padding(horizontal = 6.dp))
    }
}

// MARK: Entry editing

@Composable
fun EditEntrySheet(entryId: String) {
    val entry by remember { App.db.entries().observe(entryId) }.collectAsState(null)
    val e = entry ?: return
    val food = e.food
    if (food == null) {
        Screen("Bearbeiten") { Text("Eintrag kann nicht bearbeitet werden.", color = C.textSecondary) }
        return
    }
    FoodDetailScreen(food, DetailMode.Edit(e), back = false)
}

@Composable
fun IngredientEditSheet(entryId: String, ingredientId: String, back: Boolean = false) {
    val entry by remember { App.db.entries().observe(entryId) }.collectAsState(null)
    val e = entry ?: return
    val ing = e.ingredients.firstOrNull { it.id == ingredientId }
    if (ing == null) { Screen("Zutat") { Text("Zutat nicht gefunden.", color = C.textSecondary) }; return }
    FoodDetailScreen(ing.food, DetailMode.Ingredient(e, ingredientId), back = back)
}

/** Ingredients of a recipe or AI meal – behaves like the "Gegessen" list. */
@Composable
fun MealEntrySheet(entryId: String) {
    val entry by remember { App.db.entries().observe(entryId) }.collectAsState(null)
    val e = entry ?: return
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    var menu by remember { mutableStateOf(false) }
    Screen("Mahlzeit bearbeiten", leading = "Fertig") {
        Row(Modifier.fillMaxWidth().card(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(e.name, style = font(20, FontWeight.Bold), color = C.textPrimary, maxLines = 2, modifier = Modifier.weight(1f, false))
                    if (e.food?.source == FoodSource.ai) { Spacer(Modifier.width(6.dp)); AIBadge() }
                }
                Text("${e.ingredients.size} Zutaten · ${e.grams.clean} g", style = font(13), color = C.textSecondary)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { MacroDot(Palette.protein, e.protein); MacroDot(Palette.carbs, e.carbs); MacroDot(Palette.fat, e.fat) }
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(e.kcal.kcalString, style = font(26, FontWeight.ExtraBold), color = C.textPrimary)
                Text("kcal", style = font(12, FontWeight.Medium), color = C.textSecondary)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Zutaten", style = font(18, FontWeight.Bold), color = C.textPrimary)
            Spacer(Modifier.width(8.dp))
            Text("${e.ingredients.size}", style = font(12, FontWeight.Bold), color = C.textSecondary,
                modifier = Modifier.clip(CircleShape).background(C.cardAlt).padding(horizontal = 7.dp, vertical = 2.dp))
            Spacer(Modifier.weight(1f))
            Box {
                RoundIconButton(Icons.Rounded.Add, description = "Zutat hinzufügen") { menu = true }
                DropdownMenu(menu, { menu = false }, containerColor = C.card) {
                    DropdownMenuItem({ Text("Zutat aus Datenbank") }, {
                        menu = false
                        Nav.sheet { IngredientPickerSheet { f, q, s -> scope.launch { App.db.entries().get(e.id)?.let { Store.update(it.addingIngredient(RecipeIngredient(food = f, quantity = q, serving = s))) } } } }
                    }, leadingIcon = { Icon(Icons.Rounded.Search, null) })
                    DropdownMenuItem({ Text("Zutat selbst eintragen") }, {
                        menu = false
                        Nav.sheet { ManualIngredientSheet { ing -> scope.launch { App.db.entries().get(e.id)?.let { Store.update(it.addingIngredient(ing)) } } } }
                    }, leadingIcon = { Icon(Icons.Rounded.Edit, null) })
                }
            }
        }
        for (ing in e.ingredients) {
            SwipeRow(true, onDelete = {
                scope.launch {
                    h.warning()
                    val updated = e.removingIngredient(ing.id)
                    if (updated == null) { Store.delete(e); Nav.pop() } else Store.update(updated)
                }
            }, onDuplicate = { scope.launch { h.tap(); Store.update(e.duplicatingIngredient(ing.id)) } }) {
                IngredientRow(ing, onClick = { Nav.push { IngredientEditSheet(e.id, ing.id, back = true) } })
            }
        }
    }
}
