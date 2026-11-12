# Autodev Loop Plan — Loop 111

loop: 111
kind: product
confirmed: true
branch: dev
ship: false

Feature: AZ-4205, the three review Lows of the C# element row (AZ-4199): the row form for `E[]`, `IList<E>` and `IDictionary<string, E>` members; a member declared for another row type refused when the scheme is built (element rows and nested rows); tests for `when` and `times` inside an element row pinned to TypeScript's bytes (owner, 2026-11-12: "AZ-4199 Lows in C#", scope "accept all recommended"). The repeat class went to AZ-4206 (`todo/`, unclaimed, a later loop).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done: AZ-4205 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | C# overloads, the row check, tests, README |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | whole C# suite on both targets (with a console logger), plus the loop stages that read C# (`csharp`, ring, publish-gate C# shares) |
| test-spec-sync | 12 | Test-Spec Sync | no | no project criterion changed; AZ-4205 rows go in the traceability matrix in step 13 (loop 103 practice) |
| update-docs | 13 | Update Docs | yes | C# component description (element rows, row-type rule), traceability rows |
| security | 14 | Security Audit | yes | `lite`: 3 points, library code, the unpack path is not changed but a raw exception out of `Unpack` is removed |
| performance | 15 | Performance Test | no | the check runs at scheme build only |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | next due by loop 113 |
| local-deploy | — | Local deploy + open site | yes | no site (library): the smoke script runs the C# checks |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke111.md`, agent run |

## Implementation

### Files that change
- `csharp/Field.cs`, `csharp/Fields.cs`: overloads for `E[]`, `IList<E>`, `IDictionary<string, E>`
- `csharp/SchemeOrder.cs`: element-row and nested-row members walked with their row type
- new `csharp/tests/ElementRowLowsTests.cs` (`ElementRowTests.cs` is 291 lines)
- `README.md` C# List section

### Order of work
1. Tests first for AC-2 / AC-2b / AC-1 (fail on HEAD), AC-3 / AC-3b (pass on HEAD, pinned bytes).
2. Row check in `SchemeOrder`; overloads; README.
3. Whole C# suite on both targets.

### Proof
New tests fail on HEAD for AC-1 (compile) and AC-2 / AC-2b, pass after; whole C# suite green.

### Risks
Overload resolution of existing calls (Risk 1 of the spec).
