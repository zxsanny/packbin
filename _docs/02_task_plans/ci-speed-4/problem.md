---
loop: 33
branch: dev
---

# Loop 33 — CI speed 4 (AZ-2626, epic AZ-2223)

Owner (2026-10-17): picked "CI speed 4" from `_docs/loops/loop32/handoff33.md` (ring off the critical path, per-job image pulls in the gate jobs). Acceptance criteria and the decision batch follow after the step profile of the last two CI runs.

## What

`test.yml` wall was 275 s and 264 s on the loop 32 code (runs 39024316436 and 39025925515, median 269.5 s, 23 jobs). The wall is `ring` (261 to 273 s, unchanged since loop 28): setup actions, `toolchain versions` about 41 s (it runs `swift --version` in the 4 GB `swift:6.3.3` image, so the pull is in that step), `driver dependencies and builds` about 101 s (npm ci, cargo, Go, the Swift drivers built in `swift:6.3.3`), `cross-language ring` about 48 s. Seven `publish-gate-*` jobs pull all eight suite images before their groups, although several groups start only some of them.

1. **`ring` off the critical path**: overlap the image pull and the driver builds with the setup steps, or another layout chosen from the measured step times.
2. **Per-job pull lists**: each gate job pulls only the images its groups start; the `publish-jobs.test.sh` rule changes from "all eight" to "the images the job's groups need", with a mutant.

Goal: wall about 240 s (estimate); the next pole is `suites (swift, tests)` (180 to 246 s). No check removed; every group, Swift step and embedded target in exactly one job.

Not in scope unless the owner adds it: C3 (caches), the PlatformIO install in the Arduino-ESP32 target, AZ-2068, any tag or registry upload, F44, the `main` push.

## Code sections / UI locations for this loop

Backend only (CI and test scripts), named in the option the owner picked:

- `.github/workflows/test.yml` (`ring` job, `publish-gate-*` pull steps)
- `.github/workflows/ring-*.sh`, `.github/workflows/language-pair.sh` (only if the driver builds move)
- `.github/workflows/publish-jobs.test.sh` (the pull rule and its mutants)

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The gain is small (about 25 to 40 s): the 5-minute goal is already met and `suites (swift, tests)` (180 to 246 s) is the next floor | owner picked the round knowing the estimate | accepted-risk | Low |
| The same code varies about 1.4x between CI runs | median of two runs; never one run as proof | open | Medium |
