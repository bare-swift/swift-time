// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// Errors thrown by ``RFC3339`` and ``RFC1123`` parsers and by
/// ``Calendar/toInstant()`` when its fields are inconsistent.
public enum TimeError: Error, Equatable, Sendable {
    /// Input did not match the expected format.
    case invalidFormat(String)

    /// A field (year / month / day / hour / minute / second / nanosecond)
    /// fell outside its allowed range.
    case outOfRange(field: String)

    /// Timezone offset string could not be parsed.
    case invalidOffset(String)
}
