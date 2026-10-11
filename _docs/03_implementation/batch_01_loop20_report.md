# Loop 20 batch 01 report (wave 1a: TypeScript reference + C++)

Date: 2026-10-11. Workers run only their own package suite (owner preference). Wave 1b (C#, Python, Java, Rust) aligns to `reference_loop20_budget.md`; wave 2 is AZ-2367.

## TypeScript (done, reference package)

| Spec | Status | Notes |
|------|--------|-------|
| AZ-2354 | done | `PackOut` (new `pack-out.ts`, a `Uint8Array` that doubles but never passes `maxBytes`) replaces `number[]`; slots charged per round with unpack's width; `Scheme.DefaultMaxBytes`, `maxBytes` in `SchemeLimits`. AC-1: before `RangeError: Invalid array length`, no member, 1.55 s, 1 679 MB; after `s: the packet would be 16777477 bytes, above the limit of 16777216 bytes`, 8 to 14 ms, 135 to 145 MB (node + import alone 88 MB). Row 15 (4.26 MB) packs in 0.86 s instead of 2.06 s |
| AZ-2355 | done | `refuseRepeatOverLimit`; before 65 536 entries packed 65 537 bytes |
| AZ-2356 | pin | already aligned: list gives `pt: 2 items, times count 0`, scalar packs `010000` |
| AZ-2360 | done | before `{pt:[5,6]}` packed `0100`; now `pt: a value is given, but the count of its times is not written, ...`; `split-form-loud-pack.test.ts` pinned row updated on purpose |
| AZ-2363 | pin | already refused since loop 19 (review B2, 02206a7); two more shapes added |
| AZ-2359 | pin | numeric enum packs as a number (`Level.High = 200` gives `01c8`); string enum refused |

Suite 728 to 758 (84 suites, 0 fail), strict `tsc` exit 0 (re-run by the parent). Reference table: `_docs/03_implementation/reference_loop20_budget.md` (28 AZ-2354 rows, 10 AZ-2355 rows, rules and order of checks). Parent checked every AC of AZ-2354/AZ-2355 against its rows: AC-1 (row 1), AC-2 (rows 2, 3, 40 items of `u64`), AC-3 (rows 4 to 13), AC-4 (rows 14 to 16), AC-5 (rows 26 to 28), AC-6 (suite); AZ-2355 AC-1 to AC-3 (rows 1 to 3). No spec change needed beyond the amendments listed in the specs.

## C++ (done)

| Spec | Status | Notes |
|------|--------|-------|
| AZ-2357 | done | links in the unused `Field::bit` byte; U4 row: before `010003055a00`, now `BadValue` naming the `times`; accepted rows `0100025a00`, `01010103055a00` unchanged |
| AZ-2364 | done | `Field::late` is a chain; two late `when`s with only the second given: before `01010209`, now `BadValue` naming `b`; no-body row still `010002` |
| AZ-2356 | pin | split count 0 after the byte: list `BadValue`, scalar packs `010000` / `0102005a00` |
| AZ-2360 | pin | already loud; no values packs `0100` |

gcc:16 `make test` pass (compile-fail 15 of 15), host `make test` pass, arm embedded stage 0 failed (M3 QEMU 241 of 241, s390x PASS, M0+ PASS). 11 new tests fail on the HEAD sources, the 2 pins pass on both. Cortex-M4F: flash 8064 to 8112 of 8192 B (margin 128 to 80 B; AZ-2357 alone 8120 B), stack 448 of 512 B unchanged; first AZ-2357 version (table scan) cost +88 B and was replaced.

CI-parity: PASS (TypeScript `npm test` + strict `tsc`, C++ gcc:16 `make test` + arm embedded stage; the remaining CI jobs run in the one total test run).

## Discovered during implementation

| Spec ref | What | Proposed handling | Clear |
|----------|------|-------------------|-------|
| AZ-2360 | Python's error names `times 1`, not the member `pt` (`python/tests/test_split_form_pack_fails_loudly.py:93`) | Python worker changes the message to name the first held member (spec amended) | clear |
| AZ-2354 | combined `flags` byte over budget: named by the first name its members declare, depth-first | confirmed by the parent; the table has it | clear |
| AZ-2355 | refused `repeat` names the first member whose list passes the limit | confirmed by the parent | clear |
| AZ-2354 | a growable list of boxed values can miss the 256 MB bound (TS `number[]` 554 MB) | wave 1b workers measure AC-1 memory with `/usr/bin/time -l` (spec amended) | clear |
| AZ-2357 | one accepted row is now refused: plain `times` (no flag byte), count behind a clear `when`, count 0, no rounds; it packed `0100`, C++'s own unpack and Python's pack refuse that packet | keep; upgrade note in step 13 (single exception to "accepted rows keep their bytes") | clear |
| AZ-2357 | new construction limits: a count more than 255 entries after the `when` that holds it, and a link of more than 255 entries between two late `when`s of one bit, are `SchemeInvalid` (C9 precedent) | upgrade note / docs, step 13 | clear |
| AZ-2357 | U4 scheme, count 1 behind a clear `when`, no rounds: C++ refuses (before and after), Python packs `0100025a00` | loop 21 parity item (owner decision) | unclear |
| AZ-2357 | the same "count behind a clear `when`" gap for `sized`, `bits`, `packed` counts, not probed in other packages | loop 21 probe | unclear |
| AZ-2367 | hostile `pack` cases not wired into `typescript/tests/support/hostile-pack.ts` | wave 2 | clear |
| AZ-2364 | `pack_flag_byte` frame 48 to 56 B, not on the deepest measured path | note; arm stage passed | clear |
