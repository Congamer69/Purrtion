package de.purrtion.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.DragHandle
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.LocalDining
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Medication
import androidx.compose.material.icons.rounded.MonitorWeight
import androidx.compose.material.icons.rounded.Pets
import androidx.compose.material.icons.rounded.PieChart
import androidx.compose.material.icons.rounded.DirectionsWalk
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.ui.Divider
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.TopTextButton
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt

/** The cards of the Verlauf tab. Order and visibility are the user's choice (same storage format as on iOS). */
enum class StatsCardId(val title: String, val icon: ImageVector, val defaultVisible: Boolean) {
    kcal("Kalorien", Icons.Rounded.LocalFireDepartment, true),
    overview("Serie & Zieltreue", Icons.Rounded.Pets, true),
    expenditure("Echter Verbrauch", Icons.Rounded.Bolt, true),
    goal("Ziel eingehalten", Icons.Rounded.Flag, true),
    score("Health Score", Icons.Rounded.Favorite, true),
    weight("Gewicht", Icons.Rounded.MonitorWeight, true),
    activity("Aktivität", Icons.Rounded.DirectionsWalk, false),
    macro("Makros", Icons.Rounded.PieChart, false),
    weekday("Wochentage", Icons.Rounded.CalendarMonth, false),
    topFoods("Häufigste Lebensmittel", Icons.Rounded.LocalDining, false),
    micro("Mikronährstoffe", Icons.Rounded.Medication, false);
}

data class StatsLayout(
    val order: List<StatsCardId> = StatsCardId.entries,
    val hidden: Set<StatsCardId> = StatsCardId.entries.filter { !it.defaultVisible }.toSet(),
) {
    val visible: List<StatsCardId> get() = order.filter { it !in hidden }

    fun json(): String = JSONObject()
        .put("order", JSONArray(order.map { it.name }))
        .put("hidden", JSONArray(hidden.map { it.name }))
        .toString()

    companion object {
        const val KEY = "stats.layout"

        fun load(): StatsLayout {
            val raw = App.prefs.string(KEY, "")
            if (raw.isEmpty()) return StatsLayout()
            return runCatching {
                val o = JSONObject(raw)
                fun ids(a: JSONArray) = (0 until a.length()).mapNotNull { i -> StatsCardId.entries.firstOrNull { it.name == a.getString(i) } }
                var order = ids(o.getJSONArray("order"))
                val hidden = ids(o.getJSONArray("hidden")).toMutableSet()
                // Cards added in later versions show up at the end, hidden or not by their default.
                for (c in StatsCardId.entries) if (c !in order) { order = order + c; if (!c.defaultVisible) hidden += c }
                StatsLayout(order, hidden)
            }.getOrDefault(StatsLayout())
        }

        fun save(l: StatsLayout) = App.prefs.set(KEY, l.json())
    }
}

private val RowHeight = 60.dp

/** Verlauf → "Anpassen": drag the handle to reorder, tap the eye to show or hide. */
@Composable
fun StatsLayoutEditor() {
    val h = rememberHaptics()
    var layout by remember { mutableStateOf(StatsLayout.load()) }
    fun update(l: StatsLayout) { layout = l; StatsLayout.save(l) }
    var dragging by remember { mutableIntStateOf(-1) }
    var dragY by remember { mutableFloatStateOf(0f) }
    val rowPx = with(LocalDensity.current) { RowHeight.toPx() }

    Screen("Verlauf anpassen", leading = null, trailing = { TopTextButton("Fertig") { Nav.pop() } }) {
        Text("Ziehe an den Griffen, um die Reihenfolge zu ändern. Mit dem Auge blendest du Karten ein oder aus. Manche Karten erscheinen nur, wenn es Daten dafür gibt.",
            style = font(13), color = C.textSecondary)
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(C.card)) {
            layout.order.forEachIndexed { i, card ->
                val shown = card !in layout.hidden
                val isDragging = dragging == i
                Row(
                    Modifier.fillMaxWidth().height(RowHeight)
                        .offset { IntOffset(0, if (isDragging) dragY.roundToInt() else 0) }
                        .then(if (isDragging) Modifier.shadow(8.dp, RoundedCornerShape(14.dp)).background(C.card) else Modifier)
                        .padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.size(32.dp).clip(RoundedCornerShape(9.dp)).background(if (shown) C.accentSoft else C.cardAlt), contentAlignment = Alignment.Center) {
                        Icon(card.icon, null, Modifier.size(17.dp), tint = if (shown) Palette.accent else C.textSecondary)
                    }
                    Spacer(Modifier.width(12.dp))
                    Text(card.title, style = font(15, FontWeight.SemiBold), color = if (shown) C.textPrimary else C.textSecondary, modifier = Modifier.weight(1f))
                    Box(Modifier.size(40.dp).clip(CircleShape).clickable {
                        h.tap()
                        update(layout.copy(hidden = if (shown) layout.hidden + card else layout.hidden - card))
                    }, contentAlignment = Alignment.Center) {
                        Icon(if (shown) Icons.Rounded.Visibility else Icons.Rounded.VisibilityOff, if (shown) "${card.title} ausblenden" else "${card.title} einblenden",
                            Modifier.size(22.dp), tint = if (shown) Palette.accent else C.textSecondary)
                    }
                    Box(
                        Modifier.size(40.dp).pointerInput(card) {
                            detectDragGestures(
                                onDragStart = { dragging = layout.order.indexOf(card); dragY = 0f; h.tap() },
                                onDragEnd = { dragging = -1; dragY = 0f },
                                onDragCancel = { dragging = -1; dragY = 0f },
                            ) { change, drag ->
                                change.consume()
                                dragY += drag.y
                                val from = dragging
                                val target = (from + (dragY / rowPx).roundToInt()).coerceIn(0, layout.order.lastIndex)
                                if (from >= 0 && target != from) {
                                    val moved = layout.order.toMutableList().apply { add(target, removeAt(from)) }
                                    update(layout.copy(order = moved))
                                    dragging = target
                                    dragY -= (target - from) * rowPx
                                    h.select()
                                }
                            }
                        },
                        contentAlignment = Alignment.Center,
                    ) { Icon(Icons.Rounded.DragHandle, "Verschieben", Modifier.size(22.dp), tint = C.textSecondary) }
                }
                if (i < layout.order.lastIndex && !isDragging) Divider()
            }
        }
        Text("Auf Standard zurücksetzen", style = font(16), color = Palette.accentText,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(C.card).clickable { h.tap(); update(StatsLayout()) }.padding(16.dp))
    }
}
