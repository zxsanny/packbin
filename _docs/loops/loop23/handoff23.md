# Loop 23 handoff — written 2026-10-13 while loop 22 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 22 = last closed once the close finishes). Read `_docs/loops/loop22/plan22.md`, `review22.md`, `assessment22.md`, `_docs/03_implementation/batch_01_loop22_report.md`, `reference_loop22.md`, `test_run_loop22_report.md`, `_docs/05_security/security_report.md` (loop 22 addendum) and `_docs/06_metrics/retro_2026-10-12_loop22.md` first. Running notes of the loop: `_docs/loops/loop22/notes22.md`.

## Owner working preferences (unchanged, 2026-10-06 to 2026-10-12)

- Workers run only their own package suite; no review and no Docker run per batch; one total review and one total test run per loop. Do not chain feature-assess rounds while `todo/` grows: record open angles in the handoff.
- Worker prompts end with the shell-hygiene paragraph and forbid every index write (`git add`, `git rm`, `git mv`, `git restore`), `git stash`, `checkout`, `reset`, `clean` and "formatter or linter on files you do not own" (loop 22: no slip). The parent checks `git diff --cached` and the diff scope after each stage. C# test runs are `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`. A C++ worker also runs `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` (and `make -C cpp clean` between host and container builds), and for `cpp/src/core` or `cpp/include` the arm embedded stage. Python workers need a per-worker venv with Python 3.10+.
- Decision batches: one question with every recommendation written out and "accept all recommended" first. A cross-package rule is implemented by one package first, which writes a hex-pinned reference table (worked a fourth time: `reference_loop22.md`); a decision names the constructs it covers and both the with-value and no-value rows.
- Library smoke gate: the agent runs the smoke script at the commit before the close commit and passes the gate when all steps pass (`_docs/04_deploy/deployment_procedures.md` § Loop smoke gate).
- A tag (`v0.2.3` or `v0.3.0`) needs the owner's explicit go with the exact commit.
- Long runs on this Mac (new in loop 22, see the lessons): a `perl alarm` stage timeout counts wall time across laptop sleep and is not killed by `exec` into docker; check `uptime` and `sysctl vm.swapusage` before a step 11 run; the ring took 11 296 s at load 40 with 5.5 GB of swap where it takes about 107 s on an idle machine.

## Where things stand when loop 22 closes

- `todo/` holds 1 spec (AZ-2068 C++ AVR optional stretch); `done/` holds AZ-2410 to AZ-2418 (9 specs, 21 points) after the close.
- Done in loop 22: U11 a no-value count behind a clear `when` refused for `bits`/`packed`/`sized` in six; C# float/double/decimal collections refused for integer lists and dicts at build; Rust refuses per-name `repeat` lists given without `__repeat__` groups and accepts a short `times` list under `flags`; Python `repeat` lists need no equal length; default `maxSlots` 1 048 576 in five packages (F10: peak 1 070 -> 353 MB TypeScript, 960 -> 317 Java, 733 -> 235 C#, 550 -> 162 Python, 628 -> 120 Rust stand-in); C++ refuses a round body of only empty `when`s; 65 hostile cases; standing wrong-rule tests in all six loaders; Python shared-node `count_source` fix.
- Cortex-M4F: flash 8152 of 8192 B (**40 B margin**), stack 456 of 512 B (**56 B margin**): unchanged; any edit to `cpp/src/core` or `cpp/include` needs a flash saving first, and `unpack.cpp`/`pack.cpp` edits run the arm stage.
- Tests, review, assessment, security: see the reports named above (review PASS_WITH_WARNINGS, 0 Critical, 0 High; assessment CLARIFY, no re-entry round).
- Not run locally in loop 22: the ESP stage of `cpp-embedded-esp` (stopped at 928 of 980 steps of its first target because the host was swapping; the CI `embedded` job runs it on the push).

