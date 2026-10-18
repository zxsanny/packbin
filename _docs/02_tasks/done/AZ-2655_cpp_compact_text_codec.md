---
loop: 35
branch: dev
---

# C++: allocation-free compact text codec with caller scratch

**Task**: AZ-2655_cpp_compact_text_codec
**Name**: C++: allocation-free compact text codec with caller scratch
**Description**: The C++ core writes and reads compact text with no heap, no exceptions and tables in read-only memory.
**Complexity**: 5 points
**Dependencies**: AZ-2647
**Component**: C++ package
**Tracker**: AZ-2655
**Epic**: AZ-2645

## Problem

The C++ core allocates nothing and throws nothing, and writes into a caller's buffer. The optimal parse needs a working table per character, and the decoder must copy text out because compact text cannot be borrowed from the input.

## Outcome

- The same bytes as the other seven packages, with the C++ constraints kept.
- A scratch-buffer interface that makes the encoder allocation-free.

## Scope

### Included
- `cpp/src/core/pack.cpp` `pack_text` (106-131) and `unpack.cpp` `unpack_text` (66-86), `values.cpp` `text_bytes`/`store_text`; new codec header/source with the constant tables in read-only data.
- Pack takes a caller-sized scratch (`Scratch<N>` or a pointer and length); a text that needs more scratch than given returns an error naming the field, never a different encoding.
- Unpack writes into `Text<N>` (`TooMany` when N is too small, never a cut).
- Tests in `cpp/tests/core/` (`counted_tests.cpp`:32, `container_tests.cpp`:114, `hostile_host_tests.cpp`) with a vectors-file loader; run with `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` and the host `make -C cpp test` (AGENT_GOTCHAS).

### Excluded
- `View` binding for strings, `PACKBIN_NO_TEXT`, UTF-8 validation entry and the embedded probe (AZ-2656); README; ring and hostile fixtures (AZ-2657).

## Acceptance Criteria

**AC-1: Packs every vector**
Given `vectors.txt` rows and a scratch large enough
When each `enc` row is packed
Then bytes equal the row; mismatches 0 (CS-5, CS-7, CS-19)

**AC-2: Unpacks every vector into Text**
Given the same rows and `Text<N>` with N at least the text
When they are unpacked
Then the text equals the row; a `Text<N>` too small returns `TooMany` and leaves earlier fields (CS-5, CS-18)

**AC-3: Scratch too small**
Given a text needing more scratch than supplied
When it is packed
Then an error names the field, no byte is written for the field, and a larger scratch gives the vector bytes (CS-18)

**AC-4: No heap, no exceptions**
Given the core built with `-fno-exceptions -fno-rtti -Wall -Wextra -Werror` on gcc:16 and Apple clang
When the build and the allocation probe run
Then 0 warnings, 0 calls to `new`/`malloc` (symbol check on the object files) and tables in read-only data (CS-12, CS-18)

**AC-5: Hostile payloads**
Given every `bad` row and 100,000 random payloads
When they are unpacked
Then errors only, never a crash, output at most 6 bytes per payload byte plus 8 (CS-9, CS-10)

**AC-6: Lists and dictionaries**
Given the `user` and `nested` packets
When they are packed and unpacked
Then bytes equal the `ref` rows; keys are still required ascending from the caller (S10)

**AC-7: Speed**
Given a 20-character Ukrainian string
When 100,000 round trips run on one core
Then ≤ 1 second (CS-11)

## Non-Functional Requirements

**Performance**
- AC-7 bound on a Raspberry Pi class host; stack use of the decoder is bounded by a constant documented in the contract.

**Compatibility**
- Non-string packets are byte-identical.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | pack vs vectors | 0 mismatches |
| AC-2 | unpack into Text | 0 mismatches, TooMany case |
| AC-3 | scratch sizes | error and success |
| AC-4 | object-file symbol check | no allocation symbols |
| AC-5 | bad rows and random payloads | error only |
| AC-7 | speed loop | within bound |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | ring driver `handoff.cpp` | packs the `user` packet | bytes equal the `ref` row | CS-7 |

## Constraints

- The wire format is the one in `_docs/02_document/contracts/library/compact-text.md` (AZ-2646). A language never invents a choice the contract fixes (tie-breaks, table order, pad bits).
- The encoder works on the UTF-8 bytes this package already produces for a string today, so lone-surrogate and invalid-input behavior of the language does not change (fit decision, feature-description).
- Positions: a string field, a list element, a dictionary key, a dictionary value that is a list of strings, a string under `repeat`, `times` or `flags` (scenario S12). Dictionary pairs are still sorted by the key's UTF-8 bytes before the keys are encoded; a repeated decoded key is refused (S10).


## Contract

Consumer of `compact-text.md` and `vectors.txt`.


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Wire break: packets with strings written before this loop cannot be read | Owner accepted 2026-10-18 (no tag was ever published) | accepted-risk | Medium |
| Optimal parse scratch grows with text length (12 bytes per code point as built: a base cost and 8 one-byte deltas per character) | Caller-sized scratch, error when too small (card 4) | resolved | Low |
