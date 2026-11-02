package com.enesseval.kilitkelime.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette

/** A pushed screen: back arrow, centred title, optional actions. */
@Composable
fun TopBar(title: String = "", close: Boolean = false, onBack: (() -> Unit)? = null, actions: @Composable RowScope.() -> Unit = {}) {
    val c = Palette.current
    val router = LocalRouter.current
    Box(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 4.dp)) {
        IconButton(onClick = onBack ?: { router.back() }, modifier = Modifier.align(Alignment.CenterStart)) {
            Icon(if (close) Icons.Default.Close else Icons.AutoMirrored.Filled.ArrowBack, contentDescription = if (close) "Kapat" else "Geri", tint = c.ink)
        }
        Text(
            title, style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.ink, maxLines = 1, overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center, modifier = Modifier.align(Alignment.Center).padding(horizontal = 64.dp),
        )
        Row(Modifier.align(Alignment.CenterEnd), verticalAlignment = Alignment.CenterVertically, content = actions)
    }
}

/** Background, status bar inset, top bar and a scrolling column: the frame of most pushed screens. */
@Composable
fun PushedScreen(
    title: String = "",
    close: Boolean = false,
    horizontal: Dp = 20.dp,
    actions: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    val c = Palette.current
    Column(Modifier.fillMaxSize().background(c.background).statusBarsPadding()) {
        TopBar(title, close, actions = actions)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = horizontal).padding(bottom = 32.dp),
            content = content,
        )
    }
}
