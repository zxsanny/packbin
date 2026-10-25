# Tests by loop (loop 19 onward): java package

Split out of [tests.md](tests.md) in loop 23 so that file stays under the 500-line soft cap. The loop 19 to loop 22 sections below are unchanged; loop 23 is new.

## Loop 19 Tests (AZ-2329, AZ-2331, AZ-2332, AZ-2335, AZ-2338, AZ-2342)

Source: `_docs/03_implementation/batch_01_loop19_report.md`, `_docs/loops/loop19/review19.md`, `_docs/03_implementation/test_run_loop19_report.md`. `bash java/test.sh .` exits 0 with the Android API 26 check passing; the test classes are registered in `PackbinTest`. The review fix pass added regression tests that failed on the pre-fix sources (ten failures: B1 four, B3 two, B4 two, B9 two).

| Test class | Task | What it proves |
|------------|------|----------------|
| `RoundLimitsTest` | AZ-2329 | a `times` count of 65 536, 1 000 000 and 4 000 000 000 throws; 65 535 packs; `withLimits(70_000, ..)` packs 70 000; a `u64` count of 4294967299 and 4294967296 is refused by the cap, not truncated (review B1) |
| `SplitFormLoudPackTest` | AZ-2331 | a clear split bit throws when the condition or count was written after the byte and the body would be written, or the count was never written (also through `flags` and flag bits, review B9); the false condition is silent |
| `LoneBytesInRoundTest` | AZ-2332 | a lone `byte[]` in a `repeat` or `times` round throws; a lone `Utf8` string still broadcasts; a lone dict or buffer under a count-0 `flags` `times` throws (review B4) |
| `TimesCountZeroTest` | AZ-2335 | a list with count 0 throws; a lone scalar packs `0100` |
| `EqValueCheckedTest`, `ReferenceScopeTest` | AZ-2338 | a string, a boolean, NaN, a fraction, a whole `Double`, an out-of-range number and a `u2` slot above 3 are refused at construction |
| `HostileVectorTest` | AZ-2329 to AZ-2338 | the eight new hostile cases (the flag byte comes before the `when`, review C3) |

File split (AZ-2342): `Presence.java` moved out of `Walker.java`; the suite output is identical before and after.

## Loop 20 Tests (AZ-2354, AZ-2355, AZ-2356, AZ-2359, AZ-2360, AZ-2361, AZ-2367)

Source: `_docs/03_implementation/batch_01_loop20_report.md` to `batch_04_loop20_report.md`, `_docs/loops/loop20/review20.md`, `_docs/03_implementation/reference_loop20_budget.md`, and the scenario mapping in `_docs/02_document/tests/blackbox-tests-13-loop20-pack-budget-and-parity.md` (FT-X-38 to FT-X-52). `PackbinTest` checks went from 1772 to 1938 (wave 1b) and 1952 (hostile pack loader), 0 failures, api-check PASS; the new classes are registered in `PackbinTest`.

| Test class | Task | What it proves |
|------------|------|----------------|
| `PackBudgetTest`, `LoneUtf8Budget` | AZ-2354 | `row1LoneUtf8UnderACappedTimes` (the child-JVM helper refuses it in a small heap; 47 ms, 99.5 MB RSS); `rows4To13TheBoundaryIsExact`; `rows14To16SlotsAreChargedOnPack`; `rows17To21TheOrderOfTheChecks`; `rows22To25ScopeAndWidth`; `rows26To28TheLimitsApi` (`withLimits(int, long)` resets `maxBytes`); `growthStaysInsideTheArrayLimit` |
| `RepeatRoundCapTest` | AZ-2355 | `rows1To3TheDefaultLimit`, `rows4To6TheMemberNamed`, `rows7To10EveryPlaceARepeatSits` |
| `ParityPinsTest` | AZ-2356, AZ-2359, AZ-2360 | `az2356CountZeroAfterTheByte`, `az2360SkippedCountWithValuesIsLoud`, `az2359AnEnumIsNotANumber` |
| `CountsFractionsSinkTest` | AZ-2361 | `ac1AFractionIsRefused` (`BigDecimal` 1.5 and 0.1, `Long` and `BigInteger` 2^32 + 1 in `u2`, `bits`, `packed`), `ac2AU64CountAboveIntRange`, `ac3TheSinkGrowsWithoutOverflow` |
| `HostileVectorTest` | AZ-2367 | the seven new hostile `pack` cases; refusal only, not the rule that fired (loop 21) |

