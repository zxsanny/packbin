# Loop 25 handoff — written 2026-10-13 while loop 24 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 24 = last closed once the close finishes). Read `_docs/loops/loop24/plan24.md`, `review24.md`, `assessment24.md`, `_docs/03_implementation/batch_01_loop24_report.md`, `test_run_loop24.md` and `_docs/05_security/security_report.md` (loop 24 section) first.

## Owner working preferences (unchanged, 2026-10-06 to 2026-10-13)

- Workers run only their own suite; no review and no Docker run per batch; one total review and one total test run per loop. Do not chain feature-assess rounds: record open angles in the handoff.
- Worker prompts end with the shell-hygiene paragraph and forbid every index write (`git add`, `git rm`, `git mv`, `git restore`), `git stash`, `checkout`, `reset`, `clean` and "formatter or linter on files you do not own" (loop 24: no slip). The parent checks `git diff --cached` after each join. The scratchpad `worker-rules.md` of loop 24 is a good base (Go through Docker, ownership, report format).
- C# test runs are `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`. A C++ worker runs the host suite with `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"`, then `make -C cpp clean`, `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test`, `make -C cpp clean`, and for `cpp/src/core` or `cpp/include` the arm embedded stage (a cold image build now takes about 4 minutes). Python workers need a per-worker venv with Python 3.10+. Go runs only in `golang:1.27` (see `_docs/AGENT_GOTCHAS.md`).
- Decision batches: one question with every recommendation written out and "accept all recommended" first (taken again in loop 24, three times).
- Probe-first worked again: porters compared each TypeScript row with Go's outcome before writing the walker; differences were owner decisions (Go-1 to Go-4) or reported rows.
- A worker that develops files depending only on the committed public API can work in a `git archive` scratch copy beside another worker that changes the tree (the Go session did); the parent merges by copying its new files.
- Library smoke gate: the agent runs the smoke script at the commit before the close commit and passes the gate when all steps pass. Commit the script (`smoke{NN}.md`) first: its step 1 needs a clean tree.
- A tag needs the owner's explicit go with the exact commit.
- Before a total run check `uptime`, `sysctl vm.swapusage` and active swapping (`vm_stat` Swapouts over 10 s). Loop 24: the step 11 run took 25 minutes at load 6 to 89 (the load came from the Docker VM, Spotlight and other sessions) with no swapping and no timing failure.

## Where things stand when loop 24 closes

- `todo/` holds 1 spec (AZ-2068 C++ AVR stretch); `done/` gains AZ-2440 to AZ-2451 (12 specs, 45 points). Epic AZ-2222 (Go) is built; Jira children are In Testing; the epic closes when the first `go/vX.Y.Z` tag exists and the proxy answers.
- Done in loop 24: the Go package `go/` with full parity (all kinds, schemes, rounds, strings/lists/dicts, limits and a `FuzzUnpack` target, `PackSession`), hostile vectors (65 cases, seven loaders, the checker counts seven names), parity rows, the Go CI suite and compose service, the ring (114 Go handoff lines, `RING_GO`, SHA-pinned `setup-go`), the release path (`go-tag` target, ADR-004, `publish-go.sh`, version check, `go mod download -json` proxy check), README, 45 doc and security updates. Security F41 to F43 and F45 fixed in the loop.
- Cortex-M4F: flash 8152 of 8192 B (**40 B margin**), stack 456 of 512 B (**56 B margin**): unchanged (`cpp/` not touched).
- Review PASS_WITH_WARNINGS (0 Critical, 0 High, 1 Medium, 5 Low; 4 fixed); assessment CLARIFY (D1 to D7 open, D8 clear); security PASS_WITH_WARNINGS (Medium 2: F10, F12; Low 17).

