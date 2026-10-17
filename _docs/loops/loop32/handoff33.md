# Loop 33 handoff — written 2026-10-17 while loop 32 was closing

Read `_docs/loops/loop32/record32.md`, `notes32.md`, `assessment32.md`, `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` section 8 and `_docs/06_metrics/retro_2026-10-17_loop32.md`. Owner preferences from `_docs/loops/loop26/handoff27.md` stand; the decision-batch form ("accept all recommended" first) worked again.

## State when loop 32 closes
- `test.yml` 275 s on run 39024316436 (23 jobs, all green); the second run is the close push of `dev` (see `notes32.md`). `main` is not pushed. Mac `publish-gate` stage 391 s (8 shares, ratio 0.16); step 11 902 s.
- The wall is `ring` (273 s) with `suites (swift, tests)` (246 s) second; nothing the loop cut is above 250 s.

## Candidate work (owner picks)
- Another CI round: split `ring` (driver builds 101 s, toolchain versions 41 s, ring 48 s plus the setup steps) or move its setup out of the critical job; trim the pull list per job (phases need five images; swift is 4 GB) with the `publish-jobs.test.sh` rule changed to "the images the job's groups need"; the C3 caches; the PlatformIO install in the Arduino-ESP32 target.
- Owner only: F44 (tag ruleset), the first `v*` and `go/v*` tags (they also prove T1 and T3).
- `AZ-2068` (C++ AVR, stretch) stays in `todo/`; the flash margin is 32 B.
