package com.enesseval.kilitkelime.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.R
import com.enesseval.kilitkelime.core.model.LearningState

/** Colour tokens from KelimeUI/Palette.swift. Brand colours only; dynamic colour is off. */
@Immutable
data class KelimeColors(
    val background: Color,
    val surface: Color,
    val surface2: Color,
    val paper: Color,
    val ink: Color,
    val ink2: Color,
    val line: Color,
    val accent: Color,
    val accentSoft: Color,
    val onAccent: Color,
    /** Zorlanılan. Never red. */
    val amber: Color,
    val amberBackground: Color,
    val amberInk: Color,
    /** Öğrenildi. */
    val green: Color,
    val greenBackground: Color,
    val greenInk: Color,
    val isDark: Boolean,
) {
    fun state(state: LearningState) = when (state) {
        LearningState.NEW -> ink2
        LearningState.STRUGGLING -> amber
        LearningState.LEARNED -> green
    }
}

val LightColors = KelimeColors(
    background = Color(0xFFF4F1EB), surface = Color(0xFFFFFFFF), surface2 = Color(0xFFEAE6DE), paper = Color(0xFFFBF9F5),
    ink = Color(0xFF1B1916), ink2 = Color(0xFF6A6359), line = Color(0xFF1B1916).copy(alpha = 0.11f),
    accent = Color(0xFF335AA6), accentSoft = Color(0xFFE2ECFD), onAccent = Color(0xFFFFFFFF),
    amber = Color(0xFFE49839), amberBackground = Color(0xFFFFECCD), amberInk = Color(0xFF915114),
    green = Color(0xFF50986B), greenBackground = Color(0xFFE0F5E6), greenInk = Color(0xFF285F3F),
    isDark = false,
)

val DarkColors = KelimeColors(
    background = Color(0xFF121110), surface = Color(0xFF1C1B19), surface2 = Color(0xFF2A2825), paper = Color(0xFF1C1B19),
    ink = Color(0xFFF2EEE7), ink2 = Color(0xFFA39C91), line = Color(0xFFF2EEE7).copy(alpha = 0.11f),
    accent = Color(0xFF8BB1F7), accentSoft = Color(0xFF1B2942), onAccent = Color(0xFF121110),
    amber = Color(0xFFEEAC53), amberBackground = Color(0xFF442A08), amberInk = Color(0xFFFBC77C),
    green = Color(0xFF75BE8F), greenBackground = Color(0xFF1A3123), greenInk = Color(0xFFA1DBB4),
    isDark = true,
)

val LocalKelimeColors = staticCompositionLocalOf { LightColors }

/** The three bundled typefaces (KelimeFont): variable fonts, weights set through 'wght'. */
@OptIn(ExperimentalTextApi::class)
object KelimeFonts {
    private fun family(res: Int, italic: Boolean = false) = FontFamily(
        listOf(300, 400, 500, 600, 700).map { w ->
            Font(
                res,
                weight = FontWeight(w),
                style = if (italic) FontStyle.Italic else FontStyle.Normal,
                variationSettings = FontVariation.Settings(FontVariation.weight(w)),
            )
        },
    )

    /** English words and sentences. */
    val english: FontFamily = FontFamily(
        listOf(300, 400, 500, 600, 700).flatMap { w ->
            listOf(
                Font(R.font.newsreader, FontWeight(w), FontStyle.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(w))),
                Font(R.font.newsreader_italic, FontWeight(w), FontStyle.Italic, variationSettings = FontVariation.Settings(FontVariation.weight(w))),
            )
        },
    )

    /** Turkish text and UI. */
    val ui: FontFamily = family(R.font.hankengrotesk)

    /** Self-test letter blanks. */
    val mono: FontFamily = family(R.font.jetbrainsmono)
}

/** Text styles mirroring `KelimeFont.english(size)` and `KelimeFont.ui(size, weight)`. */
object KelimeType {
    fun english(size: TextUnit, italic: Boolean = false, weight: FontWeight = FontWeight.Normal) =
        TextStyle(fontFamily = KelimeFonts.english, fontSize = size, fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal, fontWeight = weight)

    fun ui(size: TextUnit, weight: FontWeight = FontWeight.Normal) =
        TextStyle(fontFamily = KelimeFonts.ui, fontSize = size, fontWeight = weight)

    fun mono(size: TextUnit, weight: FontWeight = FontWeight.Medium) =
        TextStyle(fontFamily = KelimeFonts.mono, fontSize = size, fontWeight = weight)
}

@Composable
fun KelimeTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val c = if (dark) DarkColors else LightColors
    val scheme = if (dark) {
        darkColorScheme(
            primary = c.accent, onPrimary = c.onAccent, background = c.background, onBackground = c.ink,
            surface = c.surface, onSurface = c.ink, surfaceVariant = c.surface2, onSurfaceVariant = c.ink2,
            outline = c.line, secondary = c.green, tertiary = c.amber,
        )
    } else {
        lightColorScheme(
            primary = c.accent, onPrimary = c.onAccent, background = c.background, onBackground = c.ink,
            surface = c.surface, onSurface = c.ink, surfaceVariant = c.surface2, onSurfaceVariant = c.ink2,
            outline = c.line, secondary = c.green, tertiary = c.amber,
        )
    }
    val base = KelimeType.ui(15.sp)
    val typography = Typography(
        bodyLarge = base.copy(fontSize = 16.sp), bodyMedium = base, bodySmall = base.copy(fontSize = 13.sp),
        titleLarge = base.copy(fontSize = 22.sp, fontWeight = FontWeight.SemiBold),
        titleMedium = base.copy(fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
        labelLarge = base.copy(fontSize = 15.sp, fontWeight = FontWeight.SemiBold),
        labelMedium = base.copy(fontSize = 13.sp, fontWeight = FontWeight.Medium),
    )
    CompositionLocalProvider(LocalKelimeColors provides c) {
        MaterialTheme(colorScheme = scheme, typography = typography, content = content)
    }
}

/** Shorthand: `Palette.current.ink`. */
object Palette {
    val current: KelimeColors
        @Composable get() = LocalKelimeColors.current
}
