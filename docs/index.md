---
summary: "Map of Focus contributing docs and when to open each page."
read_when:
  - "Orienting to the docs tree"
  - "Deciding which doc owns a topic before editing"
---

# Docs index

Contributing documentation for this repository. Start with
[writing documentation](./writing-documentation.md) when you edit docs, skills,
or `AGENTS.md`.

| Page | Purpose |
|---|---|
| [Writing documentation](./writing-documentation.md) | Principles, frontmatter, gardening |
| [Repository layout](./layout.md) | Directories, portable vs Apple boundary |
| [Testing](./testing.md) | SwiftPM lanes, Mac CI, manual limits |
| [Releasing (macOS)](./release-macos.md) | Continuous Developer ID + Sparkle deploy |
| [Releasing (iOS)](./release-ios.md) | Continuous TestFlight internal deploy |
| [Sparkle updates](./sparkle.md) | Keys, feed URL, idle relaunch |
| [ADR 0001 — Project generation](./adr/0001-project-generation.md) | Pinned XcodeGen decision |

Run `make docs-list` to validate frontmatter and see each page’s `read_when`
hints. Keep commands in `AGENTS.md` and the `Makefile`; put rationale on the
owning page above.
