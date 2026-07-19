# Focus

Focus is a native macOS menu-bar app skeleton with an in-bundle `focus` CLI, a
minimal iOS shell, and continuous deploy wiring (Developer ID + Sparkle on
macOS; internal TestFlight on iOS). Portable libraries build and test on Linux.

## Requirements

- Pinned Swift (`.swift-version`; Swift 6 language mode)
- macOS 26+ / iOS 26+ for Apple app targets (pinned Xcode in `.xcode-version`)
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
| `make build-macos` / `make build-ios` | Apple builds (macOS host + pinned Xcode) |

See [`AGENTS.md`](./AGENTS.md) for the full command index and proof boundary.
Contributing docs: [`docs/index.md`](./docs/index.md). Run `make docs-list`
before layout, testing, or release work.

## Layout

- `Sources/` — portable libraries (`FocusSession`, `FocusPersistence`, `FocusControl`)
- `CLI/FocusCLI` — `focus` executable sources
- `Apps/Focus/` — macOS / iOS UI shells (Apple frameworks only here)
- `project.yml` + `tools/projectgen/` — XcodeGen pin; generated project is gitignored
- `docs/` — contributing docs (writing, layout, testing, release, ADRs)

## License

MIT. See `LICENSE`.
