# Loop 33 scenarios — CI speed 4 (AZ-2626)

Fit walk of `new-task` Step 4.7 (5 points: up to 8 rows). All rows `confirmed` (silent proceed); the owner answered the scope decisions D1 to D6 in one batch (`problem.md`).

## Fit (today → after)

| Area | Today | After | Who depends on today | Collision |
|------|-------|-------|----------------------|-----------|
| `ring` job | every step after the one before; Swift wiring check first | pulls and Swift driver build in the background from the first step; npm, cargo, Go builds at the same time; a wait step before the version check | `ring-wiring.test.sh` (Go build line `bash .github/workflows/ring-go.sh <out>` in a ring step), `ring-wiring-swift.test.sh` (Swift build line and the wiring step in the ring job) | both guards pin the old forms: their rules change with the move (card 1) |
| `scaffold` job | 9 checks | plus the Swift ring wiring check and the new script's test | `scripts/loop-tests.sh` scaffold list (by hand) | the Mac list gains the new test |
| gate pull steps | all eight images in seven jobs | the union of the images each job's groups start | `publish-jobs.test.sh` (`languages.all?`) | rule changes from "all eight" to "exactly the job's images" |
| Mac ring stage | `language-pair.sh` builds drivers lazily | unchanged (the preparation script is CI-only) | `scripts/loop-tests.sh` ring stage | none |

**Card 1 — `ring-wiring.test.sh` is at the 500-line cap.** The Go rule must accept the build through the preparation script. Options: A change the Go rule in place (no net lines) and put the new rules (the script runs before the toolchain check, it calls `ring-go.sh` and `ring-swift.sh`, nothing builds in the background past the wait) in the new script's test; B split `ring-wiring.test.sh` first. Recommended A (auto-applied): no split for a one-rule change. Resolved.

## Scenario matrix

| # | Actor / trigger | State | Proposed behavior | Status | AC |
|---|-----------------|-------|-------------------|--------|----|
| 1 | push to `dev` | everything succeeds | pulls and Swift build overlap the setup actions; builds run at once; one timing notice; the ring runs as before | confirmed | AC-2, AC-3, AC-5 |
| 2 | push | the swift (or gcc) pull fails | the wait step fails, names the pull, prints its log | confirmed | AC-4 |
| 3 | push | the Swift driver build fails (compile error) | the wait step fails, names the Swift driver build, prints its log | confirmed | AC-4 |
| 4 | push | a background pull or build hangs | the wait gives up after at most 15 minutes, names it; the job fails before its 30-minute timeout | confirmed | AC-4 |
| 5 | push | npm, cargo or Go build fails while the others run | the build step fails naming it; each build's log is its own file, printed on failure | confirmed | AC-4 |
| 6 | push | runner image moved to Ubuntu 26 mid-loop | `ring-toolchains.sh` stays the authority; a failure is fixed in the second push (D4); the image of each run is recorded | confirmed | AC-1 |
| 7 | editor moves a container group to another gate job | pull lists unchanged | `publish-jobs.test.sh` fails naming the job and the missing or extra image | confirmed | AC-7 |
| 8 | editor makes a group start a new image | map unchanged | not caught; compose pulls the image on first use, the group gets slower (accepted-risk, `problem.md`) | confirmed | — (Excluded) |
