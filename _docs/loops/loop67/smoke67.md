# Loop 67 smoke — checks

LOCAL_URL: none (C++ core and embedded stage; nothing to open)
Branch: dev
Script: `smoke67.sh` in this folder (`bash _docs/loops/loop67/smoke67.sh`, about 40 s with a warm Docker cache).

## Checks

- [x] 1. AC-1, AC-2, AC-4: the arm embedded stage passes with stack 540 B (at most 548 B), flash 7,712 B (at most 7,724 B) and 290 of 290 vectors
- [x] 2. AC-5: `stack_pin` 540 and `flash_pin` 7712 equal the measured figures
- [x] 3. AC-3: a copy of `unpack.cpp` that never brings the outer flag bytes back fails the new `when`-scope test
- [x] 4. AC-3: `unpack.cpp` compiles with no warning in `gcc:16` at -O1, -O2, -O3 and -Os
- [x] 5. AC-1: the `unpack_children` frame is 56 B and no `with_outer_flags<unpack_children>` frame is left

## Result

Agent run 2026-10-25 at `642f139` plus the uncommitted loop 67 documents (owner rule 2026-10-12): **5/5 steps passed**, 41 s, host load 6.

## Agent walk

Step 3 first failed in the script itself: the broken copy removed the only use of `keep`, so Apple clang stopped the build on `-Wunused-but-set-variable` before any test ran. The copy now replaces the restore with `(void)keep;`; after that the new test fails as intended (8 FAIL lines, 2 of them the new test).

## For the operator

- CI of the push: `test.yml` on `dev` and `main`; the `cpp`, `ring` and `embedded-arm` jobs touch this change.
- Nothing else: no UI, no device.
