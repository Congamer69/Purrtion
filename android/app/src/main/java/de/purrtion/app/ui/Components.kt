package de.purrtion.app.ui

import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.runtime.rememberUpdatedState
import android.view.HapticFeedbackConstants
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import de.purrtion.app.App
import de.purrtion.app.domain.GoalStatus
import de.purrtion.app.domain.SwissDatabase
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.clean
import de.purrtion.app.model.format
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.pixel.PixelSprite
import de.purrtion.app.ui.pixel.PixelSpriteView
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.Radius
import de.purrtion.app.ui.theme.RadiusSmall
import de.purrtion.app.ui.theme.ThemeCards
import de.purrtion.app.ui.theme.ThemeSetting
import de.purrtion.app.ui.theme.font
import kotlin.math.max
import kotlin.math.min

// MARK: Haptics

class Haptics(private val view: android.view.View) {
    private val on: Boolean get() = App.prefs.bool("haptics", true)
    private fun buzz(kind: Int) { if (on) runCatching { view.performHapticFeedback(kind) } }
    fun tap() = buzz(HapticFeedbackConstants.CLOCK_TICK)
    fun select() = buzz(HapticFeedbackConstants.SEGMENT_FREQUENT_TICK)
    fun success() = buzz(HapticFeedbackConstants.CONFIRM)
    fun warning() = buzz(HapticFeedbackConstants.REJECT)
}

@Composable
fun rememberHaptics(): Haptics { val v = LocalView.current; return remember(v) { Haptics(v) } }

// MARK: Cards & buttons

fun Modifier.card(padding: Dp = 16.dp, color: Color? = null): Modifier = this.then(
    Modifier.composedCard(padding, color)
)

private fun Modifier.composedCard(padding: Dp, color: Color?): Modifier = composed {
    val shape = RoundedCornerShape(Radius)
    val colors = C
    var m: Modifier = this
    // Card style from the settings: soft shadow, flat or outlined (like iOS).
    when (ThemeSetting.cards) {
        ThemeCards.shadow -> m = if (colors.dark) m else m.shadow(7.dp, shape, clip = false,
            ambientColor = Color(0x66E9C9AE), spotColor = Color(0x66E9C9AE))
        else -> {}
    }
    m = m.clip(shape).background(color ?: colors.card)
    when (ThemeSetting.cards) {
        ThemeCards.outline -> m = m.border(1.5.dp, colors.line, shape)
        ThemeCards.shadow -> if (colors.dark) m = m.border(1.dp, Color.White.copy(alpha = 0.06f), shape)
        ThemeCards.flat -> {}
    }
    m.padding(padding)
}

/** Clickable that squishes a bit when pressed (iOS SquishButtonStyle). */
fun Modifier.squishClick(enabled: Boolean = true, onClick: () -> Unit): Modifier = composed {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val s by animateFloatAsState(if (pressed) 0.95f else 1f, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMediumLow), label = "squish")
    this.scale(s).clickable(source, indication = null, enabled = enabled, onClick = onClick)
}

@Composable
fun PillButton(text: String, modifier: Modifier = Modifier, icon: ImageVector? = null, filled: Boolean = true,
               color: Color = Palette.accent, enabled: Boolean = true, subtitle: String? = null, onClick: () -> Unit) {
    Row(
        modifier.fillMaxWidth().height(if (subtitle == null) 52.dp else 58.dp).clip(CircleShape)
            .background(if (filled) color.copy(alpha = if (enabled) 1f else 0.45f) else color.copy(alpha = 0.14f))
            .squishClick(enabled, onClick).padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        val fg = if (filled) Color.White else color.copy(alpha = if (enabled) 1f else 0.5f)
        if (icon != null) { Icon(icon, null, tint = fg, modifier = Modifier.size(19.dp)); Spacer(Modifier.width(8.dp)) }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(text, style = font(16, FontWeight.SemiBold), color = fg, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (subtitle != null) Text(subtitle, style = font(11, FontWeight.SemiBold), color = fg.copy(alpha = 0.85f))
        }
    }
}

