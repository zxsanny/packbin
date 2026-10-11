# Loop 19 handoff — written 2026-10-11 while loop 18 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 18 = last closed once the close finishes). Read `_docs/loops/loop18/plan18.md`, `assessment18.md`, `review18.md`, `_docs/03_implementation/batch_01_loop18_report.md`, `batch_02_loop18_report.md`, `batch_03_loop18_report.md` (the discovery tables), `test_run_loop18_report.md`, `_docs/05_security/security_report.md` (loop 18 addendum) and `_docs/06_metrics/retro_2026-10-11_loop18.md` first.

## Owner working preferences (unchanged, 2026-10-06 to 2026-10-11)

- Workers run only their own package suite; no review and no Docker run per batch; one total review and one total test run per loop. Do not chain feature-assess rounds while `todo/` grows: record open angles in the handoff.
- Worker prompts end with the shell-hygiene paragraph and forbid every index write (`git add`, `git rm`, `git mv`, `git restore --staged`), `git stash`, `checkout`, `reset` and `clean`; the parent checks `git diff --cached` and the diff scope after each stage. C# test runs are `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` (without it the suite hangs at 646 of 649). A C++ worker also runs `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` (CI is GCC 16 with `-Werror`; the Mac is clang), and for `cpp/src/core` the arm embedded stage (stack 456 of 512 B, 56 B margin). Python workers need a per-worker venv (`/tmp/packbin-pytest` is broken).
- Order: the hopper first, then the Go package (AZ-2222, full parity), then Swift (AZ-2223, no order set). A tag (`v0.2.3` or `v0.3.0`) needs the owner's explicit go with the exact commit.
- A cross-package rule is implemented by one package first, which writes a hex-pinned reference table; the other packages align in parallel (loop 18 wave 3: `_docs/03_implementation/flags_member_reference_cases_loop18.md`).

## Where things stand when loop 18 closes

- `todo/` holds 1 spec (AZ-2068, C++ AVR, optional stretch, stale loop 10 claim); `done/` holds 180 files. Loop 18 closed AZ-2120, 2126, 2128, 2135, 2194 and AZ-2304 to AZ-2311 (13 specs). All six packages now: refuse `eq(bool, v)` other than true, a `when` source that is not an integer or a bool, a count that is not an integer; write a `when`/`times`/`repeat` as a `flags` member (`01 01 03 07 5a00`); C#, TypeScript, Python, Java, Rust refuse a lone dictionary in a round. The hostile file has 25 cases with a `pack` stage; C# is in the `listgroup`, `dictgroup`, `listflags` rings.
- Tests: C# 844 (both targets), TypeScript 642, Python 692, Rust 479, Java and C++ pass. Review `review18.md`: PASS_WITH_WARNINGS after the owner-approved fixes. Security: PASS_WITH_WARNINGS, 0 Critical, 0 High, 3 Medium (F10, F12, F21), 14 Low; F25 and F26 closed.
- The first CI run of the loop is the push of the close commit; the `embedded` job runs the Pico example (not run locally: no arm64 toolchain). The loop-end merge follows `loop_end_merge: main` of `ci_cd_pipeline.md` (fast-forward `origin/main` only after a green `test.yml` on `dev`).
- Open before any release: a Unity IL2CPP test run before a release that advertises Unity (owner decision 4, option A later); C# README sentence already added.

