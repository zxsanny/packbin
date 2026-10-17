---
loop: 34
branch: dev
---

# Loop 34 — CI speed 5 (AZ-2627, epic AZ-2223)

Owner (2026-10-17): answered the loop 34 batch (D1 to D4, built from `_docs/loops/loop33/handoff34.md`) with "accept all recommended": D1 C3, cache the SwiftPM dependency build (swift-crypto) for the three Swift suite jobs and the ring's driver build, and merge short suite jobs so the workflow has at most 20 jobs; D2 median of two runs at most 225 s, no job waiting for a slot; D3 `actions/cache` pinned by SHA (new to the repository); D4 pull gcc after swift in `ring` only if the first measured run shows `ring` above the floor, no separate ask. AZ-2068 stays in `todo/`.

## What

`test.yml` on the loop 33 code took 251, 225 and 273 s (runs 39031026351 `19f4c33`, 39031606844 `2da10a6`, 39032007165 `dadd32b`; 23 jobs, all green). Job seconds (run 1 / 2 / 3; `+n` is the start delay):

| Job | Run 1 | Run 2 | Run 3 |
|-----|------:|------:|------:|
| `suites (swift, tests)` | 248 | 188 | 246 |
| `publish-gate-readonly` | 211 | 222 | 198 |
| `suites (swift, speed)` | 221 | 177 | 219 |
| `ring` | 209 | 202 | 213 (+60) |
| `publish-gate-swift` | 207 | 183 | 189 |
| `embedded-esp-core` | 202 | 206 | 197 |
| `publish-gate-rest` | 160 | 202 | 185 |
| `suites (swift, gates)` | 187 | 154 | 194 |
| `suites (csharp)` | 87 | 83 | 82 (+41) |
| `suites (rust)` | 73 | 71 (+71) | 59 |
| `embedded-arm` | 59 | 70 | 58 |
| `suites (cpp)` | 44 (+61) | 56 (+66) | 43 |
| `suites (typescript)` | 37 (+88) | 39 (+26) | 38 |
| `suites (java)` | 23 (+74) | 25 | 26 (+44) |

Swift steps from the `swift (...) suite timing` and `ring preparation timing` notices:

| Step | Run 1 | Run 2 | Run 3 |
|------|------:|------:|------:|
| tests: `swift build --build-tests` (debug) | 99 | 48 | 97 |
| tests: `swift test --skip-build` | 37 | 21 | 37 |
| tests: `swift_fuzz` (60 s by design) | 72 | 66 | 71 |
| speed: `swift_speed` (release build with tests, strict flags, then the speed tests) | 185 | 131 | 181 |
| gates: `swift build --build-tests --sanitize=thread` | 101 | 85 | n/r |
| ring: `swift-drivers` (release, `--static-swift-stdlib`) | 84 | 89 | 120 |
| ring: `pull-swift` / `pull-gcc` (in parallel) | 68 / 73 | 62 / 71 | 37 / 41 |

Every Swift build starts from nothing on every push: the suite containers keep their build output in `/tmp/packbin-swift-build` inside the container (`docker-compose.test.yml` `PACKBIN_SWIFT_SCRATCH`), the ring builds into `/tmp/packbin-ring-swift` on a fresh runner. In every run three jobs wait for a runner slot (23 jobs, 20 at a time on the free plan); which three is chance, and in run 3 it was `ring` (+60 s), which made the wall 273 s.

1. **C3, SwiftPM dependency caches**: the build output of the three Swift suite parts and of the ring's Swift driver build is restored from `actions/cache` before the build and saved only when the dependencies change.
2. **At most 20 jobs**: short suite jobs merge so no job waits for a slot.
3. **D4**: the gcc pull moves after the swift pull in `ring` only if the first measured run shows `ring` above the floor.
