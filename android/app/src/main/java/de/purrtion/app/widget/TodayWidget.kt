package de.purrtion.app.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import de.purrtion.app.App
import de.purrtion.app.MainActivity
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.pixel.CatPalette
import de.purrtion.app.ui.pixel.PixelSprite
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.ui.theme.Palette
import kotlin.math.abs
import kotlin.math.min

/** Home screen widget: ring with the cat, remaining kcal and macros – like the iOS widget. */
class TodayWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        App.init(context)
        val s = WidgetSnapshot.load().forToday()
        val dark = (context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val ring = renderRing(s, dark)
        provideContent { GlanceTheme { Content(s, ring, dark) } }
    }

    @Composable
    private fun Content(s: WidgetSnapshot, ring: Bitmap, dark: Boolean) {
        val bg = if (dark) Palette.dark.card else Palette.light.card
        val text = if (dark) Palette.dark.textPrimary else Palette.light.textPrimary
        val secondary = if (dark) Palette.dark.textSecondary else Palette.light.textSecondary
        val remaining = s.kcalGoal - s.kcal
        Row(
            modifier = GlanceModifier.fillMaxSize().background(bg).cornerRadius(24.dp).padding(14.dp)
                .clickable(actionStartActivity<MainActivity>()),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Image(ImageProvider(ring), contentDescription = null, modifier = GlanceModifier.size(110.dp))
            Spacer(GlanceModifier.width(12.dp))
            Column {
                Text(if (remaining >= 0) "Übrig" else "Drüber", style = TextStyle(color = ColorProvider(secondary), fontSize = 13.sp))
                Text(abs(remaining).kcalString, style = TextStyle(color = ColorProvider(if (remaining >= 0) text else Palette.danger),
                    fontSize = 30.sp, fontWeight = FontWeight.Bold))
                Text("von ${s.kcalGoal.kcalString} kcal", style = TextStyle(color = ColorProvider(secondary), fontSize = 12.sp))
                Spacer(GlanceModifier.height(6.dp))
                Text("P ${s.protein.toInt()} · K ${s.carbs.toInt()} · F ${s.fat.toInt()} g",
                    style = TextStyle(color = ColorProvider(secondary), fontSize = 12.sp))
                s.score?.let { Text("Health Score $it", style = TextStyle(color = ColorProvider(Palette.fiber), fontSize = 12.sp, fontWeight = FontWeight.Bold)) }
            }
        }
    }

    private fun catSprite(s: WidgetSnapshot): PixelSprite = when {
        s.entryCount == 0 -> Sprites.sleep1
        s.progress > 1.15 -> Sprites.stuffed1
        s.progress > 1.05 -> Sprites.full
        s.progress >= 0.95 -> if (s.protein >= s.proteinGoal * 0.9) Sprites.proud1 else Sprites.content2
        s.progress >= 0.85 -> if (s.protein >= s.proteinGoal * 0.9) Sprites.proud1 else Sprites.happy
        else -> Sprites.sit
    }

    private fun renderRing(s: WidgetSnapshot, dark: Boolean): Bitmap {
        val size = 330
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val stroke = 34f
        val rect = RectF(stroke / 2, stroke / 2, size - stroke / 2, size - stroke / 2)
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = stroke; color = (if (dark) Palette.dark.cardAlt else Palette.light.cardAlt).toArgb() }
        c.drawArc(rect, 0f, 360f, false, track)
        val progress = s.progress
        val color = when {
            progress > 1.05 -> Palette.danger
            progress > 1.0 -> Palette.accent
            else -> Palette.accent
        }
        val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = stroke; strokeCap = Paint.Cap.ROUND; this.color = color.toArgb() }
        c.drawArc(rect, -90f, 360f * min(progress, 1.0).toFloat(), false, arc)
        val palette = CatPalette.byId(s.paletteID)
        val sprite = catSprite(s).let { if (palette.isDog) de.purrtion.app.ui.pixel.DogSprites.convert(it) else it }
        val px = 9f
        val ox = (size - sprite.width * px) / 2
        val oy = (size - sprite.height * px) / 2 + 6
        val p = Paint()
        for ((y, row) in sprite.rows.withIndex()) for ((x, ch) in row.withIndex()) {
            val col = palette.color(ch, dark) ?: continue
            p.color = col.toArgb()
            c.drawRect(ox + x * px, oy + y * px, ox + (x + 1) * px + 0.5f, oy + (y + 1) * px + 0.5f, p)
        }
        return bmp
    }
}

class TodayWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TodayWidget()
}
