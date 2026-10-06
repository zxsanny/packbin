# Feature assessment — loop 15

loop: 15
feature: close the three open Medium security findings (epic AZ-2069: AZ-2214 F12, AZ-2215 F13, AZ-2216 to AZ-2220 F10)
rounds: 1
verdict: COMPLETE (Q1 and Q2 accepted by the owner, option A)
report_of_round: 1

## Round 1

**Date**: 2026-10-06
**Implement pass**: batches 01 to 03 (commits `b351b4a`, `7341a54`, `4300410`), batch reports `_docs/03_implementation/batch_0{1,2,3}_loop15_report.md`.
**Verdict**: COMPLETE after the owner's answers — 38 covered / 9 out-of-scope (7 declared + Q1 and Q2 accepted) / 0 gap-clear / 0 gap-unclear. The round found CLARIFY (2 gap-unclear); the owner answered on 2026-10-06: Q1 A, Q2 A.

**Intent baseline.** `_docs/02_task_plans/unpack-limits-and-ci-hardening/problem.md` (decisions D1 to D7, scenarios S1 to S13, loop criteria AC-L1 to AC-L6) and the seven specs now in `_docs/02_tasks/done/`. The owner request was "Fix F10, F12, F13" with F10 option A (a limit on unpack).

**Method note.** One reader (the parent) read the specs, the three batch reports with their `## Discovered during implementation` tables and review findings, and the diffs. Rows are grouped by task where the ACs share one test group; the per-AC test names are in the batch reports. GitHub's behavior on the Ubuntu runner (Compose 2.38.2 merge of the second compose file, the `/out` bind mount, file ownership, the pinned actions and pip tools on Python 3.12.3) cannot run locally: those rows are `covered` for the structure and the checks only, and the first CI run after the push decides.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| P1 | AZ-2214 AC-1/AC-2: every non-local `uses:` is `owner/repo@<40 hex> # <tag>`; 13 violating copies are rejected | covered | AC-1, AC-2; `publish-pins.test.sh` Ruby `uses:` check on `*.yml`; `publish.yml`, `test.yml` | AZ-2214 |
| P2 | AZ-2214 AC-3/AC-4/AC-5: one pins file, every pip install and the npm step read it, wheels only, a bump is one edit | covered | AC-3 to AC-5; `tool-pins.txt`, `tool-pin.sh`, `pip_install_pinned` in `publish-lib.sh`; stub-pip test, real install into a throwaway venv froze the pins | AZ-2214 |
| P3 | AZ-2214 AC-6: the published wheel was built by the pinned setuptools | covered | AC-6; `PIP_CONSTRAINT` in `publish-inside.sh`; wheel `Generator: setuptools (84.0.0)` | AZ-2214 |
| P4 | AZ-2214 AC-7/AC-8: test jobs use the same pins and still hold no secrets; the bump procedure is documented | covered | AC-7, AC-8; `test.yml`, `run-suite.sh`, `_docs/04_deploy/ci_cd_pipeline.md` | AZ-2214 |
| R1 | AZ-2215 AC-1/AC-2: a container cannot write, create, delete or chmod under `/src`; only its own artifacts folder is writable | covered | AC-1, AC-2; `docker-compose.publish.yml`, `publish_container`, `publish-readonly.test.sh` probe in all six services; negative proof (7 of 7 writes without the override) | AZ-2215 |
| R2 | AZ-2215 AC-3/AC-4/AC-5/AC-6: nine builds still produce the same artifacts; C# packs from a copy; the golden gate gives the same output; the tree manifest is unchanged | covered | AC-3 to AC-6; full build-only run on a tree copy, nine `build ok`; `publish-inside.sh`, `publish-position.sh` | AZ-2215 |
| R3 | AZ-2215 AC-7/AC-8: the mount cannot be dropped silently; the chown and `PACKBIN_DOCKER=0` behave as before | covered | AC-7, AC-8; config test and mutation test; ownership asserted only on Linux | AZ-2215 |
| C1 | AZ-2216 AC-1 to AC-11 (C#): defaults and `WithLimits`, repeat and times refused at the round past `maxRounds` or `maxSlots`, slot total per call, limits per scheme, invalid limits refused, existing tests unchanged | covered | AC-1 to AC-11; `csharp/tests/RoundLimitTests.cs` (17 tests), 407 of 407; mutation fails 8; 169.5 MiB against 2,704 MiB | AZ-2216 |
| T1 | AZ-2217 AC-1 to AC-11 (TypeScript) | covered | AC-1 to AC-11; `typescript/tests/round-limits.test.ts` (35 tests), 276 of 276 then 279; mutation fails 13; 85 MB against 400 MB | AZ-2217 |
| J1 | AZ-2218 AC-1 to AC-11 (Java, incl. the list-element slot total) | covered | AC-1 to AC-11; `RoundLimitsTest` through `PackbinTest`, all runners and `api-check`; mutation fails 25; 34 MB heap against 540 MB | AZ-2218 |
| U1 | AZ-2219 AC-1 to AC-13 (Rust: map and typed, `times` rows, `times` inside `repeat`, eight flag bits) | covered | AC-1 to AC-13; `rust/tests/round_limits_tests.rs` (17 tests), 234 of 234; mutation fails 10; 20 to 57 MB against 281 to 1,175 MB | AZ-2219 |
| H1 | AZ-2220 AC-1 to AC-5: the `limit` stage, two cases, 19 cases ok, the 17 older lines unchanged and replayed | covered | AC-1 to AC-5; `cases.txt`, `check-cases.sh`, `cases.test.sh`; four replays; mutations fail the replays | AZ-2220 |
| H2 | AZ-2220 AC-6/AC-7/AC-8/AC-9: C++ skips the stage, a generated default-limit test in each package, the README states the limits with measured figures, the security notes | covered | AC-6 to AC-9; C++ and Python suites green; README Untrusted input | AZ-2220 |
| L1 | Loop AC-L1 to AC-L4 (limits refuse, defaults accept, per scheme, hostile and generated tests) | covered | C1, T1, J1, U1, H1, H2 above | problem.md |
| L2 | Loop AC-L5 and AC-L6 (pins, read-only mount) | covered | P1 to P4, R1 to R3 above; CI first run for the Linux-only parts | problem.md |
| D1 | Review finding: `ls-remote` style pipeline reads are not part of this loop's code | covered | n/a: no such pattern added; batch reviews found 0 Medium | batch reviews |
| D2 | `typescript/tests` not covered by strict `tsc` (missing Node types) | out-of-scope | the CI check is `src` only, unchanged by this loop (AGENT_GOTCHAS) | batch_03 |
| D3 | C# `WithLimits` and TypeScript `withLimits` reset an omitted limit | covered | AC-1 (stated on purpose); the README states it and shows the chained example | batch_01 finding 1 |
| D4 | Rust panics on a zero limit where the other packages throw | covered | AZ-2219 AC-12 (the spec's choice); the README states it | batch_02 finding 2 |
| X1 | C++ and Python get no limit | out-of-scope | problem.md "Out of scope" and AZ-2220 `### Excluded`: fixed arrays with `Error::TooMany`; Python keeps only read values (36 MiB) | problem.md |
| X2 | Compact round representation (option B) | out-of-scope | problem.md "Out of scope": owner chose option A | problem.md |
| X3 | A distinct error kind for the refusal (C15) | out-of-scope | problem.md "Out of scope": the interim error is used | problem.md |
| X4 | F14 to F16, F1 to F3 (open Lows), a `tsc` job in `test.yml` | out-of-scope | problem.md "Out of scope" | problem.md |
| X5 | Hash-checking pip installs and the transitive pip closure (F12 not fully closed) | out-of-scope | AZ-2214 Flagged concerns: accepted (F12 reduced, not closed) | AZ-2214 |
| X6 | The v0.2.2 tag | out-of-scope | problem.md "Out of scope": after the loop, with its own go | problem.md |
| X7 | Python hostile replay of the `limit` stage | out-of-scope | AZ-2220: Python has no round slots (aligned rounds not implemented, AZ-2134) | AZ-2220 |
| Q1 | Slot counting differs by package (C# distinct names, TypeScript names of the round, Java value fields, Rust fields), so a packet right at the slot limit can pass in one package and fail in another | out-of-scope (accepted loop 15, option A) | owner answered A on 2026-10-06 after asking what the risk of keeping it is; risk judged Low (see below) | batch_01 finding 3, batch_03 |
| Q2 | Between the check and the upload, host-side steps still hold write access to earlier artifacts (the embedded targets run pip tools on the host, `publish-sign.sh` writes `artifacts/java`, `cargo publish` re-archives the staged tree) and nothing re-verifies the files; F13's remediation "sha256 of every artifact at check time, verified before upload" is not done | out-of-scope (accepted loop 15, option A) | owner answered A on 2026-10-06 | AZ-2215 Flagged concerns |

### Gaps that need a decision (gap-unclear)

#### Q1: should the slot count be the same in every package?

**What is not decided**
The slot limit counts "the names a round can hold", and each package counts them its own way: C# counts distinct member names, TypeScript the names of the round, Java its value fields, Rust its fields. For ordinary schemes the numbers are equal, but a round that holds a named flag byte or the same name twice gives different counts, so a packet sitting right at 4,194,304 slots could be accepted by one package and refused by another. The README states this. No test compares the counts across packages.

**Options**
- **A — Keep it and the README note (recommended)**: nothing changes now. A packet at the exact slot limit is an edge case, and the rounds limit (65,535) is the one that stops the amplification in practice. Trade-off: two packages can disagree at the exact boundary.
- **B — One definition and a ring**: define the count as the distinct names a round can store, make all four packages follow it, and add a `language-pair.sh` ring that unpacks the same boundary packet in all four. Trade-off: a follow-up task of about 5 points across four packages and a ring.

**Recommendation**: A — the disagreement only matters at the exact limit, the README says so, and B costs a task per package for an edge.

#### Q2: add a digest check between the build check and the upload?

**What is not decided**
The read-only mount stops a build container from changing scripts, sources or other targets' artifacts. Steps that run on the host still can: the embedded targets install pip tools there, `publish-sign.sh` writes the Java bundle, and `cargo publish` packs the staged tree again. Audit F13 also proposed recording a SHA-256 of every artifact when it is checked and verifying it just before the upload. That is not built.

**Options**
- **A — Accept (recommended)**: F13 is reduced to host-side steps that are our own scripts running pinned tools (F12). Trade-off: a compromised host-side pip tool could still alter an artifact between check and upload.
- **B — Add the digest check**: `publish-check.py` writes the SHA-256 of each artifact file to `build.log`, `publish-upload.sh` verifies them before each upload; Rust uploads the checked `.crate` instead of re-packing. Trade-off: about 3 points and a change of how `cargo publish` is invoked (it re-archives today by design), which needs a real tag run to prove.

**Recommendation**: A — the digest check mainly protects against a tool we now pin; it is the last step to close F13 fully and can follow the first green tag.

### Owner answers (2026-10-06)

- **Q1: A.** The owner asked what the risk of keeping it is, with the rule "if low, keep; if medium or high, B". Assessed as Low: the packet cannot change which names a round holds (the scheme author sets that), so there is no attacker gain; each package still enforces its own slot limit and the 65,535 rounds cap, so memory stays bounded by the rounds cap times the per-round cost of the body (about 30 MB for a 36-name body in C#, TypeScript and Java, 20 to 85 MB in Rust); the undercounts are small (C# does not count a named flag byte, Java counts a nested-row group as one slot) and cannot exceed that bound; the README states the difference. The only effect is that a packet landing exactly at the slot limit can pass in one package and fail in another.
- **Q2: A.** Accepted: F13 is reduced to host-side steps that run our own scripts and pinned tools; the digest check can follow the first green tag.

### Gaps that are clear (gap-clear)

None.

### Not walked

- `docker-compose.publish.yml` and its config test list the six services by hand: a seventh service added to the base file would stay read-write (batch_02 finding 1). A follow-up: read the service names from `docker compose config --services`.
- Round-holding list and dictionary elements still cannot be tested in C# (AZ-2119); the budget reaches those scopes by construction.
- `Nfr_RoundTripsWithinOneSecond` fails at about 1.1 s when the load average is above 30.
- `dotnet format` reports whitespace errors in two files this loop did not touch.

### Harness gaps

- None: every batch report has the `## Discovered during implementation` heading. One process note: the AZ-2214 worker ran `git stash` and `git stash pop` once while other workers were writing; the tree was intact afterwards and every later full run passed.