## Owner decisions open (each with a recommendation)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| 1 | **Pack round cap (F21, review R1)**: `pack` of a `times` with a lone scalar or no value loops `n` rounds for any `n` in TypeScript, Python, Java, C# and Rust (4 GiB or 80 minutes at a 4-billion count); C++ is not affected | A cap the count at the round limit (65 535) in `pack` in all five and add the hostile `pack` case `pack_times_count_over_limit`; B accept the risk and document it | A |
| 2 | **Python round scope (review T1)**: `repeat`/`times` rounds reuse the outer `seen`, so a value a round skipped stays visible to a later `when`; TypeScript and C# use a fresh scope per round (the same row packs `01020105010002` in Python, `010201050100` in TypeScript) | A fresh scope per round in Python pack and unpack (changes Python bytes for that shape); B keep and document | A |
| 3 | **Split-form silent drop (review C3, assessment U7/U8)**: a split `flagByte` decides its `when`/`times` bit where the byte is read, so a body whose condition or count is written between the byte and the bit is dropped silently (pack cannot produce a packet its own unpack accepts); also a `times` whose count field was skipped and a false-condition `when` with a given body | A pack fails loudly naming the member in all six (cheap in C#: re-check in `PackFlagBit`); B keep (the reference tables put the source before the byte) | A |
| 4 | **Lone byte buffer in a round (U1)**: a single `byte[]` for a `Bytes`/`Sized` name is broadcast by TypeScript, Python, Java, Rust and refused by C# (AZ-2182) | A refuse everywhere; B broadcast everywhere | A |
| 5 | **Sibling `flags` members and flag-byte scope (U3)**: C++, TypeScript, Java give each member its own scope; Rust shares one | A change Rust; B change the three | A |
| 6 | **C++ empty group as a `when` source (U5)**: C++ refuses `eq(emptyGroup, true)`, Rust accepts | A accept in C++; B document the refusal | A |
| 7 | **`times` count 0 with values (U6)**: error in `flags` and, since this loop, in C++ outside `flags` too | A keep everywhere; B only inside `flags` | A |
| 8 | **Python short `times` list (U9)**: a bare `IndexError` outside `flags` (three tests pin it), a named error inside | A named error everywhere; B leave | A |
| 9 | **C# group element inherits outer values (U10)** | A members-only rule for group elements; B keep | A |
| 10 | **C# member-type set (U11, review C4)**: `ICollection<E>`, `IReadOnlyList<E>`, `Collection<E>`, element types `IConvertible`/`IComparable` worked before and are refused now; float/double/decimal members accepted for integer fields | A keep the refusal (owner principle: refusing can be relaxed later); B accept the broader set | A |
| 11 | **Eq value on an integer source (review C5, T8)**: `Eq(u8, 300)`, a string or NaN still builds in C#; Python `eq(intField, True)` matches 1 | A refuse a non-integer or out-of-range `eq` value at construction in all six; B leave | A |
| 12 | **Ring shape (review C10)**: C# is in the rings as a chain (typescript, python, java, csharp, typescript), not all pairs | A keep; B all pairs (18 more handoffs) | A |
| 13 | **Fractions in `u2`/`bits`/`packed` slots in the other five packages (U11)** | A probe and spec what differs | A |

## Gaps that are clear (spec them; from `assessment18.md` and the reviews)

- Pin the C++ `present()` result with a test: `flags(group(flag_byte(0), flag_bit(0,x)))` with only `x` packs `01 01 01 05` (assessment U4, closed by the AZ-2128 `present()` change but not pinned).
- Harness: `run-suite.sh python` checks only `bin/pytest`; rebuild the venv or fail with a clear message (G2); `cases.test.sh` and the ring checks are now strict (done); the test-spec files stop at loop 10 for loops 11 to 17 (catch-up of AZ-2088, AZ-2191, AZ-2216 to AZ-2220, ...); `blackbox-tests.md` is 1 990 lines (split by category).
- F27 (security, latent): the C# collection check is skipped inside `repeat`/`times` bodies; when F17 (typed `Unpack` of a set round throws `InvalidCastException`) is fixed, enable it there.
- Maintainability: Rust `walk/unpack.rs` (471) and `field/mod.rs` (479), Java `Walker.java` (464), C# `Packbin.cs` and `Walker.cs` (about 420) are close to the 500 cap; split before the next addition. C# nested-group dictionary elements in a typed `List<object?>` row throw `InvalidCastException` on repack (anchored groups `ArgumentException`): decide whether the ring driver needs them.
- Dependency table: AZ-2068's stale loop 10 claim (branch `loop/10-cpp-microcontroller`) should be cleared.

## The hopper for loop 19, as waves

`todo/` is empty except AZ-2068. Suggested: **wave 1** (parallel, one worker per directory) owner decisions 1 to 11 as specs, one per decision, each cross-package change with a reference table first (decision 1 first: a cap and a hostile `pack` case touch five packages; decision 3 reuses the wave 3 table); **then** the one total review, the one total test run, docs, security, retrospective, close, push, CI watch. After the hopper, or instead if the owner moves it: the Go package (AZ-2222) as its own product loop (module path and `go/vX.Y.Z` tag layout are the open design decisions), then Swift (AZ-2223).

## Do not start before checking

1. `git status` and `git log origin/main..HEAD` (both empty after loop 18's push and fast-forward), and the CI state of `dev` and `main`: green at the close, including the `embedded` job (Pico). If the Pico example or the m4f stack/flash check is red on CI, that comes before anything else.
2. The tree should be clean; `_docs/_process_leftovers/` is empty.
3. Ask the owner decisions 1 to 3 first (they change bytes or add a cap); decisions 4 to 13 can be asked as one batch with the recommendations.
