---
loop: 114
branch: dev
tracker: AZ-4237
---
# C++ `ecc_api_tests.cpp`: a 16-byte buffer passed with capacity 17

## Problem
`cpp/tests/core/ecc_api_tests.cpp` `pack_into_a_small_buffer` declares `std::uint8_t out[16]`, then calls `packbin::pack(p4, position_row(), out, 17)`. `ecc::protect` writes the 17th byte: an ASan stack-buffer-overflow in the test (loop 113 security audit F80). The library respects the capacity it is given; the test lies about it.

## Outcome
The test declares `out[17]`; the second call ("room for exactly the message") means 17 bytes. The C++ host suite runs clean under clang `-fsanitize=address,undefined`.

## Code sections
`cpp/tests/core/ecc_api_tests.cpp` line 87. The other `out[16]` buffers (`no_text_tests.cpp:175`, `repeat_last_host_tests.cpp:266`) pass `sizeof(out)` and are correct.

## Acceptance checks
- AC-1: `make -C cpp test` (Apple clang) passes.
- AC-2: the `gcc:16` container `make test` passes.
- AC-3: an ASan + UBSan build of the host suite (`-fsanitize=address,undefined -fno-sanitize-recover`) prints `all tests passed` and no sanitizer report.

## Needs
none

## Constraints
Test code only; no library change. Short loop (one line, test only): no new-task, plan or feature-assess.
