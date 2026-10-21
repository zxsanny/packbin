# Security review — held-`when` loop in C++ unpack, bool-source corpus, speed tests (loop 55, AZ-3132, AZ-3133, AZ-3134, AZ-3141)

**Date**: 2026-10-21 · **Scope**: `git diff 8e34769..HEAD` on `cpp/src/core/pack.cpp` and `unpack.cpp` (the rest is tests, embedded images and corpus lines read for what they pin) · **Verdict**: PASS (no Critical, High or Medium; two Low observations)

## Trust boundary

C++ `unpack` reads untrusted bytes in firmware. `unpack_children` is the loop that walks the children of a `when`, a `flags` member, a group or a flag-bit child on that path; it now enters a held child `when` and a flag bit itself.

## Surfaces

| Input | Bound | Evidence |
|-------|-------|----------|
| Packet bytes in `unpack_children` | no new read, allocation or index: `j` advances by the entry's `span` (at least 1) or by 1 into a held `when`'s own children, both inside `[i + 1, end)` where `end = i + span` of the parent; the loop ends when `j` reaches `end`; a packet value never selects an index (it only decides whether `when_matches` or a flag bit is true) | `unpack.cpp` `unpack_children`; hostile corpus (75 cases) in eight packages and the ring fuzz in step 11, 14 stages passed |
| Flag scope | a held `when` that reads a flag byte still runs inside `with_outer_flags`, and a set flag bit's child too; a `when` that reads none cannot change `flag_bytes`, so it needs no restore. `reads_flag_byte` scans `[j + 1, j + span)` of the same validated table | AZ-3141 rows; `flag_scope_host_tests.cpp`; ring |
| Recursion and stack | depth is set by the scheme's nesting, never by a packet; measured on the Cortex-M4F: plain chain 348 B pack and 292 B unpack, flag-byte chain 384 B and 500 B, deepest 504 of 512 B | arm stage log of step 11 |
| Pack side | `pack_children` enters a held `when` in its loop, same table bounds | `when_chain_host_tests.cpp`, byte-equal to Python |

## Observations

- **L55-1 (Low)**: the flash margin of the Cortex-M4F budget is 72 B and the stack margin 8 B; the next edit of `cpp/src/core` must first save flash. Not a vulnerability; a build gate catches it.
- **L55-2 (Low)**: `reads_flag_byte` rescans a `when`'s entries on each unpack call (CPU is linear in the scheme size per round, set by the developer, not by a packet); the review of the loop notes a resolve-time bit as the fix.

No secret, key, network path or dependency is touched.
