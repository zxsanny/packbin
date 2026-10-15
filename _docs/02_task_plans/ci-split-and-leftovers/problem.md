---
loop: 28
branch: dev
---

# Loop 28 — CI speed and the loop 26/27 leftovers (AZ-2223 follow-up)

Loop 28 (on `dev`; no worktree). Owner (2026-10-15): "check on build and test performance - are these issues resolved, and build and tests now are the most efficient as possible? then do that" and the three leftover items below; decision batch "accept all recommended" (speed work: split the CI `scaffold` job, add per-check timings to the publish gate test). Hopper otherwise empty; AZ-2068 (C++ AVR stretch) stays held.

## What

**Speed check (done at intake, findings).** Resolved: the publish gate failure (cause: the test's `swift` stand-in printed nothing for `--version`), CG-1 to CG-8 of loop 27 met, 4 green gate runs in a row. CI `test.yml` went from 44 to 33 to 38 min; the Swift stage from 651 s to 349 s locally. Not as fast as possible:
1. The CI `scaffold` job runs the 8 language suites (860 to 984 s) and then the publish gate (1 060 to 1 245 s) one after the other in one job: 1 977 to 2 295 s end to end, while `ring` (245 to 283 s) and `embedded` (317 to 352 s) run beside it. Nothing ties the gate to the suites, so the wall time can fall to the gate job alone.
2. The publish gate test runs about 17 check groups in one process with no timing per group: 1 077 s locally (66 % of step 11, 1 626 s), of which the Swift scenarios are 330 s; about 750 s is unattributed, so it cannot be cut by evidence yet.
3. On the Mac the gate runs alone after the pool (it hashes the repository tree). Not changed in this loop (owner option "gate on the Mac in parallel" was not chosen).

**Items to do (owner's three bullets).**
- S3: write the limit "a Swift 6.0 consumer and an Xcode 16.0 build are unproven (swift-asn1 1.7.3 needs tools 6.1); only `swift:6.3.3` (CI) and `swift:6.4.1` (Linux container run) are built" into ADR-005 and the README, where the README now says "Swift 6.0+ (Xcode 16+)".
- The cpp stage race: the `cpp` pool stage failed once in loop 27 step 11 (`ld: cannot open output file build/packbin_tests`) because `cpp/build/` is shared with another stage running at the same time; the `scaffold` stage was named as the other party, but the command that writes there is not pinned. Name the cause by reproduction, then remove the shared path or the overlap.
- The small items of loops 26/27: review26 #5 (no peak-memory figure for the Swift max-slots unpack: the F10 packet and the default-limit wide round; Go measured 625 MB and 94 MB) and review26 #8 (README names Linux and CI results before a Linux run; Linux CI has now run, so reword to what ran).

**Speed work to do (owner chose the recommended set).** (a) Split `scaffold` in `test.yml` into jobs that run in parallel: static checks, the 8 suites, the publish gate; (b) add a per-check timing line to `publish-gate.test.sh` (and its sourced check files) so the next loop can cut the gate by evidence.

## Code sections / UI locations for this loop

Backend / CI, no UI. Named by the owner's items: ADR-005 (`_docs/02_document/adr/005_swift-installs-from-the-version-tag.md`) and the README Swift lines; the cpp stage and the shared `cpp/build/` (stage list in `scripts/loop-tests.sh`, `docker-compose.test.yml` `cpp` service, `cpp/Makefile`); the Swift max-slots unpack (the F10 packet and the default-limit wide round: `swift/` tests and `fixtures/hostile/`); the speed work: the `scaffold` job in `.github/workflows/test.yml` and the guards that read it (`publish-gate.test.sh` line 317 ruby over `scaffold`/`embedded`, `ring-wiring.test.sh` line 124 `scaffold`, `run-suite-swift.test.sh` line 239 `for lang in` loop, `report-row.test.sh`), and `.github/workflows/publish-gate.test.sh` with the files it sources. `publish.yml` calls `test.yml` (`uses: ./.github/workflows/test.yml`, `needs: test`).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The CI split is proven only by a pushed CI run; a push of `dev` is asked from the owner each time | owner (pushes asked) | open | Medium |
| Guards read the `scaffold` job by name and step text (3 files); a split that leaves one stale passes locally and fails in CI, or worse stops guarding | meta-rule "no stand-in": every guard is moved with its check and mutation-proved | open | High |
| The cpp race cause is not pinned (the "scaffold builds C++" claim is unverified); a fix on a guessed cause repeats the loop 27 mistake | meta-rule "debugging over contemplation": reproduce first | open | Medium |
| More parallel runner jobs raise total runner minutes (job set-up repeated, images pulled per job) | owner accepted the trade for wall time | accepted-risk | Low |
| A Swift peak-memory figure above the Go figure is a finding, not something to fix in this loop | owner; recorded as a finding | open | Low |
| No tag, no registry upload, no force-push (F44 and the first tags are the owner's) | owner | resolved | — |
