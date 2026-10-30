---
loop: 90
branch: dev
---
# CS-D5: freeze the compact text tables for 0.4.0

Owner decision, 2026-10-30: the compact text tables (`fixtures/text/tables.json`) stay as trained on Tatoeba sentences. The owner has no real messages yet and will gather statistics from real usage first; a retrain after a tag is another wire break for every string field (ADR-006).

## Change

Docs only, two files: the publisher note in `_docs/04_deploy/release_notes_0.4.0.md` and the CS-D5 row in `_docs/02_task_plans/compact-strings/scenarios.md`. No tables, code or format change.

## Out of scope

F44 (the `v*` tag ruleset: the owner applies it), the `v0.4.0` tag, the epic AZ-2750.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Tables come from literary sentences, not real traffic | owner 2026-10-30: accepted for 0.4.0 | accepted-risk | Medium |
