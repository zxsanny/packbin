# Loop 20 handoff — written 2026-10-11 while loop 19 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 19 = last closed once the close finishes). Read `_docs/loops/loop19/plan19.md`, `assessment19.md`, `review19.md`, `_docs/03_implementation/batch_01_loop19_report.md` (probe tables), `test_run_loop19_report.md`, `_docs/05_security/security_report.md` (loop 19 addendum) and `_docs/06_metrics/retro_2026-10-11_loop19.md` first.

## Owner working preferences (unchanged, 2026-10-06 to 2026-10-11)

- Workers run only their own package suite; no review and no Docker run per batch; one total review and one total test run per loop. Do not chain feature-assess rounds while `todo/` grows: record open angles in the handoff.
- Worker prompts end with the shell-hygiene paragraph and forbid every index write (`git add`, `git rm`, `git mv`, `git restore --staged`), `git stash`, `checkout`, `reset` and `clean`; the parent checks `git diff --cached` and the diff scope after each stage. C# test runs are `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`. A C++ worker also runs `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test`, and for `cpp/src/core` or `cpp/include` the arm embedded stage (stack 448 of 512 B, flash 8064 of 8192 B: a 64 B and a 128 B margin). Python workers need a per-worker venv with Python 3.10+ (`/tmp/packbin-py-l19`, python3.12).
- The ring and the publish gate on this Mac need `python3` 3.10+ first on `PATH` and `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"` (recipe in `AGENT_GOTCHAS.md` and `smoke19.md`).
- Decision batches: one question with every recommendation written out and "accept all recommended" first. A cross-package rule is implemented by one package first, which writes a hex-pinned reference table; check every AC against the reference rows before the specs are written (retro lesson, loop 19).
- A tag (`v0.2.3` or `v0.3.0`) needs the owner's explicit go with the exact commit.

## Where things stand when loop 19 closes

- `todo/` holds 1 spec (AZ-2068, C++ AVR, optional stretch, claim cleared); `done/` holds 185 files (180 AZ specs). Loop 19 closed AZ-2329 to AZ-2342 (14 specs, 26 points). All six packages: refuse a `times` count above `maxRounds` on pack (C++ fixed arrays), refuse a lone byte buffer in a round, refuse `eq` values that can never match at construction (C++: out-of-range integers), refuse count 0 with a list of values, and apply the split-form rule (loud only when the body would be written but the byte left its bit clear). Python rounds use a fresh scope; Rust sibling `flags` members have their own scope; C++ takes an empty group as a `when` source; a C# group element uses its members only. The hostile file has 33 cases.
- Tests: C# 913 (both targets), TypeScript 728, Python 777, Rust 533, Java and C++ pass; the arm embedded stage 0 failed. Total run PARTIAL (Pico example, two vcpkg checks: host limits). Review `review19.md`: PASS_WITH_WARNINGS after the owner-approved fixes. Security: PASS_WITH_WARNINGS, 0 Critical, 0 High, 3 Medium (F10, F12, F28), 18 Low.
- Open before any release: a Unity IL2CPP test run before a release that advertises Unity; F28 (below).

