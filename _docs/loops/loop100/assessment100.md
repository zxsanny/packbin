# Feature assessment — loop 100

loop: 100
feature: dart-typescript-alignment
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-11-11
**Implement pass**: batch 01 (`_docs/03_implementation/batch_01_loop100_report.md`), commits 4993aee and f955079
**Verdict**: COMPLETE — 15 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A text or key with half of an emoji packs as U+FFFD | covered | AC-1 (AL-1, AL-2); `dart/test/collections/lone_surrogate_test.dart` (16 TypeScript packets, 3 key orders), `text/text_hostile_test.dart`; `lib/src/text/text_encode.dart` `_codePoints`, `lib/src/collections_pack.dart` `_dict` | intake |
| S2 | Two keys collide after the swap | covered | AC-2 (AL-3); `lone_surrogate_test.dart` `two keys that are the same once the halves are U+FFFD are refused`; `collections_pack.dart` `_dict` | intake |
| S3 | A hostile key order or text | covered | AC-4, AC-5 (AL-5, AL-9); `dict_order_test.dart`, `text_refusal_short_test.dart` (29 fixture rows, 5 hand-made), `hostile/hostile_test.dart` (7 rule texts); `collections_unpack.dart` `readText`, `collection` | intake |
| S4 | A valid dictionary, a valid text, a buffer cut inside a text | covered | AC-4, AC-5; `dict_order_test.dart` `keys that ascend by UTF-8 bytes ... are read`, `text_refusal_short_test.dart` `a buffer that ends inside the text...`, `text/text_vectors_test.dart` (418 rows); `collections_unpack.dart` | intake |
| S5 | A clear message one byte over its parity | covered | AC-3 (AL-4); `ecc/pack_too_long_test.dart` (3 counts, 4 percentages, `maxBytes` first, unpack `too_long`), `count_vectors_test.dart`, `percent_vectors_test.dart`; `ecc/codec.dart` `protect`, `ecc/percent.dart` `protectPercent` | intake |
| S6 | A packet with 0 rounds unpacked and packed again | covered | AC-6 (AL-6); `rounds/zero_rounds_places_test.dart` (15 places), `zero_and_short_test.dart`, `typed_rounds_test.dart` (typed `[]`); `lib/src/rounds_unpack.dart` `readRounds` | intake |
| S7 | An empty `nested` row under flags and elsewhere | covered | AC-7, AC-8 (AL-7, AL-8); `collections/empty_nested_test.dart` (2 places, 5 refused places), `construction_test.dart`; `collection_fields.dart` `nested`, `checks.dart` `checkIds`, `checkMarks` | intake |
| S8 | Everything not named stays as it was | covered | AC-9 (AL-10); 2,001 of 2,001 Dart tests, 957 parity rows, shared fixtures 0 changed (`git diff --stat` shows `fixtures/hostile/README.md` only); `dart format` 0 changed, `dart analyze --fatal-infos` 0 issues | intake |
| D1 | An empty nested mark takes no id | covered | AC-7; `empty_nested_test.dart` (a row under flags numbers its fields as before); `checks.dart` `checkIds` | batch_01 discoveries |
| D2 | `g: {}` for the empty nested mark is refused | covered | AC-7 and the flagged concern (accepted-risk); `empty_nested_test.dart` `a value that is not a bool is refused naming the mark`; `pack.dart` mark check | batch_01 discoveries |
| D3 | c13: Dart repacks `01000309`, TypeScript `01000209` | covered | AC-6 and the owner's `g: {}` choice; `zero_rounds_places_test.dart` `c7, c8 and c13...` | batch_01 discoveries |
| D4 | TypeScript writes an unreadable packet for colliding keys | out-of-scope | spec `### Excluded` line: "Fixing TypeScript's unreadable packet for colliding keys (follow-up, leftover of this loop)" | batch_01 discoveries |
| D5 | Byte count of a too long text counts a lone half as 3 | covered | AC-1; `text_hostile_test.dart` `the length of a too long text counts a lone half as U+FFFD`; `text_encode.dart` `_utf8Bytes` | batch_01 discoveries |
| D6 | A refused text has no `reason` | covered | AC-5; `text_refusal_short_test.dart`; `hostile_rules.dart` texts | batch_01 discoveries |
| D7 | `nested(...).bind` of an empty nested in a typed row built and unpack threw a `TypeError` | covered | AC-8 and "unpack never throws on input bytes" (DT-4); found by a probe at assessment time, fixed in f955079; `empty_nested_test.dart` `a typed row cannot bind an empty nested...`, `the typed mark is groupOf bound to a bool`; `collection_fields.dart` `NestedField.bind` | assess-round-1 |
| A1 | The empty nested mark as the member of a `repeat` round | covered | AC-7; probe in the session scratchpad (`typed_probe/bin/q.dart`): the output equals `groupOf`'s for 3 rows and 2 wires; the same code path as the `groupOf` mark of `rounds_pack.dart` | assess-round-1 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None. The one gap found (D7) was fixed in this loop before the verdict.

### Not walked

- none

### Harness gaps

- A1 (the mark in a round) is checked by a scratchpad probe and by the shared code path, not by a committed test; a committed test would need one more row in `empty_nested_test.dart` (Low, no behaviour risk).
