# Loop 19 total review

Date: 2026-10-11. Three read-only reviewers over `git diff e1a791e..HEAD` (A: csharp, rust; B: typescript, python, java; C: cpp, fixtures, harness). Reviewers did not run the C++ embedded stage. Findings are copied from the reviewer reports; the verdict and the fix list are filled after all three return.

## Reviewer B (typescript, python, java)

| id | sev | cat | file | summary | scenario | confidence |
|----|-----|-----|------|---------|----------|------------|
| B1 | Medium | Bug | `java/.../VarFields.java:170` (`borrowedCount`), `Rounds.java:52` | Java's `maxRounds` cap is bypassed: `intValue()` truncates a long count before the `count > maxRounds` check | `u64 n; times {u8 k}`, n=4294967299L, k=7 packs `010300000001000000070707` (count bytes say 2^32+3, three rounds written; unpack then refuses); n=2^32 packs zero rounds; TypeScript and Python refuse | confirmed |
| B2 | Medium | Parity (AZ-2331 AC-2) | `typescript/src/flag-bits.ts:107-117` (`countNeverWritten`) | no `when` case: a skipped count under a `when` inside a split bit is missed | `u8 mode; m; m.bit(u8 n); m.bit(when(eq(0,1), times(.., u8 pt)))`, {mode:1, pt:[5]} packs `010100` (pt dropped); Python and Java throw | confirmed |
| B3 | Medium | Parity | `java/.../SchemeOrder.java:~225` (`requireWhenSource`) | Java checks a `u2` slot `eq` against 0..255, not 0..3 | `eq(u2Slot, 7)` builds in Java; TypeScript and Python refuse | confirmed |
| B4 | Low-Med | Parity | `java/.../VarFields.java:328-337` (`timesOn`) | a lone `byte[]` / dict under a `times` flags member with count 0 is not refused | `u8 n; flags(times(bytes(2) d))`, n=0, d=byte[2] packs `010000`; outside flags it is refused | confirmed |
| B5 | Low | Bug | `python/.../_pack.py:94-125` | a split bit holding several `when`s checks only the first with an unwritten source | `b.bit(group(when(eq(a,1) x), when(eq(b,1) y)))`, {b:1, y:9}: `010001`, y dropped | confirmed |
| B6 | Low | Parity | `python/.../_pack.py:79-85` vs `typescript/src/flag-bits.ts:60-62` | combined `flags`, skipped count with values: loud in Python, silent in TypeScript and Java | `{pt:[5,6]}` with count skipped | read + run (Python) |
| B7 | Low | Parity | `typescript/src/flag-bits.ts:68-72` | empty body list with a skipped count: loud in TypeScript, silent in Python and Java (silent is right: nothing dropped) | `{mode:1, pt:[]}` | confirmed |
| B8 | Low | Bug | `typescript/src/ref-scope.ts:62-66` (`inRange`) | `Number(range.max)` rounds up for 64-bit ranges | `eq(0, 2**64)` on u64 and `eq(0, 2**63)` on i64 build | confirmed |
| B9 | Low | Parity | `java/.../Presence.java:valuesWithoutCount` | recurses only into GROUP and WHEN, not FLAGS / FLAG_BIT | split bit holding `flags(times(..))`, count skipped, values given | read-only |
| B10 | Low | Observation | `typescript/tests/reference-scope.test.ts`, `when-on-written-values.test.ts` | `eq(int, undefined/null)` now construction errors; bytes of previously accepted TypeScript schemes changed (`010007` → `0100`) | accepted by owner point 3 | read-only |
| B11 | Low | Parity | typescript vs python | `eq(u8, 5.0)` accepted vs refused | already U5 | n/a |

Sound (reviewer B): TypeScript `PackState`/`maxRounds` threading; Python cap, fresh round scope symmetric in pack and unpack, short-times error; lone bytes in TypeScript/Python; the Java Presence/Walker split moved code verbatim; `new ByteSink(` only in `BinaryPacker`; new tests registered and not weakened.

## Reviewer C (cpp, fixtures/hostile, run-suite*, test.yml)

