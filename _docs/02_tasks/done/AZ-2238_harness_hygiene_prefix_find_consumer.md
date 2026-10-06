# Harness hygiene: npm install on the copy, `find | head` under pipefail, named ring consumer

**Task**: AZ-2238_harness_hygiene_prefix_find_consumer
**Name**: Three harness fixes: `publish-position.sh` installs with `cd` + `npm ci`, `examples.sh` captures `find` output before it picks the first line, `language-pair.sh` names a failing consumer
**Description**: The TypeScript position gate installs its dependencies on the mktemp copy with `(cd "$work/typescript" && npm ci)` so it works where the temp path goes through a symlink (macOS); the two `find ... | head -n 1` lines of `cpp/embedded/examples.sh` stop failing under `pipefail`; a ring consumer that cannot read the bytes makes `language-pair.sh` print which consumer, which ring and which producer, then fail.
**Complexity**: 2 points
**Dependencies**: AZ-2193_ci_cross_language_ring (the `handoff()` function and the `ring` job), AZ-2099_embedded_errexit (`cpp/embedded` harness and `lib.test.sh`), AZ-2215_build_containers_read_only (the copy-to-work path of `publish-position.sh`)
**Component**: shared harness (`.github/workflows/publish-position.sh`, `cpp/embedded/examples.sh`, `.github/workflows/language-pair.sh`)
**Tracker**: AZ-2238
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment, G2 and Q9 (owner option A for the `language-pair.sh` and `find | head` parts), answered by the owner on 2026-10-06 ("take all recommendations, implement everything now"). Every probe below ran against the committed HEAD 2eb9875 on a scratch copy (macOS arm64, Darwin 25.6, node 22.23.0, npm 11.17.0, bash 3.2.57).

**1. `publish-position.sh typescript` fails on macOS without `typescript/node_modules`.** The script (lines 39-48) copies `typescript/` and `position.ts` into `mktemp -d` and runs `npm ci --prefix "$work/typescript" >&2`. On macOS `mktemp -d` returns `/var/folders/...`, and `/var` is a symlink to `/private/var`.
- Probe: `bash .github/workflows/publish-position.sh typescript` on a HEAD copy with no `node_modules` exits 1 with `npm error code EUSAGE` and `npm error Missing: typescript@0.1.0 from lock file`.
- Cause (checked, not assumed): the same copy installs when npm gets the real path (`npm ci --prefix /private/var/folders/.../typescript`: `added 2 packages`), and `cd /var/folders/.../typescript && npm ci` installs too. An own symlink reproduces it anywhere: `ln -s real link; npm ci --prefix link/typescript` gives `EUSAGE`, `--prefix real/typescript` installs. It is not a TMPDIR effect: BSD `mktemp -d` ignores `$TMPDIR`.
- With `(cd "$work/typescript" && npm ci >&2)` on the same copy the script exits 0 and prints `4001000065cd1d00a3e1110100` (`fixtures/golden.hex`); with `--ignore-scripts` added (as `publish-inside.sh:66` has it) the output is the same. The repo checkout is not written.
- On the Linux container path (`publish-readonly.test.sh` AC-5, AZ-2215) the temp dir is not behind a symlink, so `--prefix` works there; nothing tests the macOS or symlink case.

**2. `find ... | head -n 1` under `pipefail` in `cpp/embedded/examples.sh`.** Lines 44 and 90 read `archive="$(find "$dir/pkg" -name '*.tar.gz' | head -n 1)"` and `archive="$(find "$dir/dist" -name '*.tgz' | head -n 1)"`; the file sets `set -euo pipefail` (line 5). `head` closes the pipe after the first line; `find` that still has output to write gets SIGPIPE and the pipeline status is 141, which `set -e` turns into an exit of the whole stage with no message.
- Probe (bash 3.2, the exact pipeline, standalone): one matching file gives status 0; 3000 matching files give status 141. The same lines with the output captured first (`found="$(find ...)"; archive="${found%%$'\n'*}"`) give status 0 for both. Today each directory holds one archive, so the line works; it fails when a second archive or a long listing appears (two matches is a race, many matches is deterministic).
- There are no other `find ... | head` lines in `cpp/embedded/*.sh` (grep).

