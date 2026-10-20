# Security review — the heap-free Rust API, nested kinds (loop 51, AZ-2752, AZ-2753)

**Date**: 2026-10-20 · **Scope**: `git diff 038d7e0..HEAD -- rust/src/nostd rust/embedded` (flags, flag bytes and bits, `when`, `sized`, `bits`, `packed`, `u2`, `group`, `repeat`, `times`, lists) · **Verdict**: PASS (no Critical, High or Medium; one Low, two observations)

## Trust boundary

`nostd::unpack` reads untrusted bytes in firmware that cannot catch a panic. The scheme is the firmware author's constant (trusted); the packet is not. New since loop 50: counts read from the packet now drive loops (`times`, lists, `bits`, `packed`, `sized`, `repeat` until the end).

## Count-driven work (the new surface)

| Count from the packet | Bound | Evidence |
|-----------------------|-------|----------|
| `times` count (any integer width, up to 2^64 - 1) | `min(count, storage, max_rounds)` rounds; a negative or non-fitting count is `BadValue`, a huge one ends with `ShortPacket` at the first round that runs out of bytes | `nostd_rounds_tests::ac4_hostile_counts_end_with_an_error_kind_at_once` (2^32 - 1 rounds: under 1 s, `ShortPacket`) |
| list count (u16) | 65,535 and the storage; an element that reads nothing is `BadValue` | same test (65,535 items over 3 bytes) |
| `repeat` (until the packet ends) | one round per byte at most: a round that reads nothing ends the repeat (the rest is trailing) | `zero_progress_repeat_round_ends_it_and_the_rest_is_trailing` |
| all rounds of one call | `max_slots` (1,048,576 by default), a round charging one slot per member | `ac2_slots_above_the_limit_*` |
| `bits`, `packed`, `sized` | the bytes are taken before any value is stored (`ShortPacket` first), then storage shorter than the count is `TooMany` with nothing written | `nostd_bits_when_tests::storage_shorter_than_the_count_*` |

No count sets an allocation (there is none) or a recursion depth: recursion follows the scheme's nesting only.

## Panic and heap freedom

- The deny list (`unwrap`, `expect`, `panic`, indexing, unchecked arithmetic) is clean on the whole module; positions in packed bytes go through `slot_of` and `checked_shl`/`checked_shr`.
- The linked Cortex-M4F image (`rust-m4f`) has no heap and no panic symbol, and the mutants are caught. The probe packs flat schemes only, so the image proves the walk code that the flat tables reach; the nested kinds are linked (the image grew from 2,652 B to 13,844 B) but are not driven on the device. A nested probe is in AZ-2757 (O2).
- 27 layouts × (3,000 random rows, every cut and trailing copy, 6,000 to 8,000 random packets) are read alike by the map API and `nostd`, with equal values.

## Integers

`count + bias` saturates; a `u64` count above `i64::MAX` reads as negative and is `BadValue`; byte counts use `div_ceil` on `u64` and clamp to `usize` (32 bits on the device), so a count that does not fit fails the short-packet or storage check, never wraps.

## Findings

| id | severity | finding | remediation |
|----|----------|---------|-------------|
| L51-1 | Low | CPU per packet grows with the square of the scheme's size: a `when`, count or flag bit finds what it refers to by scanning the table where it is used (the C++ core stores the result when the scheme is built), and `validate` runs on every call. The packet only multiplies this by its rounds (bounded as above). With meshbell's schemes (tens of entries) and packets of at most 254 bytes the cost is small; a scheme of thousands of entries with flag bits inside rounds would make each round slow. | Keep schemes small, or resolve the references once when the scheme is built (a const resolver needs Rust 1.83 or newer; option D of the loop 51 flash question). |

## Observations (not counted)

- **O1**: the stack of the flat probe is 472 of 512 B (loop 50: 88 B). A scheme nested deeper uses more; on a Cortex-M without a guard an overflow corrupts memory instead of faulting. The nesting is the author's, not the packet's. A nested probe and the stack figure per depth belong to AZ-2757.
- **O2**: see "Panic and heap freedom": the device image drives flat schemes only.