| id | sev | cat | file | summary | scenario | confidence |
|----|-----|-----|------|---------|----------|------------|
| C1 | Medium | Bug | `cpp/include/packbin/order.hpp:182-194` (`mark_late`) | a source written INSIDE the flag bit's own body counts as "late" (test is `t[i].ref > t[bit].ref`, i.e. after the flag BYTE); it must also sit before the flag BIT entry | `flag_byte(0), flag_bit(0, group(1, u8 n, times(count n){pt}))`, n=2 with two rounds: packed and round-tripped before, now `BadValue` naming id 2; same for `group(u8 mode, when(eq(mode..)))` in a bit | read-only (traced; verify with a host test first) |
| C2 | Low | Parity | `order.hpp:182-194`, `pack.cpp:81` | `mark_late` stores only the first late `when`/`times` of a bit | `bit(group(when(eq(0,1) a), when(eq(0,2) b)))`, mode=2, b given: packs (not lossy), other packages refuse | read-only |
| C3 | Low | Test | `java/.../HostileVectorTest.java` (`pack_split_times_count_skipped`) | the Java loader puts the `when` BEFORE the flag byte; README and the other five put the flag byte first, so Java does not run the README shape | reorder to `u8 sel, fb, when(..), fb.bit(times(..))` | read-only |
| C4 | Low | Test | `.github/workflows/run-suite.test.sh:24-44` | the good-venv fake python is `exit 0`, so deleting the `-m pytest` line keeps it green; a failing fake pytest is not tested; the fake root lacks `report-row.sh` (message printed, exit stays 0) | scratch replica | confirmed |
| C5 | Low | Maint | `run-suite.sh:40,52-53` | `python -m venv --clear` empties any `PACKBIN_PYTEST_VENV` directory without `bin/pytest`; parallel jobs can clear each other; `rm -rf $venv` hint unquoted; rebuild path untested | `PACKBIN_PYTEST_VENV=$HOME/work` | read-only |
| C6 | Low | Spec-Gap | `fixtures/hostile/README.md` `eq_out_of_range` | says a non-integer or bool constant is refused; C++ builds `eq(0,1.5)` and `eq(0,true)` | owner point 4 already accepts it; README must say C++ is not covered | read-only |
| C7 | Low | Spec-Gap | `fixtures/hostile/README.md` `pack_times_count_over_limit` | "the row cannot be written" is not accurate for C++: `Array<Item,65535>` with n=65536 is writable and refused as a count mismatch, not as a cap | state the true reason | read-only |
| C8 | Low | Bug (edge) | `order.hpp:97-114` (`find_ref`) | empty-group fallback binds a `when` to a group when a same-id field is not a bound count source (was SchemeInvalid) | `flags(0, group(0)), u8(0) unbound, when(1, eq(0,1))` resolves to the group silently | read-only |
| C9 | Low | Test | `order.hpp:187` | the "distance over 255" branch of `mark_late` is untested | one run-time scheme test at 255 and 256 | read-only |
| C10 | Low | Maint | `table.hpp:138` | "sizeof(Field) unchanged" holds only where int64 alignment is at least 2; on AVR (AZ-2068) each entry grows by 1 B; no static_assert | note in AZ-2068 | read-only |

Sound (reviewer C): `pack_flag_byte` refuses before the byte is written, false condition silent; `Field::late` fits the padding on 32-bit ARM, x86-32, x64, AArch64; `eq_fits` boundaries for all widths; `times_present`; `read_int` for an empty group; README vs `cases.txt` vs loaders for all eight cases (except C3, C7); no file over 500 lines; `run-suite.sh` `set -u`-safe. Embedded claims (448/512 B stack, 8064/8192 B flash) are not verifiable by reading.

## Reviewer A (csharp, rust)

No Critical or High findings. Both full suites pass; probes ran on scratch copies.