@Composable
fun RoundIconButton(icon: ImageVector, modifier: Modifier = Modifier, size: Dp = 34.dp, filled: Boolean = false,
                    tint: Color = Palette.accent, description: String? = null, onClick: () -> Unit) {
    Box(modifier.size(size).clip(CircleShape).background(if (filled) tint else C.accentSoft).squishClick(onClick = onClick),
        contentAlignment = Alignment.Center) {
        Icon(icon, description, tint = if (filled) Color.White else tint, modifier = Modifier.size(size * 0.5f))
    }
}

@Composable
fun Chip(text: String, selected: Boolean, modifier: Modifier = Modifier, icon: ImageVector? = null, onClick: () -> Unit) {
    Row(modifier.height(34.dp).clip(CircleShape).background(if (selected) Palette.accent else C.cardAlt)
        .squishClick(onClick = onClick).padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        if (icon != null) { Icon(icon, null, Modifier.size(14.dp), tint = if (selected) Color.White else C.textSecondary); Spacer(Modifier.width(5.dp)) }
        Text(text, style = font(13, FontWeight.SemiBold), color = if (selected) Color.White else C.textSecondary, maxLines = 1)
    }
}

/** Segmented control like on iOS. */
@Composable
fun <T> Segmented(options: List<T>, selected: T, label: (T) -> String, modifier: Modifier = Modifier, onSelect: (T) -> Unit) {
    val h = rememberHaptics()
    Row(modifier.fillMaxWidth().clip(CircleShape).background(C.cardAlt).padding(3.dp)) {
        for (o in options) {
            val on = o == selected
            Box(Modifier.weight(1f).height(34.dp).clip(CircleShape).background(if (on) C.card else Color.Transparent)
                .clickable { h.select(); onSelect(o) }, contentAlignment = Alignment.Center) {
                Text(label(o), style = font(14, if (on) FontWeight.SemiBold else FontWeight.Medium),
                    color = if (on) C.textPrimary else C.textSecondary, maxLines = 1)
            }
        }
    }
}

// MARK: Screen scaffold

/**
 * Screen with a top bar (title, leading close/back, trailing action) and an optional bottom bar.
 * The content area scrolls by default.
 */
@Composable
fun Screen(
    title: String,
    leading: String? = "Abbrechen",
    onLeading: (() -> Unit)? = { Nav.pop() },
    back: Boolean = false,
    trailing: (@Composable RowScope.() -> Unit)? = null,
    bottom: (@Composable () -> Unit)? = null,
    scroll: Boolean = true,
    contentPadding: PaddingValues = PaddingValues(16.dp),
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxSize().background(C.background).statusBarsPadding()) {
        Box(Modifier.fillMaxWidth().height(52.dp).padding(horizontal = 8.dp)) {
            Row(Modifier.align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically) {
                if (back) {
                    Box(Modifier.size(40.dp).clip(CircleShape).background(C.card).clickable { onLeading?.invoke() }, contentAlignment = Alignment.Center) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, "Zurück", tint = C.textPrimary)
                    }
                } else if (leading != null && onLeading != null) {
                    TextButton(onClick = onLeading) { Text(leading, style = font(16, FontWeight.Medium), color = Palette.accentText) }
                }
            }
            Text(title, style = font(17, FontWeight.Bold), color = C.textPrimary, modifier = Modifier.align(Alignment.Center).padding(horizontal = 100.dp),
                maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (trailing != null) Row(Modifier.align(Alignment.CenterEnd), verticalAlignment = Alignment.CenterVertically, content = trailing)
        }
        val inner = Modifier.weight(1f).fillMaxWidth()
        if (scroll) {
            Column(inner.verticalScroll(rememberScrollState()).padding(contentPadding), verticalArrangement = Arrangement.spacedBy(14.dp), content = content)
        } else {
            Column(inner, content = content)
        }
        if (bottom != null) Box(Modifier.fillMaxWidth().background(C.background).navigationBarsPadding().imePadding().padding(horizontal = 16.dp, vertical = 8.dp)) { bottom() }
        else Spacer(Modifier.navigationBarsPadding())
    }
}

