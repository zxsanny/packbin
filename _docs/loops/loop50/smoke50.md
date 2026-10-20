# Loop 50 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke50.sh` in this folder (run it with `bash _docs/loops/loop50/smoke50.sh`; Docker and the rustup target `thumbv7em-none-eabihf` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. AZ-2749 AC-1: the crate builds as `no_std` with default features off and the 12 heap-free tests pass
- [x] 3. AZ-2749 AC-2/AC-7: the default suite passes (792 tests, 27 targets) with the differential tests, which compare the bytes of the map API and of `nostd`
- [x] 4. AZ-2749 AC-6: with the big-endian copy broken, the differential tests fail (mutant on a copy of `rust/`)
- [x] 5. AZ-2751 AC-1/2/4/5: the Cortex-M4F image links, decodes the golden fixture under QEMU, has no heap or panic symbol and adds 0 B of RAM; flash 2,652 B of 8,192, stack 88 B of 512
- [x] 6. AZ-2751 AC-3: a limit lowered by one byte fails the stage and names the figure (`flash 2652 B over 2651 B`, `stack 88 B over 87 B`)
- [x] 7. AZ-2751 AC-4/5: `checks.test.sh`, `publish-jobs.test.sh`, `run-parts.test.sh` and `loop-tests.test.sh` pass

## Result

Agent run 2026-10-20 at `117e5d8` (owner rule 2026-10-12 in `deployment_procedures.md`): **7/7 steps passed** (the first run had 6/7: step 2 expected 13 passing tests, the file has 12 without the `alloc` feature; the expectation was fixed and the whole script re-run). Step 11 ran before the total review fixes: 5 stages passed (`rust` 80 s, `scaffold` 388 s, `rust-embedded` 5 s, `ring` 87 s, `publish-gate` 369 s; 849 s in all, host load up to 78); after the fixes the default suite (792), the embedded stage, clippy and the four guard tests were re-run (steps 3, 5, 7 above).

## For the operator

- Jira: AZ-2749 and AZ-2751 are In Testing; AZ-2752 to AZ-2757 are To Do under epic AZ-2750 (34 points in all; the first estimate of 5 was the whole feature).
- The first push runs the new `embedded-arm` steps on GitHub (Rust 1.98 install, thumb target, the stage). Their wall time is read from the annotations (see `handoff51.md`).
- The first `v*` tag, F44 and the `go/v*` tag are yours; CS-D5 waits for the 100 to 200 real messages.
