package de.purrtion.app.ui.screens

import de.purrtion.app.ui.RoundIconButton
import androidx.compose.material.icons.rounded.History
import de.purrtion.app.domain.BloodAlcohol
import de.purrtion.app.domain.Extras
import de.purrtion.app.domain.TimeSuggestions
import de.purrtion.app.domain.RestaurantDatabase
import androidx.compose.material.icons.rounded.Fastfood
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Landscape
import androidx.compose.material.icons.rounded.QrCodeScanner
import androidx.compose.material.icons.rounded.Restaurant
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.ShoppingCart
import androidx.compose.material.icons.rounded.Spa
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.data.SavedFood
import de.purrtion.app.data.Store
import de.purrtion.app.domain.FoodSearch
import de.purrtion.app.domain.SearchSource
import de.purrtion.app.domain.fold
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.ServingOption
import de.purrtion.app.model.clean
import de.purrtion.app.ui.FoodRow
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.TextInput
import de.purrtion.app.ui.Toast
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.pixel.PixelSprite
import de.purrtion.app.ui.pixel.PixelSpriteView
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.ui.pixel.WalkingCatLoader
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate

private enum class ListTab(val title: String, val icon: ImageVector) {
    recent("Zuletzt", Icons.Rounded.Schedule), favorites("Favoriten", Icons.Rounded.Star), mine("Meine", Icons.Rounded.Restaurant)
}

@Composable
fun SearchBar(search: FoodSearch, placeholder: String, focus: FocusRequester? = null, onSubmit: () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp).height(50.dp).clip(RoundedCornerShape(16.dp)).background(C.card)
        .padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Rounded.Search, null, tint = C.textSecondary)
        Spacer(Modifier.width(10.dp))
        TextInput(search.query, { search.update(it) }, placeholder, Modifier.weight(1f).then(if (focus != null) Modifier.focusRequester(focus) else Modifier),
            keyboard = KeyboardOptions(imeAction = ImeAction.Search), onSubmit = onSubmit)
        if (search.isLoading) {
            androidx.compose.material3.CircularProgressIndicator(Modifier.size(18.dp), color = Palette.accentText, strokeWidth = 2.dp)
        } else if (search.query.isNotEmpty()) {
            Icon(Icons.Rounded.Cancel, "Leeren", Modifier.clickable { search.update("") }, tint = C.textSecondary)
        }
    }
}

