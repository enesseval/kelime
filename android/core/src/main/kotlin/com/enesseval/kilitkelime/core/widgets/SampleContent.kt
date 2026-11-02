package com.enesseval.kilitkelime.core.widgets

import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.WidgetMode
import java.time.Instant

/** Sample cards for previews, onboarding and widget placeholders. */
object SampleContent {
    val reluctant = Card("b2-reluctant", "reluctant", PartOfSpeech.ADJECTIVE, CEFRLevel.B2, listOf("isteksiz", "gönülsüz"), "She was reluctant to leave.", "Ayrılmaya gönülsüzdü.")
    val happy = Card("a1-happy", "happy", PartOfSpeech.ADJECTIVE, CEFRLevel.A1, listOf("mutlu"), "I am happy today.", "Bugün mutluyum.")
    val coffee = Card("a1-coffee", "coffee", PartOfSpeech.NOUN, CEFRLevel.A1, listOf("kahve"), "I'd like a coffee, please.", "Bir kahve alayım, lütfen.")
    val friend = Card("a1-friend", "friend", PartOfSpeech.NOUN, CEFRLevel.A1, listOf("arkadaş"), "This is my friend.", "Bu benim arkadaşım.")
    val hungry = Card("a1-hungry", "hungry", PartOfSpeech.ADJECTIVE, CEFRLevel.A1, listOf("aç"), "Are you hungry? Let's eat.", "Aç mısın? Hadi yiyelim.")
    val phrase = Card("a1-p-at-home", "Make yourself at home.", PartOfSpeech.PHRASE, CEFRLevel.A1, listOf("Kendi evin gibi rahat et."), "Come in! Make yourself at home.", "Buyurun! Kendi eviniz gibi rahat edin.")
    val longest = Card("c1-misunderstanding", "misunderstanding", PartOfSpeech.NOUN, CEFRLevel.C1, listOf("yanlış anlama", "anlaşmazlık"), "There was a significant increase in prices last year.", "Geçen yıl fiyatlarda kayda değer bir artış oldu.")

    fun snapshot(card: Card = happy, mode: WidgetMode = WidgetMode.CARD, state: LearningState = LearningState.STRUGGLING) = WidgetSnapshot(
        date = Instant.now(), card = card, state = state, mode = mode,
        quizOptions = listOf(card.word, if (card.id == hungry.id) happy.word else hungry.word),
        reviewedToday = 7, struggling = listOf(hungry, coffee, friend),
        puzzleProgress = WidgetSnapshot.PuzzleCount(2, 5), previousCard = coffee,
    )
}
