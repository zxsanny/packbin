# Loop 24 handoff — written 2026-10-13 while loop 23 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 23 = last closed once the close finishes). Read `_docs/loops/loop23/plan23.md`, `review23.md`, `assessment23.md`, `_docs/03_implementation/batch_01_loop23_report.md`, `test_run_loop23_report.md` and `_docs/05_security/security_report.md` (loop 23 addendum) first.

## Owner working preferences (unchanged, 2026-10-06 to 2026-10-13)

- Workers run only their own package suite; no review and no Docker run per batch; one total review and one total test run per loop. Do not chain feature-assess rounds: record open angles in the handoff.
- Worker prompts end with the shell-hygiene paragraph and forbid every index write (`git add`, `git rm`, `git mv`, `git restore`), `git stash`, `checkout`, `reset`, `clean` and "formatter or linter on files you do not own" (loop 23: no slip). The parent checks `git diff --cached` after each join. C# test runs are `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`. A C++ worker runs the host suite with `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"`, then `make -C cpp clean`, `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test`, `make -C cpp clean`, and for `cpp/src/core` or `cpp/include` the arm embedded stage. Python workers need a per-worker venv with Python 3.10+.
- Decision batches: one question with every recommendation written out and "accept all recommended" first (taken again in loop 23).
- Probe-first worked again in loop 23: a worker that found a spec example contradicting the decided rule (AZ-2433 AC-1, AZ-2436 AC-2) followed the decision and the parent amended the spec; a worker that found a regression (AZ-2437) reported it and the parent opened a Bug and resumed the worker.
- Library smoke gate: the agent runs the smoke script at the commit before the close commit and passes the gate when all steps pass.
- A tag needs the owner's explicit go with the exact commit.
- Before a total run check `uptime`, `sysctl vm.swapusage` and active swapping (`vm_stat` Swapouts over 10 s). In loop 23 the step 11 run took about 8 minutes plus the publish gate at load 5 to 14 with no active swapping.

## Where things stand when loop 23 closes

- `todo/` holds 1 spec (AZ-2068 C++ AVR stretch); `done/` gains AZ-2431 to AZ-2437 (7 specs, 11 points).
- Done in loop 23: C++ `when` `eq` ids outside 0..32 767 refused at build (U19, 0 B); the C++ empty-body rule pinned by direct `has_member`/`check_shape` checks (G2); the C++ `packed` bias -1 refusal traced to the typed row and documented (U20); Rust `repeat` refuses values it dropped (lists beside `__repeat__` groups that disagree, nested `times` names, the nested `__times_N` key, a body `flags` name; U22, G5, G6); TypeScript refuses a bigint count above 2^53 in the U11 shape (U23); raised-limit unpack tests in Python and Rust (G1); U11 pinned in six nested positions in six packages (G3); Python short count list in a round packs again (AZ-2437, a loop 22 regression); U18 and U21 documented.
- Cortex-M4F: flash 8152 of 8192 B (**40 B margin**), stack 456 of 512 B (**56 B margin**): unchanged.
- Review PASS_WITH_WARNINGS (0 Critical, 0 High, 0 Medium, 6 Low); assessment CLARIFY (G4 to G6 done in the loop; U24 to U26 open); security PASS_WITH_WARNINGS (Medium 2: F10, F12; Low 16): F36 and F37 fixed (probes, a 270 000-row Rust fuzz with 0 drops), new Lows F39 (C++ count and own ids wrap, = U25) and F40 (C# nested-row group reads outer values, = U26).

## Owner decisions open (each with a recommendation; ask as one batch first)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| 1 | **U24** C++ packs the clear bit for an unbound `bits`/`packed`/`sized` member (no member pointer) whose count sits behind a clear `when`, count above 0 included, where the five refuse (U11); top level and all six nested positions | A refuse in `pack_flag_byte`/`pack_flags` (flash cost unmeasured, margin 40 B); B README exception (an unbound member is C++'s "not carried" spelling); C leave undocumented | B |
| 2 | **U25** C++ ids outside the int16 range: count ids of `times`/`bits`/`packed`/`sized` above 32 767 wrap and bind another field (`bits(1, 65536)` binds field 0), a count id of -1 builds and then fails every pack and unpack with `BadValue`, a field's own id or a `when` anchor above 32 767 wraps | A builder range check on every id (the U19 pattern, 0 B expected); B count ids only; C README note | A |
| 3 | **U26** C# dictionary rows read a nested-row group's names from the outer row (`{Mode: 1, X: 3}` packs `01010103`, the inner `Mode` takes the outer value; a nested dictionary under the group's name fails `'X' (field id 1) has no value`), where TypeScript and Java read the nested object | A read the nested dictionary (breaking for flat rows); B README line only; C refuse a name shared with the outer row | A |
| 4 | Review23 Low 1: Python raises `RuntimeError` (`count N is missing`) for a value given to a member whose count no field wrote, where TypeScript raises `RangeError` (`v: count c was not written`) | A `ValueError` with the TypeScript text; B leave (accepted differences, loop 21: test for the failure, not its kind) | A |

Go notes (assessment23): before AZ-2222, settle what "no value" is in a Go struct (recommended: a nil slice or nil pointer is no value, an empty slice is a value with zero items); Go's map form takes the nested map for a nested-row group (as TypeScript); Go uses `int` ids, so only negative ids need the U25 check if Go names sources by id.

## Gaps that are clear (spec them)

- Review23 Low 6: the AZ-2435 raised-limit tests (Python, Rust) take 4 to 6 s and several hundred MB in the default suites; add a slow marker if the step 11 timing ever flakes (`pyproject.toml` has no markers).
- Review23 Low 5 (cosmetic): Rust `lists_agree` copies round values through `round_lists` when a name is kept beside groups; review22 finding 10 (`names_below` per round) is the same kind.
- `mypy --strict` (PyPI today) reports 16 errors in 4 files, the same set at loop 22 and loop 23 HEAD; CI runs no mypy. The Rust crate is not rustfmt-clean at HEAD and CI runs no clippy.

## The hopper for loop 24, as waves

`todo/` holds AZ-2068. Suggested: decide the table above (one batch, "accept all recommended" first); a short wave for the accepted rows (U25 and U24 in `cpp/`, U26 in `csharp/`, Low 1 in `python/`); then the one total review and test run, close. **Then the Go package (AZ-2222, full parity)**: every rule Go copies is settled once rows 1 to 3 are decided; the module path and the `go/vX.Y.Z` tag layout are the open design decisions. The owner may move Go ahead of the short wave.

## Do not start before checking

1. `git status` and `git log origin/main..HEAD`, and the CI state of `dev` and `main` (test.yml, including the `embedded` job: the ESP targets and the Pico example run only on CI).
2. The tree is clean; `_docs/_process_leftovers/` is empty.
3. Ask the open decisions first (one batch with the recommendations).
