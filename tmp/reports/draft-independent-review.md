# Independent review: plan-draft.md

Review date: 2026-07-18. Reviewer: independent audit (not the plan author).
Sources consulted: `plan-draft.md`, `requirements-matrix.md`, `repo-design.md`,
`ipc-audit.md`, `project-generation-audit.md`, `citation-ledger.md`, `toolchains.md`,
`github-actions.md`. All line references are to `plan-draft.md` unless stated otherwise.

---

## Severity count

| Severity | Count |
|---|---:|
| BLOCKER (must fix before implementation starts) | 4 |
| HIGH (must fix before plan is accepted) | 9 |
| MEDIUM (must address; document or resolve before implementation) | 9 |
| LOW (clean up; non-blocking) | 5 |
| **Total** | **27** |

---

## BLOCKER findings

### B-1 CLI commands contradict the locked product requirement

**Lines:** §8 command table, lines 334–344; also acceptance matrix §20 line 837.

**What the plan says:** The CLI exposes nine commands: `status`, `open`, `start-now`,
`snooze`, `skip`, `pause`, `resume`, `install`, `version`.

**What the brief and `requirements-matrix.md` §11.2 require:**

> "Commands are exactly `status`, `start`, `pause`, `resume`, `skip`, `trigger-break`"

`requirements-matrix.md` §12.4 adds:

> "Only `start` may cold-launch the sibling app; other commands require a running app"

**Discrepancies (each is independently a blocker):**

| Required command | Plan command | Gap |
|---|---|---|
| `start` | `open` | Renamed without justification |
| `trigger-break` | `start-now` | Renamed without justification; `trigger-break` absent entirely |
| *(not in required set)* | `snooze` | Extra command violates "no speculative features" unless the brief explicitly adds it |
| *(not in required set)* | `install` | Utility command; not in locked set |
| *(not in required set)* | `version` | Diagnostic command; not in locked set |

`trigger-break` does not appear anywhere in `plan-draft.md`. `start` appears only as the
human-output example `"Focus is not running."` in the error block, not as a CLI command.

**Impact:** `requirements-matrix.md` §11.2 names the acceptance test as
`swift run focus --help` showing exactly those six commands. CI will fail the contract
check. Downstream docs, shell completions, and user documentation will embed the wrong
names.

**Corrected wording for §8 command table:**

Replace the entire command table with the six locked commands. Map domain actions to
commands explicitly:

| Command | App running required? | Auto-launch? | Meaning |
|---|---|---|---|
| `focus status [--json]` | No | No | Report running state and current Focus phase. |
| `focus start [--json]` | No | Yes | Launch sibling `Focus.app`, wait for socket, return status. |
| `focus pause [--json]` | Yes | No | Domain `pause`. |
| `focus resume [--json]` | Yes | No | Domain `resume`. |
| `focus skip [--json]` | Yes | No | Domain `skip`; ends current obligation. |
| `focus trigger-break [--json]` | Yes | No | Domain `startNow`; legal only in warning state. |

If `snooze`, `install`, and `version` are genuinely required, they must be added to the
locked requirements first — not slipped into the plan as unnamed extras.

---

### B-2 Licensing directly contradicts the brief

**Lines:** §18, lines 788–805.

**What the plan says (line 790):**

> "Keep Focus private/proprietary by default unless Maciek intentionally chooses an OSS license."

**Line 805:**

> "Do not add a public OSS `LICENSE` file unless the product decision is to license Focus
> source publicly."

**What the brief requires (from the user query):**

> "licensing (Focus must become public MIT)"

These are flatly incompatible. The plan actively instructs implementers to withhold the
MIT `LICENSE` file. When the foundation PR lands, there will be no `LICENSE` file and no
public OSS grant, directly violating the stated product requirement.

**Corrected wording for §18:**

Replace the current §18 entirely with:

```
Repository/product posture:
- Focus source is licensed under MIT. Add `LICENSE` (MIT, copyright Maciek Sitkowski, year 2026).
- Add `THIRD_PARTY_NOTICES.md` because the distributed app includes third-party components
  (Sparkle). Include Sparkle's MIT notice and bundled component notices.
- Do not add EULA or proprietary distribution terms to the source repository.

Required license actions for Checkpoint 9:
- `LICENSE` file with MIT text and correct copyright holder.
- `THIRD_PARTY_NOTICES.md` with Sparkle MIT notice (pinned SHA b6496a74...) and any bundled
  Sparkle sub-component notices from the Sparkle repository.
```

