# Code Review Report
**Batch**: AZ-1939_counted_list | **Date**: 2026-09-23 | **Verdict**: PASS_WITH_WARNINGS

## Findings
| # | Severity | Category | File:Line | Title |
|---|----------|----------|-----------|-------|
| 1 | Medium | Maintainability | python/src/packbin/__init__.py:1 | Python packer stays over the 500-line cap |
| 2 | Medium | Maintainability | typescript/src/index.ts:1 | TypeScript packer stays over the 500-line cap |

### Finding Details
**F1: Python packer stays over the 500-line cap** (Medium / Maintainability)
- Location: `python/src/packbin/__init__.py`
- Description: The counted-list branch landed in the same module. `list` is the field helper, so builtin `list` checks go through `_builtin_list`.
- Suggestion: Split pack and unpack in a later pass.
- Task: AZ-1939

**F2: TypeScript packer stays over the 500-line cap** (Medium / Maintainability)
- Location: `typescript/src/index.ts`
- Description: The list switch stays with the other field kinds.
- Suggestion: Leave the switch with the other field kinds.
- Task: AZ-1939

## Spec
AC-1 is `020001000200` and `[1, 2]`. AC-2 is `01000001`. AC-3 is `01000102` with the following field `2` and no bytes left. AC-4 is `0000` for an empty list, and 65536 elements fail before a buffer is returned. `repeat` is rejected as an element.
