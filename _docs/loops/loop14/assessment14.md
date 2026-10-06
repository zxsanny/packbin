# Feature assessment — loop 14

loop: 14
feature: publish pipeline (epic AZ-2069: AZ-2094, AZ-2095, AZ-2096, AZ-2097)
rounds: 1
verdict: COMPLETE (3 gaps accepted)
report_of_round: 1

## Round 1

**Date**: 2026-10-06
**Implement pass**: batches 01 to 04 (commits `AZ-2094` batch 1, `d494410`, `724ff1e`, `43af2f6`), batch reports `_docs/03_implementation/batch_0{1,2,3,4}_loop14_report.md`. The code-review reports are inside the batch reports.
**Verdict**: COMPLETE after the owner's `continue` — 32 covered / 9 out-of-scope (6 declared + U1 to U3 accepted) / 0 gap-clear / 0 gap-unclear. The round found CLARIFY (3 gap-unclear). The owner declined the question prompt and typed `continue`; the three rows were recorded with the recommended option A (accept, no code change, watch the first real tag). Any of them can be reopened by the owner at any time.

**Intent baseline.** No loop-level `problem.md` and no `scenarios.md` for this loop (the four specs were already in `todo/`). Baseline: the four specs now in `_docs/02_tasks/done/` and the owner decisions of 2026-10-06 recorded in `plan14.md` (YAML parser, optional upload failure).

