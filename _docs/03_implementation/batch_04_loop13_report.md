# Batch Report

**Batch**: 4 (assessment round 1 extension, owner scope A: C# workers AZ-2175 then AZ-2176 in one worker, TypeScript AZ-2177, Rust AZ-2178 as a parallel wave; C# took two rounds, TypeScript two)
**Tasks**: AZ-2175_csharp_when_on_written_values, AZ-2176_csharp_nested_round_refused, AZ-2177_typescript_nested_round_refused, AZ-2178_rust_typed_times_pins
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2175_csharp_when_on_written_values | Done | 11 files (6 src, 5 tests) | 390/390 pass (366 before this batch's round 2: +24) | AC-6 and AC-7 added after the review; missing count keeps `InvalidOperationException` |
| AZ-2176_csharp_nested_round_refused | Done | 3 files (1 src, 1 test, 1 edit) | in the 390 | Group elements only build (pre-existing AZ-2119) |
| AZ-2177_typescript_nested_round_refused | Done | 6 files (3 src, 3 tests) | 241/241 pass | AC-2 amended (empty collections only, AZ-2102) |
| AZ-2178_rust_typed_times_pins | Done | 1 new test file, no production change | 217/217 pass (+11) | Two spec byte strings were wrong; corrected |

Shared (parent): `_docs/02_tasks/` (specs moved to `done/`, AZ-2175 and AZ-2177 amended, dependencies table), `_docs/loops/loop13/plan13.md`, `assessment13.md`. README changes (badges, upgrade notes) wait for step 13.

## Code Review Verdict: PASS_WITH_WARNINGS

Three fresh reviewers (read-only, scratch copies, oracle fuzz and HEAD differentials):

- **C# (AZ-2175, AZ-2176) PASS_WITH_WARNINGS** (0 Critical, 0 High, 2 Medium, 4 Low). Differential of 900 000 random `when`-chain cases plus 400 000 with unrestricted counts: 3.3% differ and every difference is a packet that was unreadable, repacked differently or silently misparsed on HEAD, 0 readable-and-correct packets changed, 0 new throws where HEAD packed; 450 000 nested-mode cases against an oracle of Java's rule: 0 false refusals, 0 misses; 13 shapes also run in Java (javac): same refusals and the same message. Medium F1 (most `seen` writers unpinned: deleting a record line left the suite green) fixed in round 2 with a 12-case theory; each writer's record line, the scope hand-over and `seen.Clear()` mutants now fail named tests. Medium F2 (a count naming a field a `when` skipped still read the supplied value: `U8 P; When(1,Eq(0,0),U8 N); Sized(2,Data,count 1)` P=1, N=2 packed `01 01 09 09`, which its own read rejects; identical on HEAD but about 20 per 100 000 cases turned from a loud throw into a silent bad packet) fixed in round 2 inside AZ-2175 (new AC-6: counts of `sized`, `bits`, `packed`, `times` read from what pack wrote, as Java does; a count written in an earlier round does not count in the next). Low F3 (a Scope per round, +50% allocation) fixed for rounds (one Scope cleared per round; 70 000 rounds 14.8 MB, same as HEAD). Low F4 (`Eq(bool,false)` behavior change undocumented) became AC-7; README and component-doc updates wait for step 13. Low F5, F6 pre-existing. Delta re-review: PASS_WITH_WARNINGS, F1 and F2 fixed, a 900 000-case differential with unrestricted counts again found 0 readable-and-correct packets changed; new Low N1: a missing count throws `InvalidOperationException` while the other pack failures are `ArgumentException` (kept: it is the type `RequireCount` already threw; upgrade note).
- **TypeScript (AZ-2177) PASS_WITH_WARNINGS** (0 High, 1 Medium, 3 Low). Oracle fuzz: 240 000 random schemes (flags in flags, split flag bits, anchored and unanchored groups, `when`, list/dict elements), 0 misses and 0 false refusals against Java's rule; 16 refusal mutants, 15 killed. Medium F1 (AC-2 only met for empty collections: a non-empty `list` of group elements already fails on HEAD, AZ-2102): the spec's AC-2 was wrong, amended; tests retitled. Lows fixed: test 14 layout, the surviving list/dict-descent mutant (two new cases), the comment on the kept unreachable `addNames` branch (deleting it breaks tsc).
- **Rust (AZ-2178, tests only) PASS_WITH_WARNINGS** (2 Low). All hex strings re-derived by hand from the format rules (two AC-6 strings in the first draft were wrong and are corrected in the spec); 18 of 20 production mutants killed; the two survivors fixed by the parent: the AC-1 error text is now asserted exactly (`times at id 3: count 2, 1 rounds`) and the 255-round test pins the first packet bytes (`01 ff 00 01 00 02 00 03 02 01`).

Reproducing tests changed: TypeScript `round-values.test.ts` "values of a times nested in a round keep one entry per round that set them" built a nested `times`, now refused; rewritten to the legal `when`-in-`times` shape with the same intent (wire `01030107000109`). No existing C# or Rust test changed.

## Test Suite

- C# 390 passed; TypeScript 241 (0 todo); Python 103; Rust 217; Java 4 runners, 0 failures; C++ all tests passed
- Failed: 0
- `language-pair.sh`: all rings pass across six languages (C# driver bytes identical to HEAD)
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {typescript,rust,csharp,python,cpp,java}` (all six exit 0), `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`, `tsc --noEmit --strict` over `typescript/src/index.ts`, `bash .github/workflows/language-pair.sh`. Embedded stages and `publish-gate.test.sh` run in Run Tests (step 11).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | C#: a `when` on a bool whose bit is clear never matches on pack (`Eq(bool,false)`): the row On=false, V=5 now packs `01 00` and reads back; HEAD packed `01 00 05`, unreadable. Wire changes only for packets that were unreadable | AZ-2175 AC-7; AZ-2126 | README upgrade note, C# component doc line 89, AZ-2126 table row (step 13) | clear |
| 2 | C#: a count naming a `when`-skipped field now throws `InvalidOperationException` (`count 'N' is missing`); other pack failures are `ArgumentException` | AZ-2175 AC-6; review N1 | README upgrade note states the type; unify with AZ-2181 if wanted | unclear |
| 3 | C#: an F32 field supplied as a double (dictionary form) with `Eq(f, 0.1f)`: pack compares the unnarrowed double, unpack the narrowed float (identical on HEAD) | AZ-2126 | AZ-2126 | unclear |
| 4 | C#: `seen` keeps the caller's object, not what unpack reads back (dictionary path: a u8 as 5.4 or `"5"`) (identical on HEAD) | review F6 | AZ-2191 | clear |
| 5 | C#: a nested-row (continuing) group in a round inherits "in a round", so a `repeat` in it is refused (Java does the same) | AZ-2176 Included | Mirrors Java; one shape test | clear |
| 6 | C#: a list/dict element that is a group holding a `repeat`/`times` only builds; a group element does not pack per item (KeyNotFoundException on read, AZ-2119) | AZ-2176 AC-2; AZ-2119 | Tests are build-only for group elements | clear |
| 7 | TypeScript: the only element that can hold a `repeat`/`times` is an unanchored group in a list/dict; non-empty group elements do not pack per item even outside rounds (`missing c`) | AZ-2177 AC-2 (amended); AZ-2102 | AZ-2102 | clear |
| 8 | TypeScript: the `addNames` repeat/times branch, the `RoundLists.add` guard and `times` reading `values` instead of `seen()` are unreachable while nested rounds are refused; they become load-bearing again when AZ-2127 lifts the refusal | review F4 | Kept (deleting the branch breaks tsc); revisit with AZ-2127 | clear |
| 9 | Rust still allows a `times` inside a `repeat` round while Java, C# and TypeScript refuse it | AZ-2176, AZ-2177 flagged concerns | Documented difference; decide with AZ-2127 | unclear |
| 10 | Rust: `cargo fmt --check` reports diffs in older files (`borrowed_count_tests.rs`, `field/order.rs`, `packbin_tests.rs`, …); CI has no format gate | AZ-2178 | Not touched | clear |
| 11 | C#: pack allocation: a Scope per list/dict element and one insert per written field per Pack call (dictionary-path pack 13.9 to 22.4 ms per 100 000) | review F3 (left part) | Accepted; AC-10 holds (163 ms per 100 000 typed round trips) | clear |

## Commit

`[AZ-2175] [AZ-2176] [AZ-2177] [AZ-2178] C# written when, nested rounds, pins`. Body: one line + `Loop: 13`.

## Next Batch: AZ-2179 (cross-language rounds ring: C#, TypeScript, Java, Rust, C++ drivers by package workers; `language-pair.sh` by the parent)
