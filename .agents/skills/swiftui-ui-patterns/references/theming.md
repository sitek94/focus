# Theming and dynamic type

## Intent

Provide a clean, scalable theming approach that keeps view code semantic and consistent.

## Core patterns

- Use a single `Theme` object as the source of truth (colors, fonts, spacing).
- Inject theme at the app root and read it via `@Environment(Theme.self)` in views.
- Prefer semantic colors (`primaryBackground`, `secondaryBackground`, `label`, `tint`) instead of raw colors.
- Keep user-facing theme controls in a dedicated settings screen.
- Apply Dynamic Type scaling with real APIs: semantic text styles (`.font(.body)`, `.headline`, etc., which already scale with the user's preferred text size), `@ScaledMetric` for custom numeric metrics (padding, icon size) that should grow and shrink with type size, and `.dynamicTypeSize(_:)` only when a layout needs to clamp the supported range.

## Example: Theme object

```swift
@MainActor
@Observable
final class Theme {
  var tintColor: Color = .blue
  var primaryBackground: Color = .white
  var secondaryBackground: Color = .gray.opacity(0.1)
  var labelColor: Color = .primary
}
```

## Example: inject at app root

```swift
@main
struct MyApp: App {
  @State private var theme = Theme()

  var body: some Scene {
    WindowGroup {
      AppView()
        .environment(theme)
    }
  }
}
```

## Example: view usage

```swift
struct ProfileView: View {
  @Environment(Theme.self) private var theme
  @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 44

  var body: some View {
    VStack {
      AvatarView()
        .frame(width: avatarSize, height: avatarSize)
      Text("Profile")
        .font(.headline)
        .foregroundStyle(theme.labelColor)
    }
    .background(theme.primaryBackground)
    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
  }
}
```

## Design choices to keep

- Keep theme values semantic and minimal; avoid duplicating system colors.
- Store user-selected theme values in persistent storage if needed.
- Ensure contrast between text and backgrounds.
- Let semantic text styles and `@ScaledMetric` drive Dynamic Type scaling; don't invent a custom scale-factor property on `Theme` to reimplement what the system already does.

## Pitfalls

- Avoid sprinkling raw `Color` values in views; it breaks consistency.
- Do not tie theme to a single view’s local state.
- Avoid using `@Environment(\.colorScheme)` as the only theme control; it should complement your theme.
- Don't invent APIs like `.font(.scaled...)` — scaling comes from using a semantic `Font` text style (which already tracks Dynamic Type) or from `@ScaledMetric` for non-text metrics.
