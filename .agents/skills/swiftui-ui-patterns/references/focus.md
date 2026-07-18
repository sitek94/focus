# Focus handling and field chaining

## Intent

Use `@FocusState` to control keyboard focus, chain fields, and coordinate focus across complex forms.

## Core patterns

- Use an enum to represent focusable fields.
- Set initial focus in `onAppear`.
- Use `.onSubmit` to move focus to the next field.
- For dynamic lists of fields, use an enum with associated values (e.g., `.option(Int)`).

## Example: single field focus

```swift
struct AddServerView: View {
  @State private var server = ""
  @FocusState private var isServerFieldFocused: Bool

  var body: some View {
    Form {
      TextField("Server", text: $server)
        .focused($isServerFieldFocused)
    }
    .onAppear { isServerFieldFocused = true }
  }
}
```

## Example: chained focus with enum

```swift
struct EditTagView: View {
  enum FocusField { case title, symbol, newTag }
  @FocusState private var focusedField: FocusField?

  var body: some View {
    Form {
      TextField("Title", text: $title)
        .focused($focusedField, equals: .title)
        .onSubmit { focusedField = .symbol }

      TextField("Symbol", text: $symbol)
        .focused($focusedField, equals: .symbol)
        .onSubmit { focusedField = .newTag }
    }
    .onAppear { focusedField = .title }
  }
}
```

## Example: dynamic focus for variable fields

Appending a new field and focusing it in the same synchronous update can race the view rebuild that creates the new `TextField`. Rather than guessing at a delay with `DispatchQueue.main.asyncAfter`, record the desired focus target as state and apply it in `.onChange(of:)` once the field count has actually updated:

```swift
struct PollView: View {
  enum FocusField: Hashable { case option(Int) }
  @FocusState private var focused: FocusField?
  @State private var options: [String] = ["", ""]
  @State private var pendingFocusIndex: Int?

  var body: some View {
    Form {
      ForEach(options.indices, id: \.self) { index in
        TextField("Option \(index + 1)", text: $options[index])
          .focused($focused, equals: .option(index))
          .onSubmit { addOption(after: index) }
      }
    }
    .onAppear { focused = .option(0) }
    .onChange(of: options.count) {
      guard let pendingFocusIndex else { return }
      focused = .option(pendingFocusIndex)
      self.pendingFocusIndex = nil
    }
  }

  private func addOption(after index: Int) {
    options.append("")
    pendingFocusIndex = index + 1
  }
}
```

If a view instead needs to wait one run-loop turn on the same actor (no state to observe), prefer a structured `Task { await Task.yield(); focused = ... }` scoped to the view's lifetime over an arbitrary `asyncAfter` delay — it still hands control back to SwiftUI without guessing at a duration.

## Design choices to keep

- Keep focus state local to the view that owns the fields.
- Use focus changes to drive UX (validation messages, helper UI).
- Pair with `.scrollDismissesKeyboard(...)` when using ScrollView/Form.

## Pitfalls

- Don’t store focus state in shared objects; it is view-local.
- Avoid aggressive focus changes during animation.
- Don't use `DispatchQueue.main.asyncAfter` with a guessed duration to "wait for" a view update; use `.onChange(of:)` on the state that actually changes, or `Task.yield()` inside a structured `Task`.
