// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// RFC 3339 date/time parser and serializer.
///
/// Supports the full RFC 3339 grammar:
/// - `YYYY-MM-DDTHH:MM:SS[.fraction][Z|±HH:MM]`
/// - The literal `T` separator may be lowercase `t` or a single space.
/// - The `Z` zone designator may be lowercase `z`.
/// - Fractional seconds can carry any precision; truncated to nanoseconds
///   (anything past 9 digits is dropped).
/// - Local-only datetimes (no zone designator) parse with
///   `offsetSeconds = nil`.
public enum RFC3339 {
    public static func parse(_ s: String) throws(TimeError) -> Calendar {
        var p = StringCursor(s)

        let year = try p.readDigits(4)
        try p.expect("-")
        let month = try p.readDigits(2)
        try p.expect("-")
        let day = try p.readDigits(2)

        // Date-only?
        if p.isAtEnd {
            return Calendar(year: year, month: month, day: day, offsetSeconds: nil)
        }

        // Date-time separator: T / t / space.
        guard let sep = p.peek(), sep == "T" || sep == "t" || sep == " " else {
            throw .invalidFormat(s)
        }
        p.advance()

        let hour = try p.readDigits(2)
        try p.expect(":")
        let minute = try p.readDigits(2)
        try p.expect(":")
        let second = try p.readDigits(2)

        var nanos = 0
        if p.peek() == "." {
            p.advance()
            var digits = 0
            var n = 0
            while let c = p.peek(), c >= "0" && c <= "9" {
                if digits < 9 {
                    n = n * 10 + Int(c.value - 0x30)
                }
                digits += 1
                p.advance()
            }
            // Pad to nanoseconds if fewer than 9 fractional digits were
            // given; overlong fractions were already truncated by the
            // `digits < 9` cap on `n` above.
            if digits < 9 {
                for _ in digits..<9 { n *= 10 }
            }
            nanos = n
        }

        let offsetSeconds: Int?
        if p.isAtEnd {
            offsetSeconds = nil
        } else {
            offsetSeconds = try parseOffset(&p, source: s)
        }

        if !p.isAtEnd {
            throw .invalidFormat(s)
        }

        let cal = Calendar(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second,
            nanosecond: nanos,
            offsetSeconds: offsetSeconds
        )
        try cal.validate()
        return cal
    }

    public static func serialize(_ c: Calendar) -> String {
        var out = ""
        out.append(pad4(c.year))
        out.append("-")
        out.append(pad2(c.month))
        out.append("-")
        out.append(pad2(c.day))
        // If only a date is meaningful, RFC 3339 still requires the time
        // when an offset is given. v0.1: always emit the time when any
        // time field is non-zero or an offset is present.
        let hasTime = c.hour != 0 || c.minute != 0 || c.second != 0 || c.nanosecond != 0
        if hasTime || c.offsetSeconds != nil {
            out.append("T")
            out.append(pad2(c.hour))
            out.append(":")
            out.append(pad2(c.minute))
            out.append(":")
            out.append(pad2(c.second))
            if c.nanosecond > 0 {
                out.append(".")
                out.append(formatFraction(c.nanosecond))
            }
            if let off = c.offsetSeconds {
                if off == 0 {
                    out.append("Z")
                } else {
                    out.append(off >= 0 ? "+" : "-")
                    let abs = off < 0 ? -off : off
                    out.append(pad2(abs / 3_600))
                    out.append(":")
                    out.append(pad2((abs / 60) % 60))
                }
            }
        }
        return out
    }

    // MARK: - Helpers

    private static func parseOffset(_ p: inout StringCursor, source: String) throws(TimeError) -> Int {
        guard let c = p.peek() else {
            throw .invalidOffset(source)
        }
        if c == "Z" || c == "z" {
            p.advance()
            return 0
        }
        guard c == "+" || c == "-" else {
            throw .invalidOffset(source)
        }
        let sign: Int = (c == "+" ? 1 : -1)
        p.advance()
        let h = try p.readDigits(2)
        try p.expect(":")
        let m = try p.readDigits(2)
        if h > 24 || m > 59 { throw .invalidOffset(source) }
        return sign * (h * 3_600 + m * 60)
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

    private static func formatFraction(_ nanos: Int) -> String {
        var s = String(nanos)
        while s.count < 9 { s = "0" + s }
        // Trim trailing zeros for compact output.
        while s.last == "0" { s.removeLast() }
        return s
    }
}

/// Cursor over a `String`'s Unicode scalars used by RFC 3339 / RFC 1123
/// parsers. Tracks position only — no line/column because both formats
/// are single-line.
struct StringCursor {
    let scalars: [Unicode.Scalar]
    var cursor: Int = 0

    init(_ s: String) {
        self.scalars = Array(s.unicodeScalars)
    }

    var isAtEnd: Bool { cursor >= scalars.count }

    func peek(offset: Int = 0) -> Unicode.Scalar? {
        let i = cursor + offset
        return i < scalars.count ? scalars[i] : nil
    }

    mutating func advance(_ n: Int = 1) {
        cursor = min(cursor + n, scalars.count)
    }

    mutating func expect(_ scalar: Unicode.Scalar) throws(TimeError) {
        guard let c = peek(), c == scalar else {
            throw .invalidFormat(String(String.UnicodeScalarView(scalars)))
        }
        advance()
    }

    mutating func readDigits(_ count: Int) throws(TimeError) -> Int {
        guard cursor + count <= scalars.count else {
            throw .invalidFormat(String(String.UnicodeScalarView(scalars)))
        }
        var n = 0
        for _ in 0..<count {
            let c = scalars[cursor]
            guard c.value >= 0x30 && c.value <= 0x39 else {
                throw .invalidFormat(String(String.UnicodeScalarView(scalars)))
            }
            n = n * 10 + Int(c.value - 0x30)
            cursor += 1
        }
        return n
    }
}
