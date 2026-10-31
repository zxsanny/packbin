---
loop: 97
branch: dev
---

# Parity as a percentage: reference, vectors, contract 1.1.0 and ADR 010

**Task**: AZ-3499_parity_percent_reference
**Name**: Parity as a percentage: reference, vectors, contract 1.1.0 and ADR 010
**Description**: Define the parity percentage once: the reference codec, the vector rows every package reads, the contract and the decision record.
**Complexity**: 3 points
**Dependencies**: None
**Component**: ECC reference and fixtures (`scripts/ecc`, `fixtures/ecc`), contract `message-ecc`, ADR
**Tracker**: AZ-3499
**Epic**: none

## Problem

A scheme can only declare a fixed parity count today. The owner wants the system to derive the count from the message length with the user choosing a percentage. All eight packages need one exact rule and shared vectors, or they will disagree on rounding and on which lengths are valid.

## Outcome

- One exact formula and one exact unpack rule, computed by the reference and written in contract 1.1.0.
- Vector rows that every package reads and that fail when a package rounds or searches differently.
- A decision record for ADR 010.

## Scope

### Included
- The reference count, largest-length and inversion functions; the new vector row words, their generator, checker and corrupted-copy self-test.
- Contract `message-ecc.md` 1.0.1 to 1.1.0; ADR 010 and its README row; `fixtures/ecc/README.md`.
- Module-layout / known-consumer lines of the contract.

### Excluded
- Any package code, the ring rows and drivers (AZ-3508), the README (AZ-3509).
- A change to the code, the field polynomial, the 254-byte limit, the cap of 32 or the fixed-count rules.

## Acceptance Criteria

Plan, wording and figures: `_docs/02_task_plans/parity-percent/acceptance_criteria.md` (AC numbers there are noted in brackets), `_docs/02_task_plans/parity-percent/input_data/expected_results/results_report.md` and `_docs/02_task_plans/parity-percent/scenarios.md`.

**AC-1: Count function** [AC-1, AC-2]
Given the reference codec `scripts/ecc/eccfmt.py`
When it computes the parity count for p 0 to 100 and L 0 to the largest clear length of p
Then it returns `min(32, (p x L + 99) div 100)` for all 22,752 pairs, 0 for p 0 and for L 0, and the spot values 10 (p 25, L 40), 20 (p 50, L 40), 3 (p 100, L 3), 32 (p 100, L 222), 1 (p 1, L 3)

**AC-2: Largest clear length and inversion** [AC-4, AC-5, AC-6]
Given each percentage 0 to 100
When the largest clear length and the clear length for every sent length 0 to 254 are computed
Then the largest lengths are 251, 230, 222, 222, 222 for 1, 10, 25, 50, 100 percent (none for 0, which is unprotected), `L + n(p, L)` is strictly increasing, the number of sent lengths 0 to 254 with no clear length is 0, 3, 24, 32, 32, 32 for 0, 1, 10, 25, 50, 100 percent, and for 1 to 100 percent a length above 254 is `too_long`

**AC-3: Protect, repair and refusals under a percentage** [AC-3, AC-6, AC-7, AC-8, AC-9]
Given the position message of `vectors.txt` (13 bytes) and the cases of `results_report.md`
When the reference packs and repairs under a percentage
Then the bytes equal the fixed-count rows (p 0 / 8 / 30 / 60 give `enc.pos.n0` / `n2` / `n4` / `n8`), the repair table of `results_report.md` holds (including the limit lowered to `n / 2`), and a percentage above 100, a percentage with a count, and a limit above 16 are refused as `bad_parity`, `bad_parity` and `bad_limit`

**AC-4: Vector rows** [AC-15]
Given `gen_vectors.py` and `check_vectors.py`
When the file is regenerated
Then `fixtures/ecc/percent-vectors.txt` holds rows of the words `pct`, `encp`, `inv`, `limp`, `fixp`, `badp`, `parp`, `lmtp` (syntax in its header and in `fixtures/ecc/README.md`) and `vectors.txt` is byte-identical, `check-vectors.sh` re-derives every new row and its coverage check names each new word, and `check-vectors.test.sh` fails on a corrupted copy of a new row

**AC-5: Contract 1.1.0 and ADR 010** [AC-14]
Given `message-ecc.md` 1.0.1 and ADR 007
When the contract is updated
Then it is 1.1.0 with a Change Log row, the formula, the unpack rule, the largest-length table, the limit rule, the refusal kinds (no new kind), the dispatch rule and the spelling table of the eight packages (as proposed in the tasks), the accept-chance table is unchanged and `check-contract.sh` passes, and `adr/010_parity-percentage.md` records the decision with the alternatives (survivable-damage meaning, fixed range) and `adr/README.md` lists it

**AC-6: Ring line form** [AC-16]
Given `fixtures/ecc/README.md`
When read
Then it defines the form of the driver line under a percentage (one extra word `p<N>` in the place of the count) so the ring task and the eight drivers share it

## Non-Functional Requirements

**Performance**
- Unpack adds at most 255 integer steps to find the clear length; the existing timing checks (load-factor helpers) pass unchanged.

**Compatibility**
- A fixed-count scheme writes the same bytes as in 0.4.0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | count for all 22,752 pairs and the spot values | equal to the independent integer function |
| AC-2 | largest lengths, strictly increasing, impossible lengths | 254/251/230/222/222/222 and 0/3/24/32/32/32 |
| AC-3 | protect and repair under p 0/8/30/60 and the repair table | bytes equal `enc.pos.*`; refusals as listed |
| AC-4 | `check-vectors.sh` and `.test.sh` on a corrupted new row | pass on the file; fail on the copy |
| AC-5 | `check-contract.sh` | passes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | `fixtures/ecc/vectors.txt` | byte-identical to 0.4.0 | `git diff` shows no change to that file | Compatibility |

## Constraints

- Owner decision (2026-10-31): the percentage is overhead (parity bytes = the percentage of the clear length), integer 0 to 100, rounded up, capped at 32.
- Scenario rows S1, S2, S3, S4, S5, S9, S10, S11 are owned by this task's vectors (scenarios.md); S7 and S8 by AC-3 here and AC-1/AC-6 of each package task; S12 by the Rust task's dispatch AC, repeated in the other seven.
- Fit decision (limit semantics, option A): a limit above `n / 2` of the message is lowered; `bad_limit` only outside 0 to 16.
- No new refusal kind: an impossible length is `uncorrectable`.

## Risks & Mitigation

**Risk 1: Rounding differs between languages**
- *Risk*: `ceil` on a float gives 1 off at exact multiples.
- *Mitigation*: the formula is integer only, `(p x L + 99) div 100`, and 22,752 pairs are checked.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Formula must be identical in 8 languages | AC-1, AC-2; vectors | open | Medium |
| Wire change for opt-in schemes | contract 1.1.0 | open | Medium |

## Contract

This task produces the contract at `_docs/02_document/contracts/library/message-ecc.md` (version 1.1.0). Consumers read that file, not this spec: the eight package tasks and the ring task.
