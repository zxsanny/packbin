---
kind: queue-item
order: 900
source: agent-made items below high, gathered 2026-11-13 (loop 118 bootstrap) under work-queue.md §Agent-made work
origin: agent
severity: medium
depends_on: []
status: ready
loop: 121
branch: dev
blocked_on:
created: 2026-11-13
scanned: 2026-11-13
---
# Hygiene: seven small agent-found items

One loop for all entries (`autodev/protocols/work-queue.md` §Agent-made work, rule 1). Each entry keeps the text of its former queue item.

## C++ big-endian row: compare the percentage packets with the Cortex-M3 file

slug `s390x-percentage-packets-vs-m3`; severity low; source: loop98 record (leftovers: "the s390x stage does not compare its percentage packets with the M3 file"); `cpp/embedded/arm.sh` `target_s390x`; created 2026-11-12
#### Problem
The `cpp-m33f` row compares its `PERCENT_HEX` packets (parity percentage, loop 97) with `m3-percent.hex` written by `cpp-m3-qemu`. The big-endian `cpp-s390x` row compares only the all-kinds packet with `m3-all-kinds.hex`; its percentage packets are printed and not compared.

#### Outcome
The s390x row fails when a percentage packet differs from the Cortex-M3 bytes.

#### Code sections
`cpp/embedded/arm.sh` (`target_s390x`, `percent_packets`), `cpp/embedded/lib.test.sh`, `cpp/embedded/run-parts.test.sh`.

#### Acceptance checks
- `target_s390x` writes its percentage packets with `percent_packets` and compares them with `m3-percent.hex`, as `target_m33f` does; a missing M3 file is reported the way the all-kinds check reports it.
- The stub tests of `lib.test.sh` cover the equal and the differing case.
- `docker compose -f docker-compose.test.yml run --rm cpp-embedded` passes.

#### Needs
none

#### Constraints
No pin and no core source changes.

## Dart: use the load-aware timing helper in the wall-clock tests

slug `dart-colliding-keys-timing-helper`; severity low; source: found in loop113 (AZ-4217 fix round: `dart/test/limits/colliding_keys_test.dart` failed once at host load 50, 1,377 ms against `lessThan(1000)`); created 2026-11-12
#### Problem
`dart/test/limits/colliding_keys_test.dart` (65,535 colliding keys, two bounds `lessThan(1000)` at about lines 146 and 180) uses fixed wall-clock bounds. In loop 113 it failed once at host load about 50 (1,377 ms) and passed in the final run. The other eight packages use a load-aware helper for every wall-clock check (`_docs/gotchas/timing-bounds-use-load-factor.md`). Dart had none until loop 113, which added `dart/test/support/timing.dart` for its own new cost test.

#### Outcome
Every wall-clock assertion of the Dart suite calls the helper; a fixed bound does not fail on a busy host.

#### Code sections
`dart/test/limits/colliding_keys_test.dart`, any other `lessThan(` or `Stopwatch` use under `dart/test/` (search), `dart/test/support/timing.dart`.

#### Acceptance checks
- `git grep -n -E "lessThan\(|Stopwatch" dart/test` lists only calls inside the helper or tests that use it.
- The suite passes at an idle host and at load above 30 (run twice).

#### Needs
none

#### Constraints
The nominal bounds stay as they are; the helper scales them by the measured load.

## Java, C# and Go: the repeat-last walk is quadratic on a deep chain of containers

