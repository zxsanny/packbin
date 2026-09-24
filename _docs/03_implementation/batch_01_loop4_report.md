# Batch 1 — Loop 4

**Tasks**: AZ-1945
**Verdict**: PASS_WITH_WARNINGS
**Date**: 2026-09-24

## Results

| Task | Status | Areas | Tests | Notes |
|------|--------|-------|-------|-------|
| AZ-1945 | Done | six language packages | CI compose suites green | File-length warnings |

## Discovered during implementation

| Spec | Handling | Status |
|------|----------|--------|
| Short buffer on the type byte | Existing short-packet error, empty field name | clear |

## CI-parity

CI-parity: PASS

Commands: `docker compose -f docker-compose.test.yml run --rm` for csharp, typescript, python, rust, java; cpp rerun after `make -C cpp clean` because a host Mach-O binary was mounted into the Linux container.

## Commit

`[AZ-1945] Pack a constant type byte on the scheme`

## Next batch

AZ-1946 scheme and BinaryPacker.
