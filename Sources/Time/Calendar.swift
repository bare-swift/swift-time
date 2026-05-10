// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// A broken-down civil date. Used to serialize / parse text-format
/// timestamps (RFC 3339, RFC 1123) and to do basic year/month/day
/// arithmetic. **Not** a timezone-aware calendar.
///
/// The `offsetSeconds` field carries an explicit UTC offset
/// (`-18000` for `-05:00`, etc.). A `nil` value means "local — no
/// offset known"; per TOML 1.0's distinction between offset and local
/// datetime forms, this carries information the wire format does.
///
/// Leap seconds are not supported (`second` clamps to `0..<60`).
/// Locale-aware formatting and the IANA timezone database are out
/// of scope for v0.1.
public struct Calendar: Sendable, Equatable, Hashable {
    public var year: Int
    public var month: Int       // 1..12
    public var day: Int         // 1..31
    public var hour: Int        // 0..23
    public var minute: Int      // 0..59
    public var second: Int      // 0..59
    public var nanosecond: Int  // 0..999_999_999
    public var offsetSeconds: Int?

    public init(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0,
        nanosecond: Int = 0,
        offsetSeconds: Int? = 0
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.nanosecond = nanosecond
        self.offsetSeconds = offsetSeconds
    }

    /// Convert this civil date to a wall-clock ``Instant``. A nil
    /// `offsetSeconds` is treated as UTC (the spec for "local datetime"
    /// is "wall-clock without zone awareness"; consumers wanting
    /// strict-local semantics should verify the `offsetSeconds` themselves).
    public func toInstant() throws(TimeError) -> Instant {
        try validate()
        let days = Calendar.daysFromCivil(year: year, month: month, day: day)
        let secondsInDay = Int64(hour) * 3_600 + Int64(minute) * 60 + Int64(second)
        let totalSeconds = Int64(days) * 86_400 + secondsInDay - Int64(offsetSeconds ?? 0)
        let nanos = totalSeconds &* 1_000_000_000 &+ Int64(nanosecond)
        return Instant(nanosecondsSinceEpoch: nanos)
    }

    /// Build a calendar date from a wall-clock ``Instant``, optionally
    /// applied with a timezone offset.
    public static func from(_ instant: Instant, offsetSeconds: Int? = 0) -> Calendar {
        let totalNanos = instant.nanosecondsSinceEpoch &+ Int64(offsetSeconds ?? 0) &* 1_000_000_000
        // floor-divide toward negative infinity for nanoseconds within the day
        var nsPart = totalNanos % 1_000_000_000
        var totalSeconds = totalNanos / 1_000_000_000
        if nsPart < 0 {
            nsPart += 1_000_000_000
            totalSeconds -= 1
        }
        var dayPart = totalSeconds % 86_400
        var days = totalSeconds / 86_400
        if dayPart < 0 {
            dayPart += 86_400
            days -= 1
        }
        let hour = Int(dayPart / 3_600)
        let minute = Int((dayPart / 60) % 60)
        let second = Int(dayPart % 60)
        let (y, m, d) = civilFromDays(Int(days))
        return Calendar(
            year: y, month: m, day: d,
            hour: hour, minute: minute, second: second,
            nanosecond: Int(nsPart),
            offsetSeconds: offsetSeconds
        )
    }

    /// Validate field ranges. Days-per-month is checked against the
    /// proleptic Gregorian calendar (year > 0 / leap year aware).
    public func validate() throws(TimeError) {
        if month < 1 || month > 12 { throw .outOfRange(field: "month") }
        if day < 1 || day > Calendar.daysInMonth(year: year, month: month) {
            throw .outOfRange(field: "day")
        }
        if hour < 0 || hour > 23 { throw .outOfRange(field: "hour") }
        if minute < 0 || minute > 59 { throw .outOfRange(field: "minute") }
        if second < 0 || second > 59 { throw .outOfRange(field: "second") }
        if nanosecond < 0 || nanosecond > 999_999_999 {
            throw .outOfRange(field: "nanosecond")
        }
        if let off = offsetSeconds {
            // RFC 3339 limits offsets to ±24:00 inclusive of the 24:00 oddity.
            if off < -86_400 || off > 86_400 {
                throw .outOfRange(field: "offsetSeconds")
            }
        }
    }

    public static func isLeap(_ year: Int) -> Bool {
        if year % 4 != 0 { return false }
        if year % 100 != 0 { return true }
        return year % 400 == 0
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeap(year) ? 29 : 28
        default: return 0
        }
    }

    // MARK: - Civil ↔ days-from-epoch (Howard Hinnant, public domain)
    // http://howardhinnant.github.io/date_algorithms.html

    /// Days since 1970-01-01 (negative for earlier dates). The algorithm is
    /// proleptic Gregorian — extends the calendar backward without the
    /// Julian-style transitions.
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = month + (month > 2 ? -3 : 9)
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// Inverse of ``daysFromCivil(year:month:day:)``.
    static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp + (mp < 10 ? 3 : -9)
        let year = m <= 2 ? y + 1 : y
        return (year, m, d)
    }
}
