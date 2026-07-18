# Loading & Placeholders

Use this when a view needs a consistent loading state (skeletons, redaction, empty state) without blocking interaction.

## Patterns to prefer

- **Redacted placeholders** for list/detail content to preserve layout while loading.
- **ContentUnavailableView** for empty or error states after loading completes.
- **ProgressView** only for short, global operations (use sparingly in content-heavy screens).

## Recommended approach

1. Keep the real layout, render placeholder data, then apply `.redacted(reason: .placeholder)`.
2. For lists, show a fixed number of placeholder rows (avoid infinite spinners).
3. Switch to `ContentUnavailableView` when load finishes but data is empty.

## Accessibility and hit-testing

- `.redacted(reason: .placeholder)` only changes rendering; it does not stop VoiceOver from reading the fake placeholder text or stop taps from reaching placeholder rows.
- Add `.accessibilityHidden(true)` to the placeholder group (or give it a single summary label like "Loading") so VoiceOver doesn't announce fabricated row content one row at a time.
- Add `.allowsHitTesting(false)` to the placeholder group so taps/gestures on fake data can't trigger navigation or actions meant for real content.

## Pitfalls

- Don’t animate layout shifts during redaction; keep frames stable.
- Avoid nesting multiple spinners; use one loading indicator per section.
- Keep placeholder count small (3–6) to reduce jank on low-end devices.
- Don't leave placeholder rows focusable/tappable by VoiceOver or touch; pair `.redacted(reason: .placeholder)` with `.accessibilityHidden(true)` and `.allowsHitTesting(false)`.

## Minimal usage

```swift
VStack {
  if isLoading {
    ForEach(0..<3, id: \.self) { _ in
      RowView(model: .placeholder())
    }
    .redacted(reason: .placeholder)
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  } else if items.isEmpty {
    ContentUnavailableView("No items", systemImage: "tray")
  } else {
    ForEach(items) { item in RowView(model: item) }
  }
}
```
