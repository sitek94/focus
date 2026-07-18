# Deep links and navigation

## Intent

Route external URLs into in-app destinations while falling back to system handling when needed.

## Core patterns

- Extend the canonical `RouterPath` (the `@MainActor @Observable` router defined in `navigationstack.md`) with URL handling instead of introducing a second, incompatible router type.
- Inject an `OpenURLAction` handler that delegates to the router.
- Use `.onOpenURL` for app scheme links and convert them to web URLs if needed.
- Let the router decide whether to navigate or fall back to system handling.

## Example: extend the canonical router

Add a `handle(url:)` method as an extension on `RouterPath` so there is exactly one router type and one place that owns navigation state. Resolve the URL into an existing `Route` case; return `nil` from the initializer for anything the app doesn't recognize so callers can fall back to `.systemAction`.

```swift
extension RouterPath {
  func handle(url: URL) -> OpenURLAction.Result {
    guard let route = Route(deepLinkURL: url) else {
      return .systemAction
    }
    navigate(to: route)
    return .handled
  }
}

extension Route {
  /// Maps an external URL's path to an existing route case. Keep this mapping
  /// generic to the app's own URL scheme/host; it should not assume any
  /// particular backend or protocol.
  init?(deepLinkURL url: URL) {
    switch url.pathComponents.dropFirst().first {
    case "account": self = .account(id: url.lastPathComponent)
    case "status": self = .status(id: url.lastPathComponent)
    default: return nil
    }
  }
}
```

## Example: attach to a root view

```swift
extension View {
  @MainActor
  func withLinkRouter(_ router: RouterPath) -> some View {
    self
      .environment(
        \.openURL,
        OpenURLAction { url in
          router.handle(url: url)
        }
      )
      .onOpenURL { url in
        _ = router.handle(url: url)
      }
  }
}
```

`withLinkRouter` is marked `@MainActor` because `RouterPath` is main-actor isolated; both closures above run on the main actor as a result, so calling into `router.handle(url:)` is safe without `@preconcurrency`, `@unchecked Sendable`, or other unsafe escapes.

## Design choices to keep

- Add URL handling to the canonical `RouterPath` via `extension`, not a second router class; this keeps one source of navigation truth.
- Keep URL parsing and decision logic inside the router (or a `Route` initializer), not scattered across views.
- Use the same `handle(url:)` entry point for both `OpenURLAction` and `.onOpenURL` so there is exactly one place that decides internal vs. external handling.
- Always fall back to `.systemAction` for URLs the app does not recognize.

## Pitfalls

- Don't assume a URL is internal; validate it (e.g., via a failable `Route` initializer) and return `.systemAction` otherwise.
- Avoid blocking UI while resolving remote links; use `Task` for any async resolution and keep the resulting state mutation on the main actor.
- Because `RouterPath` is `@MainActor`, keep the `View` helper and any closures that touch it `@MainActor`-isolated rather than reaching for unsafe escapes to call into it from a background context.
