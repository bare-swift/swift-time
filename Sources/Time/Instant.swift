// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// A wall-clock instant, expressed in nanoseconds since the Unix epoch
/// (1970-01-01T00:00:00Z).
///
/// Storage is signed `Int64`, so pre-1970 instants are representable;
/// the range is roughly ±292 years either side of the Unix epoch.
///
/// `Instant` is *wall-clock*, not monotonic. For monotonic / uptime
/// measurements use Swift stdlib's `ContinuousClock.Instant` —
/// `Time.Instant` is the wrong type for benchmarking.
public struct Instant: Sendable, Equatable, Hashable, Comparable {
    /// Nanoseconds since the Unix epoch. Negative values predate 1970.
    public var nanosecondsSinceEpoch: Int64

    public init(nanosecondsSinceEpoch: Int64) {
        self.nanosecondsSinceEpoch = nanosecondsSinceEpoch
    }

    /// The Unix epoch, 1970-01-01T00:00:00Z.
    public static let unixEpoch = Instant(nanosecondsSinceEpoch: 0)

    public static func < (lhs: Instant, rhs: Instant) -> Bool {
        lhs.nanosecondsSinceEpoch < rhs.nanosecondsSinceEpoch
    }

    public static func + (lhs: Instant, rhs: Duration) -> Instant {
        Instant(nanosecondsSinceEpoch: lhs.nanosecondsSinceEpoch &+ rhs.nanoseconds)
    }

    public static func - (lhs: Instant, rhs: Duration) -> Instant {
        Instant(nanosecondsSinceEpoch: lhs.nanosecondsSinceEpoch &- rhs.nanoseconds)
    }

    public static func - (lhs: Instant, rhs: Instant) -> Duration {
        Duration(nanoseconds: lhs.nanosecondsSinceEpoch &- rhs.nanosecondsSinceEpoch)
    }
}
