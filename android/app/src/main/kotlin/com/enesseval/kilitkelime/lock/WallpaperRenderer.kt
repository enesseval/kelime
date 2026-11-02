package com.enesseval.kilitkelime.lock

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.Size
import android.view.WindowManager
import androidx.core.content.res.ResourcesCompat
import com.enesseval.kilitkelime.R
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.WidgetMode
import com.enesseval.kilitkelime.data.WallpaperBackground
import java.io.File
import kotlin.math.max
import kotlin.math.min

/**
 * Draws the lock-screen wallpaper: the chosen background (gradient or the user's own photo,
 * centre-cropped) with the current word as a text card. Rendered once per slot at the device's
 * real resolution; no animation.
 */
class WallpaperRenderer(private val context: Context) {

    data class Spec(
        val card: Card,
        val previous: Card?,
        val mode: WidgetMode,
        val background: WallpaperBackground,
        /** Vertical centre of the text card, 0 = top … 1 = bottom. */
        val position: Float,
    )

    private val serif: Typeface by lazy { ResourcesCompat.getFont(context, R.font.newsreader) ?: Typeface.SERIF }
    private val serifItalic: Typeface by lazy { ResourcesCompat.getFont(context, R.font.newsreader_italic) ?: Typeface.create(Typeface.SERIF, Typeface.ITALIC) }
    private val sans: Typeface by lazy { ResourcesCompat.getFont(context, R.font.hankengrotesk) ?: Typeface.SANS_SERIF }
    private val mono: Typeface by lazy { ResourcesCompat.getFont(context, R.font.jetbrainsmono) ?: Typeface.MONOSPACE }

    val photoFile: File get() = File(context.filesDir, "wallpaper/photo.jpg")

    /** The screen's full size in pixels, including system bars. */
    fun screenSize(): Size {
        val wm = context.getSystemService(WindowManager::class.java)
        return if (Build.VERSION.SDK_INT >= 30) {
            val b = wm.maximumWindowMetrics.bounds
            Size(b.width(), b.height())
        } else {
            val m = android.util.DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(m)
            Size(m.widthPixels, m.heightPixels)
        }
    }

