# Batch Report

**Batch**: 1 (loop 101)
**Tasks**: AZ-4168_typescript_colliding_dict_keys
**Date**: 2026-11-11

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-4168_typescript_colliding_dict_keys | Done | 1 source file (`typescript/src/pack-fields.ts`, +10 lines), 1 new test file, 4 doc files | 3,638 of 3,638 TypeScript tests pass | None |

## Code Review Verdict: PASS

One total review for the loop: a cross-language differential run, not a reading. TypeScript wrote the expected result of 5,000 seeded dictionaries (keys of 0 to 3 units over a, b, the four surrogate halves, U+FFFD, U+FFFF, U+10000, an emoji, `~` and the empty text; 1 to 5 keys); Dart packed the same dictionaries: 5,000 same, 0 different, 280 refused with the same message. The new tests fail against the old source (6 of 10 fail: the four collisions, the list element and the 20,000-dictionary property) and pass against the new one.

## Test Suite

- TypeScript: 3,638 tests, 3,638 passed, 0 failed, 0 skipped (`node --test tests/*.ts`); `tsc --noEmit --strict` clean.
- Dart: unchanged source; `parity_doc_test.dart` 55 of 55 after the parity row edit.
- CI-parity: PASS (`node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions src/index.ts` and `node --test tests/*.ts`, the commands of the TypeScript job).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The check compares the encoded neighbours after the sort the code already does, so a dictionary inside a list or a dict value is covered by the same line (`Object.keys` appears once in `typescript/src`) | AC-1 | done; the list element has its own test | clear |
| 2 | The other six packages may write the same unreadable packet for a lone surrogate in a key (C# and Java encoders replace a lone half; Go refuses a string that is not valid UTF-8; Swift strings cannot hold one) | problem.md flagged concern | not measured in this loop; a leftover in the record | unclear (needs a per-language run) |

## Commit

`[AZ-4168] TypeScript: refuse dictionary keys that collide after U+FFFD` with body and `Loop: 101`.

## Next Batch: All tasks complete
