# Traceability matrix — loop 55 (AZ-3132, AZ-3133, AZ-3134, AZ-3141)

| AC | Behavior | Status | Test IDs |
|----|----------|--------|----------|
| AZ-3132 AC-1 | 3-deep `when` chain measured on the Cortex-M4F, at most 512 B | Covered | FT-X-133; arm stage 348 B pack / 292 B unpack, deepest 504 B |
| AZ-3132 AC-2 | the image holds the chain, flash at most 8,192 B | Covered | FT-X-133; `ChainRow` 0x5b; flash 8,120 B |
| AZ-3132 AC-3 | C++ packets for the chain rows equal Python's | Covered | `when_chain_host_tests.cpp`; `CHAIN_FAILURES 0` on M3, M4F, s390x |
| AZ-3132 AC-4 | over budget gets a saving | Covered | first measure 780 B, flat loop in `pack_children` and `unpack_children`, packets unchanged |
| AZ-3133 AC-1, AC-2 | bool source skipped / held / clear in eight packages | Covered | FT-X-132; eight runners |
| AZ-3133 AC-3 | empty-group source (C++ and Rust) | Covered | Rust `when_bool_source_tests.rs`; C++ `when_group_source_host_tests.cpp` (bytes differ by field order) |
| AZ-3133 AC-4 | 0 packages fail or skip | Covered | step 11, 14 stages |
| AZ-3134 AC-1, AC-2 | the 65,535 x 200 case in seven packages, at most half the bound | Covered | FT-X-134; local figures; CI figures after the push |
| AZ-3134 AC-3 | a package above half is fixed | Covered (none above) | worst 0.25 s |
| AZ-3134 AC-4 | the seven figures are written | Covered | `batch_01_loop55_report.md`, FT-X-134 |
| AZ-3141 AC-1, AC-2 | flag-byte chain byte-equal, at most 512 B | Covered | FT-X-133; `FlagChainRow` 0x5c; 500 B net unpack, deepest 504 B |
| AZ-3141 AC-3 | over budget gets a saving | Covered | first measure 668 B, `unpack_children` enters the flag scope |
| Loop 55 review #1 | held-`when` logic exists in `unpack_children` and `unpack_one` | Open (handoff 56) | — |
| Loop 55 review #2 | `reads_flag_byte` rescans per call | Open (handoff 56; flash margin 72 B) | — |
| Loop 55 review #5 | corpus case counts hard-coded in three loaders | Open (handoff 56) | — |
