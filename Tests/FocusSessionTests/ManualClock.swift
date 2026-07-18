import Foundation

/// Test-only wall clock. Advance explicitly; never sleep.
struct ManualClock: Sendable {
  var now: Date

  init(now: Date = Date(timeIntervalSince1970: 1_000_000)) {
    self.now = now
  }

  mutating func advance(by seconds: TimeInterval) {
    now = now.addingTimeInterval(seconds)
  }

  mutating func set(_ date: Date) {
    now = date
  }
}
