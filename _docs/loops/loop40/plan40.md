# Autodev Loop Plan — Loop 40

loop: 40
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-19) took "accept all recommended": a short loop of the loop 39 review Lows, Rust `DispatchHandler::parity()` required, the correction limit 0 and the 254-byte limit kept, housekeeping, `main` fast-forward at close per `ci_cd_pipeline.md`. Ticket AZ-2704 (epic AZ-2677).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | short loop: spec written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | AZ-2704 |
| feature-assess | 10.5 | Feature Assessment | no | short loop; owner-run skill, carried |
| run-tests | 11 | Run Tests | yes | one step 11 run for the loop |
| test-spec-sync | 12 | Test-Spec Sync | no | no new scenarios beyond the ACs |
| update-docs | 13 | Update Docs | no | one contract sentence inside the task |
| security | 14 | Security Audit | no | no new untrusted input; /security carried |
| performance | 15 | Performance Test | no | none |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | owner-run skill, carried |
| local-deploy | — | Local deploy + open site | yes | none (library; CI is the proof) |
| smoke | — | Smoke acceptance | yes | script in `smoke40.md` |

## Housekeeping (intake commit)
- The shipped specs AZ-2664, AZ-2665 (loop 36) and AZ-2674 to AZ-2676 (loop 37) move from `todo/` to `done/`; AZ-2666 (owner-run `/security`) and AZ-2068 stay.
- AZ-2689 AC-3 is met: `test.yml` runs 39135620507 (`1e07978`, 205 s) and 39140952528 (`75b1d39`, 216 s), the first two green runs after loop 38, median 210.5 s against 238.5 s (run created to last update).
- Epic AZ-2677 moves to Done at the loop close, after AZ-2704.

## Implementation
### Files that change
- `typescript/src/index.ts`, `csharp/PackSession.cs`, `csharp/Packbin.cs`, `java/src/main/java/packbin/{BinaryPacker,PackSession}.java`, `python/src/packbin/_scheme.py`, `rust/src/{value.rs,scheme/mod.rs,session/mod.rs}`, `swift/Sources/Packbin/{Unpack,PackSession}.swift`, their tests, `message-ecc.md`.
### Order of work
One package at a time in the parent (small edits); each package's own suite after its edit; one total review; step 11; smoke; close; push `dev` and `main`.
### Proof
AC-1 to AC-5 of AZ-2704.
### Risks
The Rust `NoHandlers` variant is a new public enum arm (no tag yet); the ring driver maps unknown arms by a wildcard.
