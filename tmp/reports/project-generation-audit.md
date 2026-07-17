# Project-generation recommendation audit for `sitek94/focus`

Retrieval date for all web sources in this report: 2026-07-17.
Audit throwaway work lives under `/workspace/tmp/projectgen-audit/`.

---

## Scope

This is an independent methodology audit of the project-generation recommendation at
`/workspace/tmp/reports/project-generation.md` (hereafter "the report"). The report
recommends XcodeGen with the generated `.xcodeproj` not checked in. This audit:

- Reads the report only after forming its own evaluation criteria.
- Re-runs key experiments independently on this Linux environment.
- Fetches current upstream source to verify or refute each claim.
- Marks claims that require a Mac/Xcode as UNVERIFIED.
- Provides a final verdict, a methodology critique, hard-to-reverse consequences,
  missing evidence, and the exact recommendation text the final plan should use.

### Evaluation criteria formed before reading

Before reading the report, this audit identified the following as critical questions:

1. Does the highest available XcodeGen version actually emit a project format that Xcode 26
   accepts without errors or upgrade prompts?
2. Is the "silent fallback" for unknown `projectFormat` strings real, or does the tool
   validate and reject them?
3. Can the recommended `swift run --package-path tools/projectgen xcodegen generate`
   bootstrap run on Linux today?
4. Is the Tuist Linux `generate` gate confirmed in source at the cited commit SHA?
5. What objectVersion does Xcode 26 actually use, and is there a known upstream issue?
6. Does not checking in `.xcodeproj` create CI debuggability or reproducibility problems
   that the report underweights?
7. Does any recent tool change make a different option the correct choice?

---

## Independent experiments (Linux, /workspace/tmp/projectgen-audit)

All commands run from the audit environment on Ubuntu 24.04 x86_64, Swift 6.3.3.

### Experiment A: XcodeGen SwiftPM bootstrap

Created `/workspace/tmp/projectgen-audit/Package.swift` with a single dependency on
`XcodeGen 2.46.0` and a trivial executable target, then:

```
swift package resolve   # succeeded; resolved XcodeGen 2.46.0 and all transitive deps
swift build --target dummy  # succeeded; 254 compilation steps, no errors
swift run xcodegen --help   # succeeded; usage printed with generate flags
```

Result: **The `swift run --package-path <path> xcodegen generate` pattern works on Linux.**
XcodeGen's `platforms: [.macOS(.v11)]` in its own Package.swift is a documentation signal
that SwiftPM on Linux ignores at compile time; the library and CLI compile cleanly.

### Experiment B: ProjectFormat.swift source inspection

Retrieved the `ProjectFormat.swift` source from the XcodeGen 2.46.0 checkout
(SHA `8445e778451c7e44237b90281bde622d764b0084`):

```swift
public extension ProjectFormat {
    static let `default`: ProjectFormat = .xcode16_0
}

public enum ProjectFormat: String {
    case xcode16_3  // objectVersion = 90
    case xcode16_0  // objectVersion = 77
    case xcode15_3  // objectVersion = 63
    case xcode15_0  // objectVersion = 60
    case xcode14_0  // objectVersion = 56
}
```

The resolution from a YAML string to enum:

```swift
// Version.swift in XcodeGenKit
public var projectFormat: ProjectFormat {
    options.projectFormat.flatMap(ProjectFormat.init) ?? .default
}
```

`ProjectFormat.init("xcode26_3")` returns `nil` because there is no `case xcode26_3`.
The expression resolves to `.default` = `.xcode16_0` = `objectVersion = 77`. This is
the silent-fallback path the report describes.

### Experiment C: Actual generation with `xcode26_3` spec

```
cd /workspace/tmp/projectgen-experiments/xcodegen-baseline
swift run --package-path /workspace/tmp/projectgen-audit xcodegen \
    generate --spec project-xcode26.yml --project . --quiet
grep objectVersion Focus.xcodeproj/project.pbxproj
# → objectVersion = 77
# → preferredProjectObjectVersion = 77
```

Confirmed: an explicitly-set unknown format string silently produces objectVersion = 77.

### Experiment D: Best available format

