package com.enesseval.kilitkelime.ui.word

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import androidx.core.content.FileProvider
import androidx.core.content.res.ResourcesCompat
import com.enesseval.kilitkelime.R
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.queries.StatsQueries
import com.enesseval.kilitkelime.ui.components.TR
import com.enesseval.kilitkelime.ui.components.TurkishDate
import java.io.File
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * Share images, drawn like the iOS ones (`ShareCard.swift`, `ShareFrame`): 360 × 640 points at 3×
 * (1080 × 1920), 36 pt padding, left aligned, in Açık / Koyu / Mavi, and the line
 * "Kilit Kelime · Kilit ekranında İngilizce" at the bottom (the word card shows only the name).
 * Every size below is in iOS points and multiplied by [S].
 */
object ShareCard {
    /** iOS `ShareCardStyle` with the light or dark palette it renders in. */
    enum class Look(
        val title: String, val background: Int, val ink: Int, val ink2: Int, val line: Int,
        val surface2: Int, val green: Int, val amber: Int,
    ) {
        LIGHT("Açık", 0xFFFBF9F5.toInt(), 0xFF1B1916.toInt(), 0xFF6A6359.toInt(), 0x1C1B1916, 0xFFEAE6DE.toInt(), 0xFF50986B.toInt(), 0xFFE49839.toInt()),
        DARK("Koyu", 0xFF12110F.toInt(), 0xFFF2EEE7.toInt(), 0xFFA39C91.toInt(), 0x1CF2EEE7, 0xFF2A2825.toInt(), 0xFF75BE8F.toInt(), 0xFFEEAC53.toInt()),
        BLUE("Mavi", 0xFF21386B.toInt(), 0xFFF2EEE7.toInt(), 0xFFA39C91.toInt(), 0x1CF2EEE7, 0xFF2A2825.toInt(), 0xFF75BE8F.toInt(), 0xFFEEAC53.toInt()),
    }

    /** What a card shows. [type] is the `share.card` signal parameter; [title] the sheet title. */
    sealed class Content(val type: String, val title: String) {
        class Word(val card: Card) : Content("word", "Kartı paylaş")

        /** Grid cells: null = block, true = solved without help (green), false = with help (amber). */
        class Puzzle(
            val name: String, val width: Int, val height: Int, val cells: Map<Pair<Int, Int>, Boolean?>,
            val words: Int, val time: String, val hints: Int,
        ) : Content("puzzle", "Bulmaca sonucu")

        class Game(val kicker: String, val headline: String, val detail: String, val words: List<Card>) : Content("game", "Sonuç")
        class Weekly(val weekStart: LocalDate, val learned: Int, val shown: Int, val streak: Int, val wordOfWeek: Card?) : Content("weekly", "Haftalık özet")
        class Streak(val current: Int, val studied: Set<LocalDate>, val frozen: Set<LocalDate>, val today: LocalDate) : Content("streak", "Seri")
    }

    const val WIDTH = 1080
    const val HEIGHT = 1920
    private const val S = 3f
    private const val PAD = 36 * S

    /** "27 Ekim – 2 Kasım" (iOS WeeklySummaryView.range). */
    fun range(start: LocalDate): String {
        val f = DateTimeFormatter.ofPattern("d MMMM", TR)
        return start.format(f) + " – " + start.plusDays(6).format(f)
    }

    fun render(context: Context, content: Content, look: Look): Bitmap {
        val bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(look.background)
        val f = Fonts(context)
        val width = (WIDTH - 2 * PAD).toInt()

        fun paint(tf: Typeface, pt: Float, color: Int, weight: Int = 400, tracking: Float = 0f) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = tf; textSize = pt * S; this.color = color; fontVariationSettings = "'wght' $weight"
            if (tracking != 0f) letterSpacing = tracking / pt
        }
        fun layout(text: CharSequence, p: TextPaint, maxLines: Int = Int.MAX_VALUE) =
            StaticLayout.Builder.obtain(text, 0, text.length, p, width).setMaxLines(maxLines).setEllipsize(TextUtils.TruncateAt.END).build()
        /** Draws [text] at [y] (its top) and returns the y under it. */
        fun text(text: CharSequence, p: TextPaint, y: Float, maxLines: Int = Int.MAX_VALUE): Float {
            val l = layout(text, p, maxLines)
            canvas.save(); canvas.translate(PAD, y); l.draw(canvas); canvas.restore()
            return y + l.height
        }
        fun rule(y: Float) = canvas.drawRect(PAD, y, WIDTH - PAD, y + S, Paint().apply { color = look.line })
        fun kicker(title: String, y: Float) = text(title, paint(f.sans, 14f, look.ink2, 700, 1.4f), y)
        fun date(text: String, y: Float) = text(text, paint(f.sans, 15f, look.ink2), y + 2 * S)

