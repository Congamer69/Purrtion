package de.purrtion.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.ui.Modifier
import de.purrtion.app.ui.theme.C
import java.util.UUID

/**
 * Minimal navigation: screens are pushed on a stack and shown above the tabs – like sheets and pushed views on iOS.
 * Sheets slide up from the bottom, pages slide in from the right.
 */
object Nav {
    class Entry(val sheet: Boolean, val content: @Composable () -> Unit) {
        val id: String = UUID.randomUUID().toString()
        val visible = MutableTransitionState(false).apply { targetState = true }
    }

    val stack = mutableStateListOf<Entry>()

    fun sheet(content: @Composable () -> Unit) { stack += Entry(true, content) }
    fun push(content: @Composable () -> Unit) { stack += Entry(false, content) }

    /** Closes the top screen. */
    fun pop() { stack.lastOrNull { it.visible.targetState }?.visible?.targetState = false }

    /** Closes the top-most sheet including the pages pushed on top of it. */
    fun dismissSheet() {
        val i = stack.indexOfLast { it.sheet && it.visible.targetState }
        if (i < 0) return
        for (j in i until stack.size) stack[j].visible.targetState = false
    }

    fun popAll() { stack.forEach { it.visible.targetState = false } }

    @Composable
    fun Host() {
        for (entry in stack.toList()) {
            key(entry.id) {
                AnimatedVisibility(
                    visibleState = entry.visible,
                    enter = if (entry.sheet) slideInVertically(tween(320)) { it } + fadeIn(tween(200)) else slideInHorizontally(tween(280)) { it },
                    exit = if (entry.sheet) slideOutVertically(tween(260)) { it } + fadeOut(tween(260)) else slideOutHorizontally(tween(240)) { it },
                ) {
                    Box(Modifier.fillMaxSize().background(C.background)) { entry.content() }
                }
                // Remove once the exit animation finished.
                if (!entry.visible.targetState && entry.visible.isIdle) {
                    LaunchedEffect(entry.id) { stack.remove(entry) }
                }
            }
        }
        BackHandler(enabled = stack.any { it.visible.targetState }) { pop() }
    }
}

@Composable
private fun key(id: String, content: @Composable () -> Unit) = androidx.compose.runtime.key(id) { content() }