**3. `language-pair.sh` `handoff()` names only producer mismatches.** `handoff()` (lines 72-84) prints `<producer> pack-<ring> mismatch` when the producer's bytes differ, then runs the consumer as the last command: `run_lang "$consumer" "unpack-$kind" "$packed"`. Under `set -e` a consumer that exits non-zero ends the script with that status and nothing is printed by the script.
- Probe, no toolchain needed: copy `language-pair.sh` into a temp tree and put PATH shims for `dotnet`, `node` and `python3` first (a shim prints `user_hex` for `pack-*` and exits with a chosen status for `unpack-*`). Case "node consumer fails": exit 1, output empty. Case "python consumer fails" (node ok): exit 1, output empty. Case "dotnet producer prints `00`": exit 1, output `csharp pack-user mismatch`. A producer that exits 1 while packing is silent too (exit 1, empty).
- Real drivers: with the Python driver's expected `username` changed to a wrong value, `typescript -> python user` exits 1 and prints nothing; the same for the C++ driver (`handoff.cpp:233`, wrong expected name) on `typescript -> cpp user`. `drivers/handoff.py` and `drivers/handoff.cpp` hold no stderr output at all (grep: 0 uses); `handoff.ts` prints only in its boolflag and round commands, its `unpack-user` branch (line 278-279) ends in a silent `process.exit(1)`.
- AZ-2193 AC-3 reads: "a consumer that cannot read the bytes also fails the job". The job fails; the log does not say which pair.

## Outcome

- `publish-position.sh typescript` installs on the copy with `cd` and prints the golden hex on macOS without `node_modules`; the repo is not written.
- The two `find` lines of `examples.sh` cannot fail on SIGPIPE.
- A failing ring consumer exits 1 and the log ends with one line that names the consumer, the ring and the producer; producer mismatch lines and the success line are unchanged.

## Scope

### Included
- `.github/workflows/publish-position.sh`: the `npm ci` line of the typescript branch.
- `cpp/embedded/examples.sh`: the two `archive=` lines (about 44 and 90).
- `.github/workflows/language-pair.sh`: `handoff()` only.
- Checks: `npm_position_check` in `.github/workflows/publish-npm.test.sh`; a static scan in `cpp/embedded/lib.test.sh`; `consumer_failure_checks` in `.github/workflows/ring-wiring.test.sh`.

### Excluded
- Hardening the `gcc:16` container wrapper (`ring-cxx.sh`: `--network none`, read-only mount, `--cap-drop ALL`): Q9 option A says it waits for the first green `ring` run on the Ubuntu runner.
- The drivers (`.github/workflows/drivers/**`): AZ-2193 keeps them unchanged; the Python and C++ drivers stay silent, the script names the pair.
- A producer that exits non-zero while packing (observed silent, see Flagged concerns): not decided by the ticket.
- Other `| head` pipelines of `.github/workflows/*.sh` (they read small outputs and are outside the ticket).

## Acceptance Criteria

**AC-1: The TypeScript position gate installs on a symlinked temp path**
Given a copy of the repository with no `typescript/node_modules`, and a temp directory reached through a symlink (macOS `/var/folders/...` always is; on Linux set `TMPDIR` to a symlink, which GNU `mktemp -d` honours)
When `SRC_ROOT=<copy> bash .github/workflows/publish-position.sh typescript` runs
Then it exits 0 and stdout, whitespace trimmed, equals `fixtures/golden.hex` (`4001000065cd1d00a3e1110100`); the npm output goes to stderr. At HEAD it exits 1 with `npm error code EUSAGE` and `Missing: typescript@0.1.0 from lock file` (observed). The check is a new function `npm_position_check` in `publish-npm.test.sh`, called from `npm_dist_checks`; it copies the tree with `copy_tree`, removes `typescript/node_modules` from the copy, and runs the script as above (prototype run: red at HEAD, green with `(cd "$work/typescript" && npm ci >&2)`, observed on this Mac). The Linux symlinked-`TMPDIR` run is not verified here.

**AC-2: The checkout is not written**
Given the AC-1 run
When it ends
Then `typescript/node_modules` is still absent from the copy (the install ran on the work copy, as the script comment says) and the script's temp directory is removed (the existing `trap`). The check is the second assertion of `npm_position_check` (observed green on the fixed script).

**AC-3: `find | head` cannot fail the examples stage**
Given `cpp/embedded/examples.sh`
When a scan looks for a `find` command piped to `head` in `cpp/embedded/*.sh` (excluding `*.test.sh`)
Then it finds none; the two lines pick the first match from captured output (`found="$(find ...)"` then `archive="${found%%$'\n'*}"`), and the `[ -z "$archive" ]` branches that call `fail "... wrote no archive"` stay. At HEAD the scan reports `examples.sh:44` and `examples.sh:90`. The check is a static scan function in `cpp/embedded/lib.test.sh` placed before the GNU `date` guard so it also runs on macOS (the guard exits 2 on Darwin today); the reason it is static: the two functions need `pio`, `compote` and `idf.py`, which only the `espressif/idf` image has. The SIGPIPE behaviour itself is the probe above (status 141 with 3000 matches, 0 with the capture), recorded in the spec and not re-run by the test.

