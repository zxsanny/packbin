---
loop: 88
branch: dev
---

# Release notes for packbin 0.4.0 (loop 88)

Source: `_docs/loops/loop87/handoff88.md` (owner decisions). The owner chose the 0.4.0 release notes as the work of loop 88 (2026-10-30). Tracker: AZ-3435.

## Problem

The last GitHub release is 0.3.0 (tag `v0.3.0`, 2026-10-16). `dev` is 330 commits past it. The notes of the next release must say what is new and what breaks, in the format of the 0.3.0 release body (summary, New, Build and CI, Install table). ADR-009 and the loop 74 spec promise that the next release notes say the stream session (`PackSession`) is removed.

## Change location

No UI. Verbal: a new document in the repository, `_docs/04_deploy/release_notes_0.4.0.md`, whose body can be pasted as the GitHub release body. No product code changes; no tag, no release, no registry upload (owner-run).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Every claim in the notes must be read from HEAD or a loop record, not remembered (AGENT_GOTCHAS: figures are read in the same loop) | AGENT_GOTCHAS | open | Medium |
| The version number 0.4.0 is the owner's word; the notes do not tag or publish | owner, 2026-10-30 | accepted-risk | Low |
