# Batch 1 report — loop 63

Task: AZ-PENDING_cpp_pack_flash_saving (3 points; last task). No per-batch review (owner preference); the total review is feature-assess and the total test is step 11.

| Task | Status | Evidence |
|------|--------|----------|
| AZ-PENDING_cpp_pack_flash_saving | Done (part 1 kept, part 2 dropped) | `pack.cpp`: `pack_u2` writes in place (no `raw[16]`, no `put_bytes`) and `bad` is `PACKBIN_NOINLINE`. Cortex-M4F flash 7,808 B to 7,724 B (-84 B, the AC-2 floor was -72 B); stack unchanged (deepest 496 B; pack chains 404 / 440 / 492 B). Pin lowered to 7,724 B. `make -C cpp test` pass; `gcc:16 make test` pass; arm stage `0 target(s) failed` (m0+, M3 QEMU 287 vectors, M4F, s390x 287 vectors, AVR Uno). `cpp/embedded` self-tests pass. |

## Figures (Cortex-M4F `size14` over `baseline`, same container and flags as `run.sh arm`; measured on copies of the tree, repo at HEAD)

| Shape | Flash | Pack stack plain / flag / round chain | Kept |
|-------|-------|---------------------------------------|------|
| HEAD `c9ceaa7` (AC-1) | 7,808 B | 404 / 440 / 492 | |
| `pack_u2` in place | 7,768 B (-40) | 404 / 440 / 492 | part of the kept shape |
| `pack_u2` in place + `bad` out of line | 7,724 B (-84) | 404 / 440 / 492 | kept |
| ... + `ref_value` out of line | 7,724 B | same | no gain |
| ... + `full` buffer helper out of line | 7,732 B | same | worse |
| one out-of-line `put_le` for the 1/2-byte puts (with in-place `pack_u2`) | 7,736 B (-72) | 412 / 456 / 500 | stack grows |
| the same + `bad` out of line | 7,684 B (-124) | 412 / 456 / 500 | stack grows (AC-3) |
| `put_le` at the count and type byte only | 7,788 B / 7,744 B | 412 / 448 / 500 | stack grows or no gain |
| kept shape + `held_of` D (shared function, `pack_children` unchanged for flag bits) | 7,768 B (+44) | 404 / 440 / 492 | dropped (AC-7) |
| kept shape + `held_of` A (loop 61 patch) | 7,796 B (+72) | 404 / 440 / 492 | dropped (AC-7) |

AC-3 text: its pack figures (412 / 448 / 500) were the loop 61 values; HEAD after loop 62 is 404 / 440 / 492 and the kept shape does not move them. The 8 B pack-stack gain that shape A had in loop 61 is gone since loop 62.

Decision on `held_of`: the owner chose "drop" (AskUserQuestion, 2026-10-23, recommended option). CI-parity: PASS by `make -C cpp test`, `gcc:16 make test`, the arm stage and the two embedded self-tests; `scripts/loop-tests.sh` runs at step 11.

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 | AC-3 named stale pack stack figures (412 / 448 / 500) | recorded above; the kept shape is at or below HEAD in every figure | clear |
| 2 | keep rule AC-7 (held_of at most the part 1 figure) can only hold when held_of costs 0 B; a cost of 44 to 72 B lands between the new and the old pin | owner decided drop | clear |
| 3 | a noinline `bad` adds a leaf frame (8 B) on the error path only; the stack meter measures success paths | error-path stack not measured; flagged in the record | clear |
