# Autodev Loop Plan — Loop 62

loop: 62
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: `AZ-PENDING_cpp_field_layout_shrink` (3 points) |
| decompose-feature | 9.5 | Decompose Feature | no | one task |
| implement | 10 | Implement | yes | the layout change and its measurement (the source may stay at HEAD, AC-6) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement; `not_in_plan` if AC-6 keeps the source at HEAD |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` (cpp stages, arm embedded stage, ring); one total run |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario change to the product |
| update-docs | 13 | Update Docs | yes | `AGENT_GOTCHAS.md` and the C++ description (new `sizeof(Field)`, flash figure, margin) |
| security | 14 | Security Audit | no | no input, auth or exposure change; last audit loop 41 is a decoder audit, no new untrusted input |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | no | last retro loop 60, under 5 loops |
| local-deploy | — | Local deploy + open site | yes | none: a library |
| smoke | — | Smoke acceptance | yes | `smoke62.sh`, agent run (owner rule 2026-10-12) |

## Implementation

### Files that change
- `cpp/include/packbin/table.hpp` (layout, `array_count`, size guards; `fields_counted.hpp` unchanged)
- `cpp/src/core/pack.cpp`, `unpack.cpp`, `values.cpp` (readers of the Array item and count)
- `cpp/embedded/lib.sh` (`flash_pin`, when AC-2 is met)
- `_docs/AGENT_GOTCHAS.md`, `_docs/02_document/components/05_cpp_package/description.md`

### Order of work
1. Baseline: arm stage figures at HEAD (flash 8,032 B, stack 504 B) and `sizeof(Field)` per target.
2. Pick the layout; build; measure on the Cortex-M4F image before anything else.
3. If AC-2 and AC-3 hold: host suite, `gcc:16` suite, AVR and examples; size guard; pin; docs. Else AC-6: revert, record.
4. One step 11 run for the loop.

### Done in batch 1
Shape A (drop `Field::count`): flash 7,808 B, stack 496 B, `sizeof(Field)` 32 B (AC-1 relaxed by the owner).

### Proof
Arm stage figures; `sizeof(Field)`; host, container and ring suites with 0 changed expectations.

### Risks
Flash margin 160 B and stack margin 8 B (`AGENT_GOTCHAS.md`); helpers called from `unpack_one` keep three real arguments.
