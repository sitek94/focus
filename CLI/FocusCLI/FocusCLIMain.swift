import FocusControl
import FocusSession

@main
enum FocusCLIMain {
  static func main() {
    let args = CommandLine.arguments.dropFirst()
    if args.contains("--version") || args.contains("version") {
      print("focus 0.1.0-foundation")
      print("session=\(FocusSessionModule.moduleName)")
      print("control=\(FocusControlModule.moduleName)")
      return
    }

    print("focus: foundation stub — commands land in a later checkpoint")
    print("Try: focus --version")
  }
}
