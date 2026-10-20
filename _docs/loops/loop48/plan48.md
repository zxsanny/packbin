# Autodev Loop Plan — Loop 48

loop: 48
kind: product
confirmed: true
branch: dev
ship: false

Intake: hopper hit. The loop 47 record leftovers and `handoff48.md` hold the rows; the owner chose "accept all recommended" on 2026-10-20: AZ-2742 (C++ repeated-text shortcut) and AZ-2747 (ring cleanup), plus the push of `dev` at the close. Epic AZ-2645. No interview.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at intake: two specs, AZ-2742 (existing) and AZ-2747 (new), 4 points |
| decompose-feature | 9.5 | Decompose Feature | no | 4 points in two atomic tasks |
| implement | 10 | Implement | yes | AZ-2747 by one worker, AZ-2742 by the parent (disjoint files) |
| feature-assess | 10.5 | Feature Assessment | no | one task changes a text path with a written spec and byte-identical vectors; the other is scripts only |
| run-tests | 11 | Run Tests | yes | one run at HEAD; unchanged stages skipped |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario of the product changes |
| update-docs | 13 | Update Docs | no | C++ margins in `AGENT_GOTCHAS.md` and the component description are part of AZ-2742 |
| security | 14 | Security Audit | no | report dated 2026-10-19; the change is bounded by byte-identical output |
| performance | 15 | Performance Test | no | the 1 s repeat test is AC-1 of AZ-2742 |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | 2 loops since `retro_2026-10-20_loop46.md`, no incident |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke48.md` |

## Implementation

### Files that change
- AZ-2742: `cpp/src/core/text_encode.hpp`, `pack.cpp`, possibly `cpp/include/packbin/core.hpp`, `cpp/tests/core/text_repeat_host_tests.cpp`, `_docs/AGENT_GOTCHAS.md`, `_docs/02_document/components/05_cpp_package/description.md`.
- AZ-2747: comment text in `ring-cxx.sh`, `ring-go.sh`, `ring-swift.sh`, `ring-prepare.sh`, `ring-toolchains.sh`, `publish-vcpkg.test.sh`; `ring-wiring.test.sh` split into two files; `test.yml` and `scripts/loop-tests.sh` where they list the test.

### Order of work
Tracker In Progress; one worker for AZ-2747; the parent does AZ-2742 (measure the flash and stack margins, pick where the previous bytes live, gcc:16 `make test`, arm embedded stage, AVR target). Then one total review, one step 11 run, smoke, close, push `dev` and `main`.

### Proof
Repeat test within 1 s load-aware; every `enc` row and the ring byte-identical; arm image within 8,192 B flash and 512 B stack; both wiring tests green with their mutants.

### Risks
No flash or stack room (margins 272 B and 8 B): make a saving first or stop and report. A split loses a mutant: count `expect_*` calls before and after. The Mac load makes the container runs slow: status line every 30 s.

## Assessment rounds

None.