slug `walk-first-writer-memo-java-csharp-go`; severity low; source: found in loop113 (security audit F79, `_docs/05_security/security_report_loop113.md`); created 2026-11-12
#### Problem
`SchemeOrder.repeatLast` (Java), `RoundScopes.CheckLast` (C#) and `checkRepeatLast` (Go) call `firstWriter` at each level while a repeat is open, so a chain of nested `when` or group containers costs O(depth squared): Java 438 ms at depth 8,000 (9 ms at 1,000), C# 336 ms (13 ms before the rule). Both fail on the stack before the depth gets much larger, so the cost stays under a second. TypeScript, Dart and Swift were changed to one pass in loop 113; Python, Rust and C++ were linear. The schemes are code, not wire input.

#### Outcome
The three walks memoize the first writer (or carry the open repeat forward in one pass, as Swift and Dart do), so the walk is linear for any shape; every decision and refusal text stays the same.

#### Code sections
`java/src/main/java/packbin/SchemeOrder.java`, `csharp/RoundScopes.cs`, `go/counted.go`; tests in each package with the package's load-aware timing helper.

#### Acceptance checks
- A scheme with a chain of 4,000 nested `when`s (and one with 16,000 sibling `when`s that write nothing) builds in time linear in its size in each of the three packages (a timing test with the load helper that fails on the old walk).
- A differential over random trees gives the same decisions and texts as before.
- The three package suites pass.

#### Needs
none

#### Constraints
No packet change; the shared hostile cases and every refusal text stay unchanged.

## Java and Python: a missing required member is named by its name, not its id

slug `missing-member-message-by-name-java-python`; severity medium; source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 7); created 2026-11-12
#### Problem
A row whose required `utf8 text` (id 1) is missing is refused by Java with `1: expected string` and by Python with `1: expected str`; TypeScript, Go and Swift say `missing text`. The id alone does not tell a scheme author which member is missing in a row of several.

#### Outcome
Java and Python refuse a missing (null / absent) required member with a message that names the member, as TypeScript, Go and Swift do; a present value of the wrong type keeps its current message.

#### Code sections
Java `VarFields.java` (the string getter), the matching paths for other kinds; Python `_pack.py` (the `expected str` check and its siblings); both packages' tests that pin the old text (grep them first).

#### Acceptance checks
- Java and Python probe line `null-member` prints a refusal that contains `missing text`.
- A wrong-type value (an int for `text`) keeps its current message.
- Every test or fixture that pins the old text is updated in the same change; both suites pass.

#### Needs
none

## Python: a `None` item in a list of rows is refused, not a raw `TypeError`