---

### B-3 Module and test-suite names contradict `requirements-matrix.md` throughout

**Lines:** §5 target table lines 186–194; §7 lines 245–313; §12 lines 575–594;
§20 acceptance matrix lines 833–852.

**What the plan says:**

- SwiftPM library `FocusDomain` (line 186), tests at `Tests/FocusDomainTests/` (line 148)
- SwiftPM library `FocusIPC` (line 188), tests at `Tests/FocusIPCTests/` (line 151)
- Tests at `Tests/FocusPersistenceTests/` (line 150)

**What `requirements-matrix.md` requires:**

The matrix names concrete acceptance tests by suite name throughout all 21 sections. Every
named test uses the authoritative module names from `repo-design.md`:

| Matrix suite | Plan suite | Named tests that become unreachable |
|---|---|---|
| `FocusSessionTests` (§4, §5, §7) | `FocusDomainTests` | `FocusSessionTests.focusReachesWarningAtNineteenMinutesFiftySeconds`, `FocusSessionTests.pauseFreezesCurrentObligation`, and 12 others |
| `FocusPersistenceIntegrationTests` (§7, §8) | `FocusPersistenceTests` | `FocusPersistenceIntegrationTests.pausedSnapshotRestoresWithoutFastForward`, `FocusPersistenceIntegrationTests.failedAppendLeavesSnapshotAndEventsUnchanged`, and 4 others |
| `FocusSettingsTests` (§1, §8) | *(absent)* | `FocusSettingsTests.noTimingPreferencesExist`, `FocusSettingsTests.noTimingFieldsInPreferencesSchema` — both required acceptance tests |

`FocusSettings` as a distinct SwiftPM library target does not appear anywhere in
`plan-draft.md`. The plan folds preferences into `FocusDomain` and `FocusPersistence`
without explanation and without providing the required named tests.

**Additional impact:** `requirements-matrix.md` §10.1 requires that
`rg -n "import (SwiftUI|AppKit|UIKit)" Sources/FocusSession Sources/FocusSettings Sources/FocusPersistence`
returns no hits. The path `Sources/FocusSession` does not exist in the plan.

**Corrected structure:** Use the module names from `requirements-matrix.md`/`repo-design.md`:

| Module | Plan name | Correct name |
|---|---|---|
| Session/domain | `FocusDomain` | `FocusSession` |
| Settings | *(absent)* | `FocusSettings` (add as separate target) |
| Tests | `FocusDomainTests` | `FocusSessionTests` |
| Tests | `FocusPersistenceTests` | `FocusPersistenceIntegrationTests` |

`FocusIPC` may be retained as a separate module, but it needs explicit justification
because it introduces an unjustified abstraction layer not in the original design (see M-6).

---

### B-4 `snooze` CLI command absent from locked requirement set

**Lines:** §8 line 340; §8 human output example line 356; §8 JSON result line 372.

This is a subsidiary issue of B-1 but merits separate call-out because `snooze` is woven
into the examples and acceptance criteria. The brief lists six locked commands with no
`snooze`. The plan's human output example (`focus snooze` / `Break snoozed for 1m.`),
JSON example (`"command": "snooze"`), and command table all assume a seventh command.

If `snooze` is intentionally added as a seventh command, the locked requirement set must be
updated before implementation — this review cannot accept the plan's own claim that the six
commands are locked while simultaneously defining a seventh. The plan must either:

1. Remove `snooze`, `install`, and `version` from §8 and rely on the app UI + menu bar for
   snooze, or
2. Amend the locked requirements list at the top of the plan (lines 7–18) to include
   `snooze` and remove the "exact" qualifier from `requirements-matrix.md` §11.2.

---

## HIGH findings

### H-1 `git tag -v` in release commands creates a signed-tag instead of verifying one

**Lines:** §15, line 689.

**What the plan says:**

```sh
git tag -v v0.1.0
```

`git tag -v` **verifies** an existing signed tag; it does not create one. The release
command section is describing how to create the `v0.1.0` release. The correct command to
create a signed tag is:

