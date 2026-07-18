# Overlay and toasts

## Intent

Use overlays for transient UI (toasts, banners, loaders) without affecting layout.

## Core patterns

- Use `.overlay(alignment:)` to place global UI without changing the underlying layout.
- Keep overlays lightweight and dismissible.
- Use a dedicated `ToastCenter` (or similar) for global state if multiple features trigger toasts.
- Drive the auto-dismiss timer with an identity-aware `.task(id:)` so a newer toast automatically supersedes and cancels any older toast's timer.

## Example: toast overlay

```swift
struct Toast: Identifiable, Equatable {
  let id = UUID()
  let message: String
}

struct AppRootView: View {
  @State private var toast: Toast?

  var body: some View {
    content
      .overlay(alignment: .top) {
        if let toast {
          ToastView(toast: toast)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: toast.id) {
              try? await Task.sleep(for: .seconds(2))
              guard !Task.isCancelled else { return }
              withAnimation { self.toast = nil }
            }
        }
      }
  }
}
```

Because `.task(id:)` cancels its previous task whenever the `id` changes, replacing `toast` with a new value (a new `id`) automatically cancels the old dismiss timer before starting a new one. An older timer can never race ahead and dismiss a newer toast.

## Design choices to keep

- Prefer overlays for transient UI rather than embedding in layout stacks.
- Use transitions and a `.task(id:)`-driven auto-dismiss timer tied to the toast's stable identity.
- Keep the overlay aligned to a clear edge (`.top` or `.bottom`).

## Pitfalls

- Avoid overlays that block all interaction unless explicitly needed.
- Don’t stack many overlays; use a queue or replace the current toast.
- Don't dismiss with a raw `DispatchQueue.main.asyncAfter` timer keyed to `.onAppear`; it keeps running even after the toast is replaced, so an old timer can dismiss a newer toast.
