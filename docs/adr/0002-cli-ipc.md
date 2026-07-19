---
summary: "ADR: app-owned Unix-domain socket for CLI IPC; migrate to signed XPC only if process provenance is required."
read_when:
  - "Changing FocusControl transport or auth assumptions"
  - "Considering XPC, HTTP loopback, or file-polling control"
  - "Hardening peer identity beyond same-UID checks"
---

# ADR 0002 — CLI IPC

## Status

Accepted.

## Decision

Use an app-owned per-user Unix-domain socket with strict path, peer, framing,
and timeout rules. The trust boundary is the logged-in user (same UID).

## Consequences

- Protocol and much of the integration testing stay portable (Linux fixture).
- Darwin adds `getpeereid` and path ownership checks.
- If Focus later needs cryptographic proof that the caller is the signed Focus
  CLI, migrate to signed XPC — do not bolt ad hoc auth onto the socket.

## Rejected

- Loopback HTTP / Network.framework (ports, weak local identity).
- `CFMessagePort` / distributed notifications (wrong reliability model).
- Defaults/file polling (races and stale state).
- XPC as the v1 default (extra Apple-only lifecycle surface before needed).
