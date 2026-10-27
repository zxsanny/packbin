# Feature assessment — loop 76

loop: 76
feature: hygiene-after-frame-ports
rounds: 2
verdict: COMPLETE
report_of_round: 2

Tasks: AZ-3329..AZ-3333 (batch 1, commit f102eba, base a50e750) and AZ-3334 (fix batch). Round 1 was done by an independent read-only agent from the specs, scenarios and the diff (it ran no build or suite); the parent owns the verdict.

## Round 1

**Date**: 2026-10-27
**Implement pass**: batch 1, `_docs/03_implementation/batch_01_loop76_report.md`
**Verdict**: CLARIFY — 11 covered / 1 out-of-scope / 0 gap-clear / 2 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | a selftest check does not match | covered | AZ-3330 AC-3; smoke 2 greps `captured output:` in the mutant's stderr; `publish-timing.selftest.sh` `bad_in` | intake |
| S2 | bash 3.2 and bash 5 | covered, limit | here-strings add the same trailing newline as `printf '%s\n'`; `bad_in` run under bash 3.2.57 incl. `set -u`; bash 5 only in CI after the push | intake |
| S3 | build the C# probe copy with `ns20/` | covered | AZ-3329 AC-1, AC-2; smoke 3; `PackbinProbe.csproj` line 28 | intake |
| S4 | build the ns20 probe on its own | covered | AZ-3329 AC-3; smoke 3 (that csproj includes only `Compat.cs` and its own `Program.cs`) | intake |
| S5 | `--features frame` tests compile and run | covered | AZ-3331 AC-1, AC-2; smoke 5; `lib.rs:13-14`, `sha256.rs`, `hkdf.rs` test modules | intake |
| S6 | other feature sets compile their tests | covered | AZ-3331 AC-1; smoke 5 loops the 7 non-default sets and the default | intake |
| S7 | embedded Rust stage compiles `session_core` | covered by reading; run evidence at step 11 | the `rust/src` diff is 3 files, 6 lines, all `cfg(test)` or `cfg(all(test, not(std)))`; pins checked by the `rust-embedded` and `cpp-embedded-arm` stages of the total run | intake |
| S8 | Swift reader opens "Public names" | covered | AZ-3332 AC-1; smoke 6; the reviewer checked every member against `FrameSession.swift`, `FrameTypes.swift`, `MacKey.swift`, `PackbinError.swift` | intake |
| S9 | reader of ADR-003 asks why Linux and macOS only | covered | AZ-3332 AC-3; smoke 6; ADR line 48, description line 136 | intake |
| S10 | descending-order probe | out-of-scope | `DictKeyOrderTests.cs` and `DictKeyOrderTest.java` pin the refusal | intake |
| S11 | a file names a renamed file | covered | AZ-3333 AC-1; smoke 7 (exactly the `tests-by-loop.md` history line); no `.github` `paths:` filter or script names a renamed file | intake |
| S12 | renamed fuzz probes run | covered | AZ-3333 AC-2; smoke 7 (exit 0; the probes print no PASS lines) | intake |

### New angles and their status

| id | angle | status | outcome |
|----|-------|--------|---------|
| A1 | Python and TypeScript `edges` probes use the same descending NFC/NFD order and print "refused" under a text that says "accepted" | gap-unclear | owner chose "Swap the keys in both" → AZ-3334, scenario S13 |
| A2 | only the `frame` set is run at test time | gap-unclear | owner chose "Run each once, record counts" → scenario S14 |
| A3 | `--all-features` set not in the matrix | info | the change only adds `std` gates and narrows one gate to std+text; a std-on set cannot regress |
| A4 | flake hypothesis: `grep -q` cannot exit before a one-write `printf` | info | the cause stays "unproven" in every text; here-strings in bash 3.2 use a temp file (a new failure mode that `bad_in` would now show) |
| A5 | C# class rename changes test ids | info | no tracked file, filter or CI list uses the old names; external dashboards cannot be checked |
| A6 | CRLF, bash versions | info | not applicable / see S2 |
| A7 | `#![cfg]` after `//!` docs | info | compiles (`nostd_dict_tests.rs:2`); the 22 gated files carry it on line 1 |
| A8 | two C# figures (4,287 run, 4,220 listed) | info | different measures; the specs and the smoke say "listed" |

### Review findings (same agent) and disposition

| id | sev | finding | disposition |
|----|-----|---------|-------------|
| F1 | Low | the batch report said the 4 dead-code warnings are in "non-test code the embedded stage compiles"; all are `cfg(test)` items | report corrected; the cfg-only cleanup stays a candidate (handoff77) |
| F2 | Low | `nostd_dict_tests.rs` header said "Needs the `text` feature" | fixed ("`std` and `text`") |
| F3 | Low | one early-exit reader left in the selftest (`grep -nE ... \| grep -qv timed_abort`) | fixed (captured variable and here-string); selftest passes, 240 lines |
| F4 | Low | evidence says 8 burners, AC says 12; the smoke's burners lived 300 s | report cites the smoke trial (20 of 20 under 12); burner life 600 s |
| F5 | Low | the first smoke script had `env VAR limit` | fixed before the trial's repeat; steps 3 and 7 passed after |
| F6 | Info | `scenarios.md` S12 said "same PASS lines" | reworded |
| F7 | Info | `swift/Sources/Packbin/PackbinError.swift:4-5` says every raw value is a shared hostile-vector outcome term; false for the four frame kinds | not changed (Swift source comment, outside this loop's tasks); candidate (handoff77); the DocC sentence does not claim it |
| F8 | Info | "the only reason" stronger than the repository proves | ADR note now says "the reason that remains" |
| F9 | Info | plan names `smoke76.md` | file written at close |

### Harness gaps

- The batch report had no run evidence for the AZ-3331 AC-3 embedded stage, the AZ-3332 AC-2 Swift suite count and the AZ-3333 verdict-line comparison: they fall to the total run (step 11) and smoke 7.
- DocC link resolution (`swift package generate-documentation`) was not run.

## Round 2

**Date**: 2026-10-27
**Implement pass**: fix batch (AZ-3334 plus the Low fixes above)
**Verdict**: COMPLETE — 13 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

| id | status | evidence |
|----|--------|----------|
| S13 | covered | AZ-3334 AC-1, AC-2; `edges.py` and `edges.ts` packet expressions; before: `refused` in both; after: `accepted as two keys (no normalization; Swift F47 differs)` in both, exit 0, 0 FAIL, other lines equal (86 PASS in Python, 87 in TypeScript); smoke 10 |
| S14 | covered | one plain `cargo test --no-default-features [--features <set>] --no-fail-fast` per set, Cargo 1.79, run on f102eba plus the fix batch: none 19 passed, alloc 20, text 28, ecc 29, text+ecc 38, text+ecc+frame 45; 0 failed and exit 0 in all six; 40 test targets each; the two sets with `frame` print 4 dead-code warnings in `cfg(test)` items (F1) |
| S1..S12 | unchanged | round 1; the changes since touch only the selftest's last pipe (F3), a test-file comment (F2), docs, the two probes and the smoke |

Not walked: the AVR runtime check of `chacha20_xor` (owner: out of scope); dropping `supports` (owner decision, needs a Windows build).
