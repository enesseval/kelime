package com.enesseval.kilitkelime.ui.word

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

/** Pronunciation with Android TextToSpeech in en-US (port of `Speaker.swift`). */
class Speaker(context: Context) : TextToSpeech.OnInitListener {
    private val tts = TextToSpeech(context.applicationContext, this)
    private var ready = false
    private var pending: String? = null
    var rate: Float = 0.9f

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts.language = Locale.US
            ready = true
            pending?.let { speak(it) }
            pending = null
        }
    }

    fun speak(text: String) {
        if (!ready) {
            pending = text
            return
        }
        tts.setSpeechRate(rate)
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "kelime")
    }

    fun shutdown() = tts.shutdown()
}
