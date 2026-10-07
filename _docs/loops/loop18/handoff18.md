# Loop 18 handoff — written 2026-10-07 while loop 17 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 17 = last closed once the close finishes). Read `_docs/loops/loop17/plan17.md`, `assessment17.md`, `review17.md`, `_docs/03_implementation/batch_01_loop17_report.md`, `batch_02_loop17_report.md` (the discovery tables), `test_run_loop17_report.md`, `perf_run_loop17_report.md` and `_docs/loops/loop17/handoff17.md` (its "Open decisions and gaps from loop 16" list is still open and is not repeated here) first.

## Owner working preferences (unchanged, 2026-10-06 and 2026-10-07)

- Workers run only their own package suite; no review and no Docker run per batch or per change; one total review and one total test run per loop. Do not chain feature-assess rounds while `todo/` grows: record open angles in the handoff.
- Order: the hopper first, then the Go package (AZ-2222, full parity), then Swift (AZ-2223, no order set). A tag (`v0.2.3` or `v0.3.0`) needs the owner's explicit go with the exact commit.
- Worker prompts end with the shell-hygiene paragraph and forbid every index write (`git add`, `git rm`, `git mv`, `git restore --staged`), `git stash`, `checkout`, `reset` and `clean`; the parent checks `git diff --cached` and the diff scope after each stage. A worker may stall before its first edit: resume it with a smaller first step.

## Where things stand when loop 17 closes

- `todo/` holds 6 specs; `done/` holds 158 files. Loop 17 was the C# stream only: 10 specs closed (AZ-2092, 2093, 2114, 2115, 2119, 2121, 2180, 2181, 2182, 2191), the C# parts of AZ-2135 and AZ-2128 shipped, the owner's C# multi-target work was committed (`68ca4f8`). C# tests 424 to 649 on net10.0 and on the `netstandard2.0` build. Behavior changes are in the README upgrade notes (step 13).
- Pushed: `dev` at `87e554f` (the close commit). Its CI run 37588554503: `ring` and `embedded` passed, `scaffold` FAILED on the AC-10 timing test (1 618 ms on the runner, bound 1 000 ms), so the other five suites and the publish gate did not run on CI for that commit and `main` was not pushed (`origin/main` is `67cb09d`). Owner answer 2026-10-07: isolate the test; the fix commit after `87e554f` moves it to its own non-parallel xunit collection with one strict pass (`csharp/tests/Ac10TimingTests.cs`). Its CI run is the first thing to read in loop 18; the loop end channel is `main` (`ci_cd_pipeline.md`), polling is `enabled: yes`. Leftover: `_docs/_process_leftovers/2026-10-07_ci-fail-ac10-typed-path.md`.
- Review `review17.md`: PASS_WITH_WARNINGS, 2 Medium and 6 Low (R1 to R8; R7 and R8 fixed, R6 judged no change, R1 to R5 open). Security `security_report.md`: PASS_WITH_WARNINGS, Medium 3 (F10, F12, F25), Low 15. Feature assessment round 1: CLARIFY, no re-entry.

## Owner decisions open from loop 17 (each has a recommendation)

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| 1 | AZ-2092 AC-7: the typed round trip is 2.1x faster cold and 2.3x warm, not 3x (project AC-10 has margin; engine floor 130 ms cold) | A accept and amend AC-7; B spec a dictionary-free typed walker (5 points or more, a second walker) | A |
| 2 | F25 / R1: a collection member narrower than the element field (`List<int>` for `u32`) lets one hostile 7-byte packet throw `OverflowException` out of `Unpack`; also D4 / F26 / R4, custom collection types | A refuse the mismatch and unsupported collection members at scheme construction; B catch the conversion in `SchemeHandler.Dispatch` and return a bad-value error | A (closes both) |
| 3 | D2: a non-null typed nested row with all members null leaves a flags group's bit clear and the object disappears silently | A keep; B the object counts as present and pack fails naming the first missing member | B |
| 4 | D8: `Expression.Compile` per field under AOT or IL2CPP (Unity) | A one README sentence and a Unity IL2CPP test run before a release that advertises Unity; B the sentence only; C nothing | B now, A before a Unity release |
| 5 | E4: a `Flags` container as a direct list or dict element throws `KeyNotFoundException` in C# (accepted by TypeScript, Python, Java, ring `listflags`) | A support it and add C# to the ring; B refuse at construction; C leave | A |
| 6 | E5: a lone dictionary for a `Dict` name in a round is broadcast (it threw), a lone string for `Utf8` broadcasts | A refuse a lone dictionary like a lone collection (probe TypeScript, Python, Java first); B keep | A |
| 7 | E9: char, enum and `object` values for numeric fields are refused in C# dictionary rows | A keep; B accept an enum through its underlying integer | A |
| 8 | E11: `u2` slots, `bits` and `packed` items still round or coerce (`1.5` in a `u2` slot packs 2) | A follow-up spec (1 point), one strict rule for every numeric slot; B leave and document | A |
| 9 | R3 / perf: the AC-10 test took 340 to 390 ms alone and 790 ms to 1 s inside the suite on the Mac and 1 618 ms on the CI runner | **decided and done 2026-10-07 (owner)**: a collection with `DisableParallelization = true` and one strict pass; if the runner is still over 1 000 ms, decision 1 (typed walker) is the only honest fix | done |
| 10 | AZ-2120 (held by the owner 2026-10-07): `when`, `times`, `repeat` as a `flags` member or flag-bit field are dropped on pack in all six packages (`01 01 02 5a00`), C# unpack already reads `01 01 03 07 5a00` | A all six write them; B all six refuse at construction | decide together with the loop that touches all six |

