# Batch Report

**Batch**: 2 (TypeScript, Rust and C# as one wave of parallel workers; Rust took three rounds, TypeScript and C# two)
**Tasks**: AZ-2090_typescript_reference_scope, AZ-2086_rust_typed_times_vec, AZ-2088_csharp_pack_fails_loudly
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2090_typescript_reference_scope | Done | 12 files (6 src, 6 tests) | 158/158 pass, 0 todo (the 3 construct-vector todos are real) | Pack of a `when` / group inside a round still throws (owner: AZ-2091, batch 3) |
| AZ-2086_rust_typed_times_vec | Done | 18 files (8 src, 10 tests) | 206/206 pass | Public API change (owner decision); unpack memory ~8x (accepted) |
| AZ-2088_csharp_pack_fails_loudly | Done | 14 files (6 src, 8 tests) | 345/345 pass | Shared `FlagGroup` state (owner: follow-up) |

Shared (parent): `_docs/loops/loop13/plan13.md` (batch 2/3 divergence), the AZ-2090 / AZ-2086 / AZ-2088 spec moves to `done/`. README and component docs wait for step 13.

## Code Review Verdict: PASS_WITH_WARNINGS (after one owner escalation and fix rounds)

Round 1, three fresh reviewers (read-only, scratch copies, oracle fuzz and HEAD differentials):

- **TypeScript PASS_WITH_WARNINGS** (0 High, 0 Medium, 3 Low). A port of the C++ `find_ref` as an oracle over 8 x 40 000 random schemes: 0 accept/reject mismatches; deep-frozen input fields over 20 000 schemes: 0 mutation errors; 16 + 4 binder mutants killed. Lows fixed in round 2: four surviving mutants (u2 slots as count sources, loose `==` in `sameValue`, a dict element sharing the parent scope, `sized`/`bits`/`packed` as `eq` sources) now fail named tests; `f.ref!` at ten sites replaced by `refName`, which throws `reference is not bound`; `ref` removed from the exported `Field` type (`index.d.ts` byte-identical to HEAD).
- **Rust FAIL (2 High, 2 Medium, 3 Low).** High F1: a times element compiled with its own generated-name counter, so unnamed containers repeated `__bound_N` names across scopes and unpack overwrote a parent list with a list of lists (`l: []` instead of `[7]`). High F2: map-form pack took the retained `__times_<anchor>` Groups and silently ignored edited per-name lists (HEAD honored the edit). **Owner decision 2026-10-05, option A: fix both now.** Round 2: elements compile lazily with the parent's counter; `check_lists` rebuilds every declared member list from the rounds and returns `PackError::Type("times at id N: list for 'x' disagrees with its rounds")` on a mismatch; unpack always returns `__times_<anchor>` (empty for count 0, so the setter always runs); 4-round and 3+-round tests added. Re-review PASS_WITH_WARNINGS: F1, F2, F6 fixed (60 000 collision-fuzz rows: 0 mismatches; round-1 code 2 409 of 3 000); 700 000 random map packets: identical accept/reject to HEAD, lists-only values pack byte-identically; 300 000 typed rows: 0 failures. Round 3 closed the re-review's Lows: R1 (a scalar edit beside the rounds is compared as a one-item list), R2 (rustdoc), R4 (11 map-form tests; every surviving mutant killed). Medium F3 (unpack memory) accepted, README note at step 13; Medium F4 (a `times` as a `flags` member never packs, pre-existing) deferred, follow-up; Low R3 (a map scheme reusing one member name in two times cannot repack unedited values) left.
- **C# PASS_WITH_WARNINGS** (1 Medium, 5 Low; the review stalled once and was resumed). A differential of 55 000 flat schemes (about 660 000 rows) plus 27 000 repeat/times schemes: identical bytes HEAD vs new, 0 new throws; of about 1M perturbed rows every difference is new throw / old bytes (a required value missing); 200 000 parallel packs with one shared `Condition`: 0 wrong (HEAD: 200 000 wrong); 41 of the new tests fail on HEAD sources. Medium F1 (a `FlagGroup` and the caller's params arrays are still shared mutable state; `flagByte.Bit(x)` after construction still changes a built scheme; identical on HEAD): **owner decision, follow-up ticket**. Lows fixed in round 2: row-type refusal tests for nine field kinds, integer-vs-float `when` tests, a concurrency test, readable generic type names in the message, a stray `// Act`. Open Lows: F3 (release notes), F4 (a lone `byte[]` under `times` gives a misleading message), F6 (pre-existing).

Reproducing tests changed (reviewed, guards mutation-checked):
- TypeScript: `hostile.test.ts` zero-progress `repeat` / `times` cases and `runSession` used a `when` naming an outer field inside a body, which AZ-2090 refuses; they now use a zero-width `bytes(1, v, 0)` plus a never-matching `when(2, eq(1, 9), …)` (same packets and expectations); with the repeat or times zero-progress guard removed in a scratch copy they fail. `never_matching_when_element_is_error` became a construction refusal (a `when` in a list element has nothing earlier in its scope); the zero-width element guard stays covered by `row7_list_of_list_zero_width` and `row7_dict_zero_width_value*`. `value-fidelity` "when outside the repeat" asserts the refusal; `flag-scope` test gained a leading `u8` so its `when` names an earlier field; the 3 `PENDING_CONSTRUCT` todos are real tests.
- Rust: two tests that called the old three-argument `SchemeItem::times` changed call syntax only (`flag_bits_tests`, `round_tests`); expected panics unchanged.
- C#: `FieldIdBindingTests.Ac4_NestedRowTypeHasOwnIds` declared a field of `MarkerRow` in a `PointsRow` scheme; corrected (`U16<PointsRow>`), asserts kept, as the spec says.

## Test Suite

- C# 345 passed; TypeScript 158 (0 todo); Python 103; Rust 206 (159 lib + 8 + 9 + 10 + 4 + 2 + 3 + 11); Java 4 runners, 0 failures; C++ all tests passed
- Failed: 0
- `language-pair.sh`: user, nested, boolflag, booltrue, bitwhen, session and position rings pass across all six languages (Rust and C# driver bytes identical to HEAD)
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {typescript,rust,csharp,python,cpp,java}` (all six exit 0), `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`, `tsc --noEmit --strict` over `typescript/src/index.ts`, `bash .github/workflows/language-pair.sh` (macOS SDK sysroot). Embedded stages and `publish-gate.test.sh` are untouched by this batch and run in Run Tests (step 11).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | TS: `eq` may name any value field (float, bytes, utf8, bool, sized/bits/packed) and a `u2` slot counts as an integer; TS refuses a count that names a `bool`; C++ and Java limit sources to integer or bool | AZ-2090 rules | Decide with AZ-2126 (true-only `eq` on bool) | unclear |
| 2 | TS: `Scheme.fields` now returns copies of the five reference kinds; `nameById` and the `allFields` parameter of `unpackFields` removed (internal) | AZ-2090 "no public API change" | Release note | clear |
| 3 | TS: nested `flags` inside a group do not round-trip (pack writes a clear inner flag byte) | AZ-2091 | AZ-2091 (batch 3) | clear |
| 4 | TS: pack of a `when` / anchored group inside `repeat` / `times` throws `RangeError: v: expected a number for u8, got object` | AZ-2090 and AZ-2091 flagged Medium | Owner decision 2026-10-05: fix in AZ-2091 (the TypeScript part of AZ-2134: pack by round index, aligned unpack) | clear |
| 5 | Rust: typed `times` is `SchemeItem::times(anchor, count_id, get, set, members)` with `E: Default + 'static`; the old three-argument form and the `SchemeItem::Times` struct variant are gone | AZ-2086 owner decision "fix it" | README and Rust component doc at step 13 | clear |
| 6 | Rust: map-form unpack returns both the per-name lists and `__times_<anchor>` Groups (always present, empty for count 0); pack with both checks the lists against the rounds and fails with `list for 'x' disagrees with its rounds`; edit the rounds and drop or rewrite the lists, or edit the lists and drop the key | AZ-2086 R-P6 | README edit rule at step 13 | clear |
| 7 | Rust: unpack keeps one row per round: 1 MB packet with 1-byte rounds peaks at 312 MB RSS (HEAD 37 MB), 1.42 GB for a `times[flags × 8 bools]` worst case (HEAD 465 MB); linear, count never pre-allocated; the typed path never reads the per-name lists | AZ-2086 NFR | README untrusted-input note; streaming or compact rounds as a possible follow-up | unclear |
| 8 | Rust: a `times` as a `flags` member builds but its bit never sets, so its rounds are never packed (map form on HEAD too; the typed `Vec` form now reaches it) | review F4 | Follow-up: refuse in `shape.rs` at construction | unclear |
| 9 | Rust: a map scheme that reuses one member name in two `times` cannot repack unedited values (errors loudly; HEAD errored too) | review R3 | Leave | clear |
| 10 | Rust: `when` / element-id panics for a typed `times` moved from the `SchemeItem::times` call to `Scheme::new` (lazy compile) | AZ-2086 | Note in the component doc | clear |
| 11 | C#: `FlagGroup` and the caller's params arrays stay shared mutable state; `flagByte.Bit(x)` after construction changes a built scheme; a replaced element of a `params` array changes the layout | AZ-2088 Outcome | Follow-up ticket (owner decision): clone each `FlagGroup` per scheme in `SchemeOrder.Resolve` | clear |
| 12 | C#: a child-row field used directly in the parent scheme (`Field.U8<Child>` in `Scheme<Parent>`) packed correctly on HEAD and now fails at construction; an F32 source with a double-literal condition (`Eq(0, 0.1)` against `0.1f`) matched on pack and not on unpack on HEAD, now matches on neither (Java rule) | AZ-2088 AC-5, AC-6 | Upgrade note at step 13 | clear |
| 13 | C#: a lone `byte[]` under `times` longer than the count now throws `'T' holds 2 items, but the times count is 1` (misleading); under `repeat` it is still `InvalidCastException` | review Low F4 | Follow-up | clear |
| 14 | C#: `when` is evaluated on the row values, so pack can return bytes its own `Read` rejects (1 of about 394 000 random perturbed rows; Java evaluates `when` on `seen`) | review Low F6, pre-existing | Follow-up | unclear |
| 15 | C#: the README `List<Role>` example fails with `RoleName: expected string` on HEAD and now | AZ-2092 (task 23) | AZ-2092 | clear |
| 16 | C#: the AZ-2088 spec's Defect 3 probe (data F = NaN, inf, 1e30) already passed on HEAD (`IsDecimalRange` from loop 9); what was broken is a condition value out of decimal range (`OverflowException`) and the Java rule (NaN equals NaN, -0.0 differs from 0.0) | AZ-2088 Defect 3 | Spec text is stale; fixed | clear |
| 17 | C#: a lone scalar goes to round 0 only (Java broadcasts it); a repeat/times nested in a round is not packed from the outer round (Java and Rust refuse the scheme); a list/dict element that is a continuing `Group` throws `KeyNotFoundException` on unpack | batch 1 items 14–16 | Unchanged here; follow-ups / owner decisions | unclear |
| 18 | C#: typed-row `Unpack` of any repeat/times row throws `InvalidCastException` (pre-existing) | batch 1 item 12 | Follow-up | unclear |

## Commit

`[AZ-2090] [AZ-2086] [AZ-2088] Typed times, reference scope, loud pack`. Body: one line + `Loop: 13`.

## Next Batch: AZ-2091 (TypeScript nested-group fixes plus the TypeScript round slicing, owner decision 2026-10-05)
