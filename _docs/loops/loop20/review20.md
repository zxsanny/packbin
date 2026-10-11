# Loop 20 total review

Date: 2026-10-11. Three read-only reviewers over `git diff a27433e..HEAD` at HEAD e0f8b2d (A: csharp, rust; B: typescript, python, java; C: cpp, fixtures, hostile loaders, cross-package). Reviewers probed `git archive` copies; none ran the arm embedded stage or the full suites (the total run does). Findings are copied from the reviewer reports; the fix list and verdict are below.

## Findings (before fixes)

| id | sev | cat | file | summary | confidence |
|----|-----|-----|------|---------|------------|
| A1 | High | Bug | `csharp/SchemeOrder.cs:114-125` | the AZ-2366 element-only check inside a `repeat`/`times` round is inverted: `Repeat(List<List<object?>> Items, U8..)` built and bound at a27433e and is now refused at construction; `List<long>` for a `U32` list builds but every packet with a round returns `ShortPacket`; `Ac2_Scheme_ListOfLongIdsInARepeat_Builds` pins the unusable scheme | run |
| A2 | Medium | Bug | `csharp/RowBinding.cs:~164` (`RequireFits`) | `IsInstanceOfType(raw)` is stricter than the old binding: an `object[]` member in a round that bound before now returns `ShortPacket` | run |
| A3 | Medium | Spec-Gap | `csharp/Walker.Flags.cs:34,42-50` | a typed row cannot say "no value" for a non-nullable member, so a row that packed `0100` (combined `flags`, count skipped, `byte Pt`) is now refused | run |
| A4 | Medium | Parity | `rust/src/walk/flag_bits.rs:~99-102,126-130` | `zero_given` leaked from the split form into the combined `flags`: skipped count plus a stale `n: 0` silently drops a lone-scalar body (TypeScript and C# refuse) | run |
| A5 | Low | Parity | `csharp/Walker.Counted.cs:~92` | a `times` count above `int.MaxValue` keeps the older text (`does not fit an int`) | run |
| A6 | Low | Parity | `csharp/Walker.Rounds.cs:48-55` | `v is IList` counts a lone `byte[]` as a list of rounds (different error text only) | read |
| A7 | Low | Maint | `csharp/Packbin.cs:~41` | `WithLimits(int,long)` became `(int,long,long)`: source compatible, binary breaking | read |
| A8 | Low | Bug | `csharp/PackOut.cs:~47-65` | `maxBytes` above about 2^31-57: `Count + size` (int) can overflow instead of refusing | read |
| A9 | Low | Test/Perf | `rust/src/pack_output_budget_tests.rs` | AC-4 rows take 20 s in a debug build (0.8 s in release) | run |
| B1 | Low | Parity | `python/src/packbin/_pack.py:437` | AZ-2362 fixed only for the optional leaf under `flags`: a required leaf with an empty list still raises a bare `IndexError` (pre-existing) | run |
| B2 | Low | Parity | `java/.../Presence.requireNothingDropped` (unchanged) | Java refuses a split-bit `times`, count above 0 after the byte, body absent or `[]`; TypeScript and Python pack a clear bit (pre-existing) | run |
| B3 | Low | Test | `python/tests/test_pack_output_budget.py` row 16 | only asserts `ShortPacket`, not field/left | read |
| B4 | Low | Test | Java/Python hostile loaders | assert refusal only (known, batch_03) | read |
| C1 | Medium | Parity | `cpp/include/packbin/order.hpp:189-203` | the late chain misses a `when`/`times` nested in a `when` or `flags` inside the bit (C++ packs, TypeScript refuses; readable packets) | run |
| C2 | Medium | Parity | `cpp/include/packbin/order.hpp:256-259`, `cpp/src/core/pack.cpp:50-52,102-108` | AZ-2357 covers `times` only: a `bits`/`packed`/`sized` count behind a clear `when` still packs, and C++'s own unpack refuses that packet (`010005`) | run (bits), read |
| C3 | Low | Spec-Gap | `cpp/include/packbin/order.hpp:206-224` | the 255-entry limit also rejects a scheme where the `times` sits inside the same `when` that holds the count (valid before loop 20) | read |
| C4 | Low | Test | `cpp/tests/core/times_count_zero_host_tests.cpp`, `hostile_pack_cases.hpp:171-182` | the AZ-2356 pin and case pass through the late rule, not the count-0 rule | read |
| C5 | Low | Test | Python/Java/Rust/C++ hostile loaders | refusal only (same as B4) | run |
| C6 | Low | Maint | `_docs/02_document/components/05_cpp_package/description.md:128` | stale | read |

Reviewers cleared: every pack append path in all five growable packages is budget-checked before the write; bytes of all previously packing rows unchanged except the accepted rows; slot charging equals each package's unpack (Python surcharge accepted); `repeat` and `times` caps and their order match the reference; limits validation; `Field::bit` link and `late` chain safe (no out-of-range index under ASan/UBSan, no collision with unpack's use of `Field::bit`, tables over 255 entries); hostile set consistent; CI time not at risk (60 minute job, Rust debug about 9 s for the hostile test).