| id | sev | cat | file | summary | scenario | confidence |
|----|-----|-----|------|---------|----------|------------|
| A1 | Medium | Bug, Parity | `csharp/Walker.Flags.cs:55` (`DroppedBody`, Times arm) | in the split form C# calls a lone value for a `times` whose count is 0 "dropped" although the count was written BEFORE the byte; rule 3 needs count > 0 or never written; the message is wrong too; a row that packed before is now refused | `u8 C; flagbyte m; bit m {times C {u8 Pt}}; bit m {u16 Heading}`, C=0, Pt=5 (lone scalar), Heading=90: expected `0100025a00` (Rust gives it), C# throws `'Pt' has a value, but its flag bit is clear` | confirmed |
| A2 | Medium | Parity, Spec-Gap | `rust/src/walk/flag_bits.rs:224-239` (`check_split_bit`, When arm) | when the `when` source was never written and is absent from the row (a plain optional field) and a body is given, Rust errors and C# is silent; a source never written cannot match, so rule 3 says silent | `flagbyte m; bit m {u8 mode}; bit m {when mode==1 {u8 speed}}; bit m {u16 heading}`, speed=7, heading=90, mode absent: C# `01045a00`, Rust `PackError::Type` | confirmed |
| A3 | Low | Parity | `csharp/Walker.Flags.cs:47-55` | `DroppedBody` has no `Flags` case: a combined `flags` inside a split bit drops the body silently in C#, Rust refuses | `flagbyte m; u8 Mode; bit m {flags {when Mode==1 {u8 Speed}}}; bit m {u16 Heading}`, Mode=1, Speed=7: C# `0102015a00` | confirmed |
| A4 | Low | Bug | `csharp/SchemeOrder.cs` (`TryWholeNumber`) | `(decimal)real` rounds to 15 digits, so a non-whole double near an integer passes | `Eq(0, 255.00000000000003)` on `u8` builds; the `when` never matches | confirmed |
| A5 | Low | Spec-Gap | `csharp/Walker.Rounds.cs:37`, `rust/src/walk/times.rs:65` | pack caps rounds only; unpack also refuses above `maxSlots` (4 194 304) | 65 names per round, count 65 535 packs but its own unpack refuses | read-only |
| A6 | Low | Test | `SplitFormDroppedBodyTests.cs`, `split_form_loud_tests.rs` | no test pins A1, A2, A3 | the three scenarios | read-only |

Sound (reviewer A): C# `RequireRoundsWithinLimit` (`count > limit`, runs before any write, nested and flags covered); Rust `check_round_cap` (65 536 and 4e9 in times, split bit, flags, group; 65 535 is the boundary); file splits are verbatim moves; C# group elements members-only with no bypass; lone byte buffer (C#, Rust); count 0 with a list; Rust eq ranges; sibling flags scope. Files over 500 lines: `csharp/tests/LayoutTests.cs` (517) and `rust/src/scheme/bound.rs` (514), both older than the loop.

## Verdict (parent, before owner decision)

Raw counts: 0 Critical, 0 High, 8 Medium (B1, B2, B3, A1, A2, C1 unverified; plus B4 Low-Medium), the rest Low. Under the auto-fix matrix (`implement/SKILL.md`: Medium Bug / Spec-Gap escalate) the Mediums need the owner. **FAIL until the owner decides; PASS_WITH_WARNINGS after the Medium fixes.**

Proposed fix list (owner decision pending):

| Package | Fix | Findings |
|---------|-----|----------|
| Java | do the count and cap arithmetic in long; `u2` slot limit 0..3 in `eq`; lone buffer/dict under a count-0 flags `times`; recurse into FLAGS/FLAG_BIT in `valuesWithoutCount`; loader reorder (`when` after the flag byte) | B1, B3, B4, B9, C3 |
| TypeScript | `when` case in `countNeverWritten`; empty body list with a skipped count is silent; 64-bit `eq` range via `BigInt` | B2, B7, B8 |
| Python | check every unwritten source of a split bit | B5 |
| C# | `DroppedBody`: count already written means no drop (+ message); `Flags` case; whole-number check on the double | A1, A3, A4, A6 |
| Rust | never-written source with a body is silent (rule 3); tests | A2, A6 |
| C++ | verify C1 with a host test first, then fix (`t[i].ref < bit`); `find_ref` same-id guard; distance test at 255/256 | C1, C8, C9 |
| Parent | README fixes (C6, C7), `run-suite.test.sh` hardening (C4, C5) | C4 to C7 |

