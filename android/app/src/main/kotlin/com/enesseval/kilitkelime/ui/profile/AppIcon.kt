package com.enesseval.kilitkelime.ui.profile

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette

/**
 * Profil › Uygulama ikonu (port of `AppIconPicker.swift`): the cream icon or the blue or orange
 * one. Each is a launcher `activity-alias` in the manifest; exactly one is enabled.
 */
enum class AppIconChoice(val alias: String, val label: String, val background: Color, val ink: Color) {
    STANDARD("IconCream", "Krem", Color(0xFFF4F1EB), Color(0xFF1B1916)),
    BLUE("IconBlue", "Mavi", Color(0xFF335AA6), Color(0xFFF4F1EB)),
    ORANGE("IconOrange", "Turuncu", Color(0xFFE49839), Color(0xFF1B1916));

    private fun component(context: Context) = ComponentName(context.packageName, "com.enesseval.kilitkelime.$alias")

    companion object {
        fun current(context: Context): AppIconChoice {
            val pm = context.packageManager
            return entries.firstOrNull { choice ->
                when (pm.getComponentEnabledSetting(choice.component(context))) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> choice == STANDARD // the manifest default
                    else -> false
                }
            } ?: STANDARD
        }

        /** Enables [choice] first, then disables the others, so the app always has a launcher entry. */
        fun set(context: Context, choice: AppIconChoice) {
            val pm = context.packageManager
            pm.setComponentEnabledSetting(choice.component(context), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            for (other in entries) if (other != choice) {
                pm.setComponentEnabledSetting(other.component(context), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        }
    }
}

@Composable
fun AppIconRow() {
    val context = LocalContext.current
    val c = Palette.current
    var selected by remember { mutableStateOf(AppIconChoice.current(context)) }
    Row(
        Modifier.fillMaxWidth().heightIn(min = 58.dp).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Uygulama ikonu", style = KelimeType.ui(15.sp), color = c.ink)
        Spacer(Modifier.weight(1f))
        for (choice in AppIconChoice.entries) {
            val isSelected = choice == selected
            Box(
                Modifier.clip(RoundedCornerShape(12.dp))
                    .border(if (isSelected) 2.dp else 0.dp, if (isSelected) c.accent else Color.Transparent, RoundedCornerShape(12.dp))
                    .clickable {
                        if (choice != selected) {
                            AppIconChoice.set(context, choice)
                            selected = choice
                        }
                    }
                    .padding(3.dp)
                    .semantics { contentDescription = choice.label; this.selected = isSelected },
            ) {
                Box(
                    Modifier.size(36.dp).clip(RoundedCornerShape(9.dp)).background(choice.background).border(1.dp, c.line, RoundedCornerShape(9.dp)),
                    contentAlignment = Alignment.Center,
                ) { Text("k", style = KelimeType.english(22.sp), color = choice.ink) }
            }
        }
    }
}
