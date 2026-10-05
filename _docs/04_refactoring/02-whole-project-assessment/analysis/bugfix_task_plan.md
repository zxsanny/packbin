# Bug-fix tasks — ordered by severity

**Source**: `../list-of-changes.md` (C01–C31) and the four `../discovery/scan_*.md` files.
**Date**: 2026-10-05

## User decisions (2026-10-05)

| Topic | Decision |
|-------|----------|
| `bool` presence | The flags bit is set only for `true`; `false` and absent leave it clear. A `bool` (and an empty group) is allowed only inside `flags` / a flag byte — anywhere else is a scheme construction error. |
| Java target | Published jar compiled with `--release 17`; no API above Android API 26 (replace `Arrays.compareUnsigned`). |
| Required registries | NuGet, npm, PyPI, crates.io, Maven Central, vcpkg are required: a missing credential or a failed upload fails the run. PlatformIO, ESP-IDF, Arduino are optional: skipped with a warning when their credential is missing. |
| Rust typed `times` | Fix it: typed `times` binds a `Vec<E>` of element rows. |

Not decided here (later, not bug fixes): the error-label rule and error kinds (C15), Rust typed-scheme parity beyond `times` (C18), C# `Bound<T>` removal (C22).

## Rules for every task

- One package per task (component = package), ≤ 5 points, behavioral spec from `/Users/zxsanny/.claude/skills/decompose/templates/task.md` (all sections, incl. `## Flagged concerns`).
- Every bug gets a failing test first, from the probe that found it; existing tests and golden vectors stay green.
- Hostile-packet cases come from task 01's shared vector file once it exists.
- No shared walker across languages (ADR-001). No public API change unless the task says so.

## Order (most serious first)

| # | Severity | Package | Task | Sources | Points | Writer |
|---|----------|---------|------|---------|--------|--------|
| 01 | Critical | fixtures | Shared hostile-packet vectors (hex + expected error kind) used by every package | C03 | 1 | D |
| 02 | Critical | Python | Unpack never hangs or throws on hostile packets (zero-progress repeat, invalid UTF-8, count behind a clear flag) | C03, B8, B17 | 2 | B |
| 03 | Critical | TypeScript | Unpack never hangs or throws on hostile packets | C03, B8, B17 | 2 | B |
| 04 | Critical | C# | Unpack never hangs or throws on hostile packets (zero-progress repeat, negative/oversize counts) | C03, A3 | 2 | A |
| 05 | Critical | Java | Unpack never hangs or throws on hostile packets | C03, A3 | 2 | A |
| 06 | Critical | Rust | Zero-progress repeat ends with an error; `when`/count naming an outer field inside repeat/times rejected at construction | C03, C04, C1 | 2 | C |
| 07 | Critical | C# | Unpack keeps flags state per call (two threads, one scheme) | C05, A2 | 2 | A |
| 08 | Critical | Java | Unpack keeps flags state per call, incl. split flag-byte form | C05, A2 | 2 | A |
| 09 | Critical | C++ | Unpack keeps flag-byte values per scope (container reusing a byte number) | C05, C6 | 2 | C |
| 10 | High | C# | `bool` rule + 9th flag bit rejected at construction | C01, C02, A1, A5 | 2 | A |
| 11 | High | TypeScript | `bool` rule + 9th flag bit rejected at construction | C01, C02, B2, B4 | 2 | B |
| 12 | High | C++ | `bool`/empty group only inside flags; `u2` over 64 children is a construction error | C01, C13, C7 | 1 | C |
| 13 | High | Rust | Flag-bit positions from field order; 8-bit limit; `bool` only inside flags | C01, C02, C05, C2, C14 | 2 | C |
| 14 | High | Python | `bool` only inside flags; 9th flag bit rejected | C01, C02, B4 | 1 | B |
| 15 | High | TypeScript | Pack refuses integers that do not fit their field | C06, B1 | 2 | B |
| 16 | High | Rust | Typed schemes: unique binder names, `when` compares numbers, unsupported composite children fail at construction | C07, C3, C5, C21 | 3 | C |
| 17 | High | Rust | Typed `times` binds a `Vec<E>` and round-trips | C07, C4 | 3 | C |
| 18 | High | C# | References to later fields rejected at construction | C04, A4 | 2 | A |
| 19 | High | C# | Pack fails loudly: null required value, field of another row type, NaN `when`; scheme owns its field list | C08, A5, A11, A17 | 3 | A |
| 20 | High | Java | References to later fields rejected; `bool` only inside flags | C04, C01, A4, A1 | 2 | A |
| 21 | High | TypeScript | References resolve in their own id scope; 64-bit `when` matches on unpack | C04, C17, B7 | 3 | B |
| 22 | High | TypeScript | Flags inside nested groups packed; ambiguous member names rejected; flag-byte values kept out of the row | C17, B3, B5, B6 | 3 | B |
| 23 | High | C# | Nested rows and list/dict elements bind per scope (README C# example runs) | C09, A6 | 5 | A |
| 24 | Medium | C# | AC-10 throughput test times the public typed path | C09, A8 | 1 | A |
| 25 | High | Java + publish | Published jar targets Java 17 / Android API 26; gate asserts the class-file version | C10, A14, D2 | 2 | D |
| 26 | High | publish | Publish runs only after `test.yml` passed on the tagged commit | C11, D4 | 2 | D |
| 27 | High | publish | Build and verify every artifact before the first upload | C11, D5 | 3 | D |
| 28 | High | publish | Re-run of a tag completes a partial publish; required-registry policy (decision above) | C11, D6, D7 | 3 | D |
| 29 | Medium | vcpkg | Port builds `cpp/CMakeLists.txt` and exports target `packbin`; consumer build check | C12, D3 | 3 | D |
| 30 | Medium | embedded CI | Embedded targets run with errexit in force | C14, D1 | 2 | D |
| 31 | Medium | Python | Split-form `flag_byte` in a Scheme; repeat/times lists start empty; repeat with container children packs | C16, B10, B11, B12 | 3 | B |
| 32 | Medium | Java | Typed nested rows unpack to the declared child type; ids scoped per nested row (public `group(...)` gains a child factory) | C19, A7 | 3 | A |
| 33 | Medium | TypeScript | List/dict elements of kind `group` / `flags` | C17, B13 | 3 | B |
| 34 | Medium | TypeScript | npm package ships compiled JavaScript and type declarations | C20, B15 | 3 | B |
| 35 | Low | Python | `PackSession` refuses a wrong-size seed on every path; star-import does not shadow builtins | C30, B21, B22 | 1 | B |
| 36 | Low | Rust | `PackSession::pack` returns the pack error instead of "not open" | C30, C9 | 1 | C |