**Method note.** One reader (the parent) read the four specs, the four batch reports with their `## Discovered during implementation` tables, the code-review findings, and the production scripts. The AZ-2095 GitHub behavior and the AZ-2097 live Central response cannot run locally; those rows are `covered` only for the structure and the fail-closed code path, and are re-checked on the first real tag.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| A1 | AZ-2094 AC-1: every jar class is Java 17 (major 61) | covered | AC-1; `publish-check.py` java class-byte check, `publish-phases.test.sh` java-major case (major 52 rejected) and the full-publish run on the real jar; `publish-inside.sh` `javac --release 17` | AZ-2094 |
| A2 | AZ-2094 AC-2: main sources compile with `--release 17` | covered | AC-2; `java/test.sh`, worker negative proof (Java 21 call fails); `java/test.sh` | AZ-2094 |
| A3 | AZ-2094 AC-3: no API above Android API 26 | covered | AC-3; `java/api-check.sh` (Animal Sniffer, API 26 signature), negative proof (`Arrays.compareUnsigned` back in fails); `Containers.java`, `Field.java` and five more | AZ-2094 |
| A4 | AZ-2094 AC-4: dict key order and wire bytes unchanged | covered | AC-4; `ApiSafeReplacementsTest` pinned hex, signed-compare mutation fails; `Containers.compareUnsigned` | AZ-2094 |
| A5 | AZ-2094 AC-5: child lists stay immutable copies | covered | AC-5; `ApiSafeReplacementsTest` (mutable-copy mutation fails); `Field.immutableCopy` | AZ-2094 |
| A6 | AZ-2094 AC-6: javadoc built with `--release 17` | covered | AC-6; the javadoc jar check in the build phase; `publish-inside.sh` | AZ-2094 |
| B1 | AZ-2095 AC-1: failing tests publish nothing | covered | AC-1 (structural); Ruby check requires `publish` `needs` the test call, negative copy without `needs` rejected; `publish.yml`. Behavior of GitHub's `needs` re-checked on the first real tag | AZ-2095 |
| B2 | AZ-2095 AC-2: passing tests then publish | covered | AC-2 (structural); same check; `publish.yml` | AZ-2095 |
| B3 | AZ-2095 AC-3: test jobs hold no secrets and no write permission | covered | AC-3; Ruby check, `id-token` at workflow level and `secrets` on the call rejected; `publish.yml`, `test.yml` | AZ-2095 |
| B4 | AZ-2095 AC-4: tests run once per tag | covered | AC-4 (structural); `test.yml` `push: branches: ["**"]`, negative copy with `tags` rejected. First real tag confirms | AZ-2095 |
| B5 | AZ-2095 AC-5: branches and pull requests unchanged | covered | AC-5; Ruby check (`scaffold`, `embedded`, `pull_request`, branch push); `test.yml` | AZ-2095 |
| B6 | AZ-2095 AC-6: structure checked in CI | covered | AC-6; `publish-gate.test.sh` `workflow_structure` runs in the `scaffold` job; four negative copies | AZ-2095 |
| C1 | AZ-2096 AC-1: no upload before every build succeeded | covered | AC-1; `publish-phases.test.sh` ordering (every upload logs build-ok count 9); `publish-upload.sh` refuses without `build ok` | AZ-2096 |
| C2 | AZ-2096 AC-2: a late build failure writes nothing | covered | AC-2; failing `gpg` and failing `pio pkg pack` leave log and bare repos empty; `publish-build.sh` | AZ-2096 |
| C3 | AZ-2096 AC-3: build-only makes no network writes | covered | AC-3; `ph_build_only` (exit 0, 9 artifacts, empty log, dry-run marker refused by upload); `publish-registries.sh` | AZ-2096 |
| C4 | AZ-2096 AC-4: artifacts are verified | covered | AC-4; 20 fabricated artifacts plus two real-pipeline violations; `publish-check.py` | AZ-2096 |
| C5 | AZ-2096 AC-5: uploads send the checked files, no rebuild | covered | AC-5; host-tool log shows no pack or build call, static check on `publish-upload.sh` | AZ-2096 |
| C6 | AZ-2096 AC-6: golden gate order unchanged | covered | AC-6; existing gate checks unchanged and green, empty plan builds nothing; `publish-gate.sh` | AZ-2096 |
| D1a | AZ-2097 AC-1: missing required credential fails before any write | covered | AC-1; 7-run credential matrix (non-zero, names variable, empty log, bare repo unchanged); `publish-registries.sh`, `publish-lib.sh` | AZ-2097 |
| D2a | AZ-2097 AC-2: missing optional credential warns and continues | covered | AC-2; 3 `::warning::` lines, 3 summary lines, required uploaded; `publish-registries.sh` | AZ-2097 |
| D3a | AZ-2097 AC-3: python and rust never silently dropped | covered | AC-3; single-language plans fail naming the variable; `publish-lib.sh` | AZ-2097 |
| D4a | AZ-2097 AC-4: failed required upload fails the run | covered | AC-4 and owner decision; failing `cargo` and failing optional `pio` both exit non-zero; `publish-upload.sh` | AZ-2097 |
| D5a | AZ-2097 AC-5: re-run completes a partial publish | covered | AC-5; second run skips NuGet, npm, PyPI, uploads the rest; `publish-query.sh` | AZ-2097 |
| D6a | AZ-2097 AC-6: re-run of a complete publish is a no-op | covered | AC-6; 9 `already published`, 0 upload commands, bare repos unchanged; `publish-query.sh` | AZ-2097 |
| D7a | AZ-2097 AC-7: no concurrent runs for one tag | covered | AC-7; Ruby check requires `concurrency` keyed by ref without cancel; `publish.yml` | AZ-2097 |
| E1 | An artifact is built once and the upload sends that file | covered | C5 above | AZ-2096 |
| E2 | `ls-remote` failure or SIGPIPE read as an empty registry | covered | review finding 2 of batch 3, fixed; `publish-embedded.sh` `open_registry`; gate re-run green | batch_03 review |
| E3 | `ByteBuffer.flip()` resolved to a Java 9 method under `--release 17` | covered | batch_01 discovery 1; `Walker.java` `((Buffer) buf).flip()`; `api-check.sh` | batch_01 discoveries |
| E4 | A half-uploaded PyPI release must not be read as published | covered | batch_04 discovery 4; `publish-published.py` pypi mode (both files), test "partial PyPI is not published" | batch_04 discoveries |
| E5 | An Arduino tag already at other content must fail the run, not move | covered | batch_04; `--atomic` push, test "tag at other content fails" | batch_04 |
| E6 | A persistent registry query failure is not read as "not published" | covered | AZ-2097 NFR; `registry_fetch` fail-closed, 503 retried then fails | batch_04 |
| E7 | Stale docs (`tests/environment.md`, deployment procedures, system-flows F3, packages.md) | covered | batch_02 discovery 1, docs in batches 2 to 4 | batch reports |
| X1 | Publish duration grows by the full test time (about 40 minutes cold) | out-of-scope | AZ-2095 `### Excluded`: "Making the embedded job faster or cached (D12)" | AZ-2095 |
| X2 | A `workflow_dispatch` dry run to prove AZ-2095 AC-1 without a tag | out-of-scope | AZ-2095 Blackbox Tests: "optional"; the spec accepts structural proof plus the first real tag | AZ-2095 |
| X3 | ADR-002, AC-12, AC-13 wording still says six registries | out-of-scope | AZ-2097 `### Excluded`: "The ADR wording itself is task D19/C29" | AZ-2097 |
| X4 | Golden bytes checked from inside the built artifacts | out-of-scope | AZ-2096 `### Excluded` | AZ-2096 |
| X5 | Release notes should say older Central versions target JDK 26 | out-of-scope | AZ-2094 Flagged concerns row: owner, at the tag | AZ-2094 |
| X6 | Building C++ for vcpkg consumers | out-of-scope | AZ-2096 `### Excluded` (task 29) | AZ-2096 |
| U1 | Token lifetime against the longer build phase | out-of-scope (accepted loop 14, option A) | question below; recommended option A recorded on the owner's `continue` | batch_03 review finding 1 |
| U2 | PlatformIO owner lookup sends the token | out-of-scope (accepted loop 14, option A) | question below; recommended option A recorded on the owner's `continue` | batch_04 discovery 2 |
| U3 | Maven Central `published` endpoint shape and duplicate text are unconfirmed | out-of-scope (accepted loop 14, option A) | question below; recommended option A recorded on the owner's `continue` | batch_04 report |

