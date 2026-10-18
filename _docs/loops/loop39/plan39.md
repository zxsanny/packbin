# Autodev Loop Plan — Loop 39

loop: 39
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-18) chose "Loop 38 review cleanups" (short loop). Tickets AZ-2694, AZ-2695 (epic AZ-2677).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | short loop: specs written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | 5 points, two small tasks |
| implement | 10 | Implement | yes | AZ-2694, then AZ-2695 |
| feature-assess | 10.5 | Feature Assessment | no | short loop; owner-run skill, carried |
| run-tests | 11 | Run Tests | yes | one step 11 run for the loop |
| test-spec-sync | 12 | Test-Spec Sync | no | no new scenarios beyond the ACs |
| update-docs | 13 | Update Docs | no | contract sentence and C++ numbers inside the tasks |
| security | 14 | Security Audit | no | no new untrusted input; /security carried |
| performance | 15 | Performance Test | no | none |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | owner-run skill, carried |
| local-deploy | — | Local deploy + open site | yes | none (library; CI is the proof) |
| smoke | — | Smoke acceptance | yes | script in `smoke39.md` |

## Implementation
### Files that change
- ECC unpack paths and tests in all eight packages; `rust/src` trait default; `message-ecc.md` one sentence; C++ component description.
### Order of work
AZ-2694 per package in parallel workers (disjoint folders), parent keeps commits; AZ-2695 after; step 11; smoke; close; push.
### Proof
AC-1..AC-4 of AZ-2694; mutant run for AZ-2695; arm stage flash 8,132 B and stack 492 B unchanged.
### Risks
Flash 60 B and stack 20 B margins: the C++ too-long edit sits in `cpp/src` outside the core if possible, else measure first.
