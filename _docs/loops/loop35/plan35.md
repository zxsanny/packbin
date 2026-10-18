# Autodev Loop Plan — Loop 35

loop: 35
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-18) asked for compact strings; research, decisions D1 to D5 and option D for C++ are in `_docs/02_task_plans/compact-strings/`. Decomposed into epic AZ-2645, tasks AZ-2646 to AZ-2658 (57 points). Owner go for implementation in waves: 2026-10-18.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | done (13 tasks) |
| implement | 10 | Implement | yes | waves below |
| code-review | — | Total review | yes | once over the loop diff before step 11 (owner rule) |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: `scripts/loop-tests.sh` (suites, scaffold, ring, AC-10) |
| test-spec-sync | 12 | Test-Spec Sync | yes | 20 new ACs (CS-1 to CS-20) and new test scenarios |
| update-docs | 13 | Update Docs | yes | AZ-2658 plus module docs, `module-layout.md`, `glossary.md` |
| security | 14 | Security Audit | yes | a new decoder reads untrusted bytes in 8 languages (bounds, UTF-8, expansion) |
| performance | 15 | Performance Test | no | the speed AC (CS-11) is in each package task and step 11 |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 57 points |
| local-deploy | — | Local deploy + open site | yes | none (library; CI is the proof) |
| smoke | — | Smoke acceptance | yes | script in `smoke35.md` |

## Implementation
### Files that change
- New: `scripts/text/` (train_tables.py, reference.py, emit_tables.py), `fixtures/text/` (tables.json, vectors.txt, README, check-vectors.sh and test), contract `compact-text.md`, ADR 006.
- Per package (one task each, disjoint directories): `python/`, `typescript/`, `csharp/`, `java/`, `rust/`, `go/`, `swift/`, `cpp/` (codec in `cpp/src/core`, API and embedded in `cpp/include`, `cpp/embedded`).
- Shared (parent only, last): `fixtures/hostile/`, `.github/workflows/` (ring, drivers), `scripts/loop-tests.sh`, README, `_docs/`.
### Order of work
1. Wave 1 (parent): AZ-2646 format spec, training script, tables, ADR, contract.
2. Wave 2 (parent): AZ-2647 reference codec, vectors, check script, table emitter.
3. Wave 3 (workers, 4 at a time, own directories only, each runs only its suite): Python, TypeScript, Java, Rust; then C#, Go, Swift, C++ codec.
4. Wave 4 (parent): AZ-2656 C++ API and embedded; AZ-2657 hostile cases, ring, CI; AZ-2658 docs.
5. Total review, step 11 run, feature-assess, docs, security, retro, smoke, close.
### Proof
Vectors file identical bytes in 8 packages; ring pairs; size report against CS-1/2/14; hostile rows; per-package speed loops; M4F size stage unchanged budgets.
### Risks
Eight encoders must agree on ties (suffix parse with lexicographic tie-break, checked by vectors); C++ scratch size; PACKBIN_NO_TEXT and the M4F probe; the training corpus is sentences, not real messages (D5); host load when four workers run suites.
