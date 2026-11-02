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
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.model.Card
import java.io.File

/**
 * Share images (docs/V1_1_PLAN.md §4): 1080 × 1920 (9:16) in the app's three looks. A word card,
 * puzzle and game results, the weekly summary and streak milestones. Every card ends with the
 * logo, "Kilit Kelime" and "Kilit ekranında İngilizce"; no store link.
 */
object ShareCard {
    enum class Look(val title: String, val background: Int, val ink: Int, val ink2: Int, val accent: Int, val surface: Int, val green: Int, val amber: Int) {
        LIGHT("Açık", 0xFFF4F1EB.toInt(), 0xFF1B1916.toInt(), 0xFF6A6359.toInt(), 0xFFE49839.toInt(), 0xFFEAE6DE.toInt(), 0xFF50986B.toInt(), 0xFFE49839.toInt()),
        DARK("Koyu", 0xFF121110.toInt(), 0xFFF2EEE7.toInt(), 0xFFA39C91.toInt(), 0xFFEEAC53.toInt(), 0xFF2A2825.toInt(), 0xFF75BE8F.toInt(), 0xFFEEAC53.toInt()),
        BLUE("Mavi", 0xFF335AA6.toInt(), 0xFFF4F1EB.toInt(), 0xFFD5DEF0.toInt(), 0xFFF0A94A.toInt(), 0xFF2A4C8E.toInt(), 0xFF75BE8F.toInt(), 0xFFF0A94A.toInt()),
    }

    /** What a card shows. [type] is the `share.card` signal parameter. */
    sealed class Content(val type: String) {
        class Word(val card: Card) : Content("word")
        /** Grid cells: null = block, true = solved without help (green), false = solved with a hint (amber). */
        class Puzzle(val width: Int, val height: Int, val cells: Map<Pair<Int, Int>, Boolean?>, val time: String, val date: String) : Content("puzzle")
        class Game(val title: String, val score: String, val detail: String) : Content("game")
        class Weekly(val learned: Int, val streak: Int, val wordOfWeek: Card?, val detail: String) : Content("weekly")
        class Milestone(val days: Int) : Content("streak")
    }

    const val WIDTH = 1080
    const val HEIGHT = 1920

    fun render(context: Context, content: Content, look: Look): Bitmap {
        val bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(look.background)
        val f = Fonts(context)
        val margin = 96f
        val width = (WIDTH - 2 * margin).toInt()

        fun paint(tf: Typeface, size: Float, color: Int, weight: Int = 400) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = tf; textSize = size; this.color = color; fontVariationSettings = "'wght' $weight"
        }
        fun block(text: String, p: TextPaint, y: Float, align: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL): Float {
            val layout = StaticLayout.Builder.obtain(text, 0, text.length, p, width).setAlignment(align).build()
            canvas.save(); canvas.translate(margin, y); layout.draw(canvas); canvas.restore()
            return y + layout.height
        }
        fun kicker(text: String) = canvas.drawText(text, margin, 260f, paint(f.sans, 38f, look.ink2, 700).apply { letterSpacing = 0.1f })
        val center = Layout.Alignment.ALIGN_CENTER

