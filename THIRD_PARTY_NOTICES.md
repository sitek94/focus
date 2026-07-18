# Third-party notices

This file records licenses and provenance for third-party code that Focus
distributes or materially adapts. Classifications follow `PLAN.md` §18:
`copied`, `adapted`, or `pattern/inspiration`.

## Distributed dependencies

### Sparkle

| Field | Value |
|---|---|
| Classification | Distributed macOS runtime dependency (FocusMac / XcodeGen only; not in portable SwiftPM graph) |
| Version | 2.9.4 |
| Commit | `b6496a74a087257ef5e6da1c5b29a447a60f5bd7` |
| Upstream | https://github.com/sparkle-project/Sparkle |
| License | MIT (plus bundled component notices in upstream tree) |

Copyright (c) 2006-2013 Andy Matuschak.
Copyright (c) 2009-2013 Elgato Systems GmbH.
Copyright (c) 2011-2014 Kornel Lesiński.
Copyright (c) 2015-2017 Mayur Pawashe.
Copyright (c) 2014 C.W. Betts.
Copyright (c) 2014 Petroules Corporation.
Copyright (c) 2014 Big Nerd Ranch.
All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#### Sparkle bundled-component notices (commit `b6496a74a087`)

**bsdiff / bspatch** (Colin Percival) — BSD-style license as in upstream `LICENSE`.

**sais-lite** (Yuta Mori) — MIT-style license as in upstream `LICENSE`.

**Ed25519** (Orson Peters / orlp/ed25519) — zlib-style license as in upstream
`LICENSE` and `Vendor/ed25519-sparkle/license.txt`.

**SUSignatureVerifier.m** (Mark Hamlin) — BSD-style license as in upstream `LICENSE`.

Retain the full upstream `LICENSE` text with distributed Sparkle binaries.

### SQLite

| Field | Value |
|---|---|
| Classification | System library (`libsqlite3`) |
| License | Public domain |

Focus links the OS/system SQLite library. No third-party SQLite wrapper is vendored.

## Development tools

### XcodeGen

| Field | Value |
|---|---|
| Classification | Development-only tool (not shipped in the app) |
| Version | 2.46.0 |
| Commit | `8445e778451c7e44237b90281bde622d764b0084` |
| Upstream | https://github.com/yonaskolb/XcodeGen |
| License | MIT |

Pinned through `tools/projectgen/Package.swift` for deterministic project generation.

## Adapted agent skills

Each adapted skill under `.agents/skills/` records upstream URL, full SHA, source
paths, license, and copied-vs-adapted disposition in its `SKILL.md` header.
`make check-skills` validates `.agents/skills/SOURCES.md` against this file and
those headers. Disposition for the three MIT skills below is **adapted**
(substantial rewrite; not verbatim copies).

### focus-swiftui

| Field | Value |
|---|---|
| Classification | adapted |
| Upstream | https://github.com/AvdLee/SwiftUI-Agent-Skill |
| Commit | `f06d1437a3fbec7df6cdce93f77004e5409b31ee` |
| License | MIT |
| Source paths | `swiftui-expert-skill/SKILL.md`; `swiftui-expert-skill/references/{macos-scenes,macos-window-styling,liquid-glass,localization,accessibility-patterns,view-structure}.md` |
| Focus path | `.agents/skills/focus-swiftui/SKILL.md` |

Copyright (c) 2026 Antoine van der Lee

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### focus-concurrency

| Field | Value |
|---|---|
| Classification | adapted |
| Upstream | https://github.com/AvdLee/Swift-Concurrency-Agent-Skill |
| Commit | `0d472de78225d2875283c35eaca1c060c493bdb3` |
| License | MIT |
| Source paths | `swift-concurrency/SKILL.md`; `swift-concurrency/references/{actors,sendable,tasks,testing,threading}.md` |
| Focus path | `.agents/skills/focus-concurrency/SKILL.md` |

Copyright (c) 2026 Antoine van der Lee

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### focus-testing

| Field | Value |
|---|---|
| Classification | adapted |
| Upstream | https://github.com/twostraws/Swift-Testing-Agent-Skill |
| Commit | `2d6bba14a3c8bf3694f218b92fffe617c41ae43e` |
| License | MIT |
| Source paths | `swift-testing-pro/skills/swift-testing-pro/SKILL.md`; `swift-testing-pro/references/{core-rules,writing-better-tests,async-tests}.md` |
| Focus path | `.agents/skills/focus-testing/SKILL.md` |

Copyright (c) 2026 Paul Hudson.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### release-focus

| Field | Value |
|---|---|
| Classification | Focus-authored (original); pattern/inspiration from public docs and CodexBar workflow shape |
| Upstream | Focus-authored |
| License | N/A (original Focus text) |
| Focus path | `.agents/skills/release-focus/SKILL.md` |

No third-party skill text is included. CodexBar and Apple/Sparkle documentation
are cited as inspiration only; do not imply copied authorship.

## Pattern / inspiration only (not copied)

- CodexBar (`ecadcb1df43b8ca029e75b6311f491c0b15d45e6`, MIT) — shipping discipline patterns
- archive-Justsayit (`58b6b1a7ef08f46981dbcfeea041d0539a85c134`, MIT) — ownership/architecture patterns

Neither is vendored. Do not imply copied authorship.
