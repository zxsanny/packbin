# Autodev Loop Plan — Loop 55

loop: 55
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` done: AZ-3132, AZ-3133, AZ-3134 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | three tasks of 3 points, no feature description |
| implement | 10 | Implement | yes | one worker per package carries all three tasks; C++ worker first on AZ-3132 (embedded stage) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total run for the loop |
| test-spec-sync | 12 | Test-Spec Sync | yes | new hostile cases and speed tests change the blackbox and traceability lists |
| update-docs | 13 | Update Docs | yes | C++ margins in `AGENT_GOTCHAS.md` and package description |
| security | 14 | Security Audit | no | no change to untrusted-input parsing unless AZ-3133 finds a defect; revisit then |
| performance | 15 | Performance Test | no | AZ-3134 is the performance check |
| deploy | 16 | Deploy | no | `ship: false`; dev push at loop close |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | no cutover |
| retrospective | 17 | Retrospective | yes | last retro loop 53; loop 55 is two loops later, runs if the loop finds a defect |
| local-deploy | — | Local deploy + open site | yes | always at close (library repo: no site; scripts/loop-tests.sh and smoke script) |
| smoke | — | Smoke acceptance | yes | always at close; checklist in `smoke55.md` |

## Implementation

Order: C++ worker (AZ-3132 first, because its embedded stage takes about 3 minutes and edits `cpp/embedded`, then its part of AZ-3133 and AZ-3134), the other seven package workers in parallel (AZ-3133 and AZ-3134 for each package). `fixtures/hostile/cases.txt` is written by the parent before the workers start. No two workers share a file.

Divergence (batch 1): AZ-3132 needed a production change in `cpp/src/core/pack.cpp` and `unpack.cpp` (flat loop for held child `when`s; 780 B to 504 B stack, flash +88 B), which the plan did not list. The empty-group variant of AZ-3133 is C++ and Rust only (README: other packages refuse an empty group as a source).

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | EXTEND | AZ-3141_cpp_when_chain_flag_byte_stack | _docs/loops/loop55/assessment55.md |
