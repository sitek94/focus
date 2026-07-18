# Matched transitions

## Intent

Use matched transitions to create smooth continuity between a source view (thumbnail, avatar) and a destination view (sheet, detail, viewer).

## Core patterns

- Use a shared `Namespace` and a stable ID for the source.
- Use `matchedTransitionSource(id:in:)` + `navigationTransition(.zoom(sourceID:in:))`. The API is available starting in iOS 18: projects with an iOS 18+ minimum target can call it directly, while projects supporting earlier iOS versions must availability-gate the call. **`ZoomNavigationTransition` is unavailable on macOS**, so use compile-time platform gating there.
- Use `matchedGeometryEffect` for in-place transitions within a view hierarchy.
- Keep IDs stable across view updates: derive them from the model's own identifier, never a freshly generated random UUID.

## Example: gallery thumbnail to full-screen viewer (iOS 18+ minimum)

```swift
struct Photo: Identifiable, Hashable {
  let id: UUID
  let thumbnailURL: URL
  let fullURL: URL
}

struct PhotoGallery: View {
  @Namespace private var namespace
  let photos: [Photo]

  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
        ForEach(photos) { photo in
          NavigationLink {
            PhotoDetail(photo: photo)
              .zoomTransitionDestination(id: photo.id, in: namespace)
          } label: {
            AsyncImage(url: photo.thumbnailURL) { phase in
              (phase.image ?? Image(systemName: "photo"))
                .resizable()
                .aspectRatio(1, contentMode: .fill)
            }
            .accessibilityLabel("Photo")
          }
          .zoomTransitionSource(id: photo.id, in: namespace)
        }
      }
    }
  }
}

struct PhotoDetail: View {
  let photo: Photo

  var body: some View {
    AsyncImage(url: photo.fullURL) { phase in
      (phase.image ?? Image(systemName: "photo")).resizable().scaledToFit()
    }
    .accessibilityLabel("Photo detail")
  }
}
```

These helpers explicitly assume an iOS 18+ minimum target, so the iOS branch calls the API directly with no runtime legacy branch. The compile-time macOS branch returns the original view:

```swift
extension View {
  @ViewBuilder
  func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
    #if os(iOS)
    matchedTransitionSource(id: id, in: namespace)
    #else
    self
    #endif
  }

  @ViewBuilder
  func zoomTransitionDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
    #if os(iOS)
    navigationTransition(.zoom(sourceID: id, in: namespace))
    #else
    self
    #endif
  }
}
```

## Example: matched geometry within a view

```swift
struct ToggleBadge: View {
  @Namespace private var space
  @State private var isOn = false

  var body: some View {
    Button {
      withAnimation(.spring) { isOn.toggle() }
    } label: {
      Image(systemName: isOn ? "eye" : "eye.slash")
        .matchedGeometryEffect(id: "icon", in: space)
    }
    .accessibilityLabel(isOn ? "Hide" : "Show")
  }
}
```

## Design choices to keep

- Prefer `matchedTransitionSource` + `.zoom` for cross-screen transitions on iOS; compile the modifier out on macOS, where zoom navigation transitions are unavailable.
- Derive transition IDs from the model (e.g., `photo.id`), so the same item keeps the same ID across list reloads and state updates.
- Keep source and destination sizes reasonable to avoid jarring scale changes.
- Use `withAnimation` for state-driven transitions that aren't part of a navigation push/presentation.

## Pitfalls

- Don't use unstable IDs (fresh `UUID()` per render); it breaks the transition and defeats list diffing.
- Don't assume `.zoom` is available everywhere: use runtime availability gating when supporting iOS 17 or earlier, and compile-time platform gating for macOS, where it has no implementation.
- Avoid mismatched shapes (e.g., square to circle) unless the design expects it.
- Give icon-only source/destination controls an accessibility label; the matched transition itself carries no semantic meaning to VoiceOver.