```sh
git tag -s v0.1.0 -m "Release v0.1.0"
```

Verification (`git tag -v v0.1.0`) should appear as a separate check after creation.

This is a factual error that would cause an implementer to verify a tag that has not yet
been created rather than create it.

---

### H-2 JSON success example is semantically self-contradictory

**Lines:** §8, lines 367–390.

The JSON success example describes the result of a `snooze` command:

```json
"result": {"command": "snooze", "performed": true}
```

But then the `"state"` block shows:

```json
"phase": "focus",
"warningStartsAt": "2026-07-17T23:20:50Z",
"breakDueAt": "2026-07-17T23:21:00Z",
"remainingSeconds": 60,
"canStartNow": false,
"canSnooze": false
```

Two problems:

1. `remainingSeconds: 60` combined with `warningStartsAt` 10 seconds before `breakDueAt`
   means the warning is in 50 seconds, not 60. If `remainingSeconds` is the time until
   warning (50s), the JSON is wrong. If it is time until break (60s), it should be
   labeled `secondsUntilBreak` or the field semantics must be documented.
2. `canSnooze: false` is shown. If the user just snoozed from warning, the state returned
   to focus, which is correct — snooze is only available from warning. But the JSON does
   not show the pre-command phase, so a reader cannot know whether the transition was
   legal. The schema should document that `canX` fields reflect the **post-command** state.

The example should use a command from the locked set (see B-1) and be annotated to clarify
that `remainingSeconds` means "seconds until next phase transition."

---

### H-3 `Config/` layout placement is inconsistent between plan and prior design docs

**Lines:** §5 layout, lines 126–130; compare `repo-design.md` §`Apps/Focus/Config/`.

The plan places `Config/` at the repository root (alongside `Package.swift`). Every other
design document — `repo-design.md`, the `project-generation-audit.md` generate command,
and the IPC socket path design — treats the app-native configuration (`*.xcconfig`,
`ExportOptions.plist`) as living under `Apps/Focus/Config/`. Placing them at root and
running `xcodegen generate --project .` means the generated `.xcodeproj` lands at the
repository root, not under `Apps/Focus/`. That conflicts with:

- `requirements-matrix.md` §15.3: "After generation: `git ls-files "Apps/Focus/Focus.xcodeproj"` must return nothing."
- `repo-design.md`: `Apps/Focus/Focus.xcodeproj`.
- Plan §5 line 175: `.gitignore` entry `Focus.xcodeproj/` — correct path if root, but wrong if `Apps/Focus/`.

If the project is generated at root, the `.gitignore` entry should be `Focus.xcodeproj/`.
If it is generated at `Apps/Focus/`, the generate command must use `--project Apps/Focus`.
The plan uses `--project .` (§13 line 622), generating at root, yet the acceptance matrix
checks `Apps/Focus/Focus.xcodeproj` — the two are incompatible.

**Corrected approach:** Pick one layout and make it consistent throughout all five
locations: root layout, generate command, `.gitignore`, XcodeGen spec, and acceptance
matrix.

---

### H-4 `FocusMac`/`FocusIOS` target names and bundle IDs conflict with `repo-design.md`

**Lines:** §5 target table, lines 191–192; `repo-design.md` target table.

| Item | Plan | `repo-design.md` | Impact |
|---|---|---|---|
| macOS Xcode app target | `FocusMac` | `FocusMacApp` | xcodebuild `-scheme` name differs |
| iOS Xcode app target | `FocusIOS` | `FocusIOSApp` | xcodebuild `-scheme` name differs |
| macOS bundle ID | `com.macieksitkowski.focus.mac` | `com.macieksitkowski.focus.macos` | Entitlement mismatch at signing time |
| macOS smoke bundle ID | `com.macieksitkowski.focus.mac.uismoke` | `com.macieksitkowski.focus.macosuitests` | Test host mismatch |

The CI commands in §13 and §14 use `-scheme FocusMac` and `-scheme FocusIOS`. If the
schemes later align with `repo-design.md`, every CI script must change. The bundle ID
difference between `.mac` and `.macos` is a hard-to-reverse artifact that will be baked
into entitlement files, notarization records, and Sparkle appcast metadata.