@Composable
fun TopTextButton(text: String, bold: Boolean = true, enabled: Boolean = true, onClick: () -> Unit) {
    TextButton(onClick = onClick, enabled = enabled) {
        Text(text, style = font(16, if (bold) FontWeight.Bold else FontWeight.Medium), color = if (enabled) Palette.accent else C.textSecondary)
    }
}

@Composable
fun SectionHeader(title: String, modifier: Modifier = Modifier, icon: ImageVector? = null) {
    Row(modifier.padding(start = 4.dp, top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        if (icon != null) { Icon(icon, null, Modifier.size(15.dp), tint = C.textSecondary); Spacer(Modifier.width(6.dp)) }
        Text(title, style = font(14, FontWeight.Bold), color = C.textSecondary)
    }
}

// MARK: Small pieces

@Composable
fun MacroDot(color: Color, value: Double) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(6.dp).background(color))
        Spacer(Modifier.width(3.dp))
        Text("${Math.round(value).toDouble().clean} g", style = font(12, FontWeight.Medium), color = C.textSecondary)
    }
}

@Composable
fun AIBadge() {
    Row(Modifier.clip(CircleShape).background(C.accentSoft).padding(horizontal = 6.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Rounded.AutoAwesome, null, Modifier.size(10.dp), tint = Palette.accentText)
        Spacer(Modifier.width(3.dp))
        Text("KI", style = font(10, FontWeight.Bold), color = Palette.accentText)
    }
}

@Composable
fun CheckCircle(on: Boolean, modifier: Modifier = Modifier) {
    Box(modifier.size(22.dp).clip(CircleShape).then(if (on) Modifier.background(Palette.accent) else Modifier.border(BorderStroke(2.dp, C.textSecondary.copy(alpha = 0.6f)), CircleShape)),
        contentAlignment = Alignment.Center) {
        if (on) Icon(Icons.Rounded.Check, null, Modifier.size(15.dp), tint = Color.White)
    }
}

@Composable
fun Bar(fraction: Double, color: Color, modifier: Modifier = Modifier, height: Dp = 6.dp, track: Color? = null, minWidth: Dp = 4.dp) {
    Box(modifier.fillMaxWidth().height(height).clip(CircleShape).background(track ?: C.track(color))) {
        if (fraction > 0) Box(Modifier.fillMaxWidth(min(1.0, max(0.0, fraction)).toFloat()).height(height).widthIn(min = minWidth).clip(CircleShape).background(color))
    }
}

@Composable
fun Toast(text: String?, modifier: Modifier = Modifier) {
    androidx.compose.animation.AnimatedVisibility(text != null, modifier) {
        Row(Modifier.clip(RoundedCornerShape(24.dp)).background(C.textPrimary).padding(horizontal = 18.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            PixelSpriteView(Sprites.heart, 3.dp)
            Spacer(Modifier.width(10.dp))
            Text(text ?: "", style = font(15, FontWeight.SemiBold), color = C.background, maxLines = 2)
        }
    }
}

// MARK: Rings

@Composable
fun CalorieRing(progress: Double, lineWidth: Dp, modifier: Modifier = Modifier) {
    val shown by animateFloatAsState(progress.toFloat(), spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessLow), label = "ring")
    val track = C.cardAlt
    Canvas(modifier) {
        val w = lineWidth.toPx()
        val inset = w / 2
        val size = androidx.compose.ui.geometry.Size(this.size.width - w, this.size.height - w)
        drawArc(track, 0f, 360f, false, Offset(inset, inset), size, style = Stroke(w))
        val p = min(shown, 1f)
        drawArc(Palette.accent, -90f, 360f * p, false, Offset(inset, inset), size, style = Stroke(w, cap = StrokeCap.Round))
        if (shown > 1f) {
            drawArc(Palette.danger, -90f, 360f * min(shown - 1f, 1f), false, Offset(inset, inset), size, style = Stroke(w, cap = StrokeCap.Round))
        }
    }
}

