# Loop 33 handoff — written 2026-10-17 while loop 32 was closing

Read `_docs/loops/loop32/record32.md`, `notes32.md`, `assessment32.md`, `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` section 8 and `_docs/06_metrics/retro_2026-10-17_loop32.md`. Owner preferences from `_docs/loops/loop26/handoff27.md` stand; the decision-batch form ("accept all recommended" first) worked again.

## State when loop 32 closes
- `test.yml` 275 s and 264 s on runs 39024316436 and 39025925515 (23 jobs each, all green; median 269.5 s); `dev` is pushed through `73ba412`. `main` is not pushed. Mac `publish-gate` stage 391 s (8 shares, ratio 0.16); step 11 902 s.
- The wall is `ring` (261 and 273 s); nothing the loop cut is above 250 s. A local docs commit with the run 2 numbers is not pushed.

## Candidate work (owner picks)
- Another CI round: split `ring` (driver builds 101 s, toolchain versions 41 s, ring 48 s plus the setup steps) or move its setup out of the critical job; trim the pull list per job (phases need five images; swift is 4 GB) with the `publish-jobs.test.sh` rule changed to "the images the job's groups need"; the C3 caches; the PlatformIO install in the Arduino-ESP32 target.
- Owner only: F44 (tag ruleset), the first `v*` and `go/v*` tags (they also prove T1 and T3).
- `AZ-2068` (C++ AVR, stretch) stays in `todo/`; the flash margin is 32 B.
