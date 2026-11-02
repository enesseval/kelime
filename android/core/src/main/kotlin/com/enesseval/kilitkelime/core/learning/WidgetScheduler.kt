package com.enesseval.kilitkelime.core.learning

import com.enesseval.kilitkelime.core.dates.startOfDay
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.RotationInterval
import java.time.Duration
import java.time.Instant
import java.time.ZoneId

/** A card the lock screen may show, with just the fields selection needs. */
data class SchedulerCandidate(
    val cardID: String,
    val state: LearningState,
    val lastShownAt: Instant? = null,
    /** A learned word whose review day has come. */
    val due: Boolean = false,
)

/**
 * Selection logic for the rotation (port of `WidgetScheduler.swift`).
 *
 * Weights: struggling 3, learned and due 2, new 1, other learned 0.2 but only when last shown
 * more than 14 days ago. A card never repeats within the last 20 slots.
 */
object WidgetScheduler {
    const val RECENT_WINDOW = 20
    val learnedCooldown: Duration = Duration.ofDays(14)

    fun weight(candidate: SchedulerCandidate, now: Instant): Double = when (candidate.state) {
        LearningState.STRUGGLING -> 3.0
        LearningState.NEW -> 1.0
        LearningState.LEARNED -> when {
            candidate.due -> 2.0
            candidate.lastShownAt == null -> 0.2
            Duration.between(candidate.lastShownAt, now) > learnedCooldown -> 0.2
            else -> 0.0
        }
    }

    /**
     * Picks one card by weight, skipping [recent] (newest first). When every weighted card is
     * recent, the one shown longest ago is reused. Null only when nothing has weight.
     */
    fun pick(candidates: List<SchedulerCandidate>, recent: List<String>, now: Instant, rng: RandomSource): String? {
        val window = recent.take(RECENT_WINDOW)
        val excluded = window.toSet()
        val weighted = candidates.mapNotNull { c ->
            val w = weight(c, now)
            if (w > 0) c.cardID to w else null
        }
        val fresh = weighted.filter { it.first !in excluded }
        weightedChoice(fresh, rng)?.let { return it }
        val available = weighted.map { it.first }.toSet()
        return window.reversed().firstOrNull { it in available }
    }

    internal fun weightedChoice(items: List<Pair<String, Double>>, rng: RandomSource): String? {
        val total = items.sumOf { it.second }
        if (total <= 0) return null
        var target = rng.doubleUntil(0.0, total)
        for ((id, w) in items) {
            if (target < w) return id
            target -= w
        }
        return items.lastOrNull()?.first
    }

    /** Start of the slot containing [instant]; slots are aligned to the local day start. */
    fun slotStart(instant: Instant, interval: RotationInterval, zone: ZoneId): Instant {
        val dayStart = startOfDay(instant, zone)
        val elapsed = Duration.between(dayStart, instant).seconds
        val index = Math.floorDiv(elapsed, interval.seconds)
        return dayStart.plusSeconds(index * interval.seconds)
    }

    /**
     * Slot starts from the slot containing [now] through `now + horizon`. Slots restart at each
     * local midnight, so a DST change only shifts that one day's slots.
     */
    fun slots(now: Instant, interval: RotationInterval, zone: ZoneId, horizon: Duration = Duration.ofHours(24)): List<Instant> {
        val end = now.plus(horizon)
        val result = mutableListOf<Instant>()
        var cursor = slotStart(now, interval, zone)
        while (cursor <= end) {
            result.add(cursor)
            var next = cursor.plusSeconds(interval.seconds)
            val nextDay = startOfDay(cursor, zone).plus(Duration.ofHours(36))
            val midnight = startOfDay(nextDay, zone)
            if (next > midnight) next = midnight
            cursor = next
        }
        return result
    }

    /** The next slot boundary after [now]. */
    fun nextSlot(now: Instant, interval: RotationInterval, zone: ZoneId): Instant =
        slots(now, interval, zone, Duration.ofSeconds(interval.seconds + 1)).firstOrNull { it > now }
            ?: now.plusSeconds(interval.seconds)
}