## Open questions for the user (from the spec writers, 2026-10-05)

1. Task 01: the hostile-vector hex is derived from the wire rules, not replayed from the probes — each package task replays its cases first. Should a `when` inside `repeat` naming an outer field be a construction error in every package (today only Rust task 06 plans it)?
2. C++ does not validate UTF-8 (`invalid_utf8*` vectors return Ok): validate, or mark C++ exempt in the vector file?
3. Task 01 `oversize_count_times` should accept `short_packet|too_many` (C++ bound arrays report `TooMany` first).
4. Task 25: the Android API 26 floor also removes `List.of` / `List.copyOf` / `Map.of` (≈18 sites, API 30); enforcement choice: Animal Sniffer (recommended) / `javap` denylist / review only.
5. Task 28: an optional registry that fails with its credential present — fail the run (spec default) or warn?
6. Task 29: vcpkg port keeps vendored sources (recommended) or `vcpkg_from_github`?
7. Task 23: C# typed `repeat`/`times` hold one round today — same decision as Rust (bind a list of element rows)?
8. Task 32: should Java's old `group(...)` overload fail at construction on a typed row?
9. Task 19: float equality in `when` (NaN = NaN, −0.0 ≠ 0.0 as in Java) has no cross-language rule in `schema.md`.
10. Interim error shape until C15: hostile packets return any non-ok result that does not throw (tasks 02–06); a real `BadValue` kind waits on C15.
11. Unassigned TypeScript defect: `repeat`/`times` pack only direct children per item (`when` or anchored group inside `times` throws "expected number") — add to task 22 or a new task.
12. Scope added by writers: task 09 also carries the C++ zero-progress `repeat` guard (C++ hangs too when the repeat is unbound) and a host-only hostile runner; task 10 the C# group-presence gap; task 19 unequal repeat/times list lengths; task 20 the Java repeat NPE.

Total: 36 tasks, 81 points. Order of work follows the numbers; a later task may depend on an earlier one in the same package (the writer records it under **Dependencies**).
