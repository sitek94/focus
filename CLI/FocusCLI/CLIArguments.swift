import FocusControl

struct CLIParseError: Error, Equatable {
  var message: String
}

/// Parsed `focus` invocation.
struct CLIArguments: Equatable {
  var command: ControlCommandName?
  var json: Bool
  var version: Bool
  var help: Bool

  static func parse(_ args: [String]) -> Result<CLIArguments, CLIParseError> {
    var json = false
    var version = false
    var help = false
    var command: ControlCommandName?

    for arg in args {
      switch arg {
      case "--json":
        json = true
      case "--version":
        version = true
      case "--help", "-h":
        help = true
      case "status":
        guard command == nil else {
          return .failure(CLIParseError(message: "Unexpected extra command '\(arg)'."))
        }
        command = .status
      case "start":
        guard command == nil else {
          return .failure(CLIParseError(message: "Unexpected extra command '\(arg)'."))
        }
        command = .start
      case "pause":
        guard command == nil else {
          return .failure(CLIParseError(message: "Unexpected extra command '\(arg)'."))
        }
        command = .pause
      case "resume":
        guard command == nil else {
          return .failure(CLIParseError(message: "Unexpected extra command '\(arg)'."))
        }
        command = .resume
      case "skip":
        guard command == nil else {
          return .failure(CLIParseError(message: "Unexpected extra command '\(arg)'."))
        }
        command = .skip
      case "trigger-break":
        guard command == nil else {
          return .failure(CLIParseError(message: "Unexpected extra command '\(arg)'."))
        }
        command = .triggerBreak
      case "snooze":
        guard command == nil else {
          return .failure(CLIParseError(message: "Unexpected extra command '\(arg)'."))
        }
        command = .snooze
      default:
        return .failure(CLIParseError(message: "Unknown argument '\(arg)'."))
      }
    }

    if help || version {
      return .success(CLIArguments(command: command, json: json, version: version, help: help))
    }
    guard command != nil else {
      return .failure(
        CLIParseError(
          message: "Missing command. Try: focus status|start|pause|resume|skip|trigger-break|snooze"
        )
      )
    }
    return .success(CLIArguments(command: command, json: json, version: version, help: help))
  }
}

enum CLIHelp {
  static let text = """
    focus — control the Focus macOS app

    Usage:
      focus <command> [--json]
      focus --version
      focus --help

    Commands:
      status          Show current session state (does not launch Focus)
      start           Ensure Focus is running and the timer is active
      pause           Pause the current phase
      resume          Resume a paused session
      skip            Skip a warning or break
      trigger-break   Begin a full break immediately
      snooze          Snooze a warning for 1 minute

    Options:
      --json          Emit the stable machine-readable response on stdout
      --version       Print CLI version
      --help          Show this help
    """
}