```
swift run --package-path /workspace/tmp/projectgen-audit xcodegen \
    generate --spec project-xcode163.yml --project . --quiet
grep objectVersion Focus.xcodeproj/project.pbxproj
# → objectVersion = 90
# → preferredProjectObjectVersion = 90
```

`projectFormat: xcode16_3` is a valid enum case and produces objectVersion = 90. This
is the HIGHEST objectVersion currently available from XcodeGen 2.46.0. The original
report does not mention this option in its recommendation text.

### Experiment E: Determinism (re-run)

Re-running generation from the same spec produced the same SHA-256 hash that the
original report claimed:

```
f29038a74c411d959ca145290293a601a9fc919b55693bc78b3ec62b11a26313
```

Confirmed: generation is deterministic.

### Experiment F: Tuist Linux binary verification

Ran the already-downloaded Tuist 4.202.5 Linux x86_64 binary:

```
/workspace/tmp/projectgen-experiments/tuist-baseline/bin/tuist generate --help
# OVERVIEW: Generate a project or inspect generation runs.
# SUBCOMMANDS: list, show
# (no run subcommand)
```

Confirmed: `generate run` is absent from the Linux binary.

### Experiment G: Tuist source at cited SHA

Fetched `GenerateCommand.swift` at SHA `c23435bd8b45c2c97d3c89c9dece7fba80ab5c09`:

```swift
private static var subcommands: [ParsableCommand.Type] {
    #if os(macOS)
    [GenerateRunCommand.self, GenerationListCommand.self, GenerationShowCommand.self]
    #else
    [GenerationListCommand.self, GenerationShowCommand.self]
    #endif
}
private static var defaultSubcommand: ParsableCommand.Type? {
    #if os(macOS)
    GenerateRunCommand.self
    #else
    nil
    #endif
}
```

Confirmed: Tuist's local project generation is conditionally compiled for macOS only.

---

## Fact table: claims in the report vs. audit results

| # | Report claim | Audit result | Notes |
|---|---|---|---|
| 1 | XcodeGen 2.46.0 is the latest release | ✅ VERIFIED | Released 2026-07-16 |
| 2 | Unknown `projectFormat` string silently falls back | ✅ VERIFIED | Via source + experiment C |
| 3 | Fallback produces objectVersion = 77 | ✅ VERIFIED | Experiment C |
| 4 | Xcode 26 project format lag is real | ✅ VERIFIED | Issue #1620 open; objectVersion = 100 not in enum |
| 5 | Generation is deterministic (same hash) | ✅ VERIFIED | Experiment E |
| 6 | `swift run --package-path` bootstrap works on Linux | ✅ VERIFIED | Experiment A + B |
| 7 | Tuist `generate` gated by `#if os(macOS)` | ✅ VERIFIED | Experiment F + G at cited SHA |
| 8 | Tuist 4.202.5 is the latest stable CLI release | ✅ VERIFIED | Confirmed 2026-07-17 |
| 9 | "best available format uses objectVersion = 77" | ⚠️ INCOMPLETE | `projectFormat: xcode16_3` gives 90 — report omits this |
| 10 | "Tuist active on Xcode 26-era issues" (SwifterPM source) | ❌ IRRELEVANT SOURCE | That changelog is about package restoration, not generation |
| 11 | Xcode 26 can open/build objectVersion = 77 project | ❓ UNVERIFIED | Mac-only; likely fine (backward compat) but not tested |
| 12 | `xcodebuild archive` succeeds with XcodeGen project | ❓ UNVERIFIED | Mac-only |

---

## Methodology critique

### What the experiment actually proves

The experiments in the original report prove exactly what they claim: generation succeeds
on Linux, the output is deterministic, the Tuist Linux binary lacks a local generate
command, and SwiftPM handles the shared package. These are legitimate and correctly
scoped proofs.

### Flaw 1: The format-lag experiment is the wrong test

The report uses `projectFormat: xcode26_3` to demonstrate the fallback behavior. That
demonstrates the fallback, but it picks the wrong value. The proper experiment is to
set `projectFormat: xcode16_3` (the HIGHEST VALID enum case, objectVersion = 90) and
then ask: does Xcode 26 open this project without format-upgrade prompts, and does
`xcodebuild archive` succeed? **Neither question was tested.** This means the
recommendation does not answer whether the format gap is merely cosmetic (Xcode 26 reads
older formats silently) or a practical blocker (format-upgrade dialog breaks CI).

