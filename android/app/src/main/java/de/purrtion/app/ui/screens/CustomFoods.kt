package de.purrtion.app.ui.screens

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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AddCircle
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Restaurant
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.data.CustomFood
import de.purrtion.app.data.JsonCache
import de.purrtion.app.data.newId
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.NutrientKey
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.RecipeIngredient
import de.purrtion.app.model.ServingOption
import de.purrtion.app.model.clean
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.Divider
import de.purrtion.app.ui.FoodThumb
import de.purrtion.app.ui.FormSection
import de.purrtion.app.ui.MacroDot
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.NumberInput
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.Segmented
import de.purrtion.app.ui.TextInput
import de.purrtion.app.ui.TopTextButton
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.pixel.PixelSpriteView
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.launch

private fun num(s: String): Double? = s.replace(",", ".").toDoubleOrNull()

/** Manage own foods & recipes. */
@Composable
fun MyFoodsScreen() {
    val scope = rememberCoroutineScope()
    val foods by remember { App.db.custom().observeAll() }.collectAsState(emptyList())
    Screen("Eigene Lebensmittel", back = true) {
        FormSection {
            FormRowAction("Neues Rezept", Icons.Rounded.Restaurant) { Nav.sheet { RecipeEditorSheet(null) } }
            Divider()
            FormRowAction("Neues Lebensmittel", Icons.Rounded.AddCircle) { Nav.sheet { CustomFoodEditorSheet(null) } }
        }
        val recipes = foods.filter { it.isRecipe }
        val simple = foods.filter { !it.isRecipe }
        if (recipes.isNotEmpty()) FormSection("Rezepte") {
            recipes.forEachIndexed { i, r ->
                if (i > 0) Divider()
                SwipeRow(true, onDelete = { scope.launch { App.db.custom().delete(r) } }, onDuplicate = { Nav.sheet { RecipeEditorSheet(r.id) } }) {
                    CustomRow(r) { Nav.sheet { RecipeEditorSheet(r.id) } }
                }
            }
        }
        if (simple.isNotEmpty()) FormSection("Lebensmittel") {
            simple.forEachIndexed { i, f ->
                if (i > 0) Divider()
                SwipeRow(true, onDelete = { scope.launch { App.db.custom().delete(f) } }, onDuplicate = { Nav.sheet { CustomFoodEditorSheet(f.id) } }) {
                    CustomRow(f) { Nav.sheet { CustomFoodEditorSheet(f.id) } }
                }
            }
        }
        if (foods.isEmpty()) Column(Modifier.fillMaxWidth().padding(vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            PixelSpriteView(Sprites.bowl, 4.dp)
            Spacer(Modifier.height(10.dp))
            Text("Lege eigene Lebensmittel oder ganze Rezepte an, z. B. für Meal Prep.", style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
        }
        Text("Wischen nach links löscht.", style = font(12), color = C.textSecondary)
    }
}

@Composable
private fun FormRowAction(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, Modifier.size(20.dp), tint = Palette.accentText)
        Spacer(Modifier.width(12.dp))
        Text(title, style = font(16), color = Palette.accentText)
    }
}

@Composable
private fun CustomRow(item: CustomFood, onClick: () -> Unit) {
    val food = item.food
    Row(Modifier.fillMaxWidth().background(C.card).clickable(onClick = onClick).padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        FoodThumb(food, 40.dp)
        Spacer(Modifier.width(12.dp))
        Column {
            Text(item.name, style = font(16, FontWeight.SemiBold), color = C.textPrimary)
            Text(if (item.isRecipe) "${item.ingredients.size} Zutaten · ${item.portions} Portionen · ${food.nutrients(food.defaultServing.grams).kcal.kcalString} kcal/Portion"
                else "${food.per100.kcal.kcalString} kcal / 100 ${food.unit}", style = font(12), color = C.textSecondary)
        }
    }
}

@Composable
private fun InputRow(title: String, value: String, unit: String, onChange: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().height(48.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = font(16), color = C.textPrimary, modifier = Modifier.weight(1f))
        NumberInput(value, onChange, Modifier.width(90.dp))
        Spacer(Modifier.width(6.dp))
        Text(unit, style = font(14), color = C.textSecondary, modifier = Modifier.width(34.dp))
    }
}

