---
summary: "ADR: generate Focus.xcodeproj with pinned XcodeGen; single checked-in Xcode fallback if Mac gate fails."
read_when:
  - "Changing project.yml or tools/projectgen"
  - "Considering Tuist, checked-in pbxproj, or dual generation strategies"
  - "Mac CI fails to generate or build Focus.xcodeproj"
---

# ADR 0001 — Project generation

## Status

Accepted, conditional on macOS CI continuing to generate and build cleanly.

## Decision

Generate `Focus.xcodeproj` with XcodeGen. The revision pin lives in
`tools/projectgen/Package.swift` (and the pin constant there). Keep
`options.projectFormat` as set in `project.yml`. Do not commit the generated
project.

## Consequences

- Linux proves generator syntax and determinism only.
- Mac CI must generate cleanly, keep the project untracked, build `FocusMac`
  and `FocusIOS`, archive `FocusMac`, and fail on project-format upgrade
  warnings.
- If XcodeGen cannot represent the required Xcode project, replace it once
  with a checked-in native project and update this ADR. Do not patch generated
  `.pbxproj` files or maintain both strategies.

## Rejected

- Pure SwiftPM packaging for the whole app (cannot model bundles/UI tests).
- Tuist (heavier; local generate remains macOS-oriented).
- Hand-maintained `.pbxproj` as the default (opaque Linux edits).
