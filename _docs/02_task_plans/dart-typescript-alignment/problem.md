---
loop: 100
branch: dev
---

# Loop 100 — Dart aligned with TypeScript

Loop 100 (on `dev`; no worktree). Intake: the owner's choice of 2026-11-11 ("Dart: align with TypeScript"), then "Accept all recommended" twice: on the five-row list built from `_docs/02_task_plans/dart-package/parity_differences.md` and `_docs/loops/loop99/assessment99.md`, and on the three questions the probes raised (D10, D6, D1 collision).

## What and why

Loop 99 shipped the Dart package and left ten choices "as built" where Dart differs from TypeScript, the behaviour reference (A-1 of loop 99). The Dart package is not on pub.dev yet, so a change of shape costs nothing now and breaks callers after the first publish. Five of the ten move to TypeScript's behaviour. Every figure below was read by running TypeScript and Dart on HEAD 0a678be in this loop (probe scripts in the session scratchpad; the observed packets are in `input_data/expected_results/results_report.md`).

| row | Dart today | after this loop |
|-----|-----------|-----------------|
| D1 | a text with a lone surrogate is refused at pack (`packError`) | written as U+FFFD, the same bytes as TypeScript, in the raw and the compact form and in a dictionary key; dictionary keys are sorted after the swap; two keys that become one after it are refused at pack naming the dictionary |
| D7 | a clear message too long for its parity throws kind `tooLong` | a `PackbinException` of kind `packError` with TypeScript's text (kind `tooLong` stays for unpack of more than 254 bytes) |
| D8 | a repeated or out-of-order dictionary key, and every refused text, unpack as `bad_value` | a short read with `needed` 0 and `left` as TypeScript gives it (0 for key order, the bytes from the field start for a text) |
| D6 | zero rounds of a map-row `repeat` or `times` unpack to `[]` per name | no key for the names of the round; a group or nested map that holds only such rounds stays as `{}`; typed rows keep `[]` |
| D10 | an empty `nested` row is refused when the scheme is built | an empty `nested` directly under `flags` or a flag bit is a presence mark, as TypeScript's empty group; anywhere else it is refused with TypeScript's words |

The probes corrected two premises of the first list. TypeScript does **not** build an empty group as an ordinary row member (D10 premise): it builds it only as a mark under `flags` or a flag bit. And TypeScript packs two keys that become the same key after U+FFFD into a packet its own unpack refuses (D1 trap).

Kept as built (owner, 2026-11-11): D9 `Uint8List` for `bits` and `packed`, the D3 helper names, the shared rules Go-1, Go-2 and Go-4, the member-less `groupOf` (it stays the typed mark: `bind` a `bool`; an empty `nestedRow` stays refused), `eq(u64, -1)`, no `BigInt`, the frame direction type, and every owner question of loop 99 not listed above.

## Code sections / UI locations for this loop

Owner (2026-11-11): the Dart package `dart/` (option "Dart: align with TypeScript"), measured against `typescript/`. Edited places, found by running both packages and `git grep`:

- D1: `dart/lib/src/text/text_encode.dart` (lines 8-9, 72-78, 88-91), `text_types.dart` (35, 43, 49), `collections_pack.dart` (15-16, 30-31, 109: the key sort), `collection_fields.dart` (101).
- D8: `collections_unpack.dart` (10-12, 18-28, 72-85).
- D6: `rounds_unpack.dart` (21-25, 59-69).
- D7: `ecc/codec.dart` (55-71), `ecc/percent.dart` (39-53), `errors.dart` (30-33, 118-119), `scheme.dart` (179-183).
- D10: `collection_fields.dart` (115-149), `node.dart` (`isMark`, about 318), `checks.dart` (`checkMarks`, about 169).
- Tests that pin today's behaviour (11 fail on a patched copy): `test/collections/utf8_field_test.dart`, `test/text/text_hostile_test.dart`, `test/collections/dict_order_test.dart`, `hostile_collections_test.dart`, `count_bounds_test.dart`, `test/hostile/hostile_rules.dart`, `test/rounds/zero_and_short_test.dart`, `test/ecc/{count_vectors,percent_vectors,scheme_limits,scheme_vectors}_test.dart`, `test/collections/construction_test.dart`; `test/parity/parity_doc_test.dart` checks every row of `parity_differences.md` names tests that exist.
- Docs: `README.md` (980, 1000, 1002, 1079, 1106, 1887, 2233, 2411), `fixtures/hostile/README.md` (26 and the Dart lines), `_docs/02_task_plans/dart-package/parity_differences.md` (rows 17, 20, 32, 40, 41, 43), `_docs/02_document/components/09_dart_package/{description,tests}.md`.
- Not edited: shared fixtures (`fixtures/hostile/cases.txt` already accepts `bad_value|short_packet` for all seven text and key cases; `fixtures/ecc/*` use `too_long` as an outcome word that each language maps), the ring and handoff drivers (none maps these refusals), TypeScript, and the other seven packages.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| D6, D7 and D10 change the API shape of a package not yet on pub.dev; after the first publish such a change breaks callers | owner chose it before the first publish (2026-11-11) | accepted-risk | Low |
| TypeScript packs two dictionary keys that collide after U+FFFD into a packet its own unpack refuses (`0102000410efbfbd010410efbfbd02`); Dart refuses at pack, so Dart and TypeScript differ on this input | owner (2026-11-11): Dart refuses; fixing TypeScript is a follow-up, not this loop | accepted-risk | Low |
| a set flag bit over zero rounds repacks with the bit cleared in both packages (probe c7/c8, wire `01000309`) | unchanged by this loop; both packages agree | accepted-risk | Low |
| the member-less `groupOf` refuses `g: {}` where TypeScript clears the bit silently | Go-1 and Go-4 rule (a mark must be a `bool`), kept; the empty `nested` mark follows the same rule | accepted-risk | Low |