@Composable
fun ScoreRing(value: Double, color: Color, lineWidth: Dp, modifier: Modifier = Modifier, baseline: Double? = null,
              content: @Composable BoxScope.() -> Unit) {
    val shown by animateFloatAsState(value.toFloat(), spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessLow), label = "score")
    val track = C.track(color)
    Box(modifier, contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val w = lineWidth.toPx()
            val o = Offset(w / 2, w / 2)
            val s = androidx.compose.ui.geometry.Size(size.width - w, size.height - w)
            drawArc(track, 0f, 360f, false, o, s, style = Stroke(w))
            if (baseline != null && baseline < value) {
                drawArc(color.copy(alpha = 0.4f), -90f, 360f * shown, false, o, s, style = Stroke(w, cap = StrokeCap.Round))
                drawArc(color, -90f, 360f * min(shown, baseline.toFloat()), false, o, s, style = Stroke(w, cap = StrokeCap.Round))
            } else {
                drawArc(color, -90f, 360f * shown, false, o, s, style = Stroke(w, cap = StrokeCap.Round))
            }
        }
        content()
    }
}

@Composable
fun GoalLegend(modifier: Modifier = Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        for ((status, text) in listOf(GoalStatus.within to "im Ziel", GoalStatus.slightlyOver to "bis +5 %", GoalStatus.over to "drüber", GoalStatus.none to "leer")) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(10.dp).clip(RoundedCornerShape(3.dp)).background(goalColor(status)))
                Spacer(Modifier.width(4.dp))
                Text(text, style = font(11, FontWeight.Medium), color = C.textSecondary)
            }
        }
    }
}

@Composable
fun goalColor(s: GoalStatus): Color = when (s) {
    GoalStatus.none -> C.cardAlt
    GoalStatus.within -> Palette.fiber
    GoalStatus.slightlyOver -> Color(0xFFFF9F43)   // status colours stay fixed, whatever accent is chosen
    GoalStatus.over -> Palette.danger
}

// MARK: Food rows

@Composable
fun FoodThumb(food: FoodItem, size: Dp = 44.dp) {
    Box(Modifier.size(size).clip(RoundedCornerShape(12.dp)).background(C.cardAlt), contentAlignment = Alignment.Center) {
        if (food.imageURL != null) {
            AsyncImage(model = food.imageURL, contentDescription = null, modifier = Modifier.fillMaxSize(),
                contentScale = androidx.compose.ui.layout.ContentScale.Crop)
        } else {
            PixelSpriteView(thumbSprite(food), size / 14)
        }
    }
}

