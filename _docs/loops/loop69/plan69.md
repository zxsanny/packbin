# Autodev Loop Plan — Loop 69

loop: 69
kind: product
confirmed: true
branch: dev
ship: false

Feature: frame mode, Rust first (umbrella AZ-3192, epic AZ-3199). Plan folder: `_docs/02_task_plans/rust-m33f-and-frame-mode/`. Tasks: AZ-3200 (4), AZ-3201 (3), AZ-3202 (4), AZ-3203 (5), AZ-3204 (3) = 19 points. The Rust Cortex-M33F row moved to loop 70 (owner, 2026-10-25).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` — never a plan row |
| decompose-feature | 9.5 | Decompose Feature | no | done at intake: 19 points handed to decompose, five tasks and epic AZ-3199 written |
| implement | 10 | Implement | yes | AZ-3200 + AZ-3201 first (disjoint), then AZ-3202, then AZ-3203, then AZ-3204 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total run per loop |
| test-spec-sync | 12 | Test-Spec Sync | yes | new ACs and scenarios (AC-F1..F4, S1..S12) |
| update-docs | 13 | Update Docs | yes | contract 2.0.0, Rust public API, component description |
| security | 14 | Security Audit | yes | authentication, keys, constant-time compare: security predicate |
| performance | 15 | Performance Test | no | no latency or throughput NFR; cost is bounded by block and compression counts (AZ-3203 AC-6) |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | no data-store change |
| retrospective | 17 | Retrospective | yes | task complexity 5 and 19 points in all |
| local-deploy | — | Local deploy + open site | yes | always at close (no UI: the loop smoke script) |
| smoke | — | Smoke acceptance | yes | always at close; agent runs the smoke script (owner rule 2026-10-12) |

Only rows with `include: yes` are executed (plus close steps).

## Implementation

Order: batch 1 = AZ-3200 (docs) and AZ-3201 (fixture, scripts, Rust test) in parallel on disjoint paths; batch 2 = AZ-3202; batch 3 = AZ-3203; batch 4 = AZ-3204. Parent keeps commits, tracker and review (`subagents.md`). One total review and one step 11 run per loop (owner preference).

### Files that change
- AZ-3200: `_docs/02_document/contracts/library/pack-session.md`, `_docs/02_document/adr/008_*.md`, `adr/README.md`, `_docs/00_problem/*`, `_docs/02_document/architecture.md`, README.
- AZ-3201: `fixtures/crypto/`, `scripts/crypto/`, one Rust test file, `scripts/loop-tests.sh` wiring.
- AZ-3202: `fixtures/frame/`, `scripts/frame/`.
- AZ-3203: `rust/src/nostd/` (frame module), `rust/src/session_core/`, `rust/Cargo.toml`, Rust tests.
- AZ-3204: `rust/embedded/`, Rust README, `_docs/02_document/components/04_rust_package/description.md`.

### Order of work
AZ-3200 and AZ-3201 → AZ-3202 → AZ-3203 → AZ-3204.

### Proof
E1 to E5 reproduce in Python (AZ-3202) and Rust (AZ-3203); embedded figures read from a run on HEAD (AGENT_GOTCHAS: no figure from a table).

### Risks
- The contract text may leave a byte open when an implementation is written from it: settle it in AZ-3200 first.
- `scripts/loop-tests.sh` fails its publish gate if the repo changes during the gate: no edits in that window.
- The full gate takes 6 to 10 minutes on a quiet host.

## Assessment rounds

None yet.
