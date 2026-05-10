// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import Time

@Suite("Instant + Duration")
struct InstantDurationTests {
    @Test("Unix epoch")
    func epoch() {
        #expect(Instant.unixEpoch.nanosecondsSinceEpoch == 0)
    }

    @Test("comparison")
    func comparison() {
        let a = Instant(nanosecondsSinceEpoch: 1)
        let b = Instant(nanosecondsSinceEpoch: 2)
        #expect(a < b)
        #expect(b > a)
    }

    @Test("Instant + Duration")
    func plusDuration() {
        let i = Instant(nanosecondsSinceEpoch: 1_000)
        let d = Duration.nanoseconds(500)
        #expect((i + d).nanosecondsSinceEpoch == 1_500)
        #expect((i - d).nanosecondsSinceEpoch == 500)
    }

    @Test("Instant - Instant = Duration")
    func minusInstant() {
        let a = Instant(nanosecondsSinceEpoch: 1_000)
        let b = Instant(nanosecondsSinceEpoch: 600)
        #expect((a - b).nanoseconds == 400)
        #expect((b - a).nanoseconds == -400)
    }

    @Test("Duration constructors")
    func durationConstructors() {
        #expect(Duration.nanoseconds(1).nanoseconds == 1)
        #expect(Duration.microseconds(1).nanoseconds == 1_000)
        #expect(Duration.milliseconds(1).nanoseconds == 1_000_000)
        #expect(Duration.seconds(1).nanoseconds == 1_000_000_000)
        #expect(Duration.minutes(1).nanoseconds == 60_000_000_000)
        #expect(Duration.hours(1).nanoseconds == 3_600_000_000_000)
    }

    @Test("Duration arithmetic")
    func durationMath() {
        let a = Duration.seconds(5)
        let b = Duration.seconds(3)
        #expect((a + b).nanoseconds == 8_000_000_000)
        #expect((a - b).nanoseconds == 2_000_000_000)
        #expect((-a).nanoseconds == -5_000_000_000)
    }
}

@Suite("Calendar")
struct CalendarTests {
    @Test("epoch round-trips through Calendar")
    func epochRoundTrip() throws {
        let c = Calendar.from(.unixEpoch, offsetSeconds: 0)
        #expect(c.year == 1970)
        #expect(c.month == 1)
        #expect(c.day == 1)
        #expect(c.hour == 0)
        #expect(c.minute == 0)
        #expect(c.second == 0)
        #expect(try c.toInstant() == .unixEpoch)
    }

    @Test("known instant: 2026-05-10T07:30:00Z")
    func knownInstant() throws {
        // 20583 days from 1970-01-01 to 2026-05-10 (verified manually:
        // 56 years × 365 + 14 leap days = 20454; +129 days into 2026 = 20583).
        // 20583 × 86_400 + 7×3600 + 30×60 = 1_778_398_200 seconds.
        let cal = Calendar(year: 2026, month: 5, day: 10, hour: 7, minute: 30, second: 0)
        let inst = try cal.toInstant()
        #expect(inst.nanosecondsSinceEpoch == 1_778_398_200 * 1_000_000_000)
    }

    @Test("pre-epoch (1969-12-31T23:59:59Z = -1 second)")
    func preEpoch() throws {
        let cal = Calendar(year: 1969, month: 12, day: 31, hour: 23, minute: 59, second: 59)
        let inst = try cal.toInstant()
        #expect(inst.nanosecondsSinceEpoch == -1_000_000_000)
    }

    @Test("offset applied: 2026-01-01T05:00:00-05:00 = 2026-01-01T10:00:00Z")
    func offsetApplied() throws {
        let cal = Calendar(year: 2026, month: 1, day: 1, hour: 5, minute: 0, second: 0,
                           offsetSeconds: -5 * 3_600)
        let inst = try cal.toInstant()
        let utc = Calendar.from(inst, offsetSeconds: 0)
        #expect(utc.hour == 10)
        #expect(utc.day == 1)
    }