## Owner decisions open (each with a recommendation; ask as one batch first)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| 1 | **U18** Rust refuses a list for a member under a `when` inside a `times` (`'v' is under a flags or when`), where TypeScript, Python, Java and C# pack it (rows R3a to R3f through `times`); Rust unpack gives per-name lists with only the rounds that read the name, so repacking from them shifts values | A align Rust to the four (needs a rule for which entry belongs to which round when the `when` is clear); B README exception: Rust takes rounds as groups when a `when` sits inside a `times` (as it does for `repeat`, U13) | B |
| 2 | **U19** C++ builds `when(id, eq(-1, v), ...)` (negative source id) with no error: the `when` never holds, the member is dropped on pack and the same packet fails to unpack | A refuse at construction if the arm stage stays within 8 192 B, else record the saving; B document it as a C++ difference; C leave | A |
| 3 | **U20** C++ refuses `packed` with bias -1 in every cell of the U11 grid; cause not traced | A trace it, and if it is the typed row (member always present) write the C++ exception in the README; B align C++ (flash check) | A |
| 4 | **U21** the three `construct_empty_*when*` hostile cases are refused by the scope rule first in five packages; the empty-body rule is pinned only in package tests | A keep (outcome pinned, rule pinned per package); B drop the three cases; C find a spelling that reaches the empty-body rule in all six | A |
| 5 | **U22** (review finding 5) the Rust map form drops per-name lists given beside `__repeat__` groups and the names of a `times`/`repeat` nested in a `repeat` body, without a word | A refuse both (like `times` `check_lists`); B README note only | A |
| 6 | **U23** (review finding 8) TypeScript packs a clear bit for a bigint count above 2^53 in the U11 shape where Python, Rust, Java and C# refuse | A refuse in TypeScript; B README note (the same split exists for `times`, U6) | A |

## Gaps that are clear (spec them; from `assessment22.md`, `review22.md`)

- **G1 (Low)**: no raised-limit check (the old worst packet unpacks at 4 194 304 slots) in Python and Rust; TypeScript, Java, C# have one.
- **G2 (Low)**: C++ AZ-2416 tests pin three empty-`when` shapes; add an empty group body, a `repeat` with a nested empty `when` and the AC-2 member shapes through the loader; they reach the rule through `eq(-1, ...)`, which stays green if U19 closes that hole with the same error, so give one a source-less spelling that survives U19.
- **G3 (Low)**: the U11 no-value row is pinned only at the top level of a scheme; add the counted member inside a group, behind a nested holding `when`, and in a `times`/`repeat` round body (TypeScript and Python probes found the same refusal there; no standing test).
- Review finding 10 (Low): Rust `slice_times` allocates a `Vec` per round through `names_below`; hoist it if profiling shows it. Finding 11: rustfmt-only reflow of three Rust test files (noise only).
- The C# ring has no row-round driver; `language-pair.sh` could gain one when the Go driver is added. AZ-2392 AC-2 is now a standing test in all loaders (AZ-2418). C++ shared `Late` flag exact refused id needs about 54 B of flash saving (not taken). C10: on AVR (AZ-2068) each C++ table entry grows by 1 B; add an `offsetof(Field, eq)` assert when that task starts; loop 11 to 18 specs without AC rows in the traceability matrix.
- `List<decimal>` for an `f32`/`f64` C# field is refused at build while pack would convert it (existing behavior, unclear).
- Python `mypy --strict` reports one error at `_pack.py:410` (CI does not run mypy); the Rust crate is not rustfmt-clean at HEAD and CI runs no clippy; slow tests (Rust AC-4 rows, Python suite, hostile slots case, C# `Ac10TimingTests`, Python `test_nfr_round_trips`) failed only under host load in loop 22 and passed on the idle re-run.

## The hopper for loop 23, as waves

`todo/` holds AZ-2068. Suggested: decide the table above (one batch, "accept all recommended" first); **wave 1** the accepted rows (U19/U20 in `cpp/`, U22 in `rust/`, U23 in `typescript/`, G1 to G3 test work per directory), a short wave; **then** the one total review, the one total test run (check `uptime` and swap first), docs, security, retrospective, close, push, CI watch. After that, or instead if the owner moves it: the Go package (AZ-2222, full parity). Decisions Go copies are all settled: the slot rule (reference_loop21), the empty-body rule, the default `maxSlots` 1 048 576 and TypeScript's nested-row group count (U16), the 65 hostile cases; the module path and the `go/vX.Y.Z` tag layout are the open design decisions.

## Do not start before checking

1. `git status` and `git log origin/main..HEAD` (both empty after loop 22's push and fast-forward), and the CI state of `dev` and `main`: green at the close, including the `embedded` job (the ESP targets and the Pico example run on CI x86-64, which loop 22 did not run locally). If the m4f stack/flash check or the ESP stage is red on CI, that comes before anything else.
2. The tree should be clean; `_docs/_process_leftovers/` is empty.
3. Ask the open decisions first (one batch with the recommendations).
