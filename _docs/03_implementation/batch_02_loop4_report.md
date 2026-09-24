# Batch 2 — Loop 4

**Tasks**: AZ-1946
**Verdict**: PASS_WITH_WARNINGS
**Date**: 2026-09-24

## Results

| Task | Status | Areas | Tests | Notes |
|------|--------|-------|-------|-------|
| AZ-1946 | Done | six language packages | CI compose suites green | Python/Java pass the row type into Scheme.of |

## Discovered during implementation

| Spec | Handling | Status |
|------|----------|--------|
| Python and Java need a runtime type to construct T | Scheme.of takes the class | clear |
| Rust and C++ have no reflection | Accessors at the scheme site | clear |

## CI-parity

CI-parity: PASS

Commands: `docker compose -f docker-compose.test.yml run --rm` for csharp, typescript, python, rust, cpp, java, after `make -C cpp clean`.

## Commit

`[AZ-1946] Pack with an explicit scheme and a plain row`

## Next batch

None in this plan. Feature assessment is next.
