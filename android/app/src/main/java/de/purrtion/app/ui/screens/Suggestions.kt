package de.purrtion.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.Icon
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
import de.purrtion.app.data.Store
import de.purrtion.app.domain.MealSuggestions
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.FoodThumb
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.Segmented
import de.purrtion.app.ui.card
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.launch
import java.time.LocalDate

private enum class SuggestionFilter(val title: String) { all("Alle"), favorites("Favoriten"), recipes("Rezepte & Eigene") }

/** "Was passt noch?" – favourites, recipes and own foods ranked by how well they fit the rest of the day. */
@Composable
fun SuggestionsList(day: LocalDate, back: Boolean = false, onLogged: ((String) -> Unit)? = null) {
    val goals = App.goals
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val entries by remember { App.db.entries().observeDay(day.toEpochDay()) }.collectAsState(emptyList())
    val favorites by remember { App.db.saved().observeFavorites() }.collectAsState(emptyList())
    val custom by remember { App.db.custom().observeAll() }.collectAsState(emptyList())
    var filter by remember { mutableStateOf(SuggestionFilter.all) }

    val total = Nutrients.sum(entries.map { it.nutrients })
    val gap = MealSuggestions.gap(total, goals.target(day), day == LocalDate.now())
    val candidates = buildList {
        if (filter != SuggestionFilter.recipes) for (s in favorites) {
            val f = s.food ?: continue
            add(MealSuggestions.Candidate(f, s.lastQuantity, s.lastServing ?: f.defaultServing, MealSuggestions.Kind.favorite))
        }
        if (filter != SuggestionFilter.favorites) for (c in custom) {
            val f = c.food
            add(if (c.isRecipe) MealSuggestions.Candidate(f, 1.0, f.servings.firstOrNull() ?: f.defaultServing, MealSuggestions.Kind.recipe)
                else MealSuggestions.Candidate(f, f.defaultQuantity, f.defaultServing, MealSuggestions.Kind.own))
        }
    }
    val list = remember(candidates, gap) { MealSuggestions.rank(candidates, gap) }
    fun finish(name: String) { if (onLogged != null) onLogged(name) else Nav.pop() }

    Screen("Was passt noch?", back = back, leading = if (back) null else "Fertig") {
        Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically) {
            CatMascot(if (gap.kcal <= 0) CatMood.full else CatMood.hungry, 3.4.dp)
            Spacer(Modifier.width(14.dp))
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(kotlin.math.abs(gap.kcal).kcalString, style = font(28, FontWeight.ExtraBold), color = if (gap.kcal >= 0) C.textPrimary else Palette.danger)
                    Spacer(Modifier.width(4.dp))
                    Text(if (gap.kcal >= 0) "kcal übrig" else "kcal drüber", style = font(14, FontWeight.SemiBold), color = C.textSecondary)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    GapChip("P", gap.protein, Palette.protein); GapChip("K", gap.carbs, Palette.carbs); GapChip("F", gap.fat, Palette.fat)
                }
            }
        }
        Segmented(SuggestionFilter.entries, filter, { it.title }) { filter = it }
        if (favorites.isEmpty() && custom.isEmpty()) {
            Empty("Noch keine Favoriten oder Rezepte", "Markiere Lebensmittel mit dem Stern als Favorit oder lege Rezepte an. Dann schlägt die Katze hier vor, was noch passt.")
        } else if (list.isEmpty()) {
            Empty(if (gap.kcal <= 0) "Tagesziel erreicht" else "Nichts passt mehr ganz",
                if (gap.kcal <= 0) "Für heute ist das Budget aufgebraucht. Auch leichte Snacks unter 160 kcal sind nicht dabei." else "Alle Favoriten und Rezepte wären selbst in kleiner Menge zu viel.")
        } else {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(C.card)) {
                list.forEachIndexed { i, s ->
                    if (i > 0) Box(Modifier.fillMaxWidth().padding(start = 68.dp).size(0.dp, 0.5.dp).background(C.line))
                    SwipeRow(true, onDelete = null, onDuplicate = {
                        scope.launch { Store.log(s.food, s.quantity, s.serving, day); h.success(); finish(s.food.displayName) }
                    }) {
                        Row(Modifier.fillMaxWidth().background(C.card).clickable {
                            Nav.push { FoodDetailScreen(s.food, DetailMode.Add(day), s.quantity to s.serving) { name -> Nav.pop(); finish(name) } }
                        }.padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                            FoodThumb(s.food, 40.dp)
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                Text(s.food.displayName, style = font(15, FontWeight.SemiBold), color = C.textPrimary, maxLines = 1)
                                Text(s.amountText, style = font(12), color = C.textSecondary, maxLines = 1)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(s.reason, style = font(11, FontWeight.Bold), color = Palette.accent,
                                        modifier = Modifier.clip(CircleShape).background(C.accentSoft).padding(horizontal = 6.dp, vertical = 2.dp))
                                    Spacer(Modifier.width(6.dp))
                                    Text(s.kind.label, style = font(11, FontWeight.Medium), color = C.textSecondary)
                                }
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text(s.nutrients.kcal.kcalString, style = font(16, FontWeight.Bold), color = C.textPrimary)
                                Text("kcal", style = font(10, FontWeight.Medium), color = C.textSecondary)
                                Text("${Math.round(s.nutrients.protein)} g P", style = font(10, FontWeight.SemiBold), color = Palette.protein)
                            }
                            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = C.textSecondary)
                        }
                    }
                }
            }
            Text("Sortiert danach, wie gut Menge, Kalorien und Makros zum Rest des Tages passen" +
                (if (day == LocalDate.now()) ", bei noch ${gap.mealsLeft} ${if (gap.mealsLeft == 1) "Mahlzeit" else "Mahlzeiten"} heute" else "") +
                ". Nach rechts wischen trägt direkt ein.", style = font(12), color = C.textSecondary)
        }
    }
}

@Composable
fun SuggestionsSheet(day: LocalDate) = SuggestionsList(day, back = false) { Nav.pop() }

@Composable
private fun GapChip(label: String, value: Double, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(7.dp).background(color))
        Spacer(Modifier.width(4.dp))
        Text("$label ${Math.round(value)} g", style = font(12, FontWeight.SemiBold), color = C.textSecondary)
    }
}

@Composable
private fun Empty(title: String, text: String) {
    Column(Modifier.fillMaxWidth().padding(vertical = 30.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        CatMascot(CatMood.sleeping, 4.dp)
        Spacer(Modifier.size(10.dp))
        Text(title, style = font(17, FontWeight.Bold), color = C.textPrimary)
        Text(text, style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
    }
}
