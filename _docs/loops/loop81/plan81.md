# Autodev Loop Plan — Loop 81

loop: 81
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done by P0 `/problem` + `/new-task`; spec AZ-3378 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task, no handoff |
| implement | 10 | Implement | yes | AZ-3378, one batch, by the parent (one task: no parallel workers) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh --only scaffold,ring` (the stages that run the ring self-tests, the real ring and the driver script) |
| test-spec-sync | 12 | Test-Spec Sync | no | no package behavior or blackbox scenario of the packages changes; the ring is test infrastructure |
| update-docs | 13 | Update Docs | no | no public contract; `fixtures/frame/README.md` is edited by AZ-3378 itself |
| security | 14 | Security Audit | yes | `lite`, diff-scoped: CI test scripts and the ring drivers change (as loops 79 and 80) |
| performance | 15 | Performance Test | no | the step 11 `ring` stage bound is an NFR of AZ-3378 |
| deploy | 16 | Deploy | no | no ship |
| release | 16.5 | Release | no | no ship |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | not due (loop 80 record: next after loop 84) |
| local-deploy | — | Local deploy + open site | yes | at close: no UI; the ring, the driver script and the self-tests are the smoke |
| smoke | — | Smoke acceptance | yes | `smoke81.sh` + checklist |

## Implementation

### Files that change
`fixtures/frame/ring-cases.txt`, `fixtures/frame/README.md`, `scripts/frame/ring_frame.py`, `.github/workflows/drivers/handoff-rust/src/frame.rs`, `.github/workflows/drivers/handoff.cpp`, `.github/workflows/ring-frame-drivers.test.sh`, `.github/workflows/ring-frame.test.sh`.

### Order of work
1. Loader (`hx()` for key and id) and the 15 rows; run the probe against HEAD drivers first (the rows must fail: AC-6).
2. Rust and C++ drivers; the driver script cases; the stand-in cases of `ring-frame.test.sh`; README.
3. Parent: real ring with all 8 drivers (side JDK `~/.local/share/packbin-jdk26`, `npm ci` done), C++ in `gcc:16` (`ring-cxx.sh`), Rust on 1.99.1 and 1.97, AC-6 proof in a scratch copy.

### Proof
Real ring `64 pairs, mismatched: 0` and `refusals <lang>: 58 rows, 0 mismatched` x 8; driver script with the new checks for 8 languages; `ring-frame.test.sh` all PASS; CI `ring` job after the close push.

### Risks
Host differs from CI (Node 22, GCC 15, Rust 1.97 here; 24, 16, 1.98 there): C++ driver built in `gcc:16` before the commit.

### Diverged in batch 1
- `ring-frame-drivers.test.sh` checks `verify-key-31`, `verify-key-33` and `verify-key-0` in all 8 languages, not for Rust only: the probe showed that every driver prints `BadValue` for a `verify` line with a key of the wrong length (no ring row carries it).
- The `ring-frame.test.sh` case for the loader (`empty-key-and-id-keep-fields`) reads `seal.in` and `mac.in` written by `ring_frame.py` directly instead of running a stand-in driver on a dedicated row: the honest run already feeds the real rows to the stand-in.

