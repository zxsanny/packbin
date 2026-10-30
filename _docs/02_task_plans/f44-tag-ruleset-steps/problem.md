---
loop: 91
branch: dev
---
# F44: write the tag ruleset steps for the owner

Owner request, 2026-10-30: write the steps for F44 (a GitHub tag ruleset on `v*`). Only the owner can apply it (repository admin); the agent applies nothing.

## Change

Docs only: the F44 bullet in the publisher section of `_docs/04_deploy/release_notes_0.4.0.md` gets the exact ruleset settings, one `gh api` command, the check, and the two cautions (no bypass actor; `go/v*` is out of the pattern because the publish workflow creates it).

## Facts read on HEAD

- `publish.yml` triggers on tags `v*`; no workflow script creates, moves or deletes a `v*` tag.
- `publish-go.sh:65` pushes `go/v<version>` with the workflow token; `go/v0.4.0` does not match `refs/tags/v*`.
- The rulesets API returned `[]` for the repository on 2026-10-30 (public, owner type User, default branch `dev`).

## Out of scope

Applying the ruleset, the `v0.4.0` tag, `go/v*` protection.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The command was not run (needs admin); the JSON follows the GitHub rulesets API as recalled | owner runs it and reads the list back | open | Low |
