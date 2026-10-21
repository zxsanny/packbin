# Loop 54 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke54.sh` in this folder (`bash _docs/loops/loop54/smoke54.sh`; Docker, `dotnet` and `python3.14` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The hostile case file holds 72 cases (two new `pack` cases) and `check-cases.sh` / `cases.test.sh` pass
- [x] 3. The loop test stages whose files changed since step 11 pass (csharp, cpp, scaffold; 11 skipped as unchanged)
- [x] 4. Mutant on a copy of `cpp/`: a `when` that ignores a skipped source fails the corpus cases (`010005`) and the new tests (10 failing checks)
- [x] 5. C#: 200 rounds of one 65,535-character text take at most 250 ms in 12 of 12 timings (3 runs, typed and dictionary, both targets)
- [x] 6. Mutant on a copy of `csharp/`: a text cache that never compares the text fails 5 reuse tests
- [x] 7. Embedded stage: Cortex-M4F flash 7,952 B of 8,192 (margin 240 B), stack 504 B of 512 (margin 8 B), M0+, M3 QEMU, s390x and AVR Uno pass

## Result

Agent run 2026-10-21 at `aaafdf6` (owner rule 2026-10-12 in `deployment_procedures.md`): **7/7 steps passed**, second run about 240 s. The first run (6/7) failed step 5 on a script bug (`awk` took the word "ms" for the number); the script was fixed, not the check. Step 11 at `0646aaf` (`scripts/loop-tests.sh`): 13 passed, 1 skipped as unchanged (`publish-gate`), 0 failed, 836 s.

## For the operator

- Jira: AZ-2815, AZ-2816 and AZ-2823 are In Testing; the epic AZ-2645 is open.
- The Xcode licence on this Mac lapsed during the loop: `sudo xcodebuild -license` (needs your password). Until then `/usr/bin/python3` and `clang` refuse to run; the agent used `python3.14` from Homebrew and `gcc:16` in Docker.
- Owner input still open from loop 53: size limits for `text`, `ecc` and `session`; CS-D5; the first `v*` and `go/v*` tags; F44; close the epic AZ-2750; whether to close U24 in the C++ package.
