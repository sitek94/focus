---
name: focus-swiftui
description: >
  Focus macOS SwiftUI guidance for MenuBarExtra, warning/break windows, standard
  Liquid Glass, localization, accessibility, and thin views. Use when editing
  FocusMac UI, AppKit window seams, or Settings.
upstream: https://github.com/AvdLee/SwiftUI-Agent-Skill
commit: f06d1437a3fbec7df6cdce93f77004e5409b31ee
source_paths:
  - swiftui-expert-skill/SKILL.md
  - swiftui-expert-skill/references/macos-scenes.md
  - swiftui-expert-skill/references/macos-window-styling.md
  - swiftui-expert-skill/references/liquid-glass.md
  - swiftui-expert-skill/references/localization.md
  - swiftui-expert-skill/references/accessibility-patterns.md
  - swiftui-expert-skill/references/view-structure.md
license: MIT
disposition: adapted
---

# Focus SwiftUI

## Provenance

| Field | Value |
|---|---|
| Upstream | https://github.com/AvdLee/SwiftUI-Agent-Skill |
| Commit | `f06d1437a3fbec7df6cdce93f77004e5409b31ee` |
| License | MIT |
| Disposition | **adapted** (not copied) |
| Source paths | `swiftui-expert-skill/SKILL.md`; `references/macos-scenes.md`; `macos-window-styling.md`; `liquid-glass.md`; `localization.md`; `accessibility-patterns.md`; `view-structure.md` |

Materially rewritten for Focus’s macOS 26 floor, menu-bar product, and locked timing UI. Upstream iOS/charts/trace/animation collections are intentionally omitted. Correct APIs against current Apple docs when examples disagree.

## Floor and non-goals

- Target **macOS 26+** (and iOS 26 shell only). Do not add `#available` fallbacks for older OS versions.
- Prefer native SwiftUI. Narrow AppKit only for per-display break overlays and activation seams (`PLAN.md` §10).
- Do not invent timing preferences, stats UI, or LookAway wording/visuals.
- Keep views thin: render state and send intents to `@MainActor` owners.

## Product surfaces

| Surface | Guidance |
|---|---|
| Menu bar | Primary scene is `MenuBarExtra`. Dockless via `LSUIElement`. Menu shows status + pause/resume/skip/trigger/snooze equivalents and Quit. |
| Warning | One compact SwiftUI panel on the current/main display: **Start now**, **Snooze 1 minute**, **Skip**. Tab/Shift-Tab and keyboard equivalents. Not full-screen, not multi-display. |
| Break overlay | `@MainActor` coordinator owns one borderless `NSWindow` per `CGDirectDisplayID`, each hosting the same SwiftUI content. Fail open on topology errors. |
| Settings | `Settings` scene for launch-at-login and update prefs only. No timing controls. |
| Commands | Wire menu/keyboard commands to the same intents as CLI (`start`, `pause`, `resume`, `skip`, `trigger-break`, `snooze`). Reconcile before applying. |

## Liquid Glass

Use **standard** macOS 26 controls and materials so platform glass appears without custom styling. Add `.glassEffect` only when a concrete interaction needs it and Mac a11y/visual review approves. Do not proactively glass-ify chrome.

## Localization

- English first; String Catalogs + `LocalizedStringResource` for non-view strings.
- Pass string literals to `Text`/`Button`/`Label` (auto `LocalizedStringKey`). Avoid eager `String(localized:)` in views.
- Use `Text(verbatim:)` only for non-localizable runtime/debug values.

## Accessibility

- Prefer `Button` over `onTapGesture`.
- Useful labels/help on warning and overlay actions; Escape skips from the primary overlay.
- System text styles / Dynamic Type; do not trap the user (no kiosk, no Accessibility-permission requirement).

## View structure

- Extract state-driven pieces into separate `View` structs; keep `body` cheap.
- Views observe `@MainActor` store; they do not own SQLite, sockets, or wake scheduling.
- Avoid `AnyView` and heavy work in `init`/`body`.

## Review checklist

1. macOS 26 APIs only; no pre-26 shims.
2. Menu bar + warning + overlay intents match CLI semantics.
3. Overlay windows keyed by display ID; hot-plug diffs without duplicates.
4. Standard materials first; custom glass only with justification.
5. Accessibility labels and keyboard path for warning/overlay actions.
