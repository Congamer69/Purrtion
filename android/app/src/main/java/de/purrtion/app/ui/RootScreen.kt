package de.purrtion.app.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.Group
import androidx.compose.material.icons.rounded.Pets
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import de.purrtion.app.App
import de.purrtion.app.MainActivity
import de.purrtion.app.domain.FirebaseConfig
import de.purrtion.app.domain.FriendsStore
import de.purrtion.app.ui.pixel.AnimatedSprite
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.pixel.PixelText
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.ui.screens.FriendsScreen
import de.purrtion.app.ui.screens.OnboardingScreen
import de.purrtion.app.ui.screens.SettingsScreen
import de.purrtion.app.ui.screens.StatsScreen
import de.purrtion.app.ui.screens.TodayScreen
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.delay

private data class TabItem(val id: Int, val title: String, val icon: ImageVector)

@Composable
fun RootScreen(activity: MainActivity) {
    var tab by rememberSaveable { mutableIntStateOf(App.prefs.int("startTab", 0)) }
    var splash by remember { mutableStateOf(true) }
    val friendsEnabled = App.prefs.bool(FriendsStore.ENABLED_KEY, true) && FirebaseConfig.isAvailable
    val tabs = listOfNotNull(
        TabItem(0, "Heute", Icons.Rounded.Pets),
        TabItem(1, "Verlauf", Icons.Rounded.BarChart),
        if (friendsEnabled) TabItem(3, "Freunde", Icons.Rounded.Group) else null,
        TabItem(2, "Einstellungen", Icons.Rounded.Settings),
    )
    LaunchedEffect(Unit) { delay(1550); splash = false }
    LaunchedEffect(activity.reviewDay) { if (activity.reviewDay != null) tab = 0 }
    LaunchedEffect(activity.openFriends) { if (activity.openFriends) { tab = 3; activity.openFriends = false } }
    LaunchedEffect(friendsEnabled) { if (!friendsEnabled && tab == 3) tab = 2 }

    Box(Modifier.fillMaxSize().background(C.background)) {
        when (tab) {
            0 -> TodayScreen(activity)
            1 -> StatsScreen()
            3 -> FriendsScreen()
            else -> SettingsScreen()
        }
        // Soft fade behind the floating tab bar instead of a hard band.
        Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth()
            .height(WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 130.dp)
            .background(bottomFade()))
        TabBar(tabs, tab, Modifier.align(Alignment.BottomCenter)) { tab = it }
        Nav.Host()
        if (!App.goals.onboarded && !splash) OnboardingScreen()
        AnimatedVisibility(splash, exit = fadeOut(tween(400)) + scaleOut(tween(400), targetScale = 1.15f)) { Splash() }
    }
}

@Composable
private fun TabBar(tabs: List<TabItem>, selected: Int, modifier: Modifier, onSelect: (Int) -> Unit) {
    val h = rememberHaptics()
    Row(
        modifier.navigationBarsPadding().padding(horizontal = 22.dp, vertical = 8.dp).fillMaxWidth()
            .shadow(16.dp, CircleShape).clip(CircleShape).background(C.card).padding(5.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        for (t in tabs) {
            val on = t.id == selected
            Column(
                Modifier.weight(1f).clip(CircleShape).background(if (on) C.cardAlt else C.card)
                    .clickable(remember { MutableInteractionSource() }, null) { h.select(); onSelect(t.id) }
                    .padding(vertical = 7.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(t.icon, t.title, Modifier.size(24.dp), tint = if (on) Palette.accent else C.textPrimary)
                Text(t.title, style = font(11, FontWeight.SemiBold), color = if (on) Palette.accent else C.textPrimary, maxLines = 1)
            }
        }
    }
}

/**
 * Splash like on iOS: a plate pops up, the cat drops onto it, a ring draws around it and the letters rise one by one.
 * Light: the accent fills the screen. Dark: the app's background setting (warm, neutral or black) with the accent on the details.
 */
@Composable
private fun Splash() {
    val dark = C.dark
    val bg = if (dark) C.background else Palette.accent
    val plate = if (dark) C.card else Color(0xFFFFF3E4)
    val ink = if (dark) Palette.accent else Color(0xFFFFF3E4)
    val word = "PURRTION"
    val disc = remember { Animatable(0.05f) }
    val cat = remember { Animatable(0f) }
    val ring = remember { Animatable(0f) }
    val letters = remember { word.map { Animatable(0f) } }
    LaunchedEffect(Unit) {
        coroutineScope {
            launch { disc.animateTo(1f, spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessMediumLow)) }
            launch { delay(140); cat.animateTo(1f, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessLow)) }
            launch { delay(300); ring.animateTo(1f, tween(950, easing = FastOutSlowInEasing)) }
            letters.forEachIndexed { i, a -> launch { delay(450L + i * 45L); a.animateTo(1f, tween(400, easing = FastOutSlowInEasing)) } }
        }
    }
    Box(Modifier.fillMaxSize().background(bg), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(224.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.size(184.dp).graphicsLayer { scaleX = disc.value; scaleY = disc.value }
                    .shadow(14.dp, CircleShape, clip = false).clip(CircleShape).background(plate))
                Canvas(Modifier.size(216.dp)) {
                    val w = 7.dp.toPx()
                    drawArc(ink.copy(alpha = 0.9f), -90f, 360f * ring.value, false, Offset(w / 2, w / 2),
                        Size(size.width - w, size.height - w), style = Stroke(w, cap = StrokeCap.Round))
                }
                AnimatedSprite(if (cat.value > 0.5f) CatMood.happy.frames else listOf(Sprites.sit), 4.0, 7.dp,
                    modifier = Modifier.offset(y = (-4 - (1 - cat.value) * 196).dp).graphicsLayer { alpha = minOf(1f, cat.value * 2f) })
            }
            Spacer(Modifier.height(40.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                word.forEachIndexed { i, ch ->
                    val a = letters[i].value
                    PixelText(ch.toString(), 5.dp, ink, Modifier.offset(y = ((1 - a) * 16).dp).graphicsLayer { alpha = a })
                }
            }
        }
    }
}