/** "Essen hinzufügen": search, recents, favourites, own foods and recipes, AI estimate. */
@Composable
fun AddFoodSheet(day: LocalDate) {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val search = remember { FoodSearch(scope) }
    val saved by remember { App.db.saved().observeAll() }.collectAsState(emptyList())
    val custom by remember { App.db.custom().observeAll() }.collectAsState(emptyList())
    var tab by remember { mutableStateOf(runCatching { ListTab.valueOf(App.prefs.string("search.tab", "recent")) }.getOrDefault(ListTab.recent)) }
    var toast by remember { mutableStateOf<String?>(null) }
    val focus = remember { FocusRequester() }
    val aiEnabled = SearchSource.ai.isEnabled

    var timeSuggestions by remember { mutableStateOf<List<TimeSuggestions.Suggestion>>(emptyList()) }
    val suggestOn = App.prefs.bool(Extras.TIME_SUGGEST, true)
    LaunchedEffect(suggestOn) { timeSuggestions = if (suggestOn) runCatching { TimeSuggestions.suggestions() }.getOrDefault(emptyList()) else emptyList() }
    LaunchedEffect(Unit) { delay(350); runCatching { focus.requestFocus() } }
    LaunchedEffect(toast) { if (toast != null) { delay(if (toast!!.contains("🌙")) 2600 else 1600); toast = null } }

    fun flash(name: String) {
        h.success()
        toast = "$name eingetragen" + if (BloodAlcohol.lastMovedToNight) "\n🌙 zählt zur Nacht von gestern" else ""
        BloodAlcohol.lastMovedToNight = false
    }
    fun openFood(food: FoodItem) = Nav.push { FoodDetailScreen(food, DetailMode.Add(day)) { name -> Nav.pop(); flash(name) } }

    val q = search.query.trim()
    val words = q.split(" ").filter { it.isNotEmpty() }
    val sentence = words.size >= 3 || q.any(Char::isDigit) || q.contains(",") || words.any { it.lowercase() in listOf("und", "mit", "dazu", "plus") }
    val favorites = saved.filter { it.isFavorite }
    val recents = saved.take(25)
    val matchingCustom = if (q.isEmpty()) custom else custom.filter { fold(it.name).contains(fold(q)) }

    Box(Modifier.fillMaxSize()) {
        Screen("Essen hinzufügen", leading = "Fertig", scroll = false, contentPadding = PaddingValues(0.dp),
            trailing = { IconButton(onClick = { Nav.push { BarcodeSheet(day, back = true) } }) { Icon(Icons.Rounded.QrCodeScanner, "Barcode", tint = Palette.accentText) } }) {
            SearchBar(search, if (aiEnabled) "z. B. Skyr oder „2 Eier und ein Toast“" else "z. B. Apfel, Skyr, Pizza …", focus) {
                if (aiEnabled && q.length >= 2 && (sentence || search.isEmpty)) Nav.push { MealPhotoSheet(day, textQuery = q, back = true) { n -> Nav.pop(); flash(n) } }
            }
            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 40.dp)) {
                if (q.isEmpty()) {
                    item {
                        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp).clip(RoundedCornerShape(18.dp)).background(C.card)
                            .squishClick { Nav.push { SuggestionsList(day, back = true) { n -> Nav.pop(); flash(n) } } }.padding(horizontal = 12.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(34.dp).clip(CircleShape).background(C.accentSoft), contentAlignment = Alignment.Center) {
                                Icon(Icons.Rounded.AutoAwesome, null, Modifier.size(16.dp), tint = Palette.accentText)
                            }
                            Spacer(Modifier.width(10.dp))
                            Column(Modifier.weight(1f)) {
                                Text("Was passt noch?", style = font(15, FontWeight.Bold), color = C.textPrimary)
                                Text("Vorschläge aus Favoriten & Rezepten", style = font(12), color = C.textSecondary)
                            }
                            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = C.textSecondary)
                        }
                    }
                    if (timeSuggestions.isNotEmpty()) {
                        item {
                            Text("UM DIESE ZEIT", style = font(12, FontWeight.Bold), color = C.textSecondary, modifier = Modifier.padding(top = 6.dp, bottom = 2.dp))
                        }
                        items(timeSuggestions, key = { "time-" + it.name }) { sug ->
                            FoodRow(sug.food, Modifier.clickable { openFood(sug.food) }, subtitle = if (sug.days > 1) "meistens um diese Zeit" else "zuletzt um diese Zeit",
                                amountGrams = sug.quantity * sug.serving.grams) {
                                Box(Modifier.size(34.dp).clip(CircleShape).background(Palette.accent).squishClick {
                                    scope.launch { Store.log(sug.food, sug.quantity, sug.serving, day); flash(sug.food.displayName); timeSuggestions = timeSuggestions.filter { it.name != sug.name } }
                                }, contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Add, "Eintragen", tint = Color.White) }
                            }
                        }
                    }
                    item {
                        Row(Modifier.fillMaxWidth().padding(vertical = 8.dp).clip(CircleShape).background(C.card).padding(4.dp)) {
                            for (t in ListTab.entries) {
                                val on = tab == t
                                val count = when (t) { ListTab.recent -> recents.size; ListTab.favorites -> favorites.size; ListTab.mine -> custom.size }
                                Row(Modifier.weight(1f).height(38.dp).clip(CircleShape).background(if (on) Palette.accent else Color.Transparent)
                                    .clickable { h.tap(); tab = t; App.prefs.set("search.tab", t.name) },
                                    horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                                    Icon(t.icon, null, Modifier.size(14.dp), tint = if (on) Color.White else C.textSecondary)
                                    Spacer(Modifier.width(5.dp))
                                    Text(t.title, style = font(14, FontWeight.SemiBold), color = if (on) Color.White else C.textSecondary)
                                    Spacer(Modifier.width(4.dp))
                                    Text("$count", style = font(11, FontWeight.Bold), color = (if (on) Color.White else C.textSecondary).copy(alpha = 0.7f))
                                }
                            }
                        }
                    }
                    when (tab) {
                        ListTab.recent -> if (recents.isEmpty()) item {
                            Column(Modifier.fillMaxWidth().padding(vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                CatMascot(CatMood.idle, 5.dp)
                                Spacer(Modifier.height(12.dp))
                                Text("Wonach hast du Hunger?", style = font(17, FontWeight.SemiBold), color = C.textPrimary)
                                Text("Über 8.000 Lebensmittel und Gerichte aus dem Bundeslebensmittelschlüssel und der Schweizer Nährwertdatenbank, offline, plus Millionen Produkte von Open Food Facts. Alles andere schätzt die KI.",
                                    style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
                            }
                        } else items(recents, key = { it.key }) { SavedRow(it, day, { f -> openFood(f) }, { n -> flash(n) }) }
                        ListTab.favorites -> if (favorites.isEmpty()) item { TabHint(Sprites.star, "Noch keine Favoriten", "Tippe in der Detailansicht auf den Stern.") }
                            else items(favorites, key = { it.key }) { SavedRow(it, day, { f -> openFood(f) }, { n -> flash(n) }) }
                        ListTab.mine -> {
                            item {
                                Row(Modifier.padding(vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    PillButton("Rezept", Modifier.weight(1f), icon = Icons.Rounded.Restaurant, filled = false) { Nav.sheet { RecipeEditorSheet(null) } }
                                    PillButton("Eigenes", Modifier.weight(1f), icon = Icons.Rounded.Add, filled = false) { Nav.sheet { CustomFoodEditorSheet(null) } }
                                }
                            }
                            if (custom.isEmpty()) item { TabHint(Sprites.bowl, "Noch nichts Eigenes", "Lege Rezepte (z. B. Meal Prep) oder eigene Lebensmittel an.") }
                            else items(custom, key = { it.id }) { c -> FoodRow(c.food, Modifier.clickable { openFood(c.food) }) }
                        }
                    }
                } else {
                    if (aiEnabled && q.length >= 2 && sentence) item { AIRow(q, sentence) { Nav.push { MealPhotoSheet(day, textQuery = q, back = true) { n -> Nav.pop(); flash(n) } } } }
                    results(search, matchingCustom.map { it.food }) { openFood(it) }
                    if (aiEnabled && q.length >= 2 && !sentence && (!search.isLoading || !search.isEmpty)) {
                        item { SectionTitle("Nicht dabei?", Icons.Rounded.AutoAwesome) }
                        item { AIRow(q, sentence) { Nav.push { MealPhotoSheet(day, textQuery = q, back = true) { n -> Nav.pop(); flash(n) } } } }
                    }
                    if (!search.isLoading && search.isEmpty && matchingCustom.isEmpty()) item {
                        Column(Modifier.fillMaxWidth().padding(vertical = 30.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            PixelSpriteView(Sprites.fish, 4.dp)
                            Spacer(Modifier.height(10.dp))
                            Text("Nichts gefunden", style = font(16, FontWeight.SemiBold), color = C.textPrimary)
                            Text(if (aiEnabled) "Lass es oben von der KI schätzen oder trag es über ⚡ schnell selbst ein." else "Probier einen anderen Begriff oder trag es über ⚡ schnell selbst ein.",
                                style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
                        }
                    }
                }
            }
        }
        Toast(toast, Modifier.align(Alignment.TopCenter).padding(top = 100.dp))
    }
}


