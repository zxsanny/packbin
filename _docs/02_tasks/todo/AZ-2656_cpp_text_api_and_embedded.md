---
loop: 35
branch: dev
---

# C++: Text-only strings, Packed view, PACKBIN_NO_TEXT build, UTF-8 check, size probe

**Task**: AZ-2656_cpp_text_api_and_embedded
**Name**: C++: Text-only strings, PACKBIN_NO_TEXT build, UTF-8 check, size probe
**Description**: C++ string fields bind to Text, embedded builds link no codec yet still read the fields after a string through a Packed view, UTF-8 is validated, and the Cortex-M4F size probe keeps its budgets.
**Complexity**: 4 points
**Dependencies**: AZ-2655
**Component**: C++ package (embedded)
**Tracker**: AZ-2656
**Epic**: AZ-2645

## Problem

A `View` borrows bytes from the input, which compact text cannot give. The Cortex-M4F probe (`cpp/embedded/arm/size_main.cpp`) measures core plus a 14-entry table against 8,192 B of flash and 512 B of stack and its table holds a `utf8` field. C++ checks no UTF-8 today.

## Outcome

- `utf8` binds to `Text<N>` (decoded copy) or to `Packed` (a borrowed view of the count-skipped compact payload, no decoding); never to `View`.
- A board with no codec skips a string by its count header, reads the fields after it, and can forward the string's bytes.
- The embedded CI builds define `PACKBIN_NO_TEXT` and keep the 8,192 B and 512 B budgets with a string-free table.
- C++ refuses invalid UTF-8 on the escape and raw paths.

## Scope

### Included
- `cpp/include/packbin/` string binders (`utf8<&Row::name>(N)` accepts `Text<N>`, a `View` member is a compile error with a clear message); `Packed` {`data`, `len`} borrows the payload bytes after the count header (valid while the input lives); `PACKBIN_NO_TEXT` removes the codec from the dispatch and refuses a `utf8` field bound to `Text<N>` when the table is built (`static_assert` when constexpr, a `BadValue` otherwise), while a field bound to `Packed` is accepted; pack of a `Packed` member writes the count header and the bytes as given and does not decode or validate them (an opaque field for relays); a UTF-8 validator for the escape and raw bytes.
- `cpp/embedded/arm/size_main.cpp`: the 14-entry table keeps 14 entries with a non-string field in place of `utf8`; `cpp/embedded/common/all_kinds.cpp` and `all_kinds.hpp` use `Text<N>`; `arm.sh`/`lib.sh` define `PACKBIN_NO_TEXT` for the size probe only; the ARM vectors runner still runs string vectors with the codec.
- `hostile_host_tests.cpp` (176-190, 427-431): `invalid_utf8` and `invalid_utf8_dict_key` become refusals; compile-fail test for `View` on `utf8`.

### Excluded
- The codec itself (AZ-2655); README; changing the budgets (they stay 8,192 B and 512 B).

## Acceptance Criteria

**AC-1: Text only**
Given a field list with `utf8<&Row::name>` over a `View` member
When it is compiled
Then compilation fails with a message naming `Text<N>`; the same list over `Text<N>` compiles (CS-18)

**AC-2: No-text build**
Given the core built with `PACKBIN_NO_TEXT`
When a field list with a `utf8` field is built, and the object files are checked
Then the field is refused when the list is built, and no codec symbol is in the binary (CS-12)

**AC-3: Probe budgets**
Given the Cortex-M4F size probe with a string-free 14-entry table
When `arm.sh` runs the size stage
Then flash delta ≤ 8,192 B and stack ≤ 512 B; the new delta and margin are recorded in the AGENT_GOTCHAS entry (CS-12)

**AC-4: UTF-8 refused**
Given escape bytes `c3 28` and a surrogate encoding
When they are unpacked
Then each returns `BadValue` naming the field, and the two former "accepted" hostile cases are refusals (CS-16)

**AC-5: ARM runner**
Given the ARM vectors runner with the codec on
When it runs the string vectors
Then all pass on the emulated target (CS-5)

**AC-6: Packed skips and forwards**
Given a packet whose scheme is `u16 sid`, a string bound to `Packed`, `u8 kind` and a build with `PACKBIN_NO_TEXT`
When the packet is unpacked
Then `sid` and `kind` are read, `Packed` holds the payload bytes of the string without decoding, no codec symbol is in the binary, and packing the same row writes the original bytes (CS-20)

**AC-7: Packed with a damaged count**
Given the same scheme and a packet whose count header is larger than the bytes that remain
When it is unpacked
Then the result is a short-packet error naming the field and 0 values (inherits AC-8)

## Non-Functional Requirements

**Compatibility**
- Firmware that does not use strings links the same code as before (flash delta equal to today's within 0 B for the unchanged table fields).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | compile-fail test | message names Text<N> |
| AC-2 | no-text object check | no codec symbols |
| AC-4 | validator cases | BadValue |
| AC-6 | `Packed` unpack and pack in a no-text build | fields around the string read, bytes forwarded |
| AC-7 | count larger than the packet | short-packet error |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | ARM size stage | `bash cpp/embedded/run.sh` arm stage (about 3 minutes) | budgets hold | CS-12 |
| AC-5 | ARM vectors runner | string vectors | pass | CS-5 |

## Constraints

- The wire format is the one in `_docs/02_document/contracts/library/compact-text.md` (AZ-2646). A language never invents a choice the contract fixes (tie-breaks, table order, pad bits).
- The encoder works on the UTF-8 bytes this package already produces for a string today, so lone-surrogate and invalid-input behavior of the language does not change (fit decision, feature-description).
- Positions: a string field, a list element, a dictionary key, a dictionary value that is a list of strings, a string under `repeat`, `times` or `flags` (scenario S12). Dictionary pairs are still sorted by the key's UTF-8 bytes before the keys are encoded; a repeated decoded key is refused (S10).


## Contract

Producer of the C++ string binding rule in the contract's C++ section.


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Wire break: packets with strings written before this loop cannot be read | Owner accepted 2026-10-18 (no tag was ever published) | accepted-risk | Medium |
| Probe flash margin was 32 B; the table changes one field | Measure and record the new margin | open | Low |
| `Packed` is a new public C++ type; a relay can forward bytes it never validated | Owner chose option D 2026-10-18; documented as opaque | resolved | Low |
