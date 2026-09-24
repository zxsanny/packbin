# Batch 3 — Loop 4

**Tasks**: AZ-1949
**Verdict**: PASS_WITH_WARNINGS
**Date**: 2026-09-24

## Results

| Task | Status | Areas | Tests | Notes |
|------|--------|-------|-------|-------|
| AZ-1949 | Done | six language packages | each language suite green locally | Rust uses unpack_with and MapScheme |

## Discovered during implementation

| Spec | Handling | Status |
|------|----------|--------|
| Rust has no variadic unpack | unpack_with(bytes, handlers) | clear |
| Rust Values layouts have no row type | MapScheme plus pack_map / unpack_map | clear |

## CI-parity

CI-parity: PASS

Commands: `docker compose -f docker-compose.test.yml run --rm` for csharp, typescript, python, rust, cpp, java. C++ after `make -C cpp clean`.

## Commit

`[AZ-1949] Scheme dispatch by the leading type byte`

## Next batch

AZ-1950 field id binding.
