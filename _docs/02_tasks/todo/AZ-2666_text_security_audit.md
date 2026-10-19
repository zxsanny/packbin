---
loop: 41
branch: dev
---

# Compact text: security audit of the decoders in all eight packages

**Task**: AZ-2666_text_security_audit
**Name**: Compact text: security audit of the decoders in all eight packages
**Description**: Compact text: security audit of the decoders in all eight packages
**Complexity**: 3 points
**Dependencies**: None
**Component**: compact-text
**Tracker**: AZ-2666
**Epic**: AZ-2645

## Problem

The compact text decoders read untrusted bytes in eight languages and the loop 35 audit was skipped.

## Outcome

- A security report with no open High or Critical finding.

## Scope

### Included
- Reading the decoders, the `Packed` pass-through, dictionary keys, limits; report in `_docs/05_security/`; fixes for High or Critical findings.
- The message ECC unpack path added in loop 38 (parity check and repair, the 254-byte limit, dispatch), in the same eight packages (owner, 2026-10-19, loop 41 intake).

### Excluded
- The session cipher, publish path.

## Acceptance Criteria

**AC-1: Report**
Given the eight decoders
When they are audited
Then `_docs/05_security/security_report.md` has a compact text addendum covering reads past the payload, sizes from untrusted numbers, UTF-8 checks, the 65,535-byte limit, expansion and Packed (HD-5)

**AC-2: ECC unpack path**
Given the eight message ECC decoders
When they are audited
Then the same addendum covers lengths and the 254-byte limit, the syndrome and repair work on hostile bytes, Uncorrectable results, and dispatch on untrusted type numbers

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | report | every High or Critical finding fixed |
| AC-2 | report | every High or Critical finding fixed |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond `problem.md` | — | resolved | Low |
