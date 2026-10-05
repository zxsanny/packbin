# Feature assessment — loop 10

loop: 10
feature: cpp-microcontroller
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-05
**Implement pass**: batches 01–05, reports `_docs/03_implementation/batch_0{1..5}_loop10_report.md`
**Verdict**: COMPLETE — 18 covered / 3 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | Pack into a buffer exactly the packet size | covered | feature AC-1; `grouped_tests.cpp` "S1 buffer exactly the packet size"; `pack.cpp` | intake |
| S2 | Buffer one byte short | covered | AC-6; `scheme_tests.cpp` "bytes full" (`BufferFull`, offset 1); `pack.cpp` | intake |
| S3 | Truncated packet from the radio | covered | AC-6; `container_tests.cpp` "route short lon" (`ShortPacket`, field 8); `unpack.cpp` | intake |
| S4 | Unknown type number | covered | AC-6; `scheme_tests.cpp` `ac1_unknown_type_number`; `codec.hpp` `unpack` | intake |
| S5 | More `repeat` groups than the array holds | covered | AC-6; `container_tests.cpp` "AC-2 one group too many"; `unpack.cpp` `unpack_items` | intake |
| S6 | Long string into a fixed `Text<N>` | covered | AC-8; `counted_tests.cpp` line 85 (`TooMany`, needed 40); `values.cpp` `store_text` | intake |
| S7 | Big-endian CPU | covered | AC-4; s390x QEMU job 213/213 vectors, all-kinds packet equals Cortex-M3 bytes | intake |
| S8 | Board without a working RNG | covered | AC-10; `session_tests.cpp` `ac2_random_failure`; `session.cpp` `start` | intake |
| S9 | Gap in field ids | covered | AC-7; compile-fail `scheme_gap.cpp` and `scheme_tests.cpp` runtime `SchemeInvalid`; `order.hpp` | intake |
| S10 | Upgrade from 0.1.x | covered | AC-11; README migration table (plus the batch 5 construction note); host suite and language pairs | intake |
| B3-2 | Dict key order on pack | covered | `container_tests.cpp` "dict pack refuses a repeated key"; batch 4 row 1 made pack refuse non-ascending keys | batch_03 |
| B3-6 | `load` on a session that holds a seed | covered | `session_tests.cpp` "AC-4 a failed load drops the earlier seed"; `session.cpp` | batch_03 |
| B3-7 | Copying a session | covered | `session.hpp:27-28` copy deleted (a copy would reuse pads; compile error) | batch_03 |
| B3-11 | `os_random` on other hosts | covered | Apple and Linux paths run in the host suite (`session_host_tests.cpp`); the `/dev/urandom` fallback is in `os_random.cpp:37`; other hosts are not a CI target | batch_03 |
| B5-1 | AC-2 example in AZ-2081 is invalid for an id reason | covered | `scheme_tests.cpp` "AC-2 empty group at top level" uses valid ids and proves the placement rule | batch_05 |
| B5-4 | Zero-width body with a huge count | covered | `container_tests.cpp` "empty-body times ends at once"; `unpack.cpp` `unpack_items` | review |
| B5-5 | Bool in a plain group under `flags` | covered | `scheme_tests.cpp` "AC-1 bool in a plain group"; README note | batch_05 |
| B5-6 | Stack margin | covered | AC-5 job: 488 of 512 B | batch_05 |
| AC-12 | Install by registry name from a published tag | out-of-scope | `plan10.md` Risks: "AC-12 needs a published tag and registry tokens, so it cannot be proven inside this loop." Goes to the loop record | batch_04 |
| UTF8 | C++ does not validate UTF-8 in borrowed strings | out-of-scope | `AZ-2078` `### Excluded`: "UTF-8 validation in the core (Flagged concerns)". Open for the user with error labels (C15) | batch_05 |
| AVR | Real 4-byte `double` build (avr-gcc) | out-of-scope | `AZ-2068` stretch task, decision D-3 A; kept in `todo/` | batch_01 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

- `cases.txt` `oversize_count_times` could allow `short_packet|too_many` for fixed-capacity languages. C++ reaches `short_packet` with an unbound `times`, so nothing in this loop needs it; the package tasks of loop 11 onward decide.
- The C++ rows of `discovery/doc_drift.md` are handled by Update Docs (step 13), not here.

### Harness gaps

- None. All five batch reports of loop 10 carry the discoveries table.
