# Autodev loop record — loop 34

loop: 34
branch: dev
plan_artifact: _docs/loops/loop34/plan34.md
tasks_shipped: [AZ-2627]
leftovers:
  - AC-1 met: runs 39044659167 (`7cb51ca`) 217 s and 39045847480 (`6bbb3b7`, the close push) 210 s, 20 of 20 jobs green each: median 213.5 s against 225 s (loop 33: 238 s)
  - AC-2 met on all five runs: 20 jobs, latest start +1 s (loop 33: three jobs 26 to 88 s late per run)
  - AC-4 met on run D: `tests` debug build 19 s, `gates` sanitizer build 27 s, `speed` 101 s, ring drivers 26 s (loop 33 best 48, 85, 131, 84)
  - AC-6 and AC-3's ccache clause withdrawn by the owner (2026-10-17): ccache removed in batch 2 because `actions/cache` keeps nanosecond file times and CI recompiled no C file (run A: ccache asked 0 times); the intake spike's plain-tar round trip had suggested otherwise
  - batch 3 (owner): keys `swift-v2-...` hash the build-setting script; run B had shown stale `v1` entries (built with the ccache compiler) rebuilding BoringSSL on every hit; the 8 `v1` entries expire unused
  - the wall is now the non-Swift floor: `publish-gate-readonly` 204 to 214 s, `embedded-esp-core` 194 to 207 s, `publish-gate-rest` 186 to 206 s
  - review finding 5 (restore the ring's cache after its pulls start) skipped by the owner: `ring` 127 s on a hit, off the wall; D4 (gcc pull order) not needed
  - `ubuntu-latest` moves to Ubuntu 26 from 2026-10-19; the Swift builds run in `swift:6.3.3` whatever the runner
  - the two vcpkg checks are NOT RUN on the Mac (no vcpkg tool); CI runs them
  - from loop 33 and earlier: T3 (Go proxy wait) and T1 (tag run skips the repeated test) unproven until the next `v*` / `go/v*` tag (owner's go); F44 (tag ruleset) and the first tags owner only; AZ-2068 in `todo/`
smoke: PASS (agent run 10/10 on run D, 2026-10-17; owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop34/smoke34.md
assessment_artifact: _docs/loops/loop34/assessment34.md
loop_end_merge: main (not executed this loop: no push of `main`, the spec's constraint)
