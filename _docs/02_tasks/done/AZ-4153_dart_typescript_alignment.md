---
loop: 100
branch: dev
---

# Dart: align five choices with TypeScript

**Task**: AZ-4153_dart_typescript_alignment
**Name**: Dart: align five choices with TypeScript (loop 100)
**Description**: The Dart package takes TypeScript's behaviour on lone surrogates, too-long parity messages, dictionary key order and refused texts at unpack, zero rounds in map rows and the empty nested row.
**Complexity**: 5 points
**Dependencies**: AZ-4134 to AZ-4149 (shipped, loop 99)
**Component**: dart
**Tracker**: AZ-4153
**Epic**: AZ-4133

## Problem

Loop 99 shipped the Dart package with ten choices where it differs from TypeScript, the behaviour reference. The package is not on pub.dev yet, so the owner (2026-11-11, accept all recommended) moves five of them to TypeScript's behaviour now, before a published shape has callers. Reports and observed values: `_docs/02_task_plans/dart-typescript-alignment/` (`problem.md`, `acceptance_criteria.md` AL-1 to AL-10, `scenarios.md`, `input_data/expected_results/results_report.md`).

## Outcome

- Text that holds half of an emoji packs to TypeScript's bytes in Dart instead of failing.
- A hostile dictionary key order or text reports the same short-read value as TypeScript, Go and Swift.
- A caller of a map row sees no key for a round that has 0 rounds.
- An empty nested row works as the presence mark TypeScript has, and nothing else about it changes.
- Dart's own packets are never unreadable by Dart for these inputs.

## Scope

### Included
- **D1 (AL-1 to AL-3)** lone surrogate written as U+FFFD in text and dictionary keys; keys ordered on the bytes after the swap; two keys that collide after the swap refused at pack naming the dictionary; the byte budget counts U+FFFD as 3 bytes.
- **D7 (AL-4)** a clear message above its parity's limit is a pack error with TypeScript's text; unpack of more than 254 bytes keeps `tooLong`.
- **D8 (AL-5, AL-9)** repeated or out-of-order dictionary keys and refused texts unpack as a short read with `needed` 0 and TypeScript's `left`; the seven hostile rule texts follow.
- **D6 (AL-6)** zero rounds in a map row give no round key; groups and nested maps keep `{}`; typed rows keep `[]`.
- **D10 (AL-7, AL-8)** an empty `nested` is a mark under `flags` or a flag bit and refused elsewhere with TypeScript's words; an empty `nestedRow` stays refused.
- Tests that pinned the old behaviour (11 known) are rewritten; new tests carry the 16 + 16 + 5 + 29 + 15 + 8 observed rows of the results report.
- Docs: README lines that state the old Dart behaviour, `fixtures/hostile/README.md`, rows 17, 20, 32, 40, 41 and 43 of `parity_differences.md`, the Dart component docs, one change-log line each in `compact-text.md` and `message-ecc.md` (no version, bytes or rules change).

### Excluded
- TypeScript, the other seven packages, shared fixtures, ring and handoff drivers (none maps these refusals).
- Fixing TypeScript's unreadable packet for colliding keys (follow-up, leftover of this loop).
- D9, the helper names, Go-1, Go-2, Go-4, `eq` rules, the frame direction type and every other loop 99 choice.
- The first pub.dev publish and any version change.

## Acceptance Criteria

**AC-1: Lone surrogate packs (AL-1, AL-2)**
Given text or a dictionary key with a lone high or low surrogate, a reversed pair, or `a\uD800b`, in the raw, compact or bare form
When packed in Dart
Then the bytes equal TypeScript's (results report, D1 rows), unpack returns U+FFFD in place, and keys sit in ascending order of their bytes after the swap.

**AC-2: Colliding keys (AL-3)**
Given two dictionary keys that are the same once lone halves become U+FFFD
When packed
Then a pack error naming the dictionary is thrown and no packet is written.

**AC-3: Too long for parity (AL-4)**
Given count parity 1, 4 or 32 or percentage 1, 10, 50 or 100
When the clear message is at the limit, and when it is one byte over
Then it packs at the limit; one byte over is a pack error (not `tooLong`) with TypeScript's text and no field; `maxBytes` wins when both apply; unpack of more than 254 bytes is still `too_long`.

**AC-4: Dictionary order at unpack (AL-5)**
Given a repeated key, an out-of-order key, or a repeat after a gap
When unpacked
Then the result is a short read with `needed` 0 and `left` 0 naming the dictionary; valid ascending dictionaries still unpack.

**AC-5: Refused text at unpack (AL-9)**
Given any text unpack refuses (the 5 hand-made cases and the 29 refusing fixture rows, as a field and as a key)
When unpacked
Then the result is a short read with `needed` 0 and `left` equal to TypeScript's; a buffer that ends inside a text is still `short` with the bytes needed; the 7 hostile cases pass.

**AC-6: Zero rounds (AL-6)**
Given a map scheme with a `repeat` or `times` and a packet with 0 rounds, in each of the 15 places of the results report
When unpacked, then packed again
Then there is no round key (groups keep `{}`), the packet it came from is reproduced in 15 of 15 canonical cases, and typed rows still give `[]`.