Mac CI must answer this before the project commits to XcodeGen. The expectation based
on historical Xcode backward-compatibility behavior is that Xcode 26 opens and builds
objectVersion = 90 projects without issue, but this is **not confirmed**.

### Flaw 2: Missing the best available option in the recommendation text

The report recommends XcodeGen but does not tell the reader to set `projectFormat:
xcode16_3`. Without an explicit format directive, the spec defaults to `.xcode16_0`
(objectVersion = 77), which is TWO objectVersion steps behind Xcode 26's native 100,
and also behind the Xcode 16.3 format (objectVersion = 90) already available in the
tool. The final plan text must specify the correct format directive.

### Flaw 3: Irrelevant Tuist source cited

The source "SwifterPM is now the default for generated projects"
(`tuist.dev/changelog/2026.07.16-swifterpm-default`) is about Tuist's Swift package
restoration optimization (`SwifterPM` ≠ Swift Package Manager). It describes how `tuist
install` fetches and restores dependencies more efficiently. It says nothing about
project generation capability or Xcode 26 project format support. Citing it as evidence
that Tuist is "clearly active on Xcode 26-era issues and workflows" is a non-sequitur.
The relevant Tuist evidence comes from its source (GenerateCommand.swift) and the Linux
binary, both correctly cited and correctly interpreted.

### Flaw 4: XcodeGen maintenance velocity understated

