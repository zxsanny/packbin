---
loop: 83
branch: dev
---

# Ring rows: wrong-length key or msg_id with a second refusal

**Task**: AZ-3389_ring_key_id_second_refusal_rows
**Name**: Ring rows that combine a wrong-length key or id with a second refusal
**Description**: 14 refuse rows pin that a key that is not 32 bytes or a msg_id that is not 8 bytes is answered `BadValue` before `TooLong` or `BufferFull`, in the 6 packages that take a byte string.
**Complexity**: 3 points
**Dependencies**: AZ-3378 (shipped; the single key/id rows)
**Component**: Frame ring (`fixtures/frame/ring-cases.txt`, `fixtures/frame/README.md`)
**Tracker**: AZ-3389
**Epic**: none

## Problem

The ring has 12 rows of a wrong-length key or msg_id alone (AZ-3378) and 7 rows of `TooLong` / `BufferFull` alone. Nothing pins which error comes first when both apply. The reference (`scripts/frame/framefmt.py`: `check_load` for the key, `_args` for the msg_id, then `TooLong`, then `BufferFull`) answers `BadValue`. A package that checks lengths after the size checks would pass every row today. Rust (key, msg_id) and C++ (msg_id) cannot be handed the wrong-length value, so their drivers print `BadValue` by construction (README): the rows cannot pin the order in those two, and they say so.

## Outcome

- 14 new refuse rows, all `BadValue`, confirmed by the reference on every load.
- A package that answers another error first fails the ring (and is reported, not bent).

## Scope

### Included
- Refuse-seal (6): `key33` and `id7`, each with `ad256`, `body256` and `outshort` (the second refusal of the existing `R.seal.ad256`, `R.seal.body256`, `R.seal.outshort` rows).
- Refuse-open (8): `key33` and `id7`, each with `ad256`, `body256`, `clear256` and `buffer` (as `R.open.ad256`, `R.open.body256`, `R.open.clear256`, `R.open.buffer`).
- Row names `R.seal.key33.ad256` style; a comment above the block naming the order and the Rust/C++ limit; one line in `fixtures/frame/README.md`.
- Readers of the row list or count (`ring_frame.py`, `ring-frame.test.sh`, `ring-frame-drivers.test.sh`, `coverage.py`): run each; edit only a number a reader hard-codes.

### Excluded
- refuse-mac combinations (every mac refusal is `BadValue`; the order is not observable).
- Changing any package or the reference. A package that answers another error first stops the task: report it (AC-6).
- A C++ driver edit (the split, AZ-3387, owns that file).
- Multi-part MAC rows (owner-declined, G8m).

## Acceptance Criteria

**AC-1: Rows added**
Given `fixtures/frame/ring-cases.txt` on HEAD (42 `refuse-` rows: 21 seal, 12 open, 9 mac)
When the task is done
Then it has 56 `refuse-` rows (27 seal, 20 open, 9 mac), the 14 new ones each expecting `BadValue`

**AC-2: Reference confirms**
Given the loader, which derives every expected value again from `framefmt.py`
When it loads the file
Then all 14 rows are confirmed and `ring_frame.py` reports 0 rows not confirmed

**AC-3: Ring green**
Given the HEAD run (64 pairs, 45 rows per pair, 58 refusal rows per language, 0 mismatched)
When `ring-frame.sh` runs after the task
Then `64 pairs, mismatched: 0`, 45 rows per pair, and 72 refusal rows per language (58 + 14: each new seal row goes to every writer, each new open row to every reader), 0 mismatched

**AC-4: Order pinned**
Given a scratch copy of one byte-string package (Python) where the key-length check moves after the size checks
When the ring runs on it
Then at least 1 new row mismatches for that language and the exit code is non-zero; the scratch copy is deleted and no package file is changed in the tree

**AC-5: Readers**
Given `ring-frame.test.sh`, `ring-frame-drivers.test.sh`, `ring-wiring-rows.test.sh`, `scripts/frame` self-checks
When they run
Then all pass

**AC-6: Disagreement is a finding**
Given any package that answers `TooLong` or `BufferFull` for one of the 14 rows
When the ring runs
Then no row is dropped or edited to match: the loop records the package, the row and both answers in the loop record as an open finding and stops that row's merge for owner decision

## Non-Functional Requirements

**Performance**
- The ring run time grows by under 10% (HEAD: about 30 s with the drivers built).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `grep -c '^refuse-'` and per kind | 56; 27 / 20 / 9 |
| AC-2 | the loader | 14 rows confirmed |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | drivers built, JDK on PATH | `ring-frame.sh` | 0 mismatched, 72 refusal rows | none |
| AC-4 | scratch copy of the Python package | `ring-frame.sh` with it | mismatch on a new row | none |
| AC-5 | the reader scripts | run | PASS | none |

## Constraints

- Exclusive paths: `fixtures/frame/ring-cases.txt`, `fixtures/frame/README.md`, and a hard-coded count in a reader script. No driver, package or reference edit.

## Risks & Mitigation

**Risk 1: A package disagrees** (flagged concern)
- *Mitigation*: AC-6.

**Risk 2: The 14 rows are redundant with the single rows for packages that check the key first**
- *Mitigation*: that is the point; AC-4 shows the rows catch a reordering.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A package answers another error first | AC-6: stop and report | open | Medium |
| Rust and C++ print `BadValue` by construction (2 of 8 prove nothing about order) | README and row comment | accepted-risk | Low |
