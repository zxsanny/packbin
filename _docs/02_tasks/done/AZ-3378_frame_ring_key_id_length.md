---
loop: 81
branch: dev
---

# Frame ring: key and msg_id length refusals

**Task**: AZ-3378_frame_ring_key_id_length
**Name**: Frame ring key and msg_id length refusals
**Description**: The cross-language frame ring refuses a key that is not 32 bytes and a `msg_id` that is not 8 bytes in all 8 languages; the Rust and C++ drivers print `BadValue` themselves where their package cannot receive the value.
**Complexity**: 3 points
**Dependencies**: AZ-3354, AZ-3355, AZ-3356 (shipped in loops 78 and 79)
**Component**: cross-language frame ring (`.github/workflows/ring-frame.sh`, drivers, `scripts/frame/ring_frame.py`)
**Tracker**: AZ-3378
**Epic**: none

## Problem

The ring has no row for a key that is not 32 bytes or a `msg_id` that is not 8 bytes. Six packages answer `BadValue` for them; Rust takes `&[u8; 32]` and an 8-byte id and C++ an 8-byte id, so those two cannot be handed a wrong-length value, and their ring drivers do not answer `BadValue` either. On HEAD `489d291` (probe ring, loop 81, the real drivers plus 12 extra refusal rows): the C++ driver pads or cuts the id (`refusals cpp: 55 rows, 6 mismatched`: seal returned a body, open returned `TagMismatch`); the Rust driver ends with `frame line 42: key must be 32 bytes` (no answer) and zero-pads a short id. A key or id of zero length cannot be written at all: the loader emits an empty string, the driver line loses a field and all 8 drivers refuse it as malformed. The owner decided on 2026-10-29 that the Rust and C++ drivers print `BadValue` themselves, as the Rust driver does for directions 0 and 4 (loop 78).

## Outcome

- A key of 0, 31 or 33 bytes and a `msg_id` of 0, 7 or 9 bytes are refusal rows of the ring, each `BadValue`, and all 8 languages answer alike.
- Rust and C++ say `BadValue` where the type cannot hold the value; no driver pads, cuts or aborts on a wrong length.
- The README says which answers a driver, not a package, gives.

## Scope

### Included

- `fixtures/frame/ring-cases.txt`: 15 `refuse-*` rows: `R.seal.` and `R.open.` with `key0`, `key31`, `key33`, `id0`, `id7`, `id9`; `R.mac.key0`, `key31`, `key33`; header comment.
- `scripts/frame/ring_frame.py`: key and `msg_id` written as `-` when empty (seal, open, mac, verify lines).
- `.github/workflows/drivers/handoff-rust/src/frame.rs`: `BadValue` for a key that is not 32 bytes (seal, open, mac, verify) and for a `msg_id` that is not 8 bytes (seal, open).
- `.github/workflows/drivers/handoff.cpp`: `BadValue` for a `msg_id` that is not 8 bytes (seal, open).
- `fixtures/frame/README.md`: the driver-answered refusals (Rust key and id, C++ id) next to directions 0 and 4.
- `.github/workflows/ring-frame-drivers.test.sh` (real drivers) and `.github/workflows/ring-frame.test.sh` (stand-in drivers): the cases of the tables below.

### Excluded

- Multi-part MAC rows.
- A `verify` row with a wrong-length key: a `verify` row answers `valid` or `invalid`. The Rust `verify` uses the same helper as the other lines, and the driver test covers it.
- Rows that combine a wrong-length value with another refusal (which error comes first), and any field the row format does not carry (`prev_key`).
- The packages, `fixtures/frame/vectors.txt` and the per-package tests: no package behavior changes.

## Acceptance Criteria

Loop ACs: `_docs/02_task_plans/ring-key-id-length-refusals/problem.md` AC-1 to AC-8.

**AC-1: The rows exist and the reference confirms them**
Given `ring-cases.txt`
When `ring_frame.py` loads it
Then it holds the 15 new refusal rows (key of 0, 31, 33 bytes in seal, open, mac; `msg_id` of 0, 7, 9 bytes in seal, open), each `BadValue` and confirmed by the reference codec

**AC-2: The real ring is green with 8 languages**
Given the 8 real drivers, built and started as `ring-frame.sh` builds them
When `ring-frame.sh` runs
Then it prints `ring-frame: 64 pairs, ... mismatched: 0` and `refusals <lang>: 58 rows, 0 mismatched` for each of the 8 (43 on HEAD plus 15)