**AC-4: A failing consumer is named**
Given `language-pair.sh` in a temp tree with PATH shims, where the first handoff `csharp -> typescript user` has a producer that packs `user_hex` and a `node` consumer that exits 1
When the script runs
Then it exits 1 and its output is exactly `typescript unpack-user failed on the bytes packed by csharp` (consumer, ring as `unpack-<ring>`, producer). With the `node` shim passing and the `python3` consumer of `typescript -> python user` failing, the output is `python unpack-user failed on the bytes packed by typescript`. At HEAD both cases print nothing (observed). The check is `consumer_failure_checks` in `ring-wiring.test.sh` (the scaffold job already runs that file); it needs no toolchain, only bash. The wording after the consumer name is the implementer's to adjust as long as consumer, ring and producer appear in one line on stderr.

**AC-5: Producer mismatch and the success line are unchanged**
Given the shim case where the `dotnet` producer prints `00`
When the script runs
Then it exits 1 with exactly `csharp pack-user mismatch` and the consumer shim is never called (observed at HEAD and with the change). The full-ring success line `language pairs passed` and every pair order are untouched; the real ring on the CI runner (AZ-2193 AC-2) is the check for the unchanged success path.

## Non-Functional Requirements

**Compatibility**
- Wire bytes, driver commands and the ring order do not change; the fix to `handoff()` adds one `if`, no new variable outside the function.

**Reliability**
- A consumer failure keeps its non-zero status (1) and still stops the script at the first failing pair (`set -e` semantics kept).
- `publish-position.sh` still prints only the hex on stdout (npm output on stderr), because `publish-gate.sh` reads the last stdout line.

**Performance**
- `npm_position_check` adds one `npm ci` of two locked packages from the registry (about 5 s here); `npm_dist_checks` already does two. The shim checks run in well under a second.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | scan of `cpp/embedded/*.sh` for `find ... \| head` | none found; two hits at HEAD |
| AC-4 | shim run, `node` consumer fails | exit 1, one line naming typescript, `unpack-user`, csharp |
| AC-4 | shim run, `python3` consumer fails after a passing `node` | exit 1, line names python, `unpack-user`, typescript |
| AC-5 | shim run, `dotnet` prints `00` | exit 1, `csharp pack-user mismatch` only |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | copy of the tree without `typescript/node_modules`, symlinked temp dir | `publish-position.sh typescript` | golden hex on stdout, exit 0, checkout unchanged | Reliability |
| AC-4 | real drivers, one consumer's expected value changed on a scratch copy (a manual run, never in the repo) | one `handoff` of the ring | the named line appears and the exit is 1 | Reliability |

## Constraints

- ADR-001: no shared code between packages; this is harness shell only.
- Files at or under 500 lines: `publish-npm.test.sh` is 149, `ring-wiring.test.sh` 247, `lib.test.sh` 206, `language-pair.sh` 156; the additions stay under about 60 lines per file.
- Error kind and label of existing errors unchanged (decision C15): the producer line `<language> pack-<ring> mismatch` keeps its text.
- `bash.md` rules: `set -euo pipefail`, quote everything, temp dirs through `mktemp` and `trap`, no `2>/dev/null`.
- The check for AC-1 needs the npm registry for the two locked packages, as `npm_dist_checks` already does (CI scaffold job has it).
- The drivers are not edited to produce a message; the wording lives in `language-pair.sh`.

## Risks & Mitigation

**Risk 1: The Linux run of AC-1 does not reproduce the macOS failure**
- *Risk*: the test sets `TMPDIR` to a symlink so that GNU `mktemp -d` lands behind it; on Linux that was not run here, so the check could pass with the old line there.
- *Mitigation*: the macOS run is red at HEAD (observed); on Linux the check is a regression guard that is at worst weaker; the implementer confirms on the Linux runner that it fails with `--prefix` restored.

**Risk 2: A consumer line hides the driver's own message**
- *Risk*: the new line comes after the driver's stderr, so a driver that does print (TypeScript boolflag, Rust, Java, C#) keeps its text above it.
- *Mitigation*: stderr order is kept; the new line is last, so a reader of the job log sees the reason, then the pair.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A producer that exits non-zero while packing is also silent at HEAD (shim `dotnet` exit 1: exit 1, empty output). The ticket names the consumer only; the fix is the same `if !` around the producer's `run_lang`. Recommendation: include it (one more `if !`, same message shape). | owner | open | Low |
| AC-3's check is a static scan, not a run of the two functions (they need `pio`, `compote`, `idf.py`). The SIGPIPE status 141 is reproduced standalone with 3000 matches | implementer | accepted-risk | Low |
| The ticket says "`npm ci --prefix` on a mktemp dir ... `/var` is a symlink". Checked: the cause is any symlink in the `--prefix` path, not macOS as such | implementer | resolved | Low |

