import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

/// Connect / command / cold-start deadlines (PLAN §8).
public struct ControlTimeouts: Sendable, Equatable {
  public var connect: Duration
  public var command: Duration
  public var coldStart: Duration

  public init(
    connect: Duration = .milliseconds(250),
    command: Duration = .milliseconds(1_500),
    coldStart: Duration = .seconds(8)
  ) {
    self.connect = connect
    self.command = command
    self.coldStart = coldStart
  }

  public static let `default` = ControlTimeouts()

  /// Convert a `Duration` to a POSIX `timeval` for `setsockopt` timeouts.
  public static func makeTimeval(for duration: Duration) -> timeval {
    let components = duration.components
    var seconds = components.seconds
    var nanoseconds = components.attoseconds / 1_000_000_000
    if nanoseconds >= 1_000_000_000 {
      seconds += 1
      nanoseconds -= 1_000_000_000
    }
    var microseconds = nanoseconds / 1_000
    if seconds == 0 && microseconds == 0 {
      microseconds = 1
    }
    return timeval(tv_sec: time_t(seconds), tv_usec: suseconds_t(microseconds))
  }
}
