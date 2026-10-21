---
loop: 54
branch: dev
---

# C++ core: a `when` whose source sits in a false `when` is false

**Task**: AZ-2816_cpp_when_of_skipped_source
**Name**: C++ `when` of a skipped source
**Description**: Pack and unpack treat a `when` source that sits inside a `when` that does not hold as absent, so the consuming `when` is false, as in the other packages; a shared hostile case runs in all eight packages.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `cpp/src/core/pack.cpp`, `cpp/src/core/values.cpp`, `cpp/src/core/unpack.cpp`, `cpp/include/packbin/order.hpp`, `fixtures/hostile/cases.txt` and the eight package runners
**Tracker**: AZ-2816
**Epic**: AZ-2645

## Problem

`u8 mode=0; when(mode==1){u16 a; u8 k=2}; when(k==2){u8 b=5}` packs `21 00 05` in C++ and its own `unpack` refuses it with `TrailingBytes` (`gcc:16`, loops 51 and 52). The Python package (run 2026-10-21) and std Rust write the mode byte only, for `k==2` and for `k==0`, and unpack to `{mode: 0}`. A count held by a `when` already has this check (`count_skipped`, `mark_held`); a `when` source does not. On unpack the source is never read, so it holds 0, and `when(k==0)` would match and read a body that was never written.

## Outcome

- C++ pack and unpack equal the reference for the four rows of `input_data/expected_results/results_report.md`.
- A shared hostile case (`pack_when_of_skipped_source` or the name the corpus convention gives) is run by all eight packages.
- The Cortex-M4F image stays within 8,192 B flash and 512 B stack.

## Scope

### Included
- The check for a `when` source in the table (resolve time) and in pack and unpack (run time), reusing the count mechanism when it fits.
- Corpus case with scheme S and S0, mode 0 and 1; runners of all eight packages; a package that differs is fixed here when it is the same defect.
- A flash or stack saving elsewhere in `cpp/src/core` first when the change does not fit (`AGENT_GOTCHAS.md`: 272 B flash, 8 B stack); new margins in `AGENT_GOTCHAS.md` and `_docs/02_document/components/05_cpp_package/description.md`.

### Excluded
- Row U24 (the three `pack_novalue_count_clear_when_*` skips); any wire change; any new public API.
- A `when` whose source is a bool or group presence bit (existing rule; one probe only).

## Acceptance Criteria

**AC-1: Skipped source, value not equal** (AC-W1)
Given `u8 mode; when(mode==1){u16 a; u8 k}; when(k==2){u8 b}` and the row mode 0, a 7, k 2, b 5
When it is packed and unpacked
Then pack writes the mode byte only (equal to the Python and Rust packet) and unpack returns mode 0 with no error.

**AC-2: Skipped source, value zero** (AC-W2)
Given the same scheme with `when(k==0)` and the row mode 0, a 7, k 0, b 5
When it is packed and unpacked
Then pack writes the mode byte only and unpack returns mode 0, no error, `b` unset.

**AC-3: Held source** (AC-W3)
Given mode 1 for both schemes
When they are packed and unpacked
Then the packets carry a, k and b (equal to the Python and Rust packets) and unpack returns the same row.

**AC-4: Nested skip** (AC-W4)
Given a source two `when`s deep
When the outer is false, or the inner is false, or both hold
Then the consuming `when` is false, false, and true (body written).

**AC-5: One `when` holds both** (AC-W5)
Given a `when` that holds the source and its consumer
When the source is written
Then the consumer follows the source's value.

**AC-6: Eight packages** (AC-W6)
Given the shared corpus case
When the runners of the eight packages run
Then 0 packages fail it and 0 skip it.

**AC-7: Embedded budget** (AC-W7)
Given the arm embedded stage, `cpp-avr-uno` and `PACKBIN_NO_TEXT`
When they build
Then flash is at most 8,192 B, stack at most 512 B, the other two inside their recorded margins, and the new margins are written down.

**AC-8: Nothing else moves** (AC-W8)
Given the C++ suite on `gcc:16`, the hostile corpus and the language-pair ring
When they run before and after
Then packets of schemes with no skipped source are byte-identical and 0 tests fail.

## Non-Functional Requirements

**Performance**
- No C++ speed-suite case gets slower.

**Compatibility**
- No wire change; no packet that unpacked before stops unpacking.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2, AC-3 | new C++ host test with S and S0, rows of the results report | bytes and round trips as listed |
| AC-4, AC-5 | host tests with nested and same-`when` schemes | as AC text |
| AC-6 | corpus case in each package's hostile runner | pass in 8 of 8 |
| AC-7 | arm embedded stage, AVR, no-text builds | sizes within budget |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-8 | `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` | C++ suite | 0 failures | Compatibility |
| AC-6, AC-8 | `bash .github/workflows/language-pair.sh` (host recipes of `AGENT_GOTCHAS.md`) | cross-language ring | "language pairs passed" | — |

## Constraints

- `make -C cpp clean` between host and container builds; the arm embedded stage (`docker compose -f docker-compose.test.yml run --rm cpp-embedded`, about 3 minutes) and the AVR target after any edit under `cpp/src/core`.
- A worker never runs `git stash/checkout/reset/clean/add/rm/mv`; commands end on their own (stdin from `/dev/null`, a timeout).
- Hostile corpus change: every runner reads it; run each (`AGENT_GOTCHAS.md`: grep every reader of a shape).

## Risks & Mitigation

**Risk 1: The margins (272 B flash, 8 B stack) are too thin**
- *Risk*: the check costs flash or stack on the M4F.
- *Mitigation*: resolve the source once at table build time (constexpr, no run-time cost) where possible; measure before the commit; make a saving first if needed.

**Risk 2: Another package fails the shared case**
- *Risk*: the defect class exists elsewhere; only Python and Rust are known to pass.
- *Mitigation*: run all eight before the commit; fix the same defect here, ticket anything larger.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| M4F flash and stack margins may not fit the change | measure on the arm stage; saving first | open | Medium |
| Unpack reads a skipped source as 0 (`when(k==0)` would match) | AC-2 pins it | open | Medium |
| Another package may fail the shared case | AC-6; fix or ticket | open | Medium |
