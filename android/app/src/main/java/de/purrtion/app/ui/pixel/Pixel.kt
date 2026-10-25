package de.purrtion.app.ui.pixel

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.IntSize
import kotlin.math.roundToInt
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.domain.Diag
import de.purrtion.app.domain.Extras
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.delay
import kotlin.math.cos
import kotlin.math.sin

/** A pixel sprite described by rows of characters. Each character maps to a palette colour, `.` is transparent. */
class PixelSprite(val rows: List<String>) {
    val width: Int = rows.maxOfOrNull { it.length } ?: 0
    val height: Int = rows.size
    override fun equals(other: Any?) = other is PixelSprite && other.rows == rows
    override fun hashCode() = rows.hashCode()
    val mirrored: PixelSprite by lazy { PixelSprite(rows.map { it.reversed() }) }
}

/** Colour palettes for the cats – the same four as on iOS. */
data class CatPalette(val id: String, val name: String, val fur: Color, val furLight: Color, val stripe: Color) {
    val isDog: Boolean get() = id == "dog"

    fun color(c: Char, dark: Boolean): Color? = when (c) {
        'o' -> if (dark) Palette.dark.pixelOutline else Palette.light.pixelOutline
        'w' -> fur
        'l' -> furLight
        's' -> stripe
        'p' -> Color(0xFFFF8FA3)
        'e' -> Color(0xFF2B2230)
        'h' -> Color.White
        'c' -> Color(0xFFFF9EAE).copy(alpha = 0.85f)
        'r' -> Color(0xFFFF5A5F)
        'R' -> Color(0xFFC83C45)
        'g' -> Color(0xFF6BCB77)
        'G' -> Color(0xFF3E9E55)
        'b' -> Color(0xFF6EC6FF)
        'B' -> Color(0xFF3D8FD1)
        'y' -> Color(0xFFFFC145)
        'n' -> Color(0xFF9C6B4E)
        'k' -> Color(0xFFC9C2D0)
        'K' -> Color(0xFF8F879A)
        'W' -> Color.White
        'a' -> Color(0xFFFF8A4A)
        'A' -> Color(0xFFD9662B)
        'm' -> Color(0xFFE08A6A)
        'M' -> Color(0xFFB8583C)
        'Y' -> Color(0xFFE0A22E)
        'v' -> Color(0xFF9B7BFF)
        'V' -> Color(0xFF6C4FD6)
        else -> null
    }

    companion object {
        val ginger = CatPalette("ginger", "Mochi", Color(0xFFF6A25E), Color(0xFFFFE6CC), Color(0xFFE07B39))
        val grey = CatPalette("grey", "Nebel", Color(0xFFA8A9B8), Color(0xFFECECF3), Color(0xFF82849A))
        val black = CatPalette("black", "Mitternacht", Color(0xFF4A4453), Color(0xFF6E6779), Color(0xFF3A3542))
        val cream = CatPalette("cream", "Keks", Color(0xFFF3DDBE), Color(0xFFFFF6EA), Color(0xFFD9B88E))
        /** The secret dog. Not part of [all]: it is unlocked by tapping the logo in the settings. */
        val dog = CatPalette("dog", "Buddy", Color(0xFFC98B4F), Color(0xFFF4E0BE), Color(0xFF8B5A33))
        // Fur colours from the streak shop.
        val moon = CatPalette("moon", "Mondschein", Color(0xFFB9C6EC), Color(0xFFF3F6FF), Color(0xFF8D9CCF))
        val cinnamon = CatPalette("cinnamon", "Zimt", Color(0xFFC4693B), Color(0xFFF5D5B7), Color(0xFF8F4626))
        val sakura = CatPalette("sakura", "Sakura", Color(0xFFF5AACB), Color(0xFFFFEAF2), Color(0xFFD97BA3))
        val mint = CatPalette("mint", "Minze", Color(0xFF86D9BC), Color(0xFFE6FBF3), Color(0xFF4FB08E))
        val galaxy = CatPalette("galaxy", "Galaxie", Color(0xFF6F54D8), Color(0xFFCDBFFF), Color(0xFF4A34A3))
        val shop = listOf(moon, cinnamon, sakura, mint, galaxy)
        val all = listOf(ginger, grey, black, cream)
        fun byId(id: String) = (all + shop + dog).firstOrNull { it.id == id } ?: ginger
    }
}

/** Sprites rendered once at one pixel per cell. Drawing scales them up without smoothing, so a frame is a single image draw. */
private object SpriteCache {
    private val cache = android.util.LruCache<List<Any>, ImageBitmap>(256)

