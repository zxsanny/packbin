# Autodev loop record - loop 93

loop: 93
branch: dev
plan_artifact: _docs/loops/loop93/plan93.md
tasks_shipped: [AZ-3469_m33f_128k_ram_window]
decisions:
  - owner (2026-10-31, hopper empty): asked for the Go window floor; the agent probed it on HEAD dac8d6f (26 failed CI runs of the last 200, none with a Go proxy or "asked once only" message) and the owner then said "Pick another"; of the remaining handoff candidates the `nostd` ring driver is moot (the Rust ring driver already uses `packbin::nostd`, assessment77), cycle timing needs hardware, and the owner chose "128 KiB RAM view"
  - agent: one change of the shared `mps2-an505.ld` (`RAM` 128K) covers both M33F rows; the guard is one stack-top check per linked image against `m33f_ram_end` in `lib.sh`, so a later edit of the script fails the rows; no new row, so the pinned row counts of `lib.test.sh` and `run-parts.test.sh` stay
  - agent: the Rust M33F row links into the same script, so it was probed (Rust 1.98 toolchain and ARM targets installed on this host through `rustup`, libs built into the gitignored `rust/embedded/build*`) and given the same check
  - agent: Jira AZ-3469 created at intake (Task, Medium, story point estimate 3 sent but not read back, no epic); In Progress, then In Testing after the commit (read back from the transition results)
measurements:
  - probe in a scratch copy at HEAD: both rows green at 128K with unchanged figures
  - real `cpp-embedded` and `rust-embedded` compose runs: 6 of 6 arm rows PASS, `rust-m4f`, `rust-m33f`, `rust-mutants` PASS; `cpp-m33f` 315 of 315, 25,760 B, 724 B, 8,416 B, 912 B
  - failure runs in scratch copies: 130 KiB array used by `main`: ``region `RAM' overflowed by 3264 bytes``, `cpp-m33f` FAIL; script at 4M: 4 `cpp-m33f` and 5 `rust-m33f` images FAIL naming 38020000 (found 38400000); a first array that nothing referenced was dropped by `--gc-sections` and passed (injection error, not a gate gap)
  - `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded,scaffold`: 3 passed, 0 failed, 186 s (scaffold 162 s, arm 21 s, rust-embedded 3 s)
review: "code-review (low): 0 findings; feature assessment COMPLETE (assessment93.md)"
retro: none (3 points, no incident; next retro due after loop 97)
leftovers:
  - the run is a 128 KiB window in the secure alias, not a TrustZone non-secure image; the part's memory map, RRAM and timing stay unchecked (accepted risk, Medium)
  - not run locally this loop: go, typescript, csharp, python, rust, java, cpp, swift, ring, ac10 and the publish gate (no source they build changed); CI runs them on the close push
  - a plain `scripts/loop-tests.sh` was started by mistake and stopped after about 30 s; six containers it started (two `postgres:18`, two `testcontainers-ryuk`, `packbin-python-run-d7bc7503e0c2`, `packbin-go-run-7d9df3e8da43`) were still running when the harness refused the agent's `docker rm -f`; owner: remove them if they are still there
  - `shellcheck` is not installed on this host (`bash -n` only)
  - Go window floor of 10 s stays conditional on a stalled ask that no CI run shows; `nostd` ring driver candidate is moot; cycle timing needs a real part
  - owner: apply the F44 ruleset and tag `v0.4.0` (CS-D5 is decided); close the epic AZ-2750; U24; the M4F row; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring
  - Jira: AZ-3469 In Testing
smoke: PASS (owner, 2026-10-31: the agent walked all 6 checks, the owner answered PASS; no UI, no local deploy)
smoke_artifact: _docs/loops/loop93/smoke93.md
assessment_artifact: _docs/loops/loop93/assessment93.md
loop_end_merge: main
