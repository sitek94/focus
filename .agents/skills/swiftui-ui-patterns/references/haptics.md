# Haptics

## Intent

Use haptics sparingly to reinforce user actions (tab selection, refresh, success/error) and respect user preferences.

## Core patterns

- Use one concrete `@MainActor @Observable` model, with conditional iOS (`UIKit` generators) and macOS (`NSHapticFeedbackManager`) implementation details.
- Construct the model in `@State` at the app root, inject it by type with `.environment(_:)`, and read it with `@Environment(HapticFeedback.self)`.
- Gate haptics behind user preferences and hardware support.
- Use distinct types for different UX moments (selection vs. notification vs. refresh).

## Example: concrete cross-platform haptic model

```swift
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
@Observable
final class HapticFeedback {
  enum Event {
    case buttonPress
    case tabSelection
    case dataRefresh(intensity: CGFloat)
    case notification(NotificationStyle)
  }

  enum NotificationStyle {
    case success
    case warning
    case error
  }

  private let isEnabled: Bool

  #if os(iOS)
  private let selectionGenerator = UISelectionFeedbackGenerator()
  private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
  private let notificationGenerator = UINotificationFeedbackGenerator()
  #endif

  /// Pass `false` in previews and tests for a no-op model.
  init(isEnabled: Bool = true) {
    self.isEnabled = isEnabled
    #if os(iOS)
    if isEnabled {
      selectionGenerator.prepare()
    }
    #endif
  }

  func fire(_ event: Event) {
    guard isEnabled else { return }

    #if os(iOS)
    switch event {
    case .buttonPress:
      impactGenerator.impactOccurred()
    case .tabSelection:
      selectionGenerator.selectionChanged()
    case let .dataRefresh(intensity):
      impactGenerator.impactOccurred(intensity: intensity)
    case let .notification(style):
      let feedbackType: UINotificationFeedbackGenerator.FeedbackType =
        switch style {
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
      notificationGenerator.notificationOccurred(feedbackType)
    }
    #elseif os(macOS)
    let pattern: NSHapticFeedbackManager.FeedbackPattern =
      switch event {
      case .buttonPress, .tabSelection, .notification(.success), .notification(.warning):
        .generic
      case .dataRefresh, .notification(.error):
        .levelChange
      }
    NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    #else
    _ = event
    #endif
  }
}
```

## Example: environment injection at the app root

```swift
import SwiftUI

@main
struct MyApp: App {
  @State private var haptics = HapticFeedback()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(haptics)
    }
  }
}

#Preview {
  ContentView()
    .environment(HapticFeedback(isEnabled: false))
}
```

## Example: usage

```swift
import SwiftUI

struct SaveButton: View {
  @Environment(HapticFeedback.self) private var haptics
  @AppStorage("hapticsEnabled") private var hapticsEnabled = true

  var body: some View {
    Button("Save") {
      if hapticsEnabled {
        haptics.fire(.notification(.success))
      }
    }
  }
}

struct MainTabView: View {
  @Environment(HapticFeedback.self) private var haptics
  @AppStorage("hapticTabSelectionEnabled") private var hapticTabSelectionEnabled = true
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) { /* tabs */ }
      .onChange(of: selectedTab) { _, _ in
        if hapticTabSelectionEnabled {
          haptics.fire(.tabSelection)
        }
      }
  }
}
```

## Design choices to keep

- Haptics should be subtle and not fire on every tiny interaction.
- Respect user preferences (toggle to disable).
- Keep haptic triggers close to the user action, not deep in data layers.
- Own one `HapticFeedback` model at the app root and inject it by type.
- Use `HapticFeedback(isEnabled: false)` as a no-op dependency in previews and tests.

## Pitfalls

- Avoid firing multiple haptics in quick succession.
- Do not assume haptics are available; check support and gate behind preferences.
- Don't reach for a shared mutable singleton (`static let shared`); it hides the dependency and complicates testing/previews.
- Don't put an actor-isolated protocol existential behind a custom `EnvironmentKey`; its nonisolated static requirement and accessors conflict with the model's main-actor isolation under Swift 6.
