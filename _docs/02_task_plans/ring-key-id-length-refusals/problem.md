---
loop: 81
branch: dev
---
# Frame ring: key and msg_id length refusals

Stub written at the loop 81 intake. Phases 2 to 4 of `/problem` complete it (ACs, expected I/O, figures read from a run on HEAD).

## Problem

The cross-language frame ring (`.github/workflows/ring-frame.sh`, rows in `fixtures/frame/ring-cases.txt`) has no row for a key that is not 32 bytes or a `msg_id` that is not 8 bytes. Six packages (Python, TypeScript, C#, Java, Go, Swift) take a byte string and answer `BadValue`; Rust takes `&[u8; 32]` for the key and an 8-byte `msg_id`, and C++ an 8-byte `msg_id`, so those packages cannot be handed a wrong-length value. Loop 77 (U1 = A) left these rows out for that reason; `fixtures/frame/vectors.txt` and the per-package tests are the only cover.

## Owner decisions

- 2026-10-27 (loop 77, U1 = A): key and msg_id length refusals stay out of the ring. Reopened by the decision below.
- 2026-10-29 (loop 81 intake, option 1 of 3): the Rust driver (key, msg_id) and the C++ driver (msg_id) print `BadValue` themselves where the package cannot receive the value, documented in `fixtures/frame/README.md`. Same step as Rust directions 0 and 4 (loop 78, U1 = A). Not taken: a `skip=` list in the row, and leaving U1 out.

## Change location

No running-app screen: the surface is the frame ring harness. Rows in `fixtures/frame/ring-cases.txt`, the loader `scripts/frame/ring_frame.py`, the Rust and C++ ring drivers, `fixtures/frame/README.md`. Named by the owner at intake through the candidate pick (ring key/msg_id refusals) and the answer above.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| For Rust (key, msg_id) and C++ (msg_id) the driver, not the package, gives the `BadValue` answer | owner 2026-10-29, same as directions 0 and 4 of loop 78; to be stated in the README | accepted-risk | Low |

## Open for Phases 2 to 4

- Probe all 8 drivers on HEAD for every wrong-length byte-string field (key of `seal`, `open`, `mac`; `prev_key`; `msg_id`), not only the two named in the handoff (LESSONS, loop 79).
- Row set, reference check in `framefmt.py`, `coverage.py` entries, self-test cases in `ring-frame.test.sh`.