slug `python-null-item-in-element-row`; severity medium; source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 8); created 2026-11-12
#### Problem
`bash scripts/probes/element-row/run.sh python` line `null-item`: a list of element rows that holds `None` escapes pack as `TypeError: 'NoneType' object is not subscriptable` (the element's key accessor `row[key]`, `python/src/packbin/_nodes.py`, called from `_pack_element` in `_pack.py`). TypeScript, Java, Go and Swift refuse it with their own error (Go: `items: an item has no value`).

#### Outcome
Pack refuses a `None` item of a list (and a `None` value of a dict) whose element is a row with the package's own error naming the list, as it refuses other bad items; the probe line becomes `refused:`.

#### Code sections
`python/src/packbin/_pack.py` (`_pack_list_items`, `_pack_dict_items`, `_pack_element`), Python tests; the probe needs no change.

#### Acceptance checks
- `[c1, None]` and `{"a": None}` in an element-row list / dict: pack raises the package's `TypeError` / `ValueError` (the type the package uses for other bad items) naming the field; nothing is returned.
- A list of plain values that holds `None` behaves as today (measure first, keep it).
- The probe's `python null-item` line reads `refused:`; all other Python probe lines unchanged; the Python suite passes.

#### Needs
none

## C++: wall-clock bounds in a sanitizer build of the host suite

slug `cpp-wall-clock-bounds-under-sanitizers`; severity medium; source: found in loop114 (AZ-4237 smoke: the ASan + UBSan host suite); created 2026-11-12
#### Problem
Under clang `-fsanitize=address,undefined` the C++ host suite reports no memory or UB error since AZ-4237, but the text speed check "AC-7 100,000 round trips within one second" fails in about one run of two (1.015 s against 1.012 s, 1.017 s against 1.004 s, loop 114, host load 9 to 50). `load_factor.hpp` scales a bound by an integer xorshift loop that ASan does not instrument, while the timed text code is memory work that ASan slows, so the factor does not see the sanitizer's cost. The plain Apple clang and GCC 16 builds hold the bound. This blocks running the host suite under ASan in CI, which the loop 113 security audit recommends (long term).

#### Outcome
A sanitizer build of `build/packbin_tests` prints `all tests passed` on this Mac and on the CI runner, while the plain builds keep every wall-clock bound as it is.

#### Code sections
`cpp/tests/core/load_factor.hpp` (the factor, `expect_within`), `cpp/tests/core/text_codec_host_tests.cpp:264`, and every other `expect_within` / `load_factor::bound` caller (`hostile_host_tests.cpp`, the ECC and text-repeat timing lines); `cpp/Makefile` if a sanitizer target is added.

#### Acceptance checks
- A sanitizer build (`-fsanitize=address,undefined -fno-sanitize-recover=all`) passes 5 runs in a row on this Mac with no sanitizer report.
- `make -C cpp test` (Apple clang) and `gcc:16` `make test` pass, and a deliberately slowed timed section still fails the plain build (a check on a broken copy).

#### Needs
none

#### Constraints
Do not widen the bounds of the plain build. One way, to be chosen in the task: the timing checks print but do not assert when `__has_feature(address_sanitizer)` / `__SANITIZE_ADDRESS__` is set.

## C++: pin the Arduino-ESP32 core of the ESP core stage

slug `esp-core-arduino-pin`; severity medium; source: found in loop113 (AZ-4219 report: "the ESP stage installs the newest Arduino-ESP32 core, 3.3.12 today, unpinned; 525 s"); created 2026-11-12
#### Problem
`bash cpp/embedded/run.sh host esp core` installs the newest Arduino-ESP32 core at run time (3.3.12 on 2026-11-12) and took 525 s on this host in loop 113 (about 3 minutes expected). A new core release can change the build or the time with no change in this repository, and the CI job `embedded-esp-core` has the same exposure.

#### Outcome
The core version is pinned in one place that both the Mac run and the CI job read, with a gotcha file under `_docs/gotchas/` (and its line in `_docs/gotchas/INDEX.md`) saying how to move it.

#### Code sections
`cpp/embedded/esp.sh`, `cpp/embedded/run.sh`, the Docker image or the PlatformIO / arduino-cli configuration it uses, `.github/workflows/test.yml` job `embedded-esp-core`, `cpp/embedded/*.test.sh`.

#### Acceptance checks
- The stage prints the core version it uses and fails if it differs from the pin.
- `bash cpp/embedded/run.sh host esp core` passes with the pinned core; the stub tests of `lib.test.sh` and `run-parts.test.sh` pass.
- The pin and its date are recorded where the other tool pins are (`.github/workflows/tool-pin.sh` if the project keeps tool pins there).

#### Needs
none

#### Constraints
The source count of the stage (`expected N packbin sources`) does not change.

## Java: a top-level typed row member declared for another class still throws at pack

slug `java-top-level-row-class`; severity medium; source: found in loop 119 (review of AZ-4253); created 2026-11-13

#### Problem
AZ-4253 refuses at build a member of another row class inside a nested row or an element row, using the group's child factory. A top-level `new Scheme<>(1, Row.class, ...)` has no factory, so a member declared for `Other` still builds and pack throws a raw `ClassCastException`. C# refuses it at build (`'Q' is declared for row type Other, but this scheme is for R`).

#### Outcome
The top-level case is refused at build too, or the README says why it cannot be (no instance to call the accessors on).

#### Code sections
`java/src/main/java/packbin/Scheme.java` (the constructor has `Class<T> type`), `RowClassCheck.java`.

#### Acceptance checks
- A top-level member of another class is refused at build with the AZ-4253 text, or the README states the limit.
- Open point for the operator if it needs one: create the row with its no-argument constructor by reflection (fails for a class without one).
