package com.enesseval.kilitkelime.core.learning

import java.security.SecureRandom

/**
 * A source of 64-bit random values, like Swift's `RandomNumberGenerator`.
 *
 * The helpers below reproduce the Swift standard library's algorithms (`Int.random(in:)`,
 * `Double.random(in:)`, `shuffled`, `randomElement`), so a seeded run picks the same values as the
 * iOS app.
 */
interface RandomSource {
    fun nextULong(): ULong
}

/** Deterministic generator (SplitMix64) for reproducible picks and tests. Port of `SeededGenerator.swift`. */
class SeededGenerator(seed: ULong) : RandomSource {
    private var state: ULong = seed

    override fun nextULong(): ULong {
        state += 0x9E3779B97F4A7C15uL
        var z = state
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return z xor (z shr 31)
    }
}

/** Device randomness for everything that does not need to be reproducible. */
class SystemRandom(private val random: java.util.Random = SecureRandom()) : RandomSource {
    override fun nextULong(): ULong = random.nextLong().toULong()
}

/** High 64 bits of the 128-bit product of two unsigned 64-bit values. */
internal fun multiplyHigh(a: ULong, b: ULong): ULong {
    val mask = 0xFFFFFFFFuL
    val aLo = a and mask
    val aHi = a shr 32
    val bLo = b and mask
    val bHi = b shr 32
    val loLo = aLo * bLo
    val hiLo = aHi * bLo
    val loHi = aLo * bHi
    val hiHi = aHi * bHi
    val cross = (loLo shr 32) + (hiLo and mask) + loHi
    return hiHi + (hiLo shr 32) + (cross shr 32)
}

/** A value in `0 until upperBound` without bias (Lemire), as Swift's `next(upperBound:)`. */
fun RandomSource.nextBelow(upperBound: ULong): ULong {
    require(upperBound != 0uL)
    var random = nextULong()
    var high = multiplyHigh(random, upperBound)
    var low = random * upperBound
    if (low < upperBound) {
        val t = (0uL - upperBound) % upperBound
        while (low < t) {
            random = nextULong()
            high = multiplyHigh(random, upperBound)
            low = random * upperBound
        }
    }
    return high
}

/** Swift `Int.random(in: lower..<upper)`. */
fun RandomSource.intUntil(lower: Int, upper: Int): Int {
    require(lower < upper)
    val delta = (upper.toLong() - lower.toLong()).toULong()
    return (lower.toLong() + nextBelow(delta).toLong()).toInt()
}

/** Swift `Int.random(in: range)` for a closed range. */
fun RandomSource.intIn(range: IntRange): Int = intUntil(range.first, range.last + 1)

/** Swift `Double.random(in: lower..<upper)`. */
fun RandomSource.doubleUntil(lower: Double, upper: Double): Double {
    require(lower < upper)
    val delta = upper - lower
    while (true) {
        val rand = nextULong() and ((1uL shl 53) - 1uL)
        val unit = rand.toDouble() * (Math.ulp(1.0) / 2)
        val value = delta * unit + lower
        if (value != upper) return value
    }
}

/** Swift `shuffled(using:)`: Fisher–Yates from the front. */
fun <T> List<T>.shuffledWith(rng: RandomSource): List<T> {
    val result = toMutableList()
    if (result.size < 2) return result
    var amount = result.size
    var current = 0
    while (amount > 1) {
        val random = rng.intUntil(0, amount)
        amount -= 1
        val other = current + random
        val tmp = result[current]
        result[current] = result[other]
        result[other] = tmp
        current += 1
    }
    return result
}

/** Swift `randomElement(using:)`. */
fun <T> List<T>.randomElementWith(rng: RandomSource): T? =
    if (isEmpty()) null else this[rng.intUntil(0, size)]
