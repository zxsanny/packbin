# Loop 90 smoke — proposed checks

LOCAL_URL: none (docs only, no app)
Branch: dev

## Perform these checks (read the two files)

- [ ] `_docs/04_deploy/release_notes_0.4.0.md`, publisher section: CS-D5 reads "decided: the tables stay (owner, 2026-10-30)" and no longer asks to decide before the tag.
- [ ] `_docs/02_task_plans/compact-strings/scenarios.md`, row CS-D5: status `frozen`, with the 2026-10-30 decision.
- [ ] `git diff --stat HEAD~1` shows only those two files plus this loop's docs; no table, code or format file changed.
- [ ] F44 and the `v0.4.0` tag are still listed as owner items (not touched).
