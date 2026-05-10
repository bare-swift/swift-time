// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// A signed time span, expressed in nanoseconds.
///
/// `Time.Duration` shadows Swift stdlib's `Swift.Duration`; the bare-swift
/// type is intentionally simpler (`Int64` nanoseconds, no picoseconds) and
/// pairs with ``Instant`` for wall-clock arithmetic. If a consumer also
/// `import`s a stdlib clock module, qualify with `Time.Duration` to
/// disambiguate.
public struct Duration: Sendable, Equatable, Hashable, Comparable {
    /// Signed nanosecond count. Negative spans are allowed.
    public var nanoseconds: Int64

    public init(nanoseconds: Int64) {
        self.nanoseconds = nanoseconds
    }

    public static let zero = Duration(nanoseconds: 0)

    public static func nanoseconds(_ ns: Int64) -> Duration {
        Duration(nanoseconds: ns)
    }

    public static func microseconds(_ us: Int64) -> Duration {
        Duration(nanoseconds: us &* 1_000)
    }

    public static func milliseconds(_ ms: Int64) -> Duration {
        Duration(nanoseconds: ms &* 1_000_000)
    }

    public static func seconds(_ s: Int64) -> Duration {
        Duration(nanoseconds: s &* 1_000_000_000)
    }

    public static func minutes(_ m: Int64) -> Duration {
        Duration(nanoseconds: m &* 60 &* 1_000_000_000)
    }

    public static func hours(_ h: Int64) -> Duration {
        Duration(nanoseconds: h &* 3_600 &* 1_000_000_000)
    }

    public static func < (lhs: Duration, rhs: Duration) -> Bool {
        lhs.nanoseconds < rhs.nanoseconds
    }

    public static func + (lhs: Duration, rhs: Duration) -> Duration {
        Duration(nanoseconds: lhs.nanoseconds &+ rhs.nanoseconds)
    }

    public static func - (lhs: Duration, rhs: Duration) -> Duration {
        Duration(nanoseconds: lhs.nanoseconds &- rhs.nanoseconds)
    }

    public static prefix func - (operand: Duration) -> Duration {
        Duration(nanoseconds: 0 &- operand.nanoseconds)
    }
}
