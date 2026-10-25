---
loop: 69
branch: dev
---

# Frame mode golden vectors

**Task**: AZ-3202_frame_golden_vectors
**Name**: Frame mode golden vectors and reference generator (PB-03)
**Description**: A fixture pins seal, open, the replay window and the MAC-only call of frame mode, so every package and meshbell's radio code agree on every byte and every result.
**Complexity**: 4 points
**Dependencies**: AZ-3200_frame_mode_contract_and_adr, AZ-3201_primitive_vectors_python_and_rust
**Component**: fixtures and scripts (`fixtures/frame/`, `scripts/frame/`)
**Tracker**: AZ-3202
**Epic**: AZ-3199

## Problem

Frame mode will be implemented in Rust first and later in C#, Java and Swift, and meshbell pins packbin's vectors with the packbin commit that produced them. Without one fixture every implementation loads, two packages can agree with themselves and disagree with each other, and meshbell cannot tell a packbin change from its own bug. Full spec: `_docs/02_task_plans/rust-m33f-and-frame-mode/input/PB-03_frame_golden_vectors.md`; the bytes are those of the contract (AZ-3200).

## Outcome

- `scripts/frame/framefmt.py`: the reference seal, open, replay window and MAC-only call, written from the contract only (Python 3.9+, standard library plus `scripts/crypto/chacha20.py`).
- `scripts/frame/gen_vectors.py [out]` writes `fixtures/frame/vectors.txt` from a fixed seed; `scripts/frame/check_vectors.py [file]` and `fixtures/frame/check-vectors.sh` re-derive every row and check the coverage list; `check-vectors.test.sh` proves the check fails on a corrupted copy.
- `fixtures/frame/README.md` (row syntax `keys`, `seal`, `open`, `mac`, `replay`; coverage; how a package loads the file); `ring-cases.txt` optional.
- Coverage (all required): E1 to E5; `keys` rows for directions 1 to 3 at epochs 0, 1, 7, 0xFFFF, 0xFFFFFF; refusals (epoch 0x1000000, direction 0 and 4, `kind` 16, an unloaded direction); plain lengths 0, 1, 12, 42, 63, 64, 65, 128, 192, 236, 251; clear 0, 3, 40; `ad` 0, 11, 255; refusals `TooLong` (body 256, `ad` 256) and `BufferFull`; `tag_len` 4, 8, 16 and 0, 5, 32 refused; tamper rows for E1 to E3; `ShortPacket` and `BufferFull` on open; previous-slot rows; the 17-step replay sequence plus the empty-window and 2^64-1 rows and the `open` rows with a window; MAC-only rows (label 1 and 32 bytes, 0 and 33 refused; `n` 4, 8, 16, 32 and 0, 2, 5 refused; messages of 0, 5, 55, 56, 63, 64, 119, 120, 255 bytes each also in 2 and 3 parts; a flipped tag bit).

## Scope

### Included
- The reference generator, the fixture, the check scripts, the README, the coverage check; wiring in `scripts/loop-tests.sh` and CI like the ECC fixture.

### Excluded
- Package implementations (AZ-3203 for Rust; later tasks for the others); hardware timing.

## Acceptance Criteria

**AC-1: Every row reproduces**
Given `fixtures/frame/vectors.txt`
When `check_vectors.py` re-derives every row with the reference
Then every byte and every result matches (0 mismatches) and the coverage list is complete

**AC-2: The contract decides every byte**
Given the contract and an implementation written independently of `framefmt.py`
When E1 to E5 and 3 other rows of different kinds are recomputed
Then 8 of 8 match

**AC-3: The check is not vacuous**
Given copies of the file with 1 byte changed in a `body`, a `tag`, a `result` and a `results` list
When `check-vectors.test.sh` runs
Then each of the 4 copies fails

**AC-4: Deterministic**
Given the generator and its seed
When it runs twice
Then the two files are identical (0 differing bytes)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `check_vectors.py` over the file | all rows match, coverage complete |
| AC-2 | E1 to E5 and three rows through an independent script | match |
| AC-3 | corrupted copies | each fails |
| AC-4 | two generator runs | identical files |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-3, AC-4 | HEAD with the change | `fixtures/frame/check-vectors.test.sh` | passes | — |

## Constraints

- Meshbell pins this file with the packbin commit that produced it; a later change to a row is a wire change (announced, versioned).
- Standard library only for the Python scripts, plus `chacha20.py` from AZ-3201.
- E1 to E5 come from meshbell's independent implementation: a mismatch means the reference or the contract is wrong and is settled before any package uses the file.

## Risks & Mitigation

**Risk 1: The reference and the first package share a mistake**
- *Mitigation*: E1 to E5 are independent; AC-2 asks for one more independent recomputation.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| PB-03 is 4 points here, 3 in the Jira table | owner | accepted-risk | Low |
