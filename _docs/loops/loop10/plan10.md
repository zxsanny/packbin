# Autodev Loop Plan — Loop 10

loop: 10
kind: product
confirmed: true
branch: loop/10-cpp-microcontroller
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` — never a plan row |
| decompose-feature | 9.5 | Decompose Feature | yes | about 29 points, handed off (`feature-description.md`) |
| implement | 10 | Implement | yes | T1–T8 from decompose; T9 (AVR) stretch per D-3 A |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always; host suite plus embedded QEMU/big-endian jobs |
| test-spec-sync | 12 | Test-Spec Sync | yes | 13 new C++ embedded ACs |
| update-docs | 13 | Update Docs | yes | public C++ API replaced (D-2 B); `languages.md`, README |
| security | 14 | Security Audit | yes | core parses untrusted radio packets into caller buffers |
| performance | 15 | Performance Test | yes | AC-5 flash/stack budget, AC-10 host throughput |
| deploy | 16 | Deploy | no | not a ship loop; registry publish waits for maintainer tokens |
| release | 16.5 | Release | no | deploy excluded |
| migration | 16.7 | Data/Traffic Cutover | no | no data store or traffic flip; wire bytes unchanged |
| retrospective | 17 | Retrospective | yes | feature is about 29 points |
| local-deploy | — | Local deploy + open site | yes | always at close (library: test compose) |
| smoke | — | Smoke acceptance | yes | always at close |

## Implementation

### Files that change
`cpp/` (new core headers and sources, host suite ported, dynamic walker removed), embedded build files and examples, CI test workflow and test compose, publish script, README C++ section, `_docs/01_solution/languages.md`.

### Order of work
T1, then T2 and T6, then T3 and T4, then T5 and T7, then T8. T9 last, stretch only.

### Proof
Every hex vector asserted in `cpp/tests` before the port still asserted after it, and the same bytes on QEMU `mps2-an385` and a big-endian host.

### Risks
D-2 B is a breaking C++ release. AC-12 needs a published tag and registry tokens, so it cannot be proven inside this loop.
