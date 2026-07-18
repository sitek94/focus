import SwiftUI

#if canImport(AppKit)
  import AppKit
#endif

@main
struct FocusMacApp: App {
  var body: some Scene {
    MenuBarExtra("Focus", systemImage: "timer") {
      Text("Focus")
      Text("Foundation shell")
      Divider()
      Button("Quit Focus") {
        terminateApp()
      }
      .keyboardShortcut("q")
    }
  }

  private func terminateApp() {
    #if canImport(AppKit)
      NSApp.terminate(nil)
    #endif
  }
}
