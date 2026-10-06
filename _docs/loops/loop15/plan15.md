# Autodev Loop Plan — Loop 15

loop: 15
kind: product
confirmed: true
branch:
ship: false

Loop works on `dev` (no worktree: this chat is the launcher, as loops 11 to 14). Scope (owner request 2026-10-06, "Fix F10, F12, F13"; F10 option A chosen by the owner): the three open Medium security findings of `_docs/05_security/security_report.md`, epic AZ-2069. Problem and decisions D1 to D7: `_docs/02_task_plans/unpack-limits-and-ci-hardening/problem.md`.

Tasks (23 points): AZ-2214 (F12 pin the credentialed job, 3), AZ-2215 (F13 read-only build containers, 5), AZ-2216 / AZ-2217 / AZ-2218 / AZ-2219 (F10 round limits in C#, TypeScript, Java, Rust, 3 each), AZ-2220 (F10 hostile case, README, docs, closes F11, 3).

Owner decisions this loop: F10 option A (a limit on unpack); limits live on the scheme (D1, an agent default the owner can change); limits are checked when a round starts (D5, changed from eager to lazy after the spec pass because eager broke three existing assertions); AZ-2215 sized at 5 points and the golden-gate containers are in scope. Open Medium concerns carried into the loop, not decided here: Linux-only semantics of the read-only mount are proven only by the CI `scaffold` job (AZ-2215); transitive pip dependencies still float (AZ-2214); host-side steps can still write earlier artifacts (AZ-2215).

The v0.2.2 tag is not part of the loop: after the loop, with CI green on the final commit and one explicit owner go with the exact commit.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs written in P0 (`problem.md`, `/new-task` equivalent by the spec pass) |
| decompose-feature | 9.5 | Decompose Feature | no | done: seven specs of 3 to 5 points exist |
| implement | 10 | Implement | yes | batch 1: AZ-2214, AZ-2216, AZ-2217, AZ-2218 (four workers, disjoint paths: `.github/` + `cpp/embedded/examples.sh`, `csharp/`, `typescript/`, `java/`); batch 2: AZ-2215 and AZ-2219 (`.github/` + compose, `rust/`); batch 3: AZ-2220 (needs the four packages) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | project ACs unchanged; AZ-2220 updates the hostile count in `blackbox-tests.md` |
| update-docs | 13 | Update Docs | yes | public API of four packages gains limits; CI docs, pins and the read-only mount change |
| security | 14 | Security Audit | yes | closes F10, F12, F13; credentialed job and container mounts change |
| performance | 15 | Performance Test | no | the limits bound memory; measured inside AZ-2216 to AZ-2219 |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | the tag is a separate owner go after the loop |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 23 points across 7 tasks and 6 packages |
| local-deploy | — | Local deploy + open site | yes | always at close; no site: the build-only publish run and the gate tests are the local run |
| smoke | — | Smoke acceptance | yes | always at close; one-paste script in `smoke15.md` |

Only rows with `include: yes` are executed (plus close steps).

## Implementation

Optional. Created or patched when a batch diverges (`protocols/plan-diff-sync.md`).

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | CLARIFY (Q1 slot count per package, Q2 digest between check and upload); the owner answered A and A on 2026-10-06, so COMPLETE | none | _docs/loops/loop15/assessment15.md |
