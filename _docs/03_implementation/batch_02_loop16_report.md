# Batch Report

**Batch**: 2 (loop 16)
**Tasks**: AZ-2188, AZ-2128 (TS part), AZ-2183, AZ-2184, AZ-2197 (TypeScript); AZ-2128, AZ-2114, AZ-2121 AC-4 (Rust); AZ-2101, AZ-2128, AZ-2114, AZ-2121 (Java); AZ-2100, AZ-2134, AZ-2128 (Python)
**Date**: 2026-10-06

Four package workers in parallel, one directory each, a review per package, a fix pass after the review (four owner decisions) and a delta review of the Python fix with a second fix pass. Docker suites, the cross-language ring and the hostile-file checks run by the parent.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2188_typescript_duplicate_member_names | Done (option B, AC-1 to AC-7) + element scopes (review TS-F2) | `member-names.ts`, 2 existing tests rewritten, 1 new test file | in the 425 | two existing tests pinned duplicates the spec refuses (spec-sanctioned) |
| AZ-2183_typescript_flags_under_split_bit | Done (AC-1 to AC-7) | `fields.ts`, `pack-fields.ts`, 1 new test file, `tests/support/random.ts` | in the 425 | none |
| AZ-2184_typescript_dict_keys_not_flattened | Done (AC-1 to AC-7) + TS-F1 | `fields.ts`, `index.ts`, `pack-fields.ts`, 1 new test file | in the 425 | nested value wins when a flat key and a group object disagree (pinned) |
| AZ-2197_typescript_when_on_written_values | Done (AC-1 to AC-6; AC-6 by the ring) | `pack-fields.ts`, `index.ts`, 1 new test file | in the 425 | `eq(id, undefined)` follows unpack (owner A) |
| AZ-2128, TypeScript part | Done (AC-1 to AC-3) | new `flag-bits.ts`, `kinds.ts` (dead code removed) | in the 425 | `when` / `times` / `repeat` as a flags member held (owner C) |
| AZ-2128, Rust part | Done (AC-1 to AC-3) | `walk/pack.rs`, `field/mod.rs` doc, 1 new test file | in the 288 | same open concern |
| AZ-2114, Rust part | Done (tests only) | 1 new test file | in the 288 | README scheme for `01 00 ff` is refused at construction in Rust: a zero-width `bytes` repeat stands in |
| AZ-2121 AC-4, Rust | Done (tests only) | `element_tests.rs` | in the 288 | none |
| AZ-2101_java_typed_nested_rows | Done (AC-1 to AC-6, owner decision followed) | 6 src, 1 new test file | in the 1210 checks | new overload; old overload refused on a typed row (source-breaking); presence-under-flags change beyond the ACs accepted |
| AZ-2128, Java part | Done (AC-1 to AC-3) | `Walker.java`, 1 new test file | in the 1210 checks | same open concern |
| AZ-2114, Java part | Done (tests only) | 1 new test file | in the 1210 checks | same stand-in as Rust |
| AZ-2121, Java parts | Done (AC-2, AC-4, tests only) | 1 new test file | in the 1210 checks | none |
| AZ-2100_python_split_form_repeat | Done (AC-1 to AC-9); one Included line open (bit numbering by scheme order) | `_validate.py` (new), `_nodes.py`, `_pack.py`, `_unpack.py`, `_scheme.py`, 3 new test files | in the 286 | see Discovered |
| AZ-2134, Python part | Done (AC-1, AC-2; AC-3 C#, AC-4 existing) | same files | in the 286 | aligned lists cost one slot per name per round: limits added |
| AZ-2128, Python part | Done (AC-1 to AC-3) | `_pack.py` | in the 286 | same open concern |
| Python round and slot limits (review PY-F1, owner A) | Done | `_unpack.py`, `_scheme.py`, `test_round_limits.py` (37 tests), vector replay | in the 286 | new public API `Scheme.with_limits` |
| Python nested rounds refused (review PY-F2, owner A) | Done | `_validate.py` | in the 286 | none |

## Code Review Verdict: PASS_WITH_WARNINGS

Report: `_docs/03_implementation/reviews/batch_02_loop16_review.md`. First verdicts: three PASS_WITH_WARNINGS and Python FAIL (High, security); a delta review of the Python fix found a second High in the same control (element runs not priced), fixed in a second pass. Four owner decisions applied (Python limits, Python nested rounds, TypeScript `eq(id, undefined)`, hold `when` / `times` / `repeat` under flags for the C# loop).

## Test Suite

CI-parity run by the parent after the fix passes, one stage at a time:

- TypeScript (node 24, Docker): 425 of 425 (was 323); strict `tsc` clean.
- Python (3.14, pinned pytest 9.1.1, Docker): 286 passed (was 190).
- Rust (1.98, Docker): 288 passed, 0 warnings (was 261).
- Java (JDK 26, Docker): all four mains pass; 1210 checks counted on the host (was 1064); api-check PASS; `javadoc --release 17` exit 0.
- `report-row.test.sh` and the hostile case file checks: pass.
- `language-pair.sh` (committed HEAD for C# and C++, loop 16 changes for the other four): PASS in 71 s on an overlay tree, so the owner's uncommitted C# work is not in the gate.

Evidence: golden, route and hostile fixtures unchanged; wire bytes of rows that packed before unchanged except the documented fixes (differential runs against HEAD in the review). Python memory at default limits for a 1 MiB packet: one-byte rounds in a `repeat` with a 36-name `when` body refused at round 65,536 in about 39 MiB and 0.27 s (392 MiB and 4.2 s without limits); the same body inside 65,535 list elements refused after about 53 MiB in 0.3 s (276 to 479 MiB before the per-run charge).

CI-parity: PASS locally. Linux-only parts: none new.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `when`, `times` and `repeat` as a `flags` member or flag-bit field are silently dropped on pack in TypeScript, Rust, Java and Python; for the AZ-2120 shape all give `01 01 02 5a00` and C# will give `01 01 03 07 5a00` | AZ-2128 flagged concern, AZ-2120 AC-2 | HELD by the owner (2026-10-06) for the loop that lands the C# work | unclear (owner decided: hold) |
| 2 | TypeScript: two declarations inside the same `when` body still build and write the value twice; a group inside a `repeat` round given as `g:[{a:1},{a:2}]` and an anchored group as a direct list or dict element throw `missing a` (pre-existing) | AZ-2188, AZ-2184 | ticket or refuse at construction | unclear (owner) |
| 3 | Python: bit numbers follow `.bit()` call order, not scheme order; a handle shared by two schemes is refused where TypeScript builds both | AZ-2100 Included line, review PY-F4 | add Python to AZ-2135 | unclear (owner) |
| 4 | Python: `repeat(k, when(k==1, v))` with `k=[1,2], v=[9]` raises "repeat fields must have equal lengths" where TypeScript, C# and Java let the longest list set the count; `times` with a short list raises a bare `IndexError` | AZ-2134, review PY-F6 | relax Python or keep refusing (owner) | unclear |
| 5 | Python: `PackSession.load(32)` returns a session keyed by 32 zero bytes | AZ-2104 | guard `load` for bytes-like input | unclear |
| 6 | Python (pre-existing): a `bool` under `flags` inside a `times` read the row list (closed here by AZ-2134 AC-2); a scheme with a `flag_byte()` node and its `.bit(...)` nodes could not be built (closed here by AZ-2100) | batch 1 #8 | closed | clear |
| 7 | Java: a flag byte outside a nested row with its bit inside builds and packs unreadable bytes; a null nested member or null list element is dropped silently on pack; `u2` inside a round ignores the round item; typed element groups still unpack into a `Map` (all pre-existing) | AZ-2101, AZ-2127 | follow-up specs | unclear (owner) |
| 8 | Java: a typed row with a Map-valued member that used the old `group` overload now fails at construction (use `group(get, set, HashMap::new, ...)`) | AZ-2101 | upgrade note | clear |
| 9 | Rust: a `flag_byte` as a direct `flags` member is never written (pre-existing); `nfr_round_trips_under_one_second` is wall-clock and failed once above 1 s under load average 47 | review | follow-up | unclear |
| 10 | Rust, Java, Python tests of AZ-2114 use a zero-width `bytes` repeat for `01 00 ff` because the README `when` scheme is refused at construction in those packages | AZ-2114 | note in the spec (done) | clear |
| 11 | An f32 tested by `eq` is compared after rounding to 32 bits in TypeScript pack (a 0.1 `eq` on f32 never matched on unpack) | AZ-2197 | falls under AZ-2126 if floats are refused | clear |
| 12 | Docs to update in step 13: README (lines 896, 917 to 921, 1041, 1053, 1064 to 1076, 1090 and the Java, Rust, Python and TypeScript upgrade notes), `fixtures/hostile/README.md` (lines 12, 111, 134 and the two `limit` sections), `_docs/AGENT_GOTCHAS.md`, `_docs/05_security/security_report.md`, component descriptions for TypeScript, Rust, Python, `module-layout.md` | all | step 13 docs pass | clear |

## Commit

`[AZ-2188] [AZ-2101] [AZ-2100] Fix flag groups, dup names, typed rows, limits` (≤72 chars). Body: one line per package + ticket ids + `Loop: 16`.

## Next Batch: B3 (TypeScript: AZ-2103, AZ-2115, AZ-2135; Java: AZ-2135; C++: AZ-2135; Harness: AZ-2099, AZ-2193, Python `bitwhen` ring) then B4 (AZ-2098)
