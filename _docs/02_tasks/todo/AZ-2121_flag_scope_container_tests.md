# Pin the orphan flag-bit rule in every container shape, all packages

**Task**: AZ-2121_flag_scope_container_tests
**Name**: Orphan flag-bit tests for every container
**Description**: Add a build-fails-naming-the-bit test for each container shape the loop 11 specs name and no package tests yet.
**Complexity**: 2 points
**Dependencies**: None
**Component**: csharp, java, rust, typescript
**Tracker**: AZ-2121
**Epic**: AZ-2069

## Problem

The orphan split-flag-bit construction rule (a bit needs its flag byte earlier in the same scope) was added in loop 11 for TypeScript, C#, Java and Rust. The code paths are shared across containers, but the tests do not cover every shape: C# has no times-round or dict-element test; Java has no dict-element test; Rust has no test for a typed bound `list` whose element is a bare flag bit; a combined `flags` member with the byte missing is tested only in TypeScript. Found by feature-assess round 2 (R2-G2).

## Outcome

Each shape below fails to build naming the bit, in every package that has split form; same-scope shapes still build.

## Scope

### Included
- Tests only, in the four packages named above; no production change unless a test exposes a bug.

### Excluded
- Python (the rule lands with AZ-2100).
- Error kind and label (C15).

## Acceptance Criteria

**AC-1: C# times round and dict element**
Given a flag byte outside a `times` body (and outside a dict element) with its bit inside, When the scheme is built, Then building fails naming the bit

**AC-2: Java dict element**
Given a flag byte outside a dict element with its bit inside, When built, Then building fails naming the bit

**AC-3: Rust typed bound list**
Given a typed bound `list` whose element is a bare flag bit, When built, Then construction panics naming the bit (can fold into AZ-2117)

**AC-4: Combined flags member without its byte**
Given a combined `flags(...)` member that holds a split bit whose byte is missing, When built in C#, Java and Rust, Then building fails naming the bit

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: a test exposes a real false negative. *Mitigation*: fix it in the same task, with a failing-first test.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine before the loop that takes it | coordinator | open | Low |

## Loop 16 progress (2026-10-06)

| Part | Package | State |
|------|---------|-------|
| AC-3 typed bound list with a bare flag bit | Rust | done in loop 16 batch 1 (test only, no production change: the construction already panicked naming the bit) |
| AC-4 combined flags member without its byte | Rust | open (loop 16 batch 2) |
| AC-2 dict element, AC-4 | Java | open (loop 16 batch 2) |
| AC-1, AC-4 | C# | held until the C# multi-target work is committed |
