// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// RFC 1123 / RFC 7231 IMF-fixdate parser and serializer. This is the
/// canonical HTTP `Date:` and `Set-Cookie: Expires=` format:
///
/// ```
/// Wed, 09 Jun 2026 10:18:14 GMT
/// ```
///
/// Parser is liberal on the weekday-name (any 3-letter prefix accepted —
/// not validated against the date) and strict on month name and zone.
/// Serializer always emits canonical `GMT`-suffixed IMF-fixdate with
/// the weekday matching the date.
public enum RFC1123 {
    /// Three-letter month abbreviations as ASCII; index 1..12 used.
    private static let months: [String] = [
        "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    /// Three-letter weekday abbreviations. Index 0 = Sunday.
    private static let weekdays: [String] = [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat",
    ]

    public static func parse(_ s: String) throws(TimeError) -> Calendar {
        var p = StringCursor(s)

        // Weekday is informational; consume up to ", ".
        try p.skipWeekdayPrefix(source: s)

        let day = try p.readDigits(2)
        try p.expect(" ")

        let month = try p.readMonth(source: s)
        try p.expect(" ")

        let year = try p.readDigits(4)
        try p.expect(" ")

        let hour = try p.readDigits(2)
        try p.expect(":")
        let minute = try p.readDigits(2)
        try p.expect(":")
        let second = try p.readDigits(2)
        try p.expect(" ")

        // Zone: `GMT` (only canonical form supported in v0.1).
        guard p.matches("GMT") else {
            throw .invalidOffset(s)
        }
        p.advance(3)

        if !p.isAtEnd {
            throw .invalidFormat(s)
        }

        let cal = Calendar(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second,
            nanosecond: 0,
            offsetSeconds: 0
        )
        try cal.validate()
        return cal
    }

    public static func serialize(_ c: Calendar) -> String {
        // Convert to UTC if a non-zero offset is set (the IMF-fixdate format
        // is GMT-only).
        let utc: Calendar
        if let off = c.offsetSeconds, off != 0 {
            // Best-effort: round-trip through Instant to drop the offset.
            // toInstant() can throw on out-of-range fields; fall back to the
            // raw values if it does (the serializer should be total).
            do {
                utc = Calendar.from(try c.toInstant(), offsetSeconds: 0)
            } catch {
                utc = c
            }
        } else {
            utc = c
        }

        let dow = weekdayIndex(year: utc.year, month: utc.month, day: utc.day)
        var out = weekdays[dow]
        out.append(", ")
        out.append(pad2(utc.day))
        out.append(" ")
        out.append(months[max(1, min(12, utc.month))])
        out.append(" ")
        out.append(pad4(utc.year))
        out.append(" ")
        out.append(pad2(utc.hour))
        out.append(":")
        out.append(pad2(utc.minute))
        out.append(":")
        out.append(pad2(utc.second))
        out.append(" GMT")
        return out
    }

    /// 0 = Sunday … 6 = Saturday. Sakamoto's method on the proleptic
    /// Gregorian calendar.
    private static func weekdayIndex(year: Int, month: Int, day: Int) -> Int {
        let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
        var y = year
        if month < 3 { y -= 1 }
        let raw = (y + y / 4 - y / 100 + y / 400 + t[month - 1] + day) % 7
        return ((raw % 7) + 7) % 7
    }

    private static func pad2(_ n: Int) -> String {
        let s = String(n < 0 ? -n : n)
        return s.count >= 2 ? s : "0" + s
    }

    private static func pad4(_ n: Int) -> String {
        let abs = n < 0 ? -n : n
        var s = String(abs)
        while s.count < 4 { s = "0" + s }
        return n < 0 ? "-" + s : s
    }
}

extension StringCursor {
    /// Consume any `XYZ, ` (3-letter weekday + comma + space). Permissive:
    /// doesn't verify the weekday letters spell a real day. RFC-conformant
    /// inputs are well-formed; lenient parsing accepts producer typos.
    mutating func skipWeekdayPrefix(source: String) throws(TimeError) {
        // Three letters
        guard cursor + 3 <= scalars.count else {
            throw .invalidFormat(source)
        }
        cursor += 3
        try expect(",")
        try expect(" ")
    }

    mutating func readMonth(source: String) throws(TimeError) -> Int {
        guard cursor + 3 <= scalars.count else {
            throw .invalidFormat(source)
        }
        let abbrev = String(String.UnicodeScalarView(scalars[cursor..<(cursor + 3)]))
        cursor += 3
        switch abbrev {
        case "Jan": return 1
        case "Feb": return 2
        case "Mar": return 3
        case "Apr": return 4
        case "May": return 5
        case "Jun": return 6
        case "Jul": return 7
        case "Aug": return 8
        case "Sep": return 9
        case "Oct": return 10
        case "Nov": return 11
        case "Dec": return 12
        default:
            throw .invalidFormat(source)
        }
    }

    func matches(_ literal: String) -> Bool {
        let lit = Array(literal.unicodeScalars)
        guard cursor + lit.count <= scalars.count else { return false }
        for i in 0..<lit.count {
            if scalars[cursor + i] != lit[i] { return false }
        }
        return true
    }
}
