# Media (images, video, viewer)

## Intent

Use consistent patterns for loading images, previewing media, and presenting a full-screen viewer.

## Core patterns

- Use `AsyncImage` as the baseline for remote images with loading states; it ships with SwiftUI and needs no extra dependency.
- Reach for Nuke's `LazyImage` only as an optional enhancement when you need disk caching, request de-duplication, prefetching, or GIF/video previews — don't require it by default.
- Use a shared viewer coordinator, constructed and owned at the app root, to present a full-screen media viewer from anywhere without prop-drilling.
- Use `openWindow` for desktop/visionOS and a sheet for iOS.

## Example: viewer coordinator constructed at the app root

```swift
@MainActor
@Observable
final class MediaViewerCoordinator {
  var selectedMediaAttachment: MediaAttachment?
  private(set) var mediaAttachments: [MediaAttachment] = []

  func prepareFor(selectedMediaAttachment: MediaAttachment, mediaAttachments: [MediaAttachment]) {
    self.mediaAttachments = mediaAttachments
    self.selectedMediaAttachment = selectedMediaAttachment
  }
}

struct AppRoot: View {
  @State private var mediaViewer = MediaViewerCoordinator()

  var body: some View {
    content
      .environment(mediaViewer)
      .sheet(item: $mediaViewer.selectedMediaAttachment) { selected in
        MediaUIView(selectedAttachment: selected, attachments: mediaViewer.mediaAttachments)
      }
  }
}
```

## Example: inline media preview with AsyncImage (baseline)

```swift
struct MediaPreviewRow: View {
  @Environment(MediaViewerCoordinator.self) private var mediaViewer

  let attachments: [MediaAttachment]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(attachments) { attachment in
          Button {
            mediaViewer.prepareFor(
              selectedMediaAttachment: attachment,
              mediaAttachments: attachments
            )
          } label: {
            AsyncImage(url: attachment.previewURL) { phase in
              if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fill)
              } else if phase.error != nil {
                Image(systemName: "photo").foregroundStyle(.secondary)
              } else {
                ProgressView()
              }
            }
            .frame(width: 120, height: 120)
            .clipped()
          }
          .buttonStyle(.plain)
          .accessibilityLabel(attachment.accessibilityDescription)
        }
      }
    }
  }
}
```

## Optional enhancement: Nuke's `LazyImage`

Swap `AsyncImage` for Nuke's `LazyImage` only when the baseline's lack of caching becomes a measurable problem (repeated re-downloads, jank while scrolling large media grids). The call site shape stays nearly identical:

```swift
import NukeUI

Button {
  mediaViewer.prepareFor(
    selectedMediaAttachment: attachment,
    mediaAttachments: attachments
  )
} label: {
  LazyImage(url: attachment.previewURL) { state in
    if let image = state.image {
      image.resizable().aspectRatio(contentMode: .fill)
    } else {
      ProgressView()
    }
  }
  .frame(width: 120, height: 120)
  .clipped()
}
.buttonStyle(.plain)
.accessibilityLabel(attachment.accessibilityDescription)
```

Treat this as an isolated, swappable detail behind the same view shape — don't let the Nuke dependency leak into the coordinator or the viewer sheet.

## Design choices to keep

- Keep previews lightweight; load full media in the viewer.
- Use a shared viewer coordinator so any view can open media without prop-drilling.
- Construct the coordinator once at the app root and inject it via `.environment(_:)`; never reach for a `static let shared` singleton.
- Use a single entry point for the viewer (sheet/window) to avoid duplicates.
- Wrap interactive media previews in a real `Button` with `.buttonStyle(.plain)` and an accessibility label; don't simulate button semantics with a tap gesture and manually added traits.

## Pitfalls

- Avoid loading full-size images in list rows; use resized previews.
- Don't present multiple viewer sheets at once; keep a single source of truth.
- Don't default to a third-party image library; only add one when `AsyncImage`'s caching behavior is a proven bottleneck.
