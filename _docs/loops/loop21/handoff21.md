# Loop 21 handoff — written 2026-10-12 while loop 20 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 20 = last closed once the close finishes). Read `_docs/loops/loop20/plan20.md`, `review20.md`, `assessment20.md`, `_docs/03_implementation/batch_01..04_loop20_report.md`, `reference_loop20_budget.md`, `test_run_loop20_report.md`, `_docs/05_security/security_report.md` (loop 20 addendum) and `_docs/06_metrics/retro_2026-10-12_loop20.md` first.

## Owner working preferences (unchanged, 2026-10-06 to 2026-10-12)

- Workers run only their own package suite; no review and no Docker run per batch; one total review and one total test run per loop. Do not chain feature-assess rounds while `todo/` grows: record open angles in the handoff.
- Worker prompts end with the shell-hygiene paragraph and forbid every index write (`git add`, `git rm`, `git mv`, `git restore --staged`), `git stash`, `checkout`, `reset` and `clean` (loop 20: one worker still ran `git checkout` on its own file and another ran `cargo fmt` on the whole crate: say "no formatter on files you do not own"). The parent checks `git diff --cached` and the diff scope after each stage. C# test runs are `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`. A C++ worker also runs `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test`, and for `cpp/src/core` or `cpp/include` the arm embedded stage. Python workers need a per-worker venv with Python 3.10+.
- The ring and the publish gate on this Mac need `python3` 3.10+ first on `PATH` and `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"` (recipe in `AGENT_GOTCHAS.md`).
- A step 11 script template for the one total run is in the loop 20 retrospective notes: `setsid` does not exist on macOS (launch the script as a harness background task), and a heartbeat must `stat -L` a subagent's output file (it is a symlink).
- Decision batches: one question with every recommendation written out and "accept all recommended" first. A cross-package rule is implemented by one package first, which writes a hex-pinned reference table (worked again in loop 20: `reference_loop20_budget.md`); check every AC against the reference rows before the specs go to the other packages.
- A tag (`v0.2.3` or `v0.3.0`) needs the owner's explicit go with the exact commit.

## Where things stand when loop 20 closes

