---
loop: 123
branch: dev
---

# C++: a group of 255+ members builds with upstream clang at default limits

**Task**: AZ-4279_cpp_fold_depth_upstream_clang
**Description**: entry `cpp-fold-depth-upstream-clang` of `_docs/02_task_plans/hygiene-loop123/queue_item.md`; its text is the spec.
**Complexity**: 2 points
**Dependencies**: none
**Component**: cpp/include/packbin/
**Tracker**: AZ-4279
**Epic**: AZ-4133

## Problem
Fold expressions over a group's or a scheme's members nest one level per member, and upstream clang refuses more than 256 (`-fbracket-depth`): `table.hpp` `total()` (the size sum) and `nest()` (the comma fold that copies the children), `codec.hpp` `scheme()` (the `&&` fold of `binds_row` and the comma fold that copies the nodes). A `when` of 300 members fails with Debian clang 19 (loop 122); Apple clang and GCC build it.

## Outcome
Those four folds become pack expansions in an array initializer, which do not nest; the sanitizer build drops `-fbracket-depth=512`.

## Acceptance checks
- AC-1: `make -C cpp CXX=clang++-19 sanitizer-test` in `gcc:16` passes with `SAN_FLAGS` without `-fbracket-depth` (the 300-filler test of `when_skipped_source_host_tests.cpp` compiles).
- AC-2: a top-level scheme of 300 fields also compiles with clang 19 at default limits (a host test, which fails to compile on the old header with clang 19).
- AC-3: the plain suite, the compile-fail tests and the embedded rows (`cpp-embedded-arm`, `cpp-m33f` flash and stack pins) are unchanged.

## Constraints
Folds over schemes of `pack_any` / `unpack(on(...))` (a handful of schemes) and over type lists in `platform.hpp` stay.
