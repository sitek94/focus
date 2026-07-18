---
name: swift-concurrency-expert
description: Swift Concurrency review and remediation for Swift 6.2+. Use when asked to review Swift Concurrency usage, improve concurrency compliance, or fix Swift concurrency compiler errors in a feature or file. Concrete actions include adding Sendable conformance, applying @MainActor annotations, resolving actor isolation warnings, fixing data race diagnostics, and migrating completion handlers to async/await.
---

# Swift Concurrency Expert

## Overview

Review and fix Swift Concurrency issues in Swift 6.2+ codebases by applying actor isolation, Sendable safety, and modern concurrency patterns with minimal behavior changes.

## Workflow

### 1. Triage the issue

- Capture the exact compiler diagnostics and the offending symbol(s).
- Check project concurrency settings: Swift language version (6.2+), strict concurrency level, and whether approachable concurrency (default actor isolation / main-actor-by-default) is enabled.
- Identify the current actor context (`@MainActor`, `actor`, `nonisolated`) and whether a default actor isolation mode is enabled.
- Confirm whether the code is UI-bound or intended to run off the main actor.

### 2. Apply the smallest safe fix

Prefer edits that preserve existing behavior while satisfying data-race safety.

Common fixes:
- **UI-bound types**: annotate the type or relevant members with `@MainActor`.
- **Protocol conformance on main actor types**: make the conformance isolated (e.g., `extension Foo: @MainActor SomeProtocol`).
- **Global/static state**: protect with `@MainActor` or move into an actor.
- **Background work**: move expensive work into a `@concurrent` async function on a `nonisolated` type or use an `actor` to guard mutable state.
- **Sendable errors**: prefer immutable/value types; add `Sendable` conformance only when correct.

### 2b. Reject diagnostic-silencing patterns

These APIs bypass or weaken the compiler's proof of isolation and data-race safety. They are not approved in this project as fixes for diagnostics:
- `@unchecked Sendable`
- `nonisolated(unsafe)`
- `MainActor.assumeIsolated`
- `@preconcurrency`

An existing occurrence does not by itself prove that a race exists, but it must not be preserved merely to silence the compiler. Inspect the surrounding invariants, restructure the isolation or data flow first, and remove the escape rather than relying on an unchecked assertion.

### 2c. Rejected patterns

- **Mutable global singletons**: an unprotected `static let shared` (or a global `var`) holding mutable state is not a fix on its own. Isolate it to an actor or `@MainActor`, or better, remove the singleton and inject the dependency via `init`/environment.
- **`Task.detached` for shared/actor state**: `Task.detached` does not inherit actor or task-local context, introduces an unstructured lifetime and cancellation boundary, and requires `Sendable` captures. A properly awaited call from a detached task into an actor is still serialized by that actor and is not automatically a race. Even so, detached tasks are not the normal fix for stateful or shared work. Prefer structured child tasks (`async let` or task groups), a context-inheriting `Task { }` when bridging synchronous code into the caller's isolation, or a `@concurrent` async function for explicit offloading.

### 3. Verify the fix

- Rebuild and confirm all concurrency diagnostics are resolved with no new warnings introduced.
- Run the test suite to check for regressions — concurrency changes can introduce subtle runtime issues even when the build is clean.
- If the fix surfaces new warnings, treat each one as a fresh triage (return to step 1) and resolve iteratively until the build is clean and tests pass.

### Examples

**UI-bound type — adding `@MainActor`**

```swift
// Before: data-race warning because ViewModel is accessed from the main thread
// but has no actor isolation
@Observable
final class ViewModel {
    var title: String = ""
    func load() { title = "Loaded" }
}

// After: annotate the whole type so all stored state and methods are
// automatically isolated to the main actor
@MainActor
@Observable
final class ViewModel {
    var title: String = ""
    func load() { title = "Loaded" }
}
```

**Protocol conformance isolation**

```swift
// Before: compiler error — SomeProtocol method is nonisolated but the
// conforming type is @MainActor
@MainActor
class Foo: SomeProtocol {
    func protocolMethod() { /* accesses main-actor state */ }
}

// After: scope the conformance to @MainActor so the requirement is
// satisfied inside the correct isolation context
extension Foo: @MainActor SomeProtocol {
    func protocolMethod() { /* safely accesses main-actor state */ }
}
```

**Background work with `@concurrent`**

```swift
// Before: expensive computation blocks the main actor
@MainActor
func processData(_ input: [Int]) -> [Int] {
    input.map { heavyTransform($0) }   // runs on main thread
}

// After: hop off the main actor using @concurrent (Swift 6.2+). The function
// runs on the global concurrent executor; the caller awaits the result and
// stays in its own isolation — no need to reach for Task.detached.
@concurrent
func processData(_ input: [Int]) async -> [Int] {
    input.map { heavyTransform($0) }
}
```

## Reference material

- See `references/swift-6-2-concurrency.md` for Swift 6.2 changes, patterns, and examples.
- See `references/approachable-concurrency.md` when the project is opted into approachable concurrency mode.
- See `references/swiftui-concurrency-tour-wwdc.md` for SwiftUI-specific concurrency guidance.