Choose one canonical set and enforce it consistently in `project.yml`, `AGENTS.md`, all
xcodebuild commands, and the acceptance matrix.

---

### H-5 `VendorSkills/manifest.lock.json` and `make verify-vendored-skills` absent from plan

**Lines:** §5 layout lines 110–171; §13 make targets lines 601–617; §17 lines 759–784;
compare `repo-design.md` §Skill vendoring metadata and §Canonical commands.

`repo-design.md` explicitly defines `VendorSkills/manifest.lock.json` as the
machine-readable source of truth for third-party skill content. `requirements-matrix.md`
§17.3 requires:

> "`make verify-vendored-skills`" as the verification command for skill attribution.

The plan's layout (lines 110–171) omits `VendorSkills/`. The plan's make targets (§13)
omit `make verify-vendored-skills`. The plan's script list (line 162) has
`verify-research-provenance.py` — a different name with different scope — instead of
`verify-vendored-skills.py`. This means the §17 acceptance criteria are unverifiable
as written.

**Fix:** Add `VendorSkills/manifest.lock.json` to the root layout, rename the script to
`verify-vendored-skills.py`, and add `make verify-vendored-skills` to the §13 canonical
command list and the §19 checkpoint 9 acceptance criteria.

---

### H-6 `FocusIPCTests` is unexplained and splits named tests across two suites

**Lines:** §12 lines 580–583; `requirements-matrix.md` §12.

The plan introduces `FocusIPCTests` as a separate test suite. `requirements-matrix.md` §12
places all IPC-protocol acceptance tests under `FocusCLIIntegrationTests`:

- `FocusCLIIntegrationTests.ipcEnvelopeIncludesProtocolAndRequestId` (§12.2)
- `FocusCLIIntegrationTests.connectionClosesAfterSingleReply` (§12.2)
- `FocusCLIIntegrationTests.oversizeFrameRejected` (§12.6)
- `FocusCLIIntegrationTests.timeoutMapsToExit4` (§12.6)

If the plan introduces `FocusIPCTests`, those named tests become unreachable under the
required suite name, breaking the `requirements-matrix.md` acceptance criteria. Either
consolidate IPC framing tests into `FocusCLIIntegrationTests` or add `FocusIPCTests` to
the matrix with new named test IDs.

---

### H-7 `FocusSettings` module is silently dropped; two required named tests are orphaned

**Lines:** §5 target table lines 186–194; §7 lines 243–313; compare `requirements-matrix.md`
§1.5 and §8.2.

`requirements-matrix.md` §1.5 requires:

> "Named test `FocusSettingsTests.noTimingPreferencesExist`"

`requirements-matrix.md` §8.2 requires:

> "Named test `FocusSettingsTests.noTimingFieldsInPreferencesSchema`"

Neither test can exist if `FocusSettings` is not a module. The plan places preferences
entirely within `FocusDomain` constants and `FocusPersistence` tables with no separate
settings-layer target. This is a dropped requirement without justification.

**Fix:** Add `Sources/FocusSettings/` and `Tests/FocusSettingsTests/` to the plan's target
table, layout, and checkpoint 3 or 4 file lists. Define `FocusSettings` as the owner of the
preferences schema (matching `requirements-matrix.md` §8 paths like
`Sources/FocusSettings/`, `Apps/Focus/FocusMac/Features/Settings/`).

---

### H-8 `FocusPersistenceTests` should be `FocusPersistenceIntegrationTests`

**Lines:** §5 layout line 150; §12 line 581; compare `requirements-matrix.md` §7 and §8.

`requirements-matrix.md` names required tests as `FocusPersistenceIntegrationTests.*`:

- `FocusPersistenceIntegrationTests.pausedSnapshotRestoresWithoutFastForward` (§7.4)
- `FocusPersistenceIntegrationTests.preferencesRoundTrip` (§8.1)
- `FocusPersistenceIntegrationTests.failedAppendLeavesSnapshotAndEventsUnchanged` (§8.4)
- `FocusPersistenceIntegrationTests.appendedEventsIncludeStartedCompletedSnoozedSkipped` (§8.3)

The plan's suite name `FocusPersistenceTests` (line 150) is missing the `Integration` word.
These are explicitly integration tests (real temp directories, real stores, migration
assertions) and the matrix requires the `Integration` suffix in the suite name.

