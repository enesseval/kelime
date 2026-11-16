package com.enesseval.kilitkelime.core.learning

/**
 * Choices must not give the answer away by how they are written (docs/SYNC.md, 2026-11-17): a phrase
 * ending in "?" among three ending in "." is the right one. So wrong choices come from the answer's own
 * sentence type, and when there are not enough of them every choice is shown without its ending
 * punctuation; capitals are made equal too.
 */
object OptionStyle {
    enum class Ending { QUESTION, EXCLAMATION, PLAIN }

    private const val CLOSERS = "\"'’”»)]}"
    private const val PUNCTUATION = ".,!?;:…"

    /** The sentence type: the last meaningful character (closing quotes, brackets and spaces are skipped). */
    fun ending(text: String): Ending {
        val c = text.trimEnd { it.isWhitespace() || it in CLOSERS }.lastOrNull()
        return when (c) {
            '?' -> Ending.QUESTION
            '!' -> Ending.EXCLAMATION
            else -> Ending.PLAIN
        }
    }

    fun sameEnding(a: String, b: String): Boolean = ending(a) == ending(b)

    /** [text] without the punctuation at its end (and its repeats: "?!", "..."). */
    fun stripEnding(text: String): String {
        var end = text.length
        while (end > 0 && (text[end - 1].isWhitespace() || text[end - 1] in PUNCTUATION)) end--
        return if (end == 0) text else text.substring(0, end)
    }

    /** Whether the choices already look alike at the end. */
    fun endingsAlike(options: List<String>): Boolean = options.map { ending(it) }.distinct().size <= 1

    private fun sentenceLike(text: String) = text.trimEnd().lastOrNull()?.let { it in ".?!…" } == true

    /** Index of the first letter (a leading "…" or quote is skipped), or -1. */
    private fun firstLetter(text: String): Int = text.indexOfFirst { it.isLetter() }

    private fun capitalFirst(word: String, turkish: Boolean): String {
        val i = firstLetter(word)
        if (i < 0) return word
        val upper = if (turkish && word[i] == 'i') "İ" else word[i].uppercaseChar().toString()
        return word.substring(0, i) + upper + word.substring(i + 1)
    }

    /** The first word loses its capital unless it is "I", "I'm" ... or has capitals inside (TV, McDonald's). */
    private fun lowerFirst(word: String, turkish: Boolean): String {
        val i = firstLetter(word)
        if (i < 0) return word
        val first = word[i]
        if (!first.isUpperCase()) return word
        val rest = word.substring(i + 1)
        if (first == 'I' && (rest.isEmpty() || !rest[0].isLetter())) return word
        if (rest.any { it.isUpperCase() }) return word
        val lower = if (turkish && first == 'I') "ı" else if (turkish && first == 'İ') "i" else first.lowercaseChar().toString()
        return word.substring(0, i) + lower + rest
    }

    /**
     * The choices as shown, in the same order: the same ending kind for all (endings stripped when they
     * differ) and the same first-letter case (capital when the choices are sentences, small when they
     * are words or phrases). One word on its own is not changed. A choice that is already alike stays
     * as it is, so a normal word list is shown as written.
     */
    fun display(options: List<String>, turkish: Boolean = false): List<String> {
        if (options.isEmpty()) return options
        val alike = endingsAlike(options)
        val sentences = options.any { sentenceLike(it) }
        val stripped = if (alike) options else options.map { stripEnding(it) }
        // Single words are left as written (a proper noun keeps its capital); only phrases and sentences are evened out.
        fun multi(text: String) = text.trim().any { it.isWhitespace() }
        val firstCases = stripped.filter { multi(it) }.mapNotNull { text -> text.firstOrNull { c -> c.isLetter() } }.map { it.isUpperCase() }.distinct()
        if (firstCases.size <= 1) return stripped
        return stripped.map { if (!multi(it)) it else if (sentences) capitalFirst(it, turkish) else lowerFirst(it, turkish) }
    }

    /** What one choice [option] of [options] is shown as. */
    fun display(option: String, options: List<String>): String {
        val i = options.indexOf(option)
        return if (i < 0) option else display(options)[i]
    }
}