Slow tests: none above 2 s from this loop.

## Loop 21 Tests (AZ-2382, AZ-2383, AZ-2384, AZ-2386, AZ-2387, AZ-2390, AZ-2392, AZ-2394)

Source: `_docs/03_implementation/batch_01_loop21_report.md`, `test_run_loop21_report.md`, `reference_loop21_slots.md`. The suite went from 1952 to 2153 checks (`PackbinTest checks: 2153`, step 11 container run).

Test classes (all run by `PackbinTest`): `RoundSlotWidthTest` (AZ-2382: rows 1 to 14 with Java spellings; a nested row is the Java form of an unanchored group), `EmptyRoundBodyTest` (AZ-2390), `RepeatShortOptionalTest` (AZ-2383: rows 27 to 39), `ClearBitProbesTest` (AZ-2384, AZ-2386, AZ-2387: rows 40 to 56), `HostileRefusals` with `HostileLoop21` and `HostileVectorTest` (AZ-2392, AZ-2394). Changed: `RepeatRoundTest`.

## Loop 22 Tests (AZ-2410, AZ-2415, AZ-2417, AZ-2418)

Source: `_docs/03_implementation/batch_01_loop22_report.md`. `PackbinTest` runs 2252 checks (2153 at loop 21).

Test files: `ClearBitProbesTest.java` (`u11NoValueCountBehindAClearWhen`), `RoundLimitsTest.java` with `UnpackMemory.java` (AZ-2415 default, F10 packet refused, raised limit unpacks), `PackBudgetTest.java` (the element row refused by the slots, the bytes route kept), `HostileVectorTest.java` with `HostileLoop22.java` and `HostileRefusals.java` (AZ-2417 ten new cases), `HostileRuleTableTest.java` (AZ-2418: control plus wrong message, wrong exception type and missing entry for a pack and a construct case; registered in `PackbinTest`). Scenarios FT-X-66, FT-X-71, FT-X-73, FT-X-74.

## Loop 23 Tests (AZ-2436)

- `NoValueCountNestedTest.java` (AZ-2436, G3, FT-X-81), run from `PackbinTest`: `refusedNamingMemberAndCount` and `unchangedPacksAsAtHead` per position and kind, `nestedRowCannotCountByTheRowAround`, `memberInsideTheClearWhenIsASilentSkip`.
- Suite: 2540 checks (2252 at loop 22). No main change.

## Loop 24 (Go joins the ring; no Java test change)

Loop 24 added the Go package (AZ-2222, `components/07_go_package/`). No Java source or test changed (batch report: the six suites have no source change). What is new for this package is its place in the ring: Go joins every kind both ways (`user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `session`, `roundflags`, `roundwhen`, `listgroup`, `dictgroup`, `listflags`), through `language-pair.sh` (114 Go lines in all, guarded by `ring-wiring.test.sh`; scenario FT-X-90). The hostile case file is unchanged at 65 cases and is now read by seven loaders (FT-X-87). Java charges a nested-row group 1 slot where Go charges the width of a `Nested` row's own members (assessment D3, open); the U6 row was not run in Java.

## Loop 71 (frame mode, AZ-3232 to AZ-3235)

Source: `_docs/03_implementation/batch_01_loop71_report.md`, `_docs/loops/loop71/assessment71.md`.

| Test class | Task | What it proves |
|------------|------|----------------|
| `FrameVectorsTest`, `CryptoVectorsTest`, `FrameTamperReplayTest`, `FrameMacRefusalsTest`, `FrameHostileTest`, `FrameLifecycleTest`, `FrameReadmeExample` (helpers `FrameSupport`, `FrameRows`, `FrameExamples`) | AZ-3233 | run by `java/test.sh`; the same list as C#; `api-check` PASS at Android API 26 |
