# Loop 27 handoff — written 2026-10-14 while loop 26 was closing

The intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 26 = last closed once the close finishes). Read `_docs/loops/loop26/plan26.md`, `notes26.md`, `review26.md`, `assessment26.md`, `record26.md`, `_docs/03_implementation/batch_01..10_loop26_report.md`, `test_run_loop26_report.md`, `_docs/06_metrics/retro_2026-10-14_loop26.md` and `_docs/05_security/security_report.md` (loop 26 addendum) first.

## Owner working preferences (unchanged, plus loop 26)

- Everything in `_docs/loops/loop25/handoff26.md` § Owner working preferences stands: workers run only their suite; one total review (put it in the plan, before step 11) and one step 11 run; decision batches with "accept all recommended" first; `< /dev/null` on every worker command, no index writes, no formatter on files a worker does not own; the C# test recipe `env MSBUILDDISABLENODEREUSE=1`; Go only in Docker.
- **Swift on this Mac:** Command Line Tools only: `swift test` needs the `-F`/rpath flags of `_docs/AGENT_GOTCHAS.md`. One `swift build`/`swift test` at a time in the root tree. The Swift suite runs in the `swift:6.3.3` container too (pulled; 3.98 GB).
- **Run the new language's suite in the CI container early** (after the core task), not at step 11: loop 26's first container run found five defects (lesson in `LESSONS.md`).
- A sanitizer run is 10 to 40 times slower in the container: single-threaded size and speed tests skip under it (`.enabled(if: !threadSanitized)`), time bounds are asserted in the plain runs.
- A tag needs the owner's explicit go with the exact commit. The first tag also runs the live Swift consumer resolve and the live Go proxy check.
- Downloads: SwiftPM fetches swift-crypto and swift-asn1 from github.com and Docker pulled `swift:6.3.3` (owner approved, 2026-10-14); nothing else.

## Where things stand when loop 26 closes

- `todo/` holds 1 spec (AZ-2068 C++ AVR stretch); `done/` gains AZ-2513 to AZ-2524 (12 specs, 47 points). Jira: the 12 tasks are In Testing; the epic AZ-2223 stays open until the first tag resolves.
- Done in loop 26: the Swift package (`swift/`, root `Package.swift`, tools 6.0, iOS 15, macOS 12; swift-crypto 4.3.1 off Apple platforms only), 340 tests in 56 suites, 65 hostile cases, the fuzz corpus `fixtures/hostile/fuzz/`, the ring with Swift (136 hand-off lines), the `swift` CI service on `swift:6.3.3`, ADR-005 (Swift installs from the root `Package.swift` at the `vX.Y.Z` tag, no Swift tag), the release consumer resolve check (runs without publish credentials), the README Swift section with a code-drift test, security fixes F47 (dictionary keys with more than 30 combining marks in a row are refused), F48, F49.
- Review PASS_WITH_WARNINGS (0 Critical, 0 High, 3 Medium, 5 Low; 2 fixed); assessment CLARIFY (O1 to O3, answered keep); security PASS_WITH_WARNINGS (Medium 4: F10, F12, F47 [fixed], F48 [fixed]; Low 18).
- Differences from TypeScript: `_docs/02_task_plans/swift-package/parity_differences.md`.

## Owner decisions open (each with a recommendation; ask as one batch first)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| S1 | Speed up the Swift stage (741 s) and the publish gate (1 338 s): the sanitizer only on the concurrency and session suites (saves about 5 minutes), a named build-cache volume for the container (about 2), one shared consumer build cache in the gate's Swift scenarios (about 10) | A do it first in loop 27; B leave | A |
| S2 | The zeroing helper uses the underscored `@_optimize(none)` | A keep; B `memset_s` (Darwin) and `explicit_bzero` (glibc) per platform | A |
| S3 | A Swift 6.0 consumer and an Xcode 16.0 build of this repository are unproven (swift-asn1 1.7.3 needs 6.1) | A pin swift-asn1 1.6.0 (the newest at tools 6.0) and add a swift:6.0 consumer resolve; B leave and document | B, unless the owner wants the 6.0 claim proven |
| F44 | Tag protection: a ruleset on `go/v*` and `v*` (creation limited to the publish workflow and maintainers, update and deletion blocked); it now also decides what SwiftPM consumers get | the owner applies it in repository settings | do it before the first tag |
| P1 | Publish gate speed (the old row) | folded into S1 | S1 A |

## Do not start before checking

1. `git status`, `git log origin/main..HEAD`, and the CI state of `dev` and `main` (`test.yml`; no `gh` here: read the Actions page). Loop 26 adds the `swift` service to the scaffold job, the Swift lines of the ring, `RING_SWIFT` 6.3.3, and the Swift check in the publish path; their first Ubuntu run is CI's proof. Read `notes26.md` § First CI run for the list of unknowns.
2. The tree is clean; `_docs/_process_leftovers/` is empty.
3. Ask the open decisions first (one batch with the recommendations).
4. The first `vX.Y.Z` tag with Swift and the first `go/vX.Y.Z`: only with the owner's explicit go, the exact commit, CI green on `dev` and the F44 ruleset applied.
5. Next language epics, if the owner wants one: none are listed in `epics.md` beyond the eight built; AZ-2068 (C++ AVR) is the only spec in `todo/`.
