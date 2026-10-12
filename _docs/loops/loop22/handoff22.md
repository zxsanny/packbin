# Loop 22 handoff — written 2026-10-12 while loop 21 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 21 = last closed once the close finishes). Read `_docs/loops/loop21/plan21.md`, `review21.md`, `assessment21.md`, `_docs/03_implementation/batch_01_loop21_report.md`, `reference_loop21_slots.md`, `test_run_loop21_report.md`, `_docs/05_security/security_report.md` (loop 21 addendum) and `_docs/06_metrics/retro_2026-10-12_loop21.md` first.

## Owner working preferences (unchanged, 2026-10-06 to 2026-10-12)

- Workers run only their own package suite; no review and no Docker run per batch; one total review and one total test run per loop. Do not chain feature-assess rounds while `todo/` grows: record open angles in the handoff.
- Worker prompts end with the shell-hygiene paragraph and forbid every index write (`git add`, `git rm`, `git mv`, `git restore`), `git stash`, `checkout`, `reset`, `clean` and "formatter or linter on files you do not own" (loop 21: no slip). The parent checks `git diff --cached` and the diff scope after each stage. C# test runs are `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`. A C++ worker also runs `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` (and `make -C cpp clean` between host and container builds), and for `cpp/src/core` or `cpp/include` the arm embedded stage. Python workers need a per-worker venv with Python 3.10+.
- The ring and the publish gate on this Mac need `python3` 3.10+ first on `PATH` and `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"` (recipe in `AGENT_GOTCHAS.md`). The step 11 script of loop 21 (stage by stage, a per-stage log, a 30 s heartbeat with `stat -L`) ran in 1 297 s; rebuild it from `test_run_loop21_report.md`.
- Decision batches: one question with every recommendation written out and "accept all recommended" first. A cross-package rule is implemented by one package first, which writes a hex-pinned reference table (worked a third time: `reference_loop21_slots.md`); a decision names the constructs it covers (`repeat`, `times`, split bit, combined `flags`) and both the with-value and no-value rows.
- Library smoke gate: the agent runs the smoke script at the commit before the close commit and passes the gate when all steps pass (`_docs/04_deploy/deployment_procedures.md` § Loop smoke gate).
- A tag (`v0.2.3` or `v0.3.0`) needs the owner's explicit go with the exact commit.

## Where things stand when loop 21 closes

- `todo/` holds 1 spec (AZ-2068 C++ AVR optional stretch); `done/` holds AZ-2373 and AZ-2381 to AZ-2394 (15 specs, 42 points) after the close.
- Done in loop 21: one slot-width rule for a round in six packages and Python unpack charging it (the surcharge is gone); a short optional list under `flags` refused in a `repeat`; the split-bit `times` absent body packs a clear bit; a count above 0 that no field wrote refused for a split-bit or combined-`flags` `times`; C++ and Rust pack a late `when`/`times` in a bit body when another member sets the bit; C# exact integer types, whole floats refused for integer fields, typed rounds bound to a collection of rows, a dict member that cannot hold rounds refused at build, `WithLimits(int, long)` overload; an empty `times`/`repeat` body refused at construction in six (F33); TypeScript round scope views (F34); 15 new hostile cases (55 in all) with rule tables in the Python, Java, Rust, C++ loaders.
- Cortex-M4F: flash 8152 of 8192 B (**40 B margin**), stack 456 of 512 B (**56 B margin**): any edit to `cpp/src/core` or `cpp/include` needs a flash saving first, and `unpack.cpp`/`pack.cpp` edits run the arm stage.
- Tests: see `test_run_loop21_report.md` (PARTIAL: 0 failed, the Pico example and two vcpkg checks not run on this host). Review `review21.md`: PASS_WITH_WARNINGS. Assessment `assessment21.md`: CLARIFY, no re-entry round. Security (loop 21 addendum): PASS_WITH_WARNINGS, 0 Critical, 0 High, 2 Medium (F10, F12), 13 Low; F31, F33, F34 fixed.

