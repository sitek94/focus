# Focus foundation blueprint

Status: implemented in PR (branch `cursor/focus-foundation-ea41`); Mac CI and manual Mac acceptance remain gates
Prepared: 2026-07-17
Implementation scope: one foundation PR executing this blueprint.

## 1. Executive recommendation and stack summary

Build Focus as a small Swift 6.3 monorepo: a portable SwiftPM core, XcodeGen-generated Apple app projects, a native SwiftUI macOS menu-bar app with narrow AppKit seams, a compiling iOS shell, and an in-bundle `focus` CLI. Use SQLite directly for a transactional runtime snapshot and minimal outcome log, a hardened per-user Unix-domain socket for CLI control, `SMAppService.mainApp` for launch at login, and Sparkle for direct macOS updates.

The two least reversible choices remain recommendations with explicit escape hatches:

1. **Project generation:** use XcodeGen 2.46.0, do not commit `Focus.xcodeproj`, set `projectFormat: xcode16_3`, and require the first macOS CI run to prove generation, both Apple builds, and a macOS archive under Xcode 26.6. If that bridge fails because XcodeGen cannot represent the required Xcode 26 project, replace it with one checked-in native Xcode 26 project; do not patch generated `.pbxproj` files or maintain both strategies.
2. **CLI ↔ app IPC:** use an app-owned Unix-domain socket with strict path, peer, framing, and timeout rules. If Focus later requires cryptographic proof that the caller is the signed Focus CLI rather than merely the same local user, deliberately migrate to signed XPC instead of extending the socket protocol with ad hoc authentication.

| Surface | Decision |
|---|---|
| Product/repository/CLI | `Focus` / `sitek94/focus` / `focus` |
| Source license | MIT from the first implementation PR |
| Platforms | macOS 26+ and iOS 26+; English first |
| Swift | Swift 6.3.3, Swift 6 language mode, strict concurrency |
| Shared code | Root SwiftPM package: `FocusSession`, `FocusPersistence`, `FocusControl`, executable `focus` |
| Apple projects | XcodeGen 2.46.0; generated root `Focus.xcodeproj` is ignored |
| macOS UI | SwiftUI `MenuBarExtra`, no Dock presence, narrow AppKit window/activation adapters |
| Timer | Fixed 20-minute focus / 10-second warning / 20-second break / 60-second snooze |
| Local storage | System SQLite, no ORM and no event-sourcing framework |
| CLI transport | Per-user Unix-domain socket, versioned length-prefixed JSON |
| Updates | Sparkle 2.9.4, direct Developer ID distribution |
| App security | Unsandboxed v1, Hardened Runtime enabled, no unnecessary privacy permissions |
| CI | Ubuntu 24.04 for portable code; standard arm64 `macos-26` with Xcode 26.6 for Apple code |
| iOS | Minimal shell built and smoke-tested continuously; not released |

Non-goals for this slice are stats, history UI, smart activity detection, app/domain blocking, gamification, telemetry, accounts, backend, CloudKit/iCloud, configurable timing, multiple snooze lengths, focus modes, extensions, helper daemons, Homebrew, and a website.

## 2. Research log

All sources were retrieved on 2026-07-17. Git pins below were independently checked against local clones or remote refs; web citations were re-fetched. Apple-framework behavior was inspected from source/documentation only and was not executed on Linux.

### Reference repositories

