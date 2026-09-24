# Batch 4 — Loop 4

**Tasks**: AZ-1950
**Verdict**: PASS_WITH_WARNINGS
**Date**: 2026-09-24

## Results

| Task | Status | Areas | Tests | Notes |
|------|--------|-------|-------|-------|
| AZ-1950 | Done | six language packages | local suites green | Shared marker hex |

## Discovered during implementation

| Spec | Handling | Status |
|------|----------|--------|
| C# cannot infer the row type in params Field[] | Field.U16&lt;MarkerRow&gt; | clear |
| Rust typed binders have no u2 or dict | Map path still has those kinds | unclear |

## CI-parity

PASS. `docker compose -f docker-compose.test.yml run --rm` for csharp, typescript, python, rust, cpp, and java. Marker hex `2001000065cd1d00a3e111010000000000` in all six.

## Commit

`[AZ-1950] Bind scheme fields by order`

## Next batch

Feature assessment.