fun thumbSprite(food: FoodItem): PixelSprite {
    when (food.source) {
        FoodSource.ai -> return Sprites.star
        FoodSource.custom -> return Sprites.paw
        FoodSource.restaurant -> {
            val name = food.name.lowercase()
            val category = (food.origin ?: "").lowercase()
            return when {
                food.unit == "ml" -> Sprites.drop
                listOf("pommes", "fries", "potato", "wedges").any { it in name } -> Sprites.fries
                "dessert" in category || listOf("sundae", "mcflurry", "shake").any { it in name } -> Sprites.candy
                "salat" in name || "salad" in name -> Sprites.carrot
                listOf("nugget", "wings", "chicken box").any { it in name } -> Sprites.drumstick
                else -> Sprites.burger
            }
        }
        FoodSource.swiss -> {
            val category = SwissDatabase.category(food.id.drop(3)) ?: ""
            return when {
                food.unit == "ml" -> Sprites.drop
                category.startsWith("Gerichte") -> Sprites.bowl
                category.startsWith("Brote") || category.startsWith("Getreide") -> Sprites.bread
                category.startsWith("Gemüse") -> Sprites.carrot
                category.startsWith("Milch") -> Sprites.cheese
                category.startsWith("Süss") -> Sprites.candy
                category.startsWith("Fisch") -> Sprites.fish
                category.startsWith("Fleisch") -> Sprites.drumstick
                category.startsWith("Eier") -> Sprites.egg
                else -> Sprites.apple
            }
        }
        else -> {}
    }
    if (food.unit == "ml") return Sprites.drop
    if (food.source != FoodSource.bls) return Sprites.apple
    val group = food.id.drop(4).firstOrNull() ?: return Sprites.apple
    val name = (food.origin ?: food.name).lowercase()
    return when (group) {
        'B', 'C', 'D' -> Sprites.bread
        'E' -> if (name.contains("ei") && !name.contains("teig")) Sprites.egg else Sprites.bread
        'G', 'K' -> Sprites.carrot
        'M' -> Sprites.cheese
        'S' -> Sprites.candy
        'T' -> Sprites.fish
        'U', 'V', 'W' -> Sprites.drumstick
        'X', 'Y' -> Sprites.bowl
        else -> Sprites.apple
    }
}

