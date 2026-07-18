# List and Section

## Intent

Use `List` for feed-style content and settings-style rows where built-in row reuse, selection, and accessibility matter.

## Core patterns

- Prefer `List` for long, vertically scrolling content with repeated rows.
- Use `Section` headers to group related rows.
- Pair with `ScrollViewReader` when you need scroll-to-top or jump-to-id.
- Use `.listStyle(.plain)` for modern feed layouts on iOS; on macOS prefer `.listStyle(.inset)` or `.listStyle(.sidebar)`, since `.plain`'s edge-to-edge row treatment is an iOS convention.
- Use `.listStyle(.grouped)` for multi-section discovery/search pages where section grouping helps; on macOS/iPadOS sidebars, `.listStyle(.sidebar)` is the platform-idiomatic equivalent.
- Apply `.scrollContentBackground(.hidden)` + a custom background when you need a themed surface.
- Use `.listRowInsets(...)` and `.listRowSeparator(.hidden)` to tune row spacing and separators.
- Use `.environment(\.defaultMinListRowHeight, ...)` to control dense list layouts.

## Example: feed list with scroll-to-top

Use a single sentinel row plus a counter to trigger scroll-to-top; avoid layering a second, separate "scroll to arbitrary id" mechanism on the same list unless you actually need to jump to a specific row.

```swift
@MainActor
struct TimelineListView: View {
  private enum Constants { static let topSentinel = "timeline-top" }
  @Environment(\.selectedTabScrollToTop) private var selectedTabScrollToTop

  var body: some View {
    ScrollViewReader { proxy in
      List {
        Color.clear
          .frame(height: 0)
          .listRowSeparator(.hidden)
          .id(Constants.topSentinel)
        ForEach(items) { item in
          TimelineRow(item: item)
            .id(item.id)
            .listRowInsets(.init(top: 12, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
        }
      }
      .listStyle(.plain)
      .environment(\.defaultMinListRowHeight, 1)
      .onChange(of: selectedTabScrollToTop) { _, _ in
        withAnimation {
          proxy.scrollTo(Constants.topSentinel, anchor: .top)
        }
      }
    }
  }
}
```

`selectedTabScrollToTop` is a per-tab counter that increments each time the user re-taps the already-selected tab; the list only needs to react to the value changing, not to any specific number. If a screen genuinely needs to jump to an arbitrary row (not just the top), reuse the same `ScrollViewReader` and add a separate `@State` id for that one case instead of mixing it into the tab-reselect trigger above.

## Example: settings-style list

```swift
@MainActor
struct SettingsView: View {
  var body: some View {
    List {
      Section("General") {
        NavigationLink("Display") { DisplaySettingsView() }
        NavigationLink("Haptics") { HapticsSettingsView() }
      }
      Section("Account") {
        Button("Sign Out", role: .destructive) {}
      }
    }
    .listStyle(.inset)
  }
}
```

`.inset` is available across Apple platforms. When the screen is iOS-only and should use the familiar Settings appearance, `.insetGrouped` is an iOS-specific alternative.

## Design choices to keep

- Use `List` for dynamic feeds, settings, and any UI where row semantics help.
- Use stable IDs for rows to keep animations and scroll positioning reliable.
- Prefer `.contentShape(Rectangle())` on rows that should be tappable end-to-end.
- Use `.refreshable` for pull-to-refresh feeds when the data source supports it.

## Pitfalls

- Avoid heavy custom layouts inside a `List` row; use `ScrollView` + `LazyVStack` instead.
- Be careful mixing `List` and nested `ScrollView`; it can cause gesture conflicts.
