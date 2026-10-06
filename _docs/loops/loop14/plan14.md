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

Divergences from the plan, patched in the commit that made them (`protocols/plan-diff-sync.md`):

- AZ-2096 grew from the expected one-script split into two phases over seven scripts (`publish-build.sh`, `publish-upload.sh`, `publish-sign.sh`, `publish-check.py` new; `publish-registries.sh`, `publish-inside.sh`, `publish-embedded.sh` rewritten) plus a sibling test file; uploads now run on the runner host.
- AZ-2097 added `publish-query.sh`, `publish-published.py` and `publish-rerun.test.sh`; the `concurrency` group on `publish.yml` is workflow-level.
- Smoke-time fix (commit `3a6b5f2`, under AZ-2096): `PACKBIN_BUILD_ONLY=1` now checks `python3`, `gpg` and `git` up front and writes the `dry-run` marker before the first build.
- Run Tests used two extra manual Pico builds (arm64 GCC 9.3.1 and amd64 GCC 9.2.1) outside the stage script; the owner approved the toolchain downloads into `.cache/embedded`.

### Files that change
### Order of work
### Proof
### Risks

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | CLARIFY (3 gap-unclear: token lifetime, PlatformIO owner lookup, Central shape); the owner typed `continue` after declining the question prompt, recorded as accepted with the recommended option A for all three | none | _docs/loops/loop14/assessment14.md |
