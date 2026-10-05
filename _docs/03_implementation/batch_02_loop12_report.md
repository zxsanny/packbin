# Batch Report

**Batch**: 2 (feature-assess round 1 follow-through; typescript, csharp, java and rust+cpp workers in parallel; python and the shared ring by the parent)
**Tasks**: AZ-2129_typescript_constructor_checks, AZ-2130_csharp_empty_nested_row, AZ-2131_java_empty_group_refused, AZ-2132_python_empty_group_refused, AZ-2133_rust_cpp_bitwhen
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2129_typescript_constructor_checks | Done | 5 files (1 src, 3 tests, driver) | 108 pass, 0 fail, 3 todo (AZ-2090) | None |
| AZ-2130_csharp_empty_nested_row | Done | 5 files (1 src, 3 tests, driver) | 204/204 pass | None |
| AZ-2131_java_empty_group_refused | Done | 5 files (2 src, 2 tests, driver) | java/test.sh 0 failures | None |
| AZ-2132_python_empty_group_refused | Done | 2 files (1 src, 1 test) | 103/103 pass | None |
| AZ-2133_rust_cpp_bitwhen | Done | 9 files (Rust 4 src, 2 tests; C++ 1 test; 2 drivers) | Rust 135/135; C++ all tests passed | None |

Shared (parent): `.github/workflows/language-pair.sh` gains the `bitwhen` ring (`010001`) over C#, TypeScript, Rust, Java and C++ (Python joins with its split form, AZ-2100); project AC-4 reworded ("when its field is walked"); `README.md` empty-group rule and upgrade notes.

Owner decisions applied (loop 12 assessment round 1): U1 A (TS constructor runs the checks), U3 A (an empty group that can never carry `true` fails construction wherever it stands), U4 A (keep the `bitwhen` bytes, pin them, reword AC-4), G3 (pin non-`true` values). AZ-2133: the Rust public API could not express a split flag byte; owner chose to export the map `pack` / `unpack` (`pub use walk::{pack, unpack}`) so the Rust driver joins the ring.

## Code Review Verdict: PASS_WITH_WARNINGS

One fresh reviewer over the whole batch: no Critical or High; every AC traced; all six suites and the five `bitwhen` drivers verified in scratch copies. Findings and outcome:

- Medium (Rust): the newly public `pack`/`unpack` docs promised errors the code did not give. Owner: **fail loudly** — a `__repeat__` value other than `Groups` is `PackError::Type`; a `repeat` inside a `repeat`/`times` round and a `times` inside a `times` round fail at construction (red-first tests). The worker kept `times` inside a `repeat` round, which works and has an AZ-2075 test; owner confirmed the narrower rule. Docs rewritten to match the walkers (raw flag-byte value returned under its name, `times` values one list per field).
- Medium (Java): AZ-2131 AC-2 holds for Map rows only; typed empty nested rows hit AZ-2101 Defect 1. Owner: **accept the AZ-2101 dependency** (recorded on AZ-2131 and AZ-2101).
- Lows fixed by the parent: README empty-group rule names C++ and Java presence-only nested rows; TS `new Scheme` upgrade note; `language-pair.sh` rebuilds the Java driver when sources are newer than the cached build (stale `/tmp/packbin-handoff-java` reported a false mismatch); report placeholders filled. Not fixed: `language-pair.sh` is not run by CI (pre-existing; leftover).

## Test Suite

- C# 204; TypeScript 111 (108 pass, 3 todo); Python 103; Rust 135; Java 4 runners, 0 failures; C++ all tests passed
- Failed: 0
- `language-pair.sh`: user, nested, boolflag, booltrue, bitwhen (C#, TS, Rust, Java, C++), session and position rings pass; the run used the stale default Java build dir and rebuilt it (fix verified)
- CI-parity: PASS — all six `docker compose -f docker-compose.test.yml run --rm <lang>` suites exit 0 (TypeScript on a re-run, see below), `cases.test.sh`, `report-row.test.sh`, `publish-gate.test.sh`, strict `tsc`, `language-pair.sh`
- AC-10 throughput in the containers is load-sensitive on this host: the C# NFR failed once at 1013 ms and the TypeScript NFR once at 1297 ms while the host load average was ~20 (outside this run). Alone on the host both pass with a 5–6× margin (C# ~155 ms; TypeScript ~200 ms at HEAD and in the working tree alike), so batch 2 changed no hot path; re-runs passed (C# 417 ms, TypeScript 886 ms)

Pins that passed before their change (spec-expected; each was shown to catch a regression by breaking the code in a scratch copy): non-`true` values clear the bit (all four), `bitwhen` bytes (TS, C#, Java, Rust, C++), C# bool empty group, Java empty nested row presence.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | TS: `new Scheme(2, scheme(1, …).fields)` (already-flattened fields) still builds and packs | AZ-2129 U1 | None | clear |
| 2 | TS: unpacking `010001` also puts the flag byte value `m: 1` in the row | AZ-2091 | AZ-2091 | clear |
| 3 | C#: an anchored empty group on a non-bool member (`byte?`, `string`) can never carry `true` either; refused too (U3 rule), with a test | AZ-2130 U3 | Keep | clear |
| 4 | C#: the refusal fires in the `Field.Group` factory (the only place that knows the member type), before `new Scheme<T>` | AZ-2130 AC-1 | Keep | clear |
| 5 | Java: unpacking a typed nested row throws `ClassCastException` (child created as `HashMap`), with or without fields | AZ-2101 Defect 1 | AZ-2101 | clear |
| 6 | Java: an empty nested row carries presence only (`{g: {x: 1}}` comes back as `{g: {}}`) | AZ-2131 AC-2 | Document as presence-only | clear |
| 7 | Rust: the public API had no split flag-byte path at all (typed API has no flag-byte form, C18) | AZ-2133 | Owner: export map `pack` / `unpack`; typed form stays C18 | clear |
| 8 | C++: a macOS `make test` leaves a Mach-O `cpp/build/packbin_tests` that the Linux container treats as current (`Syntax error`) | none | Touch a source or `make clean` before the container run; gitignored build dir | clear |
| 9 | C# AC-10 throughput NFR failed once in the container (1013 ms > 1000 ms) at host load average ~24 (four Docker suites + a reviewer's scratch builds); alone it takes ~155 ms, earlier container runs 320–420 ms; batch 2 did not touch the C# pack/unpack path | AC-10 | Re-run on a quieter host (below); consider running the six container suites one at a time when an agent is also building | clear |
| 10 | Rust map: a `times` or `when` as a `flags` member or flag-bit field is never written, no error | AZ-2128 | Recorded on AZ-2128 | clear |
| 11 | Rust map: a `repeat` / `times` inside a `list` / `dict` group element builds but the item is ignored on pack and unpack fails | AZ-2086 | Recorded on AZ-2086 | clear |

## Commit

`[AZ-2129] [AZ-2130] [AZ-2131] [AZ-2132] [AZ-2133] Finish the bool rule` — body: one line + `Loop: 12`

## Next Batch: All tasks complete
