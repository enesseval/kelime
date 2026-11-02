package com.enesseval.kilitkelime.core.dates

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * Local calendar days, stored as `YYYY-MM-DD` (port of `LocalDate.swift`).
 *
 * Every "day" concept (daily puzzle, learning "different days", weekly stats) is a day on the
 * device's local calendar. Never derive a day from UTC.
 */
object LocalDates {
    private val pattern = Regex("""\d{4}-\d{2}-\d{2}""")

    /** Fixed epoch for day indexes (daily puzzle rotation). */
    val EPOCH: LocalDate = LocalDate.of(2026, 1, 1)

    /** The local day that contains [instant] in [zone]. */
    fun of(instant: Instant, zone: ZoneId): LocalDate = instant.atZone(zone).toLocalDate()

    /** Parses `YYYY-MM-DD`; null for anything else, including impossible dates. */
    fun parse(text: String): LocalDate? {
        if (!pattern.matches(text)) return null
        return try {
            LocalDate.parse(text)
        } catch (_: Exception) {
            null
        }
    }
}

/** Start of this day in [zone]. Handles days that don't start at 00:00 (DST). */
fun LocalDate.startInstant(zone: ZoneId): Instant = atStartOfDay(zone).toInstant()

/** Whole days from [other] to this day (positive when this day is later). */
fun LocalDate.daysSince(other: LocalDate): Int = ChronoUnit.DAYS.between(other, this).toInt()

/** Days since [LocalDates.EPOCH]; negative for earlier days. */
val LocalDate.dayIndex: Int get() = daysSince(LocalDates.EPOCH)

fun LocalDate.addingDays(days: Int): LocalDate = plusDays(days.toLong())

/** Start of the local day that contains [instant]. */
fun startOfDay(instant: Instant, zone: ZoneId): Instant = LocalDates.of(instant, zone).startInstant(zone)
