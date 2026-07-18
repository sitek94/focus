# Skill provenance index

Compact index of Focus-owned skills. Full MIT notices and pins live in
`THIRD_PARTY_NOTICES.md`. `make check-skills` validates this file against that
notice list and each skill’s `SKILL.md` header.

| Skill | Upstream | Commit | License | Disposition |
|---|---|---|---|---|
| `focus-swiftui` | https://github.com/AvdLee/SwiftUI-Agent-Skill | `f06d1437a3fbec7df6cdce93f77004e5409b31ee` | MIT | adapted |
| `focus-concurrency` | https://github.com/AvdLee/Swift-Concurrency-Agent-Skill | `0d472de78225d2875283c35eaca1c060c493bdb3` | MIT | adapted |
| `focus-testing` | https://github.com/twostraws/Swift-Testing-Agent-Skill | `2d6bba14a3c8bf3694f218b92fffe617c41ae43e` | MIT | adapted |
| `release-focus` | Focus-authored | — | N/A | original |

Trees live under `.agents/skills/<name>/SKILL.md`. Do not vendor upstream
collections. Never adapt PolyForm (dpearson) material.
