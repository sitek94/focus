import Foundation

/// Injected wall-clock seam. The reducer never reads global time itself.
public protocol WallClock: Sendable {
  var now: Date { get }
}

/// Production clock backed by `Date()`.
public struct SystemWallClock: WallClock {
  public init() {}

  public var now: Date { Date() }
}
