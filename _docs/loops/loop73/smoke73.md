# Loop 73 smoke — Rust key wipes

LOCAL_URL: none (library; no site). Branch: dev at 9f118c9. Script: `bash _docs/loops/loop73/smoke73.sh`. Run by the agent on 2026-10-26 at host load about 8 to 14, under the owner rule of 2026-10-12: one paste script, with the agent auto-passing the gate when every step passes.

## Checks

- [x] 1. No application source is dirty
- [x] 2. One volatile wipe helper with one `unsafe` block, no `black_box` wipe, `frame` forbids `unsafe`, `compress` wipes its schedule window (AC-1.1 to 1.3, AC-2.4)
- [x] 3. The helper test, RFC 5869, RFC 8439 and the primitive vector rows pass (AC-1.4, AC-2.3, AC-3.3)
- [x] 4. Frame vectors (with and without `std`), frame core, heap-free and std session tests pass (AC-7)
- [x] 5. Rust embedded rows pass with the loop 73 figures: M4F `session` 18,844 / 1,504, `frame` 20,332 / 1,728 (bound 20,480); M33F 18,916 / 1,504 and 20,404 / 1,728; `base`, `text`, `ecc` unchanged (AC-5)
- [x] 6. The stream pad is at most 1.15 times and `MacKey::tag` at most 1.10 times the claim commit 72beacb (AC-6.1, AC-6.3)
- [x] 7. The frame and crypto fixture checks pass; `fixtures/` unchanged since 72beacb (AC-7)
- [x] 8. M33F pins, gotcha line, Rust description and module layout updated (AC-5.3, AC-8)
- [x] 9. No touched Rust source file is over 500 lines

## Agent walk

9 PASS, 0 FAIL, 0 NOT RUN (`smoke73: 0 failed`). The first run failed step 5 on the script's own parsing (it read the `B` unit fields of the `SIZE` lines, not the figures); fixed in the script, the whole script rerun green.

## For the operator

Nothing: every check ran in the script.
