---
loop: 49
branch: dev
---

# Loop 49: C++ raw memo, pin the forget after a compact result

Source: `_docs/loops/loop48/record48.md` leftovers and `handoff49.md`. Owner 2026-10-20 chose "Memo pin" (short loop).

## What
`encode_field` in `cpp/src/core/text_encode.hpp` calls `forget_raw(scratch)` after a compact result, because the parse overwrites Scratch words 0 and 1 (the raw memo). No test fails if that call is removed. Add one that does.

## Code sections / UI locations for this loop
- Test: `cpp/tests/core/text_repeat_host_tests.cpp`
- Code under test (read only, no edit): `cpp/src/core/text_encode.hpp` (`encode_field`, `forget_raw`, `is_last_raw`)

## In scope
- AZ-2748 (1 point): a host test whose packet leaves the parse words pointing at a raw field equal to the next text; with `forget_raw` removed after the compact result the bytes differ.
- Prove it with a mutant (comment out the call, see the test fail, restore).

## Out of scope
- Any change to `cpp/src/core` (flash margin 272 B, stack 8 B stay as they are), any wire change, CS-D5, tags, F44.

## Acceptance criteria
- AC-1: the new test passes on the current code.
- AC-2: with the `forget_raw(scratch)` call after the compact `put_field` removed, the new test fails.
- AC-3: the full `make -C cpp test` passes and the gcc:16 container run passes.

## Flagged concerns
none
