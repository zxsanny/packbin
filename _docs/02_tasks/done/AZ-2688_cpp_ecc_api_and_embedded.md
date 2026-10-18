---
loop: 38
branch: dev
---

# Message ECC: C++ API, in-place repair, session, dispatch and embedded builds

**Task**: AZ-2688_cpp_ecc_api_and_embedded
**Name**: Message ECC: C++ API, in-place repair, session, dispatch and embedded builds
**Description**: C++ scheme setting and pack/unpack API for protected schemes, plus the embedded size gates.
**Complexity**: 4 points
**Dependencies**: AZ-2687_cpp_ecc_codec
**Component**: cpp package
**Tracker**: AZ-2688
**Epic**: AZ-2677

## Problem

A C++ caller needs the parity setting on the scheme, a way to repair its receive buffer, and proof that Cortex-M4F does not grow. Source of truth for the numbers: `_docs/02_task_plans/message-error-correction/acceptance_criteria.md` (EC-n) and `input_data/expected_results/results_report.md` (rows 1 to 17).

## Outcome

- Scheme parity setting, `pack` appends parity, protected `unpack` takes a writable buffer and repairs in place; read-only unpack stays for n = 0
- Session, compact text and dispatch rule (same n across handlers, refused at construction)
- Cortex-M4F with the feature off is unchanged (8,132 B flash, 492 B stack); ESP32 and Pico builds with encode on

## Scope

### Included
- `cpp/include/packbin/` API headers, `cpp/embedded/` size gates and examples, `cpp/tests/`

### Excluded
- Codec internals (AZ-2687)
- Other packages

## Acceptance Criteria

**AC-1: Off is unchanged**
Given n = 0
When the existing suites and size gates run
Then 0 failures; Cortex-M4F flash 8,132 B and stack 492 B (EC-1, EC-12).

**AC-2: Protected API**
Given n = 4
When packed and unpacked
Then bytes equal row 4; the buffer after a successful unpack equals the original protected message (EC-2, EC-17).

**AC-3: Limits**
Given n = 33, or a clear message above 254 - n
When the scheme is built or packed
Then a typed error, 0 bytes written (EC-3, EC-4).

**AC-4: Session, text, dispatch**
Given an open session and a text field with n = 4, and several handlers
When 2 bytes or the type byte are wrong
Then the row and handler are recovered; a mixed-n dispatch is refused at construction (EC-10, EC-11, EC-16).

**AC-5: Targets**
Given the ESP32 and Pico builds
When built with encode on
Then 0 errors, 0 warnings, and the packed bytes equal the vectors (EC-12).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | size gates | unchanged |
| AC-2 | in-place repair | equal |
| AC-3 | limits | typed errors |
| AC-4 | session, text, dispatch | as stated |
| AC-5 | target builds | 0 warnings |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | arm stage | flash and stack gate | 8,132 B / 492 B | EC-12 |
| AC-5 | esp and pico stages | build and run vectors | pass | EC-12 |

## Constraints

- `PACKBIN_NO_ECC` is the switch; Cortex-M4F builds with the feature off
- Record what encode costs in flash if an owner wants it on M4F later

## Risks & Mitigation

**Risk 1: Flash on Cortex-M4F**
- *Risk*: 60 B margin.
- *Mitigation*: feature off there; measured, not assumed.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Correcting t bytes lowers guaranteed detection to n - t bytes | the contract states it and lists the chance (EC-15); t = 0 gives full detection | open | High |
