# Loop 26 handoff — written 2026-10-14 while loop 25 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 25 = last closed once the close finishes). Read `_docs/loops/loop25/plan25.md`, `review25.md`, `assessment25.md`, `_docs/03_implementation/batch_01_loop25_report.md`, `batch_02_loop25_report.md`, `_docs/06_metrics/retro_2026-10-14_loop25.md` and `_docs/05_security/security_report.md` (loop 25 addendum) first.

## Owner working preferences (unchanged, 2026-10-06 to 2026-10-14)

- Workers run only their own suite; no review and no Docker run per batch; one total review and one total test run per loop. Do not chain feature-assess rounds: record open angles in the handoff. **Put the total review in the loop plan** (`plan25.md` left it out and it ran after step 13).
- Worker prompts end with the shell-hygiene paragraph and forbid every index write (`git add`, `git rm`, `git mv`, `git restore`), `git stash`, `checkout`, `reset`, `clean` and "formatter or linter on files you do not own". Also say it in the prompt **and enforce it**: every command ends with `< /dev/null` (a worker's `cat > /tmp/dummy` waited 70 minutes in loop 25); the parent checks `git diff --cached` after each join and `ps` for old shells.
- C# test runs are `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`. A C++ worker runs the host suite with `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"`, then `make -C cpp clean`, `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test`, `make -C cpp clean`, and for `cpp/src/core` or `cpp/include` the arm embedded stage (flash margin 40 B, stack 56 B). Python workers use the shared venv `python/.venv` (Python 3.14). Go runs only in `golang:1.27` (see `_docs/AGENT_GOTCHAS.md`); the opt-in memory test is `go test -tags packbin_memtest -v -run TestMem -count=1 ./...`.
- Decision batches: one question with every recommendation written out and "accept all recommended" first (taken again in loop 25).
- Probe-first worked again: five probe workers ran TypeScript for real (`node --experimental-strip-types` on `typescript/src/index.ts`) before they pinned anything; the first AZ-2472 tests still passed without the fix, so ask each refusal test for a mutation proof (revert the fix in a scratch copy; every case must go red).
- **A ticket key comes from the tracker.** Run New Task step 7 (create the Jira tickets) before any spec file, commit or plan names a key; loop 25 used AZ-2452 to AZ-2459 by counting and they belong to other work. The three early commits `3897c85`, `b5c804e` and `58d912c` keep the wrong keys (nothing was pushed before the close; the real keys are AZ-2472 to AZ-2479, see `batch_02_loop25_report.md` § Ticket keys).
- Library smoke gate: the agent runs the smoke script at the commit before the close commit and passes the gate when all steps pass. Commit the script (`smoke{NN}.md`) first: its step 1 needs a clean tree.
- A tag needs the owner's explicit go with the exact commit.
- Before a total run check `uptime`, `sysctl vm.swapusage` and active swapping (`vm_stat` Swapouts over 10 s). Loop 25: the step 11 run took 23 minutes at load 10 to 87 (the load came from vitest runs of another project, WindowServer and a browser) with no swapping and no timing failure. The ring now takes about 45 s (it took 239 s); the publish gate is the long stage (706 s).
- Watchers: a heartbeat keyed on log growth says STALLED for the ring and the publish gate, which print only at the end; look at the child processes before calling a stage hung.

## Where things stand when loop 25 closes

- `todo/` holds 1 spec (AZ-2068 C++ AVR stretch); `done/` gains AZ-2472 to AZ-2479 (8 specs, 14 points). Epic AZ-2222 (Go) is built; the epic closes when the first `go/vX.Y.Z` tag exists and the proxy answers.
- Done in loop 25: the C++ builder refuses ids outside 0 to 32,767 (U25 A, flash and stack unchanged), C# dictionary rows read and return a nested-row group through the nested dictionary on pack and unpack (U26 A), Python `ValueError` (Low-1 A), Go peak memory measured (F10 shape 625 MB, wide round 94 MB), `run-suite.sh` fails on a missing manifest (D6 A), the split flag bit inside a false `when` pinned in five packages (D7, all equal TypeScript), the empty anchored group probed in five packages (D1, differences documented), the README rows (U24 B and the decided open rows), the ring builds the C# and C++ drivers once a run (239 s to 43 s).
- Review PASS_WITH_WARNINGS (0 Critical, 0 High, 1 Medium fixed, 6 Low: 1 fixed, 1 no change, 4 skipped); assessment CLARIFY (G1 open, G2 done at step 13); security PASS_WITH_WARNINGS (Medium 2: F10, F12; Low 17; F46 found and fixed).
- Cortex-M4F: flash 8152 of 8192 B (**40 B margin**), stack 456 of 512 B (**56 B margin**): unchanged.

## Owner decisions open (each with a recommendation; ask as one batch first)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| G1 | The C++ range-check error names the id after the 16-bit wrap (`when(65537)` reports field 1), not the id written | A keep and document (README says so); B carry the 32-bit id in the error (a `cpp/include` change, arm stage, 40 B flash margin) | A |
| D1b | Differences found by the D1 probes: Rust gives an empty group an id slot (the `u8` after it is id 1) and builds a `when` on the mark; Java reads `Boolean.FALSE` for an empty-group mark as present (`01 01`, TypeScript `01 00`) and unpacks `{mark:{}}` | A keep (decision D1 A, documented); B align Java's `Boolean.FALSE` to clear the bit; C align Rust's numbering | A |
| P1 | Publish gate speed: its clean-room builds download packages in throwaway containers (`pip install build`, a NuGet restore for `dotnet pack`, `cargo package`; 706 s) | A leave as is; B named volumes for the NuGet, pip and cargo caches in `docker-compose.publish.yml` (a poisoned cache then persists between runs; measure cold and warm first) | A, unless the owner wants B |
| F44 | Tag protection: a ruleset on `go/v*` and `v*` (creation limited to the publish workflow and maintainers, update and deletion blocked) | the owner applies it in the repository settings; the agent cannot | do it before the first tag |

## Small items (spec them if the owner wants them)

- `go/mem_test.go` is never compiled in CI (tag `packbin_memtest`): add a `go vet -tags packbin_memtest` pass or a compile-only step to `run-suite.sh go` (review25 #3; it costs time on every run).
- The Rust (`cargo run`, 32 calls) and Go (`ring-go.sh`, 114 calls) ring launchers still pay a per-call cost (review25 #5, about 20 s of the 43 s ring).
- `fixtures/hostile/check-cases.sh` still starts one `grep` per case on the README (review25 #7).
- Carried: `mypy --strict` reports 16 errors in 4 files and CI runs no mypy; the Rust crate is not rustfmt-clean and CI runs no clippy; `ring-wiring.test.sh` is at the 500-line cap (the next edit splits it; the ring could be table-driven); review23 Low 5 (cosmetic Rust `lists_agree` copy).
- Python's `RuntimeError` for an unwritten count became `ValueError`; the README says so. A caller that catches only `RuntimeError` needs the change (an upgrade note for the next release notes).

## Do not start before checking

1. `git status` and `git log origin/main..HEAD`, and the CI state of `dev` and `main` (`test.yml`). Loop 25 changes the `ring` job (the C# and C++ drivers are built by `language-pair.sh`; the duplicate `dotnet build` step is gone) and `run-suite.sh`; the first Ubuntu run of both is CI's proof.
2. The tree is clean; `_docs/_process_leftovers/` is empty.
3. Ask the open decisions first (one batch with the recommendations).
4. The first `go/vX.Y.Z` tag: only with the owner's explicit go, the exact commit, CI green on `dev` and the F44 ruleset applied. The publish path (`go-tag`) and the live proxy check have run only in hermetic tests.
5. Swift (AZ-2223) is the next language epic if the owner wants one; its notes mirror the Go epic (tag layout: `Package.swift` at the repository root).
