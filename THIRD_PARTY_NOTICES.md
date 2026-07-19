# Third-party notices

This file records licenses and provenance for third-party code that Focus
distributes or materially adapts. Use these labels consistently:

| Classification | Meaning | Obligation |
|---|---|---|
| copied | Verbatim code/text | Preserve required headers and license notice; record exact path and SHA |
| adapted | Substantial source-derived rewrite | Record upstream URL, exact SHA/source paths, and the required MIT notice here |
| pattern/inspiration | Independently written implementation of a general idea/workflow | Cite in design docs when useful; do not imply copied authorship |

CodexBar and Justsayit remain MIT pattern references unless implementation later
copies material. LookAway contributes only a public workflow shape; never copy
its words, branding, assets, screenshots, or visual design. XcodeGen is a
development tool and Sparkle is a distributed dependency; distinguish those
notice categories. Never copy material without a verified compatible license.

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

## Adapted agent skills (Dimillian/Skills)

The skills below are adapted from Dimillian/Skills, not verbatim copies:
broad, reusable modern SwiftUI/concurrency patterns are retained; unsafe,
stale, invalid, or source-specific guidance was corrected or removed; and
Codex-only metadata (`agents/openai.yaml`) was deleted.

| Field | Value |
|---|---|
| Classification | adapted |
| Upstream | https://github.com/Dimillian/Skills |
| Commit | `05ba982bfeb0d77d3c97d4542b0ee15034d05f84` |
| License | MIT |

| Source directory | Focus path |
|---|---|
| `swiftui-ui-patterns/` | `.agents/skills/swiftui-ui-patterns/` |
| `swiftui-view-refactor/` | `.agents/skills/swiftui-view-refactor/` |
| `swiftui-performance-audit/` | `.agents/skills/swiftui-performance-audit/` |
| `swift-concurrency-expert/` | `.agents/skills/swift-concurrency-expert/` |
| `swiftui-liquid-glass/` | `.agents/skills/swiftui-liquid-glass/` |

MIT License

Copyright (c) 2026 Thomas Ricouard

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Adapted agent skill (Swift-Testing-Agent-Skill)

The skill below substantially adapts, rather than verbatim-copies, its source.

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
