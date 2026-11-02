package com.enesseval.kilitkelime.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

val TR: Locale = Locale.forLanguageTag("tr-TR")

/** White (dark: charcoal) card with a hairline border (`surfaceCard`). */
@Composable
fun Modifier.surfaceCard(radius: Dp = 22.dp, padding: Dp = 18.dp): Modifier {
    val c = Palette.current
    val shape = RoundedCornerShape(radius)
    return this.fillMaxWidth().clip(shape).background(c.surface, shape).border(1.dp, c.line, shape).padding(padding)
}

@Composable
fun SurfaceCard(modifier: Modifier = Modifier, radius: Dp = 22.dp, padding: Dp = 18.dp, onClick: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val c = Palette.current
    val shape = RoundedCornerShape(radius)
    Column(
        modifier = modifier.fillMaxWidth().clip(shape).background(c.surface, shape).border(1.dp, c.line, shape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).padding(padding),
        content = content,
    )
}

/** Large screen title (32 bold) with an optional kicker. */
@Composable
fun ScreenTitle(title: String, kicker: String? = null) {
    val c = Palette.current
    Column {
        if (kicker != null) Text(kicker, style = KelimeType.ui(13.sp, FontWeight.Medium), color = c.ink2)
        Text(title, style = KelimeType.ui(32.sp, FontWeight.Bold).copy(letterSpacing = (-0.6).sp), color = c.ink, modifier = Modifier.semantics { heading() })
    }
}

@Composable
fun Kicker(text: String, color: Color = Palette.current.ink2) {
    Text(text, style = KelimeType.ui(11.sp, FontWeight.SemiBold).copy(letterSpacing = 0.9.sp), color = color)
}

/** Filled accent button (Başla, Hızlı Tekrar …). */
@Composable
fun PrimaryButton(text: String, modifier: Modifier = Modifier, height: Dp = 50.dp, enabled: Boolean = true, onClick: () -> Unit) {
    val c = Palette.current
    Box(
        modifier = modifier.fillMaxWidth().heightIn(min = height).clip(RoundedCornerShape(14.dp))
            .background(if (enabled) c.accent else c.accent.copy(alpha = 0.4f))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.onAccent)
    }
}

/** Soft tinted button (Biliyorum / Zorlanıyorum, Devam et …). */
@Composable
fun TintedButton(
    text: String,
    modifier: Modifier = Modifier,
    ink: Color = Palette.current.ink,
    background: Color = Palette.current.surface2,
    fullWidth: Boolean = true,
    height: Dp = 44.dp,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier.then(if (fullWidth) Modifier.fillMaxWidth() else Modifier).heightIn(min = height)
            .clip(RoundedCornerShape(if (fullWidth) 14.dp else 12.dp)).background(background)
            .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 18.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = KelimeType.ui(if (fullWidth) 16.sp else 14.sp, FontWeight.SemiBold), color = ink)
    }
}

@Composable
fun OutlineButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = Palette.current
    Box(
        modifier = modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).border(1.dp, c.line, RoundedCornerShape(12.dp))
            .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.ink)
    }
}

