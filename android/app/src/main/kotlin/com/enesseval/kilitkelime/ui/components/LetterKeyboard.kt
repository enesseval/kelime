package com.enesseval.kilitkelime.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Backspace
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette

/**
 * Custom English A–Z keyboard with backspace, for Quick Review and the crossword. Never the
 * system keyboard: with a Turkish locale it would turn "i" into "İ".
 */
@Composable
fun LetterKeyboard(keyHeight: Dp = 44.dp, onLetter: (Char) -> Unit, onDelete: () -> Unit) {
    val c = Palette.current
    val haptics = LocalHapticFeedback.current
    val rows = listOf("QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM")
    BoxWithConstraints(Modifier.fillMaxWidth().background(c.surface2).navigationBarsPadding().padding(top = 8.dp, bottom = 10.dp, start = 4.dp, end = 4.dp)) {
        val gap = 5.dp
        val keyWidth = minOf((maxWidth - gap * 9) / 10, 44.dp)
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(9.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            rows.forEachIndexed { index, row ->
                Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                    for (letter in row) {
                        Key(keyWidth, keyHeight, letter.toString()) {
                            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onLetter(letter)
                        }
                    }
                    if (index == 2) {
                        Box(
                            Modifier.width(keyWidth * 1.5f).height(keyHeight).shadow(1.dp, RoundedCornerShape(6.dp)).clip(RoundedCornerShape(6.dp))
                                .background(c.surface).clickable(onClick = onDelete).semantics { contentDescription = "Sil" },
                            contentAlignment = Alignment.Center,
                        ) { Icon(Icons.AutoMirrored.Outlined.Backspace, null, tint = c.ink) }
                    }
                }
            }
        }
    }
}

@Composable
private fun Key(width: Dp, height: Dp, label: String, onClick: () -> Unit) {
    val c = Palette.current
    Box(
        Modifier.width(width).height(height).shadow(1.dp, RoundedCornerShape(6.dp)).clip(RoundedCornerShape(6.dp)).background(c.surface).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = KelimeType.ui(if (height > 44.dp) 22.sp else 19.sp), color = c.ink)
    }
}