- `todo/` holds 2 specs (AZ-2068 C++ AVR optional stretch, AZ-2373 C# exact integer types, 5 points); `done/` holds the loop 20 specs AZ-2354 to AZ-2367 (14 specs, 25 points) after the close.
- Done in loop 20: `pack` has one output budget `maxBytes` (16 MiB default, raisable: TypeScript `withLimits({ maxBytes })`, Python `with_limits(max_bytes=)`, C# optional `WithLimits` parameter, Rust `with_max_bytes`, Java `withMaxBytes`), `maxSlots` is charged per round on pack, a `repeat` above `maxRounds` is refused on pack; count 0 after the byte with a list is an error everywhere and a lone scalar is silent; the combined `flags` skipped count with values is loud in six; C++ refuses a `times`/`bits`/`packed`/`sized` count behind a clear `when` and every late decider of a bit (also nested); C# whole floats refused for `eq` and `u2`/`bits`/`packed` slots; Java `BigDecimal`/u64 count/`ByteSink` hardening; C# typed `Unpack` of a round returns an error result and the round collection check equals the binding predicate; the hostile file has 40 cases (7 new `pack` cases).
- Cortex-M4F: flash 8160 of 8192 B (**32 B margin**, exhausted: any edit to `cpp/src/core` or `cpp/include` needs a flash saving first), stack 448 of 512 B.
- Tests: see `test_run_loop20_report.md`. Review `review20.md`: PASS_WITH_WARNINGS after the fix pass. Assessment `assessment20.md`: CLARIFY, no re-entry round. Security `_docs/05_security/security_report.md` (loop 20 addendum): PASS_WITH_WARNINGS, 0 Critical, 0 High, 2 Medium (F10, F12), 16 Low; F28, F29, F30, F17, F27 fixed.

## Owner decisions open (each with a recommendation; ask as one batch first)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| 1 | **U1** Python unpack charges 8 more slots per name for the first round of each run (README line 1192): a packet pack writes at exactly `maxSlots` is refused by Python's own unpack | A align Python unpack; B document | A (with the Go package so the rule is one) |
| 2 | **U2** slot width of a round differs between packages (Rust counts group/`flags`/flag-byte names, Python never counts an empty group and counts duplicate leaves twice, TypeScript counts an empty group) | A align all six to the TypeScript rule | A |
| 3 | **U3** short list in an optional flags position: TypeScript packs `010101050200`, Python refuses | A refuse everywhere; B pack | A |
| 4 | **U4** Java refuses a split-bit `times` with count above 0 after the byte and the body absent or `[]` (pre-existing); TypeScript and Python pack a clear bit | A pack a clear bit everywhere; B refuse | A |
| 5 | **U5** C++ refuses a direct late `when` in a bit body even when another non-late child sets the bit; TypeScript packs it | A pack, if it costs no flash; B refuse | A |
| 6 | **U6** count 1 behind a clear `when`, no rounds: Python packs `0100025a00`, C++ refuses | A refuse everywhere; B pack | A |
| 7 | **U7** `bits`/`packed`/`sized` counts behind a clear `when`: C++ and TypeScript refuse; C#, Python, Java, Rust not probed | A probe the four and align to refuse | A |
| 8 | **U8** typed C# rounds bind only to object-typed or collection members (D5) | A bind typed rounds to a collection of rows (the Rust direction), a spec of its own before Go; B keep and document | A |
| 9 | **U9** a C# dict member in a round that cannot hold the rounds still builds (pack-only) | A refuse at construction; B keep | A |
| 10 | **U10** message and limit parity (Java/Rust `times` cap text, field-id names in older messages, no 2^53 bound in the Python/C# validators) | A unify; B accept | B |

## Gaps that are clear (spec them; from `assessment20.md`, `review20.md` and the audit)

- **F33 (Low, security)**: an empty `times` or `repeat` body charges 0 slots and writes 0 bytes, so the budget does not bound CPU: `list` of groups holding `times(65535) {}` with 65 535 items (about 1.1 MB of JSON) took 93 s in TypeScript (measured), extrapolated 41 s Java, 74 s C#, 3 min Rust release, 1.7 h Python; TypeScript's own unpack refuses that packet at once. Fix: refuse an empty round body at construction in the six packages, or charge at least 1 slot per round. **F34 (Low)**: TypeScript `sliceRound` copies the whole enclosing scope per round (`rounds.ts:195`): one `times(65535) { u8 }` costs 1.5 s with 100 top-level fields and 23 s with 1 000 (pre-existing). README should say `maxBytes` is also the memory bound (2 to 3 times).

- G2 Python, Java, Rust and C++ hostile loaders pin only that pack refused: add a message/rule table like TypeScript's `PACK_REFUSAL` and C#'s `NamedMember`; G3 the C++ AZ-2356 pin and `pack_split_count_zero_after_byte_list` pass through the late rule, not the count-0 rule; G4 C# count above `int.MaxValue` text and a lone `byte[]` in a `repeat` (A5, A6); A7 C# `WithLimits` binary break (upgrade note, optional overload).
- Slow tests (decide after the step 11 numbers): Rust AC-4 rows 20 s in a debug build, Python suite +20 s, hostile slots case 8 s (Rust debug), C# `Ac10TimingTests` flaked once at 1076 ms and small `times` packs are about 10% slower.
- F17/F27: typed C# round unpack now returns an error result and the checks run in rounds; binding typed rounds to rows is U8. AZ-2373: C# exact integer types (owner answer 2026-10-11, option A).
- C10: on AVR (AZ-2068) each C++ table entry grows by 1 B; add an `offsetof(Field, eq)` assert when that task starts; the `Field::bit`/`Field::late` comments in `cpp/include/packbin/table.hpp` still say "times" only.
- Loop 11 to 18 specs without AC rows in the traceability matrix (97, 53 with a test that cites the id); the loop 20 ACs are added at step 12.
- Python `mypy --strict` reports one error at `_pack.py:410` (CI does not run mypy); the Rust crate is not rustfmt-clean at HEAD (11 files) and CI runs no clippy.

## The hopper for loop 21, as waves

`todo/` holds AZ-2068 and AZ-2373. Suggested: decide the table above (one batch, "accept all recommended" first); **wave 1** (parallel, one worker per directory) U1/U2 slot rule with TypeScript as the reference, U3/U4/U6/U7 parity probes then fixes, G2/G3/G4 loader and message work, AZ-2373 in `csharp/`; **then** the one total review, the one total test run, docs, security, retrospective, close, push, CI watch. After that, or instead if the owner moves it: the Go package (AZ-2222, full parity; module path and `go/vX.Y.Z` tag layout are the open design decisions), then Swift (AZ-2223).

## Do not start before checking

1. `git status` and `git log origin/main..HEAD` (both empty after loop 20's push and fast-forward), and the CI state of `dev` and `main`: green at the close, including the `embedded` job (Pico). If the Pico example or the m4f stack/flash check is red on CI, that comes before anything else.
2. The tree should be clean; `_docs/_process_leftovers/` is empty.
3. Ask the open decisions first (one batch with the recommendations).