    fun render(spec: Spec, size: Size = screenSize()): Bitmap {
        val w = size.width
        val h = size.height
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val photo = spec.background == WallpaperBackground.PHOTO && photoFile.exists()
        if (photo) drawPhoto(canvas, w, h) else drawGradient(canvas, spec.background, w, h)

        val centerY = (h * spec.position.coerceIn(0.12f, 0.88f))
        val light = if (photo) sampleLuminance(bitmap, centerY.toInt(), h / 5) > 0.55 else spec.background.isLight(spec.position)
        val ink = if (light) INK_DARK else INK_LIGHT
        val ink2 = if (light) 0xFF6A6359.toInt() else 0xFFD8D2C8.toInt()
        val margin = w * 0.09f
        val width = (w - 2 * margin).toInt()

        val blocks = layoutText(spec, width, w, ink, ink2)
        val total = blocks.sumOf { it.height + it.gapAbove }
        var y = centerY - total / 2f
        if (photo) {
            // A soft scrim keeps the text readable on any photo.
            val pad = w * 0.05f
            val scrim = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (light) 0x40FFFFFF else 0x48000000 }
            canvas.drawRoundRect(RectF(margin - pad, y - pad, w - margin + pad, y + total + pad), w * 0.06f, w * 0.06f, scrim)
        }
        for (block in blocks) {
            y += block.gapAbove
            canvas.save()
            canvas.translate(margin, y)
            if (photo) block.layout.paint.setShadowLayer(w * 0.012f, 0f, w * 0.003f, if (light) 0x55FFFFFF else 0x99000000.toInt())
            block.layout.draw(canvas)
            canvas.restore()
            y += block.height
        }
        return bitmap
    }

    private class Block(val layout: StaticLayout, val gapAbove: Int) {
        val height: Int get() = layout.height
    }

    private fun paint(typeface: Typeface, sizePx: Float, color: Int, weight: Int = 400): TextPaint =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.typeface = typeface
            textSize = sizePx
            this.color = color
            fontVariationSettings = "'wght' $weight"
        }

    private fun layout(text: CharSequence, paint: TextPaint, width: Int, maxLines: Int): StaticLayout =
        StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .setIncludePad(false)
            .build()

    /** The English word as large as fits on one line (phrases wrap to two). */
    private fun wordBlock(card: Card, width: Int, screenW: Int, ink: Int): Block {
        var size = screenW * if (card.isPhrase) 0.085f else 0.15f
        val p = paint(serif, size, ink)
        if (!card.isPhrase) {
            while (p.measureText(card.word) > width && size > screenW * 0.06f) {
                size *= 0.92f
                p.textSize = size
            }
        }
        return Block(layout(card.word, p, width, if (card.isPhrase) 2 else 1), 0)
    }

    private fun layoutText(spec: Spec, width: Int, screenW: Int, ink: Int, ink2: Int): List<Block> {
        val card = spec.card
        val body = screenW * 0.048f
        val small = screenW * 0.036f
        val gap = (screenW * 0.025f).toInt()
        return when (spec.mode) {
            WidgetMode.CARD -> listOf(
                wordBlock(card, width, screenW, ink),
                Block(layout("${card.pos.label} · ${card.meaning}", paint(sans, body, ink, 500), width, 2), gap),
            )
            WidgetMode.DICTIONARY -> listOf(
                Block(layout("${card.word.uppercase(java.util.Locale.ROOT)} (${card.pos.label})", paint(sans, screenW * 0.06f, ink, 700), width, 2), 0),
                Block(layout(card.meaning, paint(sans, body, ink, 400), width, 2), gap),
            )
            WidgetMode.SENTENCE -> listOf(
                Block(layout(card.exampleEN, paint(serifItalic, screenW * 0.06f, ink), width, 3), 0),
                Block(layout(card.exampleTR, paint(sans, body, ink2, 400), width, 2), gap),
            )
            WidgetMode.WORD_AND_SENTENCE -> listOf(
                wordBlock(card, width, screenW, ink),
                Block(layout(card.exampleEN, paint(serifItalic, screenW * 0.05f, ink), width, 2), gap),
            )
            WidgetMode.SELF_TEST -> buildList {
                val (first, blanks) = card.selfTestPattern
                add(Block(layout(card.meaning, paint(sans, screenW * 0.06f, ink, 600), width, 2), 0))
                add(Block(layout("$first$blanks", paint(mono, screenW * 0.07f, ink, 500), width, 1), gap))
                spec.previous?.let { prev ->
                    add(Block(layout("Önceki: ${prev.word} · ${prev.meaning}", paint(sans, small, ink2, 400), width, 1), gap * 2))
                }
            }
        }
    }

    private fun drawGradient(canvas: Canvas, bg: WallpaperBackground, w: Int, h: Int) {
        val paint = Paint().apply {
            shader = LinearGradient(0f, 0f, 0f, h.toFloat(), bg.top.toInt(), bg.bottom.toInt(), Shader.TileMode.CLAMP)
        }
        canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
    }

    private fun drawPhoto(canvas: Canvas, w: Int, h: Int) {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(photoFile.path, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= w && bounds.outHeight / (sample * 2) >= h) sample *= 2
        val source = BitmapFactory.decodeFile(photoFile.path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: run {
            canvas.drawColor(Color.BLACK); return
        }
        // Centre crop to the screen's aspect ratio.
        val scale = max(w / source.width.toFloat(), h / source.height.toFloat())
        val cropW = (w / scale).toInt()
        val cropH = (h / scale).toInt()
        val left = (source.width - cropW) / 2
        val top = (source.height - cropH) / 2
        canvas.drawBitmap(source, Rect(left, top, left + cropW, top + cropH), Rect(0, 0, w, h), Paint(Paint.FILTER_BITMAP_FLAG))
        source.recycle()
    }

    /** Average relative luminance of a horizontal band around [centerY]. */
    private fun sampleLuminance(bitmap: Bitmap, centerY: Int, band: Int): Double {
        var total = 0.0
        var count = 0
        val top = max(0, centerY - band / 2)
        val bottom = min(bitmap.height - 1, centerY + band / 2)
        val stepX = max(1, bitmap.width / 40)
        val stepY = max(1, (bottom - top) / 20)
        var y = top
        while (y <= bottom) {
            var x = 0
            while (x < bitmap.width) {
                total += luminance(bitmap.getPixel(x, y)); count++
                x += stepX
            }
            y += stepY
        }
        return if (count == 0) 0.0 else total / count
    }

    companion object {
        const val INK_DARK = 0xFF1B1916.toInt()
        const val INK_LIGHT = 0xFFF2EEE7.toInt()

        fun luminance(color: Int): Double {
            fun channel(c: Int): Double {
                val v = c / 255.0
                return if (v <= 0.03928) v / 12.92 else Math.pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(Color.red(color)) + 0.7152 * channel(Color.green(color)) + 0.0722 * channel(Color.blue(color))
        }
    }
}

/** Whether text on this gradient at [position] should be dark. */
fun WallpaperBackground.isLight(position: Float): Boolean {
    val t = position.coerceIn(0f, 1f)
    fun mix(a: Long, b: Long, shift: Int): Int = (((a shr shift) and 0xFF) * (1 - t) + ((b shr shift) and 0xFF) * t).toInt()
    val color = Color.rgb(mix(top, bottom, 16), mix(top, bottom, 8), mix(top, bottom, 0))
    return WallpaperRenderer.luminance(color) > 0.45
}