| Source | Inspected pin and license | Relevant inspected paths | Use |
|---|---|---|---|
| [CodexBar](https://github.com/steipete/CodexBar/tree/ecadcb1df43b8ca029e75b6311f491c0b15d45e6) | `ecadcb1df43b8ca029e75b6311f491c0b15d45e6`, MIT | `Package.swift`, `Makefile`, `.swiftformat`, `.swiftlint.yml`, `.github/workflows/ci.yml`, `.github/workflows/release-cli.yml`, `Scripts/{docs-list.mjs,lint.sh,test.sh,package_app.sh,sign-and-notarize.sh,release.sh,mac-release}`, `Tests/`, `TestsLinux/`, `Sources/CodexBarCLI/{CLIEntry.swift,CLIPayloads.swift,CLIOutputPreferences.swift}`, `docs/{cli.md,DEVELOPMENT.md,packaging.md,RELEASING.md,sparkle.md}`, `appcast.xml`, `AGENTS.md`, `.agents/skills/`, `WidgetExtension/project.yml`, `WidgetExtension/CodexBarWidgetExtension.xcodeproj/` | Shipping discipline, Linux coverage, docs, CLI output, release checklists; not a literal project template |
| [archive-Justsayit](https://github.com/sitek94/archive-Justsayit/tree/58b6b1a7ef08f46981dbcfeea041d0539a85c134) | `58b6b1a7ef08f46981dbcfeea041d0539a85c134`, MIT | `Docs/Architecture.md`, `Docs/Decisions/001 State Management and Service Architecture.md`, `App/App.swift`, `App/Managers/RecordingManager.swift`, representative `App/Views/`, `App/Services/`, `App/Models/`, `App/Utils/`, `Justsayit.xcodeproj/project.pbxproj`, `Tests/`, `UITests/` | One owner per state domain, thin views, isolated services and actors; reject global layer buckets |
| [swift-ios-skills](https://github.com/dpearson2699/swift-ios-skills/tree/90c9573272531337962fbb3505036d61ed23389a) | `90c9573272531337962fbb3505036d61ed23389a`, [PolyForm Perimeter 1.0.0 in the pinned repository](https://github.com/dpearson2699/swift-ios-skills/blob/90c9573272531337962fbb3505036d61ed23389a/LICENSE) | Complete 86-skill tree, including each `SKILL.md`, `references/`, and eval directory | Learn-only comparison; no copying, close adaptation, or vendoring |
| [Swift-Agent-Skills](https://github.com/twostraws/Swift-Agent-Skills/tree/9a4dd2627436441350ad2067b00a61abbba14ac4) | `9a4dd2627436441350ad2067b00a61abbba14ac4`, MIT | Complete catalog `README.md`, `LICENSE`, linked upstream inventory; the catalog contains no in-tree skills | Discovery only; every selected upstream license was checked separately |
| [SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill/tree/f06d1437a3fbec7df6cdce93f77004e5409b31ee) | `f06d1437a3fbec7df6cdce93f77004e5409b31ee`, [MIT](https://github.com/AvdLee/SwiftUI-Agent-Skill/blob/f06d1437a3fbec7df6cdce93f77004e5409b31ee/LICENSE) | Complete `swiftui-expert-skill/` and references, especially `macos-scenes.md`, `macos-window-styling.md`, `liquid-glass.md`, `localization.md`, `accessibility-patterns.md`, `view-structure.md` | Primary selective SwiftUI skill source, corrected against Apple documentation |
| [Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/tree/0d472de78225d2875283c35eaca1c060c493bdb3) | `0d472de78225d2875283c35eaca1c060c493bdb3`, [MIT](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/0d472de78225d2875283c35eaca1c060c493bdb3/LICENSE) | Complete `swift-concurrency/` and references for actors, `Sendable`, tasks, testing, migration, linting | Primary selective concurrency skill source |
| [Swift-Testing-Agent-Skill](https://github.com/twostraws/Swift-Testing-Agent-Skill/tree/2d6bba14a3c8bf3694f218b92fffe617c41ae43e) | `2d6bba14a3c8bf3694f218b92fffe617c41ae43e`, MIT | `swift-testing-pro/skills/swift-testing-pro/SKILL.md` and its complete `references/` tree | Selective testing skill source |

Two premises in the brief changed upstream:

- CodexBar is not currently “pure SPM with no `.xcodeproj`”: the pinned tree contains an XcodeGen spec and tracked generated project for its widget extension. Its main app is still assembled largely through SwiftPM and scripts.
- `dpearson2699/swift-ios-skills` is not currently unlicensed: the pinned tree has a PolyForm Perimeter license. That license is not the MIT-compatible basis wanted for Focus, so the practical conclusion remains **learn from it, copy nothing**.

### Official and supporting sources

| Topic | Sources |
|---|---|
| Xcode/SDKs | [Xcode 26.6 release](https://developer.apple.com/news/releases/?id=06252026a), [Xcode system requirements](https://developer.apple.com/xcode/system-requirements/), [Xcode 26.6 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_6-release-notes) |
| Swift | [Swift 6.3.3 announcement](https://forums.swift.org/t/announcing-swift-6-3-3/87888), [Swift releases](https://github.com/swiftlang/swift/releases), [Swift install page](https://www.swift.org/install/macos/) |
| Current Apple OS releases | [Apple security releases](https://support.apple.com/en-us/100100), [iOS/iPadOS 26.5 notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26_5-release-notes), [macOS 26.5 notes](https://developer.apple.com/documentation/macos-release-notes/macos-26_5-release-notes) |
| SwiftUI/macOS APIs | [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra), [LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement), [Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/liquid-glass), [LocalizedStringResource](https://developer.apple.com/documentation/foundation/localizedstringresource), [SwiftUI accessibility](https://developer.apple.com/documentation/swiftui/view-accessibility) |
| Login item | [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp), [openSystemSettingsLoginItems](https://developer.apple.com/documentation/servicemanagement/smappservice/opensystemsettingsloginitems%28%29) |
| Displays/windows | [NSScreen](https://developer.apple.com/documentation/appkit/nsscreen), [NSScreen.frame](https://developer.apple.com/documentation/appkit/nsscreen/frame), [NSWindow.CollectionBehavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct) |
| GitHub runners | [`actions/runner-images` pin](https://github.com/actions/runner-images/commit/762deea5bafc5981af76507cbdd88ae20bf191cd), [hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [pinned macOS 26 arm64 manifest](https://raw.githubusercontent.com/actions/runner-images/762deea5bafc5981af76507cbdd88ae20bf191cd/images/macos/macos-26-arm64-Readme.md), [Xcode 26.6 default rollout notice](https://github.com/actions/runner-images/issues/14344) |
| Project generation | [XcodeGen 2.46.0](https://github.com/yonaskolb/XcodeGen/tree/8445e778451c7e44237b90281bde622d764b0084), [Xcode 26 format issue](https://github.com/yonaskolb/XcodeGen/issues/1620), [Tuist 4.202.5](https://github.com/tuist/tuist/tree/cf80c01da0d941ecad9f4847e81ffd1623f06949), [Linux generate gate at a pinned Tuist source revision](https://github.com/tuist/tuist/blob/c23435bd8b45c2c97d3c89c9dece7fba80ab5c09/cli/Sources/TuistGenerateCommand/GenerateCommand.swift) |
| IPC | [POSIX `socket`](https://pubs.opengroup.org/onlinepubs/9699919799/functions/socket.html), [Darwin `getpeereid`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getpeereid.3.html), [NSXPC code-signing requirement](https://developer.apple.com/documentation/foundation/nsxpclistener/setconnectioncodesigningrequirement%28_%3A%29) |
| Sparkle | [Sparkle 2.9.4](https://github.com/sparkle-project/Sparkle/tree/b6496a74a087257ef5e6da1c5b29a447a60f5bd7), [programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/), [publishing](https://sparkle-project.org/documentation/publishing/), [sandboxing](https://sparkle-project.org/documentation/sandboxing/) |
| Product-flow inspiration | [LookAway introduction](https://lookaway.com/docs/introduction/), [setup](https://lookaway.com/docs/setting-up/), [break-flow discussion](https://lookaway.com/blog/2025/04/07/how-i-made-break-reminders-less-annoying/) |

### External-source session bootstrap

At the beginning of every implementation or research session, read this plan, identify all
external repositories needed by that session's checkpoints, and materialize them before
doing dependent work:

1. Clone each required repository under `./tmp/references/` in a unique directory containing
   the source name and pinned SHA, such as
   `tmp/references/avdlee-swiftui-agent-skill-f06d1437a3fb/`.
2. Check out the exact full SHA from this plan in detached state. Verify the canonical remote,
   `HEAD`, clean worktree, license file, and all required nested references/directories;
   recurse submodules only when that source actually uses them.
3. Reuse a clone only when remote, SHA, and clean state all match. Otherwise create a new
   uniquely named clone. Never silently inspect a mutable default branch.
4. Treat clones as read-only research inputs. Subagents must not commit or push from them.
   Copy or materially adapt nothing until the license at that SHA and the required
   notice/header path are verified.
5. Keep a transient `tmp/references/sources.tsv` with URL, SHA, license, and purpose for the
   session. Never stage `tmp/`; use explicit-path `git add` and inspect
   `git diff --cached --name-only` before every commit.

The three skill repositories selected in section 17 are mandatory bootstrap clones before
authoring `.agents/skills/`. Clone CodexBar, Justsayit, XcodeGen, Sparkle, or another pinned
reference whenever the active checkpoint needs source inspection beyond the conclusions
already recorded here. SwiftPM dependency resolution alone is not sufficient when inspecting
source or license terms, but unrelated references need not be cloned.

## 3. Toolchain and platform findings

| Fact as of 2026-07-17 | Finding | Planning consequence |
|---|---|---|
| Latest stable Xcode | Xcode 26.6, build 17F113, released 2026-06-25 | Pin `/Applications/Xcode_26.6.app/Contents/Developer` |
| Xcode-bundled Swift | Swift 6.3.3; Apple’s Xcode page says 6.3 and the Swift 6.3.3 announcement explicitly names Xcode 26.6 | Use Swift 6.3.3 and language mode `.v6` |
| Latest standalone Swift | Best-supported conclusion is 6.3.3 from the Swift announcement and GitHub release; the Swift.org macOS install table still displayed 6.3.2, so the site was internally inconsistent | Pin the project to 6.3.3 and retain this caveat in toolchain docs |
| Current stable OS point releases | iOS/iPadOS 26.5.2 and macOS Tahoe 26.5.2, released 2026-06-29 | Product minimum remains 26.0; point release is not the deployment floor |
| SDKs in Xcode 26.6 | iOS 26.5 and macOS 26.5 SDKs | Build with the latest stable SDK while setting deployment targets to 26.0 |
| Xcode host requirement | Xcode 26.6 requires macOS Tahoe 26.2+ | Developer Macs and self-hosted runners must satisfy it |
| SwiftPM manifest | `// swift-tools-version: 6.3`, `platforms: [.macOS(.v26), .iOS(.v26)]`, `swiftLanguageModes: [.v6]` | Strict concurrency is the baseline, not a later migration |
| Standard Apple runner | `macos-26` is a standard arm64 GitHub-hosted runner available to private repos, billed against private-repo minutes | Use it for all Apple jobs; no Intel lane |
| Xcode on that image | The pinned image defaulted to 26.5 but also installed 26.6; a default switch was announced for 2026-07-21 | Never rely on the default or `macos-latest`; select 26.6 explicitly |

The Linux host has Swift 6.3.3 and can build/test Foundation plus pure SwiftPM targets. It has no Xcode, Apple SDKs, Simulator, signing identity, Keychain-backed Sparkle tooling, AppKit, SwiftUI, UIKit, ServiceManagement runtime, or notarization service. Every claim involving those surfaces is a design/documentation finding until Mac CI or manual Mac acceptance proves it.

## 4. Practice comparison: adopt, adapt, reject

| Source | Adopt | Adapt | Reject |
|---|---|---|---|
| CodexBar | Portable SwiftPM code, Linux tests, pinned CI actions, machine-readable CLI output, release checklists, docs frontmatter and docs-list workflow | Use bundled `swift format` instead of copying its formatter/linter stack; use Xcode archives instead of shell-building the primary app; keep scripts host-neutral | “No Xcode project” as a current description, manual primary-app bundle assembly, owner-specific vault/path assumptions, release helper coupling, stale duplicated config/docs |
| Justsayit | One owner for each state domain, thin SwiftUI views, services behind focused protocols, actor isolation for mutable resources | Keep state owners and adapters inside features rather than global folders | Top-level `Managers`, `Models`, `Views`, `Utils`; services instantiated directly by views |
| Swift skills ecosystem | Selectively adapt the three verified MIT skills listed in section 17 | Rewrite around Focus’s commands, architecture, macOS 26 floor, and stricter unsafe-concurrency policy | Whole collections, duplicate overlapping skills, PolyForm material, and unverified-license copying |
| Apple/Swift guidance | `MenuBarExtra`, `SMAppService.mainApp`, standard controls, String Catalogs/`LocalizedStringResource`, Swift 6 mode | Use AppKit only where SwiftUI does not own per-display windows or activation behavior | Availability shims for older OS versions, private APIs, assumed fullscreen guarantees |
| LookAway public flow | Staged cadence, short warning, humane escape, menu-bar recovery | Use only the workflow shape with Focus’s locked 20m/10s/20s/1m values | Branding, assets, wording, exact visuals, smart pause/detection, scores, rich scheduling |
| Sparkle official guidance | SwiftPM integration, `SPUStandardUpdaterController`, EdDSA, `generate_appcast`, HTTPS feed | Generate the appcast from the final notarized artifact in the release workflow | Old DSA guidance, private keys in source, authenticated private-release URLs in the app |

Reference behavior is evidence, not authority. Official current platform/tool documentation wins when it conflicts with a repository snapshot.

## 5. Repository layout, targets, identities, and project-generation strategy

### Durable layout

```text
/
├── LICENSE
├── THIRD_PARTY_NOTICES.md
├── README.md
├── AGENTS.md
├── CHANGELOG.md
├── Package.swift
├── Package.resolved
├── project.yml
├── Makefile
├── .gitignore
├── .swift-format
├── Config/
│   ├── Identifiers.xcconfig
│   ├── Shared.xcconfig
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   └── ExportOptions.plist
├── tools/projectgen/Package.swift
├── CLI/FocusCLI/
├── Sources/
│   ├── FocusSession/
│   ├── FocusPersistence/
│   └── FocusControl/
├── Tests/
│   ├── FocusSessionTests/
│   ├── FocusPersistenceIntegrationTests/
│   ├── FocusControlTests/
│   ├── FocusCLIIntegrationTests/
│   └── FocusPlatformGatingTests/
├── Apps/Focus/
│   ├── FocusMac/
│   │   ├── App/
│   │   ├── Features/{FocusSession,BreakOverlay,Settings,CLIControl}/
│   │   ├── Platform/
│   │   └── Resources/
│   ├── FocusIOS/
│   │   ├── App/
│   │   ├── Features/FocusSession/
│   │   └── Resources/
│   ├── FocusMacIntegrationTests/
│   ├── FocusMacUITests/
│   └── FocusIOSUITests/
├── Scripts/
├── docs/
├── .agents/skills/
└── .github/workflows/
```

Generated `Focus.xcodeproj`, any generated workspace, `DerivedData`, Xcode user data, and the
entire `/tmp/` research tree are ignored and never committed.

### Target and identifier graph

| Build system | Target/product | Responsibility | Identifier/output |
|---|---|---|---|
| SwiftPM | `FocusSession` | Pure state machine, events, fixed policy, injected time contracts | library |
| SwiftPM | `FocusPersistence` | SQLite runtime/event store and persistence client contracts | library |
| SwiftPM | `FocusControl` | JSON protocol, framing, socket transport, command DTOs | library |
| SwiftPM | `focus` | Portable CLI parsing/rendering plus platform-gated app launch | executable `focus` |
| Xcode | `FocusMac` | macOS menu-bar app | `com.macieksitkowski.focus.macos` |
| Xcode | `FocusIOS` | minimal iOS shell | `com.macieksitkowski.focus.ios` |
| Xcode | `FocusCLI` | same `CLI/FocusCLI` source, embedded and signed with the app | `com.macieksitkowski.focus.cli`, product `focus` |
| Xcode | `FocusMacIntegrationTests` | Apple adapters and real Darwin IPC | `com.macieksitkowski.focus.macos.tests` |
| Xcode | `FocusMacUITests` | minimal launch/menu smoke | `com.macieksitkowski.focus.macos.uitests` |
| Xcode | `FocusIOSUITests` | minimal launch/root-scene smoke | `com.macieksitkowski.focus.ios.uitests` |

`com.macieksitkowski.focus` is the locked namespace, not a concrete app target. Platform suffixes keep provisioning, release, and lifecycle histories independent. No extension exists in v1; when a real extension is approved, derive it as `<owning-app-id>.<role>` rather than reserving speculative IDs now.

### Strategy comparison

| Option | Strength | Cost/risk | Decision |
|---|---|---|---|
| Pure SwiftPM + packaging scripts | Best Linux portability and smallest tool surface | Does not model iOS/macOS app bundles, UI tests, entitlements, schemes, archive/export, or signing as first-class targets | Reject as whole-project strategy; retain SwiftPM for shared code |
| Checked-in native `.xcodeproj` | Exact Xcode 26 fidelity, no generator | Opaque/noisy `.pbxproj` diffs and unsafe structural edits from Linux agents | Fallback only |
| XcodeGen | Reviewable YAML/config, deterministic Linux generation, local-package and Apple-target support, much lighter than Tuist | Generator DSL lock-in; Xcode 26 project-format support lags upstream | Recommend conditionally |
| Tuist 4.202.5 | Rich typed project model and larger-project tooling | Local project generation remains macOS-only; more concepts and dependencies than this solo app needs | Reject for v1 |

Pin XcodeGen 2.46.0 at `8445e778451c7e44237b90281bde622d764b0084` through `tools/projectgen/Package.swift`. `project.yml` must contain:

```yaml
options:
  projectFormat: xcode16_3
```

That is XcodeGen’s highest available format (`objectVersion = 90`). Xcode 26’s native `objectVersion = 100` remains unsupported in this release. The first Mac CI gate must generate from a clean checkout, confirm the project is untracked, build `FocusMac`, build `FocusIOS`, archive `FocusMac`, and fail on project-format upgrade warnings. Successful Linux generation proves only XcodeGen determinism and syntax, not Xcode compatibility.

## 6. Dependency list

| Dependency | Pin/license | Scope | Why it earns its place |
|---|---|---|---|
| XcodeGen | 2.46.0 / `8445e778451c7e44237b90281bde622d764b0084` / MIT | Development only | Deterministic, reviewable Apple project generation from Linux and macOS |
| Sparkle | 2.9.4 / `b6496a74a087257ef5e6da1c5b29a447a60f5bd7` / MIT plus bundled notices | macOS runtime and release tooling | Durable direct-update framework, appcast signing, update UI |
| SQLite | OS/system `libsqlite3`; SQLite is public domain | Shared persistence adapter | Small transactional store without an ORM or third-party wrapper |
| Swift Testing | Bundled with Swift 6.3.3 | Shared tests | Native parameterized deterministic tests |
| XCTest/XCUITest | Bundled with Xcode 26.6 | Apple integration and smoke tests | Required Apple process/UI launch harness |
| SwiftUI, AppKit, Foundation, ServiceManagement | Apple SDK | App | Native platform implementation |
| GitHub Actions | Pin `actions/checkout` v7.0.0 to `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0`; pin `actions/upload-artifact` v7.0.1 to `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` if used | CI | Reproducible workflow dependencies |

Do not initially add Swift Argument Parser, Commander, SwiftLint, a second formatter, an ORM, SwiftNIO, an HTTP server, analytics, visual-regression tooling, a release helper, or build caches. The CLI surface is small enough for a focused parser; add a dependency only after measured complexity justifies it.

## 7. Domain design

`FocusSession` is a deterministic reducer/reconciler over immutable `Sendable` values. It receives `now` and an intent, returns the new state, outcome events, and presentation directives. It never reads global time, starts a real timer, sleeps, touches persistence, or imports Apple UI frameworks.

### Fixed policy and states

| Constant | Value | Configurable |
|---|---:|---|
| focus | 1,200 seconds | no |
| warning | final 10 seconds of focus | no |
| break | 20 seconds | no |
| snooze | 60 seconds from action time | no |

| State | Required data |
|---|---|
| `focus` | `cycleID`, `focusStartedAt`, `warningStartsAt`, `breakDueAt` |
| `warning` | same cycle/deadlines plus `warningStartedAt` |
| `break` | `cycleID`, `breakStartedAt`, `breakEndsAt`, trigger (`scheduled`, `startNow`, `cli`, `catchUp`) |
| `paused` | frozen prior state, `pausedAt`, exact remaining durations |

There is no speculative mode/configuration engine. A first launch with no snapshot starts `focus` at `now`.

### Transitions and edge semantics

- At `focusStartedAt + 19m50s`, `focus → warning`.
- At the break due time, `warning → break`; the break gets a full 20 seconds.
- Warning `Start now` begins a full break immediately.
- Warning `Snooze +1m` sets `breakDueAt = now + 60s`, returns to `focus`, and re-enters warning 10 seconds before the new due time. Repeated snoozes are allowed because no cap was specified; do not invent one.
- Warning `Skip` records the break as skipped and starts a fresh 20-minute focus cycle.
- Break `Skip`, including the emergency overlay action, records the break as skipped and starts a fresh focus cycle.
- Natural break completion records completion and starts a fresh focus cycle at `breakEndsAt`.
- Pause is legal during focus, warning, or break; it hides warning/overlay presentation and freezes exact remaining durations. Paused time never counts.
- Resume rebuilds deadlines from the frozen durations. A paused snapshot remains paused across relaunch.
- The CLI `start` bootstraps a missing runtime and may cold-launch the app. It is a successful no-op when an active runtime already exists and is rejected with “use resume” when the persisted runtime is paused.
- `trigger-break` starts a full break from focus or warning and is a successful no-op if already in break. From a paused state it explicitly abandons the frozen phase, resumes the schedule, and starts an active 20-second break so the overlay appears immediately.
- Reconcile before every wake, restore, and command so stale warning actions cannot mutate a state that has already advanced.

Wall-clock deadlines count elapsed time through screen lock, idle time, sleep, and app downtime; only explicit pause excludes time. If a persisted focus/warning deadline is overdue at restore or wake, start one full catch-up break at the current `now`. Do not fabricate repeated cycles or outcome history for every missed interval. If a persisted break has already ended, record its completion once, derive the next focus, and then apply the same bounded catch-up rule. Store UTC instants; timezone changes do not affect elapsed time. A backward system-clock jump delays a future deadline but never creates reverse transitions.

### Time and persistence seams

- `WallClock.now` is injected.
- `WakeScheduler` schedules the next absolute deadline and is replaceable by a manual scheduler.
- Tests advance a manual clock; no test uses real `Task.sleep`.
- `FocusEventStore.commit(snapshot:events:)` writes the new runtime snapshot and events in one transaction.
- SQLite has only `schema_meta`, one-row `runtime_snapshot`, and append-only `outcome_events`.
- Runtime starts from the snapshot. This is **not** event sourcing; there is no replay engine, analytics query layer, or stats schema.

Minimal outcome events are `sessionStarted`, `breakStarted`, `breakCompleted`, `breakSnoozed`, and `breakSkipped`. Each stores `schemaVersion`, monotonic sequence, event/cycle IDs, UTC timestamp, source (`timer`, `warning`, `cli`, `recovery`), and only event-specific fields such as the 60-second snooze deadline. Pause/resume remain runtime transitions, not required behavioral-outcome events.

## 8. CLI contract and IPC recommendation

### Commands

Human-readable output is the default. `--json` is the only machine contract.

| Command | Auto-launch | Semantics |
|---|---:|---|
| `focus status [--json]` | no | Read current app/runtime state; app absence is exit 3 |
| `focus start [--json]` | yes | Launch the sibling app if needed, bootstrap/ensure the timer, return authoritative state |
| `focus pause [--json]` | no | Pause; already paused is success with `performed: false` |
| `focus resume [--json]` | no | Resume; already active is success with `performed: false` |
| `focus skip [--json]` | no | Skip a warning/break obligation; focus phase rejects with exit 6 |
| `focus trigger-break [--json]` | no | Begin a full break immediately; equivalent to warning UI “Start now” |
| `focus snooze [--json]` | no | Seventh command justified by the already-required “Snooze 1 minute” warning action |

`focus --version` is a flag, not another subcommand.

Representative human output:

```text
$ focus status
Focus is running: focus, 7m 46s until warning.

$ focus start
Focus is active: focus, 19m 50s until warning.

$ focus pause
Paused during focus. 12m 30s until warning is frozen.

$ focus resume
Focus resumed: focus, 12m 30s until warning.

$ focus resume
Focus is already active: focus, 12m 29s until warning.

$ focus snooze
Break snoozed for 1m. Next warning in 50s.

$ focus trigger-break
Break started. 20s remaining.

$ focus skip
Break skipped. New focus cycle started.
```

### Stable JSON protocol

Request envelope:

```json
{
  "protocol": {"name": "focus-control", "major": 1, "minor": 0},
  "requestId": "0F72A9A5-9625-44E0-9C5F-AB9346D12D2F",
  "command": "snooze",
  "arguments": {},
  "client": {"version": "0.1.0", "build": "1"}
}
```

Successful response after snoozing at `2026-07-17T10:19:54Z`:

```json
{
  "protocol": {"name": "focus-control", "major": 1, "minor": 0},
  "requestId": "0F72A9A5-9625-44E0-9C5F-AB9346D12D2F",
  "ok": true,
  "result": {"command": "snooze", "performed": true},
  "app": {"running": true, "version": "0.1.0", "build": "1", "pid": 12345},
  "state": {
    "phase": "focus",
    "cycleId": "783FC3BB-BF5A-48F5-9E29-BE2A3C8510A1",
    "focusStartedAt": "2026-07-17T10:00:00Z",
    "warningStartsAt": "2026-07-17T10:20:44Z",
    "breakDueAt": "2026-07-17T10:20:54Z",
    "breakEndsAt": null,
    "secondsUntilNextTransition": 50,
    "canPause": true,
    "canResume": false,
    "canSkip": false,
    "canTriggerBreak": true,
    "canSnooze": false
  },
  "error": null
}
```

Error response:

```json
{
  "protocol": {"name": "focus-control", "major": 1, "minor": 0},
  "requestId": "D61C8C39-D39A-4C7E-A6B5-CC0518B181D0",
  "ok": false,
  "result": null,
  "app": {"running": false, "version": null, "build": null, "pid": null},
  "state": null,
  "error": {
    "code": "app_not_running",
    "message": "Focus is not running.",
    "retryable": true
  }
}
```

Every successful mutation includes the authoritative post-commit state in the same response. Major protocol changes are breaking; minor changes may add fields. Both sides ignore unknown additive fields. JSON goes to stdout and contains no incidental logs; human errors go to stderr.

| Exit | Meaning |
|---:|---|
| 0 | success, including documented idempotent no-op |
| 1 | unexpected internal/transport failure |
| 2 | usage/argument error |
| 3 | app/endpoint not running |
| 4 | launch/connect/reply timeout |
| 5 | protocol major-version mismatch |
| 6 | command rejected by current state |
| 7 | endpoint/peer permission failure |

### IPC options and pick

| Option | Assessment |
|---|---|
| Unix-domain socket | Pick: local, request/reply, no daemon, portable protocol/integration testing |
| XPC/Mach service | Strongest signed-client identity but adds an Apple-only service/lifecycle target; reserve for a future provenance requirement |
| Loopback HTTP/Network.framework | Adds port discovery and lacks per-user identity; wrong abstraction for one local CLI |
| `CFMessagePort` / distributed notifications | Run-loop/broadcast semantics and weak reliability/security for authoritative commands |
| Defaults/file polling | Race-prone, stale, and lacks atomic command/reply |

The app owns one per-user `SOCK_STREAM` endpoint and serializes mutations through its runtime owner:

- Shared app/CLI resolver uses `_CS_DARWIN_USER_TEMP_DIR`; use `NSTemporaryDirectory()` only when it resolves to a private non-`/tmp` directory.
- Use the flat filename `com.macieksitkowski.focus.macos.control.sock`.
- A debug/test-only injected path supports Linux integration tests; release builds do not honor arbitrary environment path overrides.
- Enforce the Darwin UTF-8 socket-path byte limit before binding.
- Verify parent owner/mode/type with `lstat`; require a private current-UID directory.
- Only the server may unlink a stale same-owner socket after verifying its type. The client never unlinks.
- On Darwin, verify each accepted peer with `getpeereid` and require the current UID; the client verifies server UID where available.
- Trust boundary is the logged-in user, not a particular signed process.
- Use one request per connection, a four-byte big-endian size prefix, UTF-8 JSON, and 64 KiB request/response caps.
- Use a 250 ms connection attempt, 1.5 s normal command deadline, and 8 s cold-start deadline.
- Reject malformed/oversized frames before decoding and serialize simultaneous commands.
- Re-establish the endpoint after app restart/wake; in-flight restart/sleep requests fail with stable errors rather than hang.

### Install story

Xcode builds and signs `focus` into `Focus.app/Contents/MacOS/focus`. “Install Command Line Tool…” creates a user-owned symlink, preferring `~/.local/bin/focus`; it never copies a second independently versioned binary and never writes `/usr/local/bin` or asks for root. If that directory is not on `PATH`, show an exact shell instruction. Disable installation from an App Translocation/DMG path and ask the user to move Focus to `/Applications` first. A stable symlink into `/Applications/Focus.app` survives Sparkle’s in-place replacement; “Repair Command Line Tool…” fixes a moved app.

## 9. Preferences persistence and launch at login

Preferences stay narrow and are owned by the feature that persists them:

- `LaunchAtLoginClient` is an injected seam; `SMAppService.mainApp.status` is its persisted source of truth.
- `UpdatePreferencesClient` wraps Sparkle’s own automatic-check preference and updater UI.
- `CLIInstaller` remembers only installation diagnostics needed to show Install versus Repair; it is not a product preference domain.
- Timing constants never enter a preference type, plist, defaults key, CLI option, or settings control.

Use `SMAppService.mainApp.register()` / `unregister()`. Do not create a login helper, `SMAppService.loginItem(identifier:)`, `Contents/Library/LoginItems`, launch agent, daemon, or app group. Settings must represent `.notRegistered`, `.enabled`, `.requiresApproval`, and `.notFound`, and offer `openSystemSettingsLoginItems()` when user action is required. Do not silently fight a revocation in System Settings.

Mac acceptance uses a clean user or VM: enable, handle approval, log out/in and verify the menu-bar app relaunches; disable and verify the next login does not relaunch; revoke externally and verify Focus reflects the authoritative state. None of this is validated on Linux.

## 10. Warning and multi-display break-overlay design

The 10-second warning is one compact, non-hostile SwiftUI-hosted panel on the current/main display. It contains standard buttons for **Start now**, **Snooze 1 minute**, and **Skip**, exposes useful accessibility labels/help, and supports Tab/Shift-Tab plus explicit keyboard equivalents. It does not cover every display or block other work.

The break uses one `@MainActor` `OverlaySessionCoordinator` and one borderless `NSWindow` per current `CGDirectDisplayID`, each hosting the same SwiftUI overlay content:

- Enumerate `NSScreen.screens`; derive session-local display identity from `NSScreenNumber`/`CGDirectDisplayID`, not localized names.
- Size each window to `NSScreen.frame`.
- Start with `.screenSaver` level and `[.canJoinAllSpaces, .fullScreenAuxiliary]`; this is a Mac-test-required candidate, not a documented guarantee over every third-party fullscreen app.
- Listen for `NSApplication.didChangeScreenParametersNotification`; diff displays and create/close windows without duplicates.
- Keep exactly one primary key window for keyboard handling; every window still has a large pointer-accessible Skip button.
- Escape skips from the primary overlay; the menu-bar Skip and normal Quit path remain available.
- Do not intercept system shortcuts, disable force quit, require Accessibility permission, or create a kiosk.
- Natural completion, Skip, display failure, and teardown all pass through one idempotent end-session path that closes every window.
- If any topology/window error could leave a user trapped or only partly covered, fail open and end the overlay session.

The UI uses standard macOS 26 controls/materials so native Liquid Glass behavior comes from the platform. Add custom `glassEffect` only if a concrete interaction needs it and Mac visual/accessibility testing approves it. Do not reproduce LookAway wording, branding, assets, screenshots, or exact visual design.

## 11. Concurrency isolation map

| Owner/value | Isolation | Notes |
|---|---|---|
| `FocusSession` reducer/state/events | immutable `Sendable` values and pure functions | No hidden mutable owner |
| App runtime store | `@MainActor` | Sole authority for current session and presentation directives |
| SwiftUI views/menu commands | `@MainActor` | Render state and send intents only |
| Warning/overlay coordinators | `@MainActor` | AppKit/SwiftUI window state |
| SQLite connection/store | actor | One mutable database handle and transaction boundary |
| Wake scheduler | actor | Owns and cancels the one next-deadline task |
| IPC listener | actor | Owns socket accept/read/write; invokes app mutations on `@MainActor` |
| CLI client | immutable value plus async operations | No process-global mutable state |
| ServiceManagement/Sparkle adapters | `@MainActor` unless the API proves otherwise | Keep Apple UI/status interactions serialized |

Compile SwiftPM and Xcode targets in Swift 6 mode. Do not add `@unchecked Sendable`, `nonisolated(unsafe)`, `MainActor.assumeIsolated`, `@preconcurrency`, detached state mutation, or mutable global singletons. A genuine framework-bound exception requires a local written invariant, owner, tracking issue, and deletion condition; it must not be used merely to silence the compiler.

## 12. Testing strategy

### Linux-runnable, authoritative subset

| Suite | Representative cases |
|---|---|
| `FocusSessionTests` (Swift Testing) | first boot; 19m50s warning; due break; 20s completion; repeated cycles; start-now; exact 60s snooze/re-warning; warning/break skip; pause/resume in every phase; long pause; bounded catch-up after sleep/relaunch; backward-clock behavior; reconcile idempotence; fixed constants |
| `FocusPersistenceIntegrationTests` | fresh schema; migration; snapshot/event atomic commit and rollback; paused restore; required started/completed/snoozed/skipped records; sequence ordering; corrupt snapshot failure; no timing preference fields |
| `FocusControlTests` | request/response Codable round trips; unknown additive fields; major mismatch; partial frame reads/writes; malformed/oversized frame rejection; timeout/cancellation; path-length/type/owner helpers |
| `FocusCLIIntegrationTests` | real Linux Unix socket fixture plus CLI subprocess; all seven commands; human stdout/stderr; stable JSON snapshots; exit codes; post-command read-back; concurrent commands. An injected `AppLauncherClient` lets Linux record a cold-launch request and start the fixture listener; the real Launch Services path runs only in `FocusMacIntegrationTests`. |
| `FocusPlatformGatingTests` | Apple-only launch/peer APIs are cleanly injected or conditionally excluded; no Apple framework import leaks into portable targets |

This adapts CodexBar’s `TestsLinux` idea without creating a parallel duplicate source tree: portable tests live with their owning SwiftPM feature, and the platform-gating suite makes the Linux boundary explicit.

### Mac CI

- Generate the project and build both app targets with Xcode 26.6.
- Run `FocusMacIntegrationTests` against the real Darwin socket transport, `getpeereid`, path race/type checks, app command handler, simultaneous clients, restart, and timeout behavior without GUI automation.
- Run one minimal `FocusMacUITests` launch/menu smoke.
- Select an available iOS 26 simulator dynamically and run one `FocusIOSUITests` launch/root-scene smoke; do not assume a static arm64 runner UDID.
- Archive an unsigned structural macOS build on PR CI; release signing is separate.

### Manual credentialed Mac acceptance

- Warning keyboard and VoiceOver/Accessibility Inspector pass.
- Single-display and real multi-display overlay matrix, including hot-plug, Spaces, Stage Manager, and representative fullscreen apps.
- Pointer, Escape, menu-bar, Quit, and failure-path recovery.
- Dockless behavior without launch/Dock flashes.
- Launch-at-login logout/login and revocation.
- Signed/notarized DMG install and Sparkle update from the previous version.

Do not add screenshot-golden or broad UI suites. A successful compile or launch alone is not evidence for overlay, accessibility, login-item, IPC-security, or update behavior.

## 13. Canonical developer commands

`Makefile` is the discoverable entry point; repo-relative scripts contain the logic and fail clearly when a command requires macOS.

| Command | Meaning/environment |
|---|---|
| `make docs-list` | Validate and list docs frontmatter on Linux/macOS |
| `make format` | `swift format --in-place --recursive Sources Tests CLI Apps` |
| `make lint` | `swift format lint --recursive Sources Tests CLI Apps` plus `Scripts/check-concurrency-safety.swift`, which rejects `@unchecked Sendable`, `nonisolated(unsafe)`, `MainActor.assumeIsolated`, and `@preconcurrency` in shipped/test Swift |
| `make generate-project` | Run pinned XcodeGen at repo root |
| `make test-linux` | `swift test` including portable SQLite/CLI integration |
| `make test-session` / `test-persistence` / `test-control` / `test-cli` / `test-platform-gating` | Focused SwiftPM filters |
| `make build-macos` | Generate, then generic macOS build with Xcode 26.6 |
| `make build-ios` | Generate, then generic iOS build with signing disabled |
| `make test-macos-integration` | Real Darwin IPC/Apple adapter integration |
| `make smoke-macos` / `make smoke-ios` | Minimal XCUITest smoke targets |
| `make archive-macos` | Structural unsigned archive in CI; signed archive in release mode |
| `make verify-linux` | toolchain pin, docs, formatting, package build, all portable tests |
| `make verify-apple` | selected Xcode, generation, both builds, integration, both smokes, archive |
| `make release-check VERSION=0.1.0` | Validate tag, changelog, versions, keys’ presence, and public feed configuration without publishing |

Canonical underlying commands include:

```sh
swift run --package-path tools/projectgen xcodegen generate --spec project.yml --project .
swift build
swift test
sudo xcode-select -s /Applications/Xcode_26.6.app/Contents/Developer
xcodebuild -project Focus.xcodeproj -scheme FocusMac -destination "generic/platform=macOS" build
xcodebuild -project Focus.xcodeproj -scheme FocusIOS -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Focus.xcodeproj -scheme FocusMac -archivePath build/Focus.xcarchive archive
```

Apple jobs always log `xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, and the runner image version before work begins.

## 14. CI workflow design

`.github/workflows/ci.yml` runs on pull requests and pushes to `main`:

| Job | Runner | Required work |
|---|---|---|
| `linux-shared` | `ubuntu-24.04` | toolchain assertion, `make verify-linux`, Linux CLI/socket integration |
| `apple-build` | `macos-26` arm64 | select Xcode 26.6, generate, assert `objectVersion = 90`, prove project untracked, build macOS and iOS |
| `macos-integration` | `macos-26` arm64 | real IPC/adapter integration and minimal macOS smoke |
| `ios-smoke` | `macos-26` arm64 | dynamically select iOS 26 simulator and run one launch smoke |
| `macos-archive-gate` | `macos-26` arm64 | structural archive and project-format warning check |

Policies:

- Pin every action by full commit SHA; annotate the human-readable release tag in comments.
- Use `contents: read` in PR CI and expose no release secrets.
- Do not use `macos-latest`, Intel runners, or larger runners.
- Start without caches. Add OS/architecture/Xcode-partitioned caches only after measured CI cost justifies them; never share compiled caches across Linux and macOS.
- The private repository consumes macOS Actions minutes; keep jobs focused and cancel superseded branch runs.
- Main remains unprotected as specified, but the social/PR rule is still: one short-lived implementation branch, one implementation PR, explicit review, all required jobs green before merge.
- CI never signs, notarizes, creates tags, publishes releases, or modifies the appcast on merge.

## 15. Signing, notarization, packaging, Sparkle, and release flow

Versioning starts at `0.1.0`. `CHANGELOG.md` uses explicit version sections. Git tags are `vX.Y.Z`, signed locally by Maciek with a documented SSH or GPG key, pushed before release, and verified by the workflow. No tag-signing private key belongs in repository secrets.

`.github/workflows/release.yml` has only `workflow_dispatch` with a required tag input:

1. Check out the exact tag with full history.
2. Verify the signed tag against the checked-in allowed signer/public key policy.
3. Verify tag, `MARKETING_VERSION`, monotonically increasing build number, and changelog agree.
4. Select Xcode 26.6 and regenerate the project.
5. Import the Developer ID Application identity into a temporary keychain.
6. Archive/export arm64 `Focus.app`, including the signed nested `focus` CLI and Sparkle components, with Hardened Runtime.
7. Verify nested and outer signatures; create and sign `Focus-<version>-macos-arm64.dmg`.
8. Submit the DMG with `notarytool`, wait, staple, and validate with `stapler`, `spctl`, and `codesign`.
9. Use Sparkle 2.9.4 `generate_appcast` and the Ed25519 private key on the final notarized artifact. Set minimum system `26.0` and hardware requirement `arm64`.
10. Create a draft GitHub Release, upload the DMG first, then `appcast.xml`, verify enclosure/feed URLs, and publish only after all checks pass.
11. Run a clean-Mac install/update smoke. Never upload or release the iOS shell.

The generated `appcast.xml` is a release artifact, not a hand-edited source file. The proposed stable feed is `https://github.com/sitek94/focus/releases/latest/download/appcast.xml`, but it works for clients only when the release assets are publicly readable. A private GitHub repository cannot serve unauthenticated Sparkle clients. Default resolution: make this MIT repository public before `0.1.0`; otherwise Maciek must provide a separate public artifact/feed host. Never put a GitHub token in the app. Homebrew waits until this pipeline is proven; a website remains entirely deferred.

### Prerequisite classification

`✓` means the prerequisite requires that class; one row may require several.

| Prerequisite | Ordinary CI-validatable | macOS runner | Repo secret | Paid Apple account | Unverifiable on Linux | Owner |
|---|:---:|:---:|:---:|:---:|:---:|---|
| Swift/XcodeGen pins, docs, changelog, SemVer consistency | ✓ |  |  |  |  | agent |
| Xcode 26.6 generation/build/archive | ✓ | ✓ |  |  | ✓ | agent via CI |
| `macos-26` availability/minutes and workflow permissions |  | ✓ |  |  | ✓ | Maciek repo settings |
| Signed Git tag and checked-in verification policy | ✓ |  |  |  |  | Maciek signs; agent verifies |
| Public GitHub repo or other public Sparkle host | ✓ after configured |  |  |  |  | Maciek |
| Apple Developer Program membership/team ID |  |  |  | ✓ | ✓ | Maciek |
| Registered macOS/iOS identifiers where Apple services require them |  | ✓ |  | ✓ | ✓ | Maciek |
| Developer ID Application certificate/private key |  | ✓ | ✓ | ✓ | ✓ | Maciek |
| Certificate export password |  | ✓ | ✓ | ✓ | ✓ | Maciek |
| App Store Connect/notary API key, key ID, issuer ID |  | ✓ | ✓ | ✓ | ✓ | Maciek |
| Hardened Runtime and nested-code signing order | ✓ structurally | ✓ | ✓ for release | ✓ | ✓ | agent + Maciek credentials |
| Sparkle Ed25519 keypair | public key config only | ✓ to generate with official tools | private key |  | ✓ | Maciek generates/stores |
| `SUPublicEDKey`, feed URL, minimum OS/hardware requirements | ✓ | ✓ runtime check |  |  | ✓ runtime | agent |
| Notarization, stapling, Gatekeeper acceptance |  | ✓ | ✓ | ✓ | ✓ | release workflow + Maciek |
| End-to-end Sparkle update from an older signed build |  | ✓ | release secrets | ✓ for signed artifacts | ✓ | Maciek credentialed Mac |
| iOS TestFlight credentials/profiles | deferred | deferred | deferred | deferred | deferred | out of v1 |

Planned CI configuration names, never values:

- Repository secrets:
  - `APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64`
  - `APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD`
  - `APPLE_NOTARY_API_PRIVATE_KEY`
  - `SPARKLE_ED25519_PRIVATE_KEY`
- Repository variables (non-sensitive identifiers):
  - `APPLE_TEAM_ID`
  - `APPLE_NOTARY_API_KEY_ID`
  - `APPLE_NOTARY_API_ISSUER_ID`

The workflow uses its scoped built-in `GITHUB_TOKEN`; no personal access token is an app or release prerequisite.

Do not create both a secret and a variable for the same identifier.

## 16. Documentation map

| Path | Single source of truth |
|---|---|
| `README.md` | Short product/status/quick-command index |
| `AGENTS.md` | Canonical commands, required docs-list step, Linux/Mac proof boundary, feature-first and generated-project rules |
| `docs/architecture/overview.md` | Target graph, identifiers, ownership, dependency direction |
| `docs/architecture/session.md` | Fixed state machine, injected time, persistence and event semantics |
| `docs/architecture/cli.md` | CLI commands, JSON/exit contract, IPC security and install story |
| `docs/testing.md` | Test lanes, named acceptance cases, simulator/manual limits |
| `docs/release-macos.md` | Version/tag/archive/sign/notarize/release checklist and prerequisites |
| `docs/release-ios.md` | Planned iOS release path (Xcode Cloud, TestFlight internal) — TODO |
| `docs/sparkle.md` | Key handling, appcast generation, feed hosting, update smoke |
| `docs/adr/0001-project-generation.md` | XcodeGen trade-off, mandatory gate, single fallback |
| `docs/adr/0002-cli-ipc.md` | Socket threat model, rejected options, XPC pivot condition |

Every `docs/` page starts with `summary` and non-empty `read_when` frontmatter. `make docs-list` validates and prints that index; `AGENTS.md` tells agents to run it before architecture, testing, or release work. Keep commands in `Makefile`/`AGENTS.md`, detailed rationale in the owner page, and links elsewhere. Do not create ADRs for reversible implementation details.

## 17. Agent skills

Skills hold reusable, approved engineering patterns; `docs/` owns Focus’s current
architecture and product decisions. The current skill baseline is:

- verbatim MIT copies of `swiftui-ui-patterns`, `swiftui-view-refactor`,
  `swiftui-performance-audit`, `swift-concurrency-expert`, and
  `swiftui-liquid-glass` from Dimillian/Skills at
  `05ba982bfeb0d77d3c97d4542b0ee15034d05f84`;
- the adapted `focus-testing` router; and
- the Focus-authored `release-focus` router.

Review copied skills visibly in follow-up commits: keep broadly useful modern
patterns, remove rejected or stale guidance, and adapt only where Focus has an
explicit rule. License notices remain in `THIRD_PARTY_NOTICES.md`; there is no
automated skill-provenance gate while the repository is private.

## 18. Licensing and attribution plan

The first implementation PR adds the standard MIT `LICENSE` with `Copyright (c) 2026 Maciek Sitkowski`, even while the repository remains private. This makes the intended eventual public release unambiguous.

`THIRD_PARTY_NOTICES.md` records:

- Sparkle’s MIT notice and bundled-component notices because Sparkle ships in the app;
- full MIT notices and pinned source paths/commits for materially adapted skills;
- any future source whose text or code is actually included.

Use these labels consistently:

| Classification | Meaning | Obligation |
|---|---|---|
| copied | Verbatim code/text | Preserve required headers and license notice; record exact path and SHA |
| adapted | Substantial source-derived rewrite | Add `Adapted from <URL>@<SHA>` header and upstream MIT notice |
| pattern/inspiration | Independently written implementation of a general idea/workflow | Cite in design/research docs when useful; do not imply copied authorship |

CodexBar and Justsayit remain MIT pattern references unless implementation later copies material. LookAway contributes only a public workflow shape; never copy its words, branding, assets, screenshots, or visual design. XcodeGen is a development tool and Sparkle is a distributed dependency; distinguish those notice categories. Never copy material without a verified compatible license.

## 19. One-PR implementation order

Use one short-lived branch and one PR, with small reviewable commits/checkpoints. Keep CI active from the first target graph.

| Checkpoint | Expected paths/responsibility | Exit proof |
|---|---|---|
| 0. Session bootstrap | transient `tmp/references/` clones for every external source needed by the active checkpoints | exact remote/SHA/license checks; `tmp/` ignored and absent from the staged diff |
| 1. Contracts and licensing | `LICENSE`, `THIRD_PARTY_NOTICES.md`, `README.md`, `AGENTS.md`, `CHANGELOG.md`, `Makefile`, `.swift-format`, docs frontmatter tooling | `make docs-list`, license/provenance checks |
| 2. Project graph and empty shells | `Package.swift`, `tools/projectgen/Package.swift`, `project.yml`, `Config/`, minimal `Apps/Focus/*`, `CLI/FocusCLI` | Linux generation; first Mac generate/build-both/archive gate |
| 3. Deterministic session | `Sources/FocusSession`, `Tests/FocusSessionTests` | Full fixed-timing/state/reconciliation suite |
| 4. Local persistence | `Sources/FocusPersistence`, integration tests, migration fixtures | Atomic snapshot/event rollback and restore |
| 5. Control protocol and CLI | `Sources/FocusControl`, `CLI/FocusCLI`, control/CLI tests | Real Linux socket fixture, all commands/JSON/exits/read-back |
| 6. macOS vertical slice | menu bar, runtime owner, warning panel, settings, launch-at-login adapter | Mac build plus focused adapter tests |
| 7. Break overlay | `Features/BreakOverlay`, narrow AppKit platform files | Mac manual fail-open/multi-display acceptance |
| 8. iOS shell and UI smokes | `FocusIOS`, both UI smoke targets | iOS build/smoke and macOS launch smoke |
| 9. Updates and release | Sparkle wiring, `ci.yml`, `release.yml`, release docs/scripts | release-check and unsigned archive; secrets remain optional until actual release |
| 10. Agent workflow and final audit | `.agents/skills`, source index, all docs/notices | full CI green; requirement matrix reviewed; no generated project committed |

If the XcodeGen Mac gate fails, resolve it inside this PR by switching once to the checked-in native Xcode 26 fallback and updating ADR 0001. Do not proceed with unverified generator assumptions.

## 20. Acceptance criteria and verification matrix

| ID | Requirement | Verification/evidence | Environment |
|---|---|---|---|
| A01 | Names are `Focus`, `sitek94/focus`, and CLI `focus`; IDs match section 5 | Manifest/project-setting assertions and `focus --version` | Linux + Mac CI |
| A02 | macOS/iOS minimums are 26.0; no compatibility branches | Inspect generated build settings; static search for app-source availability guards | Linux + Mac CI |
| A03 | macOS app is native SwiftUI and menu-bar-only | `make build-macos`; launch smoke finds menu item and no default window | Mac CI |
| A04 | No Dock presence, including settings/overlay paths | `LSUIElement` plist assertion plus launch/settings/break manual check for Dock icon/flash | Mac CI + manual Mac |
| A05 | Release binary is arm64 only | `lipo -info`/`file` on exported app and DMG naming assertion | release Mac |
| A06 | English first and localization-ready | String Catalog extraction; static check for user-facing string APIs; English UI review | Mac CI + manual Mac |
| A07 | Basic accessibility and keyboard navigation | Accessibility Inspector/VoiceOver plus Tab, Shift-Tab, Return, Escape checks on menu, warning, overlay, settings | manual Mac |
| A08 | Native macOS 26 styling without copied visuals | Standard-control review; custom glass search and focused visual/accessibility approval if present | manual Mac |
| A09 | Focus/warning/break/snooze values are exactly 20m/10s/20s/1m and not configurable | Named `FocusSessionTests`; static search of settings/defaults/CLI options | Linux |
| A10 | Timer counts wall-clock elapsed time except explicit pause | Sleep/relaunch/manual-clock reconciliation tests | Linux |
| A11 | Warning offers exactly Start now, Snooze 1 minute, Skip | Reducer tests plus warning-panel UI/accessibility check | Linux + manual Mac |
| A12 | Snooze re-warns at 50 seconds and supports repeated use | Manual-clock parameterized tests | Linux |
| A13 | Break covers every currently connected display | One logged/window-inspected overlay per `CGDirectDisplayID`; hot-plug matrix | manual multi-display Mac |
| A14 | Emergency recovery is obvious and non-hostile | Pointer Skip on every display, Escape, menu Skip, Quit, forced overlay-construction failure; all close | manual Mac |
| A15 | Pause/resume works in all phases and persists | State tests and SQLite paused-snapshot restore | Linux |
| A16 | Preferences persist without timing knobs | Injected ServiceManagement/Sparkle client tests; relaunch checks; schema/static search | Linux + manual Mac |
| A17 | Launch at login uses main app, not helper | Static search/project target assertion; clean-user enable/relogin/disable/revoke matrix | Linux + manual Mac |
| A18 | Minimal local log records started/completed/snoozed/skipped outcomes | SQLite integration tests query required event kinds and transaction rollback | Linux |
| A19 | No stats UI sits on the event log | Static app/menu/settings search and manual UI inventory | Linux + manual Mac |
| A20 | No smart detection, blocking, gamification, telemetry, account, backend, or iCloud code | Dependency/entitlement/import/static search and UI inventory | Linux |
| A21 | iOS 26 shell imports shared core, compiles, and launches; it is not released | `make build-ios`, `make smoke-ios`, release-workflow assertion of no iOS upload | Mac CI |
| A22 | Shared core is pure Swift/Foundation and deterministic | `swift build`, `swift test`, forbidden-import/sleep scan | Linux |
| A23 | Views are thin and each state domain has one owner | Architecture dependency test/search plus reviewer checklist | Linux review |
| A24 | Swift 6 strict concurrency has no unsafe escape | Swift 6 builds and `make lint` running `Scripts/check-concurrency-safety.swift` | Linux + Mac CI |
| A25 | CLI has required six commands plus justified `snooze` | `swift run focus --help` golden test | Linux |
| A26 | Human output, JSON schema, exits, and read-back match section 8 | CLI subprocess integration tests, JSON golden/semantic decoding, exit assertions | Linux |
| A27 | `status` does not launch; only `start` may cold-launch | fake launcher tests and real Mac integration | Linux + Mac CI |
| A28 | CLI controls running app without GUI automation | Real socket fixture on Linux; app-handler/Darwin transport integration on Mac | Linux + Mac CI |
| A29 | IPC path/peer/framing security invariants hold | Adversarial path type/owner/length tests, `getpeereid`, oversized/partial frames, concurrent clients | Linux + Mac CI |
| A30 | CLI install is no-root, symlinked, version-locked, and repairable | DMG/App Translocation guard and move/update/repair manual matrix | manual Mac |
| A31 | Overlay/window/AppKit code stays in narrow feature/platform paths | Import/path static check and review | Linux review |
| A32 | XcodeGen source of truth is deterministic and generated project untracked | Generate twice/hash; `git ls-files Focus.xcodeproj` empty; ignore check | Linux |
| A33 | XcodeGen output works with Xcode 26.6 or fallback is taken | Generate, build both apps, archive macOS, no format warnings | Mac CI |
| A34 | Only approved dependencies exist | Resolved-package/license allow-list | Linux |
| A35 | Portable tests, persistence integration, and CLI integration all pass | `make verify-linux` | Linux CI |
| A36 | One minimal launch/UI smoke exists per platform, no screenshot suite | `make smoke-macos`, `make smoke-ios`, test-tree assertion | Mac CI |
| A37 | Agent docs are concise, indexed, and canonical | `make docs-list`; duplicate-command/link review | Linux |
| A38 | Skills are reusable, explicit, and MIT-compatible | Manual skill and notice review; no PolyForm content | review |
| A39 | Main is unprotected but implementation merges only through one green PR | Repo-setting/manual confirmation and CI status | GitHub + Maciek |
| A40 | Release begins at 0.1.0 with changelog and signed tag | `make release-check VERSION=0.1.0`, tag verification | ordinary CI |
| A41 | Release is explicit, macOS-only, signed/notarized/stapled, with valid appcast | `workflow_dispatch` inspection plus successful release logs/artifact checks | release Mac |
| A42 | Private assets are never used as authenticated in-app feed | Public unauthenticated HTTP check of feed and enclosure; no token/static credential scan | ordinary CI |
| A43 | Homebrew and website are absent/deferred | Workflow/repository static search | Linux |
| A44 | Focus license/notices satisfy copied/adapted/pattern policy | `LICENSE`, notice, and source review | Linux |
| A45 | Every needed external source was inspected from a pinned transient clone and no research clone is committed | Verify `tmp/references/sources.tsv`, each clone remote/HEAD/license, `.gitignore`, staged paths, and base-to-head diff | Linux |

“Build passes,” “app launches,” and “a screenshot looks right” are insufficient evidence for the requirements that name stronger checks.

## 21. Risks, environment limits, and unresolved prerequisites

### Remote execution and Mac handoff

A future Cursor Cloud agent in an environment like this one can begin the implementation
without any prior setup on Maciek's Mac. It can author every tracked file and fully verify
the portable SwiftPM domain, SQLite persistence, CLI/control protocol, Linux socket
integration, XcodeGen determinism, docs, skills, licenses, and CI/release definitions.

The same implementation PR needs working GitHub-hosted `macos-26` Actions before its Apple
work can be accepted: Xcode 26.6 must generate, build both apps, run Darwin integration and
minimal UI smokes, and archive macOS. An interactive physical or remote Mac is still required
for accessibility, real display/fullscreen behavior, Dockless behavior, login-item
logout/login and revocation, App Translocation/CLI install, and signed Sparkle install/update
acceptance.

Local Mac initialization can therefore wait until the first interactive acceptance
checkpoint. At that point install the plan-pinned stable Xcode on a compatible macOS, clone
the repository, and run `make verify-apple`; no paid Apple account is needed for ordinary
unsigned debug builds and simulator tests. Apple Developer membership, Developer ID/notary
credentials, Sparkle private keys, a public feed, and TestFlight setup can wait until
release-focused work.

No product decision requires a question before implementation. The following gates remain explicit:

| Risk/prerequisite | Status and mitigation | Resolution owner |
|---|---|---|
| Linux cannot execute Apple SDK/runtime work | Portable proof only; use Mac CI/manual acceptance named above | agent-resolvable through CI, runtime acceptance Maciek-only |
| XcodeGen emits objectVersion 90, not native Xcode 26 objectVersion 100 | Mandatory first Mac gate; switch once to checked-in native project if blocked | agent-resolvable; fallback acceptance already recommended |
| XcodeGen generator DSL is a migration cost | Keep spec small and ADR explicit; do not add generator-specific abstractions | agent-resolvable |
| GitHub runner images/default Xcode are volatile | Pin `macos-26`, select exact Xcode 26.6, log image/toolchain | agent-resolvable; billing/settings Maciek-only |
| Private GitHub Releases cannot feed Sparkle clients | Make MIT repo public before 0.1.0 or provide another public host; never embed auth | Maciek-only external visibility choice |
| Apple Developer membership, certificates, notary credentials | Fully documented but unavailable here | Maciek-only |
| Sparkle private-key generation/custody | Public key/config can be planned; private key stays in secret store | Maciek-only |
| Bundle-ID registration/provisioning | IDs are resolved in this plan; Apple portal operations unavailable | Maciek-only |
| Unsandboxed direct app has a broader trust boundary | Hardened Runtime, minimal permissions, no helper/network listener; revisit sandbox as one coordinated ADR if needed | agent-resolvable implementation; policy change Maciek-only |
| Unix socket authenticates UID, not signed process | Same-user process is v1 trust boundary; XPC is the documented pivot | agent-resolvable unless product threat model changes |
| Unix socket path limits/races | Darwin user-temp resolver, byte-length guard, `lstat`, server-only unlink, peer checks | agent-resolvable; Mac integration required |
| Fullscreen/Spaces/Stage Manager overlay behavior is not guaranteed by docs | `.screenSaver`/collection behavior is provisional; fail open and record observed limits | Maciek-only physical/runtime acceptance |
| Launch-at-login approval/revocation varies with system state | Expose all statuses and System Settings recovery; clean-user test | Maciek-only runtime acceptance |
| System SQLite module/link behavior differs by host | C module map plus Linux/macOS integration; no wrapper dependency | agent-resolvable |
| Current Swift source pages disagree on standalone 6.3.3 listing | Pin verified compiler/release and document the source inconsistency | agent-resolvable |
| Adapted skill text can drift or acquire unclear provenance | Pin source SHAs, preserve MIT notices, validate source index; never use PolyForm text | agent-resolvable, legal escalation Maciek-only |
| Signed/notarized/Sparkle flow cannot be proven without secrets | Keep PR CI secret-free; run release only after prerequisites exist | Maciek-only credentials, agent-resolvable workflow |
| iOS distribution is intentionally absent | Build/smoke only; TestFlight provisioning is a later decision | locked deferral |

This blueprint deliberately leaves future psychology, scoring, blocking, Screen Time/iCloud, and cloud architecture undefined. The foundation should make those future decisions possible without prebuilding abstractions for them.