## Gaps that are clear (spec them; from `assessment17.md`)

- E3: C# dictionary-mode `Pack` of the rows `Read` returns for list or dict group elements (`'A' has no value`), about 1 point.
- E6: Rust map `times` with a lone scalar gives round 0 only; owner option A of AZ-2182 says every round (no ticket yet), 1 to 2 points.
- E8: C# `Bytes`/`Sized` given an `int` fails with a raw `InvalidCastException`; make it `ArgumentException` naming the member, 1 point.
- The `when` half of the AZ-2181 decision (float, utf8, bytes refused; a bool only with `true`) belongs to AZ-2126 with its six packages and the `eq_bool_false` vector; reverse `FloatWhenTests` and `WrittenWhenKindsTests` there.
- C# joins the `listgroup` and `dictgroup` rings (a case in `.github/workflows/drivers/csharp/Handoff.cs` and the handoff lines in `language-pair.sh`, with `ring-wiring.test.sh`): AZ-2119 AC-1 says the unpacked shape matches the other packages and loop 17 checked that by reading the drivers, not by running them; `listflags` waits for decision 5. About 2 points.
- R2 (decimal range check on every packed integer) goes with decision 1.

## The hopper for loop 18, as waves (no two batches of one wave write the same path)

`todo/` after loop 17: AZ-2068 (C++ AVR build, optional), AZ-2120 (held), AZ-2126 (`eq` on a bool accepts only `true`, six packages), AZ-2128 (the held `when`/`times`/`repeat` angle only), AZ-2135 (Python numbering by scheme order, C++ flag byte inside a `flags` member or flag-bit child follow-up spec), AZ-2194 (hostile `pack` stage, six loaders, `check-cases.sh` and its self-test; its numbers are stale: 19 cases, stages `unpack`, `construct`, `limit`).

- **Wave 1, parallel, one worker per directory:** `typescript/`, `python/`, `rust/`, `java/`: AZ-2126 construction check without the vector (1 point each; Python also AZ-2135 numbering by scheme order), `cpp/` (the C++ flag-scope parity spec, written first, then its AZ-2126 part), `csharp/` (decisions 2 to 9 once answered, plus E3 and E8).
- **Wave 2 (after wave 1):** AZ-2126 `eq_bool_false` vector and README section in `fixtures/hostile/` (all six packages read `fixtures/hostile/cases.txt`, so it comes last and only when every package refuses it), then AZ-2194.
- **Wave 3:** AZ-2120 and the `when`/`times`/`repeat` decision in all six packages (decision 10).
- **Then:** one total review, one total test run (include the embedded stages: they run in the CI job and locally only when `cpp/` changes), docs, security, retrospective, close, push, CI watch. After the hopper: the Go package (AZ-2222) as its own product loop (module path and `go/vX.Y.Z` tag layout are the open design decisions), then Swift (AZ-2223).

## Do not start before checking

1. The CI run of the fix commit after `87e554f` (and, once green, the push of `main` that loop 17 owes): read it before planning. If it is red on the AC-10 test again, that is decision 1 and nothing else moves. The five package suites and the publish gate have not run on CI since `67cb09d`.
2. `git status`: the tree should be clean (the owner's C# work is committed); `AGENT_GOTCHAS.md` no longer carries the foreign-hunk rule.
3. Ask the owner the ten decisions above before wave 1 touches C#; waves for the other packages do not wait for them.
