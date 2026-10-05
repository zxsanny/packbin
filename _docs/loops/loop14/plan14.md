# Autodev Loop Plan — Loop 14

loop: 14
kind: product
confirmed: true
branch:
ship: false

Loop works on `dev` (no worktree: this chat stays on the launcher, as loops 11 to 13). Scope (owner choice, group A, 2026-10-06): the publish pipeline, epic AZ-2069. AZ-2094 is a stated prerequisite of AZ-2096 and was included at the owner's confirmation. Order: AZ-2094 (Java `--release 17`, 2 pts), AZ-2095 (publish gated on tests, 2), AZ-2096 (build before upload, 3), AZ-2097 (re-run and registry policy, 3). 10 points.

Owner decisions this loop (2026-10-06): the structure check parses workflow YAML with Ruby stdlib `yaml` (AZ-2095); an optional target whose upload fails with its credential present fails the run (AZ-2097 flagged concern).

No Critical `open` concern in any of the four specs. Open Medium concerns carried, not decided here: publish duration grows by the full test time (AZ-2095), unconfirmed `compote` / `pio` prebuilt-upload and re-upload behavior (AZ-2096, AZ-2097; implementer checks tool docs at task start), Maven Central freshness query (AZ-2097).

The v0.2.2 tag (plan13 `## Release`) stays pending: not part of this loop, no tag, no push of a tag. Revisit after AZ-2095.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs already in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | four specs of 2 to 3 points exist |
| implement | 10 | Implement | yes | AZ-2094, AZ-2095, AZ-2096, AZ-2097; one batch each, serial (all four write `publish-gate.test.sh`; 2096 and 2097 also write the same publish scripts) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | project ACs unchanged |
| update-docs | 13 | Update Docs | yes | publish order, required/optional registries, Java 17 / Android API 26 touch deployment_procedures (both copies), system-flows F3, environment.md, packages.md, README Java section; no other loop in flight |
| security | 14 | Security Audit | yes | workflow permissions, credentials and registry upload paths change |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | no deploy; v0.2.2 stays pending |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 10 points across 4 tasks |
| local-deploy | — | Local deploy + open site | yes | always at close; no site: the build-only publish run and `publish-gate.test.sh` are the local run |
| smoke | — | Smoke acceptance | yes | always at close; checklist in `smoke14.md` |

Only rows with `include: yes` are executed (plus close steps).

## Implementation

Optional. Created or patched when a batch diverges (`protocols/plan-diff-sync.md`).

## Assessment rounds

None yet.
