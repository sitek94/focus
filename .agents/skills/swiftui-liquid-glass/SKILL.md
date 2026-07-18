---
name: swiftui-liquid-glass
description: Implement, review, or improve SwiftUI features using the iOS 26+ / macOS 26+ Liquid Glass API. Use when asked to adopt Liquid Glass in new SwiftUI UI, refactor an existing feature to Liquid Glass, or review Liquid Glass usage for correctness, performance, and design alignment.
---

# SwiftUI Liquid Glass

## Overview
Use this skill to build or review SwiftUI features that fully align with the iOS 26+ / macOS 26+ Liquid Glass API. Prioritize native APIs (`glassEffect`, `GlassEffectContainer`, glass button styles) and Apple design guidance. Keep usage consistent, interactive where needed, and performance aware. Liquid Glass ships on both iOS and macOS (and iPadOS/visionOS); apply the same guidance on macOS, adjusting only for platform-specific containers (e.g. `NavigationSplitView` sidebars/inspectors) rather than treating this as iOS-only.

## Availability first
Before applying availability guidance, check the consuming app's minimum deployment target:
- **Deployment target is iOS 26 / macOS 26 or later:** no availability shim is needed. Call Liquid Glass APIs unconditionally — skip `#available` checks and non-glass fallback code entirely.
- **Deployment target is below iOS 26 / macOS 26:** gate every Liquid Glass call with `#available(iOS 26, macOS 26, *)` for an iOS/macOS app, adding other shipped platforms explicitly, and provide a sensible non-glass fallback for older OS versions.

## Workflow Decision Tree
Choose the path that matches the request:

### 1) Review an existing feature
- Inspect where Liquid Glass should be used and where it should not.
- Verify correct modifier order, shape usage, and container placement.
- Confirm the app's deployment target, then check availability handling accordingly: `#available` gating and fallbacks only matter below an iOS/macOS 26 floor; flag them as unnecessary complexity on a 26+ floor.

### 2) Improve a feature using Liquid Glass
- Identify target components for glass treatment (surfaces, chips, buttons, cards).
- Refactor to use `GlassEffectContainer` where multiple glass elements appear.
- Introduce interactive glass only for tappable or focusable elements.

### 3) Implement a new feature using Liquid Glass
- Design the glass surfaces and interactions first (shape, prominence, grouping).
- Add glass modifiers after layout/appearance modifiers.
- Add morphing transitions only when the view hierarchy changes with animation.

## Core Guidelines
- Prefer native Liquid Glass APIs over custom blurs.
- Use `GlassEffectContainer` when multiple glass elements coexist.
- Apply `.glassEffect(...)` after layout and visual modifiers.
- Use `.interactive()` for elements that respond to touch/pointer.
- Keep shapes consistent across related elements for a cohesive look.
- If the deployment target is below iOS/macOS 26, gate with `#available` and provide a non-glass fallback. If the deployment target is iOS/macOS 26+, call the APIs unconditionally with no shim.

## Review Checklist
- **Availability**: below a 26 floor, `#available` gating is present with fallback UI; on a 26+ floor, confirm no unnecessary gating/fallback code was added.
- **Composition**: Multiple glass views wrapped in `GlassEffectContainer`.
- **Modifier order**: `glassEffect` applied after layout/appearance modifiers.
- **Interactivity**: `interactive()` only where user interaction exists.
- **Transitions**: `glassEffectID` used with `@Namespace` for morphing.
- **Consistency**: Shapes, tinting, and spacing align across the feature.

## Implementation Checklist
- Define target elements and desired glass prominence.
- Wrap grouped glass elements in `GlassEffectContainer` and tune spacing.
- Use `.glassEffect(.regular.tint(...).interactive(), in: .rect(cornerRadius: ...))` as needed.
- Use `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` for actions.
- Add morphing transitions with `glassEffectID` when hierarchy changes.
- Only provide fallback materials and visuals when the deployment target is below iOS/macOS 26; skip fallback code entirely on a 26+ floor.

## Quick Snippets
Use these patterns directly and tailor shapes/tints/spacing.

On an iOS/macOS 26+ deployment target, call the API directly with no shim:

```swift
Text("Hello")
    .padding()
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
```

On a deployment target below iOS/macOS 26, gate with `#available` and provide a fallback:

```swift
if #available(iOS 26, macOS 26, *) {
    Text("Hello")
        .padding()
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
} else {
    Text("Hello")
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
}
```

```swift
GlassEffectContainer(spacing: 24) {
    HStack(spacing: 24) {
        Image(systemName: "scribble.variable")
            .frame(width: 72, height: 72)
            .font(.system(size: 32))
            .glassEffect()
        Image(systemName: "eraser.fill")
            .frame(width: 72, height: 72)
            .font(.system(size: 32))
            .glassEffect()
    }
}
```

```swift
Button("Confirm") { }
    .buttonStyle(.glassProminent)
```

## Resources
- Reference guide: `references/liquid-glass.md`
- Prefer Apple docs for up-to-date API details.
