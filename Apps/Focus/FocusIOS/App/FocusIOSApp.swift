import SwiftUI

@main
struct FocusIOSApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

struct ContentView: View {
  var body: some View {
    VStack(spacing: 12) {
      Text("Focus")
        .font(.largeTitle.weight(.semibold))
      Text("iOS shell — foundation stub")
        .foregroundStyle(.secondary)
    }
    .padding()
  }
}
