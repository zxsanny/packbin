# Batch Report

**Batch**: 1 (loop 100)
**Tasks**: AZ-4153_dart_typescript_alignment
**Date**: 2026-11-11

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-4153_dart_typescript_alignment | Done | 12 library files, 17 test files (5 new), 6 doc files, 4 spec/plan files | 1,999 of 1,999 pass | None |

Library files: `collections_unpack.dart` (D8), `ecc/codec.dart`, `ecc/percent.dart`, `errors.dart`, `scheme.dart` (D7), `text/text_encode.dart`, `text/text_types.dart`, `utf8_order.dart`, `collections_pack.dart`, `collection_fields.dart` (D1, D10), `rounds_unpack.dart` (D6), `checks.dart` (D10).
New tests: `ecc/pack_too_long_test.dart` (AL-4), `collections/lone_surrogate_test.dart` (AL-1 to AL-3, 16 TypeScript packets), `collections/text_refusal_short_test.dart` (AL-9, 29 fixture rows and 5 hand-made), `collections/empty_nested_test.dart` (AL-7, AL-8), `rounds/zero_rounds_places_test.dart` (AL-6, 15 places).

## Code Review Verdict: PASS_WITH_WARNINGS

One independent total review of `git diff 0a678be..HEAD -- dart/lib` (a reviewer given the code and the criteria, not my conclusions): no High or Medium finding; 0 byte mismatches against TypeScript in 6,000 text and dictionary cases, 798 parity limits, 66,430 strings of `replaceLoneSurrogates` against a UTF-8 round trip, and 1.4 million hostile or mutated unpacks with 0 exceptions. Three Low findings, all fixed in the same loop (commit after f955079): the `ErrorKind.short` and `badValue` docs, a needless copy in `replaceLoneSurrogates` for a valid pair, and the message for an unbound mark in a typed scheme (it sent the user to a dead end; one older test pinned the old wording and was updated).

## Test Suite

- Total: 2,004 tests (1,919 at the end of loop 99)
- Passed: 2,004
- Failed: 0
- Skipped: 0
- `dart format --set-exit-if-changed` 0 changed in 159 files; `dart analyze --fatal-infos` 0 issues; seeded run seed 343166603, 7,193 inputs, 347,881 unpack calls, 0 failures.
- CI-parity: PASS (`dart format --set-exit-if-changed .`, `dart analyze --fatal-infos`, `dart test`, the commands of the CI Dart suite, on Dart 3.13.5; CI runs 3.13.7).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | An empty `nested` mark takes no id of the row around it (an anchored `groupOf` mark takes its anchor), so `checkIds` skips an id-less member-less group | AC-7 | done: the mark has no id, so a row under `flags` numbers its fields as before | clear (TypeScript's unanchored group takes no id; `problem.md` row D10) |
| 2 | `{h: 9, g: {}}` for the empty `nested` mark is refused (a mark is a `bool`), where TypeScript clears the bit | AC-7 | kept, as the `groupOf` rule and Go-1/Go-4; recorded as a flagged concern | clear (owner answer: same rules as `groupOf`) |
| 3 | In case c13 TypeScript repacks `01000209` and Dart `01000309` because Dart keeps `g: {}` | AC-6 | kept, owner choice "keep g: {}" | clear |
| 4 | TypeScript packs two keys that collide after U+FFFD into an unreadable packet | AC-2 | Dart refuses; TypeScript fix is a follow-up in the loop record | clear (owner decision) |
| 5 | The byte count of a too long text now counts a lone half as 3 bytes (it counted 2, used only in the refusal detail) | AC-1 | done, `text_hostile_test.dart` `the length of a too long text counts a lone half as U+FFFD` | clear |
| 6 | The unpack error of a text or key refusal has no `reason` any more (a short packet has none) | AC-5 | done; the hostile rule texts carry `needed` and `left` only | clear (Go and Swift give the same) |
| 7 | `nested('g', []).bind<Row>(...)` in a typed row built as a mark, and unpack of `010309` threw a `TypeError` out of `unpackRow` (found by a probe at assessment time) | AC-8 | fixed in a second commit: `NestedField.bind` of an empty nested is refused at build; the typed mark is `groupOf(...).bind`; tests `a typed row cannot bind an empty nested...` and `the typed mark is groupOf bound to a bool` | clear (AL-8 and `problem.md`: "a typed mark is groupOf with bind"; unpack never throws on input bytes) |

## Commit

`[AZ-4153] Dart: align five choices with TypeScript` with body and `Loop: 100`.

## Next Batch: All tasks complete