## Owner decisions open (each with a recommendation; ask as one batch first)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| 1 | **U11** `bits`/`packed`/`sized` count in the row behind a clear `when` with NO value packs a clear bit (`010000`) in six, while the same shape with `times` is refused | A refuse in six (same rule as U6); B keep | A |
| 2 | **U12** a C# `List<double>` (or `float`, `decimal`) for an integer list builds and unpacks but pack refuses it | A refuse at construction (breaking, builds iff packs); B accept whole floats for list elements | A |
| 3 | **U13** Rust drops per-name `repeat` lists given without `__repeat__` groups silently (packs `01`) | A refuse; B exempt Rust in the AC (rounds are groups) | A |
| 4 | **U14** Python needs equal lengths for `repeat` lists (a lone value, a short required list, a `when` list outside `flags`); the other five pack them | A align Python to the five; B align the five to Python | A |
| 5 | **U15** `times` with a short list under `flags`: TypeScript, Python, Java, C# accept (README Times, AZ-2248), Rust refuses the list form | A refuse in all; B accept in all | B |
| 6 | **U16** Java counts a nested-row group as one slot, TypeScript counts its members | A align Java; B README exception, Go copies TypeScript | B |
| 7 | **U17** default `maxSlots` (4 194 304) lets a 4.3 MB packet cost 548 MB (Python) to 1 072 MB (TypeScript) of memory on unpack (F10, Medium) | A lower the default (for example 1 048 576, about a quarter of the ceiling), a spec before Go; B document the ceiling in the README, keep | A |

## Gaps that are clear (spec them; from `assessment21.md`, `review21.md`, the audit)

- **G1 (Low)**: the C++ empty-round check looks at direct children only: a `times`/`repeat` whose body is an empty `when` builds in C++, refused in the other five (D8 rule). Fix in `order.hpp` `check_shape` if the 40 B flash margin allows, else record the saving needed.
- C++ shared `Late` flag: when two late members sit in different bits, the refused id can name the first present one (about 54 B to keep the exact id: do not take it without a saving).
- `row4_packed_*` TypeScript hostile schemes pass `packed(2, ...)` where the fixture README says width 1: check the schemes against the README (assessment "Not walked").
- The C# ring has no row-round driver (AZ-2388 is checked inside C# only); `language-pair.sh` could gain one when the Go driver is added.
- AZ-2392 AC-2 (the wrong-rule negative check) was shown by temporary edits only; no standing test covers it.
- C10: on AVR (AZ-2068) each C++ table entry grows by 1 B; add an `offsetof(Field, eq)` assert when that task starts; Loop 11 to 18 specs without AC rows in the traceability matrix (97, 53 with a test that cites the id).
- Python `mypy --strict` reports one error at `_pack.py:410` (CI does not run mypy); the Rust crate is not rustfmt-clean at HEAD (11 files) and CI runs no clippy; slow tests (Rust AC-4 rows 20 s in a debug build, Python suite, hostile slots case 8 s, C# `Ac10TimingTests` 1076 ms once in loop 20) passed on the idle loop 21 run.
- Message and exception-class differences per package (Java `IllegalStateException`, Python `RuntimeError`, quoted C# members, unpack error `field` names) are accepted (U10 option B); the README lists them in the upgrade notes.

## The hopper for loop 22, as waves

`todo/` holds AZ-2068. Suggested: decide the table above (one batch, "accept all recommended" first); **wave 1** (parallel, one worker per directory) the accepted rows (U11 to U13 per package, U14 in `python/`, U17 default limit in the five growable packages with TypeScript as the reference, G1 in `cpp/`); **then** the one total review, the one total test run, docs, security, retrospective, close, push, CI watch. After that, or instead if the owner moves it: the Go package (AZ-2222, full parity; module path and `go/vX.Y.Z` tag layout are the open design decisions; copy the slot rule, the empty-body rule and the 55 hostile cases), then Swift (AZ-2223).

## Do not start before checking

1. `git status` and `git log origin/main..HEAD` (both empty after loop 21's push and fast-forward), and the CI state of `dev` and `main`: green at the close, including the `embedded` job (the Pico example runs on CI x86-64). If the m4f stack/flash check is red on CI, that comes before anything else.
2. The tree should be clean; `_docs/_process_leftovers/` is empty.
3. Ask the open decisions first (one batch with the recommendations).
