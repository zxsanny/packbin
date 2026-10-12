# Total review — loop 21

Date: 2026-10-12. Scope: commit 3acc589 (113 paths; 45 source files, 70 test and fixture files). `/code-review high`, 8 angles in one context. Verdict: **PASS_WITH_WARNINGS** — 0 Critical, 0 High, 3 Medium, 5 Low.

| # | Sev | Where | Finding | Ruling |
|---|-----|-------|---------|--------|
| 1 | Medium | `csharp/FieldBinding.cs:158` | `HoldsRange` accepts float/double/decimal element types for integer lists: builds and unpacks, pack refuses | owner row U12 |
| 2 | Medium | `python/src/packbin/_unpack.py:50` | surcharge removal weakens the per-name list memory bound ~9x | measure in step 14; README memory note |
| 3 | Medium | `rust/src/walk/pack.rs:174` | per-name `repeat` lists without `__repeat__` silently dropped | owner row U13 |
| 4 | Low | `java/.../Rounds.java:317` | nested-row group is one slot, TypeScript counts members | owner row U16 |
| 5 | Low | `typescript/tests/round-scope-cost.test.ts:43` | ~20 ms timing with 5 ms slack flaked once | judge at the idle step 11 run |
| 6 | Low | `cpp/include/packbin/order.hpp:292` | empty-body check does not look through `when` | gap-clear G1, loop 22 |
| 7 | Low | `cpp/src/core/pack.cpp:96` | one `Late` flag: refused id corner | handoff |
| 8 | Low | `rust/src/field/map_scheme.rs:93` | 190-column doc line | fixed (hand reflow) |

Checked and clean: no file over 500 lines; nothing staged by workers; accepted rows keep wire bytes (golden, route and ring fixtures run at step 11); no empty `catch` or silenced error added; construct-time rules add no per-round cost; TypeScript views (`Object.create`) are not read by any `hasOwn` on the sliced scopes; the count-after-bit shape cannot reach `refuseUnwrittenCount` wrongly because a `times` count always precedes the bit in field order.
