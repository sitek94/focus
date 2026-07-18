import Foundation

/// Fixed session timing policy. These values are not configurable.
public enum FocusPolicy: Sendable {
  /// Focus duration before a break is due.
  public static let focusDuration: TimeInterval = 1_200

  /// Warning occupies the final 10 seconds of the focus window.
  public static let warningDuration: TimeInterval = 10

  /// Full break duration.
  public static let breakDuration: TimeInterval = 20

  /// Snooze postpones the break due time by this many seconds from the action.
  public static let snoozeDuration: TimeInterval = 60

  /// Focus elapsed before the warning phase begins.
  public static let focusUntilWarning: TimeInterval = focusDuration - warningDuration

  public static let outcomeSchemaVersion = 1
}
