# Loop 68 smoke — checks

LOCAL_URL: none (arm embedded stage under QEMU; nothing to open)
Branch: dev
Script: `smoke68.sh` in this folder (`bash _docs/loops/loop68/smoke68.sh`, about 1 minute with a warm Docker cache).

## Checks

- [x] 1. AC-1 to AC-5, AC-7: the arm stage passes with six rows; `cpp-m33f` flash 25,720 B (ceiling 65,536 B), net stack 724 B (ceiling 8,192 B), core `.data` plus `.bss` 0 B; M4F 7,712 B / 540 B
- [x] 2. AC-3, AC-4: the pins equal the measured figures; the ceilings are 65,536 B and 8,192 B
- [x] 3. AC-2: the M33F packet equals the M3 packet; 290 vectors (22 session) on `mps2-an505`
- [x] 4. AC-6: a pin 1 B low and a ceiling below the figure fail the row naming the figure
- [x] 5. AC-8: `run-parts.test.sh` and `lib.test.sh` pass with `cpp-m33f` listed
- [x] 6. AC-10: 0 changes in `cpp/src` and `cpp/include` since `4151a90`

## Result

Agent run 2026-10-25 at `1df2e05` plus the uncommitted loop 68 documents (owner rule 2026-10-12): **6/6 steps passed**, run twice (the second after step 11), host load 22 to 65 from other sessions.

## Agent walk

No browser (no UI). No step failed in the script itself this time.

## For the operator

- CI of the push: the `embedded-arm` job runs the new row through `run.sh host arm`; read it first.
- Real nRF54L15 (non-secure image with 128 KiB of RAM, RRAM, timing) is not covered by the QEMU row.
