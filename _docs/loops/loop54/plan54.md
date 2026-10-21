# Autodev Loop Plan — Loop 54

loop: 54
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` done: AZ-2815, AZ-2816 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | two tasks of 2 and 3 points, no feature description |
| implement | 10 | Implement | yes | AZ-2815 (C# cache) then AZ-2816 (C++ `when`, shared case, eight runners) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total run for the loop |
| test-spec-sync | 12 | Test-Spec Sync | yes | new hostile case and new C# facts change the blackbox and traceability lists |
| update-docs | 13 | Update Docs | yes | C++ package description margins, `AGENT_GOTCHAS.md` margins |
| security | 14 | Security Audit | yes | the C++ unpack of a `when` reads untrusted bytes; scope = the diff only |
| performance | 15 | Performance Test | no | the C# speed test is the check (AC-C1); C++ speed suite runs in step 11 |
| deploy | 16 | Deploy | no | `ship: false`; dev push at loop close |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | no cutover |
| retrospective | 17 | Retrospective | no | complexity 5 in total, no incident, last retro loop 53 |
| local-deploy | — | Local deploy + open site | yes | always at close (library repo: no site; scripts/loop-tests.sh and smoke script) |
| smoke | — | Smoke acceptance | yes | always at close; user checklist in `smoke54.md` |

## Implementation

Order: AZ-2815 first (it edits `csharp/**`), then AZ-2816 (C++ core, corpus, eight runners incl. `csharp/tests`). No worker pair shares a file.
