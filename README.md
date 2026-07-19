# Focus

Focus is a native macOS menu-bar timer with fixed focus / warning / break /
snooze cycles, an in-bundle `focus` CLI, and a minimal iOS shell. It is not a
stats dashboard, blocker, or configurable pomodoro suite.

## Requirements

- Swift 6.3.3+ (Swift 6 language mode)
- macOS 26+ / iOS 26+ for Apple app targets (Xcode 26.6)
- Linux Ubuntu 24.04 can build and test the portable SwiftPM packages
  (`libsqlite3-dev` required for `FocusPersistence`)

## Quick commands

| Command | Purpose |
|---|---|
| `make docs-list` | Validate and list docs frontmatter |
| `make format` / `make lint` | Format or lint Swift sources |
| `make generate-project` | Generate ignored `Focus.xcodeproj` via pinned XcodeGen |
| `make test-linux` | Portable SwiftPM tests |
| `make verify-linux` | Docs, lint, skills, build, portable tests |
| `make build-macos` / `make build-ios` | Apple builds (macOS host + Xcode 26.6) |

See `AGENTS.md` for the full command index and proof boundary. Run
`make docs-list` before architecture, testing, or release work.

## Layout

- `Sources/` — portable libraries (`FocusSession`, `FocusPersistence`, `FocusControl`)
- `CLI/FocusCLI` — `focus` executable sources
- `Apps/Focus/` — macOS / iOS UI shells (Apple frameworks only here)
- `project.yml` + `tools/projectgen/` — XcodeGen pin; generated project is gitignored
- `docs/` — architecture, testing, release, and ADRs

## License

MIT. See `LICENSE`.