    @Test("validates out-of-range month")
    func invalidMonth() {
        let cal = Calendar(year: 2026, month: 13, day: 1)
        #expect(throws: TimeError.outOfRange(field: "month")) {
            try cal.toInstant()
        }
    }

    @Test("validates out-of-range day for February")
    func invalidFebDay() {
        let cal = Calendar(year: 2026, month: 2, day: 30)
        #expect(throws: TimeError.outOfRange(field: "day")) {
            try cal.toInstant()
        }
    }

    @Test("leap year February 29")
    func leapDay() throws {
        let cal = Calendar(year: 2024, month: 2, day: 29)
        let inst = try cal.toInstant()
        let back = Calendar.from(inst, offsetSeconds: 0)
        #expect(back.year == 2024)
        #expect(back.month == 2)
        #expect(back.day == 29)
    }

    @Test("isLeap covers Gregorian rules")
    func leapRules() {
        #expect(Calendar.isLeap(2000) == true)   // divisible by 400
        #expect(Calendar.isLeap(1900) == false)  // divisible by 100 but not 400
        #expect(Calendar.isLeap(2024) == true)   // divisible by 4 not 100
        #expect(Calendar.isLeap(2025) == false)
    }

    @Test("daysInMonth correctness")
    func daysInMonth() {
        #expect(Calendar.daysInMonth(year: 2024, month: 1) == 31)
        #expect(Calendar.daysInMonth(year: 2024, month: 2) == 29)
        #expect(Calendar.daysInMonth(year: 2025, month: 2) == 28)
        #expect(Calendar.daysInMonth(year: 2024, month: 4) == 30)
    }
}

@Suite("RFC 3339")
struct RFC3339Tests {
    @Test("offset datetime: 2026-05-10T07:30:00Z")
    func offsetZ() throws {
        let c = try RFC3339.parse("2026-05-10T07:30:00Z")
        #expect(c.year == 2026 && c.month == 5 && c.day == 10)
        #expect(c.hour == 7 && c.minute == 30 && c.second == 0)
        #expect(c.offsetSeconds == 0)
    }

    @Test("offset datetime: explicit ±HH:MM")
    func explicitOffset() throws {
        let c = try RFC3339.parse("2026-05-10T07:30:00-07:00")
        #expect(c.offsetSeconds == -7 * 3_600)

        let c2 = try RFC3339.parse("2026-05-10T07:30:00+05:30")
        #expect(c2.offsetSeconds == 5 * 3_600 + 30 * 60)
    }

    @Test("fractional seconds: nanosecond precision")
    func fractional() throws {
        let c = try RFC3339.parse("2026-05-10T07:30:00.123456789Z")
        #expect(c.nanosecond == 123_456_789)
    }

    @Test("fractional seconds: less than 9 digits are padded")
    func fractionalShort() throws {
        let c = try RFC3339.parse("2026-05-10T07:30:00.5Z")
        #expect(c.nanosecond == 500_000_000)
    }

    @Test("fractional seconds: more than 9 digits are truncated")
    func fractionalLong() throws {
        let c = try RFC3339.parse("2026-05-10T07:30:00.123456789999Z")
        #expect(c.nanosecond == 123_456_789)
    }

    @Test("date-only")
    func dateOnly() throws {
        let c = try RFC3339.parse("2026-05-10")
        #expect(c.year == 2026 && c.month == 5 && c.day == 10)
        #expect(c.hour == 0 && c.minute == 0 && c.second == 0)
        #expect(c.offsetSeconds == nil)
    }

    @Test("local datetime (no offset)")
    func localDatetime() throws {
        let c = try RFC3339.parse("2026-05-10T07:30:00")
        #expect(c.offsetSeconds == nil)
    }

    @Test("lowercase t / z accepted")
    func lowercase() throws {
        let c = try RFC3339.parse("2026-05-10t07:30:00z")
        #expect(c.offsetSeconds == 0)
    }

    @Test("malformed input throws")
    func malformed() {
        #expect(throws: (any Error).self) {
            try RFC3339.parse("not-a-date")
        }
        #expect(throws: (any Error).self) {
            try RFC3339.parse("2026-13-01T00:00:00Z")  // invalid month
        }
        #expect(throws: (any Error).self) {
            try RFC3339.parse("2026-05-10T07:30:00X")  // bad zone designator
        }
    }

    @Test("serialize Z form")
    func serializeZ() {
        let c = Calendar(year: 2026, month: 5, day: 10, hour: 7, minute: 30, second: 0,
                         offsetSeconds: 0)
        #expect(RFC3339.serialize(c) == "2026-05-10T07:30:00Z")
    }

    @Test("serialize explicit offset")
    func serializeOffset() {
        let c = Calendar(year: 2026, month: 5, day: 10, hour: 7, minute: 30, second: 0,
                         offsetSeconds: -5 * 3_600)
        #expect(RFC3339.serialize(c) == "2026-05-10T07:30:00-05:00")
    }

    @Test("serialize with fractional seconds (trim trailing zeros)")
    func serializeFractional() {
        let c = Calendar(year: 2026, month: 5, day: 10, hour: 7, minute: 30, second: 0,
                         nanosecond: 500_000_000, offsetSeconds: 0)
        #expect(RFC3339.serialize(c) == "2026-05-10T07:30:00.5Z")
    }

    @Test("parse → serialize round-trip")
    func roundTrip() throws {
        let inputs = [
            "2026-05-10T07:30:00Z",
            "2026-05-10T07:30:00.123456789Z",
            "2026-05-10T07:30:00-05:00",
            "2026-05-10T07:30:00+05:30",
            "1970-01-01T00:00:00Z",
        ]
        for s in inputs {
            let c = try RFC3339.parse(s)
            #expect(RFC3339.serialize(c) == s, "round-trip mismatch for \(s)")
        }
    }
}