Deferred to the loop 20 handoff: B6 (combined `flags` skipped count loud in Python only), B10/B11 (accepted, owner points 2 and 3), A5 (slots not capped on pack, upgrade note), C2 (C++ checks only the first late decider; not lossy), C10 (AVR table +1 B, note in AZ-2068).

## Fix pass (owner option A, 2026-10-11) and final verdict

| Finding | Package | Fix | Regression test fails before / passes after |
|---------|---------|-----|---------------------------------------------|
| B1 | Java | count and cap arithmetic in long (`VarFields.borrowedLong`, `Rounds.packTimes`); u64 4294967299 and 4294967296 refused, 4e9 gives the limit message | yes: 10 failures on pre-fix sources (B1 x4, B3 x2, B4 x2, B9 x2) |
| B3 | Java | `u2` slot limit 0..3 in `eq` (`eq(u2Slot, 7)` refused, 3 builds) | yes |
| B4 | Java | lone dict / buffer check (`Rounds.requireNoLone`) also for a count-0 flags `times` | yes |
| B9 | Java | `Presence.valuesWithoutCount` recurses into FLAGS and FLAG_BIT | yes |
| C3 | Java | loader puts the flag byte before the `when` (README shape) | refuses before and after |
| B2 | TypeScript | `countNeverWritten` has a `when` case | yes (724 pass / 4 fail on HEAD sources) |
| B7 | TypeScript | empty body list with a skipped count is silent | yes |
| B8 | TypeScript | 64-bit `eq` range through BigInt (`2**64`, `2**63` refused); `2**53` stays buildable (existing test) | yes |
| B5 | Python | every unwritten source of a split bit is recorded and re-evaluated | yes (HEAD copy packs `010001`, fixed raises) |
| A1 | C# | `times` in a split bit is a dropped body only for count > 0 after the byte, a skipped count, or (decision 7) a count of 0 with a LIST; a lone scalar with count 0 stays silent (`0100025a00`) | yes (7 failures on HEAD sources) |
| A3 | C# | `Flags` case in `DroppedBody` | yes |
| A4 | C# | whole-number check on the double before decimal conversion (`255.00000000000003` refused; `5.5m` now refused too) | yes |
| A2 | Rust | a never-written source absent from the row is silent (rule 3); matching source after the byte still errors | yes (by reading; the git ban rules out running the old code) |
| A6 | C#, Rust | tests for A1, A2, A3 | n/a |
| C1 | C++ | `mark_late` requires the source to sit before the flag bit entry (`t[i].ref < bit`); reproduced first with host tests | yes (reverting the one condition fails 4 asserts) |
| C8 | C++ | empty-group fallback in `find_ref` does not bind when another span-1 field has the same id | yes |
| C9 | C++ | run-time scheme test at distance 255 / 256 | n/a |
| C4, C5 | parent | `run-suite.test.sh` logs argv, covers a failing pytest, a non-venv directory, a missing venv built with the pinned pytest; `--clear` only for a missing, empty or venv directory; `%q` quoting | mutation check: removing the `-m pytest` line fails two checks |
| C6, C7 | parent | README `eq_out_of_range` and `pack_times_count_over_limit` say what C++ really does; C++ skip text aligned | n/a |

Suites after the fix pass: C# 913/913 (both targets), TypeScript 728, Python 777, Rust 533, Java exit 0, C++ gcc:16 and host green, arm embedded 448 B stack / 8064 B flash (unchanged).

Deferred to the loop 20 handoff: B6, B10/B11, A5, C2, C10 and the assessment gaps (`assessment19.md`).

**Verdict: PASS_WITH_WARNINGS** (0 Critical, 0 High; every Medium fixed; open: B6, A5, C2 Low and the assessment unclear rows).