/** Result sections of a search (own, BLS, Swiss, restaurant chains, Open Food Facts). */
fun LazyListScope.results(search: FoodSearch, own: List<FoodItem>, onPick: (FoodItem) -> Unit) {
    fun section(title: String, icon: ImageVector, list: List<FoodItem>) {
        if (list.isEmpty()) return
        item { SectionTitle(title, icon) }
        items(list.distinctBy { it.id }, key = { title + it.id }) { f -> FoodRow(f, Modifier.clickable { onPick(f) }) }
    }
    // A chain in the query ("mcdonalds pommes") puts its products first.
    val chainsFirst = RestaurantDatabase.mentionsChain(search.query)
    section("Meine", Icons.Rounded.Restaurant, own)
    if (chainsFirst) section("Restaurantketten", Icons.Rounded.Fastfood, search.restaurants)
    section("Lebensmittel · BLS", Icons.Rounded.Spa, search.foods)
    section("Lebensmittel & Gerichte · Schweiz", Icons.Rounded.Landscape, search.swiss)
    if (!chainsFirst) section("Restaurantketten", Icons.Rounded.Fastfood, search.restaurants)
    section("Produkte · Open Food Facts", Icons.Rounded.ShoppingCart, search.products)
    if (search.isLoading && search.products.isEmpty()) item {
        Box(Modifier.fillMaxWidth().padding(vertical = 30.dp), contentAlignment = Alignment.Center) { WalkingCatLoader(2.5.dp, 200.dp, "Suche Produkte …") }
    } else search.error?.let { err -> item {
        Row(Modifier.padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.WifiOff, null, Modifier.size(16.dp), tint = C.textSecondary)
            Spacer(Modifier.width(6.dp))
            Text(err, style = font(13), color = C.textSecondary)
        }
    } }
}

@Composable
fun SectionTitle(title: String, icon: ImageVector) {
    Row(Modifier.padding(top = 14.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, Modifier.size(15.dp), tint = C.textSecondary)
        Spacer(Modifier.width(6.dp))
        Text(title, style = font(14, FontWeight.Bold), color = C.textSecondary)
    }
}

