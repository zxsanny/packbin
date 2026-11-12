# Implementation completeness, loop 112

**Task**: AZ-4206_repeat_followed_by_a_field. **Date**: 2026-11-12. **Verdict**: PASS.

| Spec item | Evidence | Status |
|-----------|----------|--------|
| Outcome: the owner sees, per package, which schemes build, what they pack and whether the package reads its own bytes, and decides one rule | `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md`; decision "Refuse at build", 2026-11-12 | PASS |
| Included: committed probes of five shapes in all nine packages | `scripts/probes/repeat-followed-by-field/` (the five shapes, `e` in two forms, a control and a sixth shape `f`); committed in the batch commit | PASS |
| Included: findings table, build / pack hex / unpack per package and shape | the matrix and the appendix (85 lines of one run) | PASS |
| Included: a proposed rule with the evidence, and the existing fixtures and golden vectors it would refuse (expected 0) | the rule and four options; measured 0 shared fixtures, golden vectors and ring schemes; 4 of TypeScript's own test schemes | PASS |
| Included: after the decision, the implementation task(s), via decompose at 8 points or more | epic AZ-4209, AZ-4210 to AZ-4219 in `todo/`, 29 points, the contract and the scenario table | PASS |
| Excluded: the repeat wire format; implementing the rule | no package source changed (`git diff --stat` of the loop touches `scripts/probes/` and `_docs/` only) | PASS |
| AC-1 "45 cells" | 9 packages by 5 shapes are all recorded; 6 cells are a refusal of the row, not of the repeat (Rust `b`, `c` in two APIs, bound C++ `b`, `c`), and say so | PASS |

Scaffold scan (`placeholder`, `stub`, `TODO`, `fake`, `mock`) over `scripts/probes/`: 0 hits. No runtime capability is named by this task.

## System Pipeline Audit

Not applicable: the loop adds measurement tools and documents; no production pipeline changes. The probes call each package's public pack and unpack for real (review, mechanical checks).