---

### H-9 `requirements-matrix.md` §3.4 acceptance check references menu items not in plan

**Lines:** §8 human output/command table; compare `requirements-matrix.md` §3.4.

`requirements-matrix.md` §3.4 requires a manual Mac check of:

> "menu contents: status, start, pause, resume, skip, settings, install/repair CLI if present"

The plan's menu-bar section (§10, §11) does not enumerate the required menu items. The plan
lists domain commands under `focus` CLI but does not commit to matching menu-bar items by
name. If the CLI renames `start`→`open` and `trigger-break`→`start-now` (B-1), the menu
names become inconsistent with the required check.

The acceptance matrix check at §20 has no corresponding row for menu-bar item naming, so
this acceptance criterion is currently unverifiable.

---

## MEDIUM findings

### M-1 PolyForm 1.0.0 URL is HTTP 404 — plan cites it directly

**Lines:** §2 line 64.

The plan cites `https://polyformproject.org/licenses/perimeter/1.0.0/` as the PolyForm
Perimeter license source. `citation-ledger.md` §3 records this as **FAILED** (HTTP 404 on
2026-07-17). The corrected citation is the pinned repo LICENSE blob:

```
https://github.com/dpearson2699/swift-ios-skills/blob/90c9573272531337962fbb3505036d61ed23389a/LICENSE
```

---

### M-2 `Apps/Focus/Mac/` vs `Apps/Focus/FocusMac/` directory naming

**Lines:** §5 layout lines 131–141; compare `repo-design.md` §`Apps/Focus/FocusMac/`.

Plan uses `Apps/Focus/Mac/` and `Apps/Focus/iOS/` as source directories. `repo-design.md`
uses `Apps/Focus/FocusMac/` and `Apps/Focus/FocusIOS/`. The XcodeGen spec
(`project.yml`) references source directories by path; this naming difference means either
`project.yml` will reference paths that don't match the layout or the layout will not
match `repo-design.md`. Standardize on the `FocusMac`/`FocusIOS` convention throughout.

---

### M-3 XcodeGen generate command path is ambiguous

**Lines:** §13, line 622.

```sh
swift run --package-path tools/projectgen xcodegen generate --spec project.yml --project . --use-cache
```

`--project .` generates the `.xcodeproj` at the current working directory (repo root).
`requirements-matrix.md` §15.3 checks `git ls-files "Apps/Focus/Focus.xcodeproj"` as the
untracked-project gate. If the project lands at the root as `./Focus.xcodeproj`, the check
path `Apps/Focus/Focus.xcodeproj` would never match. This is an internal inconsistency
between the generate command and the acceptance check.

**Fix:** Either change the generate command to `--project Apps/Focus` (to match
`repo-design.md`) and update the `.gitignore` entry, or change the acceptance check to
`git ls-files "Focus.xcodeproj"` and update `repo-design.md`.

---

### M-4 ADR titles conflict with `repo-design.md`

**Lines:** §16 line 743–745; compare `repo-design.md` §Docs, ADR list.

| Plan | `repo-design.md` |
|---|---|
| `docs/adr/0001-foundation-stack.md` | `docs/adr/0001-repository-shape.md` |
| `docs/adr/0002-xcodegen-conditional.md` | `docs/adr/0002-target-graph-and-boundaries.md` |
| `docs/adr/0003-ipc-unix-socket.md` | *(no IPC ADR in repo-design)* |

The plan adds a new ADR for IPC without documenting that it supersedes or extends the
`repo-design.md` ADR list. If both are implemented literally, there will be duplicate ADRs
with conflicting names.

---

### M-5 `generate_appcast` is not identified as Sparkle's bundled binary

**Lines:** §15, line 698.

```sh
generate_appcast build/release-assets
```

`generate_appcast` is a binary shipped inside the Sparkle distribution. It is not a
standard macOS tool and its path is not on `PATH` by default. The release command should
specify either the Xcode-built tool path or the Sparkle download path:

```sh
# Option A: from Sparkle SPM build output
$(BUILT_PRODUCTS_DIR)/generate_appcast build/release-assets
# Option B: explicit path after downloading Sparkle binary distribution
./Sparkle-2.9.4/bin/generate_appcast build/release-assets
```