## Owner decisions open (each with a recommendation; ask as one batch first)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| D1 | Empty anchored group: its anchor must be the next id but it takes none (`Flags(0, Group(0,"mark")), U8(0,"n")`), as TypeScript | A keep, probe the other four, document; B refuse in all seven | A |
| D2 | `u2` or a `Slot` as a list/dict element: TypeScript builds it, Go refuses | A keep Go's refusal and document; B allow a single-slot `u2` in Go; C refuse in TypeScript | A |
| D3 | Slot width of a `Nested` row in a round: Go charges its members, Java 1 | A keep; B charge 1 | A |
| D4 | Zero-width repeat round: TypeScript short-packet shape (needed 0), Go `TrailingBytes` | A leave (test the failure, not its kind); B align Go | A |
| D5 | `BadValue` from unpack in Go (today the interim short-packet shape with needed 0, as the six; decide C15 once for all seven) | A leave; B Go returns `BadValue` now | A |
| D6 | `run-suite.sh`: Go fails without its manifest, the six skip with a PASS row | A align the six to Go (read the publish gate first: AC-15); B leave and document | A |
| D7 | Split flag bit inside a false `when` with the member given: TypeScript packs the bit with no body (`01000306`, repacks `01000206`), Go copies it (Go-3) | A probe all six, fix the outliers; B leave | A |
| F44 | Tag protection: a ruleset on `go/v*` and `v*` (creation limited to the publish workflow and maintainers, update and deletion blocked) | the owner applies it in the repository settings; the agent cannot | do it before the first tag |

## Decided on 2026-10-13 and not started (the short wave; write the specs first)

- **U25 A** (`cpp/`): a builder range check on every id (count ids of `times`/`bits`/`packed`/`sized` above 32 767 wrap and bind another field; `bits(1, 65536)` binds field 0; a count id of -1 builds and then fails every pack and unpack with `BadValue`; a field's own id or a `when` anchor above 32 767 wraps), the U19 pattern, 0 B expected; arm stage required (margin 40 B).
- **U24 B** (README, no spec): C++ packs the clear bit for an unbound `bits`/`packed`/`sized` member (no member pointer) whose count sits behind a clear `when`; an unbound member is C++'s "not carried" spelling.
- **U26 A** (`csharp/`): dictionary rows read a nested-row group's names from the nested dictionary (today from the outer row; breaking for flat rows).
- **Low-1 A** (`python/`): `ValueError` with the TypeScript text for a value given to a member whose count no field wrote (today `RuntimeError` `count N is missing`).

## Gaps that are clear (spec them)

- D8 (assessment24): measure Go's peak memory for the F10 packet at `maxSlots` 4 194 304 and the wide-round packet at the defaults (F41's audit gave indicative figures: wide round 105 MB per 1 MiB, F10 shape 170 MB at the defaults and 624 MB raised; one run each, about 10 %), and put the figure into the loop 22 memory table and the README memory bullet. 1 point.
- Carried from loop 24 handoff: review23 Low 6 (slow marker for the AZ-2435 tests; Python took 54 s in the container, no flake), Low 5 (cosmetic Rust `lists_agree` copy), `mypy --strict` reports 16 errors in 4 files and CI runs no mypy, the Rust crate is not rustfmt-clean and CI runs no clippy.
- `ring-wiring.test.sh` is at the 500-line cap: the next edit splits it; the ring could be table-driven (review24 #6).

## Do not start before checking

1. `git status` and `git log origin/main..HEAD`, and the CI state of `dev` and `main` (test.yml). The first CI run of loop 24 (72a573f): `ring` (the Go ring on Ubuntu) and `embedded` passed; `scaffold` failed in the Go dependency check (`go list` stamping VCS info in the container: fixed with `-buildvcs=false`, see `notes24.md`); the publish gate step after it had never run on CI before the fix commit, so its first CI result is the next proof. The `dev` scaffold run of 72a573f was *cancelled* at 28 s for an unknown reason.
2. The tree is clean; `_docs/_process_leftovers/` is empty.
3. Ask the open decisions first (one batch with the recommendations).
4. The first `go/vX.Y.Z` tag: only with the owner's explicit go, the exact commit, CI green on `dev` and the F44 ruleset applied. The publish path (`go-tag`) and the live proxy check have run only in hermetic tests.
5. Swift (AZ-2223) is the next language epic if the owner wants one; its notes mirror the Go epic (tag layout: `Package.swift` at the repository root).
