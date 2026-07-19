---
summary: "focus CLI commands, JSON/exit contract, Unix-socket IPC security, and install story."
read_when:
  - "Adding or changing a CLI command or output format"
  - "Working on FocusControl framing, sockets, or peer checks"
  - "Implementing Install/Repair Command Line Tool"
---

# CLI and IPC

The `focus` CLI talks to the running macOS app over a per-user Unix-domain
socket using versioned length-prefixed JSON. The trust boundary is the
logged-in user (same UID), not a particular signed process.

## Commands

Human-readable output is the default. `--json` is the only machine contract.
`focus --version` is a flag, not a subcommand.

| Command | Auto-launch | Semantics |
|---|---:|---|
| `focus status [--json]` | no | Read current app/runtime state; app absence is exit 3 |
| `focus start [--json]` | yes | Launch the sibling app if needed, bootstrap/ensure the timer, return authoritative state |
| `focus pause [--json]` | no | Pause; already paused is success with `performed: false` |
| `focus resume [--json]` | no | Resume; already active is success with `performed: false` |
| `focus skip [--json]` | no | Skip a warning/break obligation; focus phase rejects with exit 6 |
| `focus trigger-break [--json]` | no | Begin a full break immediately; equivalent to warning UI “Start now” |
| `focus snooze [--json]` | no | Snooze break due time by 60 seconds (same as warning “Snooze 1 minute”) |

Every successful mutation includes the authoritative post-commit state in the
same response. Major protocol changes are breaking; minor changes may add
fields. Both sides ignore unknown additive fields. JSON goes to stdout with no
incidental logs; human errors go to stderr.

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

## Socket rules

- App-owned `SOCK_STREAM` endpoint; one request per connection.
- Flat filename `com.macieksitkowski.focus.macos.control.sock` under the
  Darwin user temp directory resolver (`_CS_DARWIN_USER_TEMP_DIR`; use
  `NSTemporaryDirectory()` only when it resolves to a private non-`/tmp`
  directory).
- Four-byte big-endian size prefix, UTF-8 JSON, 64 KiB caps.
- Darwin peer check via `getpeereid` (current UID); Linux tests use an injected
  path fixture. Release builds do not honor arbitrary environment path overrides.
- Connection attempt 250 ms; normal command deadline 1.5 s; cold-start deadline
  8 s.
- Only the server may unlink a stale same-owner socket after verifying its type.
- If cryptographic proof of the signed CLI is later required, migrate to signed
  XPC rather than bolting auth onto the socket (ADR 0002).

## Install

Xcode embeds `focus` at `Focus.app/Contents/MacOS/focus`. “Install Command Line
Tool…” creates a user-owned symlink (prefer `~/.local/bin/focus`); it never
copies a second versioned binary and never requires root. Disable installation
from an App Translocation/DMG path and ask the user to move Focus to
`/Applications` first. “Repair Command Line Tool…” fixes a moved app.
