# Traceability matrix — loop 54 (AZ-2815, AZ-2816, AZ-2823)

| AC | Behavior | Status | Test IDs |
|----|----------|--------|----------|
| AZ-2815 AC-1 | 200 rounds of one 65,535-character text: 1 s load-aware and 0.25 s load-aware headroom, both targets | Covered | FT-X-131; C# `RepeatedTextSpeed.Ac1_*` (typed and dictionary) |
| AZ-2815 AC-2 | every packet byte-identical, 4,236 tests on both targets | Covered | FT-X-131; whole C# suite |
| AZ-2815 AC-3 | a changed text is encoded again (mid-run, alternating, last character, compact then raw, empty) | Covered | C# `RepeatedTextReuse.Ac3_*` (5 plans; mutant fails 5) |
| AZ-2815 AC-4 | no text outlives a pack call | Covered | C# `RepeatedTextReuse.Ac4_*`, `CompactTextTests.Concurrency` |
| AZ-2815 AC-5 | 65,536 UTF-8 bytes refused as before | Covered | C# `CompactTextTests.Limits.Ac5_*` |
| AZ-2816 AC-1, AC-2 | a `when` of a skipped source is false (value differs, value 0), pack and unpack | Covered | FT-X-130; C++ `when_skipped_source_host_tests.cpp` `ac1_*`, `ac2_*`, `ac2_plain_*`; corpus `pack_when_of_skipped_source`, `..._zero` |
| AZ-2816 AC-3 | source written: packet carries a, k, b | Covered | FT-X-130; C++ `ac3_*` |
| AZ-2816 AC-4 | source two `when`s deep | Covered | C++ `ac4_nested_skip` |
| AZ-2816 AC-5 | one `when` holds source and consumer | Covered | C++ `ac5_one_when_holds_both` |
| AZ-2816 AC-6 | the corpus case in all eight packages | Covered | FT-X-130; eight runners |
| AZ-2816 AC-7 | embedded budget | Covered | `cpp-embedded` stage: 7,952 B and 504 B; AVR Uno example 15,428 B |
| AZ-2816 AC-8 | nothing else moves | Covered | step 11, 13 stages; C++ suite on `gcc:16`; ring |
| AZ-2823 AC-1 | `when` source link limit: 255 builds, 256 and 301 refused | Covered | C++ `ac6_source_link_is_limited_to_255_entries` |
| Loop 54 review #1 | stack depth of the `when_matches` / `source_skipped` recursion on a nested chain | Open (not measured on the Cortex-M4F image) | handoff55 |
| Loop 54 review #3 | a bool or group-presence source behind a clear `when` | Open (no test, Python agrees on the probe only) | handoff55 |
