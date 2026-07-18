import FocusControl
import Foundation

/// Human-readable stdout/stderr lines matching PLAN §8 samples.
enum HumanOutput {
  static func successLine(command: ControlCommandName, response: ControlResponse) -> String {
    guard let state = response.state else {
      return "Focus updated."
    }
    let performed = response.result?.performed ?? true
    let seconds = state.secondsUntilNextTransition ?? 0
    let duration = formatDuration(seconds)

    switch command {
    case .status:
      return "Focus is running: \(state.phase), \(duration) until \(nextLabel(for: state))."

    case .start:
      return "Focus is active: \(state.phase), \(duration) until \(nextLabel(for: state))."

    case .pause:
      return
        "Paused during \(frozenPhaseHint(state)). \(duration) until \(nextLabel(for: state)) is frozen."

    case .resume:
      if performed {
        return "Focus resumed: \(state.phase), \(duration) until \(nextLabel(for: state))."
      }
      return "Focus is already active: \(state.phase), \(duration) until \(nextLabel(for: state))."

    case .snooze:
      return "Break snoozed for 1m. Next warning in \(duration)."

    case .triggerBreak:
      return "Break started. \(duration) remaining."

    case .skip:
      return "Break skipped. New focus cycle started."
    }
  }

  static func errorLine(
    exitCode: ControlExitCode,
    response: ControlResponse?,
    transport: ControlTransportError?
  ) -> String {
    if let message = response?.error?.message {
      return message
    }
    switch exitCode {
    case .success:
      return ""
    case .usageError:
      return "Invalid arguments."
    case .appNotRunning:
      return "Focus is not running."
    case .timeout:
      return "Timed out waiting for Focus."
    case .protocolMismatch:
      return "Unsupported focus-control protocol major version."
    case .rejected:
      return "Command rejected by current state."
    case .permissionFailure:
      return "Control endpoint peer check failed."
    case .internalError:
      if let transport {
        return "Unexpected control failure: \(transport)"
      }
      return "Unexpected control failure."
    }
  }

  static func formatDuration(_ totalSeconds: Int) -> String {
    let seconds = max(0, totalSeconds)
    let minutes = seconds / 60
    let rem = seconds % 60
    if minutes > 0 && rem > 0 {
      return "\(minutes)m \(rem)s"
    }
    if minutes > 0 {
      return "\(minutes)m"
    }
    return "\(rem)s"
  }

  private static func nextLabel(for state: ControlSessionState) -> String {
    switch state.phase {
    case "break":
      return "end"
    case "warning":
      return "break"
    case "paused":
      if state.breakEndsAt != nil {
        return "end"
      }
      return "warning"
    default:
      return "warning"
    }
  }

  private static func frozenPhaseHint(_ state: ControlSessionState) -> String {
    if state.breakEndsAt != nil {
      return "break"
    }
    return "focus"
  }
}
