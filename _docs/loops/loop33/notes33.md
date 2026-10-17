# Loop 33 notes — CI speed 4 (AZ-2626)

## Step times before the change (job pages of the loop 32 runs, no token)

`ring` 268 s / 255 s (runs 39024316436 / 39025925515): set up and checkout 3 / 5, Swift ring wiring 25 / 18, the six setups 29 / 32, `GCC image` 21 / 31, `toolchain versions` 42 / 52 (the 4 GB `swift` pull inside `swift --version`), driver builds 101 / 76, ring 47 / 41. Gate `pull images`: 57 to 87 s per job (run 39025925515: phases 57, rest 59, readonly-gate-good 87). Code trace of the gate groups' images (loop 33 intake): `phases`, `phases-rerun`, `readonly-full` start csharp, typescript, python, rust, java; `pins` python; `readonly-gate-nojava` all but java; `gate`, `readonly`, `readonly-gate-good`, `readonly-gate-bad` all eight; the other groups none.

## First CI run (run 39031026351, `19f4c33`, `dev` push, 23 jobs, all green)

Wall 251 s (created 12:03:19, last job done 251 s later); loop 32: 275 and 264 s. No job waited for a runner slot (every wait 2 s).

| Job | s | Note |
|-----|--:|------|
| `suites (swift, tests)` | 248 | the wall (loop 32: 246 and 180 s) |
| `suites (swift, speed)` | 221 | |
| `publish-gate-readonly` | 211 | all eight images |
| `ring` | **209** | AC-2 target 180 s: missed (loop 32: 273 and 261 s) |
| `publish-gate-swift` | 207 | no pull |
| `embedded-esp-core` | 202 | |
| `readonly-gate-nojava` / `-bad` / `-good` | 188 / 183 / 179 | |
| `suites (swift, gates)` | 187 | |

`ring` steps: set up 8, checkout 2, start 0, setup-dotnet 20, node 1, python 0, java 3, go 25, Rust 11, `driver dependencies and builds` 92 (build + wait), `toolchain versions` 2, ring 39. The `ring preparation timing` notice: `pull-gcc` 73 s, `pull-swift` 68 s (at the same time, so each slower than alone: 21 to 31 and about 42 to 52 s in loop 32), `swift-drivers` 84 s, npm 2, cargo 2, Go 1, the wait 89 s, 152 s from start to the end of the wait. The critical path of `ring` is now the swift pull plus the Swift driver build (`swift build -c release --static-swift-stdlib`, with swift-crypto off Apple platforms); the setups (70 s, slower than before under the parallel pulls: dotnet 20 against 8, go 25 against 10 to 12) and the npm, cargo and Go builds (5 s) are off it.

Pull steps of the five-image jobs: `phases` 35 s (57), `phases-rerun` 35 s (about 57), `rest` 51 s (59).

Owner decision on the miss (2026-10-17): accept `ring` 209 s against 180 s and record it; no second code push; the next lever is C3 (Swift build caches: the ring's driver build and the three Swift suite parts) in loop 34. The other candidate (pull gcc after swift) was estimated at 185 to 195 s and would not move the wall.

## Background processes across steps on the runner

Proven by run 39031026351: the start step ended in 0 s, the pulls and the Swift build ran through the setup steps, the wait collected all six builds; no hang, no orphan warning in the job.