    fun get(sprite: PixelSprite, palette: CatPalette, dark: Boolean, outfit: Outfit): ImageBitmap {
        val key = listOf(sprite, palette.id, dark, outfit)
        cache.get(key)?.let { return it }
        val dressed = if (outfit.isEmpty || palette.id == "dog") sprite else Diag.safe("Outfit", sprite) { Wardrobe.apply(outfit, sprite) }
        val shown = if (palette.id == "dog") Diag.safe("Hundesprite", dressed) { DogSprites.convert(dressed) } else dressed
        val bitmap = android.graphics.Bitmap.createBitmap(maxOf(shown.width, 1), maxOf(shown.height, 1), android.graphics.Bitmap.Config.ARGB_8888)
        for ((y, row) in shown.rows.withIndex()) for ((x, ch) in row.withIndex()) {
            palette.color(ch, dark)?.let { bitmap.setPixel(x, y, it.toArgb()) }
        }
        return bitmap.asImageBitmap().also { cache.put(key, it) }
    }
}

/** Draws a [PixelSprite] crisp (nearest-neighbour scaling of a cached bitmap). */
@Composable
fun PixelSpriteView(sprite: PixelSprite, pixel: Dp = 4.dp, palette: CatPalette? = null, modifier: Modifier = Modifier, outfit: Outfit = Outfit.None) {
    val pal = palette ?: CatPalette.byId(App.prefs.string("catPalette", "ginger"))
    val dark = C.dark
    val image = remember(sprite, pal.id, dark, outfit) { SpriteCache.get(sprite, pal, dark, outfit) }
    Canvas(modifier.size(pixel * sprite.width, pixel * sprite.height)) {
        drawImage(image, dstSize = IntSize(size.width.roundToInt(), size.height.roundToInt()), filterQuality = FilterQuality.None)
    }
}

enum class CatMood(val key: String) {
    idle("idle"), happy("happy"), eating("eating"), sleeping("sleeping"), full("full"),
    yawning("yawning"), hungry("hungry"), tipsy("tipsy"), proud("proud"), content("content"),
    stuffed("stuffed"), thirsty("thirsty"), sporty("sporty");

    val frames: List<PixelSprite>
        get() = run {
            when (this@CatMood) {
                idle -> listOf(Sprites.sit, Sprites.sit, Sprites.sitTail, Sprites.sit, Sprites.sit, Sprites.sitBlink, Sprites.sit, Sprites.sitTail, Sprites.sit, Sprites.sit, Sprites.sit, Sprites.sitBlink)
                happy -> listOf(Sprites.happy, Sprites.happy, Sprites.sitTail, Sprites.happy, Sprites.sitBlink)
                eating -> listOf(Sprites.eat1, Sprites.eat2)
                sleeping -> listOf(Sprites.sleep1, Sprites.sleep1, Sprites.sleep2, Sprites.sleep2)
                full -> listOf(Sprites.full, Sprites.full, Sprites.full, Sprites.sitBlink)
                yawning -> listOf(Sprites.yawn1, Sprites.yawn1, Sprites.yawn1, Sprites.yawn2, Sprites.yawn2, Sprites.yawn1, Sprites.sitBlink, Sprites.yawn1)
                hungry -> listOf(Sprites.hungry2, Sprites.hungry2, Sprites.hungry1, Sprites.hungry2, Sprites.hungry1, Sprites.hungry2)
                tipsy -> listOf(Sprites.tipsy1, Sprites.tipsy1, Sprites.tipsy2, Sprites.tipsy2)
                proud -> listOf(Sprites.proud1, Sprites.proud2, Sprites.proud1, Sprites.proud2, Sprites.happy)
                content -> listOf(Sprites.content2, Sprites.content2, Sprites.content1, Sprites.content2, Sprites.content1, Sprites.content2)
                stuffed -> listOf(Sprites.stuffed1, Sprites.stuffed2)
                thirsty -> listOf(Sprites.thirsty1, Sprites.thirsty2, Sprites.thirsty1, Sprites.sitBlink)
                sporty -> listOf(Sprites.sporty1, Sprites.sporty2)
            }
        }

    val fps: Double
        get() = when (this) {
            eating -> 6.0
            sleeping -> 1.5
            yawning, tipsy, stuffed, thirsty -> 2.0
            else -> 3.0
        }

    companion object {
        fun of(key: String): CatMood = entries.firstOrNull { it.key == key } ?: idle
    }
}

/** Cycles through frames. */
@Composable
fun AnimatedSprite(frames: List<PixelSprite>, fps: Double = 4.0, pixel: Dp = 4.dp, palette: CatPalette? = null, modifier: Modifier = Modifier, outfit: Outfit = Outfit.None) {
    var index by remember(frames) { mutableStateOf(0) }
    LaunchedEffect(frames, fps) {
        while (true) {
            delay((1000 / fps).toLong())
            index = (index + 1) % maxOf(frames.size, 1)
        }
    }
    val w = frames.maxOf { it.width }
    val h = frames.maxOf { it.height }
    Box(modifier.size(pixel * w, pixel * h), contentAlignment = Alignment.BottomStart) {
        PixelSpriteView(frames[index.coerceIn(0, frames.size - 1)], pixel, palette, outfit = outfit)
    }
}

