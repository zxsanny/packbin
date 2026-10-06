# Batch Report

**Batch**: 6 (loop 16, round 3 after feature assessment round 2)
**Tasks**: AZ-2243, AZ-2244, AZ-2245, AZ-2246, AZ-2247, AZ-2248, AZ-2249
**Date**: 2026-10-06

Owner answers to the assessment (2026-10-06): X3, X4, X5 all option A; X5 confirmed a second time after the spec author found it also breaks pack-only callers with object elements; X1 and X2 were gap-clear. Spec authors reproduced every probe, one worker per package (TypeScript, Python, Rust, Java) on disjoint paths. By the owner's direction (2026-10-06) there is no per-batch review and no per-batch Docker run: the workers ran their own package suites and differentials, one total review and one total test run follow at the end of the loop. Only the TypeScript review had finished when the direction came (PASS, no findings); the Rust, Python and Java reviews were stopped.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2243_typescript_session_load_uint8array_only | Done: `PackSession.load` returns `null` for anything that is not a `Uint8Array` or `Buffer` of 32 bytes | `typescript/src/index.ts` (+7/-1, `isUint8Array` brand check), `tests/session.test.ts` (+178) | TypeScript 463 to 470; strict tsc 0; reviewer PASS (59 input classes, 5 mutants) | a deliberate `Symbol.toStringTag` tamper returns `null`; optional hardening with the `%TypedArray%` tag getter (owner) |
| AZ-2244_python_session_start_join_bytes_only | Done: `start` returns `None` and `join` returns `False` for a nonce that is not bytes, bytearray or memoryview of 16 bytes; `load`, `start`, `join` share `_exact_bytes` | `python/src/packbin/_session.py` (+20/-13), `tests/test_session.py` (+243) | in the Python count | 160 of 2,840 differential calls changed, all length 16 and not bytes-like; constructor list seed unchanged (excluded) |
| AZ-2245_python_duplicate_member_name_refused | Done: `Scheme(...)` raises `ValueError` for a member name (accessor key) declared twice in one scope, also outside and inside a round; names under different `when`s allowed | `_nodes.py` (access mark), `_validate.py`, `_scheme.py`, new `tests/test_duplicate_names.py` (35) | in the Python count | 3,098 of 6,000 random schemes refused, each flagged by an independent oracle of the TypeScript rule; `r.x` and `r["x"]` count as different names (owner option: match by key only) |
| AZ-2246_java_duplicate_member_name_refused | Done as the spec's option A: a key set twice through `Access.set(String)` in one scope is refused; typed accessors and lambdas are not named | `Access.java` (`KeySetter`), new `MemberNames.java` (53), `Scheme.java` (+1), new `DuplicateNamesTest.java` (317, +124 checks) | all Java checks pass; 35,000 random schemes, 0 mismatches; `javap -public` identical | options B, C, D (name the other accessors) are the owner's; a repeated key in a nested row under a `when` builds (the list/dict element case was fixed after the total review) |
| AZ-2247_rust_duplicate_member_name_refused | Done: `MapScheme::new` and `Scheme::new` panic for a data name declared twice in one scope (also across a round, either order) | new `rust/src/field/names.rs` (73), `field/map_scheme.rs`, `field/mod.rs`, `lib.rs`, new `duplicate_names_tests.rs` (320) and `duplicate_names_kept_tests.rs` (210) | Rust 331 to 360 | `u8 "x"; repeat{u8 "x"}` round-tripped and is refused now (the owner's rule; flipping it is one line); a flag-byte name equal to a data name still builds (excluded) |
| AZ-2248_python_times_short_list_optional_member | Done: a short or empty `times` list for a member under `flags` or a flag bit is absent for the missing rounds, as in TypeScript and Java | `_nodes.py` (`_Times.optional`, `_optional_leaves`), `_flag_scope.py`, `_pack.py`, new `tests/test_times_short_list.py` (21) | in the Python count | 15,000 random rows: Python equals TypeScript on all; `repeat` keeps its rule (spec STOP item, owner) |
| AZ-2249_python_element_group_attribute_accessor_refused | Done as option A: `Scheme(...)` refuses an attribute accessor inside a list or dict element group | `_validate.py`, `_scheme.py`, new `tests/test_element_accessors.py` (39) | Python 326 to 492 (485 from the four specs, +7 after the total review) | breaks callers that only pack objects as elements (owner confirmed twice); identity accessor in an element group left (STOP option B) |

## Code Review Verdict

TypeScript: PASS, no findings (one reviewer, 59 input classes against HEAD, dist and strict tsc checked, five mutants). Rust, Python and Java: not reviewed per change (owner direction); covered by the one total review of the loop.

## Test Suite

Worker-run only, host toolchains (no Docker per the owner's direction): TypeScript 470 pass and strict tsc exit 0; Python 492 pass (485 plus 7 after the total review); Rust 360 pass (282 lib, 78 integration; debug and release); Java all checks pass and `api-check` PASS (Android API 26), javadoc exit 0. Differentials against `git archive HEAD` exports per spec: Python start/join 2,840 calls, duplicate names 6,000 schemes, short list 15,000 rows (and against TypeScript), element accessors 6,000 schemes; Rust 280,000 schemes; Java 35,000 schemes; TypeScript 3,000 seeds x 3 shapes. The drivers (`handoff.py`, `handoff.ts`, the Java and Rust hand-off drivers, `position.*`) give identical output at HEAD and now. The total test run (step 11) covers the Docker toolchains.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Java names only `Access.set(String)` members; typed accessors and hand-written lambdas stay unchecked; a repeated key in a nested row under a `when` builds (the list/dict element case was fixed after the total review) | AZ-2246 Risk 1 | owner options B (probe a recording Map), C (add names to the API), D; the nested-row `when` case is the same as two declarations in one `when` body | unclear |
| 2 | Rust `repeat` clash round-tripped and is refused; a flag-byte name equal to a data name builds; two declarations inside one `when` body build in all packages | AZ-2247, AZ-2245, AZ-2246 | owner; one-line flip for `repeat` | unclear |
| 3 | Python names are accessor keys (`r.x` and `r["x"]` differ); `repeat` does not follow `times` for a short list; identity accessor in an element group; constructor `PackSession([7]*32)` | AZ-2245, AZ-2248, AZ-2249, AZ-2244 | owner | unclear |
| 4 | TypeScript constructor accepts a 5-byte key; `start`/`join` still throw for a non-Uint8Array nonce; brand hardening | AZ-2243 | owner | unclear (low) |
| 5 | The TypeScript `unpack` handler typing: `SchemeHandler<object>` is invariant, a typed row's handler needs `as SchemeHandler<any>` (README examples cast) | README check, round 2 | a spec in loop 17 | clear |
| 6 | Feature assessment round 3 is not run: the owner stopped the expansion of todo; the angles open after round 2 go to the loop 17 handoff | `_docs/loops/loop17/handoff17.md` | | |

## Commit

`[AZ-2243] [AZ-2247] [AZ-2249] Refuse repeated names, bad seeds and elements`. Body: the seven ids, one line per package, `Loop: 16`.

## Next: finish docs and state, write the loop 17 handoff, one total review, one total test run, then security (14), retrospective (17) and the loop close
