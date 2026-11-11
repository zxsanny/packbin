# Scenarios — dart-typescript-alignment

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred. AC refs are the feature ACs in `acceptance_criteria.md` (AL-n) with the owning task AC.

## Fit (Part A)

| component / flow | today | after | who depends on today | collision |
|------------------|-------|-------|----------------------|-----------|
| Dart text and dictionary pack (F1) | a lone surrogate is a pack error; keys sorted on UTF-16 text | U+FFFD written, keys sorted on the bytes after the swap, colliding keys refused | Dart tests and README that state the refusal; callers of a not yet published package | resolved: TypeScript's own colliding-key packet is unreadable (owner: Dart refuses) |
| Dart unpack of text and dictionaries (F2) | `bad_value` | short read, `needed` 0 | the 7 hostile rule texts in `hostile_rules.dart`; README Errors lines | none (the hostile cases already accept `short_packet`) |
| Dart map rows with rounds (F1, F2) | `[]` per round name | no key; groups keep `{}` | README and parity rows | resolved: `g: {}` kept (owner) |
| Dart ECC pack (F1) | kind `tooLong` | kind `packError`, TypeScript's text | 8 ECC tests map the kind; `fixtures/ecc` word `too_long` | none (each language maps its own error to the shared word) |
| Dart scheme build | empty `nested` refused | mark under `flags` or a flag bit, refused elsewhere | `construction_test.dart` | resolved: TypeScript refuses an empty group outside flags (the first premise was wrong) |

All five collisions were put to the owner as questions and answered on 2026-11-11; no problem card is open.

## Matrix (Part B)

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A Flutter app packs text that came from a broken source and holds half of an emoji | confirmed | the half is written as U+FFFD; the bytes equal TypeScript's; every ring language reads the packet | AL-1, AL-2 | intake |
| S2 | Two dictionary keys are different in Dart and the same once the halves become U+FFFD | confirmed | pack is refused naming the dictionary, no packet written; TypeScript still writes an unreadable one (follow-up, not this loop) | AL-3 | intake |
| S3 | A hostile packet carries a repeated or out-of-order dictionary key, or a text that is not valid | confirmed | a short-read value with `needed` 0, no row, no exception, as TypeScript, Go and Swift | AL-5, AL-9 | intake |
| S4 | A valid ascending dictionary, a text that is valid, a buffer cut inside a text | confirmed | unchanged: the row, and `short` with the bytes needed for the cut | AL-5, AL-9, AL-10 | intake |
| S5 | A clear message one byte over what its parity allows | confirmed | `packError` with TypeScript's words; at the limit it packs; `maxBytes` wins when both apply; unpack of more than 254 bytes stays `too_long` | AL-4 | intake |
| S6 | A packet with 0 rounds is unpacked into a map and packed again | confirmed | no round key (groups keep `{}`); the same bytes come back in 15 of 15 canonical cases; typed rows keep `[]` | AL-6 | intake |
| S7 | A scheme with an empty `nested` row is built under `flags`, and one built elsewhere | confirmed | under `flags` or a flag bit it is a mark with TypeScript's bytes; elsewhere it is refused with TypeScript's words; an empty `nestedRow` stays refused | AL-7, AL-8 | intake |
| S8 | A caller that already used `groupOf` marks, typed rows, the shared rules Go-1, Go-2, Go-4 or any other Dart row of loop 99 | confirmed | no change; the 1,919 tests of loop 99 not named in the 11 changed ones pass as they are | AL-10 | intake |