/** Segmented control drawn like the design: surface2 track, raised selection. */
@Composable
fun <T> SegmentedPicker(options: List<T>, selection: T, label: (T) -> String, modifier: Modifier = Modifier, onSelect: (T) -> Unit) {
    val c = Palette.current
    Row(
        modifier = modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).background(c.surface2).padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        for (option in options) {
            val selected = option == selection
            Box(
                modifier = Modifier.weight(1f).heightIn(min = 34.dp).clip(RoundedCornerShape(8.dp))
                    .background(if (selected) c.surface else Color.Transparent)
                    .clickable(role = Role.Tab) { onSelect(option) },
                contentAlignment = Alignment.Center,
            ) {
                Text(label(option), style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = if (selected) c.ink else c.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** Small round progress bar (4 dp). */
@Composable
fun ThinProgressBar(fraction: Double, modifier: Modifier = Modifier, color: Color = Palette.current.green) {
    val c = Palette.current
    Box(modifier = modifier.fillMaxWidth().height(4.dp).clip(CircleShape).background(c.surface2).semantics { contentDescription = "%${(fraction * 100).toInt()}" }) {
        Box(modifier = Modifier.fillMaxWidth(fraction.coerceIn(0.0, 1.0).toFloat()).height(4.dp).clip(CircleShape).background(color))
    }
}

/** Word state by shape, readable in monochrome: ○ yeni · ◐ zorlanılan · ● öğrenildi. */
@Composable
fun StateDot(state: LearningState, size: Dp = 10.dp, color: Color? = null) {
    val tint = color ?: Palette.current.state(state)
    Canvas(modifier = Modifier.size(size).semantics { contentDescription = state.label }) {
        val stroke = maxOf(1.5.dp.toPx(), size.toPx() * 0.16f)
        val r = this.size.minDimension / 2
        when (state) {
            LearningState.NEW -> drawCircle(tint, r - stroke / 2, style = Stroke(stroke))
            LearningState.STRUGGLING -> {
                drawCircle(tint, r - stroke / 2, style = Stroke(stroke))
                drawArc(tint, 90f, 180f, true, topLeft = Offset.Zero, size = Size(r * 2, r * 2))
            }
            LearningState.LEARNED -> drawCircle(tint, r)
        }
    }
}

@Composable
fun LevelChip(level: CEFRLevel, size: Int = 11) {
    val c = Palette.current
    Text(
        level.raw,
        style = KelimeType.ui(size.sp, FontWeight.SemiBold),
        color = c.ink2,
        modifier = Modifier.clip(RoundedCornerShape((size * 0.45).dp)).background(c.surface2).padding(vertical = (size * 0.27).dp, horizontal = (size * 0.55).dp),
    )
}

@Composable
fun StateChip(state: LearningState) {
    val c = Palette.current
    val (fg, bg) = when (state) {
        LearningState.NEW -> c.ink2 to c.surface2
        LearningState.STRUGGLING -> c.amberInk to c.amberBackground
        LearningState.LEARNED -> c.greenInk to c.greenBackground
    }
    Row(
        modifier = Modifier.clip(CircleShape).background(bg).padding(vertical = 4.dp, horizontal = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        StateDot(state, 8.dp, fg)
        Text(state.label, style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = fg)
    }
}

@Composable
fun ProBadge() {
    val c = Palette.current
    Text("PRO", style = KelimeType.ui(11.sp, FontWeight.Bold), color = c.accent, modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(c.surface2).padding(vertical = 4.dp, horizontal = 8.dp))
}

/** A card with a "PRO" corner tag for free users. */
@Composable
fun ProCorner(show: Boolean, content: @Composable BoxScope.() -> Unit) {
    val c = Palette.current
    Box {
        content()
        if (show) {
            Text(
                "PRO",
                style = KelimeType.ui(10.sp, FontWeight.Bold),
                color = c.onAccent,
                modifier = Modifier.align(Alignment.TopEnd).clip(RoundedCornerShape(topEnd = 22.dp, bottomStart = 8.dp)).background(c.accent)
                    .padding(start = 9.dp, end = 8.dp, top = 4.dp, bottom = 4.dp),
            )
        }
    }
}

/** Settings group: caption above a rounded surface. */
@Composable
fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    val c = Palette.current
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = KelimeType.ui(12.sp, FontWeight.SemiBold).copy(letterSpacing = 0.7.sp), color = c.ink2, modifier = Modifier.padding(start = 4.dp))
        Column(
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(c.surface).border(1.dp, c.line, RoundedCornerShape(16.dp)),
            content = content,
        )
    }
}

@Composable
fun SettingsRow(title: String, detail: String? = null, onClick: (() -> Unit)? = null, trailing: @Composable RowScope.() -> Unit = {
    if (onClick != null) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Palette.current.ink2)
}) {
    val c = Palette.current
    Row(
        modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = KelimeType.ui(15.sp), color = c.ink)
            if (detail != null) Text(detail, style = KelimeType.ui(13.sp), color = c.ink2)
        }
        trailing()
    }
}

@Composable
fun SettingsToggle(title: String, checked: Boolean, detail: String? = null, enabled: Boolean = true, onChange: (Boolean) -> Unit) {
    val c = Palette.current
    SettingsRow(title, detail, onClick = if (enabled) ({ onChange(!checked) }) else null) {
        Switch(
            checked = checked, onCheckedChange = onChange, enabled = enabled,
            colors = SwitchDefaults.colors(checkedTrackColor = c.green, checkedThumbColor = Color.White, uncheckedTrackColor = c.surface2, uncheckedBorderColor = c.line),
        )
    }
}

@Composable
fun Divider() {
    Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.current.line))
}

/** Transient message at the bottom of the screen. */
@Composable
fun BoxScope.Toast(message: String?, onDone: () -> Unit) {
    val c = Palette.current
    LaunchedEffect(message) {
        if (message != null) {
            delay(2200)
            onDone()
        }
    }
    AnimatedVisibility(
        visible = message != null,
        enter = slideInVertically { it } + fadeIn(),
        exit = slideOutVertically { it } + fadeOut(),
        modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp),
    ) {
        Text(
            message ?: "",
            style = KelimeType.ui(14.sp, FontWeight.Medium),
            color = c.ink,
            modifier = Modifier.clip(CircleShape).background(c.surface).border(BorderStroke(1.dp, c.line), CircleShape).padding(vertical = 12.dp, horizontal = 18.dp),
        )
    }
}

/** "13 Ekim, Salı". */
object TurkishDate {
    fun header(day: LocalDate): String {
        val month = day.format(DateTimeFormatter.ofPattern("d MMMM", TR))
        val weekday = day.format(DateTimeFormatter.ofPattern("EEEE", TR))
        return "$month, $weekday"
    }

    fun long(day: LocalDate): String = day.format(DateTimeFormatter.ofPattern("d MMMM yyyy", TR))
}

@Composable
fun Gap(height: Dp) = Spacer(Modifier.height(height))

@Composable
fun HGap(width: Dp) = Spacer(Modifier.width(width))

@Composable
fun EmptyText(text: String) {
    Text(text, style = KelimeType.ui(15.sp), color = Palette.current.ink2, modifier = Modifier.widthIn(max = 420.dp).padding(vertical = 24.dp))
}
