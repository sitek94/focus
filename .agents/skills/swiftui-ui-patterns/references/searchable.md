# Searchable

## Intent

Use `searchable` to add native search UI with optional scopes and async results.

## Core patterns

- Bind `searchable(text:)` to local state.
- Use `.searchScopes` for multiple search modes.
- Use `.task(id: searchQuery)` or debounced tasks to avoid overfetching.
- Show placeholders or progress states while results load.
- For the canonical `.task(id:)` restart/cancellation lifecycle (what happens when the query changes mid-flight), see `async-state.md`; this page focuses on the debounce delay itself.

## Example: searchable with scopes

```swift
@MainActor
struct ExploreView: View {
  @State private var searchQuery = ""
  @State private var searchScope: SearchScope = .all
  @State private var isSearching = false
  @State private var results: [SearchResult] = []

  var body: some View {
    List {
      if isSearching {
        ProgressView()
      } else {
        ForEach(results) { result in
          SearchRow(result: result)
        }
      }
    }
    .searchable(
      text: $searchQuery,
      prompt: Text("Search")
    )
    .searchScopes($searchScope) {
      ForEach(SearchScope.allCases, id: \.self) { scope in
        Text(scope.title)
      }
    }
    .task(id: searchQuery) {
      await runSearch()
    }
  }

  private func runSearch() async {
    guard !searchQuery.isEmpty else {
      results = []
      return
    }
    try? await Task.sleep(for: .milliseconds(250))
    guard !Task.isCancelled else { return }
    isSearching = true
    defer { isSearching = false }
    results = await fetchResults(query: searchQuery, scope: searchScope)
  }
}
```

The default placement keeps the example cross-platform. On an iOS-only screen that specifically needs a persistent navigation-bar search field, add `placement: .navigationBarDrawer(displayMode: .always)`.

## Design choices to keep

- Show a placeholder when search is empty or has no results.
- Debounce input to avoid spamming the network.
- Keep search state local to the view.

## Pitfalls

- Avoid running searches for empty strings.
- Don’t block the main thread during fetch.
- After a debounce `Task.sleep`, check `Task.isCancelled` before mutating state or fetching; `try?` swallows the cancellation error, so skipping this check lets a stale query run anyway. See `async-state.md` for the full restart/cancellation pattern.
