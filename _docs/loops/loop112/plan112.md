# Autodev Loop Plan — Loop 112

loop: 112
kind: product
confirmed: true
branch: dev
ship: false

Feature: AZ-4206, probe and decision. A `repeat` reads rounds until the buffer ends, so a field written after it, or a repeat inside a list or dict element that another element follows, is read as more rounds: the package packs bytes its own unpack refuses (measured in loop 111 in C# and TypeScript). This loop probes five shapes in all nine packages with committed probes, gives the owner one table and one proposed rule, takes the decision and writes the implementation task(s). No package source changes in this loop (the spec excludes the fix).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done: AZ-4206 in `todo/` (written in loop 111) |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task; the follow-up it writes is decomposed when it is 8 points or more (AC-3) |
| implement | 10 | Implement | yes | nine probes, the runner, the findings table, the proposed rule, the owner's decision, the follow-up spec(s) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | the probe runner on all nine packages, and the `scaffold` stage of `scripts/loop-tests.sh` (the only stage a change under `scripts/` reaches) |
| test-spec-sync | 12 | Test-Spec Sync | no | no project criterion changes in this loop; the rule's criteria travel with the implementation task |
| update-docs | 13 | Update Docs | no | no contract, module or public API changes; the README text of the rule belongs to the implementation task |
| security | 14 | Security Audit | not_in_plan | trivial: probes and documents only, no package source, no CI, compose or deploy file, no dependency |
| performance | 15 | Performance Test | no | nothing timed |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | next due by loop 113 (last: loop 108) |
| local-deploy | — | Local deploy + open site | yes | no site (library): the smoke script runs the probes |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke112.md`, agent run |

## Implementation

### Files that change
- new `scripts/probes/repeat-followed-by-field/`: `README.md` (shapes, values, output format), `run.sh`, one folder per package with its probe and its own `run.sh`, and `rule-count/` (the tool that counts the TypeScript schemes a build-time rule would refuse). The spec names `fixtures/` or `scripts/`; `scripts/` is taken because a change under `fixtures/` makes every language stage of `loop-tests.sh` run again for no proof, and a change under `scripts/` reaches the `scaffold` stage only.
- new `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md`: the matrix (10 forms by 8 shapes: the five of the spec with `e` in two forms, a control, and `f`), the packets, the proposed rule with four options, the measured cost, the run as an appendix.
- after the owner's decision: new `_docs/02_document/contracts/library/repeat-last.md`, `_docs/02_task_plans/repeat-must-be-last/` (feature description, scenarios), ten specs `todo/AZ-4210` to `AZ-4219` (epic AZ-4209), rows in `_dependencies_table.md`, a section in `interaction-risks.md`, a line in `module-layout.md`.

### Order of work
1. TypeScript probe first (the reference bytes), then the shape table in the probe `README.md`.
2. The other eight packages by four workers, two packages each, disjoint folders: C# and Java; Python and Dart; Rust and Go; Swift and C++.
3. A sixth shape `f` (two repeats in a row) added to all nine when TypeScript read it back as other values with no error.
4. Parent: the runner, one run of all nine, the findings table; the candidate rule counted in a temporary copy of TypeScript against its whole suite and the ring drivers.
5. Owner decision (one question, four options): "Refuse at build".
6. The contract, the feature description and the ten specs with their tickets.
7. One review (two read-only reviewers and the parent), the fixes, a final run.

### Proof
`run.sh` prints 85 lines (9 packages, 10 forms, 8 shapes and the suffixed second ways); every `control` line reads back `same`; the appendix of the findings is that run, copied by script; three runs are byte-identical.

### Risks
- A package that cannot write a shape at all: the cell says why (Rust and bound C++ lists cannot have a row as an element), it is not left empty.
- The rule count is measured in TypeScript only; the other packages' own test schemes are counted by their tasks. The findings say so.
