# swift-time

Foundation-free wall-clock time primitives (`Instant`, `Duration`, `Calendar`) plus RFC 3339 / RFC 1123 parsers — Sendable.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bare-swift/swift-time.git", from: "0.1.0")
```

Then depend on the `Time` product:

```swift
.product(name: "Time", package: "swift-time")
```

## Usage

```swift
import Time

// RFC 3339 round-trip
let cal = try RFC3339.parse("2026-05-10T07:30:00Z")
let instant = try cal.toInstant()
let later = instant + .hours(1)

// RFC 1123 (HTTP Date / Cookie Expires)
let httpDate = RFC1123.serialize(Calendar.from(later, offsetSeconds: 0))
// → "Sun, 10 May 2026 08:30:00 GMT"

// Arithmetic in nanoseconds (signed; negatives represent pre-epoch)
let span: Duration = later - instant
print(span.nanoseconds)  // 3_600_000_000_000
```

## Scope

Closes the date/time gap committed to in [RFC-0010](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0010-foundation-free-date-time-policy.md). v0.1 ships:

- `Instant` — wall-clock UTC, signed `Int64` nanoseconds since the Unix epoch (range ±292 years either side of 1970).
- `Duration` — signed `Int64` nanoseconds; constructors for ns/μs/ms/s/min/hr; `+`, `-`, unary `-`, `Comparable`.
- `Calendar` — broken-down civil date with optional UTC `offsetSeconds`; `toInstant()` / `from(_:offsetSeconds:)` round-trip; field validation; leap-year and `daysInMonth` helpers; proleptic Gregorian conversion via Howard Hinnant's days_from_civil algorithm.
- `RFC3339` — parser/serializer covering the full grammar: `Z` / `±HH:MM` offsets, fractional seconds (truncated to nanoseconds), date-only and local-datetime forms, lowercase `t`/`z`.
- `RFC1123` — parser/serializer for IMF-fixdate (HTTP `Date:` and `Set-Cookie: Expires=`); permissive on weekday name (recomputed on serialize), strict on month abbreviation and `GMT` suffix.
- `TimeError` typed-throws enum (`invalidFormat`, `outOfRange`, `invalidOffset`).

Out of scope for v0.1 (per RFC-0010):

- IANA timezone database / zone-name resolution. Offsets are carried literally.
- Leap seconds. UTC arithmetic ignores them.
- Locale-aware formatting (weekday/month names in non-English).
- `Codable` conformance — same Foundation-free / non-Codable differentiator as the rest of the ecosystem.
- Stdlib `Swift.Duration` / `Clock` interop. v0.2 may add bridge functions.
- Comment-/asctime-style RFC 1123 alternatives. Only canonical IMF-fixdate is parsed.

## Downstream adoption

Per RFC-0010, downstream packages with date semantics adopt `swift-time` *additively* in their next minor release:

- `swift-cookie` v0.2 — typed `Cookie.expiresAt: Calendar?` alongside the existing raw-string `expires`.
- `swift-tracing-otlp` / `swift-log-otlp` v0.2 — convenience initializers accepting `Time.Instant`.
- `swift-msgpack` v0.2 — `MsgPackValue.timestamp(Time.Instant)` case for ext-type −1.
- `swift-cbor` v0.2 — `CBOR.encodeDate(_:) / decodeDate(_:)` helpers for tags 0 and 1.
- `swift-toml` v0.2 — typed `TOMLValue.datetime(Time.Calendar)` accessor alongside the raw string.

No breaking changes to existing v0.1 APIs.

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-time/>

## Source

No upstream Rust crate; this is a native bare-swift package implementing RFC 3339 / RFC 1123 directly.

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
