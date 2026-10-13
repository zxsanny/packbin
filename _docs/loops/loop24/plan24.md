# Autodev Loop Plan — Loop 24

loop: 24
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: `_docs/loops/loop24/handoff24.md` (decision batch U24 B, U25 A, U26 A, Low-1 A; owner order: **Go first**, the short wave moves to loop 25); problem: `_docs/02_task_plans/go-package/` (G-1 to G-6, GO-1 to GO-16, scenarios S1 to S12, fit decisions 1 to 5). Owner preferences unchanged (memory `one-total-review-and-test`, `noninteractive-subagent-commands`, `long-runs-visible-status`, `decision-batches-accept-recommended`): workers run only their own suite; no per-batch review or Docker run of the six; one total review and one step-11 run at the end (check `uptime` and swap first); no chained feature-assess rounds; shell-hygiene paragraph, index-write ban and "no formatter on files you do not own" in every worker prompt. Go runs only in `golang:1.27` (pulled, go1.27.2).

## Scope

Specs claimed (`loop: 24`): AZ-2440 to AZ-2451 (12 specs, 43 points, epic AZ-2222). AZ-2068 stays out.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` + `/new-task` ran at intake (13 points → decompose) |
| decompose-feature | 9.5 | Decompose Feature | no | done at intake: `_dependencies_table.md` loop 24 block |
| implement | 10 | Implement | yes | four waves, see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only; open rows go to the loop 25 handoff |
| run-tests | 11 | Run Tests | yes | one total run: seven suites, hostile, golden, ring (with Go), publish gate tests, embedded stages |
| test-spec-sync | 12 | Test-Spec Sync | yes | new component: traceability rows for GO-1 to GO-16 |
| update-docs | 13 | Update Docs | yes | new component and public API: module-layout, components/07, architecture, ADR index |
| security | 14 | Security Audit | yes | a new untrusted-input parser and a tag-pushing publish step |
| performance | 15 | Performance Test | no | AC-10 is a suite test (AZ-2440 AC-7); no other perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | a tag needs the owner's go with the exact commit |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 43 points; new language |
| local-deploy | — | Local deploy + open site | yes | no site: suites, ring and gate tests are the local run |
| smoke | — | Smoke acceptance | yes | one-paste script in `smoke24.md`, run by the agent |

## Implementation

### Files that change

`go/**` has one writer at a time (AZ-2440 → AZ-2441 → AZ-2442 → AZ-2443 → AZ-2444 → AZ-2445 → AZ-2446 → AZ-2447 → AZ-2451's `go/example_test.go`). Beside the chain: AZ-2448 (run-suite, compose files, `test.yml` scaffold job, report-row/run-suite tests), AZ-2449 (`drivers/handoff-go/`, `language-pair.sh`, ring-toolchains, ring-wiring test, `test.yml` ring job), AZ-2450 (ADR-004, publish files, new `publish-go.test.sh`), AZ-2446 also `fixtures/hostile/`. Parent-only: `_docs/**`, README (until AZ-2451), tracker, commits.

### Order of work

1. **Wave 1**: AZ-2440 (Go core) alone.
2. **Wave 2**: `go/` chain AZ-2441 → AZ-2442 → AZ-2443 → AZ-2444 → AZ-2445; beside it AZ-2448.
3. **Wave 3**: `go/` chain AZ-2446 → AZ-2447; beside it AZ-2449.
4. **Wave 4**: AZ-2450, then AZ-2451.
5. **Parent, once**: total review, feature-assess, step-11 run, steps 12–14 and 17, smoke, close, push `dev`, `loop_end_merge`, watch CI.

### Proof

Go suite green in `golang:1.27` (`go test -race`, vet, gofmt, fuzz 60 s); the ring with Go; the publish gate tests with seven languages; the step-11 run of all seven.

### Risks

Size (43 points vs the epic's 26); Go/TypeScript disagreements found while porting (reported to the parent, owner decides); ring CI time about doubles; publish tag push is untested against a real tag this loop.
