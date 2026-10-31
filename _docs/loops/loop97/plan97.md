# Autodev Loop Plan — Loop 97

loop: 97
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: `/problem` then `/new-task` wrote 8 points and handed off |
| decompose-feature | 9.5 | Decompose Feature | yes | done: 11 tasks AZ-3499 to AZ-3509, 39 points, in `todo/` |
| implement | 10 | Implement | yes | AZ-3499 first, then the eight packages in disjoint batches, then AZ-3508 (ring) and AZ-3509 (docs) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | each package suite, `check-vectors.sh`, the real ECC ring, C++ `gcc:16`, the Cortex-M33F rows |
| test-spec-sync | 12 | Test-Spec Sync | yes | new ECC scenarios (percentage) change the blackbox specification |
| update-docs | 13 | Update Docs | yes | public contract `message-ecc` 1.1.0 and eight public APIs change |
| security | 14 | Security Audit | yes | `lite`, diff-scoped: unpack now takes the code length from untrusted received length |
| performance | 15 | Performance Test | no | AC-12 is the existing timing checks, run in run-tests |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 39 points, a wire rule in eight languages; the interval since loop 92 is also 5 loops |
| local-deploy | — | Local deploy + open site | yes | no UI, no local deploy script: noted at close |
| smoke | — | Smoke acceptance | yes | user checklist in `smoke97.md` |

## Implementation

### Files that change
- Reference and fixtures: `scripts/ecc/*`, `fixtures/ecc/*`, `_docs/02_document/contracts/library/message-ecc.md`, `_docs/02_document/adr/010_parity-percentage.md`.
- The eight packages' scheme, pack and unpack code and tests (see `_docs/02_task_plans/parity-percent/feature-description.md`).
- The ECC ring: `scripts/ecc/ring_ecc.py`, `gen_ring_cases.py`, `fixtures/ecc/ring-cases.txt`, `.github/workflows/ring-ecc*.sh`, eight ECC drivers.
- `README.md` and `_docs/02_document` component docs.

### Order of work
1. AZ-3499 (reference, vectors, contract, ADR) by the parent; it is the producer.
2. AZ-3500 to AZ-3507: disjoint package trees, up to 4 workers at a time (Python/TypeScript/C#/Java, then Go/Swift/Rust/C++), the parent owns commits, review and the vector run.
3. AZ-3508 (ring) after the packages merge; run the real ring.
4. AZ-3509 (docs) last, reading the spelling from the code.

### Proof
- `_docs/02_task_plans/parity-percent/input_data/expected_results/results_report.md`; 22,752 round trips per package; 64 ring pairs, 0 mismatched.

### Risks
- Rounding differs between languages (integer formula, vectors catch it).
- C++ and Rust Cortex-M33F pins (measure on HEAD first; raise at most 400 B / 64 B with a gotcha line).
- A new C++ core source changes `esp.sh` and `ring-lib.sh` counts.

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | CLARIFY (owner chose D4 option B), then round 2 COMPLETE | AZ-3511_parity_percent_rust_assess, AZ-3512_parity_percent_tests_pytscsj, AZ-3513_parity_percent_tests_goswcpp | _docs/loops/loop97/assessment97.md |
