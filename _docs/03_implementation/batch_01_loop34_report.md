# Batch Report

**Batch**: 1
**Tasks**: AZ-2627_ci_speed_5
**Date**: 2026-10-17

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2627_ci_speed_5 | Done (CI proof pending: AC-1 to AC-5 and AC-7 are measured on the `dev` runs) | 9 files (1 new) | 7 of 7 guards pass; gate groups `workflow`, `static` pass; real Swift `tests` part in `swift:6.3.3` passes twice | None |

Files: `.github/workflows/swift-ccache.sh` (new, 109 lines), `run-suite.sh`, `ring-swift.sh`, `ring-prepare.sh`, `test.yml`, and the guards `publish-jobs.test.sh`, `run-suite-swift.test.sh`, `ring-wiring-swift.test.sh`, `ring-prepare.test.sh`, `ring-wiring.test.sh` (one line changed in place, still 500 lines). `docker-compose.test.yml` is unchanged: CI mounts its kept directories at the container paths the service already uses.

What changed:
- `test.yml` `suites`: 7 entries (`csharp rust` and `cpp typescript java` share a job; the workflow makes 20 jobs, was 23). The step runs each suite of its entry, keeps going after a failed one and fails at the end naming them. The three Swift parts restore `$RUNNER_TEMP/swift-cache` with `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9` (v6.1.0), key `swift-v1-<part>-<swift pin>-<hash of Package.swift, Package.resolved>`, no restore-keys, never on a tag run; the suite step mounts `build` and `ccache` at `/tmp/packbin-swift-build` and `/tmp/packbin-swift-ccache`, passes `PACKBIN_SWIFT_CACHE` (hit or miss) and, after a miss, gives the files to the runner's user so the save can read them.
- `ring`: the same cache for `/tmp/packbin-ring-swift` (key on `RING_SWIFT` and the root and driver manifests) before the background start; the start step passes the cache state.
- `swift-ccache.sh`: installs ccache (the kept `.deb` files with `dpkg`, else `apt-get` into its own directory, the packages then copied to `<dir>/debs`), sets `CC=/usr/lib/ccache/clang` and `CCACHE_DIR=<dir>/cache`, zeroes the statistics, and gives one summary line (hits, misses, set-up seconds, or why it is unavailable). Best-effort: a failed install builds without it. Sourced by `run-suite.sh`; run by `ring-swift.sh`'s container as `swift-ccache.sh run <dir> <uid> <gid> <command>` (set up as root, the build as the caller through `setpriv`).
- `run-suite.sh`: with `PACKBIN_SWIFT_CACHE` set, starts ccache before the Swift steps and adds `run-suite: swift cache <state>; ccache <summary>` to the timing notice. Unset (the Mac): nothing changes.
- `ring-prepare.sh wait`: the Swift build's `ring-swift: cache` and `swift-ccache:` lines go into the ring's timing notice.

Proof before the commit:
- Real run on the Mac of the `tests` part through compose with CI's mounts (fuzz 5 s): miss, debug build 52 s, `ccache 0 hits, 372 misses, ready in 24 s` (apt-get), suite 129 s; after a tar round trip of the kept directory (new file identities): debug build 9 s, `ccache 372 hits, 0 misses, ready in 1 s` (dpkg of the kept packages), suite 59 s. Kept: 251 MB build output, 10 MB ccache, two packages (ccache, libhiredis). The Mac run did not refresh the source times as a checkout does, so its 9 s leaves out the rebuild of the package's own 93 units that CI will do.
- Guards: `publish-jobs.test.sh` (24 new mutants, all refused), `ring-wiring-swift.test.sh` (8 new mutants and one behaviour row: the kept-output build goes through `swift-ccache.sh` as the caller, no `--user`), `run-suite-swift.test.sh` S12a to S12g, `ring-prepare.test.sh` row 1b and one new mutant.
- Mutants of the new code (scratch copies of the tree): 7 of 8 rejected by `run-suite.test.sh`; the eighth (`swift_ccache_start` returns 1 instead of 0 after a failed install) is equivalent, since `run-suite.sh` ignores that status by design; the same fault as an `exit 1` is rejected (S12e).
- shellcheck: no new finding in the scripts; the tests gain only `SC2016` infos (literal `${{ }}` in mutant strings).

## Code Review Verdict: pending (one total review over the loop diff, before step 11)

## Test Suite

- Guards run: 7 (all pass); gate groups: 2 (pass); real container runs: 2 (pass)
- Full step 11 (`scripts/loop-tests.sh`): after the total review

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `publish.yml` calls `test.yml` on a `v*` tag, so a tag's test run would restore caches | AZ-2627 flagged concern "a cache could give a wrong green" (mitigation: release builds from nothing) | the cache steps do not run on a tag ref; a tag's test run builds Swift from nothing | clear |
| 2 | the workflow makes 20 jobs, not 19: the suites were 10 entries before, not 11 | AC-2 (at most 20) | 20 kept; one more merge would put a shared job near the 198 to 222 s floor | clear |
| 3 | `publish-jobs.test.sh` and `ring-wiring.test.sh` refuse any `if` on a step of `suites` and `ring` | AC-10 | the only allowed `if` is on a step that `uses: actions/cache@<sha>`; the image-tag step runs for every entry and the owner fix sits inside the suite step, so no other step has an `if`; mutants prove both | clear |
| 4 | `apt-get update` alone took 24 to 26 s on the Mac per Swift job | AC-4 | the ccache packages are kept in the cache and installed with `dpkg` on a hit (1 s) | clear |
| 5 | `apt-get` leaves a root-only lock file in its archives directory, which the cache save (tar as the runner's user) could not read | AC-5, AC-7 | `apt-get` downloads into a temp directory; only the `.deb` files are copied | clear |
| 6 | the suite container writes the kept files as root | AC-5 | `sudo chown -R` to the runner's user after a miss, inside the suite step | clear |
| 7 | `ring-wiring.test.sh` is at its 500-line cap | AC-11 | its rule changed in place; the ring's cache rules and the "if on another ring step" mutant are in `ring-wiring-swift.test.sh` | clear |
| 8 | `--disable-index-store` on the debug builds (planned "if the measured runs show it helps") | plan34 Implementation | not in batch 1: ccache caches the C compiles with the index-store flag (3 of 3 cacheable); decide from the CI notices | clear |

## Commit

`[AZ-2627] Swift build caches with ccache, 20 jobs` — body: one line + `Loop: 34`.

## Next Batch: none planned; batch 2 only if the measured runs miss (D4 gcc pull order, cache tuning)