/** Simple custom food (e.g. something from the bakery around the corner). */
@Composable
fun CustomFoodEditorSheet(id: String?) {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    var existing by remember { mutableStateOf<CustomFood?>(null) }
    var name by remember { mutableStateOf("") }
    var brand by remember { mutableStateOf("") }
    var unit by remember { mutableStateOf("g") }
    var kcal by remember { mutableStateOf("") }
    var protein by remember { mutableStateOf("") }
    var carbs by remember { mutableStateOf("") }
    var fat by remember { mutableStateOf("") }
    var sugar by remember { mutableStateOf("") }
    var fiber by remember { mutableStateOf("") }
    var salt by remember { mutableStateOf("") }
    var servingName by remember { mutableStateOf("1 Portion") }
    var servingGrams by remember { mutableStateOf("") }
    LaunchedEffect(id) {
        val c = id?.let { App.db.custom().get(it) } ?: return@LaunchedEffect
        existing = c
        val f = JsonCache.food(c.foodJson) ?: return@LaunchedEffect
        fun s(v: Double?) = v?.clean ?: ""
        name = c.name; brand = c.brand ?: ""; unit = f.unit
        kcal = s(f.per100.kcal); protein = s(f.per100.protein); carbs = s(f.per100.carbs); fat = s(f.per100.fat)
        sugar = s(f.per100[NutrientKey.sugar]); fiber = s(f.per100[NutrientKey.fiber]); salt = s(f.per100[NutrientKey.salt])
        f.servings.firstOrNull()?.let { servingName = it.name; servingGrams = it.grams.clean }
    }
    fun save() {
        var n = Nutrients(num(kcal) ?: 0.0, num(protein) ?: 0.0, num(carbs) ?: 0.0, num(fat) ?: 0.0)
            .with(NutrientKey.sugar, num(sugar)).with(NutrientKey.fiber, num(fiber)).with(NutrientKey.salt, num(salt))
        n = n.normalized()
        val servings = num(servingGrams)?.takeIf { it > 0 }?.let { listOf(ServingOption(servingName.ifEmpty { "1 Portion" }, it)) } ?: emptyList()
        val food = FoodItem(id = "custom", name = name, brand = brand.trim().ifEmpty { null }, source = FoodSource.custom, per100 = n, unit = unit, servings = servings)
        scope.launch {
            val e = existing
            App.db.custom().upsert(e?.copy(name = name, brand = food.brand, foodJson = JsonCache.encode(food)) ?: CustomFood.simple(name, food))
            h.success(); Nav.pop()
        }
    }
    Screen(if (id == null) "Neues Lebensmittel" else "Bearbeiten",
        trailing = { TopTextButton("Sichern", enabled = name.isNotBlank() && num(kcal) != null) { save() } }) {
        FormSection {
            TextInput(name, { name = it }, "Name", Modifier.fillMaxWidth().height(48.dp), keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences))
            Divider()
            TextInput(brand, { brand = it }, "Marke / Herkunft (optional)", Modifier.fillMaxWidth().height(48.dp))
            Divider()
            Box(Modifier.padding(vertical = 8.dp)) { Segmented(listOf("g", "ml"), unit, { if (it == "g") "Gramm" else "Milliliter" }) { unit = it } }
        }
        FormSection("Nährwerte pro 100 $unit") {
            InputRow("Kalorien", kcal, "kcal") { kcal = it }; Divider()
            InputRow("Protein", protein, "g") { protein = it }; Divider()
            InputRow("Kohlenhydrate", carbs, "g") { carbs = it }; Divider()
            InputRow("davon Zucker", sugar, "g") { sugar = it }; Divider()
            InputRow("Fett", fat, "g") { fat = it }; Divider()
            InputRow("Ballaststoffe", fiber, "g") { fiber = it }; Divider()
            InputRow("Salz", salt, "g") { salt = it }
        }
        FormSection("Portion (optional)") {
            TextInput(servingName, { servingName = it }, "Bezeichnung", Modifier.fillMaxWidth().height(48.dp)); Divider()
            InputRow("Menge", servingGrams, unit) { servingGrams = it }
        }
    }
}

