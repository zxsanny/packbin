# Loop 20 batch 02 report (wave 1b: C#, Python, Java, Rust against the TypeScript reference)

Date: 2026-10-11. Workers ran only their own package suite (owner preference). Contract: `reference_loop20_budget.md`. Parent checked each worker's diff scope (`git diff --cached` empty, no stash, files only under the worker's directory, every file at or under 500 lines).

## Results per package

| Package | Specs | Suite before to after | AC-1 (lone 65 535-char utf8 under times(65 535)) |
|---------|-------|-----------------------|-----------------------------------------------|
| C# | AZ-2365, 2354, 2355, 2366, 2360 done; 2358 PARTIAL; 2356, 2359 pins | 913 to 994 on net10.0 and netstandard2.0 | before `OverflowException`, no member, 1.26 s, 2 214 MB; after `'S': the packet would be 16777477 bytes, above the limit of 16777216 bytes`, 12 ms pack, 88 MB RSS |
| Python | AZ-2354, 2355, 2362, 2356, 2360 done; 2359 pin | 777 to 835 (suite about 20 s slower: 25.7 s) | before 7.3 GB (spec figure); after same message, 4 ms pack, 42.8 MB RSS |
| Java | AZ-2361, 2354, 2355, 2360 done; 2356, 2359 pins | `PackbinTest` checks 1772 to 1938, 0 failures, api-check PASS | before OOM at -Xmx1g, no member; after same message, 47 ms pack, 99.5 MB RSS (96 MB heap child JVM) |
| Rust | AZ-2365, 2354, 2355, 2360, 2356 done (2356 was a real fix); 2359 pin | lib 436 to 469, integration binaries unchanged, 566 tests in total (533 before) | before 2.19 s and 5.5 GB; after same message, 4 ms pack, 35.5 MB RSS |

Fixes that were not pins: Rust and Python AZ-2356 (a lone scalar with count 0 written after the flag byte was refused; now packs `010000`, decision 3), Python AZ-2362 (bare `IndexError` was a `flags` member inside a `repeat` round; now `0101000200` like TypeScript), Python AZ-2360 (message names `pt`), Java AZ-2361 (G1, F29, F30), C# AZ-2366 (F17: `ShortPacket` naming `V`, F27: `List<int>` of `u32` in a round refused at construction).

CI-parity: PASS per package suite (the compilers CI runs for these packages: dotnet both targets, pytest, `java/test.sh` with api-check, `cargo test`); the remaining CI jobs run in the one total test run.

## Parent rulings on the workers' open items

| Item | Ruling |
|------|--------|
| Java and Rust keep the loop 19 `times` cap text (tests pin it); Python moved to the reference text | accept; naming differences listed in the reference-table errata (step 13) |
| Java: `withLimits(int, long)` resets `maxBytes` to the default | accept (reference row 26); Rust's `with_max_bytes` is separate and `with_limits` keeps it (D3) |
| Rust: slot width of pack equals Rust's own unpack (counts group, `flags`, flag-byte names) | accept; loop 21 parity item (width differs between packages) |
| Python: unpack charges 8 more slots per name for the first round of each run (README 1192); a packet written at exactly `max_slots` is refused by Python's own unpack | accept for this loop; loop 21 owner decision (align Python unpack or document) |
| Rust/Python/C#/Java split flag byte named `flag_byte` or by the first member | accept (no flag-byte name in those APIs) |
| C# messages quote the member (`'S'`) | accept |
| Python/C# limit validators have no 2^53 upper bound | accept (existing validators) |
| Rust: reference rows 2, 3, 22, 23 and AZ-2355 row 10 do not apply (no `times`/`repeat` in a list element) | accept; AZ-2354 AC-2 has no Rust equivalent |
| C# disclosed one `git checkout -- csharp/Walker.Numbers.cs` inside its own directory | no harm: nothing staged, no stash, no other path touched; noted |
| Rust debug-build AC-4 rows 14, 15 take 8.5 s and 17.7 s; Python adds about 20 s; C# timing test `Ac10TimingTests` failed once at 1076 ms in a full-suite run | total review decides whether to scale the limits down; watch the flake in the total run |
| **AZ-2358 PARTIAL (C#)**: eq and u2/bits/packed slots done; integer fields u8..i64 NOT done: C# unpack boxes narrow integers as `double` (AZ-2116 undone) and dictionary repack of unpacked `Values` is a tested contract; refusing whole doubles failed 37 existing tests in 15 files, none weakened | **owner decision** (A finish AZ-2116: exact types from unpack, a public `UnpackResult.Values` change; B accept the asymmetry and document); AZ-2358 stays In Progress |

## Discovered during implementation (carried to feature-assess / loop 21 handoff)

| Spec ref | What | Handling | Clear |
|----------|------|----------|-------|
| AZ-2358 | see above (blocked integer-field refusal) | owner decision | unclear |
| AZ-2354 | Python unpack slot surcharge vs pack | loop 21 | unclear |
| AZ-2354 | slot width differs between packages (Rust, Python empty group, duplicate leaves) | loop 21 parity table | unclear |
| AZ-2362 | TypeScript packs `{w:[1,2], v:[5]}` (short list in an optional flags position) as `010101050200`; Python refuses `repeat fields must have equal lengths` | loop 21 | unclear |
| AZ-2356 | older Python/Java/Rust messages name a field by id, not by member | loop 21 | unclear |
| AZ-2361 | an exact `u2`/`bits`/`packed` conversion now also refuses values that were cut silently (`Long` 2^32+1, `BigInteger` 2^32+1, `BigDecimal` 0.1) | upgrade note | clear |
| AZ-2366 | typed round binding to a collection of rows stays the real F17 fix (D5); a list member inside a round runs only the element check | loop 21 | clear |
| docs | `_docs/02_document/components/01_csharp_package/description.md` line 145 and the README limits section (`MaxBytes`, `with_max_bytes`, `withMaxBytes`, pack-side slots, AZ-2358, AZ-2360) | step 13 | clear |
| perf | C# small `times` scheme pack about 10% slower (198 to 202 ms against 225 to 230 ms per 300k packs) | total run | unclear |
