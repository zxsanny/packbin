---
title: "Check a C++ change in the gcc:16 container before the commit; a clean Mac build proves nothing about GCC"
applies_when: "changing C++ sources or tests before a batch commit"
source: "loop 18 (new test files failed the CI container on -Warray-bounds and -Wformat-truncation)"
---

C++ is built with `-Wall -Wextra -Werror` by GCC 16 in CI (`gcc:16`) and by Apple clang on this Mac: a clean `make -C cpp test` on the Mac proves nothing about GCC (loop 18: new test files failed the CI container on `-Warray-bounds` false positives and `-Wformat-truncation`). A C++ worker or the parent checks with `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` (about 15 s) before the batch commit.

Before and after that container run, see [cpp-build-clean-host-vs-container.md](cpp-build-clean-host-vs-container.md): `cpp/build/` is shared between the host and the container.