/** Recipe / meal prep: ingredients from the normal search, split into portions. */
@Composable
fun RecipeEditorSheet(id: String?) {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    var existing by remember { mutableStateOf<CustomFood?>(null) }
    var name by remember { mutableStateOf("") }
    var portions by remember { mutableIntStateOf(4) }
    val ingredients = remember { mutableStateListOf<RecipeIngredient>() }
    LaunchedEffect(id) {
        val c = id?.let { App.db.custom().get(it) } ?: return@LaunchedEffect
        existing = c; name = c.name; portions = c.portions; ingredients.clear(); ingredients.addAll(c.ingredients)
    }
    val total = Nutrients.sum(ingredients.map { it.nutrients })
    val grams = ingredients.sumOf { it.grams }
    fun save() = scope.launch {
        val e = existing
        App.db.custom().upsert(e?.copy(name = name, portions = portions, ingredientsJson = JsonCache.encode(ingredients.toList()))
            ?: CustomFood.recipe(name, ingredients.toList(), portions))
        h.success(); Nav.pop()
    }
    Screen(if (id == null) "Neues Rezept" else "Rezept bearbeiten",
        trailing = { TopTextButton("Sichern", enabled = name.isNotBlank() && ingredients.isNotEmpty()) { save() } }) {
        FormSection {
            TextInput(name, { name = it }, "Name, z. B. Chili sin Carne", Modifier.fillMaxWidth().height(48.dp),
                keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences))
            Divider()
            Row(Modifier.fillMaxWidth().height(52.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Portionen", style = font(16), color = C.textPrimary, modifier = Modifier.weight(1f))
                Icon(Icons.Rounded.Remove, "Weniger", Modifier.clip(CircleShape).background(C.cardAlt).squishClick { if (portions > 1) portions-- }.padding(6.dp), tint = Palette.accent)
                Text("$portions", style = font(18, FontWeight.Bold), color = Palette.accentText, modifier = Modifier.width(44.dp), textAlign = TextAlign.Center)
                Icon(Icons.Rounded.Add, "Mehr", Modifier.clip(CircleShape).background(C.cardAlt).squishClick { if (portions < 30) portions++ }.padding(6.dp), tint = Palette.accent)
            }
        }
        FormSection("Zutaten") {
            ingredients.forEachIndexed { i, ing ->
                SwipeRow(true, onDelete = { ingredients.removeAt(i) }, onDuplicate = { ingredients.add(i + 1, ing.copy(id = newId())) }) {
                    Row(Modifier.fillMaxWidth().background(C.card).padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(ing.food.displayName, style = font(15, FontWeight.SemiBold), color = C.textPrimary)
                            Text("${ing.grams.clean} ${ing.food.unit}", style = font(12), color = C.textSecondary)
                        }
                        Text("${ing.nutrients.kcal.kcalString} kcal", style = font(14, FontWeight.SemiBold), color = C.textPrimary)
                    }
                }
                Divider()
            }
            FormRowAction("Zutat aus Datenbank", Icons.Rounded.Search) {
                Nav.sheet { IngredientPickerSheet { f, q, s -> ingredients += RecipeIngredient(food = f, quantity = q, serving = s) } }
            }
            Divider()
            FormRowAction("Zutat selbst eintragen", Icons.Rounded.Edit) { Nav.sheet { ManualIngredientSheet { ingredients += it } } }
        }
        if (ingredients.isNotEmpty()) FormSection("Nährwerte") {
            Summary("Ganzes Rezept", total, grams); Divider()
            Summary("Pro Portion", total.scaled(1.0 / portions), grams / portions)
        }
    }
}

@Composable
private fun Summary(title: String, n: Nutrients, grams: Double) {
    Column(Modifier.padding(vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row {
            Text(title, style = font(15, FontWeight.SemiBold), color = C.textPrimary, modifier = Modifier.weight(1f))
            Text("${n.kcal.kcalString} kcal · ${Math.round(grams)} g", style = font(15, FontWeight.Bold), color = C.textPrimary)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { MacroDot(Palette.protein, n.protein); MacroDot(Palette.carbs, n.carbs); MacroDot(Palette.fat, n.fat) }
    }
}

/** Free-form ingredient: name, amount and nutrients for exactly that amount. */
@Composable
fun ManualIngredientSheet(onAdd: (RecipeIngredient) -> Unit) {
    val h = rememberHaptics()
    var name by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var unit by remember { mutableStateOf("g") }
    var kcal by remember { mutableStateOf("") }
    var protein by remember { mutableStateOf("") }
    var carbs by remember { mutableStateOf("") }
    var fat by remember { mutableStateOf("") }
    val valid = name.isNotBlank() && (num(amount) ?: 0.0) > 0 && num(kcal) != null
    Screen("Eigene Zutat", trailing = {
        TopTextButton("Hinzufügen", enabled = valid) {
            val grams = num(amount) ?: return@TopTextButton
            val f = 100 / grams
            val n = Nutrients((num(kcal) ?: 0.0) * f, (num(protein) ?: 0.0) * f, (num(carbs) ?: 0.0) * f, (num(fat) ?: 0.0) * f).normalized()
            val food = FoodItem(id = "manual-${newId()}", name = name.trim(), source = FoodSource.custom, per100 = n, unit = unit)
            onAdd(RecipeIngredient(food = food, quantity = grams, serving = ServingOption.base(unit)))
            h.success(); Nav.pop()
        }
    }) {
        FormSection {
            TextInput(name, { name = it }, "Name, z. B. Omas Tomatensoße", Modifier.fillMaxWidth().height(48.dp),
                keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences))
            Divider()
            Row(Modifier.fillMaxWidth().height(52.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Menge", style = font(16), color = C.textPrimary, modifier = Modifier.weight(1f))
                NumberInput(amount, { amount = it }, Modifier.width(80.dp))
                Spacer(Modifier.width(8.dp))
                Box(Modifier.width(110.dp)) { Segmented(listOf("g", "ml"), unit, { it }) { unit = it } }
            }
        }
        FormSection("Nährwerte für diese Menge", "Trag die Werte für die gesamte Menge ein, z. B. von der Packung oder grob geschätzt.") {
            InputRow("Kalorien", kcal, "kcal") { kcal = it }; Divider()
            InputRow("Protein", protein, "g") { protein = it }; Divider()
            InputRow("Kohlenhydrate", carbs, "g") { carbs = it }; Divider()
            InputRow("Fett", fat, "g") { fat = it }
        }
    }
}