### Gaps that need a decision (gap-unclear)

#### U1: crates.io and NuGet tokens against a longer build phase

**What is not decided**
`publish.yml` exchanges the NuGet and crates.io tokens before the whole publish script runs. The script now builds all nine targets first, on a fresh runner, then uploads. The crates.io token lifetime is not confirmed (about 30 minutes is believed) and the cold build time on a runner is unmeasured. If the crates.io token expires before upload, NuGet, npm and PyPI are already published and crates.io is not; the new re-run (AZ-2097) can finish it with a fresh token, but the run is red once.

**Options**
- **A — Accept and watch the first real tag**: no change now; read the build duration on the first tag and split the workflow only if it nears 10 minutes. Trade-off: a possible one-time partial release that a re-run fixes.
- **B — Split `publish.yml` now into build, token exchange, upload**: no expiry window. Trade-off: about 3 points of work, and it rewrites the preflight (credentials are checked before any write) and the `crates_token_checks` ordering test.

**Recommendation**: A — the re-run finishes a partial release and the cost of B is a rewrite of the credential preflight.

#### U2: the PlatformIO existence check uses the token

**What is not decided**
To ask PlatformIO whether the version exists, the code must know the package owner. It reads it with `pio account show`, which sends the token to PlatformIO (the same lookup `pio pkg publish` makes). The AZ-2097 constraint says existence checks must not send tokens; only the Maven Central check is allowed to (Risk 1).

**Options**
- **A — Keep the token lookup**: no new secret to manage; the owner is whoever holds the token. Trade-off: it departs from the stated constraint for one optional registry.
- **B — A `PLATFORMIO_OWNER` setting**: the query is public and sends no token. Trade-off: one more configuration value to keep in step with the account.

**Recommendation**: A — the target is optional, the call goes to the same registry the upload talks to, and a value to keep in sync can drift.

#### U3: Central's `published` response was never called with a token

**What is not decided**
The Java existence check relies on Central's `publisher/published` endpoint returning `{"published": true|false}` (read from Central's own OpenAPI document; unauthenticated it answers 401). It also matches the text "already exists" in a FAILED deployment. Neither was run with a real token. An unexpected answer fails the run (fail-closed), which would block the first real tag until fixed.

**Options**
- **A — Accept and prove on the first real tag**: the run fails loudly if the shape is wrong, and the fix is small. Trade-off: the first tag may need one fix and one more tag number.
- **B — Probe before the tag**: you run one read-only call with your Central token and share the response shape. Trade-off: your time now, and the probe cannot show duplicate-rejection text.

**Recommendation**: A — fail-closed and cheap to fix; a probe cannot cover the duplicate text anyway.

### Gaps that are clear (gap-clear)

None.

### Not walked

- ESP-IDF archive holds the whole `cpp/` tree (not only the manifest's include list); same as the old upload (batch_03 discovery 1).
- `python/pyproject.toml` `project.license` as a table is deprecated (breaks after 2027-02-18) (batch_03 discovery 2).
- Unpinned pip installs of `build`, `twine`, `platformio`, `idf-component-manager` (batch_03 review finding 3).
- Built artifacts left world-writable by `chmod -R a+rwX` (batch_03 review finding 4).
- PyPI and npm OIDC upload branches moved, no test exercises them (batch_03 discovery 3).
- A re-run rebuilds every target before the existence checks (batch_04 report).

### Harness gaps

- None: every batch report of this loop has the `## Discovered during implementation` heading.
