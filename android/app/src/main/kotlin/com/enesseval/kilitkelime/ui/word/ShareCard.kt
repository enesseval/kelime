package com.enesseval.kilitkelime.ui.word

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.core.content.FileProvider
import androidx.core.content.res.ResourcesCompat
import com.enesseval.kilitkelime.R
import com.enesseval.kilitkelime.core.model.Card
import java.io.File

/**
 * The share image of a word (port of `ShareCard.swift`): 1080 × 1350 in three looks (Açık, Koyu,
 * Mavi), the word, its part of speech and meaning, the example, and the app name.
 */
object ShareCard {
    enum class Look(val title: String, val background: Int, val ink: Int, val ink2: Int, val accent: Int) {
        LIGHT("Açık", 0xFFF4F1EB.toInt(), 0xFF1B1916.toInt(), 0xFF6A6359.toInt(), 0xFFE49839.toInt()),
        DARK("Koyu", 0xFF121110.toInt(), 0xFFF2EEE7.toInt(), 0xFFA39C91.toInt(), 0xFFEEAC53.toInt()),
        BLUE("Mavi", 0xFF335AA6.toInt(), 0xFFF4F1EB.toInt(), 0xFFD5DEF0.toInt(), 0xFFF0A94A.toInt()),
    }

    fun render(context: Context, card: Card, look: Look): Bitmap {
        val w = 1080
        val h = 1350
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(look.background)
        val serif = ResourcesCompat.getFont(context, R.font.newsreader) ?: Typeface.SERIF
        val serifItalic = ResourcesCompat.getFont(context, R.font.newsreader_italic) ?: Typeface.SERIF
        val sans = ResourcesCompat.getFont(context, R.font.hankengrotesk) ?: Typeface.SANS_SERIF
        val margin = 96f
        val width = (w - 2 * margin).toInt()

        fun paint(tf: Typeface, size: Float, color: Int, weight: Int = 400) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = tf; textSize = size; this.color = color; fontVariationSettings = "'wght' $weight"
        }
        fun block(text: String, p: TextPaint, y: Float): Float {
            val layout = StaticLayout.Builder.obtain(text, 0, text.length, p, width).setAlignment(Layout.Alignment.ALIGN_NORMAL).build()
            canvas.save(); canvas.translate(margin, y); layout.draw(canvas); canvas.restore()
            return y + layout.height
        }

        val level = paint(sans, 34f, look.ink2, 600)
        canvas.drawText(card.level.raw, margin, 170f, level)
        var wordSize = if (card.isPhrase) 96f else 168f
        val wordPaint = paint(serif, wordSize, look.ink)
        while (!card.isPhrase && wordPaint.measureText(card.word) > width && wordSize > 80f) {
            wordSize *= 0.92f; wordPaint.textSize = wordSize
        }
        var y = block(card.word, wordPaint, 420f)
        y = block("${card.pos.label}  ·  ${card.meaning}", paint(sans, 50f, look.ink, 500), y + 30f)
        if (card.exampleEN.isNotEmpty()) {
            val rule = Paint().apply { color = look.ink2; alpha = 60 }
            canvas.drawRect(RectF(margin, y + 60f, w - margin, y + 62f), rule)
            y = block(card.exampleEN, paint(serifItalic, 54f, look.ink), y + 110f)
            block(card.exampleTR, paint(sans, 38f, look.ink2), y + 16f)
        }
        // Footer: the half-filled dot and the app name.
        val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = look.accent; style = Paint.Style.STROKE; strokeWidth = 6f }
        val cx = margin + 22f
        val cy = h - 130f
        canvas.drawCircle(cx, cy, 19f, dot)
        dot.style = Paint.Style.FILL
        canvas.drawArc(RectF(cx - 19f, cy - 19f, cx + 19f, cy + 19f), 90f, 180f, true, dot)
        canvas.drawText("Kilit Kelime", cx + 44f, cy + 14f, paint(serif, 44f, look.ink))
        return bitmap
    }

    /** Writes the image to the cache and opens the share sheet. */
    fun share(context: Context, card: Card, look: Look) {
        val dir = File(context.cacheDir, "share").apply { mkdirs() }
        val file = File(dir, "kelime-${card.word.filter { it.isLetterOrDigit() }.ifEmpty { "kart" }}.png")
        val bitmap = render(context, card, look)
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val send = Intent(Intent.ACTION_SEND).setType("image/png").putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.startActivity(Intent.createChooser(send, "Kartı paylaş").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
