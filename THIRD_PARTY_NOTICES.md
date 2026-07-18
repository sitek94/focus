# Third-party notices

This file records licenses and provenance for third-party code that Focus
distributes or materially adapts. Classifications follow `PLAN.md` §18:
`copied`, `adapted`, or `pattern/inspiration`.

## Distributed dependencies

### Sparkle

| Field | Value |
|---|---|
| Classification | Distributed macOS runtime dependency (not yet wired in SwiftPM shared package) |
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

When Sparkle is embedded, also retain upstream bundled-component notices from
that exact commit.

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

Placeholders until checkpoint 10 adapts skills under `.agents/skills/`. Each
adapted skill must record upstream URL, full SHA, source paths, license, and
copied-vs-adapted disposition. `make check-skills` validates
`.agents/skills/SOURCES.md` against this file.

### focus-swiftui (planned)

| Field | Value |
|---|---|
| Classification | adapted (planned) |
| Upstream | https://github.com/AvdLee/SwiftUI-Agent-Skill |
| Commit | `f06d1437a3fbec7df6cdce93f77004e5409b31ee` |
| License | MIT |

### focus-concurrency (planned)

| Field | Value |
|---|---|
| Classification | adapted (planned) |
| Upstream | https://github.com/AvdLee/Swift-Concurrency-Agent-Skill |
| Commit | `0d472de78225d2875283c35eaca1c060c493bdb3` |
| License | MIT |

### focus-testing (planned)

| Field | Value |
|---|---|
| Classification | adapted (planned) |
| Upstream | https://github.com/twostraws/Swift-Testing-Agent-Skill |
| Commit | `2d6bba14a3c8bf3694f218b92fffe617c41ae43e` |
| License | MIT |

### release-focus (planned)

| Field | Value |
|---|---|
| Classification | Focus-authored; pattern/inspiration from public docs and CodexBar workflow shape |
| License | N/A (original Focus text) |

## Pattern / inspiration only (not copied)

- CodexBar (`ecadcb1df43b8ca029e75b6311f491c0b15d45e6`, MIT) — shipping discipline patterns
- archive-Justsayit (`58b6b1a7ef08f46981dbcfeea041d0539a85c134`, MIT) — ownership/architecture patterns

Neither is vendored. Do not imply copied authorship.