## Owner decisions open (each with a recommendation)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| 1 | **F28 pack output budget**: the round cap bounds one count, not the output: a lone `utf8` of 65 535 bytes under one `times` writes 4.29 GB from a 64 KB request (Python 4.2 s and 7.3 GB, Rust 1.9 s and 7.5 GB, Java no result in 100 s); a list element holding a `times` repeats the cap per element; a `times` inside a `repeat` round the same | A one `maxBytes` budget per pack call (default 16 MiB, raisable with `withLimits`), enforced where bytes are written in the five packages, plus `maxSlots` charged per round as unpack does, plus hostile cases for a lone `utf8` under a `times` and for an element with a `times`; B document only | A, and do it before the Go package so Go implements it from the start |
| 2 | **U1 `repeat` above `maxRounds` on pack** (also F31, A5): a packet pack writes that its own unpack refuses | A covered by the F28 budget plus a round-count check on `repeat`; B leave | A |
| 3 | **U2 count 0 written after the byte with values**: C# (now a list only) and Rust error; other packages not probed | A error with a LIST everywhere, lone scalar silent (the C# rule); B silent | A |
| 4 | **U3 absent `when` source in a split bit**: Rust now silent (rule 3), same as C# | A keep; B error in all six | A |
| 5 | **U4 C++ count behind a clear `when`** lets rounds through (`010003055a00`); fix +56 B of the 128 B flash margin | A fix in a loop without other C++ flash cost; B document | A |
| 6 | **U5 whole-number floats** (`5.0`) for `eq` and slots: C# and TypeScript accept, Java, Python, Rust refuse | A refuse everywhere except where the language cannot tell (JavaScript); B accept everywhere | A |
| 7 | **U6 enums as slot values**: Python accepts an `IntEnum`; C# refuses | A integer-valued enum accepted where the language treats it as an int, C# unchanged, documented; B refuse everywhere | A |
| 8 | **U7 C++ `eq(u8, true)` / `eq(u8, 1.5)`** still build (typed constants convert) | A leave and document; B add `Eq` overloads | A |
| 9 | **B6 combined `flags` skipped count with values**: loud in Python and C++, silent in C#, TypeScript, Java, Rust | A loud everywhere (AZ-2331 AC-2 wording covers it); B silent everywhere | A |

## Gaps that are clear (spec them; from `assessment19.md`, `review19.md` and the audit)

- G1 Java `BigDecimal` fractions truncated in `u2`/`bits`/`packed` slots; F30 Java `packSized` and `packBits` cut a u64 count to an int (`VarFields.java:49,126`: use `borrowedCount(field, seen, Integer.MAX_VALUE)`); F29 Java `ByteSink.ensure` overflows at 2^30 bytes (`ByteSink.java:47-55`).
- G2 Python `repeat` with an empty list under a flags member raises a bare `IndexError`; G3 TypeScript does not detect a `times` inside a `when` inside a split bit whose count is never written; G4 C++ `Field::late` marks only the first late member of a bit (C2); G5 `csharp/tests/LayoutTests.cs` is 517 lines (and `rust/src/scheme/bound.rs` 514).
- F17 (typed `Unpack` of a set round throws `InvalidCastException`) and F27 (the C# collection check is skipped inside `repeat`/`times` bodies; enable it with the F17 fix) are still open.
- C10: on AVR (AZ-2068) each C++ table entry grows by 1 B; add an `offsetof(Field, eq)` assert when that task starts.
- The 97 specs of loops 11 to 18 without AC rows in the traceability matrix (listed in the matrix, "Loops 11 to 18: specs with no AC rows yet"; 53 have a test file that cites the id). The exact loop 18 T1 row of the review is not in the repo (the Python worker rebuilt an equivalent: `010201050700`).
- Stale docs listed by the docs agent in `ripple_log_loop19.md`: `architecture.md` lines 25 and 117, `_docs/01_solution/schema.md`, `_docs/00_problem/acceptance_criteria.md` (the two new interaction risks are not ACs yet).

## The hopper for loop 20, as waves

`todo/` is empty except AZ-2068. Suggested: decide the table above (one batch, "accept all recommended" first); **wave 1** (parallel, one worker per directory) F28 budget in the five packages with a Rust or TypeScript reference first (the cap value and the error wording), then G1 to G5 and F29/F30; **then** the one total review, the one total test run, docs, security, retrospective, close, push, CI watch. After that, or instead if the owner moves it: the Go package (AZ-2222, full parity; module path and `go/vX.Y.Z` tag layout are the open design decisions), then Swift (AZ-2223).

## Do not start before checking

1. `git status` and `git log origin/main..HEAD` (both empty after loop 19's push and fast-forward), and the CI state of `dev` and `main`: green at the close, including the `embedded` job (Pico). If the Pico example or the m4f stack/flash check is red on CI, that comes before anything else.
2. The tree should be clean; `_docs/_process_leftovers/` is empty.
3. Ask the open decisions first (one batch with the recommendations).
