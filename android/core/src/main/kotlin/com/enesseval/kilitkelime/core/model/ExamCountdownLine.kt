package com.enesseval.kilitkelime.core.model

/**
 * The exam countdown line (docs/V1_2_PLAN.md §5): "YDS'ye 23 gün · bugün 12 kelime". iOS shows it in a
 * Live Activity, Android in a dismissible ongoing notification. The exam plan is Pro (trial included),
 * the date comes from the exam plan; with no date, or once the exam day has passed, there is no line.
 */
object ExamCountdownLine {
    /** Whether the countdown may be on screen: Pro, and an exam date that is today or ahead. */
    fun available(isPro: Boolean, plan: ExamPlanStatus?): Boolean = isPro && plan != null && plan.daysLeft >= 0

    /** "YDS'ye", "YÖKDİL'e", "IELTS'e": YDS is read "ye-de-es", so it takes -ye. */
    fun toExam(exam: DeckID): String = "${exam.raw}${if (exam == DeckID.YDS) "'ye" else "'e"}"

    /** The line, or null when there is nothing to show. */
    fun text(isPro: Boolean, plan: ExamPlanStatus?): String? {
        if (!available(isPro, plan)) return null
        plan!!
        val head = if (plan.daysLeft == 0) "${plan.exam.raw} bugün" else "${toExam(plan.exam)} ${plan.daysLeft} gün"
        val tail = when {
            plan.remaining == 0 -> "hepsini öğrendin"
            plan.doneToday >= plan.dailyTarget -> "bugünkü hedef tamam"
            else -> "bugün ${plan.dailyTarget} kelime"
        }
        return "$head · $tail"
    }
}
