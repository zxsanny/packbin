---
kind: queue-item
order: 900
source: agent-made items below high, gathered 2026-11-13 (loop 122 close) under work-queue.md §Agent-made work
origin: agent
severity: low
depends_on: []
status: ready
blocked_on:
created: 2026-11-13
scanned: 2026-11-13
loop: 123
branch: dev
---
# Hygiene: agent-found entries

One loop for all entries (`autodev/protocols/work-queue.md` §Agent-made work, rule 1). Ready when it holds five entries, or when nothing else in the queue is ready.

## C++: a `when` of 255 or more members does not build with upstream clang

slug `cpp-fold-depth-upstream-clang`; severity low; source: found in loop 122 (AZ-4278, the first CI-image sanitizer build); created 2026-11-13
#### Problem
`cpp/include/packbin/table.hpp:266` sums the node sizes of a group with a fold expression, `(std::size_t{0} + ... + Ns::size)`. Upstream clang's default nesting limit is 256, so a scheme with a `when` (or another group) of 255 or more members fails to compile in a user's own clang build: `instantiating fold expression with 302 arguments exceeded expression nesting limit of 256` (the host test `when_skipped_source_host_tests.cpp:204`, 300 fillers). Apple's clang and GCC build it. Only the sanitizer build sets `-fbracket-depth=512` (`cpp/Makefile` `SAN_FLAGS`).

#### Outcome
A group of any member count the core accepts compiles with upstream clang at its default limits, or the limit is stated in the README.

#### Code sections
`cpp/include/packbin/table.hpp` (the size fold near line 266, and any other fold over a group's members: `git grep -n '\.\.\. +' cpp/include`), `cpp/Makefile` (`SAN_FLAGS`), `cpp/tests/core/when_skipped_source_host_tests.cpp`.

#### Acceptance checks
- `clang++-19` (Debian, in the `gcc:16` image) builds the host suite without `-fbracket-depth`; the flag is removed from `SAN_FLAGS`.
- No change in flash or stack of the `cpp-m33f` row beyond its pins (a constexpr loop or array sum, not a recursive template).

#### Needs
none

## CI: the sanitizer step's clang-19 depends on the floating gcc:16 Debian base

slug `cpp-sanitizer-clang-base`; severity low; source: found in loop 122 (AZ-4278 review, security report L1); created 2026-11-13
#### Problem
`run-suite.sh cpp` installs Debian's `clang-<major>` (pin `clang==19` in `tool-pins.txt`) in the `gcc:16` image. The tag `gcc:16` floats; a rebuild on a later Debian release may not ship `clang-19`, and the cpp suite then fails at the install with `Unable to locate package clang-19` and no repository change.

#### Outcome
When the base moves, the failure says what to change, and the change is one line.

#### Code sections
`.github/workflows/tool-pins.txt` (the `clang` comment), `.github/workflows/run-suite.sh` (`cpp_clang_install`), `_docs/gotchas/timing-bounds-use-load-factor.md` or a new gotcha.

#### Acceptance checks
- A failed install prints one line naming the pin line to move and the Debian release of the image (`/etc/debian_version`).
- The self-test `run-suite.test.sh` covers that message with a fake `apt-get` that fails.

#### Needs
none
