# Autodev Loop Plan — Loop 11

loop: 11
kind: product
confirmed: true
branch:
ship: false

Loop works on `dev` (no worktree — user decision, 2026-10-05). Scope: AZ-2071..2077 (epic AZ-2069), the first group from the loop 10 record.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs already in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | seven 2-point specs exist |
| implement | 10 | Implement | yes | AZ-2071..2077 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | ACs unchanged; vectors came from AZ-2070 |
| update-docs | 13 | Update Docs | yes | unpack error behavior and Rust constructor change touch module docs; no other loop in flight |
| security | 14 | Security Audit | yes | untrusted network input (hostile unpack) |
| performance | 15 | Performance Test | no | AC-10 round-trip budget is an existing test in Run Tests |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 14 points across 7 tasks |
| local-deploy | — | Local deploy + open site | yes | always at close |
| smoke | — | Smoke acceptance | yes | always at close |

## Task groups (disjoint write sets)
- python: AZ-2071
- typescript: AZ-2072
- csharp: AZ-2073, AZ-2076 (same package; serialize)
- java: AZ-2074, AZ-2077 (same package; serialize)
- rust: AZ-2075

## Implementation

Divergence recorded at the batch commit: the plan listed seven tasks; a cross-language decision (zero-progress `times` round is an error) was taken at review and applied to all five packages.

### Files that change
- python/src/packbin/_unpack.py (edit); python/tests/hostile_support.py, test_hostile_unpack.py, test_hostile_vectors.py (new)
- typescript/src/kinds.ts, walker.ts (edit); typescript/tests/hostile.test.ts, tests/support/* (new)
- csharp/Walker.cs, Walker.Counted.cs, Packbin.cs (edit); csharp/FlagGroup.cs, Scope.cs, tests (new)
- java/src/main/java/packbin/Walker.java, VarFields.java, Field.java (edit); Containers.java, Scalars.java and tests (new)
- rust/src/field/{mod,order}.rs, scheme/mod.rs, walk/{mod,unpack}.rs, lib.rs (edit); hostile_tests.rs, scope_tests.rs (new)

### Order of work
1. Batch 1: python, typescript, rust, csharp (2073 then 2076) in parallel; Java (2074 then 2077) as soon as a slot freed
2. Fresh-reviewer pass per package group, fixes, then the `times` decision applied to all five

### Proof
- Each package's `*hostile*` unit and vector tests, FlagState/Scope race tests (C#, Java), Rust scope tests
- Docker CI suites for all six languages PASS

### Risks
- Wire-visible change only for degenerate packets (zero-width `times` body) and for packets that used to hang, throw or misread

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | CLARIFY | AZ-2107_python_zero_width_elements, AZ-2108_typescript_zero_width_elements, AZ-2109_csharp_zero_width_elements, AZ-2110_java_zero_width_elements, AZ-2111_rust_zero_width_elements | _docs/loops/loop11/assessment11.md |
| 2 | EXTEND (2 gap-clear, test-only) | none this loop: R2-G1 extends AZ-2114, R2-G2 is AZ-2121 (follow-ups, same rule the owner chose for round 1 clear gaps) | _docs/loops/loop11/assessment11.md |

Owner answers (2026-10-05): U1 A (zero-width list/dict element is an error at unpack), U2 A (orphan split flag bit refused at construction; Python rides on AZ-2100), U3/U4/U5 become tickets AZ-2116/2117/2118, clear gaps G1-G4 become follow-up tickets AZ-2112..2115 for later loops.

## Security audit follow-through (step 14)

Verdict PASS_WITH_WARNINGS (0 Critical, 0 High, 3 Medium, 6 Low). Owner answers (2026-10-05): fix F4 (C# top-range integers), F5 (TypeScript `__proto__`) now, and F6, F7, F8, F9 also in this loop. New tasks: AZ-2122 (TypeScript F5, F6, F8), AZ-2123 (C# F4, F7, F9), AZ-2124 (Java F9), AZ-2125 (Rust F7). Report: `_docs/05_security/security_report.md`.

Re-verification by the auditor: F4, F5, F6, F8, F9 fixed; F7 residual (no packet-size budget) documented in the README; no new findings. Open Low from loop 10 (F1-F3, CI pins) unchanged.