        when (content) {
            is Content.Word -> {
                val card = content.card
                kicker(card.level.raw)
                var size = if (card.isPhrase) 104f else 180f
                val wordPaint = paint(f.serif, size, look.ink)
                while (!card.isPhrase && wordPaint.measureText(card.word) > width && size > 80f) { size *= 0.92f; wordPaint.textSize = size }
                var y = block(card.word, wordPaint, 620f)
                y = block("${card.pos.label}  ·  ${card.meaning}", paint(f.sans, 54f, look.ink, 500), y + 36f)
                if (card.exampleEN.isNotEmpty()) {
                    canvas.drawRect(RectF(margin, y + 70f, WIDTH - margin, y + 72f), Paint().apply { color = look.ink2; alpha = 70 })
                    y = block(card.exampleEN, paint(f.serifItalic, 58f, look.ink), y + 130f)
                    block(card.exampleTR, paint(f.sans, 42f, look.ink2), y + 20f)
                }
            }
            is Content.Puzzle -> {
                kicker("GÜNÜN BULMACASI · ${content.date.uppercase(com.enesseval.kilitkelime.ui.components.TR)}")
                val cell = minOf(width / content.width.toFloat(), 900f / content.height)
                val gridW = cell * content.width
                val left = (WIDTH - gridW) / 2
                val top = 420f
                val fill = Paint(Paint.ANTI_ALIAS_FLAG)
                for ((point, solved) in content.cells) {
                    val (r, c) = point
                    fill.color = when (solved) { true -> look.green; false -> look.amber; null -> look.surface }
                    canvas.drawRoundRect(RectF(left + c * cell + 4, top + r * cell + 4, left + (c + 1) * cell - 4, top + (r + 1) * cell - 4), cell * 0.18f, cell * 0.18f, fill)
                }
                val y = top + cell * content.height + 90f
                block(content.time, paint(f.serif, 120f, look.ink), y, center)
                block("yeşil: yardımsız · amber: ipucuyla", paint(f.sans, 36f, look.ink2), y + 170f, center)
            }
            is Content.Game -> {
                kicker(content.title.uppercase(com.enesseval.kilitkelime.ui.components.TR))
                val y = block(content.score, paint(f.serif, 260f, look.ink), 640f, center)
                block(content.detail, paint(f.sans, 52f, look.ink2, 500), y + 40f, center)
            }
            is Content.Weekly -> {
                kicker("BU HAFTA")
                var y = block("${content.learned}", paint(f.serif, 260f, look.ink), 480f)
                y = block("kelime öğrendim", paint(f.sans, 56f, look.ink, 500), y)
                y = block("🔒 ${content.streak} gün seri", paint(f.sans, 56f, look.ink, 600), y + 80f)
                content.wordOfWeek?.let { w ->
                    y = block("HAFTANIN KELİMESİ", paint(f.sans, 36f, look.ink2, 700).apply { letterSpacing = 0.1f }, y + 110f)
                    y = block(w.word, paint(f.serif, 110f, look.ink), y + 10f)
                    y = block(w.meaning, paint(f.sans, 46f, look.ink2), y)
                }
                block(content.detail, paint(f.sans, 40f, look.ink2), y + 60f)
            }
            is Content.Milestone -> {
                kicker("SERİ")
                val y = block("${content.days}", paint(f.serif, 380f, look.ink), 560f, center)
                block("gün üst üste İngilizce", paint(f.sans, 60f, look.ink, 500), y + 20f, center)
            }
        }

        // Footer: the half-filled dot, the name and the tagline.
        val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = look.accent; style = Paint.Style.STROKE; strokeWidth = 7f }
        val cx = margin + 26f
        val cy = HEIGHT - 190f
        canvas.drawCircle(cx, cy, 22f, dot)
        dot.style = Paint.Style.FILL
        canvas.drawArc(RectF(cx - 22f, cy - 22f, cx + 22f, cy + 22f), 90f, 180f, true, dot)
        canvas.drawText("Kilit Kelime", cx + 52f, cy + 16f, paint(f.serif, 52f, look.ink))
        canvas.drawText("Kilit ekranında İngilizce", margin, cy + 90f, paint(f.sans, 36f, look.ink2))
        return bitmap
    }

    /** Writes the image to the cache and opens the share sheet. */
    fun share(context: Context, content: Content, look: Look, signal: String = Analytics.Signal.SHARE_CARD) {
        val dir = File(context.cacheDir, "share").apply { mkdirs() }
        val file = File(dir, "kilit-kelime-${content.type}.png")
        val bitmap = render(context, content, look)
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
        Analytics.signal(Analytics.Signal.SHARE_CARD, mapOf("type" to content.type))
        if (signal != Analytics.Signal.SHARE_CARD) Analytics.signal(signal)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val send = Intent(Intent.ACTION_SEND).setType("image/png").putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.startActivity(Intent.createChooser(send, "Paylaş").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private class Fonts(context: Context) {
        val serif: Typeface = ResourcesCompat.getFont(context, R.font.newsreader) ?: Typeface.SERIF
        val serifItalic: Typeface = ResourcesCompat.getFont(context, R.font.newsreader_italic) ?: Typeface.SERIF
        val sans: Typeface = ResourcesCompat.getFont(context, R.font.hankengrotesk) ?: Typeface.SANS_SERIF
    }
}
