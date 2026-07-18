# App wiring and dependency graph

## Intent

Show how to wire the app shell (TabView + NavigationStack + sheets) and install a global dependency graph (environment values, services, an activity watcher, a SwiftData `ModelContainer`) in one place.

## Recommended structure

1) Root view sets up tabs, per-tab routers, and sheets.
2) A dedicated view modifier installs global dependencies and lifecycle tasks (session state, activity watchers, push tokens, data containers).
3) Feature views pull only what they need from the environment; feature-specific state stays local.

## Dependency selection

- Use `@Environment` for app-level services, shared clients, theme/configuration, and values that many descendants genuinely need.
- Prefer initializer injection for feature-local dependencies and models. Do not move a dependency into the environment just to avoid passing one or two arguments.
- Keep mutable feature state out of the environment unless it is intentionally shared across broad parts of the app.
- Construct app-level dependencies once at the app root and pass them down explicitly. Avoid mutable singleton statics (`static let shared` / `static var shared`) as default parameter values — they hide the dependency graph and make previews/tests harder to isolate.

## App-level dependency bag (generic)

Group root-owned dependencies into one small struct constructed once, instead of scattering `= .shared` defaults through modifier signatures.

```swift
@MainActor
struct AppDependencies {
  let sessionManager = SessionManager()
  let currentUser = CurrentUser()
  let currentWorkspace = CurrentWorkspace()
  let preferences = Preferences()
  let theme = Theme()
  let activityWatcher = ActivityWatcher()
  let pushService = PushService()
  let toastCenter = ToastCenter()
}
```

`AppDependencies` is a plain, `@MainActor`-isolated value that holds immutable references to app-owned `@Observable` services. The services remain independently observable; the dependency bag itself does not need to be observable because its references do not change after construction.

## Root shell example (generic)

```swift
@main
@MainActor
struct MyApp: App {
  private let dependencies = AppDependencies()

  var body: some Scene {
    WindowGroup {
      AppView(dependencies: dependencies)
    }
  }
}
```

```swift
@MainActor
struct AppView: View {
  let dependencies: AppDependencies
  @State private var selectedTab: AppTab = .home
  @State private var tabRouter = TabRouter(tabs: AppTab.allCases)

  var body: some View {
    TabView(selection: $selectedTab) {
      ForEach(AppTab.allCases) { tab in
        if let router = tabRouter.router(for: tab) {
          NavigationStack(path: Binding(
            get: { router.path },
            set: { router.path = $0 }
          )) {
            tab.makeContentView()
          }
          .withSheetDestinations(sheet: Binding(
            get: { router.presentedSheet },
            set: { router.presentedSheet = $0 }
          ))
          .environment(router)
          .tabItem { tab.label }
          .tag(tab)
        }
      }
    }
    .withAppDependencyGraph(dependencies)
  }
}
```

Minimal `AppTab` example:

```swift
@MainActor
enum AppTab: Identifiable, Hashable, CaseIterable {
  case home, notifications, settings
  var id: String { String(describing: self) }

  @ViewBuilder
  func makeContentView() -> some View {
    switch self {
    case .home: HomeView()
    case .notifications: NotificationsView()
    case .settings: SettingsView()
    }
  }

  @ViewBuilder
  var label: some View {
    switch self {
    case .home: Label("Home", systemImage: "house")
    case .notifications: Label("Notifications", systemImage: "bell")
    case .settings: Label("Settings", systemImage: "gear")
    }
  }
}
```

Router skeleton:

```swift
@MainActor
@Observable
final class RouterPath {
  var path: [Route] = []
  var presentedSheet: SheetDestination?
}

@MainActor
@Observable
final class TabRouter {
  private let routers: [AppTab: RouterPath]

  init(tabs: [AppTab]) {
    var routers: [AppTab: RouterPath] = [:]
    for tab in tabs {
      routers[tab] = RouterPath()
    }
    self.routers = routers
  }

  func router(for tab: AppTab) -> RouterPath? {
    routers[tab]
  }
}

enum Route: Hashable {
  case detail(id: String)
}
```

## Dependency graph modifier (generic)

Take the constructed `AppDependencies` explicitly (no defaulted singleton parameters) and install each piece into the environment. A single modifier keeps wiring consistent and avoids forgetting a dependency at call sites, and reacts to session changes with `.task(id:)`.

```swift
extension View {
  @MainActor
  func withAppDependencyGraph(
    _ dependencies: AppDependencies,
    namespace: Namespace.ID? = nil
  ) -> some View {
    environment(dependencies.sessionManager)
      .environment(dependencies.sessionManager.currentSession)
      .environment(dependencies.currentUser)
      .environment(dependencies.currentWorkspace)
      .environment(dependencies.preferences)
      .environment(dependencies.theme)
      .environment(dependencies.activityWatcher)
      .environment(dependencies.pushService)
      .environment(dependencies.toastCenter)
      .task(id: dependencies.sessionManager.currentSession.id) {
        let session = dependencies.sessionManager.currentSession
        dependencies.currentUser.setSession(session)
        dependencies.currentWorkspace.setSession(session)
        dependencies.preferences.setSession(session)
        await dependencies.currentWorkspace.fetchWorkspaceInfo()
        dependencies.activityWatcher.setSession(
          session,
          endpoint: dependencies.currentWorkspace.info?.activityEndpoint
        )
        if session.isAuthenticated {
          dependencies.activityWatcher.watch(topics: [.mentions, .direct])
        } else {
          dependencies.activityWatcher.stopWatching()
        }
      }
      .task(id: dependencies.sessionManager.pushTokens) {
        dependencies.pushService.tokens = dependencies.sessionManager.pushTokens
      }
  }
}
```

Notes:
- The `.task(id:)` hooks respond to session changes, re-seeding services and watcher state.
- Keep the modifier focused on global wiring; feature-specific state stays within features.
- Adjust types (`SessionManager`, `ActivityWatcher`, etc.) to match your project.
- Because `dependencies` is constructed once at the root and passed down, previews and tests can supply their own `AppDependencies` instance instead of touching a global singleton.

## SwiftData / ModelContainer

Install your `ModelContainer` at the root so all feature views share the same store. Keep the list minimal to the models that need persistence.

```swift
extension View {
  func withModelContainer() -> some View {
    modelContainer(for: [Draft.self, CachedList.self, Tag.self])
  }
}
```

Why: a single container avoids duplicated stores per sheet or tab and keeps data consistent.

## Sheet routing (enum-driven)

Centralize sheets with a small enum and a helper modifier.

```swift
enum SheetDestination: Identifiable {
  case composer
  case settings
  var id: String { String(describing: self) }
}

extension View {
  func withSheetDestinations(sheet: Binding<SheetDestination?>) -> some View {
    sheet(item: sheet) { destination in
      switch destination {
      case .composer:
        ComposerView().withEnvironments()
      case .settings:
        SettingsView().withEnvironments()
      }
    }
  }
}
```

Why: enum-driven sheets keep presentation centralized and testable; adding a new sheet means adding one enum case and one switch branch.

## When to use

- Apps with multiple packages/modules that share environment values and services.
- Apps that need to react to session changes and rewire an activity watcher/push tokens safely.
- Any app that wants consistent TabView + NavigationStack + sheet wiring without repeating environment setup.

## Caveats

- Keep the dependency modifier slim; do not put feature state or heavy logic there.
- Ensure `.task(id:)` work is lightweight or cancelled appropriately; long-running work belongs in services.
- If unauthenticated sessions exist, gate watcher/streaming calls to avoid reconnect spam.
- Keep ownership explicit: construct `AppDependencies` at the app root and inject it into the view hierarchy.
