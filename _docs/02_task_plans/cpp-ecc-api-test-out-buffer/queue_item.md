---
kind: queue-item
order: 300
source: found in loop113 (security audit F80: clang ASan + UBSan over the C++ host suite)
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# C++: `ecc_api_tests.cpp` passes a 17-byte capacity for a 16-byte buffer

## Problem
`cpp/tests/core/ecc_api_tests.cpp:90` declares `out[16]` and calls `ecc::protect` with capacity 17: an ASan stack-buffer-overflow in the test (pre-existing, outside the loop 113 diff; test code only). The ordinary suite passes because the overflow lands on unused stack.

## Outcome
The test declares `out[17]` (or passes capacity 16, whichever the test means), and the C++ host suite runs clean under clang `-fsanitize=address,undefined`.

## Code sections
`cpp/tests/core/ecc_api_tests.cpp` (line 90 and any neighbour with the same pattern: search `out\[16\]`).

## Acceptance checks
- `make -C cpp test` (Apple clang) and the `gcc:16` container `make test` pass.
- An ASan + UBSan build of the host suite (the recipe is in `_docs/05_security/security_report_loop113.md`) reports nothing.

## Needs
none

## Constraints
No library change; the string-free and ECC-free builds still pass.