Leaving it unqualified means the release command silently fails if Sparkle's binary path
is not in `PATH`.

---

### M-6 `FocusIPC` as a separate SwiftPM library is unjustified new abstraction

**Lines:** §5 target table line 188; §11 concurrency map.

`repo-design.md` and `requirements-matrix.md` do not include a `FocusIPC` module. The plan
introduces it as a standalone library with a separate test suite (`FocusIPCTests`). This
adds a new dependency edge (`FocusCLI → FocusIPC`, `FocusMac app → FocusIPC`) that was
not in the original design, and a separate target that has no independent consumers beyond
the CLI and the app's IPC server.

The IPC framing, envelope, and transport abstractions can live in `FocusCLI` or the app
itself, or in a shared private module. If `FocusIPC` is retained, the plan must justify why
the framing logic cannot live in `FocusCLI` and why an extra module layer is worth the
maintenance surface. The original principle is "minimal feature-first foundation, no
speculative extensions" (plan line 18).

---

### M-7 `docs/agent/skills-curation.md` vs `docs/skills/curation-and-licensing.md`

**Lines:** §16, line 745; compare `repo-design.md` §Docs.

Plan: `docs/agent/skills-curation.md`
`repo-design.md`: `docs/skills/curation-and-licensing.md`

These are different directories (`docs/agent/` vs `docs/skills/`) and different file names.
The plan also does not include `docs/contributing/agent-workflow.md` from `repo-design.md`.
Standardize the docs layout with `repo-design.md` or explicitly override it with a
documented reason.

---

### M-8 Acceptance matrix §20 line 839 says "Linux/Mac" for objectVersion check but generation must run first

**Lines:** §20, line 839.

The acceptance check "Inspect generated `project.pbxproj`" is listed with environment
"Linux/Mac". On Linux, this check requires running `xcodegen generate` first (which works,
per `project-generation-audit.md` Experiment A). The check should explicitly state:

```
Verification: After running `make generate-project`, grep objectVersion from the generated
project.pbxproj. On Linux, this is a post-generation check requiring xcodegen to have run.
```

Without this clarification, a reviewer may assume the check requires no prerequisites.

---

### M-9 `CHANGELOG.md` missing from checkpoint 1 file list but required for release prerequisites

**Lines:** §19 checkpoint 1 line 812; §15 release prerequisites table line 706.

§15 lists `CHANGELOG.md` as a CI-validatable release prerequisite. Checkpoint 1 (line 812)
lists the root contract files but does not include `CHANGELOG.md`. If checkpoint 1 passes
CI without `CHANGELOG.md` existing, the release-prerequisite check (§15) will fail on
first use.

**Fix:** Add `CHANGELOG.md` to checkpoint 1 file list.

---

## LOW findings

### L-1 `macos-26` default Xcode will switch on 2026-07-21; CI note missing

**Lines:** §14 CI policies lines 653–661; §3 toolchains table lines 72–87.

`citation-ledger.md` §5 and `github-actions.md` report that `runner-images` issue #14344
schedules the default Xcode switch on `macos-26` to Xcode 26.6 starting 2026-07-21. The
plan does not mention this, so an implementer reading the plan on or after 2026-07-21 might
not understand why `xcode-select` is still pinned even when the runner default "already
matches." The explicit pin is still correct for reproducibility — but a note explaining the
rationale would prevent future accidental removal of the pin.

---

### L-2 Bundle ID suffix `.mac` vs `.macos` for macOS smoke tests

**Lines:** §5 target table, line 193.

Plan: `com.macieksitkowski.focus.mac.uismoke`
`repo-design.md`: `com.macieksitkowski.focus.macosuitests`

Both the suffix naming pattern (`.mac.uismoke` vs `.macosuitests`) and the base suffix
(`.mac` vs `.macos`) differ. Once the team signs and notarizes a build, these identifiers
become part of the permanent notarization record and `stapler` ticket cache. Changing them
later requires re-provisioning profiles. Settle on one pattern now.

---

### L-3 `docs/architecture/ipc-and-cli.md` is named in §16 but not in `repo-design.md`

**Lines:** §16, line 741.

