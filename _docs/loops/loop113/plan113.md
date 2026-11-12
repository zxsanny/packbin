# Autodev Loop Plan — Loop 113

loop: 113
kind: product
confirmed: true
branch: dev
ship: false

Feature: epic AZ-4209, "a repeat must be the last thing a packet reads" (owner decision 2026-11-12, loop 112: refuse at build). A `repeat` has no count on the wire, so whatever a scheme writes after it is read as more rounds: every package packs bytes its own unpack refuses, and two repeats in a row read back as other values with no error (`_docs/06_metrics/repeat-followed-by-field_2026-11-12.md`). This loop adds the scheme-build check of the contract `_docs/02_document/contracts/library/repeat-last.md` to all nine packages, the shared hostile cases and the README text. No packet changes.

Tasks (29 points, `todo/`, claimed for this loop): AZ-4210 (shared cases and README, 2), AZ-4211 TypeScript (3), AZ-4212 C# (3), AZ-4213 Python (2), AZ-4214 Java (3), AZ-4215 Go (2), AZ-4216 Swift (2), AZ-4217 Dart (2), AZ-4218 Rust (5), AZ-4219 C++ (5).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in loop 112: ten specs in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | done in loop 112 (`feature-description.md`, rows in `_dependencies_table.md`) |
| implement | 10 | Implement | yes | AZ-4210 first, then the nine package tasks (disjoint directories) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total `scripts/loop-tests.sh` run: nine suites, ring, ARM rows, publish gate (`README.md` is packed) |
| test-spec-sync | 12 | Test-Spec Sync | yes | 13 new shared hostile cases and a new scheme rule change the blackbox specification |
| update-docs | 13 | Update Docs | yes | a public behaviour change in nine packages; the contract goes from "not implemented" to implemented; component docs, traceability rows |
| security | 14 | Security Audit | yes | `lite` on the real diff (scheme build only; pack and unpack of untrusted bytes do not change); escalates to full on its triggers |
| performance | 15 | Performance Test | no | the NFR is "nothing per pack or unpack"; the speed parts of the suites in step 11 hold it |
| deploy | 16 | Deploy | no | no tag; the change travels with the next release |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | yes | due by loop 113 (last: loop 108); two 5-point tasks |
| local-deploy | — | Local deploy + open site | yes | no site (library): the smoke script |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke113.md` and `smoke113.sh`, agent run (owner rule 2026-10-12) |

## Needs

| need | for | verified by | status |
|------|-----|-------------|--------|
| Docker with the suite images (`gcc:16`, `golang:1.27`, `swift:6.3.3`, `dart:3.13.7`, `rust:1.98`, `node:24`, `python:3.14`, dotnet SDK 10, temurin 26, `packbin-embedded:local`) | implement (Go, Rust, C++ workers), run-tests | `docker info`, `docker images` 2026-11-12 | ok |
| outbound network from containers (the compose `go` service has no module cache) | run-tests: `go` | `docker run golang:1.27 curl proxy.golang.org` gave 200 | ok |
| `espressif/idf:v5.3.2` image | AZ-4219 AC-6 (`cpp/embedded/run.sh host esp core`) | `docker images espressif/idf` | ok (was missing; pulled 2026-11-12, 5.04 GB) |
| Python 3.13 with PyYAML, `PACKBIN_CXX_SYSROOT`, `RUSTUP_TOOLCHAIN=1.98` (thumb targets installed) | run-tests: `scaffold`, `ring`, `publish-gate`; AZ-4218 AC-5 | `python3.13 -c 'import yaml'`, `rustup +1.98 target list --installed` | ok |
| host load below about 6 and the Mac kept awake for the total run | run-tests, smoke | `uptime`, `sysctl vm.swapusage` (13:51: load 6.1, swap 6.8 of 8 GB used) | re-check before step 11 |
| `gh` logged in | CI read after the close push | `gh auth status` | ok |
| Jira | implement Steps 5 and 12, reconciliation | read of AZ-4205 to AZ-4219 on 2026-11-12 | ok |
| owner decision: Java and C++ refuse a repeat inside a round at build (R9) | AZ-4214 AC-5, AZ-4219 AC-5 | `_docs/OPERATOR_TODO.md` D1 | applied 2026-11-12 (agent default of loop 112, reversible until the next tag; the owner can overturn it) |

## Implementation

### Files that change
- AZ-4210: `fixtures/hostile/cases.txt`, `fixtures/hostile/README.md`, the root `README.md`, the Producer and Consumer lines of the contract, the case count in `module-layout.md`.
- AZ-4211 to AZ-4219: each package's scheme-build check (beside its empty-round-body rule), its tests, its hostile loader, its own tests and examples that used a refused scheme, and its probe folder `scripts/probes/repeat-followed-by-field/<package>/` (TypeScript also `rule-count/`). Rust and C++: the device pins if they move.

### Order of work
1. AZ-4210 by one worker (the cases every loader replays); the parent reads its diff before the packages start.
2. The nine package tasks by a pool of at most four workers: TypeScript, Rust, C#, Java first; Python, Go, Swift, Dart as slots free; C++ last and only after the Rust worker has finished (both device rows write under `cpp/build/embedded`).
3. One commit per finished group (the commits stay local; between AZ-4210 and a package's own task that package's suite is red on the new case ids, which the spec names as its Risk 1).
4. One total review (`/code-review`), the fixes, feature assessment.
5. One total test run (step 11), test-spec sync, docs, security, retrospective, smoke, close.

### Proof
Each package: the refusal texts compared whole for R1 to R9, K1 to K5 with the contract's packets, the shared hostile cases, the probe's build column, the package suite as CI runs it. The loop: `scripts/loop-tests.sh` (0 bytes differ in fixtures, golden vectors and ring handoffs), the embedded rows with their pins.

### Risks
- A package's own tests rely on a refused scheme (TypeScript: 4 in 3 files; the other eight not counted): each worker counts and rewrites them; the count goes into the batch report.
- The heap-free Rust check and a run-time C++ scheme cost flash: above 256 B of flash or 64 B of stack on a pin the task stops and the owner decides.
- Host load: four workers each run a suite; timing bounds are load-aware, and the total run waits for a quiet host.

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | EXTEND | AZ-4232_repeat_last_group_in_round_cases | _docs/loops/loop113/assessment113.md |