/** The mascot: a pixel cat that reacts to your day. */
@Composable
fun CatMascot(mood: CatMood, pixel: Dp = 5.dp, palette: CatPalette? = null, modifier: Modifier = Modifier) {
    var bounced by remember { mutableStateOf(false) }
    LaunchedEffect(mood) {
        if (mood == CatMood.eating || mood == CatMood.happy || mood == CatMood.proud) {
            bounced = true; delay(180); bounced = false
        }
    }
    val lift by animateFloatAsState(if (bounced) -2f else 0f, spring(dampingRatio = 0.4f, stiffness = Spring.StiffnessMedium), label = "bounce")
    val outfit = if (App.prefs.bool(Extras.SHOP, true)) Outfit(App.prefs.string("shop.hat", ""), App.prefs.string("shop.glasses", ""), App.prefs.string("shop.scarf", "")) else Outfit.None
    Box(modifier) {
        AnimatedSprite(mood.frames, mood.fps, pixel, palette, Modifier.offset(y = pixel * lift), outfit)
        if (mood == CatMood.sleeping) FloatingZs(pixel * 0.6f, Modifier.align(Alignment.TopEnd).offset(x = pixel * 2, y = -pixel * 4))
    }
}

/** Shared frame clock for continuous animations. */
@Composable
fun rememberTime(): Long {
    var t by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) { while (true) withFrameMillis { t = it } }
    return t
}

@Composable
fun FloatingZs(pixel: Dp, modifier: Modifier = Modifier) {
    val t = rememberTime() / 1000.0
    Box(modifier.size(pixel * 10, pixel * 16)) {
        for (i in 0 until 3) {
            val p = ((t / 2.4 + i / 3.0) % 1.0).toFloat()
            PixelSpriteView(Sprites.z, pixel * (0.6f + p * 0.6f), modifier = Modifier
                .align(Alignment.BottomStart)
                .offset(x = pixel * p * 6, y = -pixel * p * 14)
                .graphicsLayer { alpha = if (p < 0.8f) 1f else (1 - p) * 5 })
        }
    }
}

/** Little cat walking back and forth – used as loading indicator. */
@Composable
fun WalkingCatLoader(pixel: Dp = 3.dp, width: Dp = 200.dp, text: String? = null, modifier: Modifier = Modifier) {
    val t = rememberTime() / 1000.0
    val phase = (t / 3.2) % 1.0
    val forward = phase < 0.5
    val p = if (forward) phase * 2 else (1 - phase) * 2
    val frame = if ((t * 7).toInt() % 2 == 0) Sprites.walk1 else Sprites.walk2
    val spriteW = pixel * Sprites.walk1.width
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.width(width).height(pixel * Sprites.walk1.height)) {
            PixelSpriteView(if (forward) frame else frame.mirrored, pixel, modifier = Modifier.offset(x = (width - spriteW) * p.toFloat()))
        }
        Row(Modifier.width(width)) {
            repeat((width.value / 10).toInt()) {
                Box(Modifier.size(6.dp, 3.dp).background(C.line))
                Spacer(Modifier.width(4.dp))
            }
        }
        if (text != null) {
            Spacer(Modifier.height(10.dp))
            Text(text, style = font(14), color = C.textSecondary)
        }
    }
}

/** Pixel hearts bursting from a point, used when food is added. */
@Composable
fun HeartBurst(trigger: Int, modifier: Modifier = Modifier) {
    if (trigger == 0) return
    // One animation per trigger, no frame clock left running afterwards.
    val progress = remember(trigger) { androidx.compose.animation.core.Animatable(0f) }
    LaunchedEffect(trigger) { progress.animateTo(1f, androidx.compose.animation.core.tween(900, easing = androidx.compose.animation.core.LinearEasing)) }
    val p = progress.value
    if (p >= 1f) return
    val sprites = listOf(Sprites.heart, Sprites.star, Sprites.heart, Sprites.paw)
    val angles = remember(trigger) { (0 until 8).map { it / 8.0 * 2 * Math.PI + (Math.random() - 0.5) * 0.6 } }
    val radii = remember(trigger) { (0 until 8).map { 60 + Math.random() * 40 } }
    Box(modifier, contentAlignment = Alignment.Center) {
        for (i in 0 until 8) {
            val dx = (cos(angles[i]) * radii[i] * p).toFloat()
            val dy = (sin(angles[i]) * radii[i] * p - 30 * p).toFloat()
            PixelSpriteView(sprites[i % sprites.size], 3.dp, modifier = Modifier
                .offset(dx.dp, dy.dp)
                .graphicsLayer { alpha = 1 - p; scaleX = 0.4f + p * 0.8f; scaleY = 0.4f + p * 0.8f })
        }
    }
}

