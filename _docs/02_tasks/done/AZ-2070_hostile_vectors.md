---
loop: 10
branch: loop/10-cpp-microcontroller
---

# Shared hostile-packet vectors

**Task**: AZ-2070_hostile_vectors
**Name**: Shared hostile-packet vector set
**Description**: One language-neutral set of hostile packets and invalid schemes, with the expected outcome kind for each, that every package's tests read.
**Complexity**: 1 point
**Dependencies**: None
**Component**: fixtures
**Tracker**: AZ-2070
**Epic**: AZ-2069

## Problem

A crafted packet can hang or crash a receiver today, and each package found that out separately with throw-away probes (`_docs/04_refactoring/02-whole-project-assessment/discovery/`):

- `repeat` whose body can read 0 bytes loops forever on leftover bytes. Seen in TS `walker.ts:311-318`, Python `_unpack.py:269-275`, C# `Walker.cs:362`, Java `Walker.java:336` and Rust `walk/unpack.rs:172`. Probes were killed by a 5 s alarm. Sources: `scan_typescript_python.md` L8, `scan_csharp_java.md` L10, `scan_rust_cpp.md` LB1.
- A count read from the packet that is negative or larger than `int.MaxValue` makes C# and Java throw instead of returning an error. Five different exception types were seen (`Walker.Counted.cs:71,111,126`; `VarFields.java:46,128,149`; C# probe 9, Java probe 7: `u32` count `0xFFFFFFFF`, `i8` count `-1`).
- Invalid UTF-8, or a count field that is absent because its flag bit is clear, makes TS and Python throw. TS `bits` silently returns `[]` (`kinds.ts:297`, `walker.ts:38-53,345`, `_unpack.py:119,178,279-321`; TS/Py L14).
- Several invalid schemes are accepted at construction and then corrupt or drop data:
  - a 9th flag bit (C# L3, Rust LB2, TS/Py L4);
  - a `when` or count that names a later field (C#/Java L11);
  - a `when` inside `repeat` that names an outer field (Rust LB1);
  - a `bool` outside `flags` (C#/Java L2, C++ LB7).

Without one shared set, each package fix (tasks 02–06, 10–14, 18, 20) would invent its own inputs, and the packages would drift.

## Outcome

- `fixtures/hostile/cases.txt`: one machine-readable line per case (id, stage, expected outcome, packet hex).
- `fixtures/hostile/README.md`: per case, the scheme in language-neutral terms (field kinds, order ids, anchors, count references), the packet bytes explained, the expected outcome, and the probe it comes from.
- A format check that runs in CI, so a malformed line fails the build.
- Package tasks 02–06, 09–14, 18 and 20 can load the file by path (`<repo>/fixtures/hostile/cases.txt`). They locate it the same way they already find `fixtures/golden.hex` (`csharp/tests/PackbinTests.cs:235`, `python/tests/test_position.py:19`, `typescript/tests/packbin.test.ts:22`, `rust/src/packbin_tests.rs:68`, `java/src/test/java/packbin/PackbinTest.java:338`).

## Notation (used in README.md and below)

- Every scheme has type number `1`, so every packet starts with `01`.
- Field order ids follow the README rule (`README.md:617-640`, "Field numbers are the order in the scheme"). A group's anchor equals the next value id and is not written. Ids continue through `flags`/`when`/`repeat`/`times` children. Only list/dict elements restart at 0.
- Wire rules come from `README.md:640-952`: little-endian integers; `utf8` = `u16` length + bytes; `list`/`dict` = `u16` count; `sized`, `bits` and `times` take their count from an earlier integer field; `flags` = one `u8`, bit 0 = first child.
- Outcome vocabulary for `expected`:
  - `short_packet`, `trailing_bytes`, `bad_value`, `too_many`, `type_mismatch` — unpack returns that error value, with no exception and no row;
  - `scheme_error` — construction fails: an exception in C#, Java, TS, Python and Rust; a compile error or `validate()` → `SchemeInvalid` in C++.
  - `a|b` means either is accepted; the first is preferred.
- Until the error-kind decision (C15) is taken, a package that has no type for a given kind passes the case with **any** non-ok unpack result that is not an exception. For example, only C++ has `BadValue`. Every package must still name the kind it actually returned in the test name or message.
- Every `unpack` case must return within **1 second** on CI hardware; a hang is a failure. Each package test supplies its own time guard.

## The cases (content of `cases.txt`)

| id | stage | expected | hex | Scheme (language-neutral) | Source probe |
|----|-------|----------|-----|---------------------------|--------------|
| zero_progress_repeat_bool | unpack | trailing_bytes\|scheme_error | `01ff` | id0 `repeat` anchor 0 { id0 `bool on` } | C# P10, Java P8 (repeat of a zero-width bool + 1 trailing byte → infinite loop) |
| zero_progress_repeat_when | unpack | trailing_bytes\|scheme_error | `0100ff` | id0 `u8 mode`; id1 `repeat` anchor 1 { id1 `when` anchor 1, `eq(0, 1)` { id1 `u8 v` } } — mode = 0, so the body reads 0 bytes and `ff` is left over | TS/Py L8 (non-matching `when`), Rust LB1 |
| negative_count | unpack | bad_value\|short_packet | `01ff61` | id0 `i8 n`; id1 `sized payload`, count = id0. n = −1, one byte left | C# P9, Java P7 (`i8` count −1). **Unconfirmed**: the probe's count consumer kind was not recorded; `sized` is chosen here |
| oversize_count | unpack | short_packet | `01ffffffff61` | id0 `u32 n`; id1 `sized payload`, count = id0. n = 4294967295, left 1 | C# P9, Java P7 (`u32` count `0xFFFFFFFF`) |
| oversize_count_times | unpack | short_packet | `01ffffffff00` | id0 `u32 n`; id1 `times` anchor 1, count = id0 { id1 `u8 v` } | derived from C#/Java L9 (`int` cast / pre-sized lists). **Unconfirmed** by a recorded probe |
| oversize_list_count | unpack | short_packet\|too_many | `01ffff` | id0 `list xs` { element id0 `u8` }; count 65535, 0 bytes left. `too_many` is accepted only for a fixed-capacity destination (C++ `Array<T,N>` with N < 65535) | derived. **Unconfirmed**: whether C++ checks capacity or bytes first |
| invalid_utf8 | unpack | bad_value\|short_packet | `010200c328` | id0 `utf8 name`; length 2, bytes `c3 28` (invalid 2-byte sequence) | TS/Py L14 (`TypeError` / `UnicodeDecodeError`). Rust returns `Short` today (`rust/src/walk/unpack.rs:328-339`) |
| invalid_utf8_dict_key | unpack | bad_value\|short_packet | `0101000100ff00` | id0 `dict m` { element id0 `u8` }; 1 pair, key length 1, key byte `ff`, value `00` | derived (Rust `unpack.rs:377` decodes keys). **Unconfirmed** for TS/Py |
| count_behind_clear_flag | unpack | bad_value\|scheme_error | `0100` | id0 `flags` anchor 0 { id0 `u8 n` }; id1 `sized payload`, count = id0. Flag byte `00`, so n is absent | TS/Py L14 (`RangeError` / `RuntimeError`); C++ returns `BadValue` today (`cpp/src/core/unpack.cpp:52-55`) |
| count_behind_clear_flag_bits | unpack | bad_value\|scheme_error | `0100` | as above, with id1 `bits segs`, count = id0 | TS L14: silently returns `[]` today |
| nine_flag_bits | construct | scheme_error | `-` | id0 `flags` anchor 0 { id0…id8: nine `u8 f0`…`f8` } | C# P3 (9th value dropped), Rust LB2 (debug panic / release alias), TS/Py L4 |
| nine_flag_bits_split | construct | scheme_error | `-` | id0 split-form `flag_byte`; nine `bit(...)` fields id1…id9, each a `u8` | Rust LB2 (`field/mod.rs:144`); Python already rejects (`scan_typescript_python.md` B4) |
| when_names_later_field | construct | scheme_error | `-` | id0 `u8 a`; id1 `when` anchor 1, `eq(2, 1)` { id1 `u8 b` }; id2 `u8 c` | C# P11, Java P5 (`README.md:788-806`: "The tested field must already have been read") |
| count_names_later_field | construct | scheme_error | `-` | id0 `sized payload`, count = id1; id1 `u16 n` | Java P6 (constructs, then throws at pack) |
| when_names_outer_field_in_repeat | construct | scheme_error | `-` | same scheme as `zero_progress_repeat_when` | Rust LB1; plan task 06. See Flagged concerns |
| bool_outside_flags | construct | scheme_error | `-` | id0 `u8 a`; id1 `bool on` | C# P2, Java P9, C++ LB7. User decision 2026-10-05 |
| empty_group_outside_flags | construct | scheme_error | `-` | id0 `u8 a`; id1 `group` with no children | C++ LB7. User decision 2026-10-05 ("a `bool` (and an empty group) is allowed only inside `flags`") |

**Hex provenance**: the scan files describe each probe's scheme and result but did not record its exact bytes, apart from C# probe 9 and Java probe 7, which give the count values. Every hex value above was derived from the README wire rules and was **not replayed** against the code. Each package task must first run its cases on the current code, check that the documented failure reproduces (hang, exception or wrong result), and only then fix it. If a hex value does not reproduce the failure, the package task corrects it here and records why.

User decision (verbatim, 2026-10-05): "The flags bit is set only for `true`; `false` and absent leave it clear. A `bool` (and an empty group) is allowed only inside `flags` / a flag byte — anywhere else is a scheme construction error."

## `cases.txt` format

- UTF-8, LF line endings. Lines starting with `#` and blank lines are ignored.
- Data line: four fields separated by one or more spaces or tabs: `id stage expected hex`.
  - `id`: `[a-z0-9_]+`, unique.
  - `stage`: `unpack` or `construct`.
  - `expected`: outcome vocabulary terms joined by `|`.
  - `hex`: lowercase, even length, starting with `01` for `unpack`; `-` for `construct`.
- The file holds no schemes: under ADR-001 each language writes the scheme by hand from `README.md` in its own test.

## Scope

### Included
- `fixtures/hostile/cases.txt` and `fixtures/hostile/README.md` with the 17 cases above.
- A format check script (for example `fixtures/hostile/cases.test.sh`, in the same style as `.github/workflows/report-row.test.sh`). It checks the rules above and that every id has a section in `README.md`. It runs in the `scaffold` job of `.github/workflows/test.yml`.
- One row for the hostile set in `_docs/02_document/tests/test-data.md`.

### Excluded
- Any package test or fix (tasks 02–06, 09–14, 18, 20).
- Changing `fixtures/golden.hex` or any golden vector.
- Deciding error labels or kinds (C15).
- Embedded (QEMU) vector runs. Firmware cannot read files, so C++ host tests read the file and the QEMU vector runner stays as it is.

## Acceptance Criteria

**AC-1: Every listed case is present and well-formed**
Given `fixtures/hostile/cases.txt`
When the format check runs
Then it finds the 17 ids above, each with a valid stage, expected outcome and hex, and exits 0.

**AC-2: A malformed line fails the check**
Given a copy of the file with an odd-length hex, an unknown stage, a duplicate id, or an unknown outcome term
When the format check runs on that copy
Then it exits non-zero and names the line.

**AC-3: Each case is described**
Given `fixtures/hostile/README.md`
When a reader looks up any id from `cases.txt`
Then they find the scheme (kinds, ids, anchors, count references), the byte-by-byte packet breakdown, the expected outcome, and the source probe.

**AC-4: CI runs the check**
Given a push or pull request
When the `scaffold` job of `test.yml` runs
Then the format check runs, and a failure fails the job.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | format check on the committed file | exit 0, 17 ids |
| AC-2 | format check on four corrupted temp copies | exit non-zero for each, offending line printed |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | branch with a broken line | push | `scaffold` job fails | — |

## Constraints

- ADR-001: no shared walker and no generated schemes. The file carries bytes and outcomes only.
- Valid-packet behavior and every golden vector stay unchanged.
- The bash format check follows `bash.md`: strict mode, no `2>/dev/null`, shellcheck-clean.

## Risks & Mitigation

**Risk 1: A derived hex does not trigger the probed failure**
- *Risk*: The exact probe bytes were not recorded.
- *Mitigation*: Each package task replays the case against current code before its fix (see Hex provenance) and corrects the file if needed.

**Risk 2: An expected outcome conflicts with a later error-kind decision (C15)**
- *Mitigation*: Alternatives with `|`, plus the "any non-ok, no exception" rule until C15 lands. Update the file when C15 is decided.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `when_names_outer_field_in_repeat` is planned as a construction error only for Rust (task 06). Other languages may currently evaluate the outer field. A cross-language rule is needed; until then, other packages accept either `scheme_error` or a correct evaluation that never hangs | user / plan owner | open | Medium |
| C++ does not validate UTF-8: `utf8` into a `View` borrows raw bytes. `invalid_utf8` may unpack OK in C++ unless C++ is required to validate | user (C15 / C++ owner) | open | Medium |
| Hex values are derived, not replayed (see Hex provenance) | package task writers | open | Low |
| Error kinds are not uniform across packages (C15 undecided) | user | open | Medium |
