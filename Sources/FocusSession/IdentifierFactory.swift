import Foundation

/// Supplies entity IDs for cycles and outcome events.
///
/// Use ``random`` in production. Tests should use ``deterministic(start:)`` so
/// reductions stay reproducible.
public struct IdentifierFactory: Sendable {
  private var nextSeed: UInt64?
  private var usesRandom: Bool

  /// System `UUID()` values.
  public static var random: IdentifierFactory {
    IdentifierFactory(nextSeed: nil, usesRandom: true)
  }

  /// Deterministic UUIDs derived from an incrementing counter.
  public static func deterministic(start: UInt64 = 0) -> IdentifierFactory {
    IdentifierFactory(nextSeed: start, usesRandom: false)
  }

  public mutating func next() -> UUID {
    if usesRandom {
      return UUID()
    }
    let seed = nextSeed ?? 0
    nextSeed = seed + 1
    return Self.makeDeterministicUUID(seed)
  }

  private static func makeDeterministicUUID(_ seed: UInt64) -> UUID {
    // Version-4-shaped UUID with a fixed variant nibble; only the node varies.
    let hex = String(seed, radix: 16, uppercase: true)
    let padded = String(repeating: "0", count: max(0, 12 - hex.count)) + hex
    let clipped = String(padded.suffix(12))
    return UUID(uuidString: "00000000-0000-4000-8000-\(clipped)")!
  }
}