/** 5×5 pixel font for the logo. */
private val glyphs = mapOf(
    'P' to listOf("xxxx.", "x...x", "xxxx.", "x....", "x...."),
    'U' to listOf("x...x", "x...x", "x...x", "x...x", ".xxx."),
    'R' to listOf("xxxx.", "x...x", "xxxx.", "x..x.", "x...x"),
    'T' to listOf("xxxxx", "..x..", "..x..", "..x..", "..x.."),
    'I' to listOf("xxx", ".x.", ".x.", ".x.", "xxx"),
    'O' to listOf(".xxx.", "x...x", "x...x", "x...x", ".xxx."),
    'N' to listOf("x...x", "xx..x", "x.x.x", "x..xx", "x...x"),
    ' ' to listOf("..", "..", "..", "..", ".."),
)

@Composable
fun PixelText(text: String, pixel: Dp = 4.dp, color: Color = C.textPrimary, modifier: Modifier = Modifier) {
    val density = LocalDensity.current
    Row(modifier) {
        for ((i, ch) in text.uppercase().withIndex()) {
            val g = glyphs[ch] ?: glyphs[' ']!!
            if (i > 0) Spacer(Modifier.width(pixel))
            Canvas(Modifier.size(pixel * g[0].length, pixel * 5)) {
                val p = with(density) { pixel.toPx() }
                for ((y, row) in g.withIndex()) for ((x, c) in row.withIndex()) if (c == 'x') drawRect(color, Offset(x * p, y * p), Size(p, p))
            }
        }
    }
}

/** What the cat wears (hat, glasses, scarf), picked in the streak shop. Drawn into the pixel rows, only on the upright poses. */
data class Outfit(val hat: String = "", val glasses: String = "", val scarf: String = "") {
    val isEmpty: Boolean get() = hat.isEmpty() && glasses.isEmpty() && scarf.isEmpty()
    companion object { val None = Outfit() }
}

object Wardrobe {
    /** Hats fill the gap between the ears: columns 3-9 of rows 0-2, painted onto empty cells only. */
    private val hats = mapOf(
        "hat.party" to listOf("...y...", "..rWr..", ".rWrWr."),
        "hat.beanie" to listOf("...W...", "..bbb..", "..BbB.."),
        "hat.top" to listOf("..eee..", "..eRe..", "..eee.."),
        "hat.crown" to listOf(".y.y.y.", ".yyyyy.", "..yYy.."),
        "hat.wizard" to listOf("...B...", "..ByB..", ".BvBvB."),
    )
    private val scarves = mapOf(
        "scarf.red" to ('r' to 'R'), "scarf.blue" to ('b' to 'B'), "scarf.green" to ('g' to 'G'), "scarf.gold" to ('y' to 'Y'), "scarf.violet" to ('v' to 'V'),
    )

    fun apply(outfit: Outfit, sprite: PixelSprite): PixelSprite {
        if (outfit.isEmpty || sprite.rows.size != 16 || !sprite.rows[0].startsWith("..o.......o..") || !sprite.rows[4].startsWith("owwwswswswwwo")) return sprite
        val grid = sprite.rows.map { it.toCharArray() }
        fun put(row: Int, col: Int, ch: Char, onlyEmpty: Boolean = false) {
            if (ch == '.' || row >= grid.size || col >= grid[row].size) return
            if (onlyEmpty && grid[row][col] != '.') return
            grid[row][col] = ch
        }
        hats[outfit.hat]?.forEachIndexed { r, line -> line.forEachIndexed { i, ch -> put(r, 3 + i, ch, onlyEmpty = true) } }
        if (outfit.glasses == "glasses.round" || outfit.glasses == "glasses.sun") {
            val sun = outfit.glasses == "glasses.sun"
            val frame = if (sun) 'e' else 'B'
            for (start in listOf(2, 7)) {
                for (c in start..start + 3) { put(4, c, frame); put(7, c, frame) }
                for (r in 5..6) { put(r, start, frame); put(r, start + 3, frame) }
                if (sun) for (r in 5..6) { put(r, start + 1, 'e'); put(r, start + 2, 'e') }
            }
            put(5, 6, frame)
        }
        scarves[outfit.scarf]?.let { (a, b) ->
            for ((i, c) in (2..10).withIndex()) put(9, c, if (i % 2 == 0) a else b)
            put(10, 5, a); put(10, 6, b); put(11, 5, b)
        }
        return PixelSprite(grid.map { String(it) })
    }
}
