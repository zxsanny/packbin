# Autodev loop record - loop 91

loop: 91
branch: dev
plan_artifact: none (short loop on launcher: docs only, 1 point)
tasks_shipped: []
decisions:
  - owner (2026-10-30): "write steps" for F44; the owner applies the ruleset, the agent applies nothing
  - agent: ruleset on `refs/tags/v*` with `update`, `deletion`, `non_fast_forward`; no creation rule, no bypass actor; `go/v*` stays outside because `publish-go.sh` creates `go/v<version>` with the workflow token and no script touches a `v*` tag
  - agent: no test-tag advice in the doc (any `v*` push starts the publish run); the check is the public rulesets listing
  - agent: no Jira ticket (docs only)
measurements:
  - the JSON of the `gh api` command parsed with `json.loads`; the command itself was not run (needs admin) and the field names follow the GitHub rulesets API as recalled, not a fresh read of its docs
  - `git diff HEAD~1 --stat` before close: 1 docs file
review: "no code review (docs only)"
retro: none (next retro due after loop 94)
leftovers:
  - owner: apply the F44 ruleset and read the rulesets listing back; tag `v0.4.0`; close the epic AZ-2750; U24; the M4F row; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring
  - not run: any test suite (no source changed)
smoke: PASS (owner, 2026-10-30; no UI, no local deploy)
smoke_artifact: _docs/loops/loop91/smoke91.md
loop_end_merge: main