@Suite("RFC 1123 (IMF-fixdate)")
struct RFC1123Tests {
    @Test("canonical: Wed, 09 Jun 2026 10:18:14 GMT")
    func canonical() throws {
        let c = try RFC1123.parse("Wed, 09 Jun 2026 10:18:14 GMT")
        #expect(c.year == 2026 && c.month == 6 && c.day == 9)
        #expect(c.hour == 10 && c.minute == 18 && c.second == 14)
        #expect(c.offsetSeconds == 0)
    }

    @Test("month abbreviation lookup")
    func monthLookup() throws {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        for (i, name) in names.enumerated() {
            let s = "Mon, 01 \(name) 2026 00:00:00 GMT"
            let c = try RFC1123.parse(s)
            #expect(c.month == i + 1)
        }
    }

    @Test("invalid month name")
    func invalidMonth() {
        #expect(throws: (any Error).self) {
            try RFC1123.parse("Mon, 01 Xxx 2026 00:00:00 GMT")
        }
    }

    @Test("non-GMT zone rejected (v0.1 only accepts canonical GMT)")
    func nonGMT() {
        #expect(throws: (any Error).self) {
            try RFC1123.parse("Mon, 01 Jan 2026 00:00:00 UTC")
        }
    }

    @Test("serialize matches canonical IMF-fixdate with computed weekday")
    func serializeCanonical() {
        // 2026-06-09 was a Tuesday.
        let c = Calendar(year: 2026, month: 6, day: 9, hour: 10, minute: 18, second: 14,
                         offsetSeconds: 0)
        #expect(RFC1123.serialize(c) == "Tue, 09 Jun 2026 10:18:14 GMT")
    }

    @Test("serialize Unix epoch (1970-01-01 was a Thursday)")
    func serializeEpoch() {
        let c = Calendar(year: 1970, month: 1, day: 1, hour: 0, minute: 0, second: 0,
                         offsetSeconds: 0)
        #expect(RFC1123.serialize(c) == "Thu, 01 Jan 1970 00:00:00 GMT")
    }

    @Test("parse → serialize round-trip canonicalizes weekday")
    func roundTrip() throws {
        // Even if the input has a wrong weekday, the serializer recomputes.
        let c = try RFC1123.parse("Mon, 09 Jun 2026 10:18:14 GMT")
        #expect(RFC1123.serialize(c) == "Tue, 09 Jun 2026 10:18:14 GMT")
    }

    @Test("offset-bearing Calendar serialized in UTC")
    func offsetCanonicalized() throws {
        // 2026-06-09T05:18:14-05:00 == 2026-06-09T10:18:14Z (Tuesday).
        let c = Calendar(year: 2026, month: 6, day: 9, hour: 5, minute: 18, second: 14,
                         offsetSeconds: -5 * 3_600)
        #expect(RFC1123.serialize(c) == "Tue, 09 Jun 2026 10:18:14 GMT")
    }
}

@Suite("End-to-end")
struct EndToEndTests {
    @Test("RFC 3339 → Instant → RFC 1123 (canonical HTTP Date)")
    func rfc3339ToHTTPDate() throws {
        let cal = try RFC3339.parse("2026-06-09T10:18:14Z")
        let _ = try cal.toInstant()  // would not have worked without RFC-0010
        #expect(RFC1123.serialize(cal) == "Tue, 09 Jun 2026 10:18:14 GMT")
    }

    @Test("RFC 1123 (Cookie Expires) → Instant → arithmetic")
    func cookieExpires() throws {
        // Set-Cookie: ... Expires=Wed, 09 Jun 2026 10:18:14 GMT
        let cal = try RFC1123.parse("Wed, 09 Jun 2026 10:18:14 GMT")
        let i = try cal.toInstant()
        let oneHourLater = i + .hours(1)
        let backToCal = Calendar.from(oneHourLater, offsetSeconds: 0)
        #expect(backToCal.hour == 11)
    }
}