@Composable
fun FoodRow(food: FoodItem, modifier: Modifier = Modifier, subtitle: String? = null, amountGrams: Double? = null, trailing: (@Composable () -> Unit)? = null) {
    Row(modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        FoodThumb(food)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(food.displayName, style = font(16, FontWeight.SemiBold), color = C.textPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis)
            val warning = food.warning
            if (warning != null && subtitle == null) {
                Text("⚠ $warning", style = font(12, FontWeight.Medium), color = Palette.carbs, maxLines = 1)
            } else {
                val detail = listOfNotNull(food.brand?.takeIf { it.isNotEmpty() }, food.servings.firstOrNull()?.name,
                    "P ${Math.round(food.per100.protein)} · K ${Math.round(food.per100.carbs)} · F ${Math.round(food.per100.fat)}").joinToString(" · ")
                Text(subtitle ?: detail, style = font(13), color = C.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Spacer(Modifier.width(6.dp))
        Column(horizontalAlignment = Alignment.End) {
            if (amountGrams != null) {
                Text(food.nutrients(amountGrams).kcal.kcalString, style = font(16, FontWeight.Bold), color = C.textPrimary)
                Text("kcal", style = font(10, FontWeight.Medium), color = C.textSecondary)
                Text("${food.per100.kcal.kcalString}/100${food.unit}", style = font(9, FontWeight.Medium), color = C.textSecondary.copy(alpha = 0.8f))
            } else {
                Text(food.per100.kcal.kcalString, style = font(16, FontWeight.Bold), color = C.textPrimary)
                Text("kcal/100${food.unit}", style = font(10, FontWeight.Medium), color = C.textSecondary)
            }
        }
        if (trailing != null) { Spacer(Modifier.width(8.dp)); trailing() }
    }
}

// MARK: Inputs

/** Numeric text field without Material chrome (fits the iOS look). */
@Composable
fun NumberInput(value: String, onValueChange: (String) -> Unit, modifier: Modifier = Modifier, placeholder: String = "0",
                style: androidx.compose.ui.text.TextStyle = font(17), color: Color = C.textPrimary, align: TextAlign = TextAlign.End,
                decimal: Boolean = true, onFocus: (Boolean) -> Unit = {}) {
    Box(modifier, contentAlignment = if (align == TextAlign.End) Alignment.CenterEnd else if (align == TextAlign.Center) Alignment.Center else Alignment.CenterStart) {
        if (value.isEmpty()) Text(placeholder, style = style.copy(textAlign = align), color = C.textSecondary.copy(alpha = 0.6f), modifier = Modifier.fillMaxWidth())
        BasicTextField(value, onValueChange, textStyle = style.copy(color = color, textAlign = align), singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = if (decimal) KeyboardType.Decimal else KeyboardType.Number),
            cursorBrush = SolidColor(Palette.accent), modifier = Modifier.fillMaxWidth().onFocusChanged { onFocus(it.isFocused) })
    }
}

@Composable
fun TextInput(value: String, onValueChange: (String) -> Unit, placeholder: String, modifier: Modifier = Modifier,
              style: androidx.compose.ui.text.TextStyle = font(17), keyboard: KeyboardOptions = KeyboardOptions.Default,
              singleLine: Boolean = true, onSubmit: (() -> Unit)? = null,
              visualTransformation: androidx.compose.ui.text.input.VisualTransformation = androidx.compose.ui.text.input.VisualTransformation.None) {
    Box(modifier, contentAlignment = Alignment.CenterStart) {
        if (value.isEmpty()) Text(placeholder, style = style, color = C.textSecondary.copy(alpha = 0.7f), maxLines = 1, modifier = Modifier.fillMaxWidth())
        BasicTextField(value, onValueChange, textStyle = style.copy(color = C.textPrimary), singleLine = singleLine,
            keyboardOptions = keyboard, visualTransformation = visualTransformation, cursorBrush = SolidColor(Palette.accent), modifier = Modifier.fillMaxWidth(),
            keyboardActions = androidx.compose.foundation.text.KeyboardActions(onAny = { onSubmit?.invoke() }))
    }
}

/** A value you can either drag with a slider or tap and type directly. */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun SliderField(title: String, value: Double, range: ClosedFloatingPointRange<Double>, onChange: (Double) -> Unit,
                step: Double = 1.0, unit: String = "", decimals: Int = 0, tint: Color = Palette.accent,
                /** − and + next to the slider for small changes (hold to repeat), e.g. for the body weight. */
                stepper: Boolean = false) {
    var text by remember { mutableStateOf(value.format(decimals, grouping = false)) }
    var focused by remember { mutableStateOf(false) }
    LaunchedEffect(value) { if (!focused) text = value.format(decimals, grouping = false) }
    Column(Modifier.padding(vertical = 4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = font(16), color = C.textPrimary, modifier = Modifier.weight(1f))
            NumberInput(text, { t ->
                text = t
                t.replace(",", ".").toDoubleOrNull()?.let { onChange(it.coerceIn(range.start * 0.5, range.endInclusive * 2)) }
            }, Modifier.width(90.dp), style = font(20, FontWeight.Bold), color = tint, decimal = decimals > 0, onFocus = { focused = it })
            if (unit.isNotEmpty()) { Spacer(Modifier.width(4.dp)); Text(unit, style = font(15, FontWeight.Medium), color = C.textSecondary) }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        val current by rememberUpdatedState(value)
        fun nudge(delta: Double) = onChange((Math.round((current + delta) / step) * step).coerceIn(range.start, range.endInclusive))
        if (stepper) StepButton(Icons.Rounded.Remove, "Weniger", tint) { nudge(-step) }
        Slider(
            modifier = Modifier.weight(1f),
            value = value.coerceIn(range.start, range.endInclusive).toFloat(),
            onValueChange = { onChange(Math.round(it / step) * step) },
            valueRange = range.start.toFloat()..range.endInclusive.toFloat(),
            colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = tint, inactiveTrackColor = C.cardAlt),
            // iOS look: round white knob on a thin continuous track.
            thumb = { Box(Modifier.size(26.dp).shadow(3.dp, CircleShape).background(Color.White, CircleShape)) },
            track = { state ->
                val f = ((state.value - state.valueRange.start) / (state.valueRange.endInclusive - state.valueRange.start)).coerceIn(0f, 1f)
                Box(Modifier.fillMaxWidth().height(5.dp).clip(CircleShape).background(C.cardAlt)) {
                    Box(Modifier.fillMaxWidth(f).fillMaxHeight().background(tint))
                }
            },
        )
        if (stepper) StepButton(Icons.Rounded.Add, "Mehr", tint) { nudge(step) }
        }
    }
}

