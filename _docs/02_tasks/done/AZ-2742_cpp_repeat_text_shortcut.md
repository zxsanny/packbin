---
loop: 48
branch: dev
---

# C++ text: reuse the previous round's encoded bytes in a times/repeat pack

**Task**: AZ-2742_cpp_repeat_text_shortcut
**Name**: C++ shortcut for a text repeated round after round
**Description**: `txt::encode_field` runs the optimal parse for every round of a `times`/`repeat` pack; when a round's text equals the previous round's, the bytes already written are reused, so 200 rounds of one 65,535-character text take 1 s, not 1.9 s.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `cpp/src/core/text_encode.hpp`, `cpp/src/core/pack.cpp`, `cpp/include/packbin/core.hpp` (only if the state lives in `Scratch`), `cpp/tests/core/text_repeat_host_tests.cpp`
**Tracker**: AZ-2742
**Epic**: AZ-2645

## Problem

Loop 46 (AZ-2737) measured the C++ pack of one 65,535-character text in 200 rounds at 1.9 s on gcc:16 at load factor 1.00 (8 to 9.5 ms a round): `txt::encode_field` solves the parse in every round. Python, TypeScript, Go, Swift, Rust and Java keep the encoded text of the last round and meet 1 s. The owner (2026-10-20) chose a 3 s bound for the C++ test and this task for the shortcut.

## Outcome

- `two_hundred_rounds_of_65535_characters_within_three_seconds` becomes a 1 s test (load-aware, `load_factor::bound(1.0)`).
- Every `enc` row of `fixtures/text/vectors.txt` and every packet of the other C++ tests stay byte-identical.
- The Cortex-M4F image stays inside 8,192 B flash and 512 B stack; no heap, no global or static mutable state.

## Scope

### Included
- Decide where the previous round's bytes are found. The only memory the core has is the caller's output buffer (the previous field) and the caller's `Scratch`; candidates: (a) `Scratch` keeps the offset and size of the last field written and the parse is replayed; (b) `encode_field` compares the text with the previous field in the output buffer when that field is a raw field. Pick the one that costs least flash and stack; record the figures.
- A flash or stack saving elsewhere in `cpp/src/core` first when the change does not fit the margins (272 B flash, 8 B stack, `AGENT_GOTCHAS.md`).
- Update the margins in `AGENT_GOTCHAS.md` and `_docs/02_document/components/05_cpp_package/description.md` with the new measured figures.

### Excluded
- Any wire change, any other package, any new public API.

## Acceptance Criteria

**AC-1: One second**
Given 200 rounds of one 65,535-character text in a times/repeat pack
When the C++ repeat test runs on `gcc:16` at an idle host
Then pack plus unpack finish within 1 s nominal times the load factor, and the packet unpacks to the input.

**AC-2: Same bytes**
Given every `enc` row of `fixtures/text/vectors.txt`, the cross-language ring and the C++ text tests
When they run before and after the change
Then every packet is byte-identical; a round whose text differs from the previous round is encoded as before (a test with alternating texts and one changed text in the middle).

**AC-3: Embedded budget**
Given the Cortex-M4F image built by the arm embedded stage
When the sizes are read
Then flash is at most 8,192 B and stack at most 512 B, and the new margins are written in `AGENT_GOTCHAS.md`.

**AC-4: Other targets**
Given the `cpp-avr-uno` target (`platform.hpp` names only) and `PACKBIN_NO_TEXT`
When they build
Then both build and their sizes do not grow beyond their recorded margins.

## Non-Functional Requirements

**Performance**
- No other C++ text case gets slower (the `speed` suite shows the same or better times).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `text_repeat_host_tests.cpp` with a 1 s load-aware bound | pass |
| AC-2 | alternating texts, a changed text mid-run, identical texts, a text that compacts, a raw text | packets equal the one-by-one encoding |
| AC-3 | arm embedded stage | sizes within 8,192 B and 512 B |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | `bash .github/workflows/language-pair.sh` (host recipes of `AGENT_GOTCHAS.md`) | cross-language ring | "language pairs passed" | Performance |

## Constraints

- `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` before the commit (GCC `-Werror`); `make -C cpp clean` when switching between host and container; `docker compose -f docker-compose.test.yml run --rm cpp-embedded` (about 3 minutes) and the AVR target after any edit under `cpp/src/core`.
- A worker never runs `git stash/checkout/reset/clean/add/rm/mv`; commands end on their own (stdin from `/dev/null`, a timeout).

## Risks & Mitigation

**Risk 1: The stack margin (8 B) is gone**
- *Risk*: a state field in the pack frame costs stack on the M4F.
- *Mitigation*: keep the state in `Scratch` (caller memory), not in the pack frame; measure before the commit; make a saving first if needed.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Where the previous bytes live is not decided | decided in implement with measured figures (this task, Included) | open | Medium |
