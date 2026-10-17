# Autodev loop record — loop 33

loop: 33
branch: dev
plan_artifact: _docs/loops/loop33/plan33.md
tasks_shipped: [AZ-2626]
leftovers:
  - AC-1 met: runs 39031026351 (`19f4c33`) 251 s and 39031606844 (`2da10a6`, the close push) 225 s, 23 of 23 jobs green each, median 238 s against 250 s; the wall moves between `suites (swift, tests)` (248 s), `publish-gate-readonly` (222 s) and `ring` (202 to 209 s)
  - AC-7's shorter pull steps missed in run 2 (phases-rerun 61, rest 65 s against about 57 and 59): the lists are exact, the network swing is larger than the images left out
  - AC-2 missed and accepted by the owner (2026-10-17): `ring` 209 s against 180 s (was 255 to 273 s); its path is the swift pull (68 s, slowed by the parallel gcc pull) plus the Swift driver build (84 s)
  - next lever: C3, SwiftPM build caches for the ring's Swift driver build and the three Swift suite parts (all rebuild from nothing on every push); the gcc pull after the swift pull would save an estimated 15 to 25 s of `ring` only
  - the Mac's Docker Desktop pulls present images in minutes (156 and 422 s, IPv6-first registry path); not a CI matter
  - `ubuntu-latest` moves to Ubuntu 26 from 2026-10-19 (GCC, Swift and the setup actions of `ring` may change); `ring-toolchains.sh` stays the authority
  - the two vcpkg checks are NOT RUN on the Mac (no vcpkg tool); CI runs them
  - from loop 32 and earlier: T3 (Go proxy wait) and T1 (tag run skips the repeated test) unproven until the next `v*` / `go/v*` tag (owner's go); F44 (tag ruleset) and the first tags owner only; AZ-2068 in `todo/`
smoke: PASS (agent run 8/9, step 3 `ring` at most 180 s failed and the owner accepted the miss, 2026-10-17; owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop33/smoke33.md
assessment_artifact: _docs/loops/loop33/assessment33.md
loop_end_merge: main (not executed this loop: no push of `main`, the spec's constraint)