/** Round − / + button: one step per tap, keeps stepping while held. */
@Composable
private fun StepButton(icon: ImageVector, label: String, tint: Color, onStep: () -> Unit) {
    val h = rememberHaptics()
    val step by rememberUpdatedState(onStep)
    val scope = rememberCoroutineScope()
    Box(Modifier.size(38.dp).clip(CircleShape).background(tint.copy(alpha = 0.15f)).pointerInput(Unit) {
        detectTapGestures(onPress = {
            h.tap(); step()
            val repeat = scope.launch { delay(400); while (true) { step(); delay(70) } }
            tryAwaitRelease()
            repeat.cancel()
        })
    }.semantics { contentDescription = label; role = Role.Button }, contentAlignment = Alignment.Center) {
        Icon(icon, null, Modifier.size(18.dp), tint = tint)
    }
}

/** Grouped settings-style list section (iOS Form section). */
@Composable
fun FormSection(header: String? = null, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column {
        if (header != null) Text(header, style = font(14, FontWeight.SemiBold), color = C.textSecondary, modifier = Modifier.padding(start = 16.dp, bottom = 6.dp))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(RadiusSmall + 6.dp)).background(C.card).padding(horizontal = 16.dp, vertical = 4.dp), content = content)
        if (footer != null) Text(footer, style = font(12), color = C.textSecondary, modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 6.dp))
    }
}

@Composable
fun Divider() = Box(Modifier.fillMaxWidth().height(0.5.dp).background(C.line))

@Composable
fun FormRow(title: String, modifier: Modifier = Modifier, icon: ImageVector? = null, value: String? = null, chevron: Boolean = false,
            titleColor: Color = C.textPrimary, onClick: (() -> Unit)? = null, trailing: (@Composable () -> Unit)? = null) {
    Row(modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically) {
        if (icon != null) { Icon(icon, null, Modifier.size(20.dp), tint = Palette.accentText); Spacer(Modifier.width(12.dp)) }
        Text(title, style = font(16), color = titleColor, modifier = Modifier.weight(1f))
        if (value != null) Text(value, style = font(15), color = C.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(start = 8.dp))
        trailing?.invoke()
        if (chevron) { Spacer(Modifier.width(6.dp)); Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = C.textSecondary) }
    }
}


@Composable
fun FormToggle(title: String, checked: Boolean, onChange: (Boolean) -> Unit, icon: ImageVector? = null, subtitle: String? = null) {
    Row(Modifier.fillMaxWidth().clickable { onChange(!checked) }.padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        if (icon != null) { Icon(icon, null, Modifier.size(20.dp), tint = Palette.accentText); Spacer(Modifier.width(12.dp)) }
        Column(Modifier.weight(1f)) {
            Text(title, style = font(16), color = C.textPrimary)
            if (subtitle != null) Text(subtitle, style = font(12), color = Palette.danger)
        }
        androidx.compose.material3.Switch(checked = checked, onCheckedChange = onChange,
            colors = androidx.compose.material3.SwitchDefaults.colors(checkedTrackColor = Palette.accent, checkedThumbColor = Color.White))
    }
}

/** Plain full-width scroll column for tabs (no top bar). */
@Composable
fun ScrollColumn(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp), content = content)
}


/** Soft fade for content that scrolls under the floating bars: transparent far above, never a hard band. */
@Composable
fun bottomFade(): androidx.compose.ui.graphics.Brush {
    val bg = C.background
    return androidx.compose.ui.graphics.Brush.verticalGradient(
        0f to Color.Transparent,
        0.30f to bg.copy(alpha = 0.18f),
        0.60f to bg.copy(alpha = 0.60f),
        0.85f to bg.copy(alpha = 0.86f),
        1f to bg.copy(alpha = 0.94f),
    )
}
