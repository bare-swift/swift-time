# ``Time``

Foundation-free wall-clock time primitives — Sendable.

## Overview

`Time` ships the foundation-tier date/time primitives committed to in
[RFC-0010](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0010-foundation-free-date-time-policy.md):

- ``Instant`` — a wall-clock instant in UTC, stored as signed `Int64`
  nanoseconds since the Unix epoch (range: ±292 years either side of 1970).
- ``Duration`` — a signed time span in nanoseconds. Pairs with `Instant`
  for arithmetic.
- ``Calendar`` — a broken-down civil date (year/month/day/hour/minute/
  second/nanosecond) with optional UTC `offsetSeconds`. Round-trips to
  `Instant` via ``Calendar/toInstant()`` / ``Calendar/from(_:offsetSeconds:)``.
- ``RFC3339`` — parser and serializer for RFC 3339 datetimes (the format
  used by CBOR tag 0, TOML datetimes, modern HTTP). Truncates fractional
  seconds beyond nanosecond precision.
- ``RFC1123`` — parser and serializer for IMF-fixdate (the format used
  by `Set-Cookie: Expires=` and HTTP `Date:`). v0.1 accepts only canonical
  `GMT`-suffixed input on parse; serializer always emits canonical form
  with the weekday recomputed from the date.

The IANA timezone database, leap seconds, locale-aware formatting, and
Codable conformance are deliberately out of scope for v0.1.

```swift
import Time

// RFC 3339 round-trip
let cal = try RFC3339.parse("2026-05-10T07:30:00Z")
let instant = try cal.toInstant()
let later = instant + .hours(1)

// RFC 1123 (HTTP Date / Cookie Expires)
let httpDate = RFC1123.serialize(Calendar.from(later, offsetSeconds: 0))
// → "Sun, 10 May 2026 08:30:00 GMT"
```

## Topics

### Essentials

- ``Instant``
- ``Duration``
- ``Calendar``
- ``RFC3339``
- ``RFC1123``
- ``TimeError``