**AC-7: Empty nested mark (AL-7)**
Given an empty `nested` directly under `flags` or a flag bit
When packed with `true`, `false` or no value, and unpacked
Then the bytes and results equal TypeScript's (`010309`, `010209`, `{g: true, h: 9}`, `{h: 9}`, `0103` is short at `h` with `needed` 1); a value that is not a `bool` is refused naming the mark.

**AC-8: Empty nested elsewhere (AL-8)**
Given an empty `nested` as a row member, under a `when`, in a non-empty group, or as a list or dict element, or an empty `nestedRow`
When the scheme is built
Then it is refused with `empty group g: allowed only directly inside flags or a flag bit; move it into flags` (`nestedRow`: refused as today).

**AC-9: Gates and docs (AL-10)**
Given the change is complete
When `dart format`, `dart analyze --fatal-infos`, `dart test`, the shared fixtures, the 957 parity rows, the nine-language rings and the seeded run are run
Then all pass with 0 changed shared fixtures, no touched source file past 500 lines, and no document that says Dart refuses a lone surrogate or reports `bad_value` for key order.

## Non-Functional Requirements

**Performance**
- Compiled speed bounds of loop 99 unchanged (100,000 round trips under 1,000 ms; 1,000 frame unpacks under 10 ms); the 10 s seeded run reports 0 failures.

**Compatibility**
- Packets Dart writes for all inputs other than a lone surrogate and a too-long parity message are byte-identical to before (shared fixtures 0 changed).

**Reliability**
- No input in AC-1 to AC-8 makes Dart write a packet its own unpack refuses.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the 16 text and key rows of the results report, pack and unpack; the byte budget with a lone half | TypeScript's hex; U+FFFD back; budget counts 3 bytes |
| AC-2 | `\uD800`+`\uDC00` and U+FFFD+`\uD800` keys | pack error naming the dictionary; nothing written |
| AC-3 | limits for 3 counts and 4 percentages at and one over; both limits set | packs / pack error text equal to TypeScript's / `maxBytes` first |
| AC-4 | the 4 order packets and 3 valid dictionaries | short, `needed` 0, `left` 0 / rows |
| AC-5 | 5 hand-made packets as field and key, 29 fixture rows, the cut buffer | `needed` 0 and TypeScript's `left`; cut stays `short` with `needed` 4 |
| AC-6 | 15 places, unpack then pack; typed row | no key, same bytes; `[]` for typed |
| AC-7 | `true`, `false`, absent, `{}`, `{x: 1}`; unpack `010309`, `010209`, `0103`, `0101`, `0100` | bytes and results as the table; non-`bool` refused |
| AC-8 | five refused places and `nestedRow` | the TypeScript words; `schemeError` naming `g` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | TypeScript packets of the D1 rows | each TypeScript packet unpacks in Dart to the same text; Dart packs the same hex; the ring packets still pass in nine languages | 0 mismatches | Reliability |
| AC-4, AC-5 | `fixtures/hostile/cases.txt` (75), `fixtures/text/vectors.txt` | every case gives an allowed outcome; each unpack returns in at most 1 s | 0 uncaught exceptions | Compatibility |
| AC-3 | `fixtures/ecc/vectors.txt` rows `lim`, `percent-vectors.txt` rows `limp` | Dart's pack error maps to `too_long` in the test | all rows pass | Compatibility |
| AC-9 | full Dart suite and loop-tests | all stages pass | 0 changed fixtures | Performance |

## Constraints

- TypeScript is the reference and is read by running it; no change to TypeScript or to packets for any other input.
- Fit decisions (owner, 2026-11-11): the empty-nested mark follows the member-less `groupOf` rules; groups and nested maps keep `{}` for zero rounds; Dart refuses colliding keys.
- A file touched stays at most 500 lines (`quality-thresholds.md`); `node.dart` is 370 and `collection_fields.dart` 155 today.

## Risks & Mitigation

**Risk 1: Sort order after the swap**
- *Risk*: sorting on UTF-16 text writes `efbfbf` before `efbfbd`, a packet Dart's unpack refuses.
- *Mitigation*: AC-1 includes the `￿` and `\u{10000}` key rows and a round trip of every dictionary packed.

**Risk 2: Tests that pin the old shape**
- *Risk*: 11 tests and the rows of `parity_differences.md` fail until rewritten; `parity_doc_test.dart` rejects a row that names a removed test.
- *Mitigation*: rewrite the tests and the rows in the same commit; run the whole suite before the commit.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| D6, D7 and D10 change the API shape of a package not yet published | owner chose it before the first publish (2026-11-11) | accepted-risk | Low |
| TypeScript writes an unreadable packet for colliding keys; Dart refuses | owner (2026-11-11); TypeScript fix is a follow-up | accepted-risk | Low |
| a set flag bit over 0 rounds repacks with the bit cleared in both packages | unchanged; both agree | accepted-risk | Low |
| `groupOf` and the empty `nested` mark refuse `g: {}` where TypeScript clears the bit | Go-1/Go-4, kept | accepted-risk | Low |
