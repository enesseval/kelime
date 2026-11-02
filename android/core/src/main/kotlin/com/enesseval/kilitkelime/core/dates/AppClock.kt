package com.enesseval.kilitkelime.core.dates

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Source of "now" and of the time zone used to turn it into local days.
 *
 * Everything that needs the current time takes an [AppClock], so tests can cross midnight and
 * DST boundaries. Port of `AppClock.swift`.
 */
class AppClock(
    private val nowProvider: () -> Instant,
    private val zoneProvider: () -> ZoneId,
) {
    val now: Instant get() = nowProvider()
    val zone: ZoneId get() = zoneProvider()
    val today: LocalDate get() = LocalDates.of(now, zone)

    companion object {
        /** The device clock and its current time zone, re-read on every call. */
        val system = AppClock({ Instant.now() }, { ZoneId.systemDefault() })

        /** A clock frozen at [instant] in [zone]. For tests and previews. */
        fun fixed(instant: Instant, zone: ZoneId) = AppClock({ instant }, { zone })
    }
}
