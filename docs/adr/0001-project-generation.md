---
summary: "ADR: use XcodeGen 2.46.0 with xcode16_3; single checked-in Xcode fallback if Mac gate fails."
read_when:
  - "Changing project.yml or tools/projectgen"
  - "Considering Tuist, checked-in pbxproj, or dual generation strategies"
  - "Mac CI fails to generate or build Focus.xcodeproj"
---

# ADR 0001 — Project generation

## Status

Accepted for the foundation PR, conditional on the first macOS CI gate.

## Decision

Use **XcodeGen 2.46.0** pinned at
`8445e778451c7e44237b90281bde622d764b0084` via `tools/projectgen/Package.swift`.
Set `options.projectFormat: xcode16_3`. Do not commit `Focus.xcodeproj`.

## Consequences

- Linux can prove generator syntax and determinism only.
- First Mac CI must generate cleanly, keep the project untracked, build
  `FocusMac` and `FocusIOS`, archive `FocusMac`, and fail on project-format
  upgrade warnings.
- If XcodeGen cannot represent the required Xcode 26 project, replace it once
  with a checked-in native Xcode 26 project and update this ADR. Do not patch
  generated `.pbxproj` files or maintain both strategies.

## Rejected

- Pure SwiftPM packaging for the whole app (cannot model bundles/UI tests).
- Tuist for v1 (heavier; local generate remains macOS-oriented).
- Hand-maintained `.pbxproj` as the default (opaque Linux edits).
