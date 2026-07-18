# Input toolbar (bottom anchored)

## Intent

Use a bottom-anchored input bar for chat, composer, or quick actions without fighting the keyboard.

## Core patterns

- Use `.safeAreaInset(edge: .bottom)` to anchor the toolbar above the keyboard.
- Keep the main content in a `ScrollView` or `List`.
- Drive focus with `@FocusState` and set initial focus when needed.
- Avoid embedding the input bar inside the scroll content; keep it separate.
- Only reach for `ScrollViewReader` when you actually call its proxy (e.g., scrolling to the newest message); otherwise skip it — an unused proxy is dead weight.

## Example: scroll view + bottom input, scrolling to the newest message

```swift
@MainActor
struct ConversationView: View {
  @FocusState private var isInputFocused: Bool
  @State private var messages: [Message] = []
  @State private var draft = ""

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack {
          ForEach(messages) { message in
            MessageRow(message: message)
              .id(message.id)
          }
        }
        .padding(.horizontal, .layoutPadding)
      }
      .safeAreaInset(edge: .bottom) {
        InputBar(text: $draft)
          .focused($isInputFocused)
      }
      .scrollDismissesKeyboard(.interactively)
      .onAppear { isInputFocused = true }
      .onChange(of: messages.last?.id) { _, newestID in
        guard let newestID else { return }
        withAnimation {
          proxy.scrollTo(newestID, anchor: .bottom)
        }
      }
    }
  }
}
```

If a screen never needs to jump to a specific row, drop `ScrollViewReader` entirely and use a plain `ScrollView { LazyVStack { ... } }` — don't wrap content in a reader whose `proxy` is never called.

## Design choices to keep

- Keep the input bar visually separated from the scrollable content.
- Use `.scrollDismissesKeyboard(.interactively)` for chat-like screens.
- Ensure send actions are reachable via keyboard return or a clear button.
- Only introduce `ScrollViewReader` when you need `proxy.scrollTo(...)`; give scrolled rows a stable `.id(...)` matching the identifier you scroll to.

## Pitfalls

- Avoid placing the input view inside the scroll stack; it will jump with content.
- Avoid nested scroll views that fight for drag gestures.
