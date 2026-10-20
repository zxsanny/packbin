# Security review — the heap-free Rust API, text, dictionaries and ECC (loop 52, AZ-2754, AZ-2755)

**Date**: 2026-10-20 · **Scope**: `git diff bae5a5e..HEAD -- rust/src rust/embedded` (compact text codec, `Utf8`, `Utf8Wire`, `Dict`, `ecc_core`, parity, `unpack_repair`) · **Verdict**: PASS (no Critical, High or Medium; one Low, two observations)

## Trust boundary

`nostd::unpack` and `unpack_repair` read untrusted bytes in firmware that cannot catch a panic. New since loop 51: a compact-text decoder (bit-level, table driven), a count header read from the packet, dictionary keys compared across items, and a repair that writes into the caller's buffer.

## Surfaces

| Input from the packet | Bound | Evidence |
|-----------------------|-------|----------|
| String count (varint, 1 to 3 bytes, up to 2,097,151) | `Reader::take` fails with `ShortPacket` at the end of the input; a fourth byte or a non-minimal form is `BadValue` | `nostd_text_tests::ac4_every_bad_row_is_refused_naming_the_field` (the `bad` rows of the vectors file) |
| Compact payload | at most 6 text bytes per payload byte (+ 8); the sink stops writing at the row's storage and at 65,535 bytes, and still checks and counts the rest (`TooMany` with the full size) | `ac2_a_text_longer_than_the_row_storage_is_too_many_with_its_full_size`; 1,000+ single-bit flips of the payloads in the `flip` rows |
| Mode switches, capital, lock, ESC | one symbol per iteration, each consuming at least one code bit; a pending capital at the end, a capital over a switch or a letter without a capital is refused | differential bit flips of 20 layouts (`ac4_every_bit_flip_of_a_packet_is_read_alike`) |
| Dictionary count (u16) | the row's item storage (`TooMany`); each item reads at least the key count byte | `ac5_more_entries_than_the_row_stores_is_too_many` |
| Dictionary key order | compared from the payloads in the input with no storage; the work is the common prefix of two neighbours, so the total is linear in the keys' bytes | `ac5_the_hostile_dictionary_packets_are_refused_on_unpack` (six packets of `cases.txt`) |
| Protected message | length checked first (`TooLong` above 254, `ShortPacket` below `n`); syndromes cost `n x length` (at most 32 x 254 byte operations); a repair writes only after its result is verified on the syndromes, so a refusal leaves the buffer as it was | `ac1_wrong_bytes_up_to_the_limit_*`, `ac1_every_bad_row_*` (the buffer is compared) |

No count sets an allocation (there is none) or a recursion depth beyond the scheme's nesting.

## Panic and heap freedom

- The deny list is clean on `nostd` and `ecc_core.rs` in all feature combinations (`cargo clippy`, six combinations). Table reads use `get`; the Huffman code tables are built at compile time.
- The linked Cortex-M4F images of the sets `base`, `text` and `ecc` have no heap and no panic symbol and add 0 B of `.data` and `.bss`. The check found a real defect on the way: `slice::split_at_mut` links `core::panicking::panic_fmt` although clippy was clean; the call was replaced by `get_mut` ranges (`count::put_field`).
- The `text` and `ecc` sets run a round trip on the device image (`pb_rs_extra`): the compact encoder in 192 B of scratch, a two-entry dictionary, a parity message repaired within its limit.

## Integers

Lengths and offsets use `checked_*` and `saturating_*`; shifts use `checked_shl/shr`; the code tables are compile-time arrays whose Kraft sums are asserted equal to 1.

## Findings

| id | severity | finding | remediation |
|----|----------|---------|-------------|
| L52-1 | Low | A repair is applied to the caller's buffer before the fields are read; a packet that then fails to read (another type number, a field that does not fit) leaves the repaired bytes in the buffer. A miscorrection (more wrong bytes than the code corrects landing on another code word, the accept chance of the contract's table) is likewise written. | Documented on `unpack_repair`; a caller that must keep the received bytes passes a copy. |

## Observations (not counted)

- **O1**: the stack of the `text` set is 1,344 B and of `ecc` 760 B on the probe (the probe's own frames are included: a 192 B scratch array and two message rows); no limit is set yet. A device with a small stack must size the scratch to its longest string (3 words per code point) and keep the call out of deep frames.
- **O2**: the C++ raw memo that skips the parse of a repeated raw string (AZ-2742) is not ported; the cost is CPU on the caller's own row, not on untrusted bytes.