@Composable
private fun AIRow(q: String, sentence: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(C.accentSoft), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.AutoAwesome, null, tint = Palette.accentText)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text("„$q“ mit KI schätzen", style = font(16, FontWeight.SemiBold), color = C.textPrimary, maxLines = 2)
            Text(if (sentence) "Erkennt alle genannten Lebensmittel und Mengen" else "Für Restaurant- und Imbissgerichte ohne Datenbankeintrag",
                style = font(13), color = C.textSecondary, maxLines = 1)
        }
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Palette.accentText)
    }
}

@Composable
private fun TabHint(sprite: PixelSprite, title: String, text: String) {
    Column(Modifier.fillMaxWidth().padding(vertical = 30.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        PixelSpriteView(sprite, 4.dp)
        Spacer(Modifier.height(10.dp))
        Text(title, style = font(16, FontWeight.SemiBold), color = C.textPrimary)
        Text(text, style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
    }
}

@Composable
private fun SavedRow(s: SavedFood, day: LocalDate, onOpen: (FoodItem) -> Unit, onLogged: (String) -> Unit) {
    val food = s.food ?: return
    val scope = rememberCoroutineScope()
    val serving = s.lastServing
    val grams = s.lastQuantity * (serving?.grams ?: if (s.lastServingName == food.unit) 1.0 else food.defaultServing.grams)
    val subtitle = if (serving != null && serving.grams != 1.0) {
        if (s.lastQuantity == 1.0) serving.name else "${s.lastQuantity.clean} × ${serving.name.removePrefix("1 ")}"
    } else "${s.lastQuantity.clean} ${s.lastServingName}"
    SwipeRow(true, onDelete = { scope.launch { App.db.saved().delete(s) } },
        onDuplicate = { scope.launch { App.db.saved().upsert(s.copy(isFavorite = !s.isFavorite)) } }) {
        FoodRow(food, Modifier.background(C.background).clickable { onOpen(food) }, subtitle = subtitle, amountGrams = grams) {
            Box(Modifier.size(34.dp).clip(CircleShape).background(Palette.accent).squishClick {
                scope.launch { Store.log(food, s.lastQuantity, serving ?: food.defaultServing, day); onLogged(food.displayName) }
            }, contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Add, "Eintragen", tint = Color.White) }
        }
    }
}

/** Search + amount picker that returns an ingredient instead of logging it. */
@Composable
fun IngredientPickerSheet(onPick: (FoodItem, Double, ServingOption) -> Unit) {
    val scope = rememberCoroutineScope()
    val search = remember { FoodSearch(scope) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { delay(350); runCatching { focus.requestFocus() } }
    // What was logged recently, for the empty search field.
    val recent by remember { App.db.saved().observeAll() }.collectAsState(emptyList())
    fun pick(f: FoodItem) = Nav.push { FoodDetailScreen(f, DetailMode.Pick { food, q, s -> onPick(food, q, s); Nav.dismissSheet() }) }
    Screen("Zutat", scroll = false, contentPadding = PaddingValues(0.dp), trailing = {
        RoundIconButton(Icons.Rounded.QrCodeScanner, Modifier.padding(end = 8.dp)) {
            Nav.sheet { BarcodeSheet(LocalDate.now(), onPick = { f, q, s -> onPick(f, q, s); Nav.dismissSheet() }) }
        }
    }) {
        SearchBar(search, "Zutat suchen", focus)
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 16.dp)) {
            if (search.query.isBlank()) {
                val items = recent.take(40).mapNotNull { it.food }
                if (items.isNotEmpty()) {
                    item { SectionTitle("Zuletzt verwendet", Icons.Rounded.History) }
                    items(items, key = { "recent" + it.id }) { f -> FoodRow(f, Modifier.clickable { pick(f) }) }
                }
            }
            results(search, emptyList()) { f -> pick(f) }
        }
    }
}

/** Search all databases; picking a row replaces only the food data (the amount stays). */
@Composable
fun FoodReplacementPicker(onPick: (FoodItem) -> Unit) {
    val scope = rememberCoroutineScope()
    val search = remember { FoodSearch(scope) }
    val custom by remember { App.db.custom().observeAll() }.collectAsState(emptyList())
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { delay(350); runCatching { focus.requestFocus() } }
    val q = search.query.trim()
    Screen("Ersetzen durch", scroll = false, contentPadding = PaddingValues(0.dp)) {
        SearchBar(search, "Lebensmittel suchen", focus)
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 16.dp)) {
            if (q.isEmpty()) item {
                Text("Der gewählte Eintrag ersetzt die KI-Schätzung. Die Grammzahl bleibt unverändert.", style = font(14), color = C.textSecondary,
                    textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(30.dp))
            } else results(search, custom.filter { fold(it.name).contains(fold(q)) }.map { it.food }) { onPick(it); Nav.pop() }
        }
    }
}