## Owner decision (2026-10-06)

DECIDED, take all recommendations (feature assessment of loop 16, "implement everything now"): G2 as a harness task: install on the copy with `cd` and `npm ci`; Q9 option A for the `find | head` and the unnamed consumer, done now; hardening the `gcc:16` container wrapper stays after the first green `ring` run on the Ubuntu runner. The open concerns above are resolved by this section except the producer row, which the owner may answer "take the recommendation" (include it).

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2), with AZ-2239 in one harness worker. Deviations from the spec text: the AC-1 and AC-2 check is `npm_position_check` in the new `.github/workflows/publish-position.test.sh`, not in `publish-npm.test.sh`; the temp directory is made a symlink by a `mktemp` shim on `PATH` (BSD `mktemp -d` ignores `TMPDIR`), the same shape on macOS and Linux.

What shipped:
- AC-1, AC-2: `publish-position.sh` runs `(cd "$work/typescript" && npm ci >&2)` (+4/-2); `publish-position.test.sh` (new, 56 lines) checks the golden hex of a tree without `typescript/node_modules`, that the install ran on the work copy, and that the work dir is gone. `publish-gate.test.sh` runs it as a child process (in the full run and in `--npm`).
- AC-3: `find_head_hits` in `cpp/embedded/lib.test.sh` (before the GNU `date` guard) prints `PASS no find | head in the embedded harness scripts`; `cpp/embedded/examples.sh` takes the first match from captured output in its two `archive=` lines (+7/-4). `lib.test.sh` has 31 PASS lines (30 before); re-run for this note: 31, exit 0.
- AC-4, AC-5: `consumer_failure_checks` in `ring-wiring.test.sh` (+70/-3; four "names the pair" checks): "the node consumer fails", "the python consumer fails after a passing node", "the csharp producer prints other bytes" (`csharp pack-user mismatch`, no `unpack` call logged), and the flagged row "the csharp producer exits 1 while packing" (`csharp pack-user failed`; included, because the open producer row was read as covered by "take all recommendations"; to drop it remove the `if !` around the producer in `handoff()` and its shim case). `language-pair.sh` `handoff()` prints `<producer> pack-<kind> failed` or `<consumer> unpack-<kind> failed on the bytes packed by <producer>` and exits 1.

Evidence: with the HEAD `--prefix` line the position check is red (`npm error code EUSAGE`, `Missing: typescript@0.1.0 from lock file`); with HEAD `examples.sh` the scan prints `examples.sh:44 examples.sh:90`; SIGPIPE probe in bash 3.2 with 3,000 matching files: the old pipeline exits 141, the captured form 0, and an empty directory still takes the `[ -z "$archive" ]` branches; against HEAD's `language-pair.sh` the consumer checks are red (exit 1, empty output). Reviewer: `bash -n` clean under bash 3.2.57 and 5.2.37, shellcheck 0.11 clean on the changed lines, `ring-wiring.test.sh` passes on macOS and its consumer checks pass under dash and bash 5.2 in ubuntu:24.04, the full ring prints `language pairs passed` (84 s cold, 92 s warm).

Discovery (fixed): `if ! run_lang ...` turns `set -e` off inside `run_lang`, so a failed C++ compile ran a stale binary and the pair passed (reproduced; the same masking existed at HEAD for a producer). Added `|| return` after the C++ compile and after `javac`, so it now fails with `cpp pack-user failed` or `cpp unpack-user failed on the bytes packed by java`.

Review findings fixed in the H2 fix pass (all Low): F1, the `publish-position.test.sh` header said "sourced" while the gate runs it as a child: the file is now a plain script run as a child, the sourced mode and the duplicated `fail` and `assert_eq` helpers are gone (56 lines); F3, the `lib.test.sh` awk regex `head([^a-zA-Z0-9_-]|$)` also flags `find | head` with no argument and `head;` (14 synthetic cases correct on macOS awk and mawk 1.3.4); F5 is recorded under AZ-2239. After the pass the ring passes on the repo; `ring-wiring`, `publish-position` and `lib.test.sh` pass on the host; `lib.test.sh` was not run in the gcc:16 container after the fix (the reviewer ran the earlier version there: pass).

Open: only the Ubuntu runner proves that the old `--prefix` line also fails with npm 10 or 11 there (Risk 1: restore it once and see), the awk scan under the runner's `mawk` (checked with mawk 1.3.4 in two images), `lib.test.sh` with its real GNU `date`, and the `ring-wiring` shims under dash.
