package com.enesseval.kilitkelime.ui.share

import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.SegmentedPicker
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.word.ShareCard

/** Bottom sheet: preview of a 9:16 share card, the three looks, and Paylaş. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShareCardSheet(content: ShareCard.Content, signal: String = Analytics.Signal.SHARE_CARD, onDismiss: () -> Unit) {
    val c = Palette.current
    val context = LocalContext.current
    var look by remember { mutableStateOf(ShareCard.Look.LIGHT) }
    val preview = remember(look, content) { ShareCard.render(context, content, look).asImageBitmap() }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = c.background) {
        Column(Modifier.padding(horizontal = 20.dp).navigationBarsPadding().padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(content.title, style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                Image(preview, contentDescription = null, modifier = Modifier.width(190.dp).clip(RoundedCornerShape(16.dp)).border(1.dp, c.line, RoundedCornerShape(16.dp)))
            }
            Text("Görünüm", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2)
            SegmentedPicker(ShareCard.Look.entries, look, { it.title }) { look = it }
            PrimaryButton("Paylaş") {
                ShareCard.share(context, content, look, signal)
                onDismiss()
            }
        }
    }
}
