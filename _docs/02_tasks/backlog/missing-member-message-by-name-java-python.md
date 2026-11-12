---
kind: queue-item
order: 500
source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 7)
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# Java and Python: a missing required member is named by its name, not its id

## Problem
A row whose required `utf8 text` (id 1) is missing is refused by Java with `1: expected string` and by Python with `1: expected str`; TypeScript, Go and Swift say `missing text`. The id alone does not tell a scheme author which member is missing in a row of several.

## Outcome
Java and Python refuse a missing (null / absent) required member with a message that names the member, as TypeScript, Go and Swift do; a present value of the wrong type keeps its current message.

## Code sections
Java `VarFields.java` (the string getter), the matching paths for other kinds; Python `_pack.py` (the `expected str` check and its siblings); both packages' tests that pin the old text (grep them first).

## Acceptance checks
- Java and Python probe line `null-member` prints a refusal that contains `missing text`.
- A wrong-type value (an int for `text`) keeps its current message.
- Every test or fixture that pins the old text is updated in the same change; both suites pass.

## Needs
none
