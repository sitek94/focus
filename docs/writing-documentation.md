---
summary: "How to write and garden Focus docs, AGENTS.md, and agent skills."
read_when:
  - "Adding, rewriting, or deleting a docs/ page"
  - "Editing AGENTS.md prose or .agents/skills descriptions"
  - "Reviewing a PR that changes contributor-facing text"
---

# Writing documentation

Audience: people and agents who contribute to this repository.

Scope: how we write and maintain `docs/`, `AGENTS.md`, and `.agents/skills/*`.
Non-scope: end-user product marketing and placeholder feature behavior.

## Principles

**Describe how things work.** Write in the present tense. Avoid changelog-style
phrases (“now we…”, “we no longer…”, “previously…”) in docs, `AGENTS.md`,
skills, and UI strings; those belong in commit messages or release notes.
Describe the system as it works today (“Deploy macOS publishes…”, “The assert
rejects…”) instead of narrating a rollout (“We now publish…”, “We no longer
accept…”).

**Exceptions.** Migration and rotation procedures may use ordered steps across
deploy phases. Outside those procedures, still describe the current design in
plain language. Quoted validation errors and runtime messages should match what
the product or script returns.

**Stay lightweight but valuable.** Prefer small, accurate pages over large stale
ones. Garden docs when behavior changes: update or delete sections in the same
change as the code when possible. Remove duplication by linking out instead of
copying paragraphs.

**Keep agent instructions and skill descriptions tight.** `AGENTS.md` and
`.agents/skills/*` should give what is needed before acting: workflows,
constraints, and copy-pasteable commands. Long policy lists and exhaustive
field semantics belong in `docs/` pages or in command output, not in the
instruction string.

**Put post-call detail in the call result.** Anything needed only after a
command runs (full docs index, ranked failures, approval URLs, error bodies)
should come from that command (`make docs-list`, `make release-check`, workflow
logs), not from static instruction text. Static text should not repeat large
chunks of what the next response already shows.

**Avoid overlap with generated surfaces.** If a host, workflow, or script
already lists schemas, flags, or resources, do not restate those tables
verbatim in docs; link to the workflow, script, or owning page.

## Clarity

Follow the habits from
[Google Technical Writing](https://developers.google.com/tech-writing):

- State audience, scope, and non-scope near the top of each page.
- Front-load the answer; put background later.
- Prefer active voice and short sentences.
- Use second person for procedures (“Run…”, “Set…”).
- Use one term per concept; define unfamiliar terms once.
- Prefer numbered lists for steps and tables for reference data.
- Use bold sparingly—for a short lead-in or warning label, not whole sentences.

## Frontmatter

Every `docs/**/*.md` page starts with YAML frontmatter:

```yaml
---
summary: "One-line description for make docs-list"
read_when:
  - "Concrete trigger when someone should open this page"
---
```

`make docs-list` fails if `summary` or `read_when` is missing or empty. Keep
`read_when` triggers concrete so agents can match them to the current task.

## Related

- [Docs index](./index.md)
- [Repository layout](./layout.md)
- Root [`AGENTS.md`](../AGENTS.md) for the command index