**AC-3: Rust answers BadValue**
Given the Rust driver and a seal, open, mac or verify line with a key of 0, 31 or 33 bytes, and a seal or open line with a `msg_id` of 0, 7 or 9 bytes
When it reads the line
Then it prints `BadValue` and exits 0; it pads and refuses nothing

**AC-4: C++ answers BadValue**
Given the C++ driver and a seal or open line with a `msg_id` of 0, 7 or 9 bytes
When it reads the line
Then it prints `BadValue` (HEAD: a sealed body for 0, 7 and 9, `TagMismatch` on open)

**AC-5: An empty key or id reaches the drivers as one token**
Given a row with an empty key or `msg_id`
When the loader writes the driver line
Then the field is `-` and the line keeps its field count; with the HEAD loader 8 of 8 drivers refuse such a line as malformed, with the fix none does

**AC-6: The new rows can fail**
Given the HEAD Rust and C++ drivers put back (scratch copy), and a stand-in driver that pads or cuts the `msg_id`
When the ring and `ring-frame.test.sh` run
Then the ring is red and names the rows (Rust: the key rows end the seal phase; C++: `R.seal.id7`, `R.open.id7` and the other `id` rows); the stand-in makes `ring-frame.test.sh` exit 1 naming `R.seal.id7`

**AC-7: The other six drivers need no change**
Given C#, TypeScript, Python, Java, Go and Swift
When the new check of `ring-frame-drivers.test.sh` runs for all 8 languages
Then every driver prints `BadValue` for each wrong-length line

**AC-8: The README says who answers**
Given `fixtures/frame/README.md`
When a maintainer reads the ring section
Then it names the Rust key and `msg_id` and the C++ `msg_id` as answered by the driver, in the words used for directions 0 and 4

## Non-Functional Requirements

**Performance**
- The step 11 `ring` stage grows by no more than 20 s over its figure on HEAD at the same load.

**Compatibility**
- A driver line without `dirs` and `out_len` still means `123` and 300 bytes. Toolchains as in CI: C++ clean under `g++ -std=c++17 -O2 -Wall -Wextra -Werror` in `gcc:16`, Rust without warnings, Swift and Go unchanged.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-5 | `ring-frame.test.sh`: a row with an empty key and one with an empty id through a stand-in driver that reads each field of the line | the line has all its fields; the ring is green |
| AC-6 | `ring-frame.test.sh`: a stand-in driver that pads the `msg_id` | exit 1, `R.seal.id7` named |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3, AC-4, AC-7 | real drivers built as `ring-frame.sh` builds them | `ring-frame-drivers.test.sh`: wrong-length key and id lines x 8 drivers | every driver prints `BadValue` | Compatibility |
| AC-1, AC-2 | all 8 toolchains | `ring-frame.sh` | `64 pairs, mismatched: 0`, `58 rows, 0 mismatched` x 8 | Performance |
| AC-6 | scratch copy with HEAD Rust and C++ drivers | `ring-frame.sh` | red, rows named | — |

## Constraints

- The owner's decision (2026-10-29): the Rust and C++ drivers print `BadValue` themselves for what their package cannot receive; no `skip=` field in the row format.
- A ring step added or changed goes into `scripts/loop-tests.sh` in the same commit (LESSONS, loop 78); this task adds cases to scripts the `ring` stage already runs.
- The ring is run for real, with all 8 drivers, before any push that touches it (AGENT_GOTCHAS, loop 77); `ring-frame.test.sh` uses stand-ins and proves the script only.

## Risks & Mitigation

**Risk 1: Two language drivers change on a host that differs from CI**
- *Risk*: the probe host runs Node 22, GCC 15 and Rust 1.97, CI pins Node 24, GCC 16 and Rust 1.98; a driver edit clean here can warn there (loop 18: `-Werror` under GCC 16).
- *Mitigation*: build the C++ driver in `gcc:16` (`ring-cxx.sh`) and the Rust driver with the 1.99.1 toolchain present, before the batch commit; CI's `ring` job is the first run on the pinned toolchains.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| For Rust (key, `msg_id`) and C++ (`msg_id`) the driver, not the package, gives the `BadValue` answer | owner 2026-10-29, as directions 0 and 4 (loop 78); README (AC-8) | accepted-risk | Low |
| No ring row feeds a wrong-length key to `verify` | Excluded above; driver test (AC-3) | open | Low |
| Probe and first implementation run on Linux with a side JDK, Node 22, GCC 15, Rust 1.97 | CI `ring` job after the close push; `gcc:16` build before the commit | open | Low |
