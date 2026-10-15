package de.purrtion.app.ui

import androidx.compose.animation.AnimatedVisibility
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
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var splash by remember { mutableStateOf(true) }
    val friendsEnabled = App.prefs.bool(FriendsStore.ENABLED_KEY, true) && FirebaseConfig.isAvailable
    val tabs = listOfNotNull(
        TabItem(0, "Heute", Icons.Rounded.Pets),
        TabItem(1, "Verlauf", Icons.Rounded.BarChart),
        if (friendsEnabled) TabItem(3, "Freunde", Icons.Rounded.Group) else null,
        TabItem(2, "Einstellungen", Icons.Rounded.Settings),
    )
    LaunchedEffect(Unit) { delay(1300); splash = false }
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

/** Falling cat, pixel logo and a cat running along the loading bar – like the iOS splash. */
@Composable
private fun Splash() {
    var landed by remember { mutableStateOf(false) }
    val drop by animateDpAsState(if (landed) 0.dp else (-260).dp, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessLow), label = "drop")
    LaunchedEffect(Unit) { landed = true }
    Box(Modifier.fillMaxSize().background(C.background), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            AnimatedSprite(if (landed) CatMood.happy.frames else listOf(Sprites.sit), 4.0, 8.dp, modifier = Modifier.offset(y = drop))
            Spacer(Modifier.height(24.dp))
            PixelText("PURRTION", 6.dp, Palette.accent)
            Spacer(Modifier.height(28.dp))
            de.purrtion.app.ui.pixel.WalkingCatLoader(2.5.dp, 180.dp)
        }
    }
}