`repo-design.md` has no `docs/architecture/ipc-and-cli.md`; it has
`docs/architecture/targets-and-identifiers.md` instead. The plan adds an IPC/CLI doc
that is not in the original layout. If both are created, the `docs-list` script will check
them; if only the plan's version is created, `repo-design.md`'s
`targets-and-identifiers.md` will be missing.

---

### L-4 `ipc-audit.md` uses `NSXPC` URL citing `NSXPCConnection.setCodeSigningRequirement`; plan cites the Listener variant

**Lines:** §2 line 59: `https://developer.apple.com/documentation/foundation/nsxpclistener/setconnectioncodesigningrequirement(_:)`

`ipc-audit.md`'s source list also cites the `NSXPCConnection` variant:
`https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement(_:)`.
The plan cites only the listener variant. Both exist; the connection variant is what a client
would use. No blocking error, but only citing the listener side leaves the client-side
requirement unsourced.

---

### L-5 `verify-research-provenance.py` name does not match `verify-vendored-skills.py`

**Lines:** §5 layout line 162; compare H-5 and `repo-design.md`.

The plan's layout includes `Scripts/verify-research-provenance.py`. This name does not
match the verification script in `repo-design.md` (`verify-vendored-skills.py`) or the
make target required by `requirements-matrix.md` (`make verify-vendored-skills`). The
script name should be `verify-vendored-skills.py` to match all downstream references.

---

## Summary: top blockers and corrected wording

### Priority order for resolution

1. **B-1** (CLI commands): Fix command table to use `status`, `start`, `pause`, `resume`,
   `skip`, `trigger-break`. Update all examples, JSON schemas, and exit-code documentation.
2. **B-2** (Licensing): Replace §18 with MIT licensing instructions. Add `LICENSE` to
   checkpoint 9 file list.
3. **B-3** (Module names): Rename `FocusDomain` → `FocusSession`; add `FocusSettings`;
   rename `FocusDomainTests` → `FocusSessionTests`; rename `FocusPersistenceTests` →
   `FocusPersistenceIntegrationTests`. Update every reference in §5, §7, §12, §19, §20.
4. **B-4** (Snooze command scope): Either remove `snooze` from the CLI command set and
   mark it as menu-bar-only, or amend the locked requirements to explicitly add it.
5. **H-1** (git tag): Change `git tag -v v0.1.0` to `git tag -s v0.1.0 -m "Release v0.1.0"`;
   add a separate verify step.
6. **H-3** (Config/ location): Resolve generate-command path vs acceptance-matrix path
   inconsistency; pick `--project .` (root) or `--project Apps/Focus` and enforce across
   all references.
7. **H-4** (Target names): Standardize `FocusMac`/`FocusIOS` vs `FocusMacApp`/`FocusIOSApp`
   and `.focus.mac` vs `.focus.macos` bundle ID prefix.
8. **H-5** (VendorSkills): Add `VendorSkills/manifest.lock.json` to layout; rename script;
   add `make verify-vendored-skills` to canonical command list.
9. **H-7** (FocusSettings): Add `Sources/FocusSettings/` and `Tests/FocusSettingsTests/`
   with required named tests `noTimingPreferencesExist` and `noTimingFieldsInPreferencesSchema`.

### Items the plan correctly gets right (do not regress)

- XcodeGen `projectFormat: xcode16_3` / `objectVersion = 90` pin (confirmed by audit).
- Unix-domain socket guarded per-user private directory with `getpeereid` (matches `ipc-audit.md`).
- Untracked generated project; `.gitignore` exclusion; first Mac CI gate as acceptance gate.
- `SMAppService.mainApp` for launch at login; no helper login-item target.
- `macos-26` runner + explicit `Xcode_26.6.app` path selection (correct per `github-actions.md`).
- Swift 6.3.3, `swift-tools-version: 6.3`, `swiftLanguageModes: [.v6]`.
- All research pins and SHAs are consistent with `citation-ledger.md` (all VERIFIED).
- Fixed timer constants (20m/10s/20s/60s) with no user-configurable knobs.
- `LSUIElement` for Dock suppression; fail-open overlay design.
- Linux-vs-Mac proof boundaries documented throughout.
- No speculative extension targets (widget, intents, helper).
