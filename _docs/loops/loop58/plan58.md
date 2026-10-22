# Autodev Loop Plan — Loop 58

loop: 58
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0 (3 tasks: AZ-3160, AZ-3161, AZ-3162) |
| decompose-feature | 9.5 | Decompose Feature | no | each task is 1-2 points |
| implement | 10 | Implement | yes | three test-only edits, disjoint files, done by the parent |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total run |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC change to the product |
| update-docs | 13 | Update Docs | no | test-only; no margin or API change |
| security | 14 | Security Audit | no | no input, auth or exposure change |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | no | last retro loop 55, under 5 loops |
| local-deploy | — | Local deploy + open site | yes | at close |
| smoke | — | Smoke acceptance | yes | at close |

## Implementation

### Files that change
rust/tests/nostd_hostile_tests.rs (AZ-3160); go/hostile_pack_test.go (AZ-3161); cpp/tests/core/dict_order_host_tests.cpp (AZ-3162).
### Order of work
Independent; AZ-3160, AZ-3161, AZ-3162.
### Proof
Broken-copy runs per AC; Rust `cargo test`, Go in `golang:1.27`, C++ host `make -C cpp test` and gcc:16; arm stage figures unchanged (flash 8,032 B).
### Risks
L57-1 (flash margin 160 B, stack 8 B) — untouched, no library edit.
