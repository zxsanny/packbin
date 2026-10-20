# Handoff to loop 49

From the loop 48 record (`record48.md`). Nothing here is owner-decided yet except where it says so.

## Candidates

| Row | Work | Owns |
|-----|------|------|
| Compact memo | C++ repeated text that compacts still parses each round (1.9 s class for 200 rounds of 65,535 ordinary characters). Needs the previous text or a safe equality proof; only if real messages repeat long texts | `cpp/src/core/text_encode.hpp` (flash margin 272 B, stack 8 B: arm embedded stage) |
| Memo pin | A test that pins the `forget_raw` after a compact result | `cpp/tests/core/text_repeat_host_tests.cpp` |
| Retrospective | Last retro `retro_2026-10-20_loop46.md`; due by loop 51 | `_docs/06_metrics` |

## Open, waiting on the owner

- CS-D5: retrain the compact-string tables on the owner's 100 to 200 real messages before the first `v*` tag (a wire break; free until the tag).
- The first `v*` and `go/v*` tags and F44 stay owner-run.

## Read after the push

- `test.yml` on `dev` and `main` for the loop 48 push: ring and scaffold job times (loop 47: ring 143 s, scaffold 166 s, wall 274 s; a second run was not read) and the Swift `sanitized` step.

## CI read after the push (loop 48, `ac03ac8`)

`test.yml` on `dev` (run 39380861306) and on `main` (run 39380864877): both green, 20 of 20 jobs. `dev`: longest job `embedded-esp-core` 204 s, then `suites (swift, tests)` 192 s, `publish-gate-swift` 190 s, `ring` 184 s; `main`: `ring` 220 s, `publish-gate-readonly` 201 s, `embedded-esp-core` 201 s. Both runs ended within about 3 minutes 40 s of the push (the first run on `dev` that is not slower than loop 47's 274 s wall; the loop 47 Swift `tests` 272 s is 192 s here, so the TSan step is not the long pole).