## Parent rulings

| id | Ruling |
|----|--------|
| A3 | accept: a typed non-nullable member is always "given", so decision 9 (loud) applies; upgrade note (it was the silent drop B6 described) |
| A5, A6, A7, B2, B4, C4, C5 | accept; loop 21 handoff (A7: upgrade note) |
| A9 | accept; keep AC-4 at spec size, noted in the handoff (release build or a smaller-limit variant) |
| C6 | step 13 |

## Fix pass (parallel, one worker per package, owner decisions unchanged)

| Finding | Package | Fix |
|---------|---------|-----|
| A1, A2 (+ AZ-2366 AC-2 corrected) | C# | inside a round the construction check is the same predicate the unpack binding uses (a member must be able to hold the per-round list: `IList`, `IList<object?>`, `List<object?>`, `List<List<object?>>`, `object[]`, `object`); `List<int>`/`List<long>` of scalars in a round are refused; the pinned unusable-scheme test is replaced |
| A8 | C# | `PackOut` refuses with the member name before an `int` overflow (effective cap at the array limit) |
| A4 | Rust | `zero_given` only for the split "count follows the byte" shape; the combined `flags` refuses as TypeScript and C# |
| B1, B3 | Python | named error (or the TypeScript outcome) for a required leaf with an empty list; row 16 pins field/left |
| C2, C1, C3 | C++ | attempt in this order with the arm stage after each: `bits`/`packed`/`sized` count behind a clear `when` (C2), nested late deciders (C1), the 255 limit skipped when the `times` sits in the holding `when` (C3); STOP and defer whatever would take the flash margin below 32 B (now 80 B) |

## Fix pass results (2026-10-12)

| Finding | Package | Result | Regression test fails before / passes after |
|---------|---------|--------|---------------------------------------------|
| A1, A2 | C# | `CollectionShape.HoldsRounds`/`Rounds` (`FieldBinding.cs`) mirror `RowBinding.ListOf`: construction refuses a list member in a round unless unpack can bind it. `List<int>`/`List<long>` refused; `List<List<object?>>`, `object[]`, `IList`, `IList<object?>`, `List<object?>`, `object` build and bind as at a27433e; a dict member in a round no longer throws (`ShortPacket` naming it) | yes: 54 new tests fail on HEAD sources (23 member types x U8/U32 x Repeat/Times) |
| A8 | C# | `PackOut` effective cap `min(maxBytes, 0x7FFFFFC7)`, long arithmetic, refusal naming the member | yes |
| A4 | Rust | `Form { Combined, Split }`: `zero_given` only in the split form; the combined `flags` refuses a skipped count with a stale `n: 0` | yes (`expected a type error, got Ok([1, 0, 0])` on HEAD) |
| B1 | Python | a required leaf with an empty list raises `KeyError 'missing field w'` (TypeScript: `missing w`), never a bare `IndexError`; all-lists-empty still packs no rounds | yes |
| B3 | Python | row 16 pins `ShortPacket(field='1', needed=0, left=66040)` (Python's own unpack accounting) | passes on HEAD (assertion tightened) |
| C2 | C++ | `bits`, `packed`, `sized` counts behind a clear `when` linked through `mark_held`; `ref_value` returns false when `count_skipped`; `010005` now `BadValue` | yes |
| C3 | C++ | no 255-entry limit when the counted member sits inside the holding `when` | yes |
| C1 | C++ | `mark_late` descends into `Flags` and non-late `when`s; `under_clear_when` keeps rows with a false outer/inner condition packing | yes (9 checks fail on HEAD sources) |

Suites after the fix pass (worker runs): C# 1118 on net10.0 and netstandard2.0 (1001 before), Rust 569 (566), Python 846 (835), C++ gcc:16 and host green, arm embedded stage 0 failed after each fix. Cortex-M4F: flash 8112 to 8160 of 8192 B (margin 80 to 32 B, exactly the floor set in the plan), stack 448 of 512 B unchanged. The C++ margin is now exhausted for loop 20: any further edit to `cpp/src/core` or `cpp/include` needs a flash saving first.

Not fixed, accepted or deferred: A3, A5, A6, A7, A9, B2, B4, C4, C5, C6 (rulings above); new from the fix pass: a pack-only list member in a round that built before (`List<List<int>>`, `IList<int>`) is refused at construction (upgrade note), typed scalars in a round still never bind to a scalar member (D5, loop 21), a dict member that cannot hold the rounds still builds (`LoneDictRoundTests` pins it for pack) and unpack returns `ShortPacket`, a direct late `when` in a bit body is refused even when another non-late child already sets the bit (TypeScript packs that row: loop 21 parity question), the C2 behavior for `bits`/`packed`/`sized` is not probed in C#, Python, Java and Rust (loop 21), the nested late link has the same 255-entry limit (upgrade note).

**Verdict: PASS_WITH_WARNINGS** (0 Critical, 0 High after the fix pass; every Medium fixed except A3, accepted by the parent ruling above; open Lows: A5, A6, A7, A9, B2, B4, C4, C5, C6, and the assessment rows still to come).
