# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-05-10

### Added
- `Instant` — Sendable, Equatable, Hashable, Comparable wall-clock instant in UTC; signed `Int64` nanoseconds since the Unix epoch (range ±292 years either side of 1970). `+ Duration`, `- Duration`, `Instant - Instant -> Duration`.
- `Duration` — signed `Int64` nanoseconds; constructors for ns/μs/ms/s/min/hr; arithmetic operators (`+`, `-`, unary `-`); Comparable.
- `Calendar` — broken-down civil date with optional UTC `offsetSeconds` (`nil` = local-only). `toInstant()` / `from(_:offsetSeconds:)` round-trip via Howard Hinnant's proleptic-Gregorian `daysFromCivil` algorithm. `validate()` field-range checking; `isLeap(_:)` and `daysInMonth(year:month:)` helpers.
- `RFC3339.parse(_:) throws(TimeError) -> Calendar` and `RFC3339.serialize(_:) -> String` — full RFC 3339 grammar: `Z` and `±HH:MM` offsets, fractional seconds truncated to nanoseconds, date-only / local-datetime forms, lowercase `t`/`z`.
- `RFC1123.parse(_:) throws(TimeError) -> Calendar` and `RFC1123.serialize(_:) -> String` — IMF-fixdate (HTTP `Date:` / `Set-Cookie: Expires=`); permissive on weekday name on parse, strict on month abbreviation and `GMT` suffix; serializer always emits canonical form with weekday recomputed via Sakamoto's algorithm.
- `TimeError` typed-throws enum (`invalidFormat`, `outOfRange`, `invalidOffset`).

Closes the date/time gap committed to in [RFC-0010](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0010-foundation-free-date-time-policy.md). Foundation-tier package; no runtime dependencies.

### Dependencies
- None at runtime. Foundation-free.

### Limitations (out of scope for v0.1)
- IANA timezone database / zone-name resolution. Offsets are carried literally.
- Leap seconds. UTC arithmetic ignores them.
- Locale-aware formatting (English month/weekday names only).
- `Codable` conformance — Foundation-free + non-Codable differentiator.
- Stdlib `Swift.Duration` / `Clock` interop. v0.2 may add bridge functions.
- Asctime-style or non-`GMT` RFC 1123 inputs. Canonical IMF-fixdate only.
