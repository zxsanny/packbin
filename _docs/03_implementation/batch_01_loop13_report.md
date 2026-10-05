# Batch Report

**Batch**: 1 (TypeScript, Rust and C# as one wave of parallel workers; C# took three rounds)
**Tasks**: AZ-2084_typescript_int_range, AZ-2085_rust_typed_scheme_integrity, AZ-2087_csharp_forward_refs
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2084_typescript_int_range | Done | 3 files (2 src, 1 test) | 119 pass, 0 fail, 3 todo (AZ-2090 construct vectors) | None |
| AZ-2085_rust_typed_scheme_integrity | Done | 15 files (9 src, 6 tests) | 166/166 pass | Composite list/dict elements refused (C18 open) |
| AZ-2087_csharp_forward_refs | Done | 13 files (5 src, 8 tests) | 243/243 pass | Scope grew to the C# part of AZ-2134 (owner decision) |

Shared (parent): `_docs/02_tasks/` (AZ-2087 and AZ-2134 specs, dependency table), `_docs/loops/loop13/plan13.md`. README and component docs wait for step 13 (update-docs).

## Code Review Verdict: PASS_WITH_WARNINGS (after one owner decision and two C# fix rounds)

Round 1, three fresh reviewers (one per package, read-only, scratch copies):

- **TypeScript PASS_WITH_WARNINGS.** Medium F1: the member-name assertion in `int-range.test.ts` passed on the English article "a" (mutation removing the `name:` prefix left tests green). Fixed: the check is `^[a-z]+: ` and a scratch mutant now fails. Low F2 (`fitsInt` type predicate returned false for guarded values) and F4 (no row label on a missing throw) fixed. F3 (release note) goes to step 13. F5 (a `u64` count unpacks as bigint and cannot repack) is pre-existing, recorded below.
- **Rust PASS_WITH_WARNINGS.** No code defect; 17 new lib tests fail on the pre-fix source and pass now; wire bytes of the handoff driver identical; 300k hostile packets, no panic. Medium F1 (docs): a `when` on a utf8/bytes/f32 source with a same-type `eq` worked before and is now refused (AC-5 mandates it), plus the composite-element and multi-name `u2` refusals are not in README or the Rust component doc: **step 13**. Lows not applied: F2 (dead placeholder container names), F3 (redundant early `repeat` panics in `list()`/`dict()`; deleting them was not verified for typed schemes), F4 (`as_int` duplicates other matches, a refactor beyond the ticket), F6 (some AC-6 tests weaker than named).
- **C# FAIL (High, Spec-Gap).** AZ-2087 AC-4's unit row says `Repeat(K, when(K==1, V))`, `{K:[1,2], V:[9]}` "packs only the rounds where K == 1 and round-trips". C# pack drops any value under `when` / `flags` / a group inside a round (identical on HEAD: `01 01 02`). The worker had flagged it; the implementer's AC-4 test was unpack-only. **Owner decision 2026-10-05, option B: fix C# pack slicing inside AZ-2087.** Because pack by round index needs aligned unpack, this is the C# part of AZ-2134 (owner decision U2: aligned everywhere, `null` for a skipped round).
- **C# re-review PASS_WITH_WARNINGS** (36 000 random schemes, ~900 000 rows: zero round-trip failures; 1.1M hostile packets: same accept/reject as HEAD, no exception, no hang; 31 new tests fail on HEAD sources). Medium: unpack memory is now about packet bytes × names in the round (1 MB packet, 36-name `when` body: 337 MB heap against 57 MB); linear, bounded by the scheme, same in Java, Rust and C++; accepted, README untrusted-input note at step 13. Low F2 (mutation gaps: multi-slot `u2`, a group's own member name, zero rounds, group inside flags, nested-row group, `true` vs `1`) and F6 (unused `using`) fixed in round 3; each reviewer mutation now fails a named test. Low F3, F4, F5, F7 are follow-ups (Discovered 12–16).

Reproducing tests changed (reviewed, guards mutation-checked):
- C#: `ZeroWidthElementTests.NeverMatchingWhenListElement_IsError` / `NeverMatchingWhenDictValue_IsError` and `HostileUnpackTests.Times_NeverTrueWhenBodyWithU32MaxCount_ReturnsShortPacketQuickly` used a `when` naming an outer or own-body field, which AZ-2087 makes illegal; they now use a zero-width `Bytes` plus a `when` naming it (same packets, same ShortPacket). With the zero-progress guards removed in a scratch copy all four rewritten tests fail (hang guard timeout or `KeyNotFoundException`). `HostileVectorTests` `zero_progress_repeat_when` is now a construction refusal; `Ac1_RepeatBodyWithANeverMatchingWhen_ReturnsTrailingBytes` keeps a legal hang guard.
- Rust: `round_tests` repeat/times-in-element test and `element_tests` `never_matching_when_element_is_error` became `should_panic` refusals (the spec changes them); the zero-width element guards stay covered by `zero_width_list_element_is_error` and `zero_width_dict_value_is_error`.

## Test Suite

- C# 243 passed; TypeScript 122 (119 pass, 3 todo); Python 103; Rust 166 (135 lib + 8 + 9 + 10 + 4); Java 4 runners, 0 failures; C++ all tests passed
- Failed: 0
- `language-pair.sh`: user, nested, boolflag, booltrue, bitwhen, session and position rings pass across all six languages (C# driver rebuilt on the new walker, Rust driver bytes identical to HEAD)
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {typescript,rust,csharp,python,cpp,java}` (all six exit 0), `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`, `tsc --noEmit --strict` over `typescript/src/index.ts`, `bash .github/workflows/language-pair.sh` (macOS SDK sysroot). The embedded ARM/ESP stages and `publish-gate.test.sh` are not touched by this batch (no C++ or publish change) and run in Run Tests (step 11).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | TS: a `bigint` into a float field was accepted (`Number(10n)`); now refused | AZ-2084 Outcome ("only `number`") | Release note at step 13 | clear |
| 2 | TS: `-0` is a safe integer and packs as 0 | none | Leave | clear |
| 3 | TS: with `u64(n)` driving `sized` / `times` / `packed` the unpacked row holds `n` as a bigint and pack throws "bad count"; an unpacked row cannot repack (HEAD identical) | AZ-2084 Outcome 4 | Follow-up ticket: accept a bigint count | unclear |
| 4 | TS: `repeat` / `times` pack only direct children per item (a `when` or anchored group inside `times` throws `expected number`) | AZ-2090, AZ-2091 concerns | Owned by batch 2/3 or a new TS task; decide before AZ-2091 | unclear |
| 5 | Rust: `when(eq(bool, 0))` never matches an absent or false bool (C++ reads it as 0); the new check allows a bool source but does not refuse `eq 0` on it; packs members that unpack rejects (HEAD identical) | AZ-2085 AC-5; AZ-2126 | Add to AZ-2126 (true-only rule across packages) | unclear |
| 6 | Rust: composite list/dict elements (flags, group, when, repeat, times, sized, bits, packed, `u2` with 2+ names) now refused at construction | AZ-2085 flagged concern C18 | Record in README and the Rust component doc (step 13); parity decision stays with C18 | unclear |
| 7 | Rust: a `when` on a utf8 / bytes / f32 source with a same-type `eq` value worked before and is now refused | AZ-2085 AC-5 | README upgrade note (step 13) | clear |
| 8 | Rust: a `when` naming a name not declared earlier in its scope, or declared only inside a `times` body, is not checked | AZ-2085 AC-5 | Leave; `times` names go with AZ-2086 | clear |
| 9 | Rust: placeholder container names `"__list"` / `"__dict"` / `__list_{id}` are overwritten by `__bound_N`; early `repeat` panics in `list()` / `dict()` are redundant with the integrity rule | review Lows F2, F3 | Cleanup follow-up after checking typed schemes | clear |
| 10 | C#: AC-4's pack leg was false (pack dropped values under `when` / `flags` / groups in a round) | AZ-2087 AC-4 | Fixed here under the owner decision; rule: pack reads each value by round index, `repeat` round count = longest list among all names in the round, `times` = borrowed count; unpack gives one entry per round, `null` skipped | clear |
| 11 | C#: unpack memory is about packet bytes × names per round (null padding) | AZ-2134 U2 | README untrusted-input note; no cap (same in Java, Rust, C++) | clear |
| 12 | C#: typed-row `Unpack` of any repeat / times row throws `InvalidCastException` out of `BinaryPacker.Unpack` (typed members are scalars); pre-existing | AZ-2134 U2 | Follow-up: bind round lists in typed rows or return an error value | unclear |
| 13 | C#: a lone `byte[]` / `List<int>` for a Bytes / Sized / Bits / Packed name under `when` / `flags` is read as a list of rounds (`InvalidCastException` on pack; HEAD dropped it silently) | review Low F3 | AZ-2088 (loud pack errors) or a small follow-up | clear |
| 14 | C#: values of a `repeat` / `times` nested inside a round are silently not packed from the outer round; Java and Rust refuse the scheme at construction | review Low F4 | Owner decision: refuse at construction like Java and Rust | unclear |
| 15 | C#: a lone scalar goes to round 0 only; Java broadcasts it to every round | review Low F5 | Parity decision; AZ-2134 silent | unclear |
| 16 | C#: a list / dict element that is a continuing `Group` with children throws `KeyNotFoundException` on any successful parse (HEAD identical) | review Low F7 | Follow-up ticket | clear |
| 17 | C#: mismatched list lengths in a round stay silent; a `when` that holds with its value absent (`K=[2,1]`, `V=[9]`) packs a packet its own unpack rejects | AZ-2088 | AZ-2088 | clear |
| 18 | C#: count and `when` targets accept any value-bearing kind; C++ and Java limit them to integer or bool | AZ-2087 (not in AC) | Decide with AZ-2126 | unclear |
| 19 | C#: a `when` as a flag-bit inner has an empty name, so its bit never turns on | AZ-2120 | AZ-2120 | clear |
| 20 | `bool` under flags unpacks as `[true, null, true]` in C# rounds; the TS and Python lists still append only set rounds until AZ-2134 | AZ-2134 | AZ-2134 (TypeScript, Python) | clear |

## Commit

`[AZ-2084] [AZ-2085] [AZ-2087] Range check, typed integrity, ref scope`. Body: one line + `Loop: 13`.

## Next Batch: AZ-2090 (TypeScript), AZ-2086 (Rust), AZ-2088 (C#)
