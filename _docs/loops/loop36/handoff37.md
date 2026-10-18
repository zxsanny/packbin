# Loop 37 handoff (written 2026-10-18 at the close of loop 36)

Read `_docs/loops/loop36/record36.md`, `_docs/loops/loop35/review35.md` and `_docs/05_security/compact_text_decoder_review_loop36.md`.

## State
- Loops 35 (compact strings, epic AZ-2645) and 36 (state per call, speed bound in CI) are on `origin/dev`. `main` is not pushed, no tag exists.
- Owner-run and still open: `/feature-assess`, `/security` (AZ-2666), the retrospective.

## Candidate work
- The Low review findings in `record36.md`; real messages (D5); CRC for the whole message; F44 and the first tags.
- If the first CI run of loop 36 shows the Rust release build costing minutes in `csharp rust`, move the step to its own job or to the ring.
