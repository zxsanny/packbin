# Autodev Loop Plan — Loop 7

loop: 7
kind: product
confirmed: true
branch:
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | Spec `04_borrowed_count` is already in todo |
| decompose-feature | 9.5 | Decompose Feature | no | The operator named this one spec |
| implement | 10 | Implement | yes | Borrowed count in all six languages |
| feature-assess | 10.5 | Feature Assessment | yes | After implement |
| run-tests | 11 | Run Tests | yes | Always |
| test-spec-sync | 12 | Test-Spec Sync | yes | New ACs |
| update-docs | 13 | Update Docs | yes | `schema.md` rows for the two helpers |
| security | 14 | Security Audit | no | No auth or secret scope |
| performance | 15 | Performance Test | no | No latency NFR |
| deploy | 16 | Deploy | no | Not a ship loop |
| release | 16.5 | Release | no | Deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | No cutover |
| retrospective | 17 | Retrospective | no | No incident this loop |
| local-deploy | — | Local deploy + open site | yes | Loop close |
| smoke | — | Smoke acceptance | yes | Loop close |

## Implementation

### Files that change
- csharp/Field.cs, Fields.cs, Packbin.cs, Walker.cs, Walker.Counted.cs (edit)
- csharp/tests/BorrowedCountTests.cs (new)
- typescript/src/fields.ts, kinds.ts, walker.ts, index.ts (edit)
- typescript/tests/borrowed-count.test.ts (new)
- python/src/packbin/_nodes.py, _pack.py, _unpack.py, __init__.py (edit)
- python/tests/test_borrowed_count.py (new)
- rust/src/field.rs, value.rs, walk/pack.rs, walk/unpack.rs, scheme/bound.rs, scheme/mod.rs, lib.rs (edit)
- rust/src/borrowed_count_tests.rs (new)
- java/src/main/java/packbin/Field.java, Packbin.java, Walker.java, VarFields.java, SchemeOrder.java (edit)
- java/src/test/java/packbin/PackbinFieldsTest.java (edit)
- cpp/include/packbin/packbin.hpp, scheme.hpp (edit)
- cpp/src/field.cpp, counted.cpp, walk.cpp, unpack_walk.cpp, walk.hpp, walk_common.cpp (edit)
- cpp/tests/borrowed_count_tests.cpp (new)
- cpp/tests/packbin_tests.cpp, cpp/Makefile (edit)

### Order of work
1. Add `packed` and `times` beside `bits` and `repeat` in each language.
2. Prove AC-1 through AC-5, including the route hex, in each language.

### Proof
- AC-1 width-2 values 0,1,2,3 are byte `e4`
- AC-2 width-1 bias −1 is `ff`, or no bytes when the item count is 0
- AC-3 two lat/lon pairs then a following `u8` of 7
- AC-4 route hex `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`
- AC-5 length mismatch names the field; a short tail names the field, bytes needed, and bytes left, and returns 0 values

### Risks
- `repeat` and fixed-slot `u2` stay on their existing paths.
