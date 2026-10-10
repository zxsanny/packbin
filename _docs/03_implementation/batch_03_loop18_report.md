# Batch Report

**Batch**: 3 (loop 18, wave 3: C# reference stage, then TypeScript, Python, Rust, Java and C++ in parallel)
**Tasks**: AZ-2120 (all six packages), AZ-2128 (the `when`/`times`/`repeat` angle)
**Date**: 2026-10-10

Owner decision 10 (2026-10-10, option A): a `when`, `times` or `repeat` that is a member of a `flags` container (or in a group or flag-bit field under it) is written like any other value, its bit on exactly when it writes a value. Stage 3a: the C# worker implemented the rule and wrote the reference table (`_docs/03_implementation/flags_member_reference_cases_loop18.md`, about 60 hex-pinned cases over twelve schemes WA to R2). Stage 3b: five workers matched the table byte for byte in their packages. Owner direction unchanged: own package suite only, no per-batch review, no Docker.

## Task Results

| Task | Status | Packages | Tests (before to after) | Issues |
|------|--------|----------|--------------------------|--------|
| AZ-2120_csharp_when_under_flags_pack | Done, all six | C#, TypeScript, Python, Rust, Java, C++ | C# 756 to 810 (both targets); TypeScript 509 to 627; Python 556 to 681; Rust 390 to 471; Java suite passes (`expect[A-Za-z]*(` 1154 to 1164, +64 assertions through helpers); C++ passes (`expect(` 282 to 288 + 5 in `member_cases.hpp`) | see discoveries |
| AZ-2128_flag_group_presence_parity | Done (the `when`/`times`/`repeat` angle, the last open part) | all six | same | C++ also fixed `present()` for nested `flags`, `flag_bit` and `u2` heads |

Failing-first evidence: C# 24 of 47, TypeScript 39 of 118, Python 50 of 125, Java 64 of 64, Rust "true" cases and 11 of 19 typed, C++ 41 checks failed before the change. Differentials against HEAD exports: no difference on schemes that do not use the shape (TypeScript 20 000 packets x 7 schemes, Rust 2.4M packets, Java 90 000 lines, Python 1 200 rows, C++ 20 000 packets per scheme).

## Reference bytes (all six packages)

`u8 mode; flags{ when eq(0,1){ u8 speed }, u16 heading }` with mode=1, speed=7, heading=90 packs `010103075a00` (was `0101025a00`); mode=0 packs `0100025a00`; `times` n=0/1/2 packs `0100025a00` / `010103055a00` / `01020305065a00`; `repeat` 0/1/2 rounds packs `0101015a00` / `0101035a0005` / `0101035a000506`.

## Code Review Verdict: not run for this batch (owner direction); the one total review follows

## Test Suite: own package suite per worker (above); CI-parity: PASS for the language suites; rings, embedded and publish gate are the one total run

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 22 | A `times` with count 0 and a non-empty list is a pack error naming the value (C# reference); C++ now also refuses it outside `flags` (was silently skipped); the owner never saw this choice | AZ-2120 rule 3 | owner to confirm; one-line revert in C++ `item_count` if limited to `flags` | unclear |
| 23 | A packet whose `times` count is above 0 but whose bit is clear (what the old packers wrote) unpacks to a row that no longer repacks (`missing pt`); before it silently repacked | AZ-2120 rule 3/6 | upgrade note; follows the rule | clear |
| 24 | A `times` whose count field was skipped leaves its bit clear and body values are dropped without an error (all six); a present but invalid count still throws (TypeScript) | AZ-2128 | keep | unclear |
| 25 | A split `flagByte` is decided where it is read (values written before it), a combined `flags` decides in order, in every package (as C#) | AZ-2120 | keep; documented | clear |
| 26 | A `when` nested in the body of another `when` that is a `flags` member is decided on the values before the outer body (cannot name a field written earlier in that body); all six | AZ-2120 | later test in all six if it matters | unclear |
| 27 | A `when` with a false condition and a body value given writes nothing and raises no error (as a `when` outside `flags`); the remaining silent drop | AZ-2120 | keep | unclear |
| 28 | Rust: a `repeat` whose rounds are all empty `{}` has no value, bit clear; a mix of empty and filled rounds fails pack | AZ-2128 | keep | clear |
| 29 | Python: a short `times` list outside `flags` still raises a bare `IndexError` (three existing tests pin it); only a `flags` member names the value | AZ-2194 AC-6 | decide whether to name it everywhere | unclear |
| 30 | C# typed rows hold one round only and typed unpack of a set `times`/`repeat` bit throws `InvalidCastException` (carried F17) | AZ-2120 | known limit, F17 stays open | clear |
| 31 | C++ typed rows cannot express list-length mismatches or out-of-range values; Rust typed `Scheme<T>` has no `repeat`, no split bytes, no groups with members | AZ-2120 | map API and dictionary rows cover them | clear |
| 32 | Error text names the value by field id in Python, Java, Rust and C++ and by name in C# and TypeScript (C15) | AZ-2128 | align if C15 defines a format | clear |

## Behavior changes for the upgrade notes

- All six: a `when`, `times` or `repeat` that is a member of `flags` (or inside a group or flag-bit field under it) is written and sets its bit when it writes a value; `Mode=1, Speed=7, Heading=90` packs `01 01 03 07 5a00` (was `01 01 02 5a00` in all six, with `Speed` dropped). A set member that cannot be written in full fails pack naming the value. A `times` count of 0 with a non-empty list fails pack. Old packets with the bit clear still unpack; repacking such a row can differ or fail.
- C++: a bound `times`/`repeat` under `flags` with zero rounds leaves its bit clear (it was set); a group, `when` body or flag bit whose only values sit in a `u2`, nested `flags` or `flag_bit` now sets its bit.

## Commit

`[AZ-2120] [AZ-2128] Loop 18 wave 3: when, times, repeat under flags` ... `Loop: 18`.

## Next: one total review, feature assessment, the one total test run (step 11), test-spec sync, docs, security, retrospective