        val top = PAD
        when (content) {
            is Content.Word -> {
                // Spacer, chip, word, kind and meaning, rule, example; centred between two spacers.
                val card = content.card
                val chipPaint = paint(f.sans, 16f, look.ink2, 600)
                var wordSize = if (card.word.length > 11) 52f else 68f
                val wordPaint = paint(f.serif, wordSize, look.ink, tracking = -1.5f)
                while (wordPaint.measureText(card.word) > width && wordSize > 34f) { wordSize *= 0.94f; wordPaint.textSize = wordSize * S }
                val meaning = android.text.SpannableStringBuilder().apply {
                    append(card.pos.label)
                    if (android.os.Build.VERSION.SDK_INT >= 28) setSpan(android.text.style.TypefaceSpan(f.serifItalic), 0, length, 0)
                    setSpan(android.text.style.AbsoluteSizeSpan((22 * S).toInt()), 0, length, 0)
                    setSpan(android.text.style.ForegroundColorSpan(look.ink2), 0, length, 0)
                    append("  ")
                    append(card.meaning)
                }
                val meaningLayout = layout(meaning, paint(f.sans, 24f, look.ink))
                val enLayout = layout(card.exampleEN, paint(f.serifItalic, 26f, look.ink))
                val trLayout = layout(card.exampleTR, paint(f.sans, 18f, look.ink2))
                val chipH = 16 * S * 1.25f + 2 * 16 * 0.27f * S
                val wordH = wordPaint.fontSpacing
                val hasExample = card.exampleEN.isNotEmpty()
                val blockH = chipH + 18 * S + wordH + 10 * S + meaningLayout.height +
                    (if (hasExample) 56 * S + S + enLayout.height + 6 * S + trLayout.height else 0f)
                val footerH = 14 * S * 1.3f
                var y = top + ((HEIGHT - 2 * PAD - footerH) - blockH) / 2
                // Level chip.
                val chipW = chipPaint.measureText(card.level.raw) + 2 * 16 * 0.55f * S
                canvas.drawRoundRect(RectF(PAD, y, PAD + chipW, y + chipH), 16 * 0.45f * S, 16 * 0.45f * S, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = look.surface2 })
                canvas.drawText(card.level.raw, PAD + 16 * 0.55f * S, y + chipH / 2 - (chipPaint.ascent() + chipPaint.descent()) / 2, chipPaint)
                y += chipH + 18 * S
                canvas.drawText(card.word, PAD, y - wordPaint.ascent(), wordPaint)
                y += wordH + 10 * S
                canvas.save(); canvas.translate(PAD, y); meaningLayout.draw(canvas); canvas.restore()
                y += meaningLayout.height
                if (hasExample) {
                    y += 28 * S; rule(y); y += S + 28 * S
                    canvas.save(); canvas.translate(PAD, y); enLayout.draw(canvas); canvas.restore()
                    y += enLayout.height + 6 * S
                    canvas.save(); canvas.translate(PAD, y); trLayout.draw(canvas); canvas.restore()
                }
                val name = paint(f.sans, 14f, look.ink2, 600)
                canvas.drawText("Kilit Kelime", PAD, HEIGHT - PAD - name.descent(), name)
                return bitmap
            }
            is Content.Puzzle -> {
                var y = kicker(content.name.uppercase(TR), top + 30 * S)
                y = date(TurkishDate.header(LocalDate.now()), y)
                y = text("${content.words} kelime", paint(f.serif, 64f, look.ink, tracking = -1.5f), y + 20 * S)
                y = text("${content.time} · ${content.hints} ipucu", paint(f.sans, 20f, look.ink, 600), y)
                // Spoiler-free grid, centred: cells min(26, 288 / width − 3) pt with 3 pt gaps.
                val cell = minOf(26f, 288f / maxOf(content.width, 1) - 3f) * S
                val gap = 3 * S
                val gridW = content.width * cell + (content.width - 1) * gap
                val left = (WIDTH - gridW) / 2
                y += 34 * S
                val fill = Paint(Paint.ANTI_ALIAS_FLAG)
                for ((point, unaided) in content.cells) {
                    if (unaided == null) continue
                    val (r, col) = point
                    fill.color = if (unaided) look.green else look.amber
                    val x0 = left + col * (cell + gap)
                    val y0 = y + r * (cell + gap)
                    canvas.drawRoundRect(RectF(x0, y0, x0 + cell, y0 + cell), cell * 0.2f, cell * 0.2f, fill)
                }
            }
            is Content.Game -> {
                var y = kicker(content.kicker, top + 30 * S)
                y = date(TurkishDate.header(LocalDate.now()), y)
                y = text(content.headline, paint(f.serif, 68f, look.ink, tracking = -1.5f), y + 20 * S)
                y = text(content.detail, paint(f.sans, 20f, look.ink, 600), y)
                if (content.words.isNotEmpty()) {
                    y += 26 * S; rule(y); y += S + 26 * S
                    val wordPaint = paint(f.serif, 24f, look.ink)
                    val meaningPaint = paint(f.sans, 16f, look.ink2)
                    for (card in content.words.take(6)) {
                        val baseline = y - wordPaint.ascent()
                        canvas.drawText(TextUtils.ellipsize(card.word, wordPaint, width * 0.55f, TextUtils.TruncateAt.END).toString(), PAD, baseline, wordPaint)
                        val meaning = TextUtils.ellipsize(card.primaryMeaning, meaningPaint, width * 0.42f, TextUtils.TruncateAt.END).toString()
                        canvas.drawText(meaning, WIDTH - PAD - meaningPaint.measureText(meaning), baseline, meaningPaint)
                        y += wordPaint.fontSpacing + 8 * S
                    }
                }
            }
            is Content.Weekly -> {
                var y = kicker("GEÇEN HAFTAM", top + 30 * S)
                y = date(range(content.weekStart), y)
                y = text("${content.learned}", paint(f.serif, 120f, look.ink, tracking = -3f), y + 18 * S)
                y = text("yeni kelime", paint(f.sans, 24f, look.ink, 600), y)
                y += 28 * S
                for ((value, label) in listOf("${content.shown}" to "kelime kilit ekranımda göründü", "${content.streak} gün" to "seri")) {
                    val line = android.text.SpannableStringBuilder().apply {
                        append(value)
                        setSpan(android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, length, 0)
                        setSpan(android.text.style.AbsoluteSizeSpan((20 * S).toInt()), 0, length, 0)
                        val start = length
                        append("  $label")
                        setSpan(android.text.style.ForegroundColorSpan(look.ink2), start, length, 0)
                    }
                    y = text(line, paint(f.sans, 17f, look.ink), y) + 10 * S
                }
                content.wordOfWeek?.let { w ->
                    y += 14 * S; rule(y); y += S + 24 * S
                    y = text("HAFTANIN KELİMESİ", paint(f.sans, 12f, look.ink2, 700, 1.2f), y)
                    y = text(w.word, paint(f.serif, 40f, look.ink), y + 4 * S, maxLines = 1)
                    text(w.meaning, paint(f.sans, 17f, look.ink2), y, maxLines = 2)
                }
            }
            is Content.Streak -> {
                var y = kicker("SERİ", top + 40 * S)
                y = text("${content.current}", paint(f.serif, 140f, look.ink, tracking = -4f), y + 4 * S)
                y = text("gün üst üste İngilizce", paint(f.sans, 22f, look.ink, 600), y)
                drawCalendar(canvas, content, look, f, y + 40 * S, dot = 26 * S)
            }
        }

        // ShareFrame footer: "Kilit Kelime · Kilit ekranında İngilizce", ink2.
        val name = paint(f.sans, 14f, look.ink2, 600)
        val tagline = paint(f.sans, 13f, look.ink2)
        val baseline = HEIGHT - PAD - name.descent()
        canvas.drawText("Kilit Kelime", PAD, baseline, name)
        canvas.drawText("· Kilit ekranında İngilizce", PAD + name.measureText("Kilit Kelime") + 6 * S, baseline, tagline)
        return bitmap
    }

    /** iOS StreakCalendar: five Monday-first weeks; filled = studied, dashed ring = freeze. */
    private fun drawCalendar(canvas: Canvas, content: Content.Streak, look: Look, f: Fonts, top: Float, dot: Float) {
        val width = WIDTH - 2 * PAD
        val column = width / 7
        val initials = listOf("P", "S", "Ç", "P", "C", "C", "P")
        val label = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = f.sans; textSize = 11 * S; color = look.ink2; fontVariationSettings = "'wght' 600"; textAlign = Paint.Align.CENTER
        }
        var y = top - label.ascent()
        initials.forEachIndexed { i, s -> canvas.drawText(s, PAD + column * (i + 0.5f), y, label) }
        y += label.descent() + 8 * S
        val start = StatsQueries.weekStart(content.today).minusDays(28)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        for (week in 0 until 5) {
            for (weekday in 0 until 7) {
                val day = start.plusDays((week * 7 + weekday).toLong())
                val cx = PAD + column * (weekday + 0.5f)
                val cy = y + dot / 2
                paint.pathEffect = null
                when {
                    day in content.studied -> { paint.style = Paint.Style.FILL; paint.color = look.green; canvas.drawCircle(cx, cy, dot / 2, paint) }
                    day in content.frozen -> {
                        paint.style = Paint.Style.STROKE; paint.strokeWidth = 1.5f * S; paint.color = look.ink2
                        paint.pathEffect = DashPathEffect(floatArrayOf(3 * S, 3 * S), 0f)
                        canvas.drawCircle(cx, cy, dot / 2 - 0.75f * S, paint)
                    }
                    day > content.today -> Unit
                    else -> { paint.style = Paint.Style.FILL; paint.color = look.surface2; canvas.drawCircle(cx, cy, dot / 2, paint) }
                }
            }
            y += dot + 8 * S
        }
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
