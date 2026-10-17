# Loop 35 handoff — written 2026-10-17 while loop 34 was closing

Read `_docs/loops/loop34/record34.md`, `notes34.md`, `assessment34.md`, `review34.md`, `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` section 10 and `_docs/06_metrics/retro_2026-10-17_loop34.md`. Owner preferences from `_docs/loops/loop26/handoff27.md` stand; decision batches with "accept all recommended" first worked again (four questions this loop, each answered with the recommendation).

## State when loop 34 closes
- `test.yml` makes 20 jobs (the free plan's limit); no job waited for a slot on any of the five runs. Run D (39044659167, `7cb51ca`) 217 s; the close push is the second measured run (`notes34.md`).
- The four Swift builds keep their output in `actions/cache` (keys `swift-v2-...`, hashing the manifests and the build-setting script): on a hit the `tests` debug build took 17 s and the ring's driver build 22 s (run A). The 8 stale `swift-v1-...` entries expire unused (7 days).
- The wall is now the non-Swift floor: `publish-gate-readonly` (204 to 214 s), `embedded-esp-core` (194 to 207 s), `publish-gate-rest` (186 to 206 s). `main` is not pushed.

## Candidate work (owner picks)
- Stop the CI-speed series here: 217 s against 382 s in loop 30; every further 10 s needs a loop of its own.
- Or cut the floor: `publish-gate-readonly` (it pulls all eight images; read the `publish gate timing` notice first) or `embedded-esp-core` (the PlatformIO install of the Arduino-ESP32 target).
- Watch the first runs on Ubuntu 26 (from 2026-10-19): the Swift builds run in `swift:6.3.3` whatever the runner; `ring-toolchains.sh` stays the authority for the ring.
- Owner only: F44 (tag ruleset), the first `v*` and `go/v*` tags (they also prove T1 and T3).
- `AZ-2068` (C++ AVR, stretch) stays in `todo/`; the flash margin is 32 B.
- Not needed now: review finding 5 (restore the ring's cache after its pulls start; `ring` is 127 s, off the wall) and D4 (gcc pull after swift).