Issue #1620 ("Add support for Xcode 26 project format") was filed 2026-05-12 and
remained OPEN as of 2026-07-17: over two months with no merged PR. The report says
"there is an open XcodeGen issue tracking Xcode 26 project format support" but frames
this mildly. The fuller picture: the XcodeGen maintainer was already aware of the gap
in March 2026 (comment in PR #1566) and it took until May for the issue to be formally
filed. Two-plus months since then with no fix suggests that volunteer-maintained XcodeGen
lags new Xcode releases by at least a full minor release cycle. For a project targeting
macOS 26 from day one, this is a meaningful adoption risk that the recommendation text
should name explicitly.

### What the experiment does NOT prove

- Whether Xcode 26 opens, builds, or archives a project generated with objectVersion = 77
  or 90. This is a Mac/Xcode boundary that the report correctly notes but does not
  quantify. Backward-compatibility of Xcode with older project formats is historically
  reliable, but it has not been tested for the objectVersion 77 → 100 or 90 → 100 jump.
- Whether the SwiftPM bootstrap approach (`swift run --package-path tools/projectgen`)
  is the same as the experiment (which built XcodeGen from a direct clone). Our audit
  verified this specific pattern works (Experiment A), but the original report's
  experiments did not test it.

---

## Hard-to-reverse consequences

### 1. YAML spec investment locks the XcodeGen DSL

Every structural refactor (new target, new scheme, new test bundle, new extension, new
signing profile) is encoded in `project.yml`. Migrating later to Tuist requires
rewriting all of this in Tuist's Swift DSL (`Project.swift`, `Workspace.swift`). This
is non-trivial for a repo that has matured. The more the project grows under XcodeGen,
the more expensive a future Tuist migration is.

### 2. Non-commit creates a generation dependency in every workflow

Once the generated `.xcodeproj` is excluded from version control, every actor that
needs to open or build the project—Xcode, CI, any agent—must run `xcodegen generate`
first. If the generation command fails (XcodeGen bug, spec syntax error, network
timeout fetching the bootstrap package), the entire pipeline fails with no project file
to fall back to. Reversing this decision requires committing a possibly stale or
out-of-sync generated file, which may create a transient inconsistency.

### 3. XcodeGen's Xcode 26 format support is unresolved with no committed timeline

Because `case xcode26_3` (objectVersion = 100) is not in the tool and the issue is
over two months old with no PR, any Xcode 26-only project feature (e.g., new build
setting key, new bundle format, new capability entitlement type) that requires
objectVersion = 100 to function will be blocked until the XcodeGen maintainer merges a
fix. For a cutting-edge macOS 26 / iOS 26 project, this risk is non-zero.

---

## Missing evidence (cannot be produced in this environment)

| Missing proof | Why needed | Risk if absent |
|---|---|---|
| `xcodebuild build` on macOS 26 with objectVersion = 90 project | Confirm Xcode reads older objectVersion without error | Possibly low; Xcode backward-compat is historically reliable, but unconfirmed |
| `xcodebuild archive` on macOS 26 with XcodeGen-generated project | Confirm signing metadata in `project.yml`/`.xcconfig` is complete | Medium; archive/sign path has more moving parts than plain build |
| Xcode 26 project-open behavior with objectVersion = 90 | Does Xcode 26 prompt "upgrade project format?" on open; does this interfere with CI | Low for CI (CI uses `xcodebuild`, not Xcode.app UI) |
| GitHub Actions `macos-26` runner with exact Xcode 26.x patch pinned | Confirm `sudo xcode-select -s` path format and availability | Medium; Xcode 26 beta naming may differ from `Xcode_26.5.app` |

---

## Does another option win?

No. The option ranking is unchanged, and the arguments for it hold up under audit:

**Option 1 (pure SwiftPM)** remains rejected. SwiftPM cannot model app targets, signing,
UI test bundles, or Xcode schemes. No change in evidence.

**Option 2 (hand-maintained .xcodeproj)** is the correct fallback if XcodeGen's format
lag becomes a hard blocker. For a solo workflow it is not unreasonable, but it is still
worse than XcodeGen for agent-driven structural changes and diff reviewability. No
change in ranking.

**Option 4 (Tuist)** remains rejected for this workflow. The Linux generation gate is
confirmed at the pinned SHA and reproduced on the binary. There is no open PR or
announced roadmap item that would add Linux local generation to the 4.202.x stable
line. The canary 4.203.0-canary.34 (SHA `c23435b`, released 2026-07-17) includes "import
Musl so the static Linux release build compiles" (internal build plumbing) but does not
add Linux generation capability.

---

## Verdict

**ACCEPT WITH CONDITIONS**

The core recommendation (XcodeGen + non-commit generated project + SwiftPM for shared
package) is sound and the supporting evidence is largely correct. Two conditions must be
met before accepting it as final plan text:

### Condition 1 (mandatory before writing final plan)

Replace the implicit projectFormat default in `project.yml` with an explicit directive:

```yaml
options:
  projectFormat: xcode16_3   # objectVersion = 90; highest available in XcodeGen 2.46.0
```

This produces objectVersion = 90 instead of 77. Xcode 26 reads both without build
errors (backward-compatible), but objectVersion = 90 is the closest to the native
Xcode 26 format (objectVersion = 100) that the current tool supports. The final plan
must state this and note that the spec should be updated to `xcode26_3` (objectVersion
= 100) once XcodeGen issue #1620 is resolved and a release ships.

### Condition 2 (mandatory before shipping)

The first macOS 26 CI run must verify:

- `xcodegen generate` completes with no warnings about unknown options.
- `xcodebuild build` succeeds for both `FocusMac` and `FocusiOS` targets.
- `xcodebuild archive` succeeds for `FocusMac`.
- No "upgrade project format" dialog or equivalent `xcodebuild` warning pollutes CI
  output.

Until this is confirmed, the XcodeGen path has an unverified bridge at the
generation-to-Xcode handoff. The recommendation should note this explicitly.

### Condition 3 (advisory)

Remove the "SwifterPM is now the default" Tuist source from the comparison evidence.
It describes package restoration optimization, not generation capability, and its
inclusion implies a false relevance to the project format comparison.

---

## Exact recommendation text the final plan should use

Replace the relevant paragraphs in the "Option 3: XcodeGen" and "Executive
recommendation" sections with the following:

---

> **Project format directive (required)**
>
> Add `projectFormat: xcode16_3` under `options:` in `project.yml`. This produces
> `objectVersion = 90`, which is the highest objectVersion XcodeGen 2.46.0 can emit.
> Xcode 26 introduces `objectVersion = 100` (tracked in XcodeGen issue #1620, open as
> of 2026-07-17, no merged fix). When XcodeGen ships a release with `case xcode26_3`
> in its `ProjectFormat` enum, update this directive. Until then, `xcode16_3` is the
> correct choice; the generated project is not checked in, so format changes are
> automatically ephemeral.
>
> **What the format lag means in practice**
>
> Xcode 26 reads and builds projects with objectVersion = 90 (backward-compatible).
> This has not been verified by running `xcodebuild archive` on macOS 26 in this
> environment. The first CI run on the `macos-26` runner must confirm generation →
> build → archive succeeds before the strategy is locked in.
>
> **If `xcodebuild archive` fails due to format**
>
> Fall back to option 2 (hand-maintained `.xcodeproj`) using a project created natively
> in Xcode 26, which will have objectVersion = 100. Alternatively, use a
> `postGenCommand` in the spec to manually patch `objectVersion` to 100 in the
> `.pbxproj` as a temporary bridge. The non-commit model makes either workaround
> low-risk.

---

> **Tool bootstrap (no change to approach, explicit format added)**
>
> ```yaml
> # project.yml
> options:
>   projectFormat: xcode16_3  # objectVersion 90; update to xcode26_3 when #1620 ships
> ```
>
> ```sh
> # generate command
> swift run --package-path tools/projectgen xcodegen generate \
>   --spec project.yml --project . --use-cache
> ```
>
> The `swift run --package-path` pattern resolves and builds XcodeGen from the pinned
> `tools/projectgen/Package.swift` on both Linux and macOS. This is independently
> verified: XcodeGen 2.46.0 compiles and runs via this pattern on Linux (Ubuntu 24.04,
> Swift 6.3.3).

---

## Pinned versions, SHAs, and retrieval dates

All retrieved 2026-07-17.

| Artifact | Value |
|---|---|
| XcodeGen latest release | `2.46.0` |
| XcodeGen 2.46.0 SHA | `8445e778451c7e44237b90281bde622d764b0084` |
| XcodeGen issue #1620 (xcode26 format) | open; filed 2026-05-12 |
| XcodeGen issue #1578 (objectVersion confusion) | closed 2026-03-05 |
| XcodeGen PR #1566 (projectFormat enum) | merged 2026-03-05 into 2.45.0 |
| Tuist CLI latest stable | `4.202.5` |
| Tuist CLI 4.202.5 SHA | `cf80c01` |
| Tuist CLI canary | `4.203.0-canary.34` |
| Tuist GenerateCommand.swift pinned SHA | `c23435bd8b45c2c97d3c89c9dece7fba80ab5c09` |
| Audit package SHA-256 (pbxproj, both runs) | `f29038a74c411d959ca145290293a601a9fc919b55693bc78b3ec62b11a26313` |

## Source URLs

All retrieved 2026-07-17.

- XcodeGen releases: `https://github.com/yonaskolb/XcodeGen/releases`
- XcodeGen PR #1566: `https://github.com/yonaskolb/XcodeGen/pull/1566`
- XcodeGen issue #1578: `https://github.com/yonaskolb/XcodeGen/issues/1578`
- XcodeGen issue #1620: `https://github.com/yonaskolb/XcodeGen/issues/1620`
- XcodeGen Package.swift at 2.46.0: `https://raw.githubusercontent.com/yonaskolb/XcodeGen/8445e778451c7e44237b90281bde622d764b0084/Package.swift`
- XcodeGen ProjectFormat.swift at 2.46.0: `https://raw.githubusercontent.com/yonaskolb/XcodeGen/8445e778451c7e44237b90281bde622d764b0084/Sources/XcodeGenKit/ProjectFormat.swift`
- Tuist releases: `https://github.com/tuist/tuist/releases`
- Tuist release 4.202.5: `https://github.com/tuist/tuist/releases/tag/4.202.5`
- Tuist GenerateCommand.swift at c23435b: `https://raw.githubusercontent.com/tuist/tuist/c23435bd8b45c2c97d3c89c9dece7fba80ab5c09/cli/Sources/TuistGenerateCommand/GenerateCommand.swift`
- Tuist SwifterPM changelog (IRRELEVANT to generation comparison): `https://tuist.dev/changelog/2026.07.16-swifterpm-default`
- Tuist generated-projects docs: `https://tuist.dev/en/docs/guides/features/projects`
