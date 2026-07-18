---
summary: "focus CLI commands, JSON/exit contract, Unix-socket IPC security, and install story."
read_when:
  - "Adding or changing a CLI command or output format"
  - "Working on FocusControl framing, sockets, or peer checks"
  - "Implementing Install/Repair Command Line Tool"
---

# CLI and IPC

The `focus` CLI talks to the running macOS app over a per-user Unix-domain
socket using versioned length-prefixed JSON. Trust boundary is the logged-in
user (same UID), not a particular signed process.

## Commands (planned)

Status, start, pause, resume, skip, snooze, and version/help surfaces are defined
in `PLAN.md` §8. Human stdout/stderr and stable JSON (`--json`) share one
protocol; exit codes are part of the contract.

## Socket rules (summary)

- App-owned `SOCK_STREAM` endpoint; one request per connection.
- Flat filename `com.macieksitkowski.focus.macos.control.sock` under the
  Darwin user temp directory resolver.
- Four-byte big-endian size prefix, UTF-8 JSON, 64 KiB caps.
- Darwin peer check via `getpeereid`; Linux tests use an injected path fixture.
- If cryptographic proof of the signed CLI is later required, migrate to signed
  XPC rather than bolting auth onto the socket (ADR 0002).

## Install story

Xcode embeds `focus` at `Focus.app/Contents/MacOS/focus`. “Install Command Line
Tool…” creates a user-owned symlink (prefer `~/.local/bin/focus`); it never
copies a second versioned binary and never requires root.
